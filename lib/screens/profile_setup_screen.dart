import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/city_distances.dart';
import '../data/industries.dart';
import '../lock/session.dart';
import '../widgets/searchable_choice.dart';
import 'verification_screen.dart';

/// Lets the verified alumnus update their employment info. Identity fields
/// (name, NIM, faculty, major, graduation year) came from verification and
/// aren't editable here.
class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key, required this.profile});

  final Map<String, dynamic> profile;

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  late final TextEditingController _roleController;
  late final TextEditingController _industryController;
  late final TextEditingController _cityController;
  late final TextEditingController _companyController;

  // Picked from the fixed lists; null/empty means nothing chosen. A value
  // saved before the lists existed is kept as an extra choice so opening
  // this screen and saving never wipes it.
  String? _industry;
  String? _city;

  bool _saving = false;
  String? _error;
  bool _profileNotFound = false;

  @override
  void initState() {
    super.initState();
    _roleController = TextEditingController(
      text: widget.profile['current_role'] as String? ?? '',
    );
    _industry = _nonEmpty(widget.profile['industry']);
    _city = _nonEmpty(widget.profile['city']);
    _industryController = TextEditingController(text: _industry ?? '');
    _cityController = TextEditingController(text: _city ?? '');
    // Company and Current Employer used to be two boxes for the same thing.
    // Show whichever one has a value.
    _companyController = TextEditingController(
      text:
          _nonEmpty(widget.profile['company']) ??
          _nonEmpty(widget.profile['current_employer']) ??
          '',
    );
  }

  @override
  void dispose() {
    _roleController.dispose();
    _industryController.dispose();
    _cityController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  static String? _nonEmpty(Object? v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  // Update-by-id then select-back can legitimately match 0 rows: this
  // demo's data gets reset/reseeded from time to time (see PROJECT_NOTES.md),
  // which assigns fresh ids to every row, so a browser session opened
  // before a reset is left holding a profile id that no longer exists.
  // .select() (a list) instead of .select().single() lets us detect that
  // as "empty list" rather than a thrown PostgrestException.
  Future<Map<String, dynamic>?> _updateById(String id) async {
    final rows = await Supabase.instance.client
        .from('alumni_profiles')
        .update({
          'current_role': _roleController.text.trim(),
          'industry': _industry ?? '',
          'company': _companyController.text.trim(),
          // The old Current Employer column is no longer shown. Keep it equal
          // to Company so nothing stale is left behind until it is dropped.
          'current_employer': _companyController.text.trim(),
          // Only send the city when it changed, so saving the job fields
          // never depends on the city column being writable.
          if (_city != null && _city != _nonEmpty(widget.profile['city']))
            'city': _city,
        })
        .eq('id', id)
        .select();
    final list = rows as List;
    return list.isEmpty ? null : list.first as Map<String, dynamic>;
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
      _profileNotFound = false;
    });

    try {
      var updated = await _updateById(widget.profile['id'] as String);

      if (updated == null) {
        // Our cached id is stale -- look the row up again by NIM (a
        // stable natural key untouched by a reset regenerating ids) and
        // retry once with whatever id it has now.
        final nim = widget.profile['nim'] as String?;
        final fresh = nim == null
            ? null
            : await Supabase.instance.client
                  .from('alumni_profiles')
                  .select('id')
                  .eq('nim', nim)
                  .maybeSingle();
        if (fresh != null) {
          updated = await _updateById(fresh['id'] as String);
        }
      }

      if (updated == null) {
        if (!mounted) return;
        setState(() {
          _saving = false;
          _profileNotFound = true;
          _error =
              "We couldn't find your profile to save to — it may have "
              'changed since you signed in. Please sign out and verify '
              'again.';
        });
        return;
      }

      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      if (!mounted) return;
      // The database refuses a field it has locked with "Only ... can be
      // updated". Say that, instead of a message that suggests retrying.
      final locked =
          e is PostgrestException && e.message.contains('can be updated');
      setState(() {
        _saving = false;
        _error = locked
            ? "Your city can't be saved yet. Please contact the admin."
            : 'Something went wrong saving your changes. Please try again.';
      });
    }
  }

  void _signOut() {
    signOutTo(context, const VerificationScreen());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Employment Info')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _roleController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Current Role',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('profile-company'),
                    controller: _companyController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SearchableChoice(
                    fieldKey: const Key('profile-industry'),
                    label: 'Industry',
                    controller: _industryController,
                    options: kIndustries,
                    selected: _industry,
                    enabled: !_saving,
                    onSelected: (v) => setState(() => _industry = v),
                  ),
                  const SizedBox(height: 16),
                  SearchableChoice(
                    fieldKey: const Key('profile-city'),
                    label: 'City',
                    helper: 'Used for Nearby Alumni',
                    controller: _cityController,
                    options: kNearbyCities,
                    selected: _city,
                    enabled: !_saving,
                    onSelected: (v) => setState(() => _city = v),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    if (_profileNotFound) ...[
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _signOut,
                        child: const Text('Sign Out & Verify Again'),
                      ),
                    ],
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Save'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
