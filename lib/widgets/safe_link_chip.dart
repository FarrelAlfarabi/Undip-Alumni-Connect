import 'package:flutter/material.dart';

import '../util/safe_url.dart';

/// A chip that opens a user-supplied link, but only if it is a plain
/// http(s) web link. Anything else shows a message and opens nothing.
class SafeLinkChip extends StatelessWidget {
  const SafeLinkChip({
    super.key,
    required this.icon,
    required this.label,
    required this.url,
    this.launcher = defaultLauncher,
  });

  final IconData icon;
  final String label;
  final String url;
  final UrlLauncher launcher;

  static Future<bool> defaultLauncher(Uri uri) => openHttpUrlDefault(uri);

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        final ok = await openHttpUrl(url, launcher: launcher);
        if (!ok) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text("This link isn't valid or can't be opened."),
            ),
          );
        }
      },
    );
  }
}
