import 'package:flutter/material.dart';

import '../data/contact_repository.dart';
import '../widgets/error_view.dart';

/// "Request to contact" bottom sheet: an optional short message (200
/// characters, plain text) and Send. Shows the result as a snackbar.
Future<bool> showRequestContactSheet(
  BuildContext context, {
  required ContactRepository repository,
  required String requesterId,
  required String targetId,
  required String targetName,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    // SafeArea keeps the Send button clear of the phone's own navigation bar.
    builder: (ctx) => SafeArea(
      child: _RequestSheet(
        repository: repository,
        requesterId: requesterId,
        targetId: targetId,
        targetName: targetName,
      ),
    ),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('Request sent to $targetName.')));
  }
  return sent == true;
}

class _RequestSheet extends StatefulWidget {
  const _RequestSheet({
    required this.repository,
    required this.requesterId,
    required this.targetId,
    required this.targetName,
  });

  final ContactRepository repository;
  final String requesterId;
  final String targetId;
  final String targetName;

  @override
  State<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends State<_RequestSheet> {
  final _message = TextEditingController();
  bool _sending = false;
  String? _error;
  Object? _lastError;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.repository.send(
        requesterId: widget.requesterId,
        targetId: widget.targetId,
        message: _message.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = contactErrorMessage(e);
        _lastError = e;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Request to contact ${widget.targetName}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'They will see your name and your message. If they accept, '
              'they choose what contact detail to share with you.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              enabled: !_sending,
              maxLength: kContactMessageMax,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Message (optional)',
                hintText: 'For example: why you would like to connect',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              InlineError(
                message: _error!,
                textKey: const Key('request-error'),
                screen: 'Request to contact',
                error: _lastError,
              ),
            ],
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Send request'),
            ),
          ],
        ),
      ),
    );
  }
}
