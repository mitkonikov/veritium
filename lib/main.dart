import 'package:flutter/services.dart';
import 'theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'file_handler.dart';

// Platform channel for custom window controls
class WindowControls {
  static const _channel = MethodChannel('custom_window_controls');

  static Future<void> close() => _channel.invokeMethod('close');
  static Future<void> minimize() => _channel.invokeMethod('minimize');
  static Future<void> maximize() => _channel.invokeMethod('maximize');
  static Future<void> startDrag() => _channel.invokeMethod('startDrag');
}

void main() {
  runApp(const Veritium());
}

class Veritium extends StatelessWidget {
  const Veritium({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Veritium',
      theme: buildAppTheme(),
      debugShowCheckedModeBanner: false,
      themeAnimationDuration: .zero,
      home: const CorrectionPage(),
    );
  }
}

class CorrectionPage extends StatefulWidget {
  const CorrectionPage({ super.key });

  @override
  State<CorrectionPage> createState() => _CorrectionPageState();
}

class _CorrectionPageState extends State<CorrectionPage> {
  late TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: "No file loaded.");
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  List<BoundingBox> _croppedBoxes = [];
  int _currentBoxIndex = 0;
  String? _jsonFilePath;

  void _showCroppedImages(List<BoundingBox> boxes, {String? jsonFilePath}) {
    setState(() {
      _croppedBoxes = boxes.where((b) => b.croppedPngBytes != null).toList();
      _currentBoxIndex = 0;
      if (_croppedBoxes.isNotEmpty) {
        _textController.text = _croppedBoxes[0].text;
      }
      if (jsonFilePath != null) {
        _jsonFilePath = jsonFilePath;
      }
    });
  }

  void _onNavigateToBox(int newIndex) {
    setState(() {
      _currentBoxIndex = newIndex;
      _textController.text = _croppedBoxes[_currentBoxIndex].text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(40),
        child: AppBar(
          backgroundColor: Colors.grey[850],
          title: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onPanStart: (_) => WindowControls.startDrag(),
            child: Row(
              children: (!kIsWeb) ? [
                _buildMenuItem('File', ['Load JSON', 'Save JSON']),
                const Spacer(),
                _buildWindowControls(),
              ] : [
                _buildMenuItem('File', ['Load JSON', 'Save JSON']),
              ],
            ),
          ),
        ),
      ),
      body: Center(
        child: _croppedBoxes.isEmpty
            ? const Text(
                'Please load a file to begin.',
                style: TextStyle(fontSize: 22, color: Colors.white70),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 10,
                children: [
                  _buildCorrectionPanel(),
                  _croppedImageNavigation(),
                  _buildButtons()
                ],
              ),
      ),
    );
  }

  Widget _buildMenuItem(String title, List<String> options) {
    return PopupMenuButton<String>(
      popUpAnimationStyle: AnimationStyle(duration: .zero),
      onSelected: (value) async {
        if (value == 'Load JSON') {
          await FileHandler.pdfrxInitialize();
          try {
            final (filePath, boxes) = await FileHandler.loadJsonFileWithPath();
            await FileHandler.renderBoxes(filePath, boxes);
            _showCroppedImages(boxes, jsonFilePath: filePath);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading JSON: $e')),
              );
            }
          }
        } else if (value == 'Save JSON') {
          await FileHandler.saveNewCorrectedJsonFile(_jsonFilePath!, _croppedBoxes);
        }
        // Handle other menu actions here
      },
      itemBuilder: (BuildContext context) {
        return options.map((option) => PopupMenuItem(
          value: option,
          height: 38,
          child: Text(option)
        )).toList();
      },
      padding: EdgeInsetsGeometry.all(0),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

  Widget _buildWindowControls() {
    Widget windowsControlButton({
      required Color color,
      required Color hoverColor,
      required VoidCallback onPressed,
      String? tooltip,
      IconData? hoverIcon,
      Color? hoverIconColor,
    }) {
      return _WindowsControlButton(
        color: color,
        hoverColor: hoverColor,
        onPressed: onPressed,
        tooltip: tooltip,
        hoverIcon: hoverIcon,
        hoverIconColor: hoverIconColor,
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        windowsControlButton(
          color: const Color(0xFFFFBD2E), // Yellow (minimize)
          hoverColor: const Color.fromARGB(255, 160, 117, 0),
          onPressed: WindowControls.minimize,
          tooltip: 'Minimize',
          hoverIcon: Icons.remove,
          hoverIconColor: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
        ),
        windowsControlButton(
          color: const Color(0xFF28C940), // Green (maximize)
          hoverColor: const Color(0xFF249C36),
          onPressed: WindowControls.maximize,
          tooltip: 'Maximize/Restore',
          hoverIcon: Icons.crop_square,
          hoverIconColor: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
        ),
        windowsControlButton(
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

  Widget _croppedImageViewer() {
    const double fixedWidth = 600;
    if (_croppedBoxes.isEmpty) {
      return const SizedBox(
        height: 200,
        width: fixedWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black12),
          child: Center(child: Text('No image loaded')),
        ),
      );
    }
    final box = _croppedBoxes[_currentBoxIndex];
    return Image.memory(
      box.croppedPngBytes!,
      width: fixedWidth,
      fit: BoxFit.contain,
    );
  }

  Widget _croppedImageNavigation() {
    if (_croppedBoxes.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      spacing: 10,
      children: [
        IconButton(
          icon: const Icon(Icons.arrow_left),
          onPressed: _currentBoxIndex > 0
              ? () => _onNavigateToBox(_currentBoxIndex - 1)
              : null,
        ),
        Text('${_currentBoxIndex + 1} / ${_croppedBoxes.length}'),
        IconButton(
          icon: const Icon(Icons.arrow_right),
          onPressed: _currentBoxIndex < _croppedBoxes.length - 1
              ? () => _onNavigateToBox(_currentBoxIndex + 1)
              : null,
        ),
      ],
    );
  }

  Widget _buildCorrectionPanel() {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.7,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Show cropped image if available, else placeholder
          SizedBox(
            width: 600,
            child: _croppedImageViewer(),
          ),
          SizedBox(width: 20),
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 600,
                minWidth: 200,
              ),
              child: _buildCorrectionTextField(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCorrectionTextField() {
    final box = _croppedBoxes.isNotEmpty ? _croppedBoxes[_currentBoxIndex] : null;
    final int lineCount = box?.text.split('\n').length ?? 1;
    final int imageHeight = box?.croppedImage?.height ?? 200;
    final double fontSize = (imageHeight / lineCount).clamp(12, 32).toDouble() * 1.4;
    return TextField(
      controller: _textController,
      onChanged: (value) {
        if (_croppedBoxes.isNotEmpty) {
          setState(() {
            _croppedBoxes[_currentBoxIndex].updateText(value);
          });
        }
      },
      maxLines: null,
      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: fontSize),
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.zero),
        hintText: 'Enter text here',
      ),
    );
  }

  Widget _buildButtons() {
    const double buttonWidth = 120;
    const double buttonHeight = 48;
    final bool isFlagged = _croppedBoxes.isNotEmpty && _croppedBoxes[_currentBoxIndex].isFlagged;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: TextButton(
            onPressed: () async {
              if (_jsonFilePath != null && _croppedBoxes.isNotEmpty) {
                await FileHandler.saveCorrectedJsonFile(_jsonFilePath!, _jsonFilePath!, _croppedBoxes);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Corrected JSON saved.')),
                  );
                }
              }
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            ),
            child: Text(
              "Save",
              style: TextStyle(
                fontSize: 18, // Increase font size
              ),
            ),
          ),
        ),
        const SizedBox(width: 20),
        SizedBox(
          width: buttonWidth,
          height: buttonHeight,
          child: TextButton(
            onPressed: () {
              setState(() {
                if (_croppedBoxes.isNotEmpty) {
                  final box = _croppedBoxes[_currentBoxIndex];
                  box.isFlagged = !box.isFlagged;
                }
              });
            },
            style: TextButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              backgroundColor: isFlagged
                  ? Colors.redAccent
                  : darkThemeValues[ThemeStyleKey.buttonColor],
            ),
            child: Text(
              isFlagged ? "Flagged" : "Flag",
              style: TextStyle(
                fontSize: 18
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WindowsControlButton extends StatefulWidget {
  final Color color;
  final Color hoverColor;
  final VoidCallback onPressed;
  final String? tooltip;
  final IconData? hoverIcon;
  final Color? hoverIconColor;
  const _WindowsControlButton({
    required this.color,
    required this.hoverColor,
    required this.onPressed,
    this.tooltip,
    this.hoverIcon,
    this.hoverIconColor,
  });

  @override
  State<_WindowsControlButton> createState() => _WindowsControlButtonState();
}

class _WindowsControlButtonState extends State<_WindowsControlButton> {
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