import 'package:flutter/material.dart';

/// A dropdown you can also type into to narrow the list. Only a value from
/// [options] (or the one already [selected] when the screen opened) can be
/// chosen, so free text never reaches the database.
class SearchableChoice extends StatelessWidget {
  const SearchableChoice({
    super.key,
    required this.fieldKey,
    required this.label,
    required this.controller,
    required this.options,
    required this.selected,
    required this.enabled,
    required this.onSelected,
    this.helper,
    this.errorText,
  });

  final Key fieldKey;
  final String label;
  final String? helper;
  final String? errorText;
  final TextEditingController controller;
  final List<String> options;
  final String? selected;
  final bool enabled;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    final entries = [
      if (selected != null && !options.contains(selected)) selected!,
      ...options,
    ];
    return LayoutBuilder(
      builder: (context, box) => DropdownMenu<String>(
        key: fieldKey,
        controller: controller,
        width: box.maxWidth,
        enabled: enabled,
        label: Text(label),
        helperText: helper,
        errorText: errorText,
        initialSelection: selected,
        enableFilter: true,
        trailingIcon: Icon(
          Icons.arrow_drop_down,
          semanticLabel: 'Show $label options',
        ),
        selectedTrailingIcon: Icon(
          Icons.arrow_drop_up,
          semanticLabel: 'Hide $label options',
        ),
        requestFocusOnTap: true,
        menuHeight: 280,
        dropdownMenuEntries: [
          for (final o in entries)
            DropdownMenuEntry<String>(value: o, label: o),
        ],
        onSelected: onSelected,
      ),
    );
  }
}
