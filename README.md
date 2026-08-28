# PhotoOrganizer

A small macOS app that tidies a folder of photos copied from a camera card
(e.g. a Fujifilm X100VI via Image Capture) into per-day subfolders.

## Workflow

1. Use **Image Capture** to copy everything from the SD card into a folder on your Mac.
2. Open PhotoOrganizer and drop that folder onto the sidebar (or click **Choose Folder…**).
3. The preview table shows, for every file, its EXIF date taken, where it will go, and why (or why not).
4. Press **Go**. Nothing on disk changes before that.

## The operation: *Move into date folders*

Each image is moved into a `YYYY-MM-DD/` subfolder of the chosen folder, named from the
photo's EXIF **DateTimeOriginal** (falling back to DateTimeDigitized, then the TIFF DateTime).
Filenames are never changed.

Policies, deliberately conservative:

- **Camera-local date.** The date is taken verbatim from the EXIF string; it is never converted
  through a time zone, so a 23:30 shot stays on the day the camera says it was taken.
- **Never overwrite.** If `YYYY-MM-DD/<name>` already exists, the file is skipped and left in place
  (checked when planning and again immediately before each move).
- **No EXIF date → skipped.** No silent fallback to file-system dates (copies alter those).
- **Top level only.** Subfolders are not scanned, so running the app twice on the same folder is
  safe: files already in `YYYY-MM-DD/` folders are never touched.
- **Any image ImageIO can read** is handled (JPG, HIF/HEIF/HEIC, RAF, DNG, TIFF, PNG…). Other files
  (`.MOV`, `.XMP`, text…) are listed as "Not an image" and left alone. Hidden files, symlinks,
  aliases and packages are ignored.

## Film simulation bracketing

Some cameras (e.g. Fujifilm's *film simulation bracketing*) write several files per shutter press,
one per film simulation. Turn on **Detect bracketed sets** in the sidebar and each member of a set
is filed one level deeper, into a subfolder of the date folder named for its film simulation:
`2026-07-15/provia/`, `2026-07-15/astia/`, `2026-07-15/acros/`… When a member's simulation can't
be read (or two members would share a name) that member falls back to its position in the set:
`2026-07-15/set2/`. Photos that aren't part of a set stay directly in `2026-07-15/`.

How sets are found — nothing to configure:

- Files of one press share their EXIF date-time **and** sub-second timestamp (and file type).
  Walking the files in filename order, runs with identical values are the candidate sets.
- The most common run length on the card is the detected **photos per press** (shown in the
  sidebar, e.g. "Detected: 3 per press, 881 complete sets").
- Only runs of exactly that length become sets. Everything else — single shots, a press with a
  deleted frame, an odd-sized run — is filed directly into `YYYY-MM-DD/` and marked "none" in the
  **Set** column, so nothing is silently mis-filed.
- The preview shows a **thumbnail** (click it for a sharp 512 px preview) and the camera's
  **film simulation** (best effort, e.g. Provia / Astia / Acros) per row. For `setN` fallback
  folders the sidebar shows the dominant simulation and says "mixed" if several would land there.
- Organised folders are never nested again. Dropping a date folder (`…/2026-07-15`) with detection
  on splits the photos of that date into its simulation subfolders (`provia/`, `astia/`…); photos
  already inside a simulation subfolder (`…/2026-07-15/acros`) are reported as "Already in place".
- Limitations: detection relies on sub-second timestamps (cameras that don't write them may
  confuse bursts with sets — check the preview), and a filename rollover (`DSCF9999` →
  `DSCF0001`) inside one press splits that press into unassigned singles.

## Building

The project is a plain Xcode project (`PhotoOrganizer.xcodeproj`, macOS 15+, Swift 6). Open it in
Xcode and press Run, or from the terminal:

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
xcodebuild -project PhotoOrganizer.xcodeproj -scheme PhotoOrganizer -configuration Debug -derivedDataPath build build
xcodebuild -project PhotoOrganizer.xcodeproj -scheme PhotoOrganizer -destination 'platform=macOS' -derivedDataPath build test
open build/Build/Products/Debug/PhotoOrganizer.app --args -folder ~/Pictures/card   # optional: open a folder at launch
```

## Code map

- `PhotoOrganizer/Core/` — pure, testable logic: `ExifDate` (parsing), `ImageMetadataReader` (ImageIO: date,
  sub-second, film simulation), `FolderScanner` (listing + concurrent metadata read), `BracketSetAssigner`
  (set detection), `OrganizeOperation` + `MoveIntoDateFoldersOperation` (planning), `ThumbnailLoader`,
  `ChangeExecutor` (the only code that writes to disk).
- `PhotoOrganizer/Model/OrganizerModel.swift` — `@Observable` state machine driving the window.
- `PhotoOrganizer/Views/` — `NavigationSplitView` with the sidebar (drop zone, operation picker) and the preview pane.
- `PhotoOrganizerTests/` — Swift Testing suites; fixtures are tiny JPEG/HEIC files generated on the fly.

## Adding an operation

Write a new type conforming to `OrganizeOperation` (`plan(files:in:options:)` must be pure and
returns a `PlanResult`) and add it to `OrganizeOperations.all`. The picker, preview and executor
need no changes; `OrganizeOptions` carries the user-selectable settings (currently bracket-set
detection).

## Sandbox

The app runs without App Sandbox (hardened runtime on). To sandbox it later, enable
`ENABLE_APP_SANDBOX` + user-selected read/write in the target and add security-scoped bookmark
handling in `OrganizerModel.setFolder` — that is the only place folder access is established.
