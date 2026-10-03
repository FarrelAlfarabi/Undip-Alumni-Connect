import 'package:flutter/material.dart';

import '../auth/after_sign_in.dart';
import '../auth/auth_gateway.dart';
import '../kawung_mark.dart';
import '../lock/lock_service.dart';
import '../lock/session.dart';
import 'set_password_screen.dart';

enum _Mode { signIn, forgot, reset }

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// The app's login: email and password, and forgot password (an emailed
/// code). Every alumnus already has an account; the first password is their
/// NIM, and after the first sign-in they are asked (not forced) to choose
/// their own, see [SetPasswordScreen].
///
/// NOTE: this gives people a real account and session, but the database rules
/// are still open to everyone with the app's public key (see
/// SECURITY_AUDIT.md). Signing in does not yet protect the data.
class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    this.gateway = const SupabaseAuthGateway(),
    this.lock,
    this.homeBuilder = defaultHomeBuilder,
  });

  final AuthGateway gateway;

  /// Injectable for tests; defaults to [LockService.shared].
  final LockService? lock;
  final HomeBuilder homeBuilder;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();

  _Mode _mode = _Mode.signIn;
  bool _busy = false;
  bool _showPassword = false;
  String? _error;
  String? _info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  String get _emailValue => _email.text.trim().toLowerCase();

  void _go(_Mode mode, {String? info, String? error}) {
    setState(() {
      _mode = mode;
      _info = info;
      _error = error;
      _showPassword = false;
      _password.clear();
      _code.clear();
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
      _info = null;
    });
    try {
      await action();
    } on AuthFailure catch (e) {
      if (!mounted) return;
      setState(() => _error = authProblemMessage(e.problem));
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = authProblemMessage(AuthProblem.other));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish(Map<String, dynamic> profile) async {
    // First time on the NIM password: invite them to choose their own. They
    // can skip; they will be asked again next time.
    if (profile['password_set'] != true) {
      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (_) => SetPasswordScreen(
            gateway: widget.gateway,
            nim: profile['nim'] as String?,
          ),
        ),
      );
      if (!mounted) return;
      if (changed == true) profile = {...profile, 'password_set': true};
    }
    if (!mounted) return;
    await afterSignIn(
      context,
      profile,
      _emailValue,
      lock: widget.lock,
      homeBuilder: widget.homeBuilder,
      signInBuilder: () => SignInScreen(
        gateway: widget.gateway,
        lock: widget.lock,
        homeBuilder: widget.homeBuilder,
      ),
    );
  }

  Future<void> _submit() => _run(() async {
    final g = widget.gateway;
    switch (_mode) {
      case _Mode.signIn:
        await _finish(await g.signIn(_emailValue, _password.text));
      case _Mode.forgot:
        await g.sendPasswordReset(_emailValue);
        if (!mounted) return;
        _go(
          _Mode.reset,
          info:
              'If this email has an account, we sent a code to $_emailValue. '
              'Enter it with a new password.',
        );
      case _Mode.reset:
        await _finish(
          await g.resetPassword(_emailValue, _code.text, _password.text),
        );
    }
  });

  Future<void> _resend() async {
    if (_emailValue.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.gateway.sendPasswordReset(_emailValue);
      if (mounted) {
        setState(() => _info = 'We sent a new code to $_emailValue.');
      }
    } on AuthFailure catch (e) {
      if (mounted) setState(() => _error = authProblemMessage(e.problem));
    } catch (_) {
      if (mounted) {
        setState(() => _error = authProblemMessage(AuthProblem.other));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String get _title => switch (_mode) {
    _Mode.signIn => 'Sign in',
    _Mode.forgot => 'Forgot password',
    _Mode.reset => 'Set a new password',
  };

  String get _subtitle => switch (_mode) {
    _Mode.signIn => 'Welcome back. Sign in with your alumni email.',
    _Mode.forgot => "Enter your email and we'll send you a code.",
    _Mode.reset => 'Enter the code from the email and choose a new password.',
  };

  String get _submitLabel => switch (_mode) {
    _Mode.signIn => 'Sign in',
    _Mode.forgot => 'Send code',
    _Mode.reset => 'Save and sign in',
  };

  bool get _showsEmail => _mode != _Mode.reset;
  bool get _showsPassword => _mode == _Mode.signIn || _mode == _Mode.reset;
  bool get _showsCode => _mode == _Mode.reset;

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Enter a password';
    if (_mode == _Mode.reset && v.length < kMinPasswordLength) {
      return 'Use at least $kMinPasswordLength characters';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: KawungMark(size: 40)),
                      const SizedBox(height: 16),
                      Text(
                        _title,
                        key: const Key('auth-title'),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _subtitle,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 24),
                      if (_info != null) ...[
                        _Banner(
                          key: const Key('auth-info'),
                          text: _info!,
                          background: scheme.secondaryContainer,
                          foreground: scheme.onSecondaryContainer,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_showsEmail) ...[
                        TextFormField(
                          key: const Key('auth-email'),
                          controller: _email,
                          enabled: !_busy,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: _showsPassword
                              ? TextInputAction.next
                              : TextInputAction.done,
                          autofillHints: const [AutofillHints.email],
                          autocorrect: false,
                          onFieldSubmitted: (_) {
                            if (!_showsPassword) _submit();
                          },
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            hintText: 'name@example.com',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.mail_outline),
                          ),
                          validator: (v) {
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Enter your email';
                            if (!_emailPattern.hasMatch(t)) {
                              return 'Enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_showsCode) ...[
                        TextFormField(
                          key: const Key('auth-code'),
                          controller: _code,
                          enabled: !_busy,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.next,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          decoration: const InputDecoration(
                            labelText: 'Code from the email',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.pin_outlined),
                          ),
                          validator: (v) =>
                              RegExp(r'^\d{6,10}$').hasMatch((v ?? '').trim())
                              ? null
                              : 'Enter the code from the email',
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_showsPassword) ...[
                        TextFormField(
                          key: const Key('auth-password'),
                          controller: _password,
                          enabled: !_busy,
                          obscureText: !_showPassword,
                          textInputAction: TextInputAction.done,
                          autofillHints: [
                            _mode == _Mode.signIn
                                ? AutofillHints.password
                                : AutofillHints.newPassword,
                          ],
                          onFieldSubmitted: (_) => _submit(),
                          decoration: InputDecoration(
                            labelText: _mode == _Mode.reset
                                ? 'New password'
                                : 'Password',
                            border: const OutlineInputBorder(),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              key: const Key('auth-show-password'),
                              tooltip: _showPassword
                                  ? 'Hide password'
                                  : 'Show password',
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                              ),
                              onPressed: () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                            ),
                          ),
                          validator: _validatePassword,
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_mode == _Mode.signIn) ...[
                        Text(
                          'First time? Your password is your NIM. You can '
                          'change it after signing in.',
                          key: const Key('auth-first-time'),
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (_error != null) ...[
                        _Banner(
                          key: const Key('auth-error'),
                          text: _error!,
                          background: scheme.errorContainer,
                          foreground: scheme.onErrorContainer,
                        ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        key: const Key('auth-submit'),
                        onPressed: _busy ? null : _submit,
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _busy
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                ),
                              )
                            : Text(_submitLabel),
                      ),
                      const SizedBox(height: 8),
                      ..._links(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _links() {
    Widget link(String key, String label, VoidCallback onTap) => TextButton(
      key: Key(key),
      onPressed: _busy ? null : onTap,
      child: Text(label),
    );
    return switch (_mode) {
      _Mode.signIn => [
        link('auth-forgot', 'Forgot password?', () => _go(_Mode.forgot)),
      ],
      _Mode.forgot => [
        link('auth-to-signin', 'Back to sign in', () => _go(_Mode.signIn)),
      ],
      _Mode.reset => [
        link('auth-resend', 'Send the code again', _resend),
        link('auth-to-signin', 'Back to sign in', () => _go(_Mode.signIn)),
      ],
    };
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium
            ?.copyWith(color: foreground),
      ),
    );
  }
}
