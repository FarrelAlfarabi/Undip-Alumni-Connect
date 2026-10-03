import 'package:flutter/material.dart';

import '../data/report_repository.dart';

/// "Report" bottom sheet: pick a reason, add an optional note (300
/// characters), send, then a thank you. Returns true when a report was sent.
Future<bool> showContentReportSheet(
  BuildContext context, {
  required ReportRepository repository,
  required String reporterId,
  required ReportTarget type,
  required String targetId,
  String? what,
}) async {
  final sent = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ReportSheet(
      repository: repository,
      reporterId: reporterId,
      type: type,
      targetId: targetId,
      what: what,
    ),
  );
  if (sent == true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text(kReportThanks)));
  }
  return sent == true;
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.repository,
    required this.reporterId,
    required this.type,
    required this.targetId,
    this.what,
  });

  final ReportRepository repository;
  final String reporterId;
  final ReportTarget type;
  final String targetId;
  final String? what;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ContentReportReason? _reason;
  final _note = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_reason == null) {
      setState(() => _error = 'Pick a reason.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await widget.repository.report(
        reporterId: widget.reporterId,
        type: widget.type,
        targetId: widget.targetId,
        reason: _reason!,
        note: _note.text,
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = reportErrorMessage(e);
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
              widget.what == null ? 'Report' : 'Report ${widget.what}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'An admin will look at it. The person is not told who reported.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            RadioGroup<ContentReportReason>(
              groupValue: _reason,
              onChanged: (v) {
                if (_sending) return;
                setState(() {
                  _reason = v;
                  _error = null;
                });
              },
              child: Column(
                children: [
                  for (final r in ContentReportReason.values)
                    RadioListTile<ContentReportReason>(
                      key: Key('reason-${r.value}'),
                      value: r,
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.label),
                    ),
                ],
              ),
            ),
            TextField(
              controller: _note,
              enabled: !_sending,
              maxLength: kReportNoteMax,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  _error!,
                  key: const Key('report-error'),
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: _sending ? null : _send,
              child: _sending
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : const Text('Send report'),
            ),
          ],
        ),
      ),
    );
  }
}
