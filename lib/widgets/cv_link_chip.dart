import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../util/safe_url.dart';

/// Gives a short lived link for a file in the private `cvs` bucket.
typedef CvSigner = Future<String> Function(String path);

Future<String> defaultCvSigner(String path) =>
    Supabase.instance.client.storage.from('cvs').createSignedUrl(path, 300);

/// A CV button. The link is made only when the button is tapped (it expires
/// after 5 minutes), so a screen left open never holds a dead link.
class CvLinkChip extends StatelessWidget {
  const CvLinkChip({
    super.key,
    required this.path,
    this.signer = defaultCvSigner,
    this.launcher = openHttpUrlDefault,
  });

  final String path;
  final CvSigner signer;
  final UrlLauncher launcher;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.description_outlined, size: 16),
      label: const Text('CV'),
      onPressed: () async {
        final messenger = ScaffoldMessenger.of(context);
        var ok = false;
        try {
          final url = await signer(path);
          ok = await openHttpUrl(url, launcher: launcher);
        } catch (_) {
          ok = false;
        }
        if (!ok) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text("This CV can't be opened right now. Try again."),
            ),
          );
        }
      },
    );
  }
}
