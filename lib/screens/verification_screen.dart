import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../lock/lock_service.dart';
import '../lock/pin_setup_screen.dart';
import '../lock/session.dart';
import '../util/friendly_error.dart';

/// Step 1: finds out whether the email belongs to an alumni record and, if
/// so, sends a 6-digit code to it. Returns false when there is no match.
typedef EmailCodeSender = Future<bool> Function(String email);

/// Step 2: confirms the code (creating a real Supabase Auth session) and
/// links that session to the alumni record. Returns the linked profile.
typedef EmailCodeConfirmer = Future<Map<String, dynamic>> Function(
  String email,
  String code,
);

Future<bool> defaultSendCode(String email) async {
  final client = Supabase.instance.client;
  final match = await client
      .from('alumni_profiles')
      .select('id')
      .eq('email', email)
      .maybeSingle();
  if (match == null) return false;

  // The email-exists check happens before sending the code so a stranger's
  // email never gets an auth account created for it just by trying: only
  // emails that already match an alumni record trigger a real signup.
  await client.auth.signInWithOtp(email: email, shouldCreateUser: true);
  return true;
}

Future<Map<String, dynamic>> defaultConfirmCode(
  String email,
  String code,
) async {
  final client = Supabase.instance.client;
  await client.auth.verifyOTP(email: email, token: code, type: OtpType.email);
  final profile = await client.rpc('claim_alumni_profile').single();
  return Map<String, dynamic>.from(profile as Map);
}

/// Real Supabase Auth verification (replaces the old plain email
/// exact-match; see PROJECT_NOTES.md's production-hardening entry).
///
/// Flow: enter email -> [sendCode] checks it matches an alumni record and
/// emails a 6-digit code -> enter the code -> [confirmCode] runs `verifyOTP`
/// (a real Supabase Auth session) and `claim_alumni_profile()` (links that
/// session to the matching `alumni_profiles` row) -> remember the person on
/// this device and offer a PIN -> the app, with a real authenticated session.
class VerificationScreen extends StatefulWidget {
  const VerificationScreen({
    super.key,
    this.lock,
    this.sendCode = defaultSendCode,
    this.confirmCode = defaultConfirmCode,
    this.homeBuilder = defaultHomeBuilder,
  });

  /// Injectable for tests; defaults to the real [HomeShell].
  final HomeBuilder homeBuilder;

  /// Injectable for tests; defaults to [LockService.shared].
  final LockService? lock;

  /// Injectable for tests; defaults to the Supabase email-code request.
  final EmailCodeSender sendCode;

  /// Injectable for tests; defaults to Supabase code confirmation.
  final EmailCodeConfirmer confirmCode;

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

enum _VerificationState { idle, loading, notFound, awaitingCode, error }

class _VerificationScreenState extends State<VerificationScreen> {
  final _emailFormKey = GlobalKey<FormState>();
  final _codeFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _codeController = TextEditingController();

  _VerificationState _state = _VerificationState.idle;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _submitEmail() async {
    if (!_emailFormKey.currentState!.validate()) return;

    final email = _emailController.text.trim().toLowerCase();

    setState(() {
      _state = _VerificationState.loading;
      _errorMessage = null;
    });

    try {
      final found = await widget.sendCode(email);
      if (!mounted) return;
      setState(
        () => _state =
            found ? _VerificationState.awaitingCode : _VerificationState.notFound,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _VerificationState.error;
        _errorMessage = friendlyError(e);
      });
    }
  }

  Future<void> _resendCode() async {
    setState(() {
      _state = _VerificationState.loading;
      _errorMessage = null;
    });
    try {
      final email = _emailController.text.trim().toLowerCase();
      await widget.sendCode(email);
      if (!mounted) return;
      setState(() => _state = _VerificationState.awaitingCode);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _VerificationState.error;
        _errorMessage = friendlyError(e);
      });
    }
  }

  Future<void> _submitCode() async {
    if (!_codeFormKey.currentState!.validate()) return;

    setState(() {
      _state = _VerificationState.loading;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim().toLowerCase();
      final code = _codeController.text.trim();
      final profile = await widget.confirmCode(email, code);

      if (!mounted) return;
      setState(() => _state = _VerificationState.idle);
      await _afterVerified(profile, email);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _state = _VerificationState.error;
        _errorMessage = friendlyError(e);
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
    if (!offerPin) {
      enterApp(context, profile, lock: lock, homeBuilder: widget.homeBuilder);
      return;
    }
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          lock: lock,
          // The setup screen is replaced by the app once done or skipped.
          onDone: (setupContext) async => enterApp(
            setupContext,
            profile,
            lock: lock,
            homeBuilder: widget.homeBuilder,
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
      _codeController.clear();
    });
  }

  void _backToEmail() {
    setState(() {
      _state = _VerificationState.idle;
      _errorMessage = null;
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
        return _ErrorResult(message: _errorMessage!, onTryAgain: _reset);
      case _VerificationState.awaitingCode:
        return _CodeForm(
          formKey: _codeFormKey,
          controller: _codeController,
          email: _emailController.text.trim(),
          loading: false,
          onSubmit: _submitCode,
          onResend: _resendCode,
          onChangeEmail: _backToEmail,
        );
      case _VerificationState.idle:
      case _VerificationState.loading:
        return _EmailForm(
          formKey: _emailFormKey,
          controller: _emailController,
          loading: _state == _VerificationState.loading,
          onSubmit: _submitEmail,
        );
    }
  }
}

class _EmailForm extends StatelessWidget {
  const _EmailForm({
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
            'Enter the email on file with UNDIP. We\'ll send a 6-digit '
            'code to confirm it\'s you against the demo\'s seeded records.',
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
                : const Text('Send Code'),
          ),
        ],
      ),
    );
  }
}

class _CodeForm extends StatelessWidget {
  const _CodeForm({
    required this.formKey,
    required this.controller,
    required this.email,
    required this.loading,
    required this.onSubmit,
    required this.onResend,
    required this.onChangeEmail,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController controller;
  final String email;
  final bool loading;
  final VoidCallback onSubmit;
  final VoidCallback onResend;
  final VoidCallback onChangeEmail;

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
              Icons.mark_email_read_outlined,
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Enter Your Code',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We sent a 6-digit code to $email.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 24),
          TextFormField(
            controller: controller,
            autofocus: true,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            enabled: !loading,
            onFieldSubmitted: (_) => onSubmit(),
            decoration: const InputDecoration(
              labelText: '6-digit code',
              prefixIcon: Icon(Icons.pin_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (value) {
              final v = value?.trim() ?? '';
              if (v.isEmpty) return 'Enter the code';
              if (v.length < 6) return 'Enter the full 6-digit code';
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
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(
                onPressed: loading ? null : onChangeEmail,
                child: const Text('Change email'),
              ),
              TextButton(
                onPressed: loading ? null : onResend,
                child: const Text('Resend code'),
              ),
            ],
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
  const _ErrorResult({required this.message, required this.onTryAgain});

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
      ],
    );
  }
}
