# ExifArmor — TestFlight & Submission Checklist

## Pre-Flight: Xcode Project

- [ ] Bundle ID set: `com.katafract.exifarmor` (match App Store Connect)
- [ ] Version: `1.2.0` / Build: `11`
- [ ] Deployment target: iOS 17.0
- [ ] All placeholder strings replaced (search for placeholder strings):
  - `StoreManager.proProductID` → `com.katafract.ExifArmor.Pro`
  - `PrivacyReportManager.appGroupID` → `group.com.katafract.exifarmor`
  - `ShareViewController.appGroupID` → `group.com.katafract.exifarmor`
- [ ] App Group created in Apple Developer portal and enabled on both targets
- [ ] StoreKit Configuration removed from scheme (Run → Options → StoreKit Configuration → None)
  - Keep the `.storekit` file in the project for Simulator testing
- [ ] App icon present in Assets.xcassets (1024×1024)
- [ ] All 9 color sets present in Assets.xcassets
- [ ] All image sets present (onboarding, empty states, badges)

## Pre-Flight: App Store Connect

- [ ] App created in App Store Connect with matching bundle ID
- [ ] In-App Purchase created:
  - Type: Non-Consumable
  - Reference Name: `Pro Unlock`
  - Product ID: `com.katafract.ExifArmor.Pro`
  - Price: $3.99 (Tier 4)
  - Display Name: `ExifArmor Pro`
  - Description: `One-time Pro unlock for unlimited strips, premium share extension, batch mode, custom strip options, and privacy report`
  - Review screenshot: screenshot of the Pro upgrade screen
  - Status: Ready to Submit
- [ ] Privacy Policy URL set: `https://katafract.com/privacy/exifarmor`
- [ ] Support URL set: `https://katafract.com/support/exifarmor`

## Pre-Flight: Privacy & Compliance

- [ ] Privacy policy page hosted at `https://katafract.com/privacy/exifarmor`
- [ ] App Privacy Nutrition Label filled out in App Store Connect:
  - Data Not Collected (select this option)
- [ ] `ITSAppUsesNonExemptEncryption` set to `NO` in Info.plist (already done)
- [ ] Export Compliance: No (app uses no encryption beyond HTTPS)

## Build & Archive

- [ ] Select "Any iOS Device" as build target
- [ ] Product → Archive
- [ ] Validate archive (fixes common issues before uploading)
- [ ] Distribute App → App Store Connect → Upload
- [ ] Wait for build processing (5–15 minutes)

## TestFlight Testing

### Release Sanity
- [ ] Install the TestFlight build on a physical iPhone
- [ ] App launches cleanly on first open
- [ ] No unexpected permission prompts appear before the user starts an action
- [ ] App works with airplane mode enabled after install

### Onboarding
- [ ] First launch shows onboarding
- [ ] Skip and completion both land on the main app
- [ ] Second launch does not show onboarding again
- [ ] Replay Onboarding from Settings works

### Core Strip Flow
- [ ] Photo picker opens and returns selected photos
- [ ] A geotagged photo shows metadata and map preview
- [ ] A screenshot or metadata-light image still loads without crashing
- [ ] "Strip All" creates a cleaned copy successfully
- [ ] Cleaned photo saves to the library
- [ ] Shared/exported cleaned photo has metadata removed when checked in another EXIF viewer

### Free Tier Behavior
- [ ] Non-Pro users see remaining free strips count
- [ ] Counter decreases after successful strips
- [ ] Paywall appears once the free limit is reached
- [ ] Batch selection respects the current free-limit rules

### Pro Purchase And Restore
- [ ] Upgrade screen loads and shows the correct price from App Store Connect
- [ ] Purchase completes with a sandbox/TestFlight tester account
- [ ] After purchase, free-limit messaging disappears
- [ ] Pro-only features unlock without reinstalling the app
- [ ] Restore Purchase works on a fresh install or second device
- [ ] Pro status still appears after killing and relaunching the app

### Pro Features
- [ ] Batch mode allows larger selections for Pro users
- [ ] Custom strip sheet opens and applies the selected options
- [ ] Share extension is available from the Photos share sheet
- [ ] Share extension strips metadata and saves the result correctly

### Privacy Report
- [ ] Fresh install shows an empty report state
- [ ] Report counters increase after successful strips
- [ ] Badge/progress state updates correctly after new activity

### Offline Promise
- [ ] Core strip flow works with networking disabled
- [ ] Purchase state persists locally after successful unlock
- [ ] No app feature besides StoreKit purchase/restore depends on a web service

### Final Regression Sweep
- [ ] Version/build shown in Settings matches the uploaded build
- [ ] Dark UI renders correctly on supported iPhone sizes
- [ ] Backgrounding and returning during a strip does not corrupt the workflow
- [ ] Denied photo-library access shows a graceful error path
- [ ] No obvious crashes, freezes, or stuck loading states during normal use

## App Store Submission

- [ ] All TestFlight tests pass
- [ ] App Store screenshots uploaded (see below)
- [ ] App Store listing copy pasted from LISTING.md
- [ ] Keywords set (100 char max)
- [ ] Age rating set to 4+
- [ ] Category: Utilities (primary), Photography (secondary)
- [ ] Review notes for Apple:
  ```
  ExifArmor strips photo metadata (EXIF data) to protect user privacy.
  The app processes all photos on-device and does not depend on a custom backend.
  To test: select any photo from the library, view the exposure preview
  showing metadata like GPS coordinates, then tap "Strip All" to create
  a clean copy. The $3.99 one-time Pro unlock adds unlimited strips,
  the premium share extension, batch mode, custom strip options,
  and privacy report progress.
  ```
- [ ] Submit for review

---

## App Store Screenshots

### Required Sizes
| Device | Resolution | Required |
|---|---|---|
| iPhone 6.7" (15 Pro Max) | 1290 × 2796 | Yes |
| iPhone 6.5" (11 Pro Max) | 1242 × 2688 | Yes |
| iPad Pro 12.9" (6th gen) | 2048 × 2732 | Only if universal |

### Screenshot Sequence (5-6 screens)

**Screenshot 1: "Your photos are talking"**
- Show the exposure preview for a geotagged photo
- GPS pin visible on the mini-map
- Privacy score banner showing "HIGH RISK"
- Caption overlay: "See what your photos reveal"

**Screenshot 2: "One tap to silence them"**
- Before/after: left side shows metadata, right shows "All Clear"
- The strip action button prominently visible
- Caption overlay: "One tap to strip metadata"

**Screenshot 3: "Share from anywhere"**
- iOS share sheet with "Strip Metadata" extension highlighted
- Show it being used from Messages or another app
- Caption overlay: "Strip from any app"

**Screenshot 4: "Batch clean"**
- Photo grid with multiple photos selected
- Progress indicator showing batch processing
- Caption overlay: "Clean dozens of photos at once"

**Screenshot 5: "Your privacy, tracked"**
- Privacy report screen with the hero number, badges, streak
- Caption overlay: "Track your protection"

**Screenshot 6 (optional): "No internet. No data. No compromise."**
- Settings screen showing the privacy statement
- Or a simple graphic reinforcing the no-network promise
- Caption overlay: "100% on-device"

### How to Capture
1. Run the app in Simulator on iPhone 15 Pro Max (6.7")
2. Use test photos WITH GPS metadata for screenshots 1-2
3. `Cmd + S` to save simulator screenshot
4. Frame in Figma/Canva with device bezels and captions
5. Export at exact resolution
