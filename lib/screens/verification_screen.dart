import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../auth/login_api.dart';
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

/// The server function verify_alumni_email() does the match and sets the
/// status. The app can no longer write verification_status itself.
Future<Map<String, dynamic>?> defaultVerifyEmail(String email) async {
  final result = await Supabase.instance.client.rpc(
    'verify_alumni_email',
    params: {'p_email': email},
  );
  return profileFromVerifyResult(result);
}

/// Turns the function's result into a profile, or null when there is no match
/// or the person is not verified (for example an admin marked them failed).
Map<String, dynamic>? profileFromVerifyResult(Object? result) {
  Object? row = result;
  if (result is List) {
    if (result.isEmpty) return null;
    row = result.first;
  }
  if (row is! Map) return null;
  final profile = Map<String, dynamic>.from(row);
  return profile['verification_status'] == 'verified' ? profile : null;
}

/// Demo email-verification screen (scope change 14 Sep: was NIM exact-match,
/// now email exact-match — see PROJECT_NOTES.md Session 3).
///
/// DEMO SCOPE: this is a plain exact-string-match against seeded dummy
/// data in `alumni_profiles.email`. No real auth account is created, no
/// OTP or confirmation email is sent — same dummy-data demo scope as the
/// rest of the project. On a match, the server function verify_alumni_email()
/// sets verification_status to 'verified', then the user lands in the app
/// shell (HomeShell) — see PROJECT_NOTES.md Sessions 5 and 9.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    this.lock,
    this.verifyEmail = defaultVerifyEmail,
    this.homeBuilder = defaultHomeBuilder,
    this.accountRepository,
    this.loginApi,
  });

  /// Email code login. Null means the old email match, unless the build was
  /// made with REAL_LOGIN=true, which uses [SupabaseLoginApi].
  final LoginApi? loginApi;

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
  final _codeController = TextEditingController();
  bool _codeSent = false;

  _VerificationState _state = _VerificationState.idle;
  String? _errorMessage;
  Object? _lastError;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  LoginApi? get _login =>
      widget.loginApi ?? (kRealLogin ? SupabaseLoginApi() : null);

  /// Step 1 of the code login: send the code. Step 2: check it.
  Future<void> _verifyWithCode(LoginApi api, String email) async {
    setState(() {
      _state = _VerificationState.loading;
      _errorMessage = null;
    });
    try {
      if (!_codeSent) {
        if (!await api.emailKnown(email)) {
          setState(() => _state = _VerificationState.notFound);
          return;
        }
        await api.sendCode(email);
        setState(() {
          _codeSent = true;
          _state = _VerificationState.idle;
        });
        return;
      }
      final profile = await api.verifyCode(email, _codeController.text);
      if (profile == null) {
        setState(() => _state = _VerificationState.notFound);
        return;
      }
      if (!mounted) return;
      setState(() => _state = _VerificationState.idle);
      await _afterVerified(profile, email);
    } catch (e) {
      setState(() {
        _state = _VerificationState.error;
        _errorMessage = friendlyError(e);
        _lastError = e;
      });
    }
  }

  Future<void> _verify() async {
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();
    final api = _login;
    if (api != null) return _verifyWithCode(api, email);

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
      _codeSent = false;
      _codeController.clear();
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
          codeController: _codeSent ? _codeController : null,
          loading: _state == _VerificationState.loading,
          onSubmit: _verify,
          onChangeEmail: _reset,
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
    this.codeController,
    this.onChangeEmail,
  });

  /// Shown instead of the email box once a code was sent.
  final TextEditingController? codeController;
  final VoidCallback? onChangeEmail;

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
            'Enter the email the Ikafe team has on file for you to confirm '
            'your alumni record.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (codeController != null) ...[
            Text(
              'We sent a 6 digit code to ${controller.text.trim()}. '
              'Enter it below.',
              key: const Key('code-sent-note'),
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const Key('login-code'),
              controller: codeController,
              autofocus: true,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              enabled: !loading,
              maxLength: 6,
              onFieldSubmitted: (_) => onSubmit(),
              decoration: const InputDecoration(
                labelText: '6 digit code',
                prefixIcon: Icon(Icons.pin_outlined),
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  RegExp(r'^\d{6}$').hasMatch((value ?? '').trim())
                  ? null
                  : 'Enter the 6 digit code',
            ),
          ] else
            TextFormField(
              key: const Key('login-email'),
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
                : Text(codeController != null ? 'Verify code' : 'Verify'),
          ),
          if (codeController != null)
            TextButton(
              key: const Key('login-change-email'),
              onPressed: loading ? null : onChangeEmail,
              child: const Text('Use a different email'),
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
          'We couldn\'t find an alumni record for "$email". Use the email '
          'the Ikafe team has for you, or contact the beta team.',
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
