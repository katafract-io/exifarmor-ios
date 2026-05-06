import Foundation
import UIKit

/// Defines which metadata categories to strip from a photo.
struct StripOptions: Codable, Equatable, Hashable {
    var removeLocation: Bool = true
    var removeDateTime: Bool = true
    var removeDeviceInfo: Bool = true
    var removeCameraSettings: Bool = true
    var removeAll: Bool = true
    var includeVideos: Bool = true

    /// Preset: remove everything (default).
    static let all = StripOptions(
        removeLocation: true,
        removeDateTime: true,
        removeDeviceInfo: true,
        removeCameraSettings: true,
        removeAll: true,
        includeVideos: true
    )

    /// Preset: remove only GPS/location data.
    static let locationOnly = StripOptions(
        removeLocation: true,
        removeDateTime: false,
        removeDeviceInfo: false,
        removeCameraSettings: false,
        removeAll: false,
        includeVideos: true
    )

    /// Preset: remove location + device info but keep camera settings.
    static let privacyFocused = StripOptions(
        removeLocation: true,
        removeDateTime: true,
        removeDeviceInfo: true,
        removeCameraSettings: false,
        removeAll: false,
        includeVideos: true
    )
}

/// Result of a strip operation on a single photo.
struct StripResult: Identifiable {
    let id = UUID()
    let originalMetadata: PhotoMetadata
    let cleanedImageURL: URL
    let cleanedImage: UIImage   // 512px thumbnail — display only
    let fieldsRemoved: Int

    var cleanedImageData: Data? { try? Data(contentsOf: cleanedImageURL) }
}
