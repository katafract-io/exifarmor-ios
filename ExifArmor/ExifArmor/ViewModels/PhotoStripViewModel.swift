import Foundation
import AVFoundation
import Photos
import PhotosUI
import SwiftUI
import UniformTypeIdentifiers
import UIKit

/// Drives the core workflow: pick → analyze → preview → strip → save/share.
@Observable
final class PhotoStripViewModel {

    private enum Keys {
        static let defaultStripMode = "defaultStripMode"
    }

    // MARK: - State

    enum Phase {
        case idle
        case loading
        case preview
        case stripping
        case done
        case error(String)
    }

    var phase: Phase = .idle
    var selectedItems: [PhotosPickerItem] = []
    var analyzedPhotos: [PhotoMetadata] = []
    var analyzedVideos: [VideoMetadata] = []
    var stripResults: [StripResult] = []
    var videoStripResults: [URL] = []
    var stripOptions: StripOptions = .all
    var showStripOptions: Bool = false
    private var sharedItemURLs: [URL] = []

    // Batch progress
    var processedCount: Int = 0
    var totalCount: Int = 0

    // MARK: - Load Selected Photos

    /// Load image data from PhotosPicker selections and extract metadata.
    func loadSelectedPhotos() async {
        guard !selectedItems.isEmpty else { return }

        await MainActor.run {
            phase = .loading
            analyzedPhotos = []
            analyzedVideos = []
            stripResults = []
            videoStripResults = []
            processedCount = 0
            totalCount = selectedItems.count
        }

        var photoResults: [PhotoMetadata] = []
        var videoResults: [VideoMetadata] = []

        for item in selectedItems {
            guard !item.supportedContentTypes.contains(.movie) else {
                await MainActor.run {
                    processedCount += 1
                }
                continue
            }

            do {
                guard let data = try await item.loadTransferable(type: Data.self),
                      let image = UIImage(data: data)
                else { continue }

                let isLivePhoto = item.supportedContentTypes.contains(.livePhoto)
                var metadata = MetadataService.extractMetadata(from: data, image: image)
                metadata.isLivePhoto = isLivePhoto
                photoResults.append(metadata)
            } catch {
                // Skip photos that fail to load
            }

            await MainActor.run {
                processedCount += 1
            }
        }

        for item in selectedItems {
            guard item.supportedContentTypes.contains(.movie) else { continue }

            if let url = try? await item.loadTransferable(type: URL.self) {
                let videoMeta = await VideoMetadataService.extractMetadata(from: url)
                videoResults.append(videoMeta)
            }
        }

        await MainActor.run {
            analyzedPhotos = photoResults
            analyzedVideos = videoResults
            phase = (photoResults.isEmpty && videoResults.isEmpty) ? .error("Could not load any media") : .preview
        }
    }

    // MARK: - Strip Metadata

    func stripAll() async {
        await MainActor.run {
            phase = .stripping
            stripResults = []
            videoStripResults = []
            processedCount = 0
            totalCount = analyzedPhotos.count + (stripOptions.includeVideos ? analyzedVideos.count : 0)
        }

        var results: [StripResult] = []

        for metadata in analyzedPhotos {
            let fieldsToRemove = StripService.countFieldsToRemove(
                from: metadata, options: stripOptions
            )

            if let cleanedData = StripService.stripMetadata(
                from: metadata.imageData, options: stripOptions
            ),
               let cleanedImage = UIImage(data: cleanedData) {

                let result = StripResult(
                    originalMetadata: metadata,
                    cleanedImageData: cleanedData,
                    cleanedImage: cleanedImage,
                    fieldsRemoved: fieldsToRemove
                )
                results.append(result)
            }

            await MainActor.run {
                processedCount += 1
            }
        }

        await stripAllVideos()

        await MainActor.run {
            stripResults = results
            phase = (results.isEmpty && videoStripResults.isEmpty) ? .error("Failed to strip media") : .done
        }
    }

    func stripAllVideos() async {
        guard stripOptions.includeVideos else { return }

        for meta in analyzedVideos {
            if let cleanURL = try? await VideoStripService.stripMetadata(from: meta.fileURL) {
                await MainActor.run {
                    videoStripResults.append(cleanURL)
                    processedCount += 1
                }
            } else {
                await MainActor.run {
                    processedCount += 1
                }
            }
        }
    }

    // MARK: - Save to Photo Library

    func saveAllToPhotoLibrary() async -> Bool {
        do {
            for result in stripResults {
                try await saveToPhotoLibrary(data: result.cleanedImageData)
            }
            for url in videoStripResults {
                try await PHPhotoLibrary.shared().performChanges {
                    let request = PHAssetCreationRequest.forAsset()
                    request.addResource(with: .video, fileURL: url, options: nil)
                }
            }
            return true
        } catch {
            await MainActor.run {
                phase = .error("Failed to save: \(error.localizedDescription)")
            }
            return false
        }
    }

    private func saveToPhotoLibrary(data: Data) async throws {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "ExifArmor",
                        code: -1,
                        userInfo: [NSLocalizedDescriptionKey: "Failed to save cleaned photo"]
                    ))
                }
            }
        }
    }

    // MARK: - Share

    /// Returns temp file URLs for the cleaned images so that all share destinations
    /// (Instagram, Facebook, Messages, Mail, etc.) can accept them.
    func shareItems() -> [Any] {
        cleanupSharedItems()
        let tmpDir = FileManager.default.temporaryDirectory
        let imageURLs = stripResults.compactMap { result -> URL? in
            let ext = preferredImageExtension(for: result.originalMetadata.sourceUTI)
            let filename = "ExifArmor_\(UUID().uuidString.prefix(8)).\(ext)"
            let url = tmpDir.appendingPathComponent(filename)
            let data = result.cleanedImageData
            do {
                try data.write(to: url, options: .atomic)
                return url
            } catch {
                return nil
            }
        }

        sharedItemURLs = imageURLs + videoStripResults
        return sharedItemURLs
    }

    // MARK: - Reset

    func reset() {
        cleanupSharedItems()
        for url in videoStripResults {
            try? FileManager.default.removeItem(at: url)
        }
        phase = .idle
        selectedItems = []
        analyzedPhotos = []
        analyzedVideos = []
        stripResults = []
        videoStripResults = []
        processedCount = 0
        totalCount = 0
        applySavedDefaultStripMode()
    }

    // MARK: - Stats for this batch

    var totalFieldsRemoved: Int {
        stripResults.reduce(0) { $0 + $1.fieldsRemoved }
            + analyzedVideos.reduce(0) { $0 + $1.exposedFieldCount }
    }

    var hadLocationData: Bool {
        analyzedPhotos.contains { $0.hasLocation } || analyzedVideos.contains { $0.hasLocation }
    }

    var totalProcessedMediaCount: Int {
        stripResults.count + videoStripResults.count
    }

    func applySavedDefaultStripMode() {
        stripOptions = stripOptions(for: UserDefaults.standard.string(forKey: Keys.defaultStripMode) ?? "all")
    }

    private func stripOptions(for mode: String) -> StripOptions {
        switch mode {
        case "location":
            return .locationOnly
        case "privacy":
            return .privacyFocused
        default:
            return .all
        }
    }

    private func preferredImageExtension(for sourceUTI: String?) -> String {
        guard let sourceUTI,
              let type = UTType(sourceUTI),
              let ext = type.preferredFilenameExtension
        else {
            return "jpg"
        }
        return ext
    }

    private func cleanupSharedItems() {
        for url in sharedItemURLs {
            try? FileManager.default.removeItem(at: url)
        }
        sharedItemURLs = []
    }
}
