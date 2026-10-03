import 'package:flutter/material.dart';

import '../auth/auth_gateway.dart';

/// Shown once after signing in with the first password (the NIM): invites the
/// person to choose their own. Optional. "Not now" skips it, and they are
/// asked again next sign-in. Pops `true` if the password was changed.
class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key, required this.gateway, this.nim});

  final AuthGateway gateway;

  /// Their NIM, so the new password can't be the same as the first one.
  final String? nim;

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  bool _show = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.gateway.changePassword(_password.text);
      if (mounted) Navigator.of(context).pop(true);
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return PopScope(
      canPop: !_busy,
      child: Scaffold(
        key: const Key('set-password'),
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text('Choose your password'),
          actions: [
            TextButton(
              key: const Key('set-password-skip'),
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              child: const Text('Not now'),
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'You signed in with your NIM. Choose your own '
                        'password so only you can sign in as you.',
                        style: theme.textTheme.bodyLarge,
                      ),
                      const SizedBox(height: 24),
                      TextFormField(
                        key: const Key('set-password-new'),
                        controller: _password,
                        enabled: !_busy,
                        obscureText: !_show,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.newPassword],
                        decoration: InputDecoration(
                          labelText: 'New password',
                          helperText: 'At least $kMinPasswordLength characters',
                          border: const OutlineInputBorder(),
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            tooltip: _show ? 'Hide password' : 'Show password',
                            icon: Icon(
                              _show
                                  ? Icons.visibility_off_outlined
                                  : Icons.visibility_outlined,
                            ),
                            onPressed: () => setState(() => _show = !_show),
                          ),
                        ),
                        validator: (v) {
                          if (v == null || v.length < kMinPasswordLength) {
                            return 'Use at least $kMinPasswordLength characters';
                          }
                          if (widget.nim != null && v == widget.nim) {
                            return "Choose something different from your NIM";
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        key: const Key('set-password-confirm'),
                        controller: _confirm,
                        enabled: !_busy,
                        obscureText: !_show,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.newPassword],
                        onFieldSubmitted: (_) => _save(),
                        decoration: const InputDecoration(
                          labelText: 'Repeat new password',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.lock_outline),
                        ),
                        validator: (v) => v == _password.text
                            ? null
                            : "The passwords don't match",
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          key: const Key('set-password-error'),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onErrorContainer,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 24),
                      FilledButton(
                        key: const Key('set-password-save'),
                        onPressed: _busy ? null : _save,
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
                            : const Text('Save password'),
                      ),
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
}
