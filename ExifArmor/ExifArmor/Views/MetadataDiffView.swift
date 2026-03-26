import CoreLocation
import SwiftUI

struct MetadataDiffView: View {
    let result: StripResult
    let options: StripOptions

    enum DiffStatus {
        case removed
        case retained
        case notPresent
    }

    struct DiffRow: Identifiable {
        let id = UUID()
        let field: String
        let originalValue: String
        let status: DiffStatus
    }

    private var rows: [DiffRow] { buildRows() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    Image(uiImage: result.cleanedImage)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 200)
                        .clipped()

                    VStack(spacing: 20) {
                        diffSection(
                            "Removed",
                            rows: rows.filter { $0.status == .removed },
                            icon: "minus.circle.fill",
                            color: Color("WarningRed")
                        )
                        diffSection(
                            "Retained",
                            rows: rows.filter { $0.status == .retained },
                            icon: "checkmark.circle.fill",
                            color: Color("SuccessGreen")
                        )
                        diffSection(
                            "Not Present in This Photo",
                            rows: rows.filter { $0.status == .notPresent },
                            icon: "circle.dashed",
                            color: Color("TextSecondary")
                        )
                    }
                    .padding(16)
                }
            }
            .background(Color("BackgroundDark"))
            .navigationTitle("Metadata Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .preferredColorScheme(.dark)
    }

    private func diffSection(_ title: String, rows: [DiffRow], icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(color)
                .textCase(.uppercase)
                .tracking(0.5)

            ForEach(rows) { row in
                HStack(spacing: 10) {
                    Image(systemName: icon)
                        .foregroundStyle(color)
                        .frame(width: 20)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.field)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color("TextPrimary"))
                        Text(row.originalValue)
                            .font(.caption.monospaced())
                            .foregroundStyle(Color("TextSecondary"))
                    }

                    Spacer()
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.field): \(row.originalValue) - \(accessibilityStatus(row.status))")
            }
        }
        .padding(14)
        .background(Color("CardBackground"))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func accessibilityStatus(_ status: DiffStatus) -> String {
        switch status {
        case .removed:
            return "removed"
        case .retained:
            return "retained"
        case .notPresent:
            return "not present"
        }
    }

    private func buildRows() -> [DiffRow] {
        let metadata = result.originalMetadata
        let currentOptions = options
        var rows: [DiffRow] = []

        func row(_ field: String, value: String?, removedWhen: Bool) {
            if let value {
                rows.append(
                    DiffRow(
                        field: field,
                        originalValue: value,
                        status: removedWhen ? .removed : .retained
                    )
                )
            } else {
                rows.append(DiffRow(field: field, originalValue: "Not found", status: .notPresent))
            }
        }

        row(
            "GPS Location",
            value: metadata.coordinate.map { String(format: "%.6f, %.6f", $0.latitude, $0.longitude) },
            removedWhen: currentOptions.removeAll || currentOptions.removeLocation
        )
        row(
            "Altitude",
            value: metadata.altitude.map { String(format: "%.1f m", $0) },
            removedWhen: currentOptions.removeAll || currentOptions.removeLocation
        )
        row(
            "Date Taken",
            value: metadata.dateTimeOriginal,
            removedWhen: currentOptions.removeAll || currentOptions.removeDateTime
        )
        row(
            "Device Make",
            value: metadata.deviceMake,
            removedWhen: currentOptions.removeAll || currentOptions.removeDeviceInfo
        )
        row(
            "Device Model",
            value: metadata.deviceModel,
            removedWhen: currentOptions.removeAll || currentOptions.removeDeviceInfo
        )
        row(
            "Software",
            value: metadata.software,
            removedWhen: currentOptions.removeAll || currentOptions.removeDeviceInfo
        )
        row(
            "Lens Model",
            value: metadata.lensModel,
            removedWhen: currentOptions.removeAll || currentOptions.removeCameraSettings
        )
        row(
            "Focal Length",
            value: metadata.focalLength.map { String(format: "%.1f mm", $0) },
            removedWhen: currentOptions.removeAll || currentOptions.removeCameraSettings
        )
        row(
            "Aperture",
            value: metadata.aperture.map { String(format: "f/%.1f", $0) },
            removedWhen: currentOptions.removeAll || currentOptions.removeCameraSettings
        )
        row(
            "Exposure",
            value: metadata.formattedExposureTime,
            removedWhen: currentOptions.removeAll || currentOptions.removeCameraSettings
        )
        row(
            "ISO",
            value: metadata.iso.map { String(format: "%.0f", $0) },
            removedWhen: currentOptions.removeAll || currentOptions.removeCameraSettings
        )

        rows.append(
            DiffRow(
                field: "Orientation",
                originalValue: metadata.orientation.map { "\($0)" } ?? "Not found",
                status: metadata.orientation != nil ? .retained : .notPresent
            )
        )

        return rows
    }
}
