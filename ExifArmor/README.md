# ExifArmor

ExifArmor is a privacy-focused iPhone app for inspecting and removing metadata from photos and videos before you share them.

It exists for a simple reason:

- many people do not realize how much location and device data media files carry
- privacy tools should be inspectable
- useful privacy software still needs a sustainable distribution model

ExifArmor is open source because privacy software should be auditable.

ExifArmor is also sold on the App Store because most people want a signed, maintained, ready-to-use build, and because paid distribution helps fund continued work on open source, privacy-driven software.

In short:

- GitHub is for transparency, source access, and contribution
- the App Store is for the polished consumer build

## Why This Is Open Source And Also Paid

That combination is intentional.

Open source matters here because:

- people should be able to inspect whether the app really keeps media on-device
- privacy claims should be verifiable, not marketing copy
- developers and researchers should be able to audit the implementation

The paid App Store build also matters because:

- most users do not want to compile their own iPhone apps
- signed App Store distribution is simpler and safer for normal users
- support, maintenance, testing, StoreKit, release engineering, and App Review all take real time
- funding privacy tools directly is better than funding them through ads, tracking, or data collection

Buying the App Store version is not paying for secrecy. It is paying for distribution, maintenance, updates, support, and continued development of a privacy-first product.

## What The App Does

ExifArmor can analyze media for:

- GPS location
- creation date and time
- device make and model
- software tags
- camera settings
- video metadata such as location, recording date, and device tags

It can then create cleaned copies without touching the original file.

Current capabilities include:

- photo metadata inspection
- video metadata inspection
- selective stripping templates
- before/after metadata report view
- Live Photo awareness
- batch processing
- share-ready cleaned exports
- local-only privacy report tracking

## Privacy Model

ExifArmor is designed around a strict local-first rule set:

- no custom backend
- no cloud sync
- no analytics SDKs
- no photo uploads
- no third-party dependencies

All media processing happens on-device.

The only network-adjacent behavior is Apple-managed commerce when using StoreKit for purchases and tips.

## Open Source Vs App Store Build

This repository contains the source code for ExifArmor.

The App Store/TestFlight app is:

- signed by the developer account
- compiled and distributed by Apple
- the easiest way for most people to use the app

The open-source repository is for:

- transparency
- auditing the privacy model
- local builds
- contributions and experimentation

If you want the easiest experience, use the App Store build.

If you want to inspect, audit, modify, or locally build the app, use this repository.

These two channels serve different needs and are meant to coexist.

## Tech Stack

- Swift
- SwiftUI
- Observation (`@Observable`)
- ImageIO for photo metadata reads/writes
- AVFoundation for video metadata reads/writes
- StoreKit 2 for purchases
- UserDefaults and App Groups for local persistence

Minimum target:

- iOS 17+

## Project Structure

```text
ExifArmor/
├── ExifArmor/
│   ├── App/
│   ├── Extensions/
│   ├── Models/
│   ├── Services/
│   ├── ViewModels/
│   └── Views/
├── ExifArmorTests/
├── ExifArmorUITests/
├── ExifArmorShareExtension/
├── AppStore/
└── StoreKitConfig/
```

Important areas:

- [ExifArmorApp.swift](./ExifArmor/ExifArmor/App/ExifArmorApp.swift): app entry point
- [PhotoStripViewModel.swift](./ExifArmor/ExifArmor/ViewModels/PhotoStripViewModel.swift): main media workflow
- [MetadataService.swift](./ExifArmor/ExifArmor/Services/MetadataService.swift): photo metadata extraction
- [StripService.swift](./ExifArmor/ExifArmor/Services/StripService.swift): photo metadata stripping
- [VideoMetadataService.swift](./ExifArmor/ExifArmor/Services/VideoMetadataService.swift): video metadata extraction
- [VideoStripService.swift](./ExifArmor/ExifArmor/Services/VideoStripService.swift): video metadata stripping
- [ShareViewController.swift](./ExifArmorShareExtension/ShareViewController.swift): share extension

## Building From Source

Requirements:

- Xcode 16 or newer
- iOS 17 SDK
- an Apple Developer account if you want to run on device or test StoreKit and extension flows fully

Basic setup:

1. Open the project in Xcode.
2. Configure your signing team for the app and share extension.
3. Confirm the App Group matches your developer account setup.
4. Attach the local StoreKit config if you want Simulator purchase testing.
5. Build and run on Simulator or device.

StoreKit config file:

- [ExifArmorProducts.storekit](./ExifArmorProducts.storekit)

## Distribution Notes

This repository may move faster than the App Store release.

That means:

- GitHub can contain features or fixes not yet available in the public build
- the App Store build can have a higher review and stability bar
- TestFlight builds may temporarily lead or trail `main`

## Support The Project

If you value open source privacy tools, the most direct ways to support ExifArmor are:

- buy the App Store version
- use the tip jar in the app
- report bugs clearly
- contribute code or review
- share the project with people who care about on-device privacy

The business model is intentionally straightforward: paid software, transparent code, no surveillance.

## Contributing

Contributions are welcome, but the project has a few non-negotiable constraints:

- preserve the on-device privacy model
- do not add third-party SDKs
- do not add cloud sync
- do not add general networking for media processing
- use ImageIO for image metadata I/O
- keep temporary files cleaned up after processing

If a change weakens the privacy promise, it is out of scope.

## License

No license file is currently included in this repository.

That means the source is visible, but reuse rights are not yet formally granted beyond standard GitHub viewing/fork mechanics. Add a license if you want to permit broader reuse.
