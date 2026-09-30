import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/marketplace_format.dart';
import '../data/marketplace_repository.dart';
import '../models/marketplace_listing.dart';
import '../widgets/marketplace_demo_notice.dart';
import 'marketplace_screen.dart' show ListingImage;
import 'profile_detail_screen.dart';

typedef UrlOpener = Future<bool> Function(Uri uri);

Future<bool> _defaultOpenUrl(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// One approved listing: photo, price, description, seller card, and the
/// buyer actions. There is no checkout: buyers go to the seller's shop
/// link and/or contact them directly.
class MarketplaceDetailScreen extends StatefulWidget {
  const MarketplaceDetailScreen({
    super.key,
    required this.listing,
    required this.repository,
    required this.currentUser,
    this.openUrl = _defaultOpenUrl,
    this.onReport,
  });

  final MarketplaceListing listing;
  final MarketplaceRepository repository;
  final ValueNotifier<Map<String, dynamic>> currentUser;
  final UrlOpener openUrl;

  /// Wired to the report sheet in a later stage. Null shows a placeholder
  /// message instead.
  final VoidCallback? onReport;

  @override
  State<MarketplaceDetailScreen> createState() =>
      _MarketplaceDetailScreenState();
}

class _MarketplaceDetailScreenState extends State<MarketplaceDetailScreen> {
  bool _showContact = false;
  bool _openingProfile = false;

  MarketplaceListing get _l => widget.listing;

  Future<void> _visitShop() async {
    final uri = Uri.tryParse(_l.shopUrl ?? '');
    final messenger = ScaffoldMessenger.of(context);
    if (uri == null || !uri.hasScheme) {
      messenger.showSnackBar(
        const SnackBar(content: Text('This shop link is not valid.')),
      );
      return;
    }
    final ok = await widget.openUrl(uri);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the shop link.')),
      );
    }
  }

  Future<void> _openSellerProfile() async {
    if (_openingProfile) return;
    setState(() => _openingProfile = true);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final profile = await widget.repository.fetchSellerProfile(_l.sellerId);
      if (!mounted) return;
      if (profile == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Seller profile not found.')),
        );
        return;
      }
      navigator.push(
        MaterialPageRoute(
          builder: (_) => ProfileDetailScreen(
            profile: profile,
            showEditButton: false,
            currentUser: widget.currentUser,
          ),
        ),
      );
    } catch (_) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not open the seller profile.')),
      );
    } finally {
      if (mounted) setState(() => _openingProfile = false);
    }
  }

  void _report() {
    if (widget.onReport != null) {
      widget.onReport!();
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Reporting is not available yet.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final seller = _l.seller;
    final hasShop = (_l.shopUrl ?? '').trim().isNotEmpty;
    final hasContact = (_l.contactInfo ?? '').trim().isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Listing')),
      body: Column(
        children: [
          const MarketplaceDemoNotice(),
          Expanded(
            child: SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: ListingImage(url: _l.imageUrl),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _l.title,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatRupiah(_l.priceIdr),
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Chip(
                              avatar: const Icon(Icons.sell_outlined, size: 16),
                              label: Text(_l.category),
                            ),
                            Chip(
                              avatar: const Icon(
                                Icons.place_outlined,
                                size: 16,
                              ),
                              label: Text(_l.city),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Posted ${formatPostedDate(_l.createdAt)}',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(_l.description, style: theme.textTheme.bodyLarge),
                        const SizedBox(height: 20),
                        _SellerCard(
                          seller: seller,
                          busy: _openingProfile,
                          onTap: _openSellerProfile,
                        ),
                        const SizedBox(height: 20),
                        if (hasShop)
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _visitShop,
                              icon: const Icon(Icons.storefront_outlined),
                              label: const Text('Visit shop'),
                            ),
                          ),
                        if (hasShop && hasContact) const SizedBox(height: 8),
                        if (hasContact)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () =>
                                  setState(() => _showContact = !_showContact),
                              icon: const Icon(Icons.chat_outlined),
                              label: const Text('Contact seller'),
                            ),
                          ),
                        if (hasContact && _showContact) ...[
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: SelectableText(
                              _l.contactInfo!.trim(),
                              style: theme.textTheme.bodyLarge,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: TextButton.icon(
                            onPressed: _report,
                            icon: const Icon(Icons.flag_outlined, size: 18),
                            label: const Text('Report listing'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SellerCard extends StatelessWidget {
  const _SellerCard({
    required this.seller,
    required this.busy,
    required this.onTap,
  });

  final MarketplaceSeller? seller;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final name = seller?.name ?? 'Alumni';
    final details = [
      if ((seller?.major ?? '').isNotEmpty) seller!.major!,
      if ((seller?.faculty ?? '').isNotEmpty) seller!.faculty!,
      if (seller?.graduationYear != null) 'Class of ${seller!.graduationYear}',
    ].join(' · ');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
      child: ListTile(
        onTap: seller == null || busy ? null : onTap,
        leading: CircleAvatar(
          child: Text(name.isEmpty ? '?' : name[0].toUpperCase()),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: details.isEmpty ? null : Text(details),
        trailing: busy
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5),
              )
            : const Icon(Icons.chevron_right),
      ),
    );
  }
}
