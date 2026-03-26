# ExifArmor — Xcode Project Setup Guide

## Quick Start (15 minutes)

### 1. Create the Xcode Project

1. Open Xcode → File → New → Project
2. Choose **App** under iOS
3. Settings:
   - **Product Name:** ExifArmor
   - **Team:** Your Apple Developer Team
   - **Organization Identifier:** com.katafract (match what you'll use in App Store Connect)
   - **Interface:** SwiftUI
   - **Language:** Swift
   - **Minimum Deployment:** iOS 17.0
4. Create the project

### 2. Add the Source Files

1. In Xcode's Project Navigator, delete the auto-generated `ContentView.swift`
2. Drag the following folders from this package into the `ExifArmor` group:
   - `App/`
   - `Models/`
   - `Services/`
   - `ViewModels/`
   - `Views/`
   - `Extensions/`
3. When prompted: ✅ Copy items if needed, ✅ Create groups, Target: ExifArmor

### 3. Add the Asset Catalog

Replace the default `Assets.xcassets` with the one from the asset package we built earlier:
1. Delete the default `Assets.xcassets` from the project
2. Drag in `ExifArmor-Xcode/Assets.xcassets` from the asset package
3. Verify it contains: AppIcon, 9 Color Sets, Onboarding/Empty/Badge image sets

### 4. Add the Info.plist

1. Drag `Info.plist` into the ExifArmor group
2. In Build Settings → search "Info.plist File" → set to `ExifArmor/Info.plist`
3. This includes photo library permission strings and launch screen config

### 5. Set Up the Share Extension

1. File → New → Target → **Share Extension**
2. Product Name: `ExifArmorShareExtension`
3. Delete the auto-generated files in the new target
4. Drag in the files from `ExifArmorShareExtension/`:
   - `ShareViewController.swift`
   - `Info.plist`
5. In the extension's Build Settings, set its Info.plist path

### 6. Configure App Groups

Both the main app and share extension need to share data:

1. Select the **ExifArmor** target → Signing & Capabilities → + Capability → App Groups
2. Add: `group.com.katafract.exifarmor`
3. Select the **ExifArmorShareExtension** target → same steps → same group ID
4. Update the `appGroupID` string in `PrivacyReportManager.swift` and `ShareViewController.swift` to match

### 7. Configure StoreKit

1. Drag `StoreKitConfig/ExifArmorProducts.storekit` into the project
2. Edit Scheme → Run → Options → StoreKit Configuration → select `ExifArmorProducts.storekit`
3. This enables testing purchases in the Simulator without App Store Connect

**Before submitting to App Store Connect:**
- Create the product `com.katafract.ExifArmor.Pro` as a Non-Consumable IAP
- This is a $3.99 one-time unlock for unlimited strips, the premium share extension, batch mode, custom strip options, and privacy report progress
- Update `StoreManager.proProductID` if you use a different product ID
- Remove the StoreKit configuration from the scheme (it overrides real products)

### 8. Update Bundle Identifiers

Search and replace these placeholder values across the project:

| Placeholder | Replace With |
|---|---|
| `com.katafract.exifarmor` | Your actual bundle ID |
| `com.katafract.ExifArmor.Pro` | Your IAP product ID |
| `group.com.katafract.exifarmor` | Your App Group ID |
| `YOUR_TEAM_ID` | Your Apple Developer Team ID |

---

## Project Structure

```
ExifArmor/
├── App/
│   ├── ExifArmorApp.swift          # Entry point, onboarding gate
│   └── MainTabView.swift            # Tab bar (Strip, Report, Settings)
├── Models/
│   ├── PhotoMetadata.swift          # EXIF data model
│   └── StripOptions.swift           # Strip configuration + StripResult
├── Services/
│   ├── MetadataService.swift        # Reads EXIF via ImageIO
│   ├── StripService.swift           # Creates clean copies via ImageIO
│   ├── StoreManager.swift           # StoreKit 2 IAP ($3.99 one-time Pro unlock)
│   ├── PrivacyReportManager.swift   # Lifetime stats (App Group shared)
│   ├── FreeTierManager.swift        # 5 strips/day gating
│   └── AnalyticsLogger.swift        # On-device conversion funnel tracker
├── ViewModels/
│   └── PhotoStripViewModel.swift    # Core workflow: pick → analyze → strip
├── Views/
│   ├── HomeView.swift               # Main screen + photo picker
│   ├── ExposurePreviewView.swift    # "What your photo reveals" with map
│   ├── StripResultView.swift        # Success screen + save/share
│   ├── StripOptionsSheet.swift      # Custom strip category picker
│   ├── PrivacyReportView.swift      # Gamified stats + badges
│   ├── OnboardingView.swift         # 3-page intro
│   ├── ProUpgradeView.swift         # IAP purchase screen
│   ├── SettingsView.swift           # Settings + restore purchase
│   ├── AnalyticsDebugView.swift     # DEBUG: conversion funnel viewer
│   └── Components/
│       └── MetadataCard.swift       # Reusable metadata display card
├── Extensions/
│   └── Color+Theme.swift            # Fallback colors + palette reference
├── Info.plist
│
├── ExifArmorShareExtension/
│   ├── ShareViewController.swift    # Premium share extension (clean, then share onward)
│   └── Info.plist
│
└── StoreKitConfig/
    └── ExifArmorProducts.storekit  # Local IAP testing config
```

---

## Key Architecture Decisions

1. **Never modify originals.** `StripService` creates a new image via `CGImageDestination` — zero quality loss, original untouched.

2. **No networking.** The app never makes network calls. The analytics logger stores everything in UserDefaults on-device.

3. **StoreKit 2 native.** Single non-consumable product. Transactions are cryptographically verified on-device by Apple's JWS signing. No server-side receipt validation needed.

4. **App Group sharing.** The privacy report counter is shared between the main app and share extension via `UserDefaults(suiteName:)`.

5. **@Observable (iOS 17+).** All state managers use the Observation framework instead of ObservableObject/Published for cleaner code and better performance.

---

## Analytics Funnel

The `AnalyticsLogger` tracks this conversion funnel entirely on-device:

```
App Launch → Onboarding → Photos Selected → Exposure Preview → Strip → Paywall → Purchase
```

View the funnel in DEBUG builds: Settings → Analytics Debug

Export as JSON for your own analysis.

---

## Testing Checklist

- [ ] Photo picker loads and selections work
- [ ] EXIF data displays correctly (test with a photo that has GPS)
- [ ] Map pin appears for geotagged photos
- [ ] Strip creates a clean copy (verify no EXIF in saved photo)
- [ ] Free tier blocks after 5 strips
- [ ] StoreKit purchase flow works (use StoreKit config)
- [ ] Premium share extension appears in share sheet for Pro users
- [ ] Premium share extension strips metadata and can share the clean copy onward
- [ ] Privacy report increments correctly
- [ ] Onboarding shows on first launch, can be replayed from Settings
- [ ] Analytics debug shows funnel events
