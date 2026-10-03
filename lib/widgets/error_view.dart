import 'package:flutter/material.dart';

import 'feedback_sheet.dart';

/// The one error widget for "failed to load" screens: the friendly message,
/// the existing "Try again" action where there is one, and a "Send feedback"
/// button. [error] is the raw error (it is cleaned before it is sent and is
/// never shown). [screen] names the screen in the report.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    required this.screen,
    this.error,
    this.onRetry,
    this.retryLabel = 'Try again',
  });

  final String message;
  final String screen;
  final Object? error;
  final VoidCallback? onRetry;
  final String retryLabel;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (onRetry != null)
                  OutlinedButton(onPressed: onRetry, child: Text(retryLabel)),
                TextButton(
                  key: const Key('send-feedback'),
                  onPressed: () =>
                      showFeedbackSheet(context, error: error, screen: screen),
                  child: const Text('Send feedback'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A failed form submit: the red message plus a small "Send feedback" button.
class InlineError extends StatelessWidget {
  const InlineError({
    super.key,
    required this.message,
    required this.screen,
    this.error,
    this.textKey,
  });

  final String message;
  final String screen;
  final Object? error;
  final Key? textKey;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          message,
          key: textKey,
          style: TextStyle(color: theme.colorScheme.error),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            key: const Key('send-feedback'),
            style: TextButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(48, 48),
              tapTargetSize: MaterialTapTargetSize.padded,
              alignment: Alignment.centerLeft,
            ),
            onPressed: () =>
                showFeedbackSheet(context, error: error, screen: screen),
            child: const Text('Send feedback'),
          ),
        ),
      ],
    );
  }
}

/// A snackbar for a failed action, with a "Send feedback" action.
void showErrorSnackBar(
  BuildContext context, {
  required String message,
  required String screen,
  Object? error,
}) => showErrorSnackBarOn(
  ScaffoldMessenger.of(context),
  message: message,
  screen: screen,
  error: error,
);

/// Same, for code that already holds the [ScaffoldMessengerState] (after an
/// await, when the screen's own context may be gone). The messenger outlives
/// the screen, so the feedback sheet still opens.
void showErrorSnackBarOn(
  ScaffoldMessengerState messenger, {
  required String message,
  required String screen,
  Object? error,
}) {
  final sheetContext = messenger.context;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: 'Send feedback',
          onPressed: () =>
              showFeedbackSheet(sheetContext, error: error, screen: screen),
        ),
      ),
    );
}
