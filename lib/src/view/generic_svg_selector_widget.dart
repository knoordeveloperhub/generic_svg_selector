import 'dart:math';

import 'package:flutter/material.dart';
import 'package:generic_svg_selector/src/model/svg_selection.dart';
import 'package:generic_svg_selector/src/service/generic_svg_service.dart';

class GenericSvgSelector extends StatefulWidget {
  const GenericSvgSelector({
    required this.assetPath,
    required this.selection,
    required this.onSelectionUpdated,
    this.mirrored = false,
    this.selectedColor,
    this.unselectedColor,
    this.selectedOutlineColor,
    this.unselectedOutlineColor,
    this.loadingWidget,
    this.errorWidget,
    super.key,
  });

  final String assetPath;
  final SvgSelection selection;
  final void Function(SvgSelection selection) onSelectionUpdated;
  final bool mirrored;
  final Color? selectedColor;
  final Color? unselectedColor;
  final Color? selectedOutlineColor;
  final Color? unselectedOutlineColor;
  final Widget? loadingWidget;
  final Widget? errorWidget;

  @override
  State<GenericSvgSelector> createState() =>
      _GenericSvgSelectorState();
}

class _GenericSvgSelectorState extends State<GenericSvgSelector> {
  bool _initialized = false;

  /// SVG path string ko Flutter Path mein convert karo — path_drawing replace
  Path _parseSvgPath(String d) {
    final path = Path();
    // Simple SVG path parser — M, L, C, Z, c, l commands support
    final commands = RegExp(
      r'([MmLlCcZzHhVvSsQqTtAa])|(-?\d*\.?\d+(?:[eE][+-]?\d+)?)',
    ).allMatches(d);

    String currentCmd = '';
    final nums = <double>[];

    void flushNums() {
      switch (currentCmd) {
        case 'M':
          for (var i = 0; i + 1 < nums.length; i += 2) {
            if (i == 0)
              {path.moveTo(nums[i], nums[i + 1]);}
            else
              {path.lineTo(nums[i], nums[i + 1]);}
          }
        case 'm':
          for (var i = 0; i + 1 < nums.length; i += 2) {
            if (i == 0)
              {path.relativeMoveTo(nums[i], nums[i + 1]);}
            else
              {path.relativeLineTo(nums[i], nums[i + 1]);}
          }
        case 'L':
          for (var i = 0; i + 1 < nums.length; i += 2) {
            path.lineTo(nums[i], nums[i + 1]);
          }
        case 'l':
          for (var i = 0; i + 1 < nums.length; i += 2) {
            path.relativeLineTo(nums[i], nums[i + 1]);
          }
        case 'H':
          for (final x in nums) {path.lineTo(x, 0);}
        case 'h':
          for (final x in nums) {path.relativeLineTo(x, 0);}
        case 'V':
          for (final y in nums){ path.lineTo(0, y);}
        case 'v':
          for (final y in nums) {path.relativeLineTo(0, y);}
        case 'C':
          for (var i = 0; i + 5 < nums.length; i += 6) {
            path.cubicTo(
              nums[i],
              nums[i + 1],
              nums[i + 2],
              nums[i + 3],
              nums[i + 4],
              nums[i + 5],
            );
          }
        case 'c':
          for (var i = 0; i + 5 < nums.length; i += 6) {
            path.relativeCubicTo(
              nums[i],
              nums[i + 1],
              nums[i + 2],
              nums[i + 3],
              nums[i + 4],
              nums[i + 5],
            );
          }
        case 'Z':
        case 'z':
          path.close();
      }
      nums.clear();
    }

    for (final match in commands) {
      final cmd = match.group(1);
      final num = match.group(2);
      if (cmd != null) {
        if (currentCmd.isNotEmpty) flushNums();
        currentCmd = cmd;
        if (cmd == 'Z' || cmd == 'z') {
          flushNums();
        }
      } else if (num != null) {
        nums.add(double.parse(num));
      }
    }
    if (currentCmd.isNotEmpty) flushNums();

    return path;
  }

  void _onTapDown(TapDownDetails details, SvgData data, Size size) {
    final tapPoint = details.localPosition;

    final double scale = min(
      size.width / data.viewBoxWidth,
      size.height / data.viewBoxHeight,
    );
    final scaledW = data.viewBoxWidth * scale;
    final scaledH = data.viewBoxHeight * scale;
    final dx = (size.width - scaledW) / 2.0;
    final dy = (size.height - scaledH) / 2.0;

    // Tap point ko SVG coordinate space mein convert karo
    final svgX = (tapPoint.dx - dx) / scale;
    final svgY = (tapPoint.dy - dy) / scale;
    final svgPoint = Offset(svgX, svgY);

    // Reverse order mein check karo (top layer pehle)
    for (final pathData in data.paths.reversed) {
      Path rawPath;
      try {
        rawPath = _parseSvgPath(pathData.pathData);
      } catch (_) {
        continue;
      }
      if (rawPath.contains(svgPoint)) {
        widget.onSelectionUpdated(
          widget.selection.withToggledId(
            pathData.id,
            mirror: widget.mirrored,
          ),
        );
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final notifier = GenericSvgService.instance.load(widget.assetPath);
    final colorScheme = Theme.of(context).colorScheme;

    final selectedColor = widget.selectedColor ?? colorScheme.primary;
    final unselectedColor =
        widget.unselectedColor ?? colorScheme.surfaceContainerHighest;
    final selectedOutlineColor =
        widget.selectedOutlineColor ?? colorScheme.onPrimary;
    final unselectedOutlineColor =
        widget.unselectedOutlineColor ?? colorScheme.outline;

    return ValueListenableBuilder<SvgData?>(
      valueListenable: notifier,
      builder: (context, data, _) {
        if (data == null &&
            GenericSvgService.instance.hasError(widget.assetPath)) {
          return widget.errorWidget ??
              const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.broken_image_outlined,
                        size: 48, color: Colors.red),
                    SizedBox(height: 8),
                    Text('Failed to load SVG'),
                  ],
                ),
              );
        }

        if (data == null) {
          return widget.loadingWidget ??
              const Center(child: CircularProgressIndicator.adaptive());
        }

        if (!_initialized) {
          _initialized = true;
          final ids = data.paths.map((p) => p.id).toList();
          if (widget.selection.ids.isEmpty && ids.isNotEmpty) {
            Future.microtask(() {
              widget.onSelectionUpdated(SvgSelection.fromIds(ids));
            });
          }
        }

        final effectiveSelection = widget.selection.ids.isEmpty
            ? SvgSelection.fromIds(data.paths.map((p) => p.id).toList())
            : widget.selection;

        return SizedBox.expand(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final size = Size(constraints.maxWidth, constraints.maxHeight);
              return GestureDetector(
                onTapDown: (details) => _onTapDown(details, data, size),
                child: CustomPaint(
                  size: size,
                  painter: _SvgPainter(
                    data: data,
                    selection: effectiveSelection,
                    selectedColor: selectedColor,
                    unselectedColor: unselectedColor,
                    selectedOutlineColor: selectedOutlineColor,
                    unselectedOutlineColor: unselectedOutlineColor,
                    pathParser: _parseSvgPath,
                  ),
                  child: SizedBox(
                    width: size.width,
                    height: size.height,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _SvgPainter extends CustomPainter {
  _SvgPainter({
    required this.data,
    required this.selection,
    required this.selectedColor,
    required this.unselectedColor,
    required this.selectedOutlineColor,
    required this.unselectedOutlineColor,
    required this.pathParser,
  });

  final SvgData data;
  final SvgSelection selection;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectedOutlineColor;
  final Color unselectedOutlineColor;
  final Path Function(String) pathParser;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final double scale = min(
      size.width / data.viewBoxWidth,
      size.height / data.viewBoxHeight,
    );

    final scaledW = data.viewBoxWidth * scale;
    final scaledH = data.viewBoxHeight * scale;
    final dx = (size.width - scaledW) / 2.0;
    final dy = (size.height - scaledH) / 2.0;

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    for (final pathData in data.paths) {
      final isSelected = selection.isSelected(pathData.id);

      Path rawPath;
      try {
        rawPath = pathParser(pathData.pathData);
      } catch (_) {
        continue;
      }

      canvas.drawPath(
        rawPath,
        Paint()
          ..color = isSelected ? selectedColor : unselectedColor
          ..style = PaintingStyle.fill,
      );

      canvas.drawPath(
        rawPath,
        Paint()
          ..color = isSelected ? selectedOutlineColor : unselectedOutlineColor
          ..strokeWidth = 1.5 / scale
          ..style = PaintingStyle.stroke,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(_SvgPainter old) =>
      old.selection != selection ||
      old.data != data ||
      old.selectedColor != selectedColor ||
      old.unselectedColor != unselectedColor ||
      old.selectedOutlineColor != selectedOutlineColor ||
      old.unselectedOutlineColor != unselectedOutlineColor;
}
