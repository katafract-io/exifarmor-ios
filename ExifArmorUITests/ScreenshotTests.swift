import XCTest

@MainActor
class ScreenshotTests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        app = nil
    }

    // MARK: - Test 1: Home with marketplace photos (preview state)
    func test01_homeMarketplacePhotos() throws {
        let app = launchApp(args: [
            "--screenshots",
            "--skip-onboarding",
            "--mock-subscribed",
            "--seed-data", "marketplace"
        ])

        // Wait for the ExifArmor nav title to appear
        let navBar = app.navigationBars["ExifArmor"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5), "Navigation bar with 'ExifArmor' title should exist")

        snapshot("01-home-marketplace-photos")
    }

    // MARK: - Test 2: Metadata exposure view (showing GPS/device/timestamp)
    func test02_metadataExposure() throws {
        let app = launchApp(args: [
            "--screenshots",
            "--skip-onboarding",
            "--mock-subscribed",
            "--seed-data", "marketplace"
        ])

        // Wait for nav to appear
        let navBar = app.navigationBars["ExifArmor"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        // Tap the first photo card to open details
        let firstPhotoButton = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "photo-card")).element(boundBy: 0)
        if firstPhotoButton.exists {
            firstPhotoButton.tap()
            // Wait for metadata text (GPS or Location) to appear
            let metadataText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "GPS", "Location")).element(boundBy: 0)
            XCTAssertTrue(metadataText.waitForExistence(timeout: 5), "Metadata exposure view should show GPS/Location")
        }

        snapshot("02-metadata-exposure")
    }

    // MARK: - Test 3: Strip options sheet (Custom Strip chooser)
    func test03_stripOptions() throws {
        let app = launchApp(args: [
            "--screenshots",
            "--skip-onboarding",
            "--mock-subscribed",
            "--seed-data", "marketplace"
        ])

        let navBar = app.navigationBars["ExifArmor"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        // Tap "Custom Strip" specifically — "Strip All Metadata" shows a confirm sheet, not the options sheet
        let customStripButton = app.buttons.matching(
            NSPredicate(format: "label CONTAINS[c] 'Custom'")
        ).firstMatch
        if customStripButton.waitForExistence(timeout: 4) {
            customStripButton.tap()
            let optionLabel = app.staticTexts.matching(
                NSPredicate(format: "label CONTAINS[c] 'Remove'")
            ).firstMatch
            XCTAssertTrue(optionLabel.waitForExistence(timeout: 5), "Strip options sheet should appear with 'Remove' section")
        }

        snapshot("03-strip-options")
    }

    // MARK: - Test 4: Stripping in progress (frozen at ~65%)
    func test04_strippingProgress() throws {
        // marketplace-stripping preset sets phase = .stripping with processedCount 2/4
        // and currentItemProgress 0.6 — renders KataProgressRing at ~65% deterministically
        let app = launchApp(args: [
            "--screenshots",
            "--skip-onboarding",
            "--mock-subscribed",
            "--seed-data", "marketplace-stripping"
        ])

        let navBar = app.navigationBars["ExifArmor"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))
        sleep(1)

        snapshot("04-stripping-progress")
    }

    // MARK: - Test 5: Clean result with metadata diff (0 fields remaining)
    func test05_cleanResult() throws {
        let app = launchApp(args: [
            "--screenshots",
            "--skip-onboarding",
            "--mock-subscribed",
            "--seed-data", "marketplace-stripped"
        ])

        let navBar = app.navigationBars["ExifArmor"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        // Verify the clean result is displayed (look for success/completion indicator)
        let cleanText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@ OR label CONTAINS[c] %@", "Clean", "Removed")).element(boundBy: 0)
        XCTAssertTrue(cleanText.waitForExistence(timeout: 5), "Result summary should show cleaned metadata")

        snapshot("05-clean-result")
    }

    // MARK: - Test 6: Pro upgrade view (paywall)
    func test06_proUpgrade() throws {
        let app = launchApp(args: [
            "--screenshots",
            "--skip-onboarding",
            "--mock-unsubscribed",
            "--mock-prices",
            "--seed-data", "marketplace"
        ])

        let navBar = app.navigationBars["ExifArmor"]
        XCTAssertTrue(navBar.waitForExistence(timeout: 5))

        // Tap the Pro/Upgrade button to show paywall
        let proButton = app.buttons.matching(NSPredicate(format: "label CONTAINS[c] 'Pro' OR label CONTAINS[c] 'Upgrade'")).element(boundBy: 0)
        if proButton.exists {
            proButton.tap()
            // Wait for price text to appear (e.g., $0.99)
            let priceText = app.staticTexts.matching(NSPredicate(format: "label CONTAINS[c] %@", "$")).element(boundBy: 0)
            XCTAssertTrue(priceText.waitForExistence(timeout: 5), "Paywall with pricing should appear")
        }

        snapshot("06-pro-upgrade")
    }
    @discardableResult
    private func launchApp(args: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = args
        setupSnapshot(app)
        app.launch()
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 30),
            "App did not reach foreground within 30s — aborting to avoid silent 0-PNG run"
        )
        return app
    }
}