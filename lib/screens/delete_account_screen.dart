import 'package:flutter/material.dart';

import '../data/account_repository.dart';
import '../data/block_list.dart';
import '../data/feedback_repository.dart';
import '../lock/lock_service.dart';
import '../util/friendly_error.dart';
import '../widgets/error_view.dart';
import 'welcome_screen.dart';

/// Shown on the Welcome screen after an account was deleted.
const String kAccountDeletedNotice =
    'Your account was deleted. Thank you for being part of Lingkaran.';

/// What the person has to type (or their first name) to continue.
const String kDeleteWord = 'HAPUS';

/// True when [typed] is HAPUS or the person's first name (any case).
bool deleteConfirmationMatches(String typed, String name) {
  final t = typed.trim().toLowerCase();
  if (t.isEmpty) return false;
  final first = name.trim().split(RegExp(r'\s+')).first.toLowerCase();
  return t == kDeleteWord.toLowerCase() || (first.isNotEmpty && t == first);
}

/// "Delete my account": explains what is removed and what is kept, asks for
/// HAPUS (or the first name), then a final confirm. On success everything on
/// this device is wiped and the person lands on the Welcome screen.
///
/// Honest limit: with no real login, anyone who knows a person's email could
/// trigger this, so the typed word is only a speed bump.
class DeleteAccountScreen extends StatefulWidget {
  const DeleteAccountScreen({
    super.key,
    required this.currentUser,
    this.repository,
    this.lock,
    this.blockList,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;
  final AccountRepository? repository;
  final LockService? lock;
  final BlockList? blockList;

  @override
  State<DeleteAccountScreen> createState() => _DeleteAccountScreenState();
}

class _DeleteAccountScreenState extends State<DeleteAccountScreen> {
  final _controller = TextEditingController();
  bool _deleting = false;
  String? _error;
  Object? _lastError;

  String get _name => widget.currentUser.value['name'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    final sure = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete your account for good?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('delete-final'),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete my account'),
          ),
        ],
      ),
    );
    if (sure != true || !mounted) return;

    setState(() {
      _deleting = true;
      _error = null;
      _lastError = null;
    });
    final navigator = Navigator.of(context);
    try {
      final result = await (widget.repository ?? AccountRepository())
          .deleteAccount(widget.currentUser.value['id'] as String);
      // Wipe everything on this device (PIN, remembered profile, block list).
      try {
        await (widget.lock ?? LockService.shared).clear();
      } catch (_) {}
      FeedbackSession.profileId = null;
      (widget.blockList ?? BlockList.shared).blocked.value = const {};
      // The paths the app could not remove are in the result (and in the
      // database table storage_cleanup_queue).
      debugPrint('Account deleted. Files not removed: ${result.failedPaths}');
      navigator.pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const WelcomeScreen(notice: kAccountDeletedNotice),
        ),
        (_) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _deleting = false;
        _error = friendlyError(e);
        _lastError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ready = deleteConfirmationMatches(_controller.text, _name);
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
      appBar: AppBar(title: const Text('Delete my account')),
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
                    'This removes your account from Lingkaran.',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  Text('What is removed', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  bullets(const [
                    'Your businesses and products',
                    'Your job posts, and every application to them',
                    'Your job applications',
                    'Your contact requests, sent and received',
                    'Your notifications and blocks',
                    'Your feedback reports',
                    'Your profile details: name, NIM, email, city, employer details',
                    'On this phone: your PIN and everything remembered',
                  ]),
                  const SizedBox(height: 12),
                  Text('What is kept', style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  bullets(const [
                    'Reports you filed, or that were filed about others, for moderation, without your note or any personal detail',
                    'An empty profile called "Deleted user". It cannot be used to sign in.',
                    'Photos and CV files may stay in storage until an admin removes them',
                  ]),
                  const SizedBox(height: 12),
                  Text(
                    'After this you cannot verify again with the same email. '
                    'If you change your mind, the Ikafe team can restore you '
                    'from the alumni list.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    key: const Key('delete-field'),
                    controller: _controller,
                    enabled: !_deleting,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Type $kDeleteWord or your first name',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    InlineError(
                      message: _error!,
                      screen: 'Delete account',
                      error: _lastError,
                      textKey: const Key('delete-error'),
                    ),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    key: const Key('delete-button'),
                    style: FilledButton.styleFrom(
                      backgroundColor: theme.colorScheme.error,
                      foregroundColor: theme.colorScheme.onError,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: (ready && !_deleting) ? _delete : null,
                    child: _deleting
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.5),
                          )
                        : const Text('Delete my account'),
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
