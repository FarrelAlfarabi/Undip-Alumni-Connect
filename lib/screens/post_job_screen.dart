import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A small curated set of common titles for the roles Ikafe/FEB alumni
/// actually post (business, finance, and adjacent tech roles — matches
/// this app's faculty-wide scope per PROJECT_NOTES.md, not a generic
/// jobs-site list). Merged with titles already used in real job_posts
/// rows so the suggestions improve as the board fills up.
const List<String> _commonJobTitles = [
  'Accountant',
  'Auditor',
  'Business Analyst',
  'Business Development Manager',
  'Data Analyst',
  'Digital Marketing Specialist',
  'Finance Manager',
  'Financial Analyst',
  'HR Generalist',
  'Investment Analyst',
  'Marketing Manager',
  'Operations Manager',
  'Product Manager',
  'Project Manager',
  'Relationship Manager',
  'Risk Analyst',
  'Sales Executive',
  'Software Engineer',
  'Supply Chain Analyst',
  'Tax Consultant',
];

/// Post-a-job form (Day 5). No visual paywall here — anyone verified can
/// post. Contact-button gating is Day 6's job, on the (not yet built) job
/// detail view.
class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key, required this.posterId});

  final String posterId;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _companyController = TextEditingController();
  final _industryController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  bool _notifyOnApply = true;
  bool _requireCv = false;
  bool _requireLinkedin = false;
  bool _requirePortfolio = false;
  bool _requireCoverNote = false;

  bool _saving = false;
  String? _error;

  List<String> _titleOptions = _commonJobTitles;

  @override
  void initState() {
    super.initState();
    _loadTitleOptions();
  }

  // Best-effort: if this fails (offline, RLS, whatever), the curated
  // static list above is still there as a fallback — autocomplete is a
  // convenience, not something the form depends on to work.
  Future<void> _loadTitleOptions() async {
    try {
      final rows = await Supabase.instance.client
          .from('job_posts')
          .select('title');
      final existingTitles = List<Map<String, dynamic>>.from(rows as List)
          .map((r) => r['title'] as String?)
          .whereType<String>()
          .where((t) => t.trim().isNotEmpty);

      final merged = <String>{..._commonJobTitles, ...existingTitles}.toList()
        ..sort();
      if (mounted) setState(() => _titleOptions = merged);
    } catch (_) {
      // Keep the static fallback list — see comment above.
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _companyController.dispose();
    _industryController.dispose();
    _descriptionController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await Supabase.instance.client.from('job_posts').insert({
        'posted_by': widget.posterId,
        'title': _titleController.text.trim(),
        'company': _companyController.text.trim(),
        'industry': _industryController.text.trim(),
        'description': _descriptionController.text.trim(),
        'contact_info': _contactController.text.trim(),
        'notify_on_apply': _notifyOnApply,
        'require_cv': _requireCv,
        'require_linkedin': _requireLinkedin,
        'require_portfolio': _requirePortfolio,
        'require_cover_note': _requireCoverNote,
      });

      if (!mounted) return;
      Navigator.of(context).pop(true);
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
      appBar: AppBar(title: const Text('Post a Job')),
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
                    Autocomplete<String>(
                      textEditingController: _titleController,
                      optionsBuilder: (textEditingValue) {
                        final query = textEditingValue.text
                            .trim()
                            .toLowerCase();
                        if (query.isEmpty) {
                          return const Iterable<String>.empty();
                        }
                        return _titleOptions.where(
                          (title) => title.toLowerCase().contains(query),
                        );
                      },
                      fieldViewBuilder:
                          (context, controller, focusNode, onFieldSubmitted) {
                            return TextFormField(
                              controller: controller,
                              focusNode: focusNode,
                              enabled: !_saving,
                              decoration: const InputDecoration(
                                labelText: 'Job Title',
                                border: OutlineInputBorder(),
                              ),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Required'
                                  : null,
                            );
                          },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _companyController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Company',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _industryController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Industry',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      enabled: !_saving,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Description',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contactController,
                      enabled: !_saving,
                      decoration: const InputDecoration(
                        labelText: 'Contact Info (email, phone, etc.)',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _notifyOnApply,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _notifyOnApply = v),
                      title: const Text('Notify me when someone applies'),
                      subtitle: const Text(
                        'Demo scope: shown as an applicant count on this '
                        'job, not a real push/email notification.',
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Require applicants to provide',
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _requireCv,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _requireCv = v ?? false),
                      title: const Text('CV'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _requireLinkedin,
                      onChanged: _saving
                          ? null
                          : (v) =>
                                setState(() => _requireLinkedin = v ?? false),
                      title: const Text('LinkedIn URL'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _requirePortfolio,
                      onChanged: _saving
                          ? null
                          : (v) =>
                                setState(() => _requirePortfolio = v ?? false),
                      title: const Text('Portfolio / other link'),
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      value: _requireCoverNote,
                      onChanged: _saving
                          ? null
                          : (v) =>
                                setState(() => _requireCoverNote = v ?? false),
                      title: const Text('Cover note'),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        'Post failed: $_error',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Post Job'),
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
