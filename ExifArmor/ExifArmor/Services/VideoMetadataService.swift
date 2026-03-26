import AVFoundation
import CoreLocation
import Foundation

struct VideoMetadataService {
    static func extractMetadata(from url: URL) async -> VideoMetadata {
        var meta = VideoMetadata(fileURL: url)
        meta.fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize)
            .flatMap { Int64($0) } ?? 0

        let asset = AVURLAsset(url: url)
        meta.duration = (try? await asset.load(.duration)) ?? .zero

        let items = (try? await asset.load(.metadata)) ?? []
        for item in items {
            guard let key = item.commonKey else { continue }

            switch key {
            case .commonKeyCreationDate:
                meta.creationDate = try? await item.load(.dateValue)
            case .commonKeyMake:
                meta.make = try? await item.load(.stringValue)
            case .commonKeyModel:
                meta.model = try? await item.load(.stringValue)
            case .commonKeySoftware:
                meta.software = try? await item.load(.stringValue)
            case .commonKeyLocation:
                if let data = try? await item.load(.dataValue),
                   let string = String(data: data, encoding: .utf8) {
                    meta.location = parseISO6709(string)
                } else if let string = try? await item.load(.stringValue) {
                    meta.location = parseISO6709(string)
                }
            default:
                break
            }
        }

        return meta
    }

    private static func parseISO6709(_ string: String) -> CLLocation? {
        let pattern = #"([+-]\d+\.?\d*)([+-]\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              let latRange = Range(match.range(at: 1), in: string),
              let lonRange = Range(match.range(at: 2), in: string),
              let lat = Double(string[latRange]),
              let lon = Double(string[lonRange])
        else {
            return nil
        }

        return CLLocation(latitude: lat, longitude: lon)
    }
}
