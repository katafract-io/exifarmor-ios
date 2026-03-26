import AppIntents
import UniformTypeIdentifiers

// MARK: - Strip Mode Enum

/// Maps the app's three StripOptions presets to an AppEnum for use in Shortcuts and Siri.
enum StripModeAppEnum: String, AppEnum {
    case all
    case locationOnly
    case privacyFocused

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Strip Mode"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] = [
        .all: DisplayRepresentation(
            title: "Full Strip",
            subtitle: "Remove all metadata"
        ),
        .locationOnly: DisplayRepresentation(
            title: "Location Only",
            subtitle: "Remove GPS data only"
        ),
        .privacyFocused: DisplayRepresentation(
            title: "Privacy Focused",
            subtitle: "Remove location, date, and device info"
        ),
    ]

    var stripOptions: StripOptions {
        switch self {
        case .all:            return .all
        case .locationOnly:   return .locationOnly
        case .privacyFocused: return .privacyFocused
        }
    }
}

// MARK: - Intent

/// An AppIntent that strips metadata from photos. Surfaces in Shortcuts, Siri, and Spotlight.
/// Users can invoke this directly ("Hey Siri, strip metadata with ExifArmor") or build
/// Shortcuts workflows that auto-clean photos before sharing.
struct StripPhotoMetadataIntent: AppIntent {
    static var title: LocalizedStringResource = "Strip Photo Metadata"
    static var description = IntentDescription(
        "Remove metadata from photos using ExifArmor. Returns clean copies without modifying your originals. All processing happens on-device — no data leaves your phone.",
        categoryName: "Privacy"
    )

    @Parameter(title: "Photos")
    var photos: [IntentFile]

    @Parameter(title: "Strip Mode", default: .all)
    var mode: StripModeAppEnum

    static var parameterSummary: some ParameterSummary {
        Summary("Strip metadata from \(\.$photos) using \(\.$mode)")
    }

    func perform() async throws -> some IntentResult & ReturnsValue<[IntentFile]> & ProvidesDialog {
        let options = mode.stripOptions
        var results: [IntentFile] = []

        for photo in photos {
            guard let url = photo.fileURL,
                  let data = try? Data(contentsOf: url)
            else { continue }

            guard let cleanedData = await MainActor.run(
                body: { StripService.stripMetadata(from: data, options: options) }
            ) else { continue }

            let ext = photo.type?.preferredFilenameExtension
                ?? url.pathExtension.lowercased()
            let filename = "ExifArmor_\(UUID().uuidString.prefix(8)).\(ext.isEmpty ? "jpg" : ext)"
            let outURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try cleanedData.write(to: outURL)
            results.append(IntentFile(fileURL: outURL, filename: filename, type: photo.type ?? .jpeg))
        }

        let count = results.count
        return .result(
            value: results,
            dialog: "\(count) photo\(count == 1 ? "" : "s") cleaned."
        )
    }
}

// MARK: - App Shortcuts Provider

/// Registers suggested Shortcuts phrases so ExifArmor appears in Siri and Shortcuts
/// without the user needing to manually discover it.
struct ExifArmorShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StripPhotoMetadataIntent(),
            phrases: [
                "Strip metadata with \(.applicationName)",
                "Clean photo metadata with \(.applicationName)",
                "Remove location from photos with \(.applicationName)",
                "Strip photos with \(.applicationName)"
            ],
            shortTitle: "Strip Metadata",
            systemImageName: "eye.slash.fill"
        )
    }
}
