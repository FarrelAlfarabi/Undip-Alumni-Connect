import 'package:flutter/material.dart';

import '../data/city_distances.dart';
import '../data/profile_fields.dart';
import '../theme.dart';
import '../widgets/searchable_choice.dart';

/// Profile > Kota, Ubah. Pick the city I live in. Pops the updated profile row.
class ProfileCityScreen extends StatefulWidget {
  const ProfileCityScreen({super.key, required this.profile, this.save});

  final Map<String, dynamic> profile;
  final ProfileFieldSaver? save;

  @override
  State<ProfileCityScreen> createState() => _ProfileCityScreenState();
}

class _ProfileCityScreenState extends State<ProfileCityScreen> {
  late String? _city = _clean(widget.profile['city']);
  late final _controller = TextEditingController(text: _city ?? '');
  bool _saving = false;
  String? _error;

  static String? _clean(Object? v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final updated = await (widget.save ?? saveProfileFields)(
        widget.profile['id'] as String,
        {'city': _city},
      );
      if (!mounted) return;
      // No row back means nothing was stored.
      if (updated == null) throw StateError('city not saved');
      Navigator.of(context).pop(updated);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = 'Kota belum tersimpan. Coba lagi.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Kota')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SearchableChoice(
                fieldKey: const Key('city-field'),
                label: 'Kota',
                helper: 'Kota tempat kamu tinggal',
                controller: _controller,
                options: kNearbyCities,
                selected: _city,
                enabled: !_saving,
                onSelected: (v) => setState(() => _city = v),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(
                  _error!,
                  key: const Key('city-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _saving || _city == null ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: AppTheme.black,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
