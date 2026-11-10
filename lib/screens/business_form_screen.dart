import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../data/business_repository.dart';
import '../data/category_repository.dart';
import '../data/marketplace_image_picker.dart';
import 'photo_adjust_screen.dart';
import '../models/business.dart';
import '../util/safe_url.dart';
import '../widgets/business_photo.dart';
import '../widgets/error_view.dart';
import '../widgets/image_size_hint.dart';
import '../widgets/searchable_choice.dart';

/// What the owner is told after submitting.
const String kBusinessSubmittedMessage =
    'Permintaanmu sudah kami terima. Admin akan meninjau bisnismu dan kamu '
    'akan mendapat pemberitahuan saat ada keputusan. Status bisa dilihat di '
    '"My businesses".';

/// Added to [kBusinessSubmittedMessage] when the business was saved but its
/// photo could not be.
const String kBusinessPhotoFailedMessage =
    ' Fotonya belum terunggah. Buka bisnisnya dari "My businesses" lalu '
    'tambahkan lagi.';

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
  late final TextEditingController _nib;
  late final TextEditingController _categoryText;
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
    _nib = TextEditingController(text: e?.nib);
    _category = e?.category;
    _categoryText = TextEditingController(text: _category ?? '');
    CategoryRepository.shared.load();
    _band = e?.requestedBand;
    _personal = e?.isPersonal ?? false;
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _description,
      _social,
      _website,
      _nib,
      _categoryText,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _choosePhoto() async {
    try {
      final raw = await widget.pickPhoto();
      if (raw == null || !mounted) return;
      final picked = await PhotoAdjust.run(context, raw);
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
      var nibFailed = false;
      // The NIB is saved after the business too. It is optional; a number
      // that did not change is not sent again (that would take its tick).
      final nib = cleanNib(_nib.text);
      if (nib != existing?.nib) {
        try {
          result = await widget.repository.setNib(
            widget.ownerId,
            saved.id,
            nib,
          );
        } catch (_) {
          nibFailed = true;
        }
      }
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
            '$kBusinessSubmittedMessage'
            '${photoFailed ? kBusinessPhotoFailedMessage : ''}'
            '${nibFailed ? tr(' NIB belum tersimpan, coba lagi lewat Edit.') : ''}',
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
        Text(tr('Photo (optional)'), style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        const SizedBox(height: 8),
        if (_picked != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 3 / 2,
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
          BusinessPhoto(url: existingUrl, semanticLabel: _name.text),
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
                child: Text(tr('Remove')),
              ),
          ],
        ),
        const ImageSizeHint(),
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
                          trf('Not approved: {0}. Fix it and send it again.', [
                            widget.existing!.rejectionReason ??
                                tr('no reason given'),
                          ]),
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
                      decoration: InputDecoration(
                        labelText: tr('Business name *'),
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
                      decoration: InputDecoration(
                        labelText: tr('Short description *'),
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                      validator: _requiredDescription,
                    ),
                    const SizedBox(height: 8),
                    FormField<String>(
                      key: const Key('category-dropdown'),
                      initialValue: _category,
                      validator: (v) => CategoryRepository.shared.validate(
                        v,
                        current: widget.existing?.category,
                      ),
                      builder: (field) => ValueListenableBuilder<List<String>>(
                        valueListenable: CategoryRepository.shared.names,
                        builder: (context, names, _) => SearchableChoice(
                          fieldKey: const Key('category-choice'),
                          label: tr('Category *'),
                          controller: _categoryText,
                          options: names,
                          selected: _category,
                          enabled: !_saving,
                          errorText: field.errorText,
                          onSelected: (v) {
                            setState(() => _category = v);
                            field.didChange(v);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      key: const Key('personal-business'),
                      contentPadding: EdgeInsets.zero,
                      title: Text(tr('Personal business')),
                      subtitle: Text(
                        tr(
                          'Run only by you, the owner. It is still listed '
                          'publicly like any other business.',
                        ),
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
                      tr('Where people can see it'),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      tr(
                        'Instagram is required, the website is optional. Each '
                        'link can be used by one business only.',
                      ),
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
                      decoration: InputDecoration(
                        labelText: tr('Instagram *'),
                        hintText: tr('@username or https://instagram.com/...'),
                        border: OutlineInputBorder(),
                      ),
                      validator: _instagramField,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _website,
                      enabled: !_saving,
                      keyboardType: TextInputType.url,
                      decoration: InputDecoration(
                        labelText: tr('Website link (optional)'),
                        hintText: 'https://...',
                        border: OutlineInputBorder(),
                      ),
                      validator: _websiteField,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      key: const Key('nib-field'),
                      controller: _nib,
                      enabled: !_saving,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: tr('NIB (opsional)'),
                        helperText: tr(
                          'Nomor Induk Berusaha, 13 digit. Akan dicek admin. '
                          'Kalau lolos, usahamu dapat tanda centang biru.',
                        ),
                        helperMaxLines: 3,
                        border: OutlineInputBorder(),
                      ),
                      validator: nibFieldError,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      tr('Yearly sales *'),
                      style: theme.textTheme.titleSmall,
                    ),
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
