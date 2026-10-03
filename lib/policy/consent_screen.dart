import 'package:flutter/material.dart';

import '../config/policy_config.dart';
import '../data/account_repository.dart';
import '../lock/lock_service.dart';
import '../lock/session.dart';
import '../screens/welcome_screen.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import 'policy_text.dart';

/// True when this person has not accepted the CURRENT policy version. Not
/// shown on every launch: only when nothing was accepted yet, or the version
/// constant changed.
bool needsConsent(Map<String, dynamic> profile) =>
    profile['policy_version'] != kPolicyVersion;

/// Shown after verification (and after unlocking) when [needsConsent]. The
/// person reads the policy, ticks the box and continues. Without accepting
/// they cannot enter the app; they can go back and sign out.
class ConsentScreen extends StatefulWidget {
  const ConsentScreen({
    super.key,
    required this.profile,
    required this.onAccepted,
    this.repository,
    this.lock,
    this.bundle,
  });

  final Map<String, dynamic> profile;

  /// Called with the profile that now carries the accepted version.
  final void Function(BuildContext context, Map<String, dynamic> profile)
  onAccepted;
  final AccountRepository? repository;
  final LockService? lock;
  final AssetBundle? bundle;

  @override
  State<ConsentScreen> createState() => _ConsentScreenState();
}

class _ConsentScreenState extends State<ConsentScreen> {
  bool _checked = false;
  bool _saving = false;
  String? _error;
  Object? _lastError;

  Future<void> _continue() async {
    setState(() {
      _saving = true;
      _error = null;
      _lastError = null;
    });
    try {
      await (widget.repository ?? AccountRepository()).acceptPolicy(
        widget.profile['id'] as String,
        kPolicyVersion,
      );
      if (!mounted) return;
      widget.onAccepted(context, {
        ...widget.profile,
        'policy_version': kPolicyVersion,
        'policy_accepted_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = friendlyError(e);
        _lastError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('consent-screen'),
      appBar: AppBar(
        title: const Text('Before you start'),
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: PolicyReader(bundle: widget.bundle)),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CheckboxListTile(
                    key: const Key('consent-checkbox'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _checked,
                    onChanged: _saving
                        ? null
                        : (v) => setState(() => _checked = v ?? false),
                    title: const Text(
                      'I have read and accept the privacy policy and community '
                      'rules. (Saya sudah membaca dan menyetujui kebijakan '
                      'privasi dan aturan komunitas.)',
                    ),
                  ),
                  if (_error != null)
                    InlineError(
                      message: _error!,
                      screen: 'Consent',
                      error: _lastError,
                      textKey: const Key('consent-error'),
                    ),
                  const SizedBox(height: 4),
                  FilledButton(
                    key: const Key('consent-continue'),
                    onPressed: (_checked && !_saving) ? _continue : null,
                    child: _saving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Continue'),
                  ),
                  TextButton(
                    key: const Key('consent-back'),
                    onPressed: _saving
                        ? null
                        : () => signOutTo(
                            context,
                            const WelcomeScreen(),
                            lock: widget.lock,
                          ),
                    child: Text(
                      'Back and sign out',
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
