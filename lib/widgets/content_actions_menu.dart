import 'package:flutter/material.dart';

import '../util/app_language.dart';

import '../data/block_list.dart';
import '../data/report_repository.dart';
import 'report_sheet.dart';
import 'error_view.dart';

/// The flag / overflow menu on someone else's job, product, business, profile
/// or contact request: Report, and Block person (with a confirm step).
/// Not shown on your own content.
class ContentActionsMenu extends StatelessWidget {
  const ContentActionsMenu({
    super.key,
    required this.currentUserId,
    required this.ownerId,
    required this.ownerName,
    this.reportType,
    this.targetId,
    this.what,
    this.reportRepository,
    this.blockList,
    this.onBlocked,
  });

  final String currentUserId;

  /// The person who owns the content (profile id).
  final String? ownerId;
  final String? ownerName;

  /// Null means no Report entry (for example a product, which keeps its own
  /// report flow).
  final ReportTarget? reportType;
  final String? targetId;
  final String? what;
  final ReportRepository? reportRepository;
  final BlockList? blockList;

  /// Called after the person was blocked.
  final VoidCallback? onBlocked;

  bool get _isOwn => ownerId == null || ownerId == currentUserId;

  Future<void> _report(BuildContext context) async {
    await showContentReportSheet(
      context,
      repository: reportRepository ?? ReportRepository(),
      reporterId: currentUserId,
      type: reportType!,
      targetId: targetId!,
      what: what,
    );
  }

  Future<void> _block(BuildContext context) async {
    final name = ownerName ?? 'alumni ini';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(trf('Blokir {0}?', [name])),
        content: Text(
          tr(
            'Kamu tidak akan melihat profil, lowongan, produk atau usahanya, dan '
            'dia tidak bisa mengirim permintaan kontak kepadamu. Dia tidak '
            'diberi tahu. Kamu bisa membuka blokirnya lagi di Profile > '
            'Pengguna terblokir.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Blokir')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await (blockList ?? BlockList.shared).block(currentUserId, ownerId!);
      messenger.showSnackBar(
        SnackBar(content: Text(trf('{0} diblokir.', [name]))),
      );
      onBlocked?.call();
    } catch (e) {
      showErrorSnackBarOn(
        messenger,
        navigator: navigator,
        message: tr('Tidak bisa memblokir. Coba lagi.'),
        screen: 'Block person',
        error: e,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isOwn) return const SizedBox.shrink();
    final canReport = reportType != null && targetId != null;
    return PopupMenuButton<String>(
      key: const Key('content-menu'),
      tooltip: tr('Menu lainnya'),
      icon: const Icon(Icons.more_vert),
      onSelected: (v) {
        if (v == 'report') _report(context);
        if (v == 'block') _block(context);
      },
      itemBuilder: (_) => [
        if (canReport)
          PopupMenuItem(
            key: Key('menu-report'),
            value: 'report',
            child: ListTile(
              leading: Icon(Icons.flag_outlined),
              title: Text(tr('Laporkan')),
              contentPadding: EdgeInsets.zero,
            ),
          ),
        PopupMenuItem(
          key: Key('menu-block'),
          value: 'block',
          child: ListTile(
            leading: Icon(Icons.block),
            title: Text(tr('Blokir alumni ini')),
            contentPadding: EdgeInsets.zero,
          ),
        ),
      ],
    );
  }
}
