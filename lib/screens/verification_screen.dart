import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/account_repository.dart';
import '../lock/lock_service.dart';
import '../policy/consent_screen.dart';
import '../lock/pin_setup_screen.dart';
import '../lock/session.dart';
import '../util/friendly_error.dart';
import '../widgets/feedback_sheet.dart';

/// Looks up the alumni profile whose email matches and marks it verified.
/// Returns null when there is no match.
typedef EmailVerifier = Future<Map<String, dynamic>?> Function(String email);

Future<Map<String, dynamic>?> defaultVerifyEmail(String email) async {
  final client = Supabase.instance.client;
  final match = await client
      .from('alumni_profiles')
      .select()
      .eq('email', email)
      .maybeSingle();
  if (match == null) return null;

  if (match['verification_status'] != 'verified') {
    await client
        .from('alumni_profiles')
        .update({'verification_status': 'verified'})
        .eq('id', match['id']);
    match['verification_status'] = 'verified';
  }
  return match;
}

/// Demo email-verification screen (scope change 14 Sep: was NIM exact-match,
/// now email exact-match — see PROJECT_NOTES.md Session 3).
///
/// DEMO SCOPE: this is a plain exact-string-match against seeded dummy
/// data in `alumni_profiles.email`. No real auth account is created, no
/// OTP or confirmation email is sent — same dummy-data demo scope as the
/// rest of the project. On a match, verification_status is set to
/// 'verified' directly on the matched row, then the user lands in the app
/// shell (HomeShell) — see PROJECT_NOTES.md Sessions 5 and 9.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    this.lock,
    this.verifyEmail = defaultVerifyEmail,
    this.homeBuilder = defaultHomeBuilder,
    this.accountRepository,
  });

  /// Injectable for tests (consent is saved through it).
  final AccountRepository? accountRepository;

  /// Injectable for tests; defaults to the real [HomeShell].
  final HomeBuilder homeBuilder;

  /// Injectable for tests; defaults to [LockService.shared].
  final LockService? lock;

  /// Injectable for tests; defaults to the Supabase email match.
  final EmailVerifier verifyEmail;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

enum _VerificationState { idle, loading, notFound, error }

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  _VerificationState _state = _VerificationState.idle;
  String? _errorMessage;
  Object? _lastError;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _state = _VerificationState.loading;
      _errorMessage = null;
    });

    try {
      final match = await widget.verifyEmail(email);

      if (match == null) {
        setState(() => _state = _VerificationState.notFound);
        return;
      }

      if (!mounted) return;
      setState(() => _state = _VerificationState.idle);
      await _afterVerified(match, email);
    } catch (e) {
      setState(() {
        _state = _VerificationState.error;
        _errorMessage = friendlyError(e);
        _lastError = e;
      });
    }
  }

  /// Remember this person on the device (id, name and a masked email hint
  /// only) and offer a PIN, then go into the app. If the lock storage fails
  /// for any reason, skip the lock and go straight in: verification itself
  /// already succeeded.
  Future<void> _afterVerified(
    Map<String, dynamic> profile,
    String email,
  ) async {
    final lock = widget.lock ?? LockService.shared;
    var offerPin = false;
    try {
      if (lock.enabled) {
        await lock.remember(
          profileId: profile['id'] as String,
          displayName: profile['name'] as String? ?? '',
          email: email,
        );
        offerPin = !await lock.hasPin();
      }
    } catch (_) {
      offerPin = false;
    }
    if (!mounted) return;
    // First run: Welcome, verify, consent, PIN offer, app.
    if (needsConsent(profile)) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ConsentScreen(
            profile: profile,
            lock: lock,
            repository: widget.accountRepository,
            onAccepted: (ctx, accepted) =>
                _continueAfterConsent(ctx, accepted, lock, offerPin),
          ),
        ),
      );
      return;
    }
    _continueAfterConsent(context, profile, lock, offerPin);
  }

  void _continueAfterConsent(
    BuildContext ctx,
    Map<String, dynamic> profile,
    LockService lock,
    bool offerPin,
  ) {
    if (!offerPin) {
      enterApp(
        ctx,
        profile,
        lock: lock,
        homeBuilder: widget.homeBuilder,
        accountRepository: widget.accountRepository,
      );
      return;
    }
    Navigator.of(ctx).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          lock: lock,
          // The setup screen is replaced by the app once done or skipped.
          onDone: (setupContext) async => enterApp(
            setupContext,
            profile,
            lock: lock,
            homeBuilder: widget.homeBuilder,
            accountRepository: widget.accountRepository,
          ),
        ),
      ),
    );
  }

  void _reset() {
    setState(() {
      _state = _VerificationState.idle;
      _errorMessage = null;
      _emailController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(title: const Text('Verify Alumni Status')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                color: theme.colorScheme.surface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(color: theme.colorScheme.outlineVariant),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: _buildContent(theme),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(ThemeData theme) {
    switch (_state) {
      case _VerificationState.notFound:
        return _NotFoundResult(
          email: _emailController.text.trim(),
          onTryAgain: _reset,
        );
      case _VerificationState.error:
        return _ErrorResult(
          message: _errorMessage!,
          error: _lastError,
          onTryAgain: _reset,
        );
      case _VerificationState.idle:
      case _VerificationState.loading:
        return _VerificationForm(
          formKey: _formKey,
          controller: _emailController,
          loading: _state == _VerificationState.loading,
          onSubmit: _verify,
        );
    }
  }
}

class _VerificationForm extends StatelessWidget {
  const _VerificationForm({
    required this.formKey,
    required this.controller,
    required this.loading,
    required this.onSubmit,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CircleAvatar(
            radius: 28,
            backgroundColor: theme.colorScheme.primaryContainer,
            child: Icon(
              Icons.verified_user_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Verify Your Alumni Status',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter the email on file with UNDIP to confirm your alumni '
            'record. This is a demo check against seeded sample data.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            enabled: !loading,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'name@example.com',
              prefixIcon: Icon(Icons.mail_outline),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Enter your email';
              if (!v.contains('@') || !v.contains('.')) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: loading ? null : onSubmit,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: loading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2.5),
                  )
                : const Text('Verify'),
          ),
        ],
      ),
    );
  }
}

class _NotFoundResult extends StatelessWidget {
  const _NotFoundResult({required this.email, required this.onTryAgain});

  final String email;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.errorContainer,
          child: Icon(
            Icons.person_search_outlined,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'No Matching Record',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'We couldn\'t find an alumni record for "$email" in the demo '
          'dataset. Double-check the email, or try one of the sample demo '
          'accounts.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onTryAgain, child: const Text('Try again')),
      ],
    );
  }
}

class _ErrorResult extends StatelessWidget {
  const _ErrorResult({
    required this.message,
    required this.onTryAgain,
    this.error,
  });

  final Object? error;
  final String message;
  final VoidCallback onTryAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: theme.colorScheme.errorContainer,
          child: Icon(
            Icons.error_outline,
            color: theme.colorScheme.onErrorContainer,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Something Went Wrong',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          message,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: onTryAgain, child: const Text('Try again')),
        TextButton(
          key: const Key('send-feedback'),
          onPressed: () =>
              showFeedbackSheet(context, error: error, screen: 'Verification'),
          child: const Text('Send feedback'),
        ),
      ],
    );
  }
}
