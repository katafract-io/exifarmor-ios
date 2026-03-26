import Foundation
import CoreLocation
import UIKit

/// Represents all extractable metadata from a single photo.
struct PhotoMetadata: Identifiable {
    let id = UUID()
    let image: UIImage
    let imageData: Data
    var sourceUTI: String?
    var isLivePhoto: Bool = false

    // Location
    var latitude: Double?
    var longitude: Double?
    var altitude: Double?
    var coordinate: CLLocationCoordinate2D? {
        guard let lat = latitude, let lon = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    // Device
    var deviceMake: String?
    var deviceModel: String?
    var software: String?
    var lensModel: String?

    // Date/Time
    var dateTimeOriginal: String?
    var dateTimeDigitized: String?

    // Camera Settings
    var focalLength: Double?
    var aperture: Double?
    var exposureTime: Double?
    var iso: Double?
    var flash: Bool?

    // Image Info
    var pixelWidth: Int?
    var pixelHeight: Int?
    var colorSpace: String?
    var orientation: Int?

    // Raw dictionaries for custom strip
    var exifDictionary: [String: Any]?
    var gpsDictionary: [String: Any]?
    var tiffDictionary: [String: Any]?

    /// True if this photo has any GPS data embedded.
    var hasLocation: Bool { latitude != nil && longitude != nil }

    /// True if this photo has any device-identifying info.
    var hasDeviceInfo: Bool { deviceMake != nil || deviceModel != nil || software != nil }

    /// True if this photo has date/time info.
    var hasDateTime: Bool { dateTimeOriginal != nil }

    /// Total number of metadata fields found.
    var exposedFieldCount: Int {
        var count = 0
        if hasLocation { count += 1 }
        if altitude != nil { count += 1 }
        if deviceMake != nil { count += 1 }
        if deviceModel != nil { count += 1 }
        if software != nil { count += 1 }
        if lensModel != nil { count += 1 }
        if dateTimeOriginal != nil { count += 1 }
        if dateTimeDigitized != nil { count += 1 }
        if focalLength != nil { count += 1 }
        if aperture != nil { count += 1 }
        if exposureTime != nil { count += 1 }
        if iso != nil { count += 1 }
        if flash != nil { count += 1 }
        if colorSpace != nil { count += 1 }
        return count
    }

    /// Severity rating: how much personal info is exposed (0-10).
    var privacyScore: Int {
        var score = 0
        if hasLocation { score += 4 }  // GPS is the biggest risk
        if hasDeviceInfo { score += 2 }
        if hasDateTime { score += 2 }
        if altitude != nil { score += 1 }
        if lensModel != nil { score += 1 }
        return min(score, 10)
    }

    /// Human-readable exposure time (e.g., "1/125s")
    var formattedExposureTime: String? {
        guard let time = exposureTime else { return nil }
        if time >= 1 {
            return String(format: "%.1fs", time)
        } else {
            let denominator = Int(round(1.0 / time))
            return "1/\(denominator)s"
        }
    }
}
