# generic_svg_selector

A Flutter plugin to interactively select parts of any flat SVG by tapping.

## Features

- ✅ Load **any flat SVG** file — body, car, map, etc.
- ✅ Tap to **select/deselect** individual paths
- ✅ **Mirror mode** — tap left side, right side auto-selects
- ✅ **Custom colors** for selected/unselected states
- ✅ **Runtime ID extraction** — no hardcoded body parts
- ✅ Select all / Clear all support

## Installation

```yaml
dependencies:
  generic_svg_selector: ^0.7.0
```

## SVG Requirements

SVG must have `<path id="partName">` elements with unique IDs:

```xml
<svg viewBox="0 0 100 100">
  <path id="head" d="M ..."/>
  <path id="leftArm" d="M ..."/>
  <path id="rightArm" d="M ..."/>
</svg>
```

## Usage

```dart
import 'package:generic_svg_selector/generic_svg_selector.dart';

class MyWidget extends StatefulWidget { ... }

class _MyWidgetState extends State<MyWidget> {
  SvgSelection _selection = const SvgSelection.empty();

  @override
  Widget build(BuildContext context) {
    return GenericSvgSelector(
      assetPath: 'assets/body.svg',
      selection: _selection,
      onSelectionUpdated: (newSelection) {
        setState(() => _selection = newSelection);
      },
    );
  }
}
```

## Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| `assetPath` | `String` | Path to SVG asset |
| `selection` | `SvgSelection` | Current selection state |
| `onSelectionUpdated` | `Function` | Called on tap |
| `mirrored` | `bool` | Mirror left/right selection |
| `selectedColor` | `Color?` | Fill color when selected |
| `unselectedColor` | `Color?` | Fill color when unselected |
| `selectedOutlineColor` | `Color?` | Outline when selected |
| `unselectedOutlineColor` | `Color?` | Outline when unselected |

## SvgSelection API

```dart
// Initialize
SvgSelection.empty()
SvgSelection.fromIds(['head', 'leftArm'])
SvgSelection.allSelected(['head', 'leftArm'])

// Toggle
selection.withToggledId('head')
selection.withToggledId('leftArm', mirror: true)

// Bulk
selection.selectAll()
selection.cleared()

// Query
selection.selectedIds        // ['head', 'leftArm']
selection.isSelected('head') // true/false
```