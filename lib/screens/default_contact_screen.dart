import 'package:flutter/material.dart';

import '../data/contact_repository.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';

/// Profile > Settings > Default contact to share. One free-text contact
/// (WhatsApp, email, Instagram, Telegram, phone, anything). It only fills the
/// box when I accept a request; I still confirm it every time.
class DefaultContactScreen extends StatefulWidget {
  const DefaultContactScreen({
    super.key,
    required this.profileId,
    this.repository,
  });

  final String profileId;
  final ContactRepository? repository;

  @override
  State<DefaultContactScreen> createState() => _DefaultContactScreenState();
}

class _DefaultContactScreenState extends State<DefaultContactScreen> {
  late final ContactRepository _repo = widget.repository ?? ContactRepository();
  final _text = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  String? _loadError;
  String? _error;
  Object? _lastError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final current = await _repo.defaultContact(widget.profileId);
      if (!mounted) return;
      _text.text = current ?? '';
      setState(() => _loading = false);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _loadError = friendlyLoadError('your default contact', e);
        _lastError = e;
      });
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await _repo.setDefaultContact(widget.profileId, _text.text);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            _text.text.trim().isEmpty
                ? 'Default contact removed. Your email will be used.'
                : 'Default contact saved.',
          ),
        ),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = contactErrorMessage(e);
        _lastError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Default contact to share')),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _loadError != null
            ? ErrorView(
                message: _loadError!,
                screen: 'Default contact',
                error: _lastError,
                onRetry: _load,
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'When you accept a contact request, this is filled in '
                      'for you. You can still change it each time, and nothing '
                      'is shared until you tap Accept.',
                      style: theme.textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('default-contact-field'),
                      controller: _text,
                      enabled: !_saving,
                      maxLength: kSharedContactMax,
                      decoration: const InputDecoration(
                        labelText: 'Contact to share',
                        hintText: 'For example: WA +62 812..., IG @name',
                        helperText:
                            'Any kind: WhatsApp, phone, email, Instagram, '
                            'Telegram, LinkedIn... Leave empty to use your '
                            'email.',
                        helperMaxLines: 3,
                        border: OutlineInputBorder(),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 8),
                      InlineError(
                        message: _error!,
                        textKey: const Key('default-contact-error'),
                        screen: 'Default contact',
                        error: _lastError,
                      ),
                    ],
                    const SizedBox(height: 16),
                    FilledButton(
                      key: const Key('default-contact-save'),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                              ),
                            )
                          : const Text('Save'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
