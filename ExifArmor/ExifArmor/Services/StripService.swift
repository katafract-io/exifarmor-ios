import Foundation
import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Creates clean copies of images with metadata stripped using ImageIO.
struct StripService {

    /// Strip metadata from image data based on the given options.
    /// Returns new image data with metadata removed, preserving image quality.
    /// Uses CGImageMetadata API to ensure XMP GPS tags are properly removed.
    static func stripMetadata(from data: Data, options: StripOptions) -> Data? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let uti = CGImageSourceGetType(source),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
        else {
            return nil
        }

        // Read existing properties
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else {
            return nil
        }

        var mutableProperties = properties

        if options.removeAll {
            // Nuclear option: remove all metadata dictionaries
            mutableProperties.removeValue(forKey: kCGImagePropertyExifDictionary as String)
            mutableProperties.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
            mutableProperties.removeValue(forKey: kCGImagePropertyIPTCDictionary as String)
            mutableProperties.removeValue(forKey: kCGImagePropertyExifAuxDictionary as String)
            mutableProperties.removeValue(forKey: kCGImagePropertyMakerAppleDictionary as String)

            // Strip TIFF fields that identify the device, but keep orientation
            if var tiff = mutableProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                let orientation = tiff[kCGImagePropertyTIFFOrientation as String]
                tiff.removeAll()
                if let orientation {
                    tiff[kCGImagePropertyTIFFOrientation as String] = orientation
                }
                mutableProperties[kCGImagePropertyTIFFDictionary as String] = tiff
            }

            // Remove JFIF
            mutableProperties.removeValue(forKey: kCGImagePropertyJFIFDictionary as String)

        } else {
            // Selective strip
            if options.removeLocation {
                mutableProperties.removeValue(forKey: kCGImagePropertyGPSDictionary as String)
            }

            if options.removeDateTime {
                if var exif = mutableProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    exif.removeValue(forKey: kCGImagePropertyExifDateTimeOriginal as String)
                    exif.removeValue(forKey: kCGImagePropertyExifDateTimeDigitized as String)
                    exif.removeValue(forKey: kCGImagePropertyExifSubsecTimeOriginal as String)
                    exif.removeValue(forKey: kCGImagePropertyExifSubsecTimeDigitized as String)
                    mutableProperties[kCGImagePropertyExifDictionary as String] = exif
                }
                if var tiff = mutableProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    tiff.removeValue(forKey: kCGImagePropertyTIFFDateTime as String)
                    mutableProperties[kCGImagePropertyTIFFDictionary as String] = tiff
                }
            }

            if options.removeDeviceInfo {
                if var tiff = mutableProperties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
                    let orientation = tiff[kCGImagePropertyTIFFOrientation as String]
                    tiff.removeValue(forKey: kCGImagePropertyTIFFMake as String)
                    tiff.removeValue(forKey: kCGImagePropertyTIFFModel as String)
                    tiff.removeValue(forKey: kCGImagePropertyTIFFSoftware as String)
                    if let orientation {
                        tiff[kCGImagePropertyTIFFOrientation as String] = orientation
                    }
                    mutableProperties[kCGImagePropertyTIFFDictionary as String] = tiff
                }
                // Remove Apple-specific maker data
                mutableProperties.removeValue(forKey: kCGImagePropertyMakerAppleDictionary as String)
            }

            if options.removeCameraSettings {
                if var exif = mutableProperties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
                    exif.removeValue(forKey: kCGImagePropertyExifFocalLength as String)
                    exif.removeValue(forKey: kCGImagePropertyExifFNumber as String)
                    exif.removeValue(forKey: kCGImagePropertyExifExposureTime as String)
                    exif.removeValue(forKey: kCGImagePropertyExifISOSpeedRatings as String)
                    exif.removeValue(forKey: kCGImagePropertyExifFlash as String)
                    exif.removeValue(forKey: kCGImagePropertyExifLensModel as String)
                    exif.removeValue(forKey: kCGImagePropertyExifLensMake as String)
                    mutableProperties[kCGImagePropertyExifDictionary as String] = exif
                }
            }
        }

        // Create new image data with cleaned properties
        let destData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            destData as CFMutableData, uti, 1, nil
        ) else {
            return nil
        }

        // Fetch and clean up XMP metadata to remove GPS tags that iPhone Pro embeds.
        // iPhone 14/15/16 Pro embeds location as XMP, and we must strip it at the metadata
        // level using CGImageMetadata APIs, not just the property dictionary.
        var metadata: CGImageMetadata?
        if let sourceMetadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) {
            if let mutableMetadata = CGImageMetadataCreateMutableCopy(sourceMetadata) {
                stripXMPGPSTags(from: mutableMetadata, removeLocation: options.removeLocation || options.removeAll)
                metadata = mutableMetadata
            } else {
                metadata = sourceMetadata
            }
        }

        // Use CGImageDestinationAddImageAndMetadata to ensure cleaned metadata is written.
        // This respects both the property dictionary and the CGImageMetadata object,
        // preventing XMP GPS tags from bleeding through on iPhone Pro devices.
        if let metadata = metadata {
            CGImageDestinationAddImageAndMetadata(destination, image, metadata, mutableProperties as CFDictionary)
        } else {
            CGImageDestinationAddImage(destination, image, mutableProperties as CFDictionary)
        }

        guard CGImageDestinationFinalize(destination) else {
            return nil
        }

        #if DEBUG
        if let verifySource = CGImageSourceCreateWithData(destData as CFData, nil),
           let outputUTI = CGImageSourceGetType(verifySource) {
            assert(outputUTI == uti, "[StripService] UTI mismatch: input \(uti) → output \(outputUTI)")
            // Verify no XMP GPS tags remain
            assertNoXMPGPSTags(in: destData as Data)
        }
        #endif

        return destData as Data
    }

    /// Strip GPS-related XMP tags from a mutable CGImageMetadata object.
    /// Removes tags like:
    /// - exif:GPSLatitude
    /// - exif:GPSLongitude
    /// - exif:GPSAltitude
    /// - exif:GPSDateStamp
    /// - exif:GPSTimeStamp
    /// - And other GPS-specific XMP namespaced properties
    private static func stripXMPGPSTags(from metadata: CGMutableImageMetadata, removeLocation: Bool) {
        guard removeLocation else { return }

        // Common XMP namespace prefixes for GPS data
        let gpsNamespaces = [
            "exif",   // exif:GPSLatitude, exif:GPSLongitude, etc.
            "exifEx", // exif:GPSLatitude (extended)
            "Exif"    // Case variant
        ]

        let gpsTags = [
            "GPSLatitude",
            "GPSLongitude",
            "GPSAltitude",
            "GPSAltitudeRef",
            "GPSDateStamp",
            "GPSTimeStamp",
            "GPSMapDatum",
            "GPSVersionID",
            "GPSSpeed",
            "GPSSpeedRef",
            "GPSTrack",
            "GPSTrackRef",
            "GPSImgDirection",
            "GPSImgDirectionRef",
            "GPSDestBearing",
            "GPSDestBearingRef",
            "GPSDestDistance",
            "GPSDestDistanceRef",
            "GPSProcessingMethod",
            "GPSAreaInformation",
            "GPSSatellites",
            "GPSDOP",
            "GPSHPositioningError"
        ]

        for namespace in gpsNamespaces {
            for tag in gpsTags {
                let key = "\(namespace):\(tag)"
                CGImageMetadataRemoveTagWithPath(metadata, nil, key as CFString)
            }
        }
    }

    /// Assertion function: verify that output image has no XMP GPS tags.
    /// Called in DEBUG builds after finalization to catch any GPS metadata that leaked through.
    private static func assertNoXMPGPSTags(in data: Data) {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) else {
            return
        }

        // Use CGImageMetadataCopyTags to enumerate all tags in the metadata
        if let tagsArray = CGImageMetadataCopyTags(metadata) as? [CGImageMetadataTag] {
            for tag in tagsArray {
                if let prefix = CGImageMetadataTagCopyPrefix(tag) as String?,
                   let name = CGImageMetadataTagCopyName(tag) as String? {
                    let fullTag = "\(prefix):\(name)"
                    assert(!fullTag.contains("GPS"), "[StripService] GPS XMP tag leaked through: \(fullTag)")
                }
            }
        }
    }

    /// Count how many metadata fields would be removed by the given options.
    static func countFieldsToRemove(from metadata: PhotoMetadata, options: StripOptions) -> Int {
        if options.removeAll {
            return metadata.exposedFieldCount
        }

        var count = 0
        if options.removeLocation && metadata.hasLocation { count += 1 }
        if options.removeLocation && metadata.altitude != nil { count += 1 }
        if options.removeDateTime && metadata.hasDateTime { count += 1 }
        if options.removeDeviceInfo && metadata.deviceMake != nil { count += 1 }
        if options.removeDeviceInfo && metadata.deviceModel != nil { count += 1 }
        if options.removeDeviceInfo && metadata.software != nil { count += 1 }
        if options.removeCameraSettings && metadata.focalLength != nil { count += 1 }
        if options.removeCameraSettings && metadata.aperture != nil { count += 1 }
        if options.removeCameraSettings && metadata.exposureTime != nil { count += 1 }
        if options.removeCameraSettings && metadata.iso != nil { count += 1 }
        if options.removeCameraSettings && metadata.lensModel != nil { count += 1 }
        return count
    }
}
