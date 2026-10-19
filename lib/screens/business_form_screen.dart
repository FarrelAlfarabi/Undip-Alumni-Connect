import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../data/marketplace_image_picker.dart';
import '../models/business.dart';
import '../util/safe_url.dart';
import '../widgets/business_photo.dart';
import '../widgets/error_view.dart';

/// What the owner is told after submitting.
const String kBusinessSubmittedMessage =
    'Submitted. An admin will review your business. You can see the status '
    'in "My businesses".';

/// Added to [kBusinessSubmittedMessage] when the business was saved but its
/// photo could not be.
const String kBusinessPhotoFailedMessage =
    ' The photo did not upload. Open the business from "My businesses" and '
    'add it again.';

/// Register a business, or (when [existing] is set) fix a pending or rejected
/// one. The yearly sales band is chosen once and cannot be changed after.
class BusinessFormScreen extends StatefulWidget {
  const BusinessFormScreen({
    super.key,
    required this.ownerId,
    required this.repository,
    this.existing,
    this.pickPhoto = pickListingImage,
  });

  final String ownerId;
  final BusinessRepository repository;
  final Business? existing;

  /// Injectable for tests; defaults to the file picker.
  final ImagePickerFn pickPhoto;

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
  bool _personal = false;
  String? _bandError;
  String? _photoError;
  PickedImage? _picked;
  bool _removePhoto = false;
  String? _error;
  Object? _lastError;
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
    _personal = e?.isPersonal ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _description, _social, _website]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    try {
      final picked = await widget.pickPhoto();
      if (picked == null || !mounted) return;
      setState(() {
        _picked = picked;
        _removePhoto = false;
        _photoError = null;
      });
    } on ImagePickException catch (e) {
      if (!mounted) return;
      setState(() => _photoError = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _photoError = 'Could not open that image. Try another.');
    }
  }

  void _clearPhoto() => setState(() {
    _picked = null;
    _removePhoto = true;
    _photoError = null;
  });

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

  static String? _instagramField(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return 'Required';
    final uri = parseInstagram(t);
    if (uri == null || !uri.host.contains('.')) {
      return 'Enter @username or a link like https://instagram.com/yourshop';
    }
    return null;
  }

  static String? _websiteField(String? v) {
    final t = (v ?? '').trim();
    if (t.isEmpty) return null;
    final uri = parseHttpUrl(t);
    if (uri == null || !uri.host.contains('.')) {
      return 'Enter a link like https://yourshop.com';
    }
    return null;
  }

  /// A typed link in the form the database stores (with https://).
  static String? _clean(String text, {bool instagram = false}) {
    final t = text.trim();
    if (t.isEmpty) return null;
    return (instagram ? parseInstagram(t) : parseHttpUrl(t))?.toString();
  }

  Future<void> _submit() async {
    final fieldsOk = _formKey.currentState!.validate();
    final social = _clean(_social.text, instagram: true);
    final website = _clean(_website.text);
    final bandMsg = (!_isEdit && _band == null)
        ? 'Choose the yearly sales band.'
        : null;
    setState(() => _bandError = bandMsg);
    if (!fieldsOk || bandMsg != null) return;

    setState(() {
      _saving = true;
      _error = null;
      _lastError = null;
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
        isPersonal: _personal,
      );
      final existing = widget.existing;
      final saved = existing == null
          ? await widget.repository.register(widget.ownerId, input)
          : await widget.repository.update(widget.ownerId, existing.id, input);
      // The business is saved first, so a photo that fails never loses what
      // the owner typed.
      var result = saved;
      var photoFailed = false;
      try {
        if (_picked != null) {
          final url = await widget.repository.uploadPhoto(
            ownerId: widget.ownerId,
            fileName: _picked!.name,
            bytes: _picked!.bytes,
          );
          result = await widget.repository.setPhoto(
            widget.ownerId,
            saved.id,
            url,
          );
        } else if (_removePhoto && existing?.photoUrl != null) {
          result = await widget.repository.setPhoto(
            widget.ownerId,
            saved.id,
            null,
          );
        }
      } catch (_) {
        photoFailed = true;
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            photoFailed
                ? '$kBusinessSubmittedMessage$kBusinessPhotoFailedMessage'
                : kBusinessSubmittedMessage,
          ),
        ),
      );
      navigator.pop(result);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = businessErrorMessage(e);
        _lastError = e;
      });
    }
  }

  /// The optional photo: a preview, then Add / Change and Remove buttons.
  Widget _photoSection(ThemeData theme) {
    final existingUrl = _removePhoto ? null : widget.existing?.photoUrl;
    final hasPhoto = _picked != null || (existingUrl?.isNotEmpty ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Photo (optional)', style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(
          'A logo or a picture of your products. JPG, PNG or WebP, up to '
          '2 MB, any size. It is shown cropped to a wide banner, so keep the '
          'main part in the middle. An admin sees it when reviewing.',
          key: const Key('business-photo-help'),
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        if (_picked != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 140,
                width: double.infinity,
                child: Image.memory(
                  _picked!.bytes,
                  key: const Key('business-photo-preview'),
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
              ),
            ),
          )
        else
          BusinessPhoto(url: existingUrl),
        Wrap(
          spacing: 8,
          children: [
            OutlinedButton.icon(
              key: const Key('business-photo-pick'),
              onPressed: _saving ? null : _choosePhoto,
              icon: const Icon(Icons.add_photo_alternate_outlined),
              label: Text(hasPhoto ? 'Change photo' : 'Add photo'),
            ),
            if (hasPhoto)
              TextButton(
                key: const Key('business-photo-remove'),
                onPressed: _saving ? null : _clearPhoto,
                child: const Text('Remove'),
              ),
          ],
        ),
        if (_photoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _photoError!,
              key: const Key('business-photo-error'),
              style: TextStyle(color: theme.colorScheme.error),
            ),
          ),
      ],
    );
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
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: const Key('personal-business'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Personal business'),
                      subtitle: const Text(
                        'Run only by you, the owner. It is still listed '
                        'publicly like any other business.',
                      ),
                      value: _personal,
                      onChanged: _saving
                          ? null
                          : (v) => setState(() => _personal = v),
                    ),
                    const SizedBox(height: 16),
                    _photoSection(theme),
                    const SizedBox(height: 16),
                    Text(
                      'Where people can see it',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Instagram is required, the website is optional. Each '
                      'link can be used by one business only.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _social,
                      enabled: !_saving,
                      keyboardType: TextInputType.text,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Instagram *',
                        hintText: '@username or https://instagram.com/...',
                        border: OutlineInputBorder(),
                      ),
                      validator: _instagramField,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _website,
                      enabled: !_saving,
                      keyboardType: TextInputType.url,
                      decoration: const InputDecoration(
                        labelText: 'Website link (optional)',
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                      ),
                      validator: _websiteField,
                    ),
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
                      InlineError(
                        message: _error!,
                        textKey: const Key('business-form-error'),
                        screen: 'Register a business',
                        error: _lastError,
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
