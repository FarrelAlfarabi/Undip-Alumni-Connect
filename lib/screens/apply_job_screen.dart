import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Job application form (added 17 Sep 2026, Master Plan §3.4 item 7).
/// Collects a CV upload plus LinkedIn/portfolio links, on top of the
/// contact info the app already gates behind subscription — an
/// application is a step further than "here's how to reach the poster."
///
/// Gated behind subscription, same mechanism as messaging and contacting
/// a job poster (see job_detail_screen.dart) — applying is at least as
/// much "contacting the poster" as the existing paid action.
class ApplyJobScreen extends StatefulWidget {
  const ApplyJobScreen({super.key, required this.job, required this.applicant});

  final Map<String, dynamic> job;
  final Map<String, dynamic> applicant;

  @override
  State<ApplyJobScreen> createState() => _ApplyJobScreenState();
}

class _ApplyJobScreenState extends State<ApplyJobScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(
    text: widget.applicant['name'] as String? ?? '',
  );
  late final _emailController = TextEditingController(
    text: widget.applicant['email'] as String? ?? '',
  );
  final _phoneController = TextEditingController();
  final _linkedinController = TextEditingController();
  final _portfolioController = TextEditingController();
  final _noteController = TextEditingController();

  PlatformFile? _cvFile;
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _linkedinController.dispose();
    _portfolioController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickCv() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx'],
    );
    if (file == null) return;
    setState(() => _cvFile = file);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _error = null;
    });

    try {
      final client = Supabase.instance.client;
      String? cvPath;

      if (_cvFile != null) {
        final bytes = await _cvFile!.xFile.readAsBytes();
        final safeName = _cvFile!.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
        cvPath =
            '${widget.job['id']}/${DateTime.now().millisecondsSinceEpoch}_$safeName';
        await client.storage.from('cvs').uploadBinary(cvPath, bytes);
      }

      await client.from('job_applications').insert({
        'job_post_id': widget.job['id'],
        'applicant_id': widget.applicant['id'],
        'full_name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'phone': _phoneController.text.trim(),
        'linkedin_url': _linkedinController.text.trim(),
        'portfolio_url': _portfolioController.text.trim(),
        'cover_note': _noteController.text.trim(),
        'cv_path': cvPath,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('Apply — ${widget.job['title'] as String? ?? ''}'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      widget.job['company'] as String? ?? '',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _phoneController,
                      enabled: !_submitting,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Phone (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _linkedinController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'LinkedIn URL (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _portfolioController,
                      enabled: !_submitting,
                      decoration: const InputDecoration(
                        labelText: 'Portfolio / other link (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _noteController,
                      enabled: !_submitting,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Cover note (optional)',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _submitting ? null : _pickCv,
                      icon: const Icon(Icons.attach_file),
                      label: Text(
                        _cvFile == null
                            ? 'Attach CV (optional, PDF/DOC)'
                            : _cvFile!.name,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Application failed: $_error',
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _submitting ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _submitting
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Submit Application'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
