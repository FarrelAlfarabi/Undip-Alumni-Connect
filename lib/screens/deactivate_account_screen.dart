import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../lock/lock_service.dart';
import '../lock/session.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import 'delete_account_screen.dart';
import 'welcome_screen.dart';

/// Shown on the Welcome screen after an account was deactivated.
const String kAccountDeactivatedNotice =
    'Your account is deactivated. Sign in again any time to bring it back.';

/// "Deactivate my account": hides the person, removes nothing. It sits next
/// to "Delete my account" and never replaces it: only deleting removes data.
class DeactivateAccountScreen extends StatefulWidget {
  const DeactivateAccountScreen({
    super.key,
    required this.currentUser,
    this.repository,
    this.lock,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;
  final AccountRepository? repository;
  final LockService? lock;

  @override
  State<DeactivateAccountScreen> createState() =>
      _DeactivateAccountScreenState();
}

class _DeactivateAccountScreenState extends State<DeactivateAccountScreen> {
  bool _busy = false;
  String? _error;
  Object? _lastError;

  Future<void> _deactivate() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Deactivate your account?'),
        content: const Text(
          'You will be signed out. Sign in again any time to bring it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('deactivate-final'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() {
      _busy = true;
      _error = null;
      _lastError = null;
    });
    try {
      await (widget.repository ?? AccountRepository()).deactivateAccount(
        widget.currentUser.value['id'] as String,
      );
      if (!mounted) return;
      // Same as signing out: the PIN stays on this phone, the person goes.
      await signOutTo(
        context,
        const WelcomeScreen(notice: kAccountDeactivatedNotice),
        lock: widget.lock,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = friendlyError(e);
        _lastError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget bullets(List<String> items) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final i in items)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('•  '),
                Expanded(child: Text(i)),
              ],
            ),
          ),
      ],
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Deactivate my account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Take a break without losing anything.',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Hidden while deactivated',
                    style: theme.textTheme.titleSmall,
                  ),
                  const SizedBox(height: 4),
                  bullets(const [
                    'Your profile in Members and Nearby Alumni',
                    'Your businesses in the Business directory',
                    'Your products in Marketplace',
                  ]),
                  const SizedBox(height: 12),
                  Text('What stays', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  bullets(const [
                    'All your data: profile, businesses, products, job posts, requests',
                    'Your PIN on this phone',
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    'To come back, just sign in again. Your account is '
                    'switched on again right away.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Deactivating is not the same as deleting. Your data is '
                    'kept. If you want your data removed, delete your '
                    'account instead.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InlineError(
                      message: _error!,
                      screen: 'Deactivate account',
                      error: _lastError,
                      textKey: const Key('deactivate-error'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('deactivate-button'),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _busy ? null : _deactivate,
                    child: _busy
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Deactivate my account'),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    key: const Key('deactivate-go-delete'),
                    onPressed: _busy
                        ? null
                        : () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => DeleteAccountScreen(
                                currentUser: widget.currentUser,
                              ),
                            ),
                          ),
                    child: const Text('Delete my account instead'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
