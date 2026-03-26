import AVFoundation
import Foundation

struct VideoStripService {
    enum VideoStripError: LocalizedError {
        case exportFailed(String?)
        case unsupportedFormat
        case cancelled

        var errorDescription: String? {
            switch self {
            case .exportFailed(let message):
                return "Export failed: \(message ?? "unknown error")"
            case .unsupportedFormat:
                return "This video format is not supported."
            case .cancelled:
                return "Export was cancelled."
            }
        }
    }

    /// Strips metadata from a video file and returns the URL of the cleaned temp file.
    /// Caller must delete the output file after use.
    static func stripMetadata(from inputURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: inputURL)
        guard try await asset.load(.isExportable) else {
            throw VideoStripError.unsupportedFormat
        }

        let ext = inputURL.pathExtension.lowercased()
        let outputFileType: AVFileType = ext == "mp4" ? .mp4 : .mov
        guard let session = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetPassthrough
        ) else {
            throw VideoStripError.exportFailed("Could not create export session")
        }

        let tmpURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("ExifArmor_\(UUID().uuidString).\(ext.isEmpty ? "mov" : ext)")

        session.outputURL = tmpURL
        session.outputFileType = outputFileType
        session.metadata = []
        session.metadataItemFilter = AVMetadataItemFilter.forSharing()

        do {
            try await session.export(to: tmpURL, as: outputFileType)
            return tmpURL
        } catch is CancellationError {
            try? FileManager.default.removeItem(at: tmpURL)
            throw VideoStripError.cancelled
        } catch {
            try? FileManager.default.removeItem(at: tmpURL)
            throw VideoStripError.exportFailed(error.localizedDescription)
        }
    }
}
