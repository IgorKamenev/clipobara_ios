# Clipobara

Clipobara is a private, local clipboard history app for macOS 14 and newer. It runs
as a menu bar utility, records changes to the system pasteboard, and opens a
bottom history panel with `Command-Shift-V` by default.

## Features

- Captures text, rich text, HTML, links, images, files, and unknown pasteboard
  representations.
- Preserves all readable pasteboard representations and restores them together.
- Shows source application icons, relative timestamps, previews, and payload sizes.
- Supports search, mouse selection, arrow keys (including Up/Down), Return, and Escape.
- Always opens at the leftmost/newest clip without a scroll animation.
- Optionally moves a selected clip to the front of history (on by default).
- Supports dragging a clip from the panel straight into another application —
  no permissions required.
- Allows the global history shortcut to be recorded in Settings.
- Stores metadata with SwiftData and large payloads as files in Application Support.
- Deduplicates adjacent copies and enforces configurable item/storage limits.
- Excludes common password managers by default and supports custom bundle IDs.
- Has no networking, analytics, or cloud sync.

Selecting an item makes it the current system clipboard: paste normally in the
destination application with `Command-V`, or skip the clipboard and drag a card
straight into the destination. (An auto-paste mode that synthesizes `Command-V`
exists in the code base but is currently disabled.)

## Build

Requirements:

- macOS 14+
- Xcode 16 or newer
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

Generate and open the project:

```sh
xcodegen generate
open Clipobara.xcodeproj
```

Or build from the command line:

```sh
xcodebuild \
  -project Clipobara.xcodeproj \
  -scheme Clipobara \
  -configuration Debug \
  -destination 'platform=macOS' \
  build
```

The generated Xcode project is committed for convenience. `project.yml` remains
the source of truth for project settings and file membership — never edit
`Clipobara.xcodeproj` directly, the next `xcodegen` run overwrites it.

### Versioning

The version and build number live in `project.yml` (`MARKETING_VERSION` and
`CURRENT_PROJECT_VERSION`). `project.yml` is visible in Xcode's navigator, and a
scheme pre-action runs `xcodegen --use-cache` before every build, so edits to
the spec are picked up automatically. Note that the build that triggers
regeneration may still use the old settings; build once more to apply them.

## Usage

1. Launch Clipobara. A clipboard icon appears in the menu bar.
2. Copy content in any application.
3. Press `Command-Shift-V`.
4. Search or use arrow keys, then click a card or press Return.
5. Paste normally with `Command-V`, or drag a card straight into the
   destination application.

The menu bar provides monitoring pause/resume, history clearing, launch-at-login,
settings, and quit actions. The history shortcut can be changed in Settings. If
another app already owns the selected shortcut, Clipobara keeps the previous shortcut
and shows an error.

## Local data and privacy

SwiftData metadata and payload files are stored under the user's Application
Support container in `Clipobara/Clips`. History never leaves the Mac.

Each representation is limited to 64 MB and one clipboard snapshot to 128 MB.
Defaults retain up to 500 entries and 512 MB. These limits can be changed in
Settings.

Password-manager bundle identifiers are excluded by default. Add other sensitive
applications in Settings before copying confidential content from them.

## Tests

```sh
xcodebuild \
  -project Clipobara.xcodeproj \
  -scheme Clipobara \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  test
```

Unit tests cover hashing, ordering, manifest serialization, selection bounds,
payload persistence, adjacent-copy deduplication, and drag item providing.
Manual release checks should include TextEdit, Safari/Chrome, Finder, Preview,
screenshots, multiple files, large payloads, multiple displays, Spaces,
full-screen apps, restart persistence, drag & drop into other applications,
and shortcut-conflict behavior.

## Distribution

Hardened Runtime and App Sandbox are both enabled for App Store submission.
Neither clip selection nor drag & drop needs any permission. Set your Apple
Developer team, archive, then sign and notarize as needed.
