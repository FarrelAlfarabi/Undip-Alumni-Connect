import 'package:flutter/material.dart';

import 'subscribe_screen.dart';

bool isSubscribed(Map<String, dynamic> user) =>
    user['subscription_status'] == 'subscribed';

/// Posting is for subscribers. A free user gets a short explanation, then
/// the existing Subscribe screen. Returns true when the user is (now)
/// subscribed and may continue. The shared [currentUser] notifier is
/// updated on subscribe, like the job and messaging gates.
Future<bool> ensureSubscriber(
  BuildContext context,
  ValueNotifier<Map<String, dynamic>> currentUser,
) async {
  if (isSubscribed(currentUser.value)) return true;

  final go = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Subscribers only'),
      content: const Text(
        'Posting in the marketplace is for subscribers. Browsing stays '
        'free for everyone.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Not now'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Subscribe'),
        ),
      ],
    ),
  );
  if (go != true || !context.mounted) return false;

  final updated = await Navigator.of(context).push<Map<String, dynamic>>(
    MaterialPageRoute(
      builder: (_) => SubscribeScreen(profile: currentUser.value),
    ),
  );
  if (updated != null) currentUser.value = updated;
  return isSubscribed(currentUser.value);
}
