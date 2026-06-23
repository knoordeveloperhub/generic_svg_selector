import 'package:flutter/material.dart';
import 'package:generic_svg_selector/generic_svg_selector.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Generic SVG Selector Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const SvgSelectorDemo(),
    );
  }
}

class SvgSelectorDemo extends StatefulWidget {
  const SvgSelectorDemo({super.key});

  @override
  State<SvgSelectorDemo> createState() => _SvgSelectorDemoState();
}

class _SvgSelectorDemoState extends State<SvgSelectorDemo> {
  SvgSelection _selection = const SvgSelection.empty();
  bool _mirrored = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SVG Selector Demo'),
        actions: [
          // Mirror toggle
          IconButton(
            icon: Icon(_mirrored ? Icons.flip : Icons.flip_outlined),
            tooltip: 'Mirror mode',
            onPressed: () => setState(() => _mirrored = !_mirrored),
          ),
          // Clear all
          IconButton(
            icon: const Icon(Icons.clear_all),
            tooltip: 'Clear selection',
            onPressed: () => setState(() => _selection = _selection.cleared()),
          ),
          // Select all
          IconButton(
            icon: const Icon(Icons.select_all),
            tooltip: 'Select all',
            onPressed: () =>
                setState(() => _selection = _selection.selectAll()),
          ),
        ],
      ),
      body: Column(
        children: [
          // SVG Selector
          Expanded(
            child: GenericSvgSelector(
              assetPath: 'assets/body.svg',
              selection: _selection,
              mirrored: _mirrored,
              selectedColor: Colors.red,
              unselectedColor: Colors.green,
              selectedOutlineColor: Colors.black,
              unselectedOutlineColor: Colors.greenAccent,
              onSelectionUpdated: (newSelection) {
                setState(() => _selection = newSelection);
              },
            ),
          ),

          // Selected IDs list
          Container(
            height: 120,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: Colors.grey.shade100,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Selected (${_selection.selectedIds.length}):',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: SingleChildScrollView(
                    child: Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _selection.selectedIds
                          .map(
                            (id) => Chip(
                              label: Text(id),
                              onDeleted: () {
                                setState(() {
                                  _selection = _selection.withId(
                                    id,
                                    selected: false,
                                  );
                                });
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
