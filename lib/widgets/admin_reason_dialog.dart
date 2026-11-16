import 'package:flutter/material.dart';

import '../util/app_language.dart';

/// Confirm step for an admin action that needs a reason. Returns the reason
/// (trimmed, never empty) when the admin confirms, or null when they cancel.
///
/// [confirmWord] adds a second check for actions that cannot be undone: the
/// admin must type that word (for example HAPUS) before the button works.
Future<String?> askAdminReason(
  BuildContext context, {
  required String title,
  required String body,
  required String action,
  String label = 'Alasan (dicatat di Riwayat)',
  bool destructive = false,
  String? confirmWord,
}) {
  final reason = TextEditingController();
  final word = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      String? reasonError;
      String? wordError;
      return StatefulBuilder(
        builder: (ctx, setLocal) {
          final scheme = Theme.of(ctx).colorScheme;
          return AlertDialog(
            title: Text(title),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(body, style: Theme.of(ctx).textTheme.bodyMedium),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('admin-reason'),
                    controller: reason,
                    autofocus: true,
                    maxLines: 3,
                    maxLength: 300,
                    decoration: InputDecoration(
                      labelText: tr(label),
                      errorText: reasonError,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  if (confirmWord != null) ...[
                    const SizedBox(height: 8),
                    TextField(
                      key: const Key('admin-confirm-word'),
                      controller: word,
                      decoration: InputDecoration(
                        labelText: trf('Ketik {0} untuk lanjut', [confirmWord]),
                        errorText: wordError,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                key: const Key('admin-reason-cancel'),
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(tr('Batal')),
              ),
              FilledButton(
                key: const Key('admin-reason-ok'),
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      )
                    : null,
                onPressed: () {
                  final t = reason.text.trim();
                  final okWord =
                      confirmWord == null ||
                      word.text.trim().toUpperCase() ==
                          confirmWord.toUpperCase();
                  setLocal(() {
                    reasonError = t.isEmpty ? tr('Alasan wajib diisi.') : null;
                    wordError = okWord
                        ? null
                        : trf('Ketik {0} persis.', [confirmWord]);
                  });
                  if (t.isEmpty || !okWord) return;
                  Navigator.of(ctx).pop(t);
                },
                child: Text(action),
              ),
            ],
          );
        },
      );
    },
  );
}
