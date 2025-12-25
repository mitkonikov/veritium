import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'theme.dart';

// Platform channel for custom window controls
class WindowControls {
  static const _channel = MethodChannel('custom_window_controls');

  static Future<void> close() => _channel.invokeMethod('close');
  static Future<void> minimize() => _channel.invokeMethod('minimize');
  static Future<void> maximize() => _channel.invokeMethod('maximize');
  static Future<void> startDrag() => _channel.invokeMethod('startDrag');
}

class WindowsControlButton extends StatefulWidget {
  final Color color;
  final Color hoverColor;
  final VoidCallback onPressed;
  final String? tooltip;
  final IconData? hoverIcon;
  final Color? hoverIconColor;
  const WindowsControlButton({
    super.key,
    required this.color,
    required this.hoverColor,
    required this.onPressed,
    this.tooltip,
    this.hoverIcon,
    this.hoverIconColor,
  });

  @override
  State<WindowsControlButton> createState() => _WindowsControlButtonState();
}

class _WindowsControlButtonState extends State<WindowsControlButton> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() => _hovering = false),
        child: GestureDetector(
          onTap: widget.onPressed,
          child: Tooltip(
            message: widget.tooltip ?? '',
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: _hovering ? widget.hoverColor : widget.color,
                shape: BoxShape.rectangle,
                border: Border.all(color: Colors.black26, width: 1),
              ),
              child: _hovering && widget.hoverIcon != null
                  ? Center(
                      child: Icon(
                        widget.hoverIcon,
                        size: 10,
                        color: widget.hoverIconColor ?? Colors.black54,
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class WindowsControlButtons extends StatelessWidget {
  const WindowsControlButtons({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        WindowsControlButton(
          color: const Color(0xFFFFBD2E), // Yellow (minimize)
          hoverColor: const Color.fromARGB(255, 160, 117, 0),
          onPressed: WindowControls.minimize,
          tooltip: 'Minimize',
          hoverIcon: Icons.remove,
          hoverIconColor: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
        ),
        WindowsControlButton(
          color: const Color(0xFF28C940), // Green (maximize)
          hoverColor: const Color(0xFF249C36),
          onPressed: WindowControls.maximize,
          tooltip: 'Maximize/Restore',
          hoverIcon: Icons.crop_square,
          hoverIconColor: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
        ),
        WindowsControlButton(
          color: const Color(0xFFFF5F57), // Red (close)
          hoverColor: const Color(0xFFE0483E),
          onPressed: WindowControls.close,
          tooltip: 'Close',
          hoverIcon: Icons.close,
          hoverIconColor: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
        ),
      ],
    );
  }
}