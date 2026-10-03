import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../models/business.dart';
import '../util/safe_url.dart';

/// What the owner is told after submitting.
const String kBusinessSubmittedMessage =
    'Submitted. An admin will review your business. You can see the status '
    'in "My businesses".';

/// Register a business, or (when [existing] is set) fix a pending or rejected
/// one. The yearly sales band is chosen once and cannot be changed after.
class BusinessFormScreen extends StatefulWidget {
  const BusinessFormScreen({
    super.key,
    required this.ownerId,
    required this.repository,
    this.existing,
  });

  final String ownerId;
  final BusinessRepository repository;
  final Business? existing;

  @override
  State<BusinessFormScreen> createState() => _BusinessFormScreenState();
}

class _BusinessFormScreenState extends State<BusinessFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _description;
  late final TextEditingController _social;
  late final TextEditingController _website;
  String? _category;
  BusinessBand? _band;
  String? _bandError;
  String? _linkError;
  String? _error;
  bool _saving = false;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name);
    _description = TextEditingController(text: e?.description);
    _social = TextEditingController(text: e?.socialLink);
    _website = TextEditingController(text: e?.websiteLink);
    _category = e?.category;
    _band = e?.requestedBand;
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _social, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  static String? _requiredName(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (t.length < 2) return 'Name must be at least 2 characters';
    if (t.length > 100) return 'Name must be 100 characters or fewer';
    return null;
  }

  static String? _requiredDescription(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    if (t.length > 500) return 'Description must be 500 characters or fewer';
    return null;
  }

  static String? _linkField(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final uri = parseHttpUrl(t);
    if (uri == null || !uri.host.contains('.')) {
      return 'Enter a link like https://instagram.com/yourshop';
    }
    return null;
  }

  /// A typed link in the form the database stores (with https://).
  static String? _clean(String text) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return parseHttpUrl(t)?.toString();
  }

  Future<void> _submit() async {
    final fieldsOk = _formKey.currentState!.validate();
    final social = _clean(_social.text);
    final website = _clean(_website.text);
    final linkMsg = (social == null && website == null)
        ? 'Add an Instagram or social link, a website link, or both.'
        : null;
    final bandMsg = (!_isEdit && _band == null)
        ? 'Choose the yearly sales band.'
        : null;
    setState(() {
      _linkError = linkMsg;
      _bandError = bandMsg;
    });
    if (!fieldsOk || linkMsg != null || bandMsg != null) return;

    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      final input = BusinessInput(
        name: _name.text.trim(),
        description: _description.text.trim(),
        category: _category!,
        socialLink: social,
        websiteLink: website,
        band: _band,
      );
      final existing = widget.existing;
      final saved = existing == null
          ? await widget.repository.register(widget.ownerId, input)
          : await widget.repository.update(widget.ownerId, existing.id, input);
      messenger.showSnackBar(
        const SnackBar(content: Text(kBusinessSubmittedMessage)),
      );
      navigator.pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = businessErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEdit ? 'Edit business' : 'Register a business'),
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
                    if (widget.existing?.status == BusinessStatus.rejected) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Not approved: '
                          '${widget.existing!.rejectionReason ?? 'no reason given'}. '
                          'Fix it and send it again.',
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    TextFormField(
                      controller: _name,
                      enabled: !_saving,
                      maxLength: 100,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Business name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: _requiredName,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _description,
                      enabled: !_saving,
                      maxLines: 3,
                      maxLength: 500,
                      decoration: const InputDecoration(
                        labelText: 'Short description *',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: _requiredDescription,
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      initialValue: _category,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Category *',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final c in kBusinessCategories)
                          DropdownMenuItem(value: c, child: Text(c)),
                      ],
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _category = v),
                      validator: (v) =>
                          (v == null || v.isEmpty) ? 'Choose a category' : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Where people can see it',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Add at least one link. Each link can be used by one '
                      'business only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _social,
                      enabled: !_saving,
                      keyboardType: TextInputType.url,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Instagram or social link',
                        hintText: 'https://instagram.com/...',
                        border: OutlineInputBorder(),
                      ),
                      validator: _linkField,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _website,
                      enabled: !_saving,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Website link',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                      ),
                      validator: _linkField,
                    ),
                    if (_linkError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        _linkError!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Text('Yearly sales *', style: theme.textTheme.titleSmall),
                    const SizedBox(height: 4),
                    Text(
                      _isEdit
                          ? 'The band was chosen when you registered and '
                                'cannot be changed.'
                          : 'Choose honestly. You cannot change it after you '
                                'submit. An admin checks it.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    RadioGroup<BusinessBand>(
                      groupValue: _band,
                      onChanged: (v) {
                        if (_saving || _isEdit) return;
                        setState(() {
                          _band = v;
                          _bandError = null;
                        });
                      },
                      child: Column(
                        children: [
                          for (final b in BusinessBand.values)
                            RadioListTile<BusinessBand>(
                              key: Key('band-${b.name}'),
                              value: b,
                              enabled: !_isEdit && !_saving,
                              contentPadding: EdgeInsets.zero,
                              title: Text(b.label),
                              subtitle: Text(b.range),
                            ),
                        ],
                      ),
                    ),
                    if (_bandError != null)
                      Text(
                        _bandError!,
                        style: TextStyle(color: theme.colorScheme.error),
                      ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Text(
                        _error!,
                        key: const Key('business-form-error'),
                        style: TextStyle(color: theme.colorScheme.error),
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
                          : Text(
                              _isEdit
                                  ? 'Save and send again'
                                  : 'Submit for review',
                            ),
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
