# ExifArmor Screenshots Runbook

## Overview

ExifArmor screenshots are captured via fastlane snapshot tests and automatically framed with device bezels + marketing banners on every push to `main`. The workflow captures 6 key moments from the app's value prop arc and applies custom banners that speak to the user's outcome, not the feature.

## Running Screenshots Locally

```bash
# Capture screenshots (output: fastlane/screenshots/en-US/)
bundle exec fastlane screenshots

# Capture + frame with device bezels + banners
bundle exec fastlane screenshots
bundle exec fastlane frameit silver --path fastlane/screenshots
```

The framed output writes `*_framed.png` files alongside originals.

## Files

| File | Purpose |
|---|---|
| `ExifArmorUITests/ScreenshotTests.swift` | 6 UI tests seeding marketplace scenarios (photo cards, EXIF exposure, strip options, progress, clean result, paywall) |
| `fastlane/Snapfile` | snapshot device list (iPhone 17 Pro Max, iPad Pro 13"), languages, launch args |
| `fastlane/Framefile.json` | frameit config: title font (Helvetica Bold, cyan #00F0FF), background (navy #0B0C12), per-frame banners |
| `fastlane/screenshots/en-US/title.strings` | banner captions (top title + bottom caption per frame) |
| `.github/workflows/screenshots.yml` | CI: capture + frame → upload to ASC (no binary) |

## Banner Captions — The Story Arc

Each frame's banner speaks to a step in the user's journey:

| Frame | Banner (top) | Caption (bottom) |
|---|---|---|
| 01-home-marketplace-photos | Selling something online? They can see more than the photo. | Your marketplace listing photos contain GPS, device details, and timestamps. Buyers (or anyone) can extract them. |
| 02-metadata-exposure | GPS. Device. Timestamp. All visible to the buyer. | EXIF metadata travels with every photo. See what's exposed before you share. |
| 03-strip-options | You control what gets removed. | Choose which metadata to strip. All metadata removal is yours to decide. |
| 04-stripping-progress | One tap. Metadata gone. | Strip metadata from one photo or a batch. Process runs instantly on-device. |
| 05-clean-result | Photos shared. Location stripped. | Location, device, and timestamps removed. Share safely without revealing where you are. |
| 06-pro-upgrade | Unlimited strips. Unlimited peace of mind. | Pro ($0.99 one-time) removes limits. Share from any app. Total privacy. |

## Updating Banner Copy

Edit `fastlane/Framefile.json` (top title) or `fastlane/screenshots/en-US/title.strings` (captions), then trigger screenshots.yml workflow via push to main or manual dispatch.

**Style rules (marketing-truth):**
- Lead with the risk story (frame 01) — user must feel the problem in 2 seconds
- Speak the outcome, not the feature — "Photos shared. Location stripped." not "EXIF Stripper Tool"
- Don't claim features not shipped (e.g., no "verified safe" badge without backend reputation lookup)
- Per audit: iOS strips location + device + timestamp (preserves orientation in TIFF dict); Android strips GPS + date + device + camera settings

## Verifying Output

After screenshots.yml completes, check the artifacts:
- `fastlane/screenshots/en-US/*_framed.png` — device-framed versions (what ASC receives)
- Verify each frame shows: app UI centered + device bezel surround + cyan-accented title banner at top + caption text below
- Inspect for font rendering issues, truncated captions, or text overflow (frameit silently skips bad fonts on some systems)

## CI Workflow Notes

The `screenshot run started` → `screenshot run SUCCEEDED`/`FAILED` Matrix messages are dispatched from steps in `.github/workflows/screenshots.yml`. Matrix room routing:
- ✅ Success → `#ci` channel
- 🔴 Failure → both `#ci` and `#alerts`

Screenshot logs committed to `docs-internal/runbooks/screenshot_runs/exifarmor-TIMESTAMP.md` with run number, shot count, and fastlane tail.

## Blocking CI Issues

If frameit step fails silently (no error, no output):
1. Check for missing fonts — Helvetica-Bold may not exist on cmfmbp; fallback to system font like `HelveticaNeue-Bold`
2. Check Snapfile scheme — must match Xcode project scheme name (`ExifArmorScreenshots` for screenshot config)
3. Manual frameit on runner: `cd fastlane/screenshots && fastlane frameit silver --path .`
4. If still failing: document in the issue + skip frameit for that run (graceful exit 0 in workflow allows upload without frames)

## Marketing Story Reference

See `~/.claude/projects/-home-artemis/memory/project_app_marketing_stories_2026_04_29.md` ExifArmor section for the full risk story, promise, and screenshot arc that drives these captions. The "Audit truth" section lists what's shipped vs. aspirational — banner copy must match audit truth.
