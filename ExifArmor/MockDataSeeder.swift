import Foundation
import UIKit

/// Mock data seeder for screenshot mode (`--screenshots --seed-data <preset>`).
///
/// Synthesizes 4 marketplace-style `PhotoMetadata` records from the bundled
/// fixture JPEGs in `Resources/Fixtures/` and pushes them into the supplied
/// `PhotoStripViewModel`. EXIF (GPS coords near a SF residence, iPhone make /
/// model, timestamps spanning 3 weeks) is fabricated in-memory — the JPEGs
/// themselves carry no metadata, no PII, and no geolocation.
///
/// Wired in by `HomeView` when `ScreenshotMode.isActive`, driven by the
/// `--seed-frame <id>` argument to land on the correct UI state for each of
/// the 8 App Store frames.
@MainActor
struct MockDataSeeder {

    // MARK: - Public entry

    /// Seed the supplied view model based on the active screenshot launch args.
    /// No-op when `ScreenshotMode.isActive` is false.
    static func seed(into viewModel: PhotoStripViewModel,
                     report: PrivacyReportManager? = nil) {
        guard ScreenshotMode.isActive else { return }
        guard ScreenshotMode.seedData == "marketplace" else { return }

        // Seed the lifetime privacy stats so frame 07 (Privacy Report) does
        // not render the empty state. Recorded once per launch.
        if let report, report.totalPhotosStripped == 0 {
            // 168 fields removed this week, ~24/day average → seed 24 records.
            for _ in 0..<24 {
                report.recordStrip(photosCount: 4, fieldsRemoved: 7, hadLocation: true)
            }
        }

        let photos = makeMarketplacePhotos()
        viewModel.analyzedPhotos = photos
        viewModel.totalCount = photos.count

        // Drive the phase based on which frame this lane is targeting.
        switch ScreenshotMode.seedFrame {
        case "01-gallery":
            // Gallery grid lives on the .preview phase with all photos visible.
            viewModel.phase = .preview
        case "02-exposure":
            viewModel.phase = .preview
        case "03-strip-options":
            viewModel.phase = .preview
            // ExposurePreviewView opens the strip-options sheet via state;
            // the UITest taps the toolbar to invoke it after the snapshot
            // so we keep the phase at .preview here.
        case "04-progress":
            viewModel.phase = .stripping
            viewModel.processedCount = 2
            viewModel.totalCount = 4
            viewModel.currentItemProgress = 0.55
            viewModel.statusMessage = "Cleaning photo 3 of 4…"
        case "05-diff", "06-success":
            // Pre-populate strip results so MetadataDiffView + SealSuccessView
            // have data to render.
            viewModel.stripResults = makeStripResults(from: photos)
            viewModel.processedCount = photos.count
            viewModel.totalCount = photos.count
            viewModel.phase = .done
        case "07-history", "08-unlock":
            // These frames render Privacy Report / Pro Upgrade (separate tabs /
            // sheets). Keep gallery in preview state in case the back stack is
            // visible behind the modal.
            viewModel.phase = .preview
        default:
            viewModel.phase = .preview
        }

        print("MockDataSeeder: seeded \(photos.count) marketplace photos, frame=\(ScreenshotMode.seedFrame ?? "default")")
    }

    /// Legacy entry-point retained for older call-sites (currently no-op when
    /// no view-model context is available).
    static func seedDataIfNeeded() {
        guard ScreenshotMode.isActive else { return }
        // Real seeding requires a view-model; HomeView drives that on appear.
    }

    // MARK: - Marketplace fixture pool

    private struct FixtureSpec {
        let resourceName: String
        let category: String
        let dateTimeOriginal: String
        let latitude: Double
        let longitude: Double
        let altitude: Double
        let model: String
        let lensModel: String
        let iso: Double
        let exposureTime: Double
        let aperture: Double
        let focalLength: Double
    }

    private static let marketplaceFixtures: [FixtureSpec] = [
        FixtureSpec(
            resourceName: "watch",
            category: "Watch",
            dateTimeOriginal: "2026:04:15 09:42:13",
            latitude: 37.760078,
            longitude: -122.589567,
            altitude: 38.0,
            model: "iPhone 15 Pro",
            lensModel: "iPhone 15 Pro back triple camera 6.86mm f/1.78",
            iso: 64,
            exposureTime: 1.0 / 250.0,
            aperture: 1.78,
            focalLength: 6.86
        ),
        FixtureSpec(
            resourceName: "bike",
            category: "Bike",
            dateTimeOriginal: "2026:03:28 16:03:48",
            latitude: 37.760082,
            longitude: -122.589571,
            altitude: 36.0,
            model: "iPhone 15 Pro",
            lensModel: "iPhone 15 Pro back triple camera 6.86mm f/1.78",
            iso: 100,
            exposureTime: 1.0 / 320.0,
            aperture: 1.78,
            focalLength: 6.86
        ),
        FixtureSpec(
            resourceName: "camera",
            category: "Camera",
            dateTimeOriginal: "2026:04:02 11:18:09",
            latitude: 37.760074,
            longitude: -122.589561,
            altitude: 39.0,
            model: "iPhone 15 Pro",
            lensModel: "iPhone 15 Pro back triple camera 6.86mm f/1.78",
            iso: 80,
            exposureTime: 1.0 / 200.0,
            aperture: 1.78,
            focalLength: 6.86
        ),
        FixtureSpec(
            resourceName: "sofa",
            category: "Sofa",
            dateTimeOriginal: "2026:04:11 14:55:27",
            latitude: 37.760079,
            longitude: -122.589564,
            altitude: 37.0,
            model: "iPhone 15 Pro",
            lensModel: "iPhone 15 Pro back triple camera 6.86mm f/1.78",
            iso: 125,
            exposureTime: 1.0 / 160.0,
            aperture: 1.78,
            focalLength: 6.86
        ),
    ]

    // MARK: - Builders

    private static func makeMarketplacePhotos() -> [PhotoMetadata] {
        marketplaceFixtures.compactMap { spec in
            guard let image = loadFixtureImage(spec.resourceName, category: spec.category),
                  let data = image.jpegData(compressionQuality: 0.85)
            else { return nil }

            return PhotoMetadata(
                image: image,
                imageData: data,
                sourceUTI: "public.jpeg",
                isLivePhoto: false,
                latitude: spec.latitude,
                longitude: spec.longitude,
                altitude: spec.altitude,
                deviceMake: "Apple",
                deviceModel: spec.model,
                software: "iOS 18.1",
                lensModel: spec.lensModel,
                dateTimeOriginal: spec.dateTimeOriginal,
                dateTimeDigitized: spec.dateTimeOriginal,
                focalLength: spec.focalLength,
                aperture: spec.aperture,
                exposureTime: spec.exposureTime,
                iso: spec.iso,
                flash: false,
                pixelWidth: Int(image.size.width),
                pixelHeight: Int(image.size.height),
                colorSpace: "sRGB",
                orientation: 1,
                exifDictionary: [
                    "ISOSpeedRatings": [Int(spec.iso)],
                    "ExposureTime": spec.exposureTime,
                    "FNumber": spec.aperture,
                    "FocalLength": spec.focalLength,
                    "DateTimeOriginal": spec.dateTimeOriginal,
                ],
                gpsDictionary: [
                    "Latitude": spec.latitude,
                    "Longitude": spec.longitude,
                    "Altitude": spec.altitude,
                    "DateStamp": String(spec.dateTimeOriginal.prefix(10)),
                ],
                tiffDictionary: [
                    "Make": "Apple",
                    "Model": spec.model,
                    "Software": "iOS 18.1",
                ]
            )
        }
    }

    private static func makeStripResults(from photos: [PhotoMetadata]) -> [StripResult] {
        photos.map { meta in
            // For screenshot mode, the "cleaned" image is the same image bytes
            // (we don't actually need to re-encode without EXIF for the visual
            // diff — `MetadataDiffView` reads the original metadata's fields
            // and renders them as removed).
            StripResult(
                originalMetadata: meta,
                cleanedImageData: meta.imageData,
                cleanedImage: meta.image,
                fieldsRemoved: 14
            )
        }
    }

    // MARK: - Bundle loader

    private static func loadFixtureImage(_ name: String, category: String) -> UIImage? {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: name, withExtension: "jpg", subdirectory: "Fixtures")
                ?? bundle.url(forResource: name, withExtension: "jpg"),
              let data = try? Data(contentsOf: url),
              let base = UIImage(data: data)
        else {
            print("MockDataSeeder: missing fixture \(name).jpg")
            return nil
        }
        return decorate(base, category: category)
    }

    /// Burn a thin caption ("WATCH", "BIKE", …) onto the gradient background
    /// so each tile reads as a distinct marketplace listing instead of a
    /// solid block of color in the gallery grid.
    private static func decorate(_ image: UIImage, category: String) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))

            let label = category.uppercased()
            let fontSize = max(size.width, size.height) * 0.10
            let attributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .heavy),
                .foregroundColor: UIColor.white.withAlphaComponent(0.92),
                .kern: fontSize * 0.05,
            ]

            let textSize = (label as NSString).size(withAttributes: attributes)
            let origin = CGPoint(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2
            )

            // Subtle drop-shadow for legibility.
            ctx.cgContext.setShadow(
                offset: CGSize(width: 0, height: 2),
                blur: 6,
                color: UIColor.black.withAlphaComponent(0.45).cgColor
            )

            (label as NSString).draw(at: origin, withAttributes: attributes)
        }
    }
}
