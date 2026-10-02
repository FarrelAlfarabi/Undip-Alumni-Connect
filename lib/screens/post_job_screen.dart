import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/job_industries.dart';
import '../util/friendly_error.dart';

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

/// Post-a-job form (Day 5), also used to edit one of your own jobs. No visual paywall here — anyone verified can
/// post. Contact-button gating is Day 6's job, on the (not yet built) job
/// detail view.
class PostJobScreen extends StatefulWidget {
  const PostJobScreen({super.key, required this.posterId, this.existing});

  final String posterId;

  /// The job being edited, or null to post a new one.
  final Map<String, dynamic>? existing;

  @override
  State<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends State<PostJobScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  // Autocomplete asserts that focusNode and textEditingController are
  // either both given or both null, so the title field owns both.
  final _titleFocusNode = FocusNode();
  final _companyController = TextEditingController();
  String? _industry;
  final _descriptionController = TextEditingController();
  final _contactController = TextEditingController();
  bool get _isEdit => widget.existing != null;

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
    final job = widget.existing;
    if (job != null) {
      _titleController.text = job['title'] as String? ?? '';
      _companyController.text = job['company'] as String? ?? '';
      _industry = (job['industry'] as String?)?.trim();
      if (_industry?.isEmpty == true) _industry = null;
      _descriptionController.text = job['description'] as String? ?? '';
      _contactController.text = job['contact_info'] as String? ?? '';
      _notifyOnApply = job['notify_on_apply'] != false;
      _requireCv = job['require_cv'] == true;
      _requireLinkedin = job['require_linkedin'] == true;
      _requirePortfolio = job['require_portfolio'] == true;
      _requireCoverNote = job['require_cover_note'] == true;
    }
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
    _titleFocusNode.dispose();
    _companyController.dispose();
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
      final client = Supabase.instance.client;
      if (_isEdit) {
        // Goes through a function that checks the caller posted this job.
        await client.rpc(
          'update_job_post',
          params: {
            'p_job': widget.existing!['id'],
            'p_poster': widget.posterId,
            'p_title': _titleController.text.trim(),
            'p_company': _companyController.text.trim(),
            'p_industry': _industry,
            'p_description': _descriptionController.text.trim(),
            'p_contact_info': _contactController.text.trim(),
            'p_notify_on_apply': _notifyOnApply,
            'p_require_cv': _requireCv,
            'p_require_linkedin': _requireLinkedin,
            'p_require_portfolio': _requirePortfolio,
            'p_require_cover_note': _requireCoverNote,
          },
        );
      } else {
        await client.from('job_posts').insert({
          'posted_by': widget.posterId,
          'title': _titleController.text.trim(),
          'company': _companyController.text.trim(),
          'industry': _industry,
          'description': _descriptionController.text.trim(),
          'contact_info': _contactController.text.trim(),
          'notify_on_apply': _notifyOnApply,
          'require_cv': _requireCv,
          'require_linkedin': _requireLinkedin,
          'require_portfolio': _requirePortfolio,
          'require_cover_note': _requireCoverNote,
        });
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _saving = false;
        _error = friendlyError(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit Job' : 'Post a Job')),
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
                      focusNode: _titleFocusNode,
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
                    DropdownButtonFormField<String>(
                      initialValue: _industry,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Industry',
                        border: OutlineInputBorder(),
                      ),
                      // A job saved before this was a fixed list may have an
                      // industry that isn't in it; keep it selectable.
                      items: [
                        for (final i in {
                          ...kJobIndustries,
                          if (_industry != null) _industry!,
                        })
                          DropdownMenuItem(value: i, child: Text(i)),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _industry = v),
                      validator: (v) => v == null ? 'Choose an industry' : null,
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
                        '${_isEdit ? 'Save' : 'Post'} failed. $_error',
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
                          : Text(_isEdit ? 'Save changes' : 'Post Job'),
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
