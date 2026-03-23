# Veritium Internal Documentation

This document maps the internal source files and major functions in `lib/`.

## Scope

- Focuses on runtime behavior and major symbols currently implemented in the app.
- Covers these files:
  - `lib/main.dart`
  - `lib/cli_export.dart`
  - `lib/cli_hash_export.dart`
  - `lib/file_handler.dart`
  - `lib/hash_exporter.dart`
  - `lib/markdown_exporter.dart`
  - `lib/keyboard.dart`
  - `lib/theme.dart`
  - `lib/windows_controls.dart`
  - `bin/export_markdown.dart`
  - `bin/export_empty_corrected_hashes.dart`

## High-Level Runtime Flow

1. App boot: `main(args)` checks for CLI export args first; otherwise runs `Veritium` with app theme and global UI scale.
2. File load: `CorrectionPage` triggers `FileHandler.loadJsonFileWithPath()`.
3. PDF rendering: `FileHandler.renderBoxes()` renders original and span PDFs into per-box crops.
4. Editing: text edits update the current `BoundingBox.hashTextPairs` and mark it dirty.
5. Review: users can flag and comment boxes, and filter to flagged/commented subsets.
6. Save:
   - In-place save: `_saveCurrent()` → `FileHandler.saveCorrectedJsonFile(...)`
   - Save-as: menu action → `FileHandler.saveNewCorrectedJsonFile(...)`
7. Export markdown:
  - UI: `File > Export Markdown` → `FileHandler.exportMarkdownFromJson(...)`
  - CLI (Dart): `bin/export_markdown.dart` → `runCliExportCommand(...)` → `MarkdownExporter.exportToFile(...)`
  - CLI (Windows binary): `veritium.exe --cli-export ...` → `runCliExportCommand(...)` → `MarkdownExporter.exportToFile(...)`
8. Export empty corrected hashes:
  - CLI (Dart): `bin/export_empty_corrected_hashes.dart` → `runCliHashExportCommand(...)` → `HashExporter.exportToFile(...)`
  - CLI (Windows binary): `veritium.exe --cli-export-empty-hashes ...` → `runCliHashExportCommand(...)` → `HashExporter.exportToFile(...)`

---

## File Map

| File | Responsibility |
|---|---|
| `lib/main.dart` | App entrypoint, embedded CLI mode switch, main UI, menu actions, navigation, edit workflow, save flow, progress UI |
| `lib/cli_export.dart` | Shared CLI parser/executor for markdown export (used by both app binary mode and `bin` entrypoint) |
| `lib/cli_hash_export.dart` | Shared CLI parser/executor for exporting hashes with empty `corrected_content` |
| `lib/file_handler.dart` | JSON loading/parsing, PDF crop rendering, save/writeback logic, `BoundingBox` model, UI-facing export wrappers |
| `lib/hash_exporter.dart` | Reusable `_middle.json` → hash list extraction/file export for spans with empty `corrected_content` |
| `lib/markdown_exporter.dart` | Reusable `_middle.json` → Markdown conversion + file export logic (shared by UI and CLI) |
| `lib/keyboard.dart` | Global keyboard shortcut handling and callback dispatch |
| `lib/theme.dart` | Dark theme tokens + `ThemeData` construction |
| `lib/windows_controls.dart` | Windows platform channel window actions + custom traffic-light UI controls |
| `bin/export_markdown.dart` | Command-line entrypoint for markdown export |
| `bin/export_empty_corrected_hashes.dart` | Command-line entrypoint for exporting hashes where `corrected_content` is empty |

---

## `lib/main.dart`

### Top-level symbols

- `uiScaleNotifier` (`ValueNotifier<double>`)
  - Global UI scale state shared by app-level `MediaQuery` override.

- `main()`
  - Entrypoint; checks CLI args and executes embedded CLI export mode when requested.
  - Otherwise starts the Flutter UI app.

### `Veritium` (`StatelessWidget`)

- `build(BuildContext context)`
  - Creates `MaterialApp` with:
    - global text scaling bound to `uiScaleNotifier`
    - theme from `buildAppTheme()`
    - `CorrectionPage` as home

### `CorrectionPage` / `_CorrectionPageState`

#### Lifecycle and core helpers

- `initState()`
  - Initializes text controller and focus node.
- `dispose()`
  - Disposes text controller and focus node.
- `_setTextSafe(String text)`
  - Updates text controller while clamping selection bounds.
- `_currentVisibleBox()`
  - Returns current visible box or `null` if index/filter state is invalid.

#### Save / edit / navigation logic

- `_saveCurrent()`
  - Saves in-place to currently loaded JSON and clears dirty flags.
- `_toggleFlagCurrent()`
  - Toggles current box flag, marks dirty, and re-aligns selection under filters.
- `_navigateToIndex(int newIndex)`
  - Clamped navigation over visible boxes; syncs editor text + restores focus.
- `_navigatePrev()` / `_navigateNext()`
  - Convenience navigation wrappers.
- `_onTextChangedHandler(String value)`
  - Writes edited text into current box and marks it dirty.
- `_visibleBoxes` (getter)
  - Applies active filter mode:
    - all
    - flagged only
    - commented only

#### Data loading + user feedback

- `_showCroppedImages(List<BoundingBox> boxes, {String? jsonFilePath})`
  - Injects rendered boxes into state and initializes selection.
- `_showSnack(String message)`
  - Displays custom overlay snackbar at bottom-right.

#### Dialogs and action entry points

- `_openCommentDialog()`
  - Lets user add/update comment for current box (`Ctrl+Enter` saves in dialog).
- `_openGotoDialog()`
  - Jump-to-index dialog; navigates to user-selected item.

#### UI composition methods

- `build(BuildContext context)`
  - Wraps page in `KeyboardShortcuts` and builds scaffold/app shell.
- `_buildMenuItem(String title, List<String> options)`
  - Creates menu popups and handles all menu command branches:
    - Load JSON
    - Save JSON (save-as)
    - Export Markdown
    - Keyboard shortcuts dialog
    - View filters
    - UI Scale dialog
- `_buildGotoMenuItem()`
  - Top menu item shortcut to goto dialog.
- `_buildRenderProgress()`
  - Progress bar + render phase label.
- `_croppedImageViewer()`
  - Displays selected crop image (original or spans), with fallback placeholders.
- `_croppedImageNavigation()`
  - Prev/next controls + item position label.
- `_buildCommentLabel()`
  - Displays current box comment summary under panel.
- `_buildCorrectionPanel()`
  - Main side-by-side panel (image + text editor).
- `_buildCorrectionTextField()`
  - Dynamic text field with computed font-size fitting.
- `_buildButtons()`
  - Lower action buttons (toggle span/original, flag, comment, save).

---

## `lib/cli_export.dart`

### Purpose

Shared CLI command implementation for markdown export, reusable from both:

- `bin/export_markdown.dart`
- `lib/main.dart` (embedded app-binary CLI mode)

### Key APIs

- `shouldRunEmbeddedCliMode(List<String> args)`
  - Detects whether startup args should route to CLI mode.

- `cliExportUsage(String command)`
  - Returns formatted CLI usage/help text.

- `parseCliExportArgs(List<String> args)`
  - Parses and validates CLI options (`--input`, `--output`, `--no-images`, `--original-content`, `--lists-as-text`, `--all-as-text`, `--block-separator`, `--skip-hashes`, `--skip-hashes-mode`, `--help`).

- `runCliExportCommand(List<String> args, {required String command, ...})`
  - Executes end-to-end CLI export flow and returns a process-like exit code.

---

## `lib/cli_hash_export.dart`

### Purpose

Shared CLI command implementation for exporting span hashes whose `corrected_content` is empty.

### Key APIs

- `shouldRunEmbeddedCliHashMode(List<String> args)`
  - Detects explicit binary hash export mode (`--cli-export-empty-hashes`).

- `cliHashExportUsage(String command)`
  - Returns formatted CLI usage/help text.

- `parseCliHashExportArgs(List<String> args)`
  - Parses and validates CLI options (`--input`, `--output`, `--help`).

- `runCliHashExportCommand(List<String> args, {required String command, ...})`
  - Executes end-to-end empty-corrected-hash export flow and returns a process-like exit code.

---

## `lib/file_handler.dart`

### `FileHandler`

- `generateRandomHash()`
  - Creates random 64-char lowercase alphanumeric hash.

- `loadJsonFileWithPath()`
  - Opens a file picker, validates selection, then delegates to `loadJsonFileFromPath(...)`.

- `loadJsonFileFromPath(String filePath, {bool writeBackups = true})`
  - Reads MinerU `_middle.json`.
  - Walks `pdf_info -> para_blocks -> lines -> spans`.
  - Ensures missing `hash` values are generated for blocks/spans.
  - Builds `BoundingBox` list with text mapped as `hash_text_pairs`.
  - Optionally writes backup (`.bak`) and persists hash backfills.

- `renderBoxes(String pdfFilePath, List<BoundingBox> allBboxes, bool spans, double dpi, {void Function(int processed, int total)? onProgress})`
  - Opens PDF with `pdfrx`.
  - Groups boxes by page.
  - Renders each page at target DPI, crops each bbox rectangle.
  - Stores PNG bytes into either original or span crop fields on `BoundingBox`.
  - Reports incremental progress via callback.

- `pdfrxInitialize()`
  - Initializes `pdfrx` Flutter integration.

- `saveCorrectedJsonFile(String originalJsonFile, String jsonFilePath, List<BoundingBox> boxes)`
  - Re-reads source JSON.
  - Re-maps edited text by span hash into `corrected_content`.
  - Persists `flagged` and `comment` at block level.
  - Writes either in place or to a target output path.

- `saveNewCorrectedJsonFile(String originalJsonFile, List<BoundingBox> boxes)`
  - Shows save dialog and forwards to `saveCorrectedJsonFile(...)`.

- `buildMarkdownFromJson(String originalJsonFile, List<BoundingBox> boxes)`
  - UI-facing wrapper that builds hash/text overrides from in-memory edits and delegates to `MarkdownExporter.buildFromJsonFile(...)`.

- `exportMarkdownFromJson(String originalJsonFile, List<BoundingBox> boxes)`
  - UI-facing wrapper for save dialog + markdown export, delegating conversion and file writing to `MarkdownExporter`.

---

## `lib/markdown_exporter.dart`

### `MarkdownExporter`

- `defaultOutputFileName(String originalJsonFile)`
  - Converts `_middle.json` (or any `.json`) to default `.md` output filename.

- `buildFromJsonFile(String jsonFilePath, {Map<String, String>? hashTextOverrides, bool includeImages = true, bool preferCorrectedContent = true, bool listsAsText = false, bool allAsText = false, String blockSeparator = '\\n\\n', Set<String> skipHashes = const <String>{}, SkipHashesMode skipHashesMode = SkipHashesMode.span})`
  - Reads JSON file from disk and converts it to markdown.
  - Supports `includeImages` to keep or skip markdown image entries.
  - Supports `listsAsText` to render list blocks as plain text.
  - Supports `allAsText` to render supported blocks without markdown syntax.
  - Supports `blockSeparator` to control separator between rendered blocks.
  - Supports `skipHashes` and `skipHashesMode` to omit matching spans (`span`) or full lines (`line`).
  - Defaults to corrected-content-first text resolution.

- `buildFromJsonData(Map<String, dynamic> jsonData, {Map<String, String>? hashTextOverrides, bool includeImages = true, bool preferCorrectedContent = true, bool listsAsText = false, bool allAsText = false, String blockSeparator = '\\n\\n', Set<String> skipHashes = const <String>{}, SkipHashesMode skipHashesMode = SkipHashesMode.span})`
  - Core reusable conversion logic:
    - `title` blocks → markdown headings
    - `text` blocks → paragraphs
    - `list` blocks → bullet lines (or plain text when `listsAsText = true`)
    - `image` blocks → markdown image tags + captions
    - `allAsText = true` forces titles/lists/images into plain text output
  - Uses `hashTextOverrides` first, then:
    - corrected-first mode: `corrected_content` → `content`
    - original-first mode: `content` → `corrected_content`

- `exportToFile({required String inputJsonFile, required String outputMarkdownFile, Map<String, String>? hashTextOverrides, bool includeImages = true, bool preferCorrectedContent = true, bool listsAsText = false, bool allAsText = false, String blockSeparator = '\\n\\n', Set<String> skipHashes = const <String>{}, SkipHashesMode skipHashesMode = SkipHashesMode.span})`
  - End-to-end file export helper used by both UI and CLI.
  - Supports `includeImages`, `preferCorrectedContent`, `listsAsText`, `allAsText`, `blockSeparator`, `skipHashes`, and `skipHashesMode` for output control.

---

## `lib/hash_exporter.dart`

### `HashExporter`

- `defaultOutputFileName(String originalJsonFile)`
  - Converts `_middle.json` (or any `.json`) to a default `*_empty_corrected_hashes.txt` output filename.

- `buildEmptyCorrectedHashesFromJsonFile(String jsonFilePath)`
  - Reads JSON file from disk and returns unique span hashes whose `corrected_content` is empty.

- `buildEmptyCorrectedHashesFromJsonData(Map<String, dynamic> jsonData)`
  - Core reusable extraction logic:
    - walks `pdf_info -> para_blocks -> lines -> spans`
    - includes hashes only when `hash` is non-empty
    - includes only when `corrected_content` field is present and empty
    - preserves duplicates in original order

- `exportToFile({required String inputJsonFile, required String outputHashFile})`
  - End-to-end helper that writes one hash per line.

---

## `bin/export_markdown.dart`

### Purpose

CLI command to export MinerU `_middle.json` into markdown without launching the Flutter app.

### Behavior

- Parses options:
  - `--input` / `-i` (required)
  - `--output` / `-o` (optional)
  - `--no-images` (optional)
  - `--original-content` (optional)
  - `--lists-as-text` (optional)
  - `--all-as-text` (optional)
  - `--block-separator` (optional: `double` default, or `single`)
  - `--skip-hashes` (optional, one hash per line text file)
  - `--skip-hashes-mode` (optional: `span` default, or `line`)
  - `--help` / `-h`
- Defaults output path next to input when `--output` is omitted.
- Delegates execution to `runCliExportCommand(...)` in `lib/cli_export.dart`.

## `bin/export_empty_corrected_hashes.dart`

### Purpose

CLI command to export span hashes with empty `corrected_content` from MinerU `_middle.json`.

### Behavior

- Parses options:
  - `--input` / `-i` (required)
  - `--output` / `-o` (optional)
  - `--help` / `-h`
- Defaults output path next to input when `--output` is omitted.
- Delegates execution to `runCliHashExportCommand(...)` in `lib/cli_hash_export.dart`.
- Windows binary mode should use explicit switch: `--cli-export-empty-hashes`.

## `lib/file_handler.dart` (continued)

### `BoundingBox`

#### Purpose

Represents one OCR block region + its editable text fragments.

#### Key fields

- Geometry: `pageIndex`, `xMin`, `yMin`, `xMax`, `yMax`
- Identity/text: `hash`, `hashTextPairs`
- Rendered images: `croppedImage`, `croppedPngBytes`, `croppedSpans`, `croppedSpansPngBytes`
- Review metadata: `isFlagged`, `comment`, `isDirty`

#### Methods

- `BoundingBox.fromJson(Map<String, dynamic> json)`
  - Builds model from normalized map payload.
- `text` (getter)
  - Joins `hashTextPairs` values with newlines for display/edit.
- `updateText(String newText)`
  - Splits edited text by line and updates values in `hashTextPairs`.
  - Marks box dirty.

---

## `lib/keyboard.dart`

### Types

- `ShortcutInfo`
  - Data holder for displayable shortcut key + description.

- `KeyboardShortcuts` (`StatefulWidget`)
  - Wrapper that installs app-level keyboard listeners.
  - Exposes callback hooks (`onPrev`, `onNext`, `onSave`, etc.).
  - `shortcuts` static list defines user-facing shortcut catalog.

### `_KeyboardShortcutsState` methods

- `initState()`
  - Creates focus node and registers global hardware key handler.
- `dispose()`
  - Unregisters handler and disposes focus node.
- `_isCtrlPressed()` / `_isAltPressed()`
  - Modifier key helper checks.
- `_hardwareKeyHandler(KeyEvent event)`
  - Dispatches shortcut actions:
    - `F7`, `Alt+Left` → previous
    - `F8`, `Alt+Right` → next
    - `Ctrl+S` → save
    - `Ctrl+F` → flag
    - `Ctrl+T` → comment
    - `Ctrl+G` → goto
    - `Ctrl+=`, `Ctrl++`, `NumpadAdd` → scale up
    - `Ctrl+-`, `NumpadSubtract` → scale down
- `build(BuildContext context)`
  - Returns `Focus` wrapper around child.

---

## `lib/theme.dart`

### Theme tokens

- `ThemeStyleKey` enum
  - Typed keys for color and style values.
- `darkThemeValues`
  - Central map holding dark theme constants.

### Factory

- `buildAppTheme()`
  - Constructs global `ThemeData` for app:
    - dark color scheme
    - button/input/popup/icon themes
    - rectangular (zero-radius) visual style

---

## `lib/windows_controls.dart`

### `WindowControls`

- `close()`
- `minimize()`
- `maximize()`
- `startDrag()`

All methods invoke the `custom_window_controls` method channel for native desktop window actions.

### Widgets

- `WindowsControlButton`
  - Stateful UI button for single traffic-light action, including hover behavior.
- `_WindowsControlButtonState.build(...)`
  - Renders hover/normal visuals and optional hover icon.
- `WindowsControlButtons`
  - Group widget that composes minimize/maximize/close controls.
- `WindowsControlButtons.build(...)`
  - Provides final row of window control buttons.
