import 'package:flutter/material.dart';

import '../data/marketplace_messages.dart';
import '../data/marketplace_repository.dart';
import '../models/marketplace_listing.dart';

/// Bottom sheet to report a listing: pick a reason, optional note.
/// Shows the result as a snackbar on the caller's scaffold.
Future<void> showReportSheet(
  BuildContext context, {
  required MarketplaceRepository repository,
  required String listingId,
  required String reporterId,
}) {
  final messenger = ScaffoldMessenger.of(context);
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _ReportSheet(
      repository: repository,
      listingId: listingId,
      reporterId: reporterId,
      messenger: messenger,
    ),
  );
}

class _ReportSheet extends StatefulWidget {
  const _ReportSheet({
    required this.repository,
    required this.listingId,
    required this.reporterId,
    required this.messenger,
  });

  final MarketplaceRepository repository;
  final String listingId;
  final String reporterId;
  final ScaffoldMessengerState messenger;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  ReportReason? _reason;
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
      setState(() => _error = 'Pick a reason');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await widget.repository.report(
        listingId: widget.listingId,
        reporterId: widget.reporterId,
        reason: _reason!,
        note: _note.text,
      );
      widget.messenger.showSnackBar(
        const SnackBar(content: Text(kReportSentMessage)),
      );
      navigator.pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = marketplaceErrorMessage(e);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        0,
        24,
        24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Report listing', style: theme.textTheme.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Why are you reporting this listing?',
              style: theme.textTheme.bodyMedium,
            ),
            RadioGroup<ReportReason>(
              groupValue: _reason,
              onChanged: (v) {
                if (!_sending) setState(() => _reason = v);
              },
              child: Column(
                children: [
                  for (final r in ReportReason.values)
                    RadioListTile<ReportReason>(
                      contentPadding: EdgeInsets.zero,
                      title: Text(r.label),
                      value: r,
                    ),
                ],
              ),
            ),
            TextField(
              controller: _note,
              enabled: !_sending,
              maxLines: 3,
              maxLength: 500,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
            const SizedBox(height: 16),
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
