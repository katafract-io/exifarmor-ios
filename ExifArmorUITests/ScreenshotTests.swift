import XCTest

/// 8-frame App Store screenshot capture for ExifArmor.
/// Each lane launches with `--screenshots --skip-onboarding --seed-data marketplace`
/// plus a per-frame `--seed-frame <id>` that drives `MockDataSeeder` to land
/// the UI in the correct state. Re-run with `bundle exec fastlane screenshots`
/// from the repo root.
@MainActor
class ScreenshotTests: XCTestCase {

    private let baseArgs = [
        "--screenshots",
        "--skip-onboarding",
        "--seed-data", "marketplace",
        "--mock-subscribed",
        "--mock-prices",
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func launchApp(frame: String, extraArgs: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = baseArgs + ["--seed-frame", frame] + extraArgs
        setupSnapshot(app)
        app.launch()
        // Allow SwiftUI animations to settle before any tap.
        _ = app.wait(for: .runningForeground, timeout: 10)
        return app
    }

    private func waitFor(_ element: XCUIElement, timeout: TimeInterval = 8) {
        _ = element.waitForExistence(timeout: timeout)
    }

    // MARK: - Frame 01 — Gallery (preview phase, top of carousel)
    func test01Gallery() throws {
        let app = launchApp(frame: "01-gallery")
        // ExposurePreviewView renders the carousel + privacy score banner.
        // Wait for any image to appear.
        waitFor(app.images.firstMatch)
        snapshot("01-gallery")
    }

    // MARK: - Frame 02 — Exposure (location/device/datetime cards visible)
    func test02Exposure() throws {
        let app = launchApp(frame: "02-exposure")
        waitFor(app.images.firstMatch)
        // Scroll down to reveal the metadata cards (location → device → date/time).
        app.swipeUp()
        snapshot("02-exposure")
    }

    // MARK: - Frame 03 — Strip Options sheet
    func test03StripOptions() throws {
        let app = launchApp(frame: "03-strip-options")
        waitFor(app.images.firstMatch)
        // Scroll to surface the action buttons, then tap "Custom Strip" to
        // present the StripOptionsSheet.
        app.swipeUp()
        app.swipeUp()
        let customStrip = app.buttons["Custom Strip"]
        if customStrip.waitForExistence(timeout: 6) {
            customStrip.tap()
        } else {
            app.buttons.matching(
                NSPredicate(format: "label CONTAINS[c] %@", "Custom")
            ).firstMatch.tap()
        }
        // Wait for the sheet to surface (Templates section header).
        waitFor(app.staticTexts["Templates"])
        snapshot("03-strip-options")
    }

    // MARK: - Frame 04 — Stripping in progress (mid-batch ring)
    func test04Progress() throws {
        let app = launchApp(frame: "04-progress")
        // The stripping view shows progress text — wait for a digit to appear.
        waitFor(app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS '/'")
        ).firstMatch)
        snapshot("04-progress")
    }

    // MARK: - Frame 05 — Metadata diff (before vs after)
    func test05Diff() throws {
        let app = launchApp(frame: "05-diff")
        // StripResultView shows a "View Full Metadata Report" button.
        let reportButton = app.buttons["View Full Metadata Report"]
        if reportButton.waitForExistence(timeout: 8) {
            reportButton.tap()
        }
        // Wait for the diff sheet to surface.
        waitFor(app.staticTexts["Removed"])
        snapshot("05-diff")
    }

    // MARK: - Frame 06 — Seal success ("Metadata purged.")
    func test06Success() throws {
        let app = launchApp(frame: "06-success")
        // SealSuccessView is presented as a fullScreenCover from HomeView.
        // Give the seal animation time to land.
        sleep(2)
        snapshot("06-success")
    }

    // MARK: - Frame 07 — Privacy report (history + sparkline)
    func test07History() throws {
        let app = launchApp(frame: "07-history")
        // Switch to the Report tab.
        let reportTab = app.tabBars.buttons["Report"]
        if reportTab.waitForExistence(timeout: 6) {
            reportTab.tap()
        }
        waitFor(app.navigationBars["Privacy Report"])
        snapshot("07-history")
    }

    // MARK: - Frame 08 — Pro upgrade ($0.99 unlock)
    func test08Unlock() throws {
        // Override base args for the unlock frame: free tier + price mock.
        let app = XCUIApplication()
        app.launchArguments = [
            "--screenshots",
            "--skip-onboarding",
            "--seed-data", "marketplace",
            "--seed-frame", "08-unlock",
            "--mock-unsubscribed",
            "--mock-prices",
        ]
        setupSnapshot(app)
        app.launch()
        _ = app.wait(for: .runningForeground, timeout: 10)
        // The ProUpgradeView is presented as a sheet by HomeView.onAppear.
        sleep(1)
        snapshot("08-unlock")
    }
}
