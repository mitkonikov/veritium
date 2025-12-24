import 'package:flutter/services.dart';
import 'theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'file_handler.dart';
import 'keyboard.dart';

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

  BoundingBox? _currentVisibleBox() {
    if (_visibleBoxes.isEmpty) return null;
    if (_currentBoxIndex < 0) return null;
    if (_currentBoxIndex >= _visibleBoxes.length) return null;
    return _visibleBoxes[_currentBoxIndex];
  }

  Future<void> _saveCurrent() async {
    if (_jsonFilePath != null && _croppedBoxes.isNotEmpty) {
      await FileHandler.saveCorrectedJsonFile(_jsonFilePath!, _jsonFilePath!, _croppedBoxes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Corrected JSON saved.')),
        );
      }
    }
  }

  void _toggleFlagCurrent() {
    setState(() {
      final box = _currentVisibleBox();
      if (box != null) {
        box.isFlagged = !box.isFlagged;
        if (_viewOnlyFlagged && !_visibleBoxes.contains(box)) {
          _currentBoxIndex = 0;
          if (_visibleBoxes.isNotEmpty) {
            _textController.text = _visibleBoxes[0].text;
          } else {
            _textController.text = 'No image available';
          }
        }
      }
    });
  }

  void _navigateToIndex(int newIndex) {
    if (_visibleBoxes.isEmpty) return;
    final int clamped = newIndex.clamp(0, _visibleBoxes.length - 1);
    setState(() {
      _currentBoxIndex = clamped;
      _textController.text = _visibleBoxes[_currentBoxIndex].text;
    });
  }

  void _navigatePrev() => _navigateToIndex(_currentBoxIndex - 1);
  void _navigateNext() => _navigateToIndex(_currentBoxIndex + 1);

  void _onTextChangedHandler(String value) {
    if (_currentVisibleBox() != null) {
      setState(() {
        _currentVisibleBox()!.updateText(value);
      });
    }
  }

  List<BoundingBox> _croppedBoxes = [];
  int _currentBoxIndex = 0;
  bool _showSpans = false;
  bool _isRendering = false;
  double _renderProgress = 0.0;
  String? _renderLabel;
  String? _jsonFilePath;
  bool _viewOnlyFlagged = false;

  List<BoundingBox> get _visibleBoxes => _viewOnlyFlagged ? _croppedBoxes.where((b) => b.isFlagged).toList() : _croppedBoxes;

  void _showCroppedImages(List<BoundingBox> boxes, {String? jsonFilePath}) {
    setState(() {
      _croppedBoxes = boxes.where((b) => b.croppedPngBytes != null || b.croppedSpansPngBytes != null).toList();
      _currentBoxIndex = 0;
      if (_visibleBoxes.isNotEmpty) {
        _textController.text = _visibleBoxes[0].text;
      }
      if (jsonFilePath != null) {
        _jsonFilePath = jsonFilePath;
      }
    });
  }

  void _onNavigateToBox(int newIndex) {
    _navigateToIndex(newIndex);
  }

  @override
  Widget build(BuildContext context) {
    return KeyboardShortcuts(
      onPrev: _navigatePrev,
      onNext: _navigateNext,
      onSave: _saveCurrent,
      onFlag: _toggleFlagCurrent,
      child: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(40),
          child: AppBar(
            backgroundColor: Colors.grey[850],
            title: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onPanStart: (_) => WindowControls.startDrag(),
              child: Row(
                children: (!kIsWeb) ? [
                  _buildMenuItem('File', ['Load JSON', 'Save JSON', 'Show Keyboard Shortcuts']),
                  _buildMenuItem('View', ['View Only Flagged', 'View All']),
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
          child: _isRendering
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  spacing: 10,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48.0),
                      child: _buildRenderProgress(),
                    ),
                    const SizedBox(height: 24),
                    if (_visibleBoxes.isEmpty)
                      const Text(
                        'Preparing images...',
                        style: TextStyle(fontSize: 18, color: Colors.white70),
                      ),
                    if (_visibleBoxes.isNotEmpty) ...[
                      _buildCorrectionPanel(),
                      _croppedImageNavigation(),
                      _buildButtons(),
                    ]
                  ],
                )
              : (_visibleBoxes.isEmpty
                  ? Text(
                      (_croppedBoxes.isEmpty ? 'Please load a file to begin.' : 'No flagged images.'),
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
                    )),
        ),
      )
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
            final pdfFilePathOriginal = filePath.replaceAll('_middle.json', '_origin.pdf');
            final pdfFilePathSpans = filePath.replaceAll('_middle.json', '_span.pdf');
            
            setState(() {
              _isRendering = true;
              _renderProgress = 0.0;
              _renderLabel = 'Rendering original';
            });
            final stopwatchOriginal = Stopwatch()..start();
            await FileHandler.renderBoxes(
              pdfFilePathOriginal,
              boxes,
              false,
              150,
              onProgress: (processed, total) {
                if (mounted) {
                  setState(() {
                    _renderProgress = total > 0 ? processed / total : 0.0;
                  });
                }
              },
            );
            stopwatchOriginal.stop();
            debugPrint('FileHandler.renderBoxes(original) elapsed: ${stopwatchOriginal.elapsedMilliseconds} ms');

            setState(() {
              _renderLabel = 'Rendering spans';
              _renderProgress = 0.0;
            });
            final stopwatchSpans = Stopwatch()..start();
            await FileHandler.renderBoxes(
              pdfFilePathSpans,
              boxes,
              true,
              150,
              onProgress: (processed, total) {
                if (mounted) {
                  setState(() {
                    _renderProgress = total > 0 ? processed / total : 0.0;
                  });
                }
              },
            );
            stopwatchSpans.stop();
            debugPrint('FileHandler.renderBoxes(spans) elapsed: ${stopwatchSpans.elapsedMilliseconds} ms');
            setState(() {
              _isRendering = false;
              _renderProgress = 0.0;
              _renderLabel = null;
            });
            
            _showCroppedImages(boxes, jsonFilePath: filePath);
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error loading JSON: $e')),
              );
            }
          }
        } else if (value == 'Save JSON') {
          if (_jsonFilePath != null && _croppedBoxes.isNotEmpty) {
            await FileHandler.saveNewCorrectedJsonFile(_jsonFilePath!, _croppedBoxes);
          } else {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('No file loaded to save.')),
              );
            }
          }
        } else if (value == 'Show Keyboard Shortcuts') {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Keyboard Shortcuts'),
              shape: ShapeBorder.lerp(
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                0,
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('F7 — Previous item'),
                  SizedBox(height: 8),
                  Text('F8 — Next item'),
                  SizedBox(height: 8),
                  Text('Ctrl+S — Save corrected JSON'),
                  SizedBox(height: 8),
                  Text('Ctrl+F — Toggle flag on current item'),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
              ],
            ),
          );
        } else if (value == 'View Only Flagged') {
          setState(() {
            _currentBoxIndex = 0;
            _viewOnlyFlagged = true;
            if (_visibleBoxes.isNotEmpty) {
              _textController.text = _visibleBoxes[0].text;
            }
          });
        } else if (value == 'View All') {
          setState(() {
            _viewOnlyFlagged = false;
            _currentBoxIndex = 0;
            if (_visibleBoxes.isNotEmpty) {
              _textController.text = _visibleBoxes[0].text;
            }
          });
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

  Widget _buildRenderProgress() {
    return Column(
      children: [
        LinearProgressIndicator(value: _renderProgress),
        if (_renderLabel != null)
          Padding(
            padding: const EdgeInsets.only(top: 6.0),
            child: Text(_renderLabel!, style: const TextStyle(color: Colors.white70)),
          ),
      ],
    );
  }

  Widget _croppedImageViewer() {
    const double fixedWidth = 600;
    if (_visibleBoxes.isEmpty) {
      return const SizedBox(
        height: 200,
        width: fixedWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black12),
          child: Center(child: Text('No image loaded')),
        ),
      );
    }
    final box = _visibleBoxes[_currentBoxIndex];
    // Choose spans image if toggled and available, otherwise fallback to original cropped image
    final bytes = (_showSpans && box.croppedSpansPngBytes != null) ? box.croppedSpansPngBytes : box.croppedPngBytes;
    if (bytes == null) {
      return const SizedBox(
        height: 200,
        width: fixedWidth,
        child: DecoratedBox(
          decoration: BoxDecoration(color: Colors.black12),
          child: Center(child: Text('No image available')),
        ),
      );
    }
    return Image.memory(
      bytes,
      width: fixedWidth,
      fit: BoxFit.contain,
    );
  }

  Widget _croppedImageNavigation() {
    if (_visibleBoxes.isEmpty) return const SizedBox.shrink();
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
        Text('${_currentBoxIndex + 1} / ${_visibleBoxes.length}'),
        IconButton(
          icon: const Icon(Icons.arrow_right),
          onPressed: _currentBoxIndex < _visibleBoxes.length - 1
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
    return LayoutBuilder(builder: (context, constraints) {
      final box = _visibleBoxes.isNotEmpty ? _visibleBoxes[_currentBoxIndex] : null;
      final int lineCount = box?.text.split('\n').length ?? 1;
      final int imageHeight = box?.croppedImage?.height ?? 200;
      final double maxFont = (imageHeight / lineCount).clamp(12, 32).toDouble() * 1.5;
      const double minFont = 8.0;
      final double horizontalPadding = 38.0; // adjust if your TextField has different padding
      final double availableWidth = constraints.maxWidth - horizontalPadding;

      double fitFont(String text) {
        if (text.isEmpty) return maxFont;
        double lo = minFont;
        double hi = maxFont;
        while (hi - lo > 0.5) {
          final mid = (lo + hi) / 2;
          final lines = text.split('\n');
          bool anyOverflow = false;
          for (final line in lines) {
            final tp = TextPainter(
              text: TextSpan(text: line, style: TextStyle(fontSize: mid)),
              textDirection: TextDirection.ltr,
            )..layout(minWidth: 0, maxWidth: double.infinity);
            if (tp.width >= availableWidth) {
              anyOverflow = true;
              break;
            }
          }
          if (anyOverflow) {
            hi = mid;
          } else {
            lo = mid;
          }
        }
        return lo;
      }

      final double fontSize = fitFont(box?.text ?? '');

      return TextField(
        controller: _textController,
        onChanged: _onTextChangedHandler,
        maxLines: null,
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontSize: fontSize),
        decoration: const InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          border: OutlineInputBorder(borderRadius: BorderRadius.zero),
          hintText: 'Enter text here',
        ),
      );
    });
  }

  Widget _buildButtons() {
    const double buttonSize = 38;
    final bool isFlagged = _visibleBoxes.isNotEmpty && _visibleBoxes[_currentBoxIndex].isFlagged;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.save,
            size: buttonSize,
            color: darkThemeValues[ThemeStyleKey.fontPrimaryColor],
          ),
          tooltip: 'Save',
          onPressed: _saveCurrent,
        ),
        const SizedBox(width: 20),
        IconButton(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          icon: Icon(
            isFlagged ? Icons.flag : Icons.outlined_flag,
            size: buttonSize,
            color: isFlagged ? Colors.red : darkThemeValues[ThemeStyleKey.fontPrimaryColor],
          ),
          tooltip: isFlagged ? 'Flagged' : 'Flag',
          onPressed: _toggleFlagCurrent,
        ),
        const SizedBox(width: 20),
        // Toggle button to switch between spans and original cropped images
        IconButton(
          icon: Icon(
            _showSpans ? Icons.image : Icons.layers,
            size: buttonSize
          ),
          tooltip: _showSpans ? 'Show original' : 'Show spans',
          onPressed: () {
            setState(() {
              _showSpans = !_showSpans;
            });
          },
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