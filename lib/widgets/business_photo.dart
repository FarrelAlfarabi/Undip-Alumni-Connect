import 'package:flutter/material.dart';

import 'app_photo.dart';

/// A business photo in the shared 3:2 box. Draws nothing when there is no
/// photo, so a business without one looks as before.
class BusinessPhoto extends StatelessWidget {
  const BusinessPhoto({super.key, required this.url, this.semanticLabel});

  final String? url;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final u = url;
    if (u == null || u.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppPhoto(url: u, semanticLabel: semanticLabel),
    );
  }
}
