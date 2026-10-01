import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  late final TextEditingController _employerController;
  late final TextEditingController _roleController;
  late final TextEditingController _industryController;
  late final TextEditingController _companyController;

  bool _saving = false;
  String? _error;
  bool _profileNotFound = false;

  @override
  void initState() {
    super.initState();
    _employerController = TextEditingController(
      text: widget.profile['current_employer'] as String? ?? '',
    );
    _roleController = TextEditingController(
      text: widget.profile['current_role'] as String? ?? '',
    );
    _industryController = TextEditingController(
      text: widget.profile['industry'] as String? ?? '',
    );
    _companyController = TextEditingController(
      text: widget.profile['company'] as String? ?? '',
    );
  }

  @override
  void dispose() {
    _employerController.dispose();
    _roleController.dispose();
    _industryController.dispose();
    _companyController.dispose();
    super.dispose();
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
          'current_employer': _employerController.text.trim(),
          'current_role': _roleController.text.trim(),
          'industry': _industryController.text.trim(),
          'company': _companyController.text.trim(),
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
      setState(() {
        _saving = false;
        _error = 'Something went wrong saving your changes. Please try again.';
      });
    }
  }

  void _signOut() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const VerificationScreen()),
      (_) => false,
    );
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
                    controller: _employerController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Current Employer',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
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
                    controller: _industryController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Industry',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _companyController,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Company',
                      border: OutlineInputBorder(),
                    ),
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
