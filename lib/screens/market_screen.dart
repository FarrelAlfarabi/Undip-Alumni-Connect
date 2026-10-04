import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../data/marketplace_repository.dart';
import 'business_directory_screen.dart';
import 'marketplace_screen.dart';

/// The Market tab: two segments, Products and Businesses. [segment] can be
/// changed from outside (the Home tiles open the tab on the right segment).
class MarketScreen extends StatefulWidget {
  const MarketScreen({
    super.key,
    required this.currentUser,
    required this.segment,
    this.marketplaceRepository,
    this.businessRepository,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// 0 = Products, 1 = Businesses.
  final ValueNotifier<int> segment;
  final MarketplaceRepository? marketplaceRepository;
  final BusinessRepository? businessRepository;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Market'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: widget.segment,
        builder: (context, index, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  key: const Key('market-segments'),
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: Text('Products'),
                      icon: Icon(Icons.storefront_outlined),
                    ),
                    ButtonSegment(
                      value: 1,
                      label: Text('Businesses'),
                      icon: Icon(Icons.business_center_outlined),
                    ),
                  ],
                  selected: {index},
                  onSelectionChanged: (s) => widget.segment.value = s.first,
                ),
              ),
            ),
            Expanded(
              child: IndexedStack(
                index: index,
                children: [
                  MarketplaceScreen(
                    currentUser: widget.currentUser,
                    repository: widget.marketplaceRepository,
                    embedded: true,
                  ),
                  BusinessDirectoryScreen(
                    currentUser: widget.currentUser,
                    repository: widget.businessRepository,
                    embedded: true,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
