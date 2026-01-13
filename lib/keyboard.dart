import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardShortcuts extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onSave;
  final VoidCallback? onComment;
  final VoidCallback? onFlag;

  const KeyboardShortcuts({
    super.key,
    required this.child,
    this.onPrev,
    this.onNext,
    this.onSave,
    this.onComment,
    this.onFlag,
  });

  @override
  State<KeyboardShortcuts> createState() => _KeyboardShortcutsState();
}

class _KeyboardShortcutsState extends State<KeyboardShortcuts> {
  late FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'keyboard_shortcuts_root');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });

    // Global hardware keyboard handler so shortcuts work regardless of focus
    HardwareKeyboard.instance.addHandler(_hardwareKeyHandler);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_hardwareKeyHandler);
    _focusNode.dispose();
    super.dispose();
  }

  bool _isCtrlPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.controlLeft) ||
        pressed.contains(LogicalKeyboardKey.controlRight) ||
        pressed.contains(LogicalKeyboardKey.control);
  }

  bool _isAltPressed() {
    final pressed = HardwareKeyboard.instance.logicalKeysPressed;
    return pressed.contains(LogicalKeyboardKey.altLeft) ||
        pressed.contains(LogicalKeyboardKey.altRight) ||
        pressed.contains(LogicalKeyboardKey.alt);
  }

  bool _hardwareKeyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // F7: Previous
    if (event.logicalKey == LogicalKeyboardKey.f7) {
      widget.onPrev?.call();
      return true; // handled globally
    }
    // Alt+Left: Previous
    if (_isAltPressed() && event.logicalKey == LogicalKeyboardKey.arrowLeft) {
      widget.onPrev?.call();
      return true;
    }
    // F8: Next
    if (event.logicalKey == LogicalKeyboardKey.f8) {
      widget.onNext?.call();
      return true;
    }
    // Alt+Right: Next
    if (_isAltPressed() && event.logicalKey == LogicalKeyboardKey.arrowRight) {
      widget.onNext?.call();
      return true;
    }
    // Ctrl+S: Save
    if (_isCtrlPressed() && event.logicalKey == LogicalKeyboardKey.keyS) {
      widget.onSave?.call();
      return true;
    }
    // Ctrl+F: Flag toggle
    if (_isCtrlPressed() && event.logicalKey == LogicalKeyboardKey.keyF) {
      widget.onFlag?.call();
      return true;
    }
    // Ctrl+T: Comment
    if (_isCtrlPressed() && event.logicalKey == LogicalKeyboardKey.keyT) {
      widget.onComment?.call();
      return true;
    }

    return false;
  }

  @override
  Widget build(BuildContext context) {
    return Focus(focusNode: _focusNode, child: widget.child);
  }
}

