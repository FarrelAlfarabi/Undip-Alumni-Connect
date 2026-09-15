import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  @override
  void initState() {
    super.initState();
    _employerController = TextEditingController(
        text: widget.profile['current_employer'] as String? ?? '');
    _roleController = TextEditingController(
        text: widget.profile['current_role'] as String? ?? '');
    _industryController =
        TextEditingController(text: widget.profile['industry'] as String? ?? '');
    _companyController =
        TextEditingController(text: widget.profile['company'] as String? ?? '');
  }

  @override
  void dispose() {
    _employerController.dispose();
    _roleController.dispose();
    _industryController.dispose();
    _companyController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final updated = await Supabase.instance.client
          .from('alumni_profiles')
          .update({
            'current_employer': _employerController.text.trim(),
            'current_role': _roleController.text.trim(),
            'industry': _industryController.text.trim(),
            'company': _companyController.text.trim(),
          })
          .eq('id', widget.profile['id'])
          .select()
          .single();

      if (!mounted) return;
      Navigator.of(context).pop(updated);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = e.toString();
      });
    }
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
                      'Save failed: $_error',
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
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
