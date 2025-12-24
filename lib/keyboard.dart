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

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'keyboard_shortcuts_root');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<LogicalKeySet, Intent> shortcuts = {
      LogicalKeySet(LogicalKeyboardKey.f7): const _PrevIntent(),
      LogicalKeySet(LogicalKeyboardKey.f8): const _NextIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyS): const _SaveIntent(),
      LogicalKeySet(LogicalKeyboardKey.control, LogicalKeyboardKey.keyF): const _FlagIntent(),
    };

    return Shortcuts(
      shortcuts: shortcuts,
      child: Actions(
        actions: {
          _PrevIntent: CallbackAction<_PrevIntent>(onInvoke: (intent) {
            widget.onPrev?.call();
            return null;
          }),
          _NextIntent: CallbackAction<_NextIntent>(onInvoke: (intent) {
            widget.onNext?.call();
            return null;
          }),
          _SaveIntent: CallbackAction<_SaveIntent>(onInvoke: (intent) {
            widget.onSave?.call();
            return null;
          }),
          _FlagIntent: CallbackAction<_FlagIntent>(onInvoke: (intent) {
            widget.onFlag?.call();
            return null;
          }),
        },
        child: Focus(
          focusNode: _focusNode,
          child: widget.child,
        ),
      ),
    );
  }
}

class _PrevIntent extends Intent { const _PrevIntent(); }
class _NextIntent extends Intent { const _NextIntent(); }
class _SaveIntent extends Intent { const _SaveIntent(); }
class _FlagIntent extends Intent { const _FlagIntent(); }