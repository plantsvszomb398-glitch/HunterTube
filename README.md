# HunterTube iOS starter project

This is a native SwiftUI iOS project foundation for the HunterTube blueprint.

## Included in this build
- Local video import from the iOS Files picker (multi-select supported)
- Private library section protected by device authentication
- Local video playback using AVKit
- Playback speed selection
- Theme Studio with iOS color picker, hue/saturation/brightness controls, and dark appearance toggle
- Storage Guardian showing saved library size and per-file sizes
- Export/share saved video files
- Duplicate-file scanning using SHA-256 file hashes
- Batch selection and deletion
- Video information inspector
- Storage forecast calculator
- Import troubleshooting guide
- Library-index backup export
- Local library metadata persistence

## Open and build
1. Unzip the project on a Mac.
2. Open `HunterTube.xcodeproj` in Xcode.
3. Select an iPhone simulator or connected iPhone.
4. Choose your Apple development team under Signing & Capabilities.
5. Build and run.

## Important limitations
This is a starter implementation, not a finished YouTube client or signed IPA. It does not include YouTube account access, streaming feeds, ad removal, or downloading from YouTube. It manages videos the user imports and has rights to use. A signed IPA requires Xcode and Apple signing on macOS.

Still planned for later development: in-app compression, trimming/merging, full video metadata editing, automatic scheduled backups, custom icon packs, and saved theme presets. Backup export currently exports the library index, not the video media files.
