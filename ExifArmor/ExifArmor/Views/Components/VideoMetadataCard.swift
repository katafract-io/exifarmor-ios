import CoreLocation
import SwiftUI

struct VideoMetadataCard: View {
    let video: VideoMetadata

    var body: some View {
        MetadataCard(
            icon: "video.fill",
            title: "Video File",
            iconColor: Color("AccentMagenta"),
            severity: video.hasLocation ? .critical : .info
        ) {
            MetadataRow(label: "Duration", value: video.formattedDuration)
            MetadataRow(label: "File Size", value: video.formattedFileSize)

            if let location = video.location {
                MetadataRow(
                    label: "GPS",
                    value: String(format: "%.6f, %.6f", location.coordinate.latitude, location.coordinate.longitude)
                )
            }

            if let creationDate = video.creationDate {
                MetadataRow(
                    label: "Created",
                    value: creationDate.formatted(date: .abbreviated, time: .shortened)
                )
            }

            if let make = video.make {
                MetadataRow(label: "Make", value: make)
            }

            if let model = video.model {
                MetadataRow(label: "Model", value: model)
            }

            if let software = video.software {
                MetadataRow(label: "Software", value: software)
            }
        }
    }
}
