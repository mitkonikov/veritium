# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]

### Added

- Added MIT License file.
- Added internal source map and function reference documentation in `docs/` directory.
- Added markdown export from UI and CLI with option to skip images.
- Added embedded CLI export mode in Flutter app entrypoint, enabling Windows binary invocation with `--cli-export`.
- Added reusable shared CLI command module (`lib/cli_export.dart`) used by both `bin/export_markdown.dart` and `lib/main.dart`.
- Added automated CLI checks in test suite (`test/cli_export_test.dart`) and GitHub Actions (Dart CLI + Windows binary smoke tests).
- Added `--original-content` CLI option for exporting original OCR text; default export mode now explicitly prefers `corrected_content` when present.
- Added `--lists-as-text` CLI option for exporting list blocks as plain text (without markdown bullets).

## Release 2.1.0 - 2026-01-14

### Added

- Added `Alt+Left` and `Alt+Right` keyboard shortcuts for navigating to the previous and next items, respectively.
- Added `Ctrl+T` and `Ctrl+Enter` keyboard shortcuts to open the comment dialog and submit the comment, respectively.
- Added `Ctrl+Plus` and `Ctrl+Minus` keyboard shortcuts to increase and decrease the UI scale, respectively.
- Added `Ctrl+G` keyboard shortcut to open the Goto dialog and improved shortcuts inside the dialog.
- All keyboard shortcuts are now listed in the Keyboard Shortcuts dialog.

### Fixed

- Fixed keyboard shortcuts not working when textbox is not selected.

### Improved

- Layout usage on small screens.
- Textbox is focused after loading a file or navigating to a different item.
- Keyboard shortcuts are now handled with a hardware keyboard listener to work anywhere in the app.

### Changed

- Changed font in the correction textbox to Latin Modern Mono for better readability.

## Release 2.0.0 - 2026-01-02

### Breaking Changes
- Flags and comments are now saved in the bounding box data structure instead of in the spans. ([f4b925f](https://github.com/mitkonikov/veritium/commit/f4b925f2061904206d6cceb52346d8277f5c4f14))

### Added
- Support for displaying OCR internal spans. ([bef5599](https://github.com/mitkonikov/veritium/commit/bef55995268198b0e04c4cedb5612e388502441a))
- Support for comments on bounding boxes. ([f4b925f](https://github.com/mitkonikov/veritium/commit/f4b925f2061904206d6cceb52346d8277f5c4f14))
- Add ability to filter only boxes with comments. ([ea5e797](https://github.com/mitkonikov/veritium/commit/ea5e797b9d0c4477773580fba7a1cbe1c977b694))
- Add Goto dialog to jump to a specific item. ([cb40e2d](https://github.com/mitkonikov/veritium/commit/cb40e2d5139197ec677a8bbf83b78fc30a1128a3))
- UI Text & widget scaling (UI Scale) with live slider. ([9a1387b](https://github.com/mitkonikov/veritium/commit/9a1387b9d3aa42b786d310ce2f9fe6fa501b0896))
- Keyboard shortcuts (F7/F8, Ctrl+S, Ctrl+F). ([ac98e66](https://github.com/mitkonikov/veritium/commit/ac98e66eacad60a7d4b36338f8a9e2c317496255))
- Progress bar for loading/rendering PDF files. ([e9e9a13](https://github.com/mitkonikov/veritium/commit/e9e9a1393b52137fa264d351a6186ae44a36ab41))

### Changed
- Save icon now visually indicates unsaved changes. ([b1e32b1](https://github.com/mitkonikov/veritium/commit/b1e32b1f64f1e32f9102003a5e8484ce1634a2a2))
- Binary-search font sizing in correction text field to fit lines. ([330010c](https://github.com/mitkonikov/veritium/commit/330010cd2c2ccf103080d63b90e6dac0bfcf4a52))
- Increased PDF rendering DPI for improved image quality. ([ba48f65](https://github.com/mitkonikov/veritium/commit/ba48f6539ffd27aeccdbf86925bc2a7656eb9c05))

### Refactor
- Separated custom Windows controls into their own widget/file. ([20ae1df](https://github.com/mitkonikov/veritium/commit/20ae1dfeeaa9dd254b7b03bb61ab90266b13a805))
- Add few tests for loading example JSON files. ([7a895b6](https://github.com/mitkonikov/veritium/commit/7a895b68807813f60c8dd63cf2c6fc013a97c50c))

---

Notes:
- Entries show the short commit hash in parentheses for reference.

## Release 1.1.0 - 2025-12-16

## Release 1.0.0 - 2025-12-15
