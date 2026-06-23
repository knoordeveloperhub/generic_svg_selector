import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:xml/xml.dart';

/// A single parsed SVG path element.
class SvgPathData {
  /// The id attribute of the <path> element.
  final String id;

  /// The raw "d" attribute string of the <path> element.
  final String pathData;

  /// Creates an [SvgPathData].
  const SvgPathData({required this.id, required this.pathData});
}

/// Holds the parsed SVG data: viewBox dimensions and all flat paths.
class SvgData {
  /// ViewBox width of the SVG.
  final double viewBoxWidth;

  /// ViewBox height of the SVG.
  final double viewBoxHeight;

  /// All parsed paths with their IDs.
  final List<SvgPathData> paths;

  /// Creates an [SvgData].
  const SvgData({
    required this.viewBoxWidth,
    required this.viewBoxHeight,
    required this.paths,
  });
}

/// Loads and caches flat SVG files, extracting <path id="..."> elements.
///
/// SVG must be flat — direct <path> children of <svg> with id attributes.
class GenericSvgService {
  GenericSvgService._();

  static final GenericSvgService _instance = GenericSvgService._();

  /// Singleton instance.
  static GenericSvgService get instance => _instance;

  final Map<String, ValueNotifier<SvgData?>> _notifiers = {};
  final Map<String, bool> _hasError = {};

  /// Returns a [ValueNotifier] for the SVG at [assetPath].
  ///
  /// Notifier value is null while loading. Check [hasError] after null
  /// persists to distinguish loading vs error.
  ValueNotifier<SvgData?> load(String assetPath) {
    if (_notifiers.containsKey(assetPath)) {
      return _notifiers[assetPath]!;
    }
    final notifier = ValueNotifier<SvgData?>(null);
    _notifiers[assetPath] = notifier;
    _loadAndParse(assetPath, notifier);
    return notifier;
  }

  /// Whether the given [assetPath] had a load error.
  bool hasError(String assetPath) => _hasError[assetPath] ?? false;

  /// Clears cache for a specific asset (forces reload).
  void evict(String assetPath) {
    _notifiers.remove(assetPath);
    _hasError.remove(assetPath);
  }

  /// Clears entire cache.
  void clearAll() {
    _notifiers.clear();
    _hasError.clear();
  }


  Future<void> _loadAndParse(
    String assetPath,
    ValueNotifier<SvgData?> notifier,
  ) async {
    try {
      final svgString = await rootBundle.loadString(assetPath);
      final document = XmlDocument.parse(svgString);
      final svgElement = document.findElements('svg').first;

      double vbWidth = 300;
      double vbHeight = 150;
      final viewBoxAttr = svgElement.getAttribute('viewBox');

      if (viewBoxAttr != null) {
        final parts = viewBoxAttr.trim().split(RegExp(r'[\s,]+'));
        if (parts.length >= 4) {
          vbWidth = double.tryParse(parts[2]) ?? vbWidth;
          vbHeight = double.tryParse(parts[3]) ?? vbHeight;
        }
      } else {
        final w = svgElement.getAttribute('width');
        final h = svgElement.getAttribute('height');
        if (w != null)
          {vbWidth =
              double.tryParse(w.replaceAll(RegExp(r'[^\d.]'), '')) ?? vbWidth;}
        if (h != null)
          {vbHeight =
              double.tryParse(h.replaceAll(RegExp(r'[^\d.]'), '')) ?? vbHeight;}
      }

      final paths = <SvgPathData>[];
      for (final element in svgElement.childElements) {
        _extractPaths(element, paths);
      }

      notifier.value = SvgData(
        viewBoxWidth: vbWidth,
        viewBoxHeight: vbHeight,
        paths: paths,
      );
    } catch (e, stack) {
      debugPrint('[GenericSvgService] Failed to load "$assetPath": $e');
      debugPrint('$stack');
      _hasError[assetPath] = true;
    }
  }
  
  
  /// Recursively extracts <path> elements that have an id attribute.
  /// Works for both flat SVGs and SVGs with <g> groups.
  void _extractPaths(XmlElement element, List<SvgPathData> paths) {
    if (element.localName == 'path') {
      final id = element.getAttribute('id');
      final d = element.getAttribute('d');
      if (id != null && id.isNotEmpty && d != null && d.isNotEmpty) {
        paths.add(SvgPathData(id: id, pathData: d));
      }
    }
    // Recurse into children (handles <g> groups too)
    for (final child in element.childElements) {
      _extractPaths(child, paths);
    }
  }
}
