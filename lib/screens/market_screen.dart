import 'package:flutter/material.dart';

import '../data/business_repository.dart';
import '../data/marketplace_repository.dart';
import 'business_directory_screen.dart';
import 'job_board_screen.dart';
import 'marketplace_screen.dart';

/// The Explore tab: three segments, Marketplace, Businesses and Jobs. [segment] can be
/// changed from outside (the Home tiles open the tab on the right segment).
class MarketScreen extends StatefulWidget {
  const MarketScreen({
    super.key,
    required this.currentUser,
    required this.segment,
    this.marketplaceRepository,
    this.businessRepository,
    this.fetchJobs,
  });

  final ValueNotifier<Map<String, dynamic>> currentUser;

  /// 0 = Products, 1 = Businesses, 2 = Jobs.
  final ValueNotifier<int> segment;
  final MarketplaceRepository? marketplaceRepository;
  final BusinessRepository? businessRepository;

  /// Injectable for tests; defaults to the Supabase query.
  final Future<List<Map<String, dynamic>>> Function()? fetchJobs;

  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Explore'),
        automaticallyImplyLeading: false,
      ),
      body: ValueListenableBuilder<int>(
        valueListenable: widget.segment,
        builder: (context, index, _) => Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              // On a phone the icons and the check mark leave too little
              // room, and "Marketplace" broke over two lines. There each
              // label is text only and shrinks to fit one line.
              child: LayoutBuilder(
                builder: (context, box) {
                  final wide = box.maxWidth >= 480;
                  Widget label(String text) => wide
                      ? Text(text)
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(text, maxLines: 1, softWrap: false),
                        );
                  return SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<int>(
                      key: const Key('market-segments'),
                      showSelectedIcon: wide,
                      segments: [
                        ButtonSegment(
                          value: 0,
                          label: label('Marketplace'),
                          icon: wide
                              ? const Icon(Icons.storefront_outlined)
                              : null,
                        ),
                        ButtonSegment(
                          value: 1,
                          label: label('Businesses'),
                          icon: wide
                              ? const Icon(Icons.business_center_outlined)
                              : null,
                        ),
                        ButtonSegment(
                          value: 2,
                          label: label('Jobs'),
                          icon: wide ? const Icon(Icons.work_outline) : null,
                        ),
                      ],
                      selected: {index},
                      onSelectionChanged: (s) => widget.segment.value = s.first,
                    ),
                  );
                },
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
                  JobBoardScreen(
                    currentUser: widget.currentUser,
                    embedded: true,
                    fetchJobs: widget.fetchJobs,
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
