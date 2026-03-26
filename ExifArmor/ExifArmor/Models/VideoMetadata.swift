import AVFoundation
import CoreLocation
import Foundation

struct VideoMetadata: Identifiable {
    let id = UUID()
    let fileURL: URL
    var duration: CMTime = .zero
    var fileSize: Int64 = 0
    var creationDate: Date?
    var location: CLLocation?
    var make: String?
    var model: String?
    var software: String?

    var hasLocation: Bool { location != nil }
    var hasDeviceInfo: Bool { make != nil || model != nil }

    var exposedFieldCount: Int {
        [hasLocation, creationDate != nil, make != nil, model != nil, software != nil]
            .filter { $0 }
            .count
    }

    var privacyScore: Int {
        var score = 0
        if hasLocation { score += 4 }
        if hasDeviceInfo { score += 2 }
        if creationDate != nil { score += 2 }
        return min(score, 10)
    }

    var formattedDuration: String {
        let seconds = Int(CMTimeGetSeconds(duration).isFinite ? CMTimeGetSeconds(duration) : 0)
        return String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
}
