/// A class that holds the selection state of SVG elements by their IDs.
///
/// Unlike a fixed model, this works with any flat SVG — IDs are read
/// at runtime from the SVG file itself.
class SvgSelection {
  final Map<String, bool> _selections;

  /// Creates an [SvgSelection] from an existing map.
  const SvgSelection(Map<String, bool> selections) : _selections = selections;

  /// Creates an empty [SvgSelection].
  const SvgSelection.empty() : _selections = const {};

  /// Creates an [SvgSelection] from a list of IDs, all unselected.
  factory SvgSelection.fromIds(List<String> ids) {
    return SvgSelection({for (final id in ids) id: false});
  }

  /// Creates an [SvgSelection] from a list of IDs, all selected.
  factory SvgSelection.allSelected(List<String> ids) {
    return SvgSelection({for (final id in ids) id: true});
  }

  /// Whether the element with the given [id] is selected.
  bool isSelected(String id) => _selections[id] ?? false;

  /// All IDs currently tracked.
  List<String> get ids => _selections.keys.toList();

  /// Unmodifiable view of the selection map.
  Map<String, bool> get selections => Map.unmodifiable(_selections);

  /// Returns all selected IDs.
  List<String> get selectedIds =>
      _selections.entries.where((e) => e.value).map((e) => e.key).toList();

  /// Returns a new [SvgSelection] with the given [id] toggled.
  ///
  /// If [mirror] is true and the id contains 'left' or 'right',
  /// the opposite side is toggled as well.
  SvgSelection withToggledId(String id, {bool mirror = false}) {
    if (!_selections.containsKey(id)) return this;

    final map = Map<String, bool>.from(_selections);
    map[id] = !(map[id] ?? false);

    if (mirror) {
      if (id.contains('left') || id.contains('Left')) {
        final mirrored =
            id.replaceAll('left', 'right').replaceAll('Left', 'Right');
        if (map.containsKey(mirrored)) map[mirrored] = map[id]!;
      } else if (id.contains('right') || id.contains('Right')) {
        final mirrored =
            id.replaceAll('right', 'left').replaceAll('Right', 'Left');
        if (map.containsKey(mirrored)) map[mirrored] = map[id]!;
      }
    }

    return SvgSelection(map);
  }

  /// Returns a new [SvgSelection] with the given [id] set to [selected].
  SvgSelection withId(String id, {required bool selected}) {
    if (!_selections.containsKey(id)) return this;
    final map = Map<String, bool>.from(_selections);
    map[id] = selected;
    return SvgSelection(map);
  }

  /// Returns a new [SvgSelection] with all IDs deselected.
  SvgSelection cleared() {
    return SvgSelection({for (final id in _selections.keys) id: false});
  }

  /// Returns a new [SvgSelection] with all IDs selected.
  SvgSelection selectAll() {
    return SvgSelection({for (final id in _selections.keys) id: true});
  }

  /// Merges new [ids] into this selection (keeps existing state).
  SvgSelection mergeIds(List<String> ids) {
    final map = Map<String, bool>.from(_selections);
    for (final id in ids) {
      map.putIfAbsent(id, () => false);
    }
    return SvgSelection(map);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SvgSelection &&
          runtimeType == other.runtimeType &&
          _selectionsEqual(other._selections);

  bool _selectionsEqual(Map<String, bool> other) {
    if (_selections.length != other.length) return false;
    for (final entry in _selections.entries) {
      if (other[entry.key] != entry.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(
        _selections.entries.map((e) => Object.hash(e.key, e.value)),
      );

  @override
  String toString() => 'SvgSelection($_selections)';
}
