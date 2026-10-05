import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/feedback_repository.dart';
import '../util/app_info.dart';

/// Thank you shown after a successful send.
const String kFeedbackThanks = 'Thank you. Your feedback was sent.';

/// Shown when sending fails (for example no internet).
const String kFeedbackFailed =
    "Couldn't send it. Check your connection, or copy the details and send "
    'them on WhatsApp.';

/// "Send feedback" bottom sheet. Says what will be sent, offers an optional
/// "What were you doing?" box, sends, and on failure offers "Copy details".
Future<void> showFeedbackSheet(
  BuildContext context, {
  required Object? error,
  required String screen,
  FeedbackRepository? repository,
  AppInfo? appInfo,
  String? profileId,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _FeedbackSheet(
      error: error,
      screen: screen,
      repository: repository,
      appInfo: appInfo,
      profileId: profileId,
    ),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text(kFeedbackThanks)));
  }
}

class _FeedbackSheet extends StatefulWidget {
  const _FeedbackSheet({
    required this.error,
    required this.screen,
    this.repository,
    this.appInfo,
    this.profileId,
  });

  final Object? error;
  final String screen;
  final FeedbackRepository? repository;
  final AppInfo? appInfo;
  final String? profileId;

  @override
  State<_FeedbackSheet> createState() => _FeedbackSheetState();
}

class _FeedbackSheetState extends State<_FeedbackSheet> {
  final _message = TextEditingController();
  bool _sending = false;
  bool _failed = false;
  FeedbackReport? _report;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<FeedbackReport> _buildReport() => FeedbackRepository.build(
    error: widget.error,
    screen: widget.screen,
    message: _message.text,
    appInfo: widget.appInfo,
    profileId: widget.profileId,
  );

  Future<void> _send() async {
    setState(() {
      _sending = true;
      _failed = false;
    });
    try {
      final report = await _buildReport();
      _report = report;
      await (widget.repository ?? FeedbackRepository()).send(report);
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      _report ??= await _buildReport();
      if (!mounted) return;
      setState(() {
        _sending = false;
        _failed = true;
      });
    }
  }

  Future<void> _copy() async {
    final report = await _buildReport();
    await Clipboard.setData(ClipboardData(text: report.copyText));
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(const SnackBar(content: Text('Details copied.')));
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
              'Send feedback',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'This sends a short error summary, the screen name '
              '(${widget.screen}), the app version and your device type. '
              'Emails, keys, links and long numbers are removed first.',
              key: const Key('feedback-what'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _message,
              enabled: !_sending,
              maxLength: kFeedbackMessageMax,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'What were you doing? (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (_failed) ...[
              const SizedBox(height: 4),
              Text(
                kFeedbackFailed,
                key: const Key('feedback-failed'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                key: const Key('feedback-copy'),
                onPressed: _copy,
                icon: const Icon(Icons.copy_outlined),
                label: const Text('Copy details'),
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
                  : Text(_failed ? 'Try sending again' : 'Send'),
            ),
          ],
        ),
      ),
    );
  }
}
