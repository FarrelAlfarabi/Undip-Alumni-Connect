import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/cities.dart';
import '../data/marketplace_image_picker.dart';
import '../data/marketplace_messages.dart';
import '../data/marketplace_repository.dart';
import '../data/marketplace_validation.dart';
import '../models/marketplace_listing.dart';
import '../widgets/marketplace_demo_notice.dart';
import 'marketplace_screen.dart' show ListingImage;
import '../widgets/error_view.dart';

/// Create or edit a listing. Pops with the saved [MarketplaceListing], or
/// null if the user backed out. Shows the "what happens next" message
/// itself before popping.
class MarketplaceFormScreen extends StatefulWidget {
  const MarketplaceFormScreen({
    super.key,
    required this.sellerId,
    required this.repository,
    this.businessId,
    this.existing,
    this.defaultCity,
    this.pickImage = pickListingImage,
  });

  final String sellerId;
  final MarketplaceRepository repository;

  /// The approved business a NEW product is added to. Not needed when
  /// editing.
  final String? businessId;

  /// Set when editing.
  final MarketplaceListing? existing;
  final String? defaultCity;
  final ImagePickerFn pickImage;

  @override
  State<MarketplaceFormScreen> createState() => _MarketplaceFormScreenState();
}

class _MarketplaceFormScreenState extends State<MarketplaceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _price;
  late final TextEditingController _shop;
  late final TextEditingController _contact;
  String? _category;
  String? _city;
  PickedImage? _picked;
  bool _saving = false;
  String? _error;
  Object? _lastError;
  String? _photoError;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _title = TextEditingController(text: e?.title);
    _description = TextEditingController(text: e?.description);
    _price = TextEditingController(text: e?.priceIdr.toString());
    final startCity = (e?.city ?? widget.defaultCity ?? '').trim();
    _city = startCity.isEmpty ? null : startCity;
    _shop = TextEditingController(text: e?.shopUrl);
    _contact = TextEditingController(text: e?.contactInfo);
    _category = e?.category;
    _contact.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    for (final c in [_title, _description, _price, _shop, _contact]) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasPhoto =>
      _picked != null || (widget.existing?.imageUrl.isNotEmpty ?? false);

  Future<void> _choosePhoto() async {
    try {
      final img = await widget.pickImage();
      if (img == null) return;
      checkListingImage(img.name, img.bytes.length);
      setState(() {
        _picked = img;
        _photoError = null;
      });
    } on ImagePickException catch (e) {
      setState(() => _photoError = e.message);
    } catch (_) {
      setState(() => _photoError = 'Could not read that image.');
    }
  }

  Future<void> _submit() async {
    final fieldsOk = _formKey.currentState!.validate();
    final photoOk = _hasPhoto;
    final contactMsg = MarketplaceValidation.shopOrContact(
      _shop.text,
      _contact.text,
    );
    setState(() {
      _photoError = photoOk ? _photoError : 'Add a photo';
      _error = contactMsg;
    });
    if (!fieldsOk || !photoOk || contactMsg != null) return;

    setState(() {
      _saving = true;
      _error = null;
      _lastError = null;
    });

    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      var imageUrl = widget.existing?.imageUrl ?? '';
      if (_picked != null) {
        imageUrl = await widget.repository.uploadImage(
          sellerId: widget.sellerId,
          fileName: _picked!.name,
          bytes: _picked!.bytes,
        );
      }
      final input = MarketplaceListingInput(
        title: _title.text.trim(),
        description: _description.text.trim(),
        priceIdr: int.parse(_price.text.trim()),
        category: _category!,
        city: _city!,
        imageUrl: imageUrl,
        shopUrl: _shop.text.trim().isEmpty ? null : _shop.text.trim(),
        contactInfo: _contact.text.trim().isEmpty ? null : _contact.text.trim(),
      );
      final existing = widget.existing;
      final saved = existing == null
          ? await widget.repository.create(
              widget.sellerId,
              widget.businessId!,
              input,
            )
          : await widget.repository.update(widget.sellerId, existing.id, input);

      final message = existing == null
          ? kSubmittedMessage
          : (existing.businessId != null &&
                    existing.status == ListingStatus.approved
                ? kEditedBusinessMessage
                : (existing.status == ListingStatus.approved
                      ? kEditedApprovedMessage
                      : kEditedMessage));
      messenger.showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 7)),
      );
      navigator.pop(saved);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = marketplaceErrorMessage(e);
        _lastError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Only the old seed listings (no business) go back to review on edit.
    final editingApproved =
        _isEdit &&
        widget.existing!.status == ListingStatus.approved &&
        widget.existing!.businessId == null;

    return Scaffold(
      appBar: AppBar(title: Text(_isEdit ? 'Edit product' : 'Add a product')),
      body: Column(
        children: [
          const MarketplaceDemoNotice(),
          Expanded(
            child: SafeArea(
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
                          if (editingApproved) ...[
                            _Callout(
                              icon: Icons.rate_review_outlined,
                              text:
                                  'Saving changes sends this listing back to '
                                  'review. It stays hidden until an admin '
                                  'approves it again.',
                            ),
                            const SizedBox(height: 16),
                          ],
                          _PhotoPicker(
                            picked: _picked,
                            existingUrl: widget.existing?.imageUrl,
                            error: _photoError,
                            enabled: !_saving,
                            onTap: _choosePhoto,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _title,
                            enabled: !_saving,
                            maxLength: 100,
                            decoration: const InputDecoration(
                              labelText: 'Title',
                              border: OutlineInputBorder(),
                            ),
                            validator: MarketplaceValidation.title,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _description,
                            enabled: !_saving,
                            maxLines: 4,
                            maxLength: 2000,
                            decoration: const InputDecoration(
                              labelText: 'Description',
                              border: OutlineInputBorder(),
                              alignLabelWithHint: true,
                            ),
                            validator: MarketplaceValidation.description,
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _price,
                            enabled: !_saving,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                              labelText: 'Price (whole rupiah)',
                              prefixText: 'Rp ',
                              border: OutlineInputBorder(),
                            ),
                            validator: MarketplaceValidation.price,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: _category,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'Category',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final c in kMarketplaceCategories)
                                DropdownMenuItem(value: c, child: Text(c)),
                            ],
                            onChanged: _saving
                                ? null
                                : (v) => setState(() => _category = v),
                            validator: MarketplaceValidation.category,
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            key: const Key('city-dropdown'),
                            initialValue: _city,
                            isExpanded: true,
                            decoration: const InputDecoration(
                              labelText: 'City',
                              border: OutlineInputBorder(),
                            ),
                            items: [
                              for (final c in citiesWith(_city))
                                DropdownMenuItem(value: c, child: Text(c)),
                            ],
                            onChanged: _saving
                                ? null
                                : (v) => setState(() => _city = v),
                            validator: MarketplaceValidation.city,
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'How buyers reach you',
                            style: theme.textTheme.titleSmall,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Add a shop link, contact info, or both. There is '
                            'no checkout in the app.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _shop,
                            enabled: !_saving,
                            keyboardType: TextInputType.url,
                            decoration: const InputDecoration(
                              labelText: 'Online shop link (optional)',
                              hintText: 'https://...',
                              border: OutlineInputBorder(),
                            ),
                            validator: MarketplaceValidation.shopUrl,
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _contact,
                            enabled: !_saving,
                            maxLength: 300,
                            decoration: const InputDecoration(
                              labelText: 'Contact info (optional)',
                              hintText:
                                  'WhatsApp, phone, email, social media...',
                              border: OutlineInputBorder(),
                            ),
                          ),
                          if (_contact.text.trim().isNotEmpty) ...[
                            const SizedBox(height: 8),
                            _Callout(
                              icon: Icons.visibility_outlined,
                              text:
                                  'Your contact info will be visible to other '
                                  'members.',
                            ),
                          ],
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            _lastError == null
                                ? Text(
                                    _error!,
                                    style: TextStyle(
                                      color: theme.colorScheme.error,
                                    ),
                                  )
                                : InlineError(
                                    message: _error!,
                                    screen: 'Add a product',
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
                                    _isEdit ? 'Save changes' : 'Post product',
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Callout extends StatelessWidget {
  const _Callout({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhotoPicker extends StatelessWidget {
  const _PhotoPicker({
    required this.picked,
    required this.existingUrl,
    required this.error,
    required this.enabled,
    required this.onTap,
  });

  final PickedImage? picked;
  final String? existingUrl;
  final String? error;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasExisting = (existingUrl ?? '').isNotEmpty;
    Widget preview;
    if (picked != null) {
      preview = AspectRatio(
        aspectRatio: 3 / 2,
        child: Image.memory(
          picked!.bytes,
          fit: BoxFit.cover,
          semanticLabel: 'Photo you picked',
        ),
      );
    } else if (hasExisting) {
      preview = ListingImage(
        url: existingUrl!,
        semanticLabel: 'Current photo of this listing',
      );
    } else {
      preview = AspectRatio(
        aspectRatio: 3 / 2,
        child: Container(
          color: theme.colorScheme.surfaceContainerHigh,
          alignment: Alignment.center,
          child: Icon(
            Icons.add_photo_alternate_outlined,
            size: 40,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(borderRadius: BorderRadius.circular(12), child: preview),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: enabled ? onTap : null,
          icon: const Icon(Icons.photo_outlined),
          label: Text(
            picked != null || hasExisting ? 'Change photo' : 'Choose photo',
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            error ?? 'One photo. JPG, PNG or WebP, up to 2 MB.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: error == null
                  ? theme.colorScheme.onSurfaceVariant
                  : theme.colorScheme.error,
            ),
          ),
        ),
      ],
    );
  }
}
