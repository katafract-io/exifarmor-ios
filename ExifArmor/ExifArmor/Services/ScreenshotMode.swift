// ScreenshotMode — Katafract per-app screenshot infrastructure (Layer 1)
//
// Activated via launch arguments passed by fastlane snapshot or XCUITest:
//   --screenshots               (master switch — enables all overrides)
//   --mock-subscribed           (force Pro tier active)
//   --mock-unsubscribed         (force free tier — for paywall capture)
//   --skip-onboarding           (bypass onboarding gates)
//   --seed-data <preset>        (pre-populate sample photos with EXIF;
//                                presets: travel, portrait, batch)
//   --mock-prices               (use canonical website prices)
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

    static var seedData: String? {
        guard isActive else { return nil }
        guard let i = args.firstIndex(of: "--seed-data"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }

    private static var args: [String] { ProcessInfo.processInfo.arguments }
}
