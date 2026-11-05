import 'package:flutter/material.dart';

import '../util/app_language.dart';

import 'error_view.dart';

/// How long an admin has to undo an action. The button lives inside the
/// notification, so it goes away with it.
const Duration kUndoWindow = Duration(seconds: 8);

/// Shows [message] at the bottom with an "Urungkan" button next to it.
/// [onUndo] runs when the button is pressed. A failure shows the usual error
/// snackbar; success shows "Dibatalkan."
void showUndoSnackBar(
  BuildContext context, {
  required String message,
  required Future<void> Function() onUndo,
  required String Function(Object) errorText,
  String screen = 'Admin',
}) {
  final messenger = ScaffoldMessenger.of(context);
  final navigator = Navigator.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: kUndoWindow,
      // A snackbar with a button stays forever unless this is false.
      persist: false,
      action: SnackBarAction(
        key: const Key('undo-action'),
        label: tr('Urungkan'),
        onPressed: () async {
          try {
            await onUndo();
            messenger.showSnackBar(SnackBar(content: Text(tr('Dibatalkan.'))));
          } catch (e) {
            showErrorSnackBarOn(
              messenger,
              navigator: navigator,
              message: errorText(e),
              screen: screen,
              error: e,
            );
          }
        },
      ),
    ),
  );
}
