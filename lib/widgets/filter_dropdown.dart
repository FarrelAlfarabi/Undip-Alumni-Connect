import 'package:flutter/material.dart';

/// Sentinel value meaning "no filter selected" in a [FilterDropdown] —
/// always the first entry in its options list.
const kAllFilter = 'All';

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
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      ),
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
