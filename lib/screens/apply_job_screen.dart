import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Job application form (added 17 Sep 2026, Master Plan §3.4 item 7).
///
/// Redone 18 Sep 2026 per Mas Gilang's feedback: the flow now matches
/// LinkedIn's "Easy Apply" — Details, then a read-only Review step the
/// applicant must explicitly confirm, then an on-screen Done step that
/// states the application will be reviewed. There's no more
/// submit-and-pop-back-to-a-snackbar; the confirmation lives on its own
/// screen so it can't be missed.
///
/// The poster can mark CV / LinkedIn / portfolio / cover note as required
/// per job post (see post_job_screen.dart, job_posts.require_*) — the
/// Details step won't let the applicant continue to Review until those
/// are filled in.
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

enum _ApplyStep { details, review, done }

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
  _ApplyStep _step = _ApplyStep.details;

  bool get _requireCv => widget.job['require_cv'] == true;
  bool get _requireLinkedin => widget.job['require_linkedin'] == true;
  bool get _requirePortfolio => widget.job['require_portfolio'] == true;
  bool get _requireCoverNote => widget.job['require_cover_note'] == true;

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

  void _goToReview() {
    if (!_formKey.currentState!.validate()) return;
    if (_requireCv && _cvFile == null) {
      setState(() => _error = 'This job requires a CV to be attached.');
      return;
    }
    setState(() {
      _error = null;
      _step = _ApplyStep.review;
    });
  }

  Future<void> _confirmAndSubmit() async {
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
      setState(() {
        _submitting = false;
        _step = _ApplyStep.done;
      });
    } catch (e) {
      setState(() {
        _submitting = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Apply — ${widget.job['title'] as String? ?? ''}'),
        automaticallyImplyLeading: _step != _ApplyStep.done,
        leading: _step == _ApplyStep.review
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _step = _ApplyStep.details),
              )
            : null,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: switch (_step) {
                _ApplyStep.details => _buildDetailsStep(context),
                _ApplyStep.review => _buildReviewStep(context),
                _ApplyStep.done => _buildDoneStep(context),
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsStep(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _StepHeader(step: 1, total: 3, label: 'Details'),
          const SizedBox(height: 16),
          Text(
            widget.job['company'] as String? ?? '',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          TextFormField(
            controller: _nameController,
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
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Phone (optional)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _linkedinController,
            decoration: InputDecoration(
              labelText: _requireLinkedin
                  ? 'LinkedIn URL (required by this job)'
                  : 'LinkedIn URL (optional)',
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                (_requireLinkedin && (v == null || v.trim().isEmpty))
                ? 'Required by this job'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _portfolioController,
            decoration: InputDecoration(
              labelText: _requirePortfolio
                  ? 'Portfolio / other link (required by this job)'
                  : 'Portfolio / other link (optional)',
              border: const OutlineInputBorder(),
            ),
            validator: (v) =>
                (_requirePortfolio && (v == null || v.trim().isEmpty))
                ? 'Required by this job'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _noteController,
            maxLines: 3,
            decoration: InputDecoration(
              labelText: _requireCoverNote
                  ? 'Cover note (required by this job)'
                  : 'Cover note (optional)',
              border: const OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
            validator: (v) =>
                (_requireCoverNote && (v == null || v.trim().isEmpty))
                ? 'Required by this job'
                : null,
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _pickCv,
            icon: const Icon(Icons.attach_file),
            label: Text(
              _cvFile == null
                  ? (_requireCv
                        ? 'Attach CV (required by this job)'
                        : 'Attach CV (optional, PDF/DOC)')
                  : _cvFile!.name,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _goToReview,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Review Application'),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewStep(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(step: 2, total: 3, label: 'Review'),
        const SizedBox(height: 16),
        Text(
          'Review your application before submitting to '
          '${widget.job['company'] as String? ?? 'the poster'}.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ReviewRow(label: 'Full Name', value: _nameController.text),
                _ReviewRow(label: 'Email', value: _emailController.text),
                _ReviewRow(
                  label: 'Phone',
                  value: _phoneController.text,
                  emptyText: 'Not provided',
                ),
                _ReviewRow(
                  label: 'LinkedIn URL',
                  value: _linkedinController.text,
                  emptyText: 'Not provided',
                ),
                _ReviewRow(
                  label: 'Portfolio / other link',
                  value: _portfolioController.text,
                  emptyText: 'Not provided',
                ),
                _ReviewRow(
                  label: 'Cover note',
                  value: _noteController.text,
                  emptyText: 'Not provided',
                ),
                _ReviewRow(
                  label: 'CV',
                  value: _cvFile?.name ?? '',
                  emptyText: 'Not attached',
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 16),
          Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
        ],
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _submitting ? null : _confirmAndSubmit,
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: _submitting
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Text('Confirm & Submit'),
        ),
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: _submitting
              ? null
              : () => setState(() => _step = _ApplyStep.details),
          child: const Text('Back to Edit'),
        ),
      ],
    );
  }

  Widget _buildDoneStep(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StepHeader(step: 3, total: 3, label: 'Done'),
        const SizedBox(height: 32),
        Icon(Icons.check_circle, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 20),
        Text(
          'Application submitted',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Your application for "${widget.job['title'] as String? ?? ''}" '
          'at ${widget.job['company'] as String? ?? ''} has been sent to '
          'the poster and will be reviewed. You can check its status any '
          'time from this job.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 32),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Text('Back to Job'),
        ),
      ],
    );
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.step,
    required this.total,
    required this.label,
  });

  final int step;
  final int total;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Text(
          'Step $step of $total',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 8),
        Text('· $label', style: theme.textTheme.labelMedium),
      ],
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.label, required this.value, this.emptyText});

  final String label;
  final String value;
  final String? emptyText;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = value.trim().isEmpty ? (emptyText ?? '') : value.trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          Text(
            display,
            style: value.trim().isEmpty
                ? theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
