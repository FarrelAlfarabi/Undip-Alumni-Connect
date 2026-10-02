import 'package:flutter/material.dart';

import '../util/friendly_error.dart';

/// What a screen shows when its data failed to load: the safe message from
/// [friendlyLoadError] and a Try again button, so people are not stuck
/// having to leave the screen and come back.
class LoadErrorView extends StatelessWidget {
  const LoadErrorView({
    super.key,
    required this.thing,
    required this.error,
    required this.onRetry,
  });

  /// What failed to load, in a sentence ("the job board").
  final String thing;
  final Object? error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(friendlyLoadError(thing, error), textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonalIcon(
              key: const Key('load-retry'),
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
