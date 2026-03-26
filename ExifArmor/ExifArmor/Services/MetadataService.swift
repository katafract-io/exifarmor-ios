import Foundation
import ImageIO
import UIKit
import CoreLocation

/// Reads EXIF and other metadata from photo data using ImageIO.
struct MetadataService {

    /// Extract all metadata from raw image data.
    static func extractMetadata(from data: Data, image: UIImage) -> PhotoMetadata {
        var meta = PhotoMetadata(image: image, imageData: data)

        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
            return meta
        }

        meta.sourceUTI = CGImageSourceGetType(source) as? String

        // --- EXIF Dictionary ---
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            meta.exifDictionary = exif
            meta.dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String
            meta.dateTimeDigitized = exif[kCGImagePropertyExifDateTimeDigitized as String] as? String
            meta.focalLength = exif[kCGImagePropertyExifFocalLength as String] as? Double
            meta.iso = (exif[kCGImagePropertyExifISOSpeedRatings as String] as? [Double])?.first
            meta.exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? Double
            meta.lensModel = exif[kCGImagePropertyExifLensModel as String] as? String

            if let apertureValue = exif[kCGImagePropertyExifFNumber as String] as? Double {
                meta.aperture = apertureValue
            }

            if let flashValue = exif[kCGImagePropertyExifFlash as String] as? Int {
                meta.flash = flashValue & 1 == 1  // Bit 0 indicates flash fired
            }
        }

        // --- GPS Dictionary ---
        if let gps = properties[kCGImagePropertyGPSDictionary as String] as? [String: Any] {
            meta.gpsDictionary = gps

            if let lat = gps[kCGImagePropertyGPSLatitude as String] as? Double,
               let latRef = gps[kCGImagePropertyGPSLatitudeRef as String] as? String,
               let lon = gps[kCGImagePropertyGPSLongitude as String] as? Double,
               let lonRef = gps[kCGImagePropertyGPSLongitudeRef as String] as? String {
                meta.latitude = latRef == "S" ? -lat : lat
                meta.longitude = lonRef == "W" ? -lon : lon
            }

            meta.altitude = gps[kCGImagePropertyGPSAltitude as String] as? Double
        }

        // --- TIFF Dictionary ---
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            meta.tiffDictionary = tiff
            meta.deviceMake = tiff[kCGImagePropertyTIFFMake as String] as? String
            meta.deviceModel = tiff[kCGImagePropertyTIFFModel as String] as? String
            meta.software = tiff[kCGImagePropertyTIFFSoftware as String] as? String
            meta.orientation = tiff[kCGImagePropertyTIFFOrientation as String] as? Int
        }

        // --- Top-level properties ---
        meta.pixelWidth = properties[kCGImagePropertyPixelWidth as String] as? Int
        meta.pixelHeight = properties[kCGImagePropertyPixelHeight as String] as? Int
        meta.colorSpace = properties[kCGImagePropertyColorModel as String] as? String

        return meta
    }
}
