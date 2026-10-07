import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/contact_repository.dart';
import '../data/report_repository.dart';
import '../models/contact_request.dart';
import '../util/friendly_error.dart';
import '../widgets/content_actions_menu.dart';
import '../widgets/error_view.dart';

/// "Requests": what people asked me (Received) and what I asked (Sent).
class RequestsScreen extends StatefulWidget {
  const RequestsScreen({
    super.key,
    required this.currentUser,
    this.repository,
    this.initialTab = 0,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;
  final ContactRepository? repository;

  /// 0 = Received, 1 = Sent.
  final int initialTab;

  @override
  State<RequestsScreen> createState() => _RequestsScreenState();
}

class _RequestsScreenState extends State<RequestsScreen> {
  late final ContactRepository _repo = widget.repository ?? ContactRepository();
  late Future<List<IncomingRequest>> _incoming;
  late Future<List<OutgoingRequest>> _outgoing;

  String get _myId => widget.currentUser.value['id'] as String;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    _incoming = _repo.incoming(_myId);
    _outgoing = _repo.outgoing(_myId);
  }

  void _refresh() => setState(_reload);

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: widget.initialTab,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Requests'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Received'),
              Tab(text: 'Sent'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _ListTab<IncomingRequest>(
              future: _incoming,
              what: 'requests',
              emptyText:
                  'No requests yet. When another alumnus asks to contact '
                  'you, it shows up here.',
              onRetry: _refresh,
              itemBuilder: (r) => _IncomingCard(
                request: r,
                repository: _repo,
                myId: _myId,
                defaultContact: (widget.currentUser.value['email'] as String?)
                    ?.trim(),
                onChanged: _refresh,
              ),
            ),
            _ListTab<OutgoingRequest>(
              future: _outgoing,
              what: 'your requests',
              emptyText:
                  'You have not asked anyone yet. Open an alumnus profile '
                  'and tap "Request to contact".',
              onRetry: _refresh,
              itemBuilder: (r) =>
                  _OutgoingCard(request: r, repository: _repo, myId: _myId),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListTab<T> extends StatelessWidget {
  const _ListTab({
    required this.future,
    required this.what,
    required this.emptyText,
    required this.onRetry,
    required this.itemBuilder,
  });

  final Future<List<T>> future;
  final String what;
  final String emptyText;
  final VoidCallback onRetry;
  final Widget Function(T item) itemBuilder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<T>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return ErrorView(
            message: friendlyLoadError(what, snap.error),
            screen: 'Requests',
            error: snap.error,
            onRetry: onRetry,
          );
        }
        final items = snap.data ?? const [];
        if (items.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(emptyText, textAlign: TextAlign.center),
            ),
          );
        }
        return ListView.separated(
          padding: const EdgeInsets.all(16),
          itemCount: items.length,
          separatorBuilder: (_, _) => const SizedBox(height: 12),
          itemBuilder: (context, i) => itemBuilder(items[i]),
        );
      },
    );
  }
}

class _IncomingCard extends StatelessWidget {
  const _IncomingCard({
    required this.request,
    required this.repository,
    required this.myId,
    required this.onChanged,
    this.defaultContact,
  });

  /// Filled into the share box when accepting. You can change it.
  final String? defaultContact;

  final IncomingRequest request;
  final ContactRepository repository;
  final String myId;
  final VoidCallback onChanged;

  Future<void> _accept(BuildContext context) async {
    // My saved default, else my email. A failed lookup just uses the email.
    String? saved;
    try {
      saved = await repository.defaultContact(myId);
    } catch (_) {}
    if (!context.mounted) return;
    final text = await showDialog<String>(
      context: context,
      builder: (ctx) => _ShareDialog(initial: saved ?? defaultContact),
    );
    if (text == null || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await repository.accept(
        targetId: myId,
        requestId: request.id,
        sharedContact: text,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Accepted. ${request.requesterName} can now see what you shared.',
          ),
        ),
      );
    } catch (e) {
      showErrorSnackBarOn(
        messenger,
        navigator: navigator,
        message: contactErrorMessage(e),
        screen: 'Requests',
        error: e,
      );
    }
    onChanged();
  }

  Future<void> _reject(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await repository.reject(targetId: myId, requestId: request.id);
      messenger.showSnackBar(
        const SnackBar(content: Text('Request declined.')),
      );
    } catch (e) {
      showErrorSnackBarOn(
        messenger,
        navigator: navigator,
        message: contactErrorMessage(e),
        screen: 'Requests',
        error: e,
      );
    }
    onChanged();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = request;
    return Card(
      key: Key('incoming-${r.id}'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    r.requesterName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ContentActionsMenu(
                  currentUserId: myId,
                  ownerId: r.requesterId,
                  ownerName: r.requesterName,
                  reportType: ReportTarget.contactRequest,
                  targetId: r.id,
                  what: 'this request',
                  onBlocked: onChanged,
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              (r.message == null || r.message!.isEmpty)
                  ? 'No message.'
                  : r.message!,
            ),
            const SizedBox(height: 8),
            if (r.status == ContactRequestStatus.pending)
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    key: Key('reject-${r.id}'),
                    onPressed: () => _reject(context),
                    child: const Text('Decline'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    key: Key('accept-${r.id}'),
                    onPressed: () => _accept(context),
                    child: const Text('Accept'),
                  ),
                ],
              )
            else
              Text(
                r.status == ContactRequestStatus.accepted
                    ? 'You accepted this request.'
                    : 'You declined this request.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Accept asks what to share. Your email is filled in as the default; change
/// it to a WhatsApp number or anything else if you prefer.
class _ShareDialog extends StatefulWidget {
  const _ShareDialog({this.initial});

  final String? initial;

  @override
  State<_ShareDialog> createState() => _ShareDialogState();
}

class _ShareDialogState extends State<_ShareDialog> {
  late final _text = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _ok() {
    final t = _text.text.trim();
    if (t.isEmpty) {
      setState(() => _error = 'Type what you want to share.');
      return;
    }
    Navigator.of(context).pop(t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('What do you want to share?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your default contact is filled in (or your email if you have not '
            'set one). Change it to anything you prefer: WhatsApp, Instagram, '
            'phone, email... Only this person will see it. You can set your '
            'default in Profile > Settings.',
          ),
          const SizedBox(height: 12),
          TextField(
            key: const Key('share-field'),
            controller: _text,
            maxLength: kSharedContactMax,
            decoration: InputDecoration(
              labelText: 'Contact to share *',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _ok, child: const Text('Accept and share')),
      ],
    );
  }
}

class _OutgoingCard extends StatefulWidget {
  const _OutgoingCard({
    required this.request,
    required this.repository,
    required this.myId,
  });

  final OutgoingRequest request;
  final ContactRepository repository;
  final String myId;

  @override
  State<_OutgoingCard> createState() => _OutgoingCardState();
}

class _OutgoingCardState extends State<_OutgoingCard> {
  String? _shared;
  String? _error;
  bool _loading = false;

  Future<void> _show() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final text = await widget.repository.sharedContact(
        requesterId: widget.myId,
        requestId: widget.request.id,
      );
      if (mounted) setState(() => _shared = text);
    } catch (e) {
      if (mounted) setState(() => _error = contactErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final r = widget.request;
    final status = switch (r.status) {
      ContactRequestStatus.pending => 'Waiting for an answer',
      ContactRequestStatus.accepted => 'Accepted',
      // The requester only ever sees "not accepted".
      ContactRequestStatus.rejected => 'Not accepted',
    };
    return Card(
      key: Key('outgoing-${r.id}'),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              r.targetName,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(status, key: Key('status-${r.id}')),
            if (r.status == ContactRequestStatus.accepted) ...[
              const SizedBox(height: 8),
              if (_shared == null)
                OutlinedButton(
                  key: Key('show-${r.id}'),
                  onPressed: _loading ? null : _show,
                  child: _loading
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Show shared contact'),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: SelectableText(
                        _shared!,
                        key: Key('shared-${r.id}'),
                        style: theme.textTheme.bodyLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      icon: const Icon(Icons.copy_outlined),
                      onPressed: () =>
                          Clipboard.setData(ClipboardData(text: _shared!)),
                    ),
                  ],
                ),
              if (_error != null)
                Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
            ],
          ],
        ),
      ),
    );
  }
}
