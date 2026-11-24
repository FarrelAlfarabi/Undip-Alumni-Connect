import 'package:flutter/material.dart';

import '../data/marketplace_format.dart';
import '../models/business.dart';
import '../models/marketplace_listing.dart';
import '../util/app_language.dart';
import '../widgets/app_photo.dart';
import '../widgets/safe_link_chip.dart';
import '../widgets/verified_badge.dart';

/// Admin: everything about one business, read only. Opened with "Detail" on
/// Admin > Businesses. The decisions (approve, reject, suspend, NIB) stay on
/// the list card.
class AdminBusinessDetailScreen extends StatelessWidget {
  const AdminBusinessDetailScreen({super.key, required this.business});

  final Business business;

  @override
  Widget build(BuildContext context) {
    final b = business;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(tr('Detail usaha'))),
      body: _DetailBody(
        children: [
          if ((b.photoUrl ?? '').isNotEmpty)
            AppPhoto(url: b.photoUrl!, aspectRatio: 1, semanticLabel: b.name),
          const SizedBox(height: 16),
          NameWithBadge(
            name: b.name,
            verified: b.nibVerified,
            badgeSize: 22,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            b.status.label,
            key: const Key('detail-status'),
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(b.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          if (b.socialLink != null || b.websiteLink != null) ...[
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (b.socialLink != null)
                  SafeLinkChip(
                    icon: Icons.alternate_email,
                    label: tr('Instagram / social'),
                    url: b.socialLink!,
                  ),
                if (b.websiteLink != null)
                  SafeLinkChip(
                    icon: Icons.language,
                    label: 'Website',
                    url: b.websiteLink!,
                  ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _Row(tr('Pemilik'), b.ownerName ?? 'Alumni'),
          _Row(tr('Kategori'), b.category),
          _Row(
            tr('Jenis'),
            b.isPersonal ? tr('Usaha perorangan') : tr('Usaha'),
          ),
          _Row(
            tr('Ukuran pilihan pemilik'),
            b.requestedBand == null
                ? '-'
                : '${b.requestedBand!.sizeLabel} (${b.requestedBand!.range})',
          ),
          _Row(
            tr('Ukuran disetujui'),
            b.approvedBand == null
                ? tr('Belum')
                : '${b.approvedBand!.sizeLabel} (${b.approvedBand!.range})',
          ),
          _Row(
            'NIB',
            b.nib == null
                ? tr('Tidak diisi')
                : '${b.nib} (${b.nibVerified ? tr('sudah dicek') : tr('belum dicek')})',
          ),
          if (b.socialLink != null) _Row(tr('Media sosial'), b.socialLink!),
          if (b.websiteLink != null) _Row('Website', b.websiteLink!),
          if ((b.rejectionReason ?? '').isNotEmpty)
            _Row(tr('Alasan'), b.rejectionReason!),
          if (b.hiddenAt != null)
            _Row(
              tr('Disembunyikan'),
              [
                _date(b.hiddenAt),
                if ((b.hiddenReason ?? '').isNotEmpty) b.hiddenReason!,
              ].join(' · '),
            ),
          if (b.unlimitedUntil != null)
            _Row(tr('Posting tanpa batas sampai'), _date(b.unlimitedUntil)),
          _Row(tr('Didaftarkan'), _date(b.createdAt)),
          if (b.reviewedAt != null) _Row(tr('Ditinjau'), _date(b.reviewedAt)),
          if (b.updatedAt != null)
            _Row(tr('Terakhir diubah'), _date(b.updatedAt)),
        ],
      ),
    );
  }
}

/// Admin: everything about one product, read only. Opened with "Detail" on
/// Admin > Marketplace (Review queue and Products).
class AdminProductDetailScreen extends StatelessWidget {
  const AdminProductDetailScreen({super.key, required this.listing});

  final MarketplaceListing listing;

  String _status(MarketplaceListing l) {
    if (l.isHidden) return tr('Disembunyikan');
    return switch (l.status) {
      ListingStatus.pending => tr('Menunggu persetujuan'),
      ListingStatus.approved => tr('Tayang'),
      ListingStatus.rejected => tr('Ditolak'),
      ListingStatus.sold => tr('Terjual'),
    };
  }

  @override
  Widget build(BuildContext context) {
    final l = listing;
    final theme = Theme.of(context);
    final seller = l.seller;
    return Scaffold(
      appBar: AppBar(title: Text(tr('Detail produk'))),
      body: _DetailBody(
        children: [
          if (l.imageUrl.isNotEmpty)
            AppPhoto(url: l.imageUrl, aspectRatio: 1, semanticLabel: l.title),
          const SizedBox(height: 16),
          Text(
            l.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            priceLabel(l.priceIdr, l.priceNegotiable),
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _status(l),
            key: const Key('detail-status'),
            style: theme.textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Text(l.description, style: theme.textTheme.bodyLarge),
          const SizedBox(height: 16),
          if ((l.shopUrl ?? '').isNotEmpty) ...[
            Wrap(
              children: [
                SafeLinkChip(
                  icon: Icons.storefront_outlined,
                  label: tr('Buka toko'),
                  url: l.shopUrl!,
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
          _Row(
            tr('Penjual'),
            [
              seller?.name ?? 'Alumni',
              if (seller?.major != null) seller!.major!,
              if (seller?.graduationYear != null) '${seller!.graduationYear}',
            ].join(' · '),
          ),
          _Row(tr('Kategori'), l.category),
          _Row(tr('Kota'), l.city.isEmpty ? '-' : l.city),
          if ((l.contactInfo ?? '').isNotEmpty)
            _Row(tr('Kontak'), l.contactInfo!),
          if ((l.shopUrl ?? '').isNotEmpty) _Row(tr('Toko'), l.shopUrl!),
          if ((l.rejectedReason ?? '').isNotEmpty)
            _Row(tr('Alasan ditolak'), l.rejectedReason!),
          if (l.hiddenAt != null)
            _Row(
              tr('Disembunyikan'),
              [
                _date(l.hiddenAt),
                if ((l.hiddenReason ?? '').isNotEmpty) l.hiddenReason!,
              ].join(' · '),
            ),
          if (l.homeRank != null)
            _Row(tr('Disematkan di Home'), '#${l.homeRank}'),
          _Row(tr('Dibuat'), _date(l.createdAt)),
          if (l.approvedAt != null) _Row(tr('Disetujui'), _date(l.approvedAt)),
          _Row(tr('Terakhir diubah'), _date(l.updatedAt)),
        ],
      ),
    );
  }
}

String _date(DateTime? d) {
  if (d == null) return '-';
  final l = d.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(l.day)}/${two(l.month)}/${l.year}';
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    // Admins can select and copy any value (an email, a link, the NIB).
    child: SelectionArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ),
    ),
  );
}

/// One label and value line.
class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 172,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(child: Text(value, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }
}

/// The "Detail" button on admin list cards.
class AdminDetailButton extends StatelessWidget {
  const AdminDetailButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => TextButton.icon(
    onPressed: onPressed,
    icon: const Icon(Icons.info_outline, size: 18),
    label: Text(tr('Detail')),
  );
}
