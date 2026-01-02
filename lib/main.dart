import 'theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'file_handler.dart';
import 'keyboard.dart';
import 'windows_controls.dart';

// Global UI scale notifier (1.0 = normal)
final ValueNotifier<double> uiScaleNotifier = ValueNotifier<double>(1.0);

void main() {
  runApp(const Veritium());
}

class Veritium extends StatelessWidget {
  const Veritium({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, child) {
        return ValueListenableBuilder<double>(
          valueListenable: uiScaleNotifier,
          builder: (context, scale, child) {
            final mq = MediaQuery.of(context);
            return MediaQuery(
              data: mq.copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            );
          },
          child: child,
        );
      },
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
        setState(() {
          for (final b in _croppedBoxes) {
            b.isDirty = false;
          }
        });
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
        box.isDirty = true;
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
        _currentVisibleBox()!.isDirty = true;
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
  bool _viewOnlyCommented = false;
  bool get _hasUnsavedChanges => _croppedBoxes.any((b) => b.isDirty);

  List<BoundingBox> get _visibleBoxes {
    if (_viewOnlyFlagged) return _croppedBoxes.where((b) => b.isFlagged).toList();
    if (_viewOnlyCommented) return _croppedBoxes.where((b) => b.comment.isNotEmpty).toList();
    return _croppedBoxes;
  }

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
                  _buildMenuItem('View', ['View Only Flagged', 'View Only Commented', 'View All', 'UI Scale']),
                  _buildGotoMenuItem(),
                  const Spacer(),
                  const WindowsControlButtons(),
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
                      _buildCommentLabel(),
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
                        _buildCommentLabel(),
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
            setState(() {
              for (final b in _croppedBoxes) {
                b.isDirty = false;
              }
            });
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
            _viewOnlyCommented = false;
            if (_visibleBoxes.isNotEmpty) {
              _textController.text = _visibleBoxes[0].text;
            }
          });
        } else if (value == 'View Only Commented') {
          setState(() {
            _currentBoxIndex = 0;
            _viewOnlyCommented = true;
            _viewOnlyFlagged = false;
            if (_visibleBoxes.isNotEmpty) {
              _textController.text = _visibleBoxes[0].text;
            }
          });
        } else if (value == 'View All') {
          setState(() {
            _viewOnlyFlagged = false;
            _viewOnlyCommented = false;
            _currentBoxIndex = 0;
            if (_visibleBoxes.isNotEmpty) {
              _textController.text = _visibleBoxes[0].text;
            }
          });
        } else if (value == 'UI Scale') {
          final double initial = uiScaleNotifier.value;
          double current = initial;
          await showDialog<void>(
            context: context,
            builder: (ctx) {
              return StatefulBuilder(builder: (ctx2, setState2) {
                return AlertDialog(
                  title: const Text('UI Scale'),
                  shape: ShapeBorder.lerp(
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                    0,
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Scale: ${current.toStringAsFixed(2)}x'),
                      const SizedBox(height: 12),
                      Slider(
                        value: current,
                        onChanged: (v) {
                          setState2(() => current = v);
                          uiScaleNotifier.value = v;
                        },
                        min: 0.4,
                        max: 1.6,
                        divisions: 16,
                        label: '${current.toStringAsFixed(2)}x',
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: () {
                              setState2(() => current = 1.0);
                              uiScaleNotifier.value = 1.0;
                            },
                            child: const Text('Reset'),
                          ),
                          TextButton(
                            onPressed: () {
                              uiScaleNotifier.value = initial;
                              Navigator.of(ctx2).pop();
                            },
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(ctx2).pop(),
                      child: const Text('OK'),
                    ),
                  ],
                );
              });
            },
          );
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

  Widget _buildGotoMenuItem() {
    return InkWell(
      onTap: () async {
        if (_visibleBoxes.isEmpty) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('No items to go to.')),
            );
          }
          return;
        }
        final controller = TextEditingController();
        final result = await showDialog<int?>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Go to item'),
            shape: ShapeBorder.lerp(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
              0,
            ),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                hintText: 'Enter item number (1 - ${_visibleBoxes.length})',
                hintStyle: TextStyle(color: Colors.grey[600]),
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
              TextButton(
                onPressed: () {
                  final v = int.tryParse(controller.text);
                  Navigator.of(ctx).pop(v);
                },
                child: const Text('Go'),
              ),
            ],
          ),
        );
        if (result != null) {
          final int target = (result - 1).clamp(0, _visibleBoxes.length - 1);
          _navigateToIndex(target);
        }
      },
      child: const Padding(
        padding: EdgeInsets.symmetric(horizontal: 14.0, vertical: 10.0),
        child: Text('Goto', style: TextStyle(color: Colors.white, fontSize: 16)),
      ),
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

  Widget _buildCommentLabel() {
    final box = _currentVisibleBox();
    final comment = box?.comment;
    if (comment == null || comment.isEmpty) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.only(top: 8.0),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Text(
          'Comment: $comment',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70),
        ),
      ),
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
      final double maxFont = (imageHeight / lineCount).clamp(12, 32).toDouble() * 0.83;
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
        IconButton(
          icon: const Icon(Icons.comment, size: buttonSize),
          tooltip: 'Add Comment',
          onPressed: () async {
            final box = _currentVisibleBox();
            if (box == null) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No item selected.')),
                );
              }
              return;
            }

            final controller = TextEditingController(text: box.comment);
            final result = await showDialog<String>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('Add Comment'),
                shape: ShapeBorder.lerp(
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  RoundedRectangleBorder(borderRadius: BorderRadius.circular(0)),
                  0,
                ),
                content: SizedBox(
                  width: 500,
                  child: TextField(
                    controller: controller,
                    maxLines: 6,
                    decoration: const InputDecoration(
                      hintText: 'Type your comment here...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.zero),
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
                    child: const Text('Save'),
                  ),
                ],
              ),
            );

            if (result != null) {
              setState(() {
                box.comment = result;
                box.isDirty = true;
                if (_viewOnlyCommented && !_visibleBoxes.contains(box)) {
                  _currentBoxIndex = 0;
                  if (_visibleBoxes.isNotEmpty) {
                    _textController.text = _visibleBoxes[0].text;
                  } else {
                    _textController.text = 'No image available';
                  }
                }
              });
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Comment saved.')),
                );
              }
            }
          }
        ),
        const SizedBox(width: 20),
        IconButton(
          padding: const EdgeInsets.all(8),
          constraints: const BoxConstraints(),
          icon: Icon(
            Icons.save,
            size: buttonSize,
            color: _hasUnsavedChanges ? Colors.orangeAccent : darkThemeValues[ThemeStyleKey.fontPrimaryColor],
          ),
          tooltip: _hasUnsavedChanges ? 'Save (unsaved changes)' : 'Save',
          onPressed: _saveCurrent,
        ),
      ],
    );
  }
}
