import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class KeyboardShortcuts extends StatefulWidget {
  final Widget child;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback? onSave;
  final VoidCallback? onFlag;

  const KeyboardShortcuts({
    super.key,
    required this.child,
    this.onPrev,
    this.onNext,
    this.onSave,
    this.onFlag,
  });

  @override
  State<KeyboardShortcuts> createState() => _KeyboardShortcutsState();
}

class _KeyboardShortcutsState extends State<KeyboardShortcuts> {
  late FocusNode _focusNode;
  KeyEventResult? _lastResult;

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

  bool _hardwareKeyHandler(KeyEvent event) {
    if (event is! KeyDownEvent) return false;

    // F7: Previous
    if (event.logicalKey == LogicalKeyboardKey.f7) {
      widget.onPrev?.call();
      return true; // handled globally
    }
    // F8: Next
    if (event.logicalKey == LogicalKeyboardKey.f8) {
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

    return false;
  }

  @override
  Widget build(BuildContext context) {
    final Map<LogicalKeySet, Intent> shortcuts = {
      LogicalKeySet(LogicalKeyboardKey.f7): const _PrevIntent(),
      LogicalKeySet(LogicalKeyboardKey.f8): const _NextIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS):
          const _SaveIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF):
          const _FlagIntent(),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          _PrevIntent: CallbackAction<_PrevIntent>(
            onInvoke: (intent) {
              widget.onPrev?.call();
              return null;
            },
          ),
          _NextIntent: CallbackAction<_NextIntent>(
            onInvoke: (intent) {
              widget.onNext?.call();
              return null;
            },
          ),
          _SaveIntent: CallbackAction<_SaveIntent>(
            onInvoke: (intent) {
              widget.onSave?.call();
              return null;
            },
          ),
          _FlagIntent: CallbackAction<_FlagIntent>(
            onInvoke: (intent) {
              widget.onFlag?.call();
              return null;
            },
          ),
        },
        child: Focus(focusNode: _focusNode, child: widget.child),
      ),
    );
  }
}

class _PrevIntent extends Intent {
  const _PrevIntent();
}

class _NextIntent extends Intent {
  const _NextIntent();
}

class _SaveIntent extends Intent {
  const _SaveIntent();
}

class _FlagIntent extends Intent {
  const _FlagIntent();
}
