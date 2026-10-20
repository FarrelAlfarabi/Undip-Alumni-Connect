import 'package:flutter/material.dart';

/// Sentinel value meaning "no filter selected" in a [FilterDropdown] —
/// always the first entry in its options list.
const kAllFilter = 'All';

/// One look for every search box and filter in a search+filter bar: rounded,
/// softly filled, same height. [FilterDropdown], [ClearableSearchField] and
/// the dense [SearchableChoice] all use it, so they line up.
InputDecorationTheme filterFieldTheme(BuildContext context) {
  final scheme = Theme.of(context).colorScheme;
  OutlineInputBorder border(Color color, [double width = 1]) =>
      OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: color, width: width),
      );
  return InputDecorationTheme(
    isDense: true,
    filled: true,
    fillColor: scheme.surfaceContainerLowest,
    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
    constraints: const BoxConstraints(minHeight: 48, maxHeight: 48),
    suffixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 24),
    border: border(scheme.outlineVariant),
    enabledBorder: border(scheme.outlineVariant),
    focusedBorder: border(scheme.primary, 1.5),
  );
}

/// A labeled dropdown filter, shared by every screen with a search+filter
/// bar (Alumni Directory, Job Board, Messages).
class FilterDropdown extends StatelessWidget {
  const FilterDropdown({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final String value;
  final List<String> options;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      borderRadius: BorderRadius.circular(12),
      decoration: InputDecoration(labelText: label)
          .applyDefaults(filterFieldTheme(context)),
      items: options
          .map(
            (o) => DropdownMenuItem(
              value: o,
              child: Text(o, overflow: TextOverflow.ellipsis),
            ),
          )
          .toList(),
      onChanged: (v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Distinct, sorted values of [field] across [rows], prefixed with
/// [kAllFilter] for use as a [FilterDropdown]'s options.
List<String> distinctSortedValues(
  List<Map<String, dynamic>> rows,
  String field,
) {
  final values =
      rows
          .map((r) => r[field]?.toString())
          .whereType<String>()
          .where((v) => v.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
  return [kAllFilter, ...values];
}

/// A search [TextField] with a clear (×) button that appears once there's
/// text to clear — shared by every screen with a search+filter bar.
class ClearableSearchField extends StatelessWidget {
  const ClearableSearchField({
    super.key,
    required this.controller,
    required this.hintText,
  });

  final TextEditingController controller;
  final String hintText;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        return TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: value.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.clear),
                    tooltip: 'Clear search',
                    onPressed: controller.clear,
                  ),
          ).applyDefaults(filterFieldTheme(context)),
        );
      },
    );
  }
}

/// A "Clear filters" text button, shown only while [active] — placed
/// below a screen's filter row so search text and every dropdown can be
/// reset in one tap instead of one field at a time. Shared by every
/// screen with a search+filter bar.
class ClearFiltersButton extends StatelessWidget {
  const ClearFiltersButton({
    super.key,
    required this.active,
    required this.onPressed,
  });

  final bool active;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    if (!active) return const SizedBox.shrink();
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.filter_alt_off_outlined, size: 18),
        label: const Text('Hapus filter'),
      ),
    );
  }
}
