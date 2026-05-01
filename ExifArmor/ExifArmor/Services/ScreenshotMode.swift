// ScreenshotMode — Katafract per-app screenshot infrastructure (Layer 1)
//
// Activated via launch arguments passed by fastlane snapshot or XCUITest:
//   --screenshots               (master switch — enables all overrides)
//   --mock-subscribed           (force Pro tier active)
//   --mock-unsubscribed         (force free tier — for paywall capture)
//   --skip-onboarding           (bypass onboarding gates AND splash)
//   --seed-data <preset>        (pre-populate sample photos with EXIF;
//                                presets: travel, portrait, batch, marketplace)
//   --seed-frame <id>           (which screenshot frame to land on:
//                                01-gallery, 02-exposure, 03-strip-options,
//                                04-progress, 05-diff, 06-success,
//                                07-history, 08-unlock)
//   --mock-prices               (use canonical website prices for IAP cards)
//
// Pair with MockDataSeeder.swift which actually injects the seed photos.

import Foundation

enum ScreenshotMode {
    /// Master switch. ALL other flags are no-ops unless this is true.
    static var isActive: Bool { args.contains("--screenshots") }

    static var mockSubscribed: Bool   { isActive && args.contains("--mock-subscribed") }
    static var mockUnsubscribed: Bool { isActive && args.contains("--mock-unsubscribed") }
    static var skipOnboarding: Bool   { isActive && args.contains("--skip-onboarding") }
    static var mockPrices: Bool       { isActive && args.contains("--mock-prices") }

    static var seedData: String? { argValue(after: "--seed-data") }
    static var seedFrame: String? { argValue(after: "--seed-frame") }

    /// Canonical price string for the single $0.99 unlock — ExifArmor uses
    /// `com.katafract.exifarmor.unlock` (set 2026-04-30).
    static var canonicalUnlockPrice: String { "$0.99" }

    private static func argValue(after key: String) -> String? {
        guard isActive else { return nil }
        guard let i = args.firstIndex(of: key), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private static var args: [String] { ProcessInfo.processInfo.arguments }
}
