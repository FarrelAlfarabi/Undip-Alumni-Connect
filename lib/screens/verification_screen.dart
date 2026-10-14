import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// Shown under the code box when a code is wrong or expired, so the person
  /// stays on the code step instead of starting over.
  String? _codeError;

  /// Seconds before "Resend code" works again.
  int _resendIn = 0;
  Timer? _resendTimer;

  _VerificationState _state = _VerificationState.idle;
  String? _errorMessage;
  Object? _lastError;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  LoginApi? get _login =>
      widget.loginApi ?? (kRealLogin ? SupabaseLoginApi() : null);

  void _startCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendIn = 30);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted || _resendIn <= 1) {
        t.cancel();
        if (mounted) setState(() => _resendIn = 0);
        return;
      }
      setState(() => _resendIn--);
    });
  }

  Future<void> _resend() async {
    final api = _login;
    if (api == null || _resendIn > 0) return;
    final email = _emailController.text.trim().toLowerCase();
    setState(() {
      _state = _VerificationState.loading;
      _codeError = null;
      _codeController.clear();
    });
    try {
      await api.sendCode(email);
      if (!mounted) return;
      setState(() => _state = _VerificationState.idle);
      _startCooldown();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('New code sent')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _VerificationState.idle;
        _codeError = friendlyError(e);
      });
    }
  }

  /// Step 1 of the code login: send the code. Step 2: check it.
  Future<void> _verifyWithCode(LoginApi api, String email) async {
    setState(() {
      _state = _VerificationState.loading;
      _errorMessage = null;
      _codeError = null;
    });
    try {
      if (!_codeSent) {
        // Same screen whether or not the email is on the list, so the app
        // never tells a stranger who is an alumnus. Only known emails get a
        // code.
        if (await api.emailKnown(email)) await api.sendCode(email);
        if (!mounted) return;
        setState(() {
          _codeSent = true;
          _state = _VerificationState.idle;
        });
        _startCooldown();
        return;
      }
      Map<String, dynamic>? profile;
      try {
        profile = await api.verifyCode(email, _codeController.text);
      } catch (e) {
        // A wrong or expired code is the most common slip: keep the person
        // on the code step with a plain message and let them retry or resend.
        if (!mounted) return;
        final network = friendlyError(e) == kNetworkError;
        setState(() {
          _state = _VerificationState.idle;
          _codeError = network
              ? kNetworkError
              : 'That code is wrong or has expired. Check it and try again, '
                    'or send a new code.';
          _codeController.clear();
        });
        return;
      }
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
      _codeError = null;
      _resendTimer?.cancel();
      _resendIn = 0;
      _codeController.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Verify Alumni Status'),
        // On the code step the back arrow returns to the email box.
        leading: _codeSent && _state == _VerificationState.idle
            ? BackButton(onPressed: _reset)
            : null,
      ),
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
          codeError: _codeError,
          resendIn: _resendIn,
          onResend: _resend,
          realLogin: _login != null,
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
    this.codeError,
    this.resendIn = 0,
    this.onResend,
    this.realLogin = false,
  });

  final String? codeError;
  final int resendIn;
  final VoidCallback? onResend;

  /// Code login: the email step says "Send code" and the texts explain the
  /// code. The old email match keeps its original wording.
  final bool realLogin;

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
            codeController != null
                ? 'Enter the code'
                : 'Verify Your Alumni Status',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            codeController != null
                ? 'If ${controller.text.trim()} is on the alumni list, we emailed '
                      'a 6 digit code.'
                : realLogin
                ? 'Enter the email the Ikafe team has on file for you. '
                      'We will email you a 6 digit code, no password needed.'
                : 'Enter the email the Ikafe team has on file for you to '
                      'confirm your alumni record.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          if (codeController != null) ...[
            Text(
              'Can\'t find it? Check your spam or junk folder. The code '
              'expires after a while.',
              key: const Key('code-sent-note'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
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
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: const TextStyle(fontSize: 22, letterSpacing: 6),
              onChanged: (v) {
                // Check as soon as the sixth digit is in.
                if (v.length == 6 && !loading) onSubmit();
              },
              onFieldSubmitted: (_) => onSubmit(),
              decoration: InputDecoration(
                labelText: '6 digit code',
                counterText: '',
                errorText: codeError,
                errorMaxLines: 3,
                prefixIcon: const Icon(Icons.pin_outlined),
                border: const OutlineInputBorder(),
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
              autofillHints: const [AutofillHints.email],
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.none,
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
                : Text(
                    codeController != null
                        ? 'Verify code'
                        : realLogin
                        ? 'Send code'
                        : 'Verify',
                  ),
          ),
          if (codeController != null) ...[
            TextButton(
              key: const Key('login-resend'),
              onPressed: loading || resendIn > 0 ? null : onResend,
              child: Text(
                resendIn > 0 ? 'Resend code in ${resendIn}s' : 'Resend code',
              ),
            ),
            TextButton(
              key: const Key('login-help'),
              onPressed: () => showFeedbackSheet(
                context,
                error: null,
                screen: 'Login help: no code or changed email',
              ),
              child: const Text('No code, or email changed? Contact the team'),
            ),
            TextButton(
              key: const Key('login-change-email'),
              onPressed: loading ? null : onChangeEmail,
              child: const Text('Use a different email'),
            ),
          ],
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
