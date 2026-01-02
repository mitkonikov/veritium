# Changelog

All notable changes to this project will be documented in this file.

## Release 2.0.0 - 2026-01-02

### Breaking Changes
- Flags and comments are now saved in the bounding box data structure instead of in the spans. (f4b925f)

### Added
- Support for displaying OCR internal spans. (bef5599)
- Support for comments on bounding boxes. (f4b925f)
- Add ability to filter only boxes with comments. (ea5e797)
- Add Goto dialog to jump to a specific item. (4374d8f)
- UI Text & widget scaling (UI Scale) with live slider. (9a1387b)
- Keyboard shortcuts (F7/F8, Ctrl+S, Ctrl+F). (ac98e66)
- Progress bar for loading/rendering PDF files. (e9e9a13)

### Changed
- Save icon now visually indicates unsaved changes. (b1e32b1)
- Binary-search font sizing in correction text field to fit lines. (330010c)
- Increased PDF rendering DPI for improved image quality. (ba48f65)

### Refactor
- Separated custom Windows controls into their own widget/file. (20ae1df)
- Add few tests for loading example JSON files. (7a895b6)

---

Notes:
- Entries show the short commit hash in parentheses for reference.

## Release 1.1.0 - 2024-12-16

## Release 1.0.0 - 2024-12-15
