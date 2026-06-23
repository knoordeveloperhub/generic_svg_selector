import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:generic_svg_selector/src/model/svg_selection.dart';
import 'package:generic_svg_selector/src/service/generic_svg_service.dart';
import 'package:path_drawing/path_drawing.dart';
import 'package:touchable/touchable.dart';

class GenericSvgSelectorWidget extends StatefulWidget {
  const GenericSvgSelectorWidget({
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
  State<GenericSvgSelectorWidget> createState() =>
      _GenericSvgSelectorWidgetState();
}

class _GenericSvgSelectorWidgetState extends State<GenericSvgSelectorWidget> {
  bool _initialized = false;

  @override
  Widget build(BuildContext context) {
    final notifier = GenericSvgService.instance.load(widget.assetPath);
    final colorScheme = Theme.of(context).colorScheme;

    // Effective colors — unselected should be clearly visible
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
        // Error state
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

        // Loading state
        if (data == null) {
          return widget.loadingWidget ??
              const Center(child: CircularProgressIndicator.adaptive());
        }

        // Initialize selection ONCE when data first arrives
        if (!_initialized) {
          _initialized = true;
          final ids = data.paths.map((p) => p.id).toList();
          if (widget.selection.ids.isEmpty && ids.isNotEmpty) {
            // Synchronously notify — no postFrameCallback needed
            Future.microtask(() {
              widget.onSelectionUpdated(SvgSelection.fromIds(ids));
            });
          }
        }

        // Use current selection, but if still empty use data ids as unselected
        final effectiveSelection = widget.selection.ids.isEmpty
            ? SvgSelection.fromIds(data.paths.map((p) => p.id).toList())
            : widget.selection;

      return LayoutBuilder(
        builder: (context, constraints) { 
      
          if (constraints.maxHeight == double.infinity ||
              constraints.maxHeight == 0) {
            return const Center(
                child: Text('NO HEIGHT — wrap in Expanded or SizedBox'));
          }
      
          return CanvasTouchDetector(
            gesturesToOverride: const [GestureType.onTapDown],
            builder: (ctx) => CustomPaint(
              size: Size(constraints.maxWidth, constraints.maxHeight),
              painter: _SvgPainter(
                data: data,
                selection: effectiveSelection,
                context: ctx,
                selectedColor: selectedColor,
                unselectedColor: unselectedColor,
                selectedOutlineColor: selectedOutlineColor,
                unselectedOutlineColor: unselectedOutlineColor,
                onTap: (id) {
                  widget.onSelectionUpdated(
                    effectiveSelection.withToggledId(id,
                        mirror: widget.mirrored),
                  );
                },
              ),
            ),
          );
        },
      );
      },
    );
  }
}

class _SvgPainter extends CustomPainter {
  _SvgPainter({
    required this.data,
    required this.selection,
    required this.context,
    required this.selectedColor,
    required this.unselectedColor,
    required this.selectedOutlineColor,
    required this.unselectedOutlineColor,
    required this.onTap,
  });

  final SvgData data;
  final SvgSelection selection;
  final BuildContext context;
  final Color selectedColor;
  final Color unselectedColor;
  final Color selectedOutlineColor;
  final Color unselectedOutlineColor;
  final void Function(String id) onTap;



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

    // Transform matrix — tap detection ke liye
    final matrix = Float64List(16);
    Matrix4.identity()
      ..translate(dx, dy, 0)
      ..scale(scale, scale, 1)
      ..copyIntoArray(matrix);

    canvas.save();
    canvas.translate(dx, dy);
    canvas.scale(scale);

    final touchyCanvas = TouchyCanvas(context, canvas);

    for (final pathData in data.paths) {
      final id = pathData.id;
      final isSelected = selection.isSelected(id);

      Path rawPath;
      try {
        rawPath = parseSvgPathData(pathData.pathData);
      } catch (e) {
        continue;
      }

      final tappablePath = rawPath.transform(matrix);

      // Fill — raw path (canvas transformed hai)
      canvas.drawPath(
        rawPath,
        Paint()
          ..color = isSelected ? selectedColor : unselectedColor
          ..style = PaintingStyle.fill,
      );

      // Outline — raw path (canvas transformed hai)
      canvas.drawPath(
        rawPath,
        Paint()
          ..color = isSelected ? selectedOutlineColor : unselectedOutlineColor
          ..strokeWidth = 1.5 / scale
          ..style = PaintingStyle.stroke,
      );

      // Tap detection — transformed path (screen coords), transparent paint
      touchyCanvas.drawPath(
        tappablePath,
        Paint()
          ..color = Colors.transparent
          ..style = PaintingStyle.fill,
        onTapDown: (_) => onTap(id),
      );
    }

    canvas.restore();
  }



@override
  bool shouldRepaint(_SvgPainter old) =>
      old.selection != selection ||
      old.data != data || // pehle old.data != old.data tha — yeh bug tha!
      old.selectedColor != selectedColor ||
      old.unselectedColor != unselectedColor ||
      old.selectedOutlineColor != selectedOutlineColor ||
      old.unselectedOutlineColor != unselectedOutlineColor;
}
