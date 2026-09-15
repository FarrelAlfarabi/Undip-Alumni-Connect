import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_shell.dart';

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
  const VerificationScreen({super.key});

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

enum _VerificationState { idle, loading, notFound, error }

class _VerificationScreenState extends State<VerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  _VerificationState _state = _VerificationState.idle;
  String? _errorMessage;

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
      final client = Supabase.instance.client;
      final match = await client
          .from('alumni_profiles')
          .select()
          .eq('email', email)
          .maybeSingle();

      if (match == null) {
        setState(() => _state = _VerificationState.notFound);
        return;
      }

      if (match['verification_status'] != 'verified') {
        await client
            .from('alumni_profiles')
            .update({'verification_status': 'verified'})
            .eq('id', match['id']);
        match['verification_status'] = 'verified';
      }

      if (!mounted) return;
      setState(() => _state = _VerificationState.idle);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HomeShell(profile: match)),
      );
    } catch (e) {
      setState(() {
        _state = _VerificationState.error;
        _errorMessage = e.toString();
      });
    }
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
        return _ErrorResult(message: _errorMessage!, onTryAgain: _reset);
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
