import 'package:flutter/material.dart';

import '../data/indonesia_cities.dart';

/// A form field that picks a city from [kIndonesiaCities] in a searchable
/// bottom sheet (a plain dropdown of 100+ names is unusable on a phone).
///
/// Reads and writes [controller] so it can replace a free-text city
/// field without touching the code around it. A value already in the
/// controller that isn't in the list (a listing saved back when City was
/// free text) is kept and shown as is until the person picks another.
class CityPickerField extends StatelessWidget {
  const CityPickerField({
    super.key,
    required this.controller,
    this.enabled = true,
    this.validator,
    this.labelText = 'City',
  });

  final TextEditingController controller;
  final bool enabled;
  final String? Function(String?)? validator;
  final String labelText;

  Future<void> _pick(BuildContext context) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CitySheet(selected: controller.text.trim()),
    );
    if (picked != null) {
      controller.value = TextEditingValue(
        text: picked,
        selection: TextSelection.collapsed(offset: picked.length),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      readOnly: true,
      // Picking happens in the sheet: no cursor or text selection (which
      // showed the chosen city highlighted) in the field itself.
      showCursor: false,
      enableInteractiveSelection: false,
      enabled: enabled,
      onTap: () => _pick(context),
      validator: validator,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        suffixIcon: const Icon(Icons.arrow_drop_down),
      ),
    );
  }
}

class _CitySheet extends StatefulWidget {
  const _CitySheet({required this.selected});

  final String selected;

  @override
  State<_CitySheet> createState() => _CitySheetState();
}

class _CitySheetState extends State<_CitySheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final query = _query.trim().toLowerCase();
    final cities = query.isEmpty
        ? kIndonesiaCities
        : kIndonesiaCities
              .where((c) => c.toLowerCase().contains(query))
              .toList();

    return Padding(
      // Keep the list above the keyboard.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                autofocus: true,
                onChanged: (v) => setState(() => _query = v),
                decoration: const InputDecoration(
                  hintText: 'Search city',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            Expanded(
              child: cities.isEmpty
                  ? const Center(child: Text('No city found.'))
                  : ListView.builder(
                      itemCount: cities.length,
                      itemBuilder: (context, i) {
                        final city = cities[i];
                        return ListTile(
                          title: Text(city),
                          trailing: city == widget.selected
                              ? const Icon(Icons.check)
                              : null,
                          onTap: () => Navigator.of(context).pop(city),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
