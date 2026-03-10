# Veritium Internal Documentation

This document maps the internal source files and major functions in `lib/`.

## Scope

- Focuses on runtime behavior and major symbols currently implemented in the app.
- Covers these files:
  - `lib/main.dart`
  - `lib/file_handler.dart`
  - `lib/keyboard.dart`
  - `lib/theme.dart`
  - `lib/windows_controls.dart`

## High-Level Runtime Flow

1. App boot: `main()` runs `Veritium`, applying app theme and global UI scale.
2. File load: `CorrectionPage` triggers `FileHandler.loadJsonFileWithPath()`.
3. PDF rendering: `FileHandler.renderBoxes()` renders original and span PDFs into per-box crops.
4. Editing: text edits update the current `BoundingBox.hashTextPairs` and mark it dirty.
5. Review: users can flag and comment boxes, and filter to flagged/commented subsets.
6. Save:
   - In-place save: `_saveCurrent()` → `FileHandler.saveCorrectedJsonFile(...)`
   - Save-as: menu action → `FileHandler.saveNewCorrectedJsonFile(...)`

---

## File Map

| File | Responsibility |
|---|---|
| `lib/main.dart` | Main UI, menu actions, navigation, edit workflow, save flow, progress UI |
| `lib/file_handler.dart` | JSON loading/parsing, PDF crop rendering, save/writeback logic, `BoundingBox` model |
| `lib/keyboard.dart` | Global keyboard shortcut handling and callback dispatch |
| `lib/theme.dart` | Dark theme tokens + `ThemeData` construction |
| `lib/windows_controls.dart` | Windows platform channel window actions + custom traffic-light UI controls |

---

## `lib/main.dart`

### Top-level symbols

- `uiScaleNotifier` (`ValueNotifier<double>`)
  - Global UI scale state shared by app-level `MediaQuery` override.

- `main()`
  - Entrypoint; runs `Veritium`.

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
