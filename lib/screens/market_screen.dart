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
              child: SizedBox(
                width: double.infinity,
                child: SegmentedButton<int>(
                  key: const Key('market-segments'),
                  showSelectedIcon: false,
                  style: const ButtonStyle(
                    padding: WidgetStatePropertyAll(
                      EdgeInsets.symmetric(horizontal: 4),
                    ),
                  ),
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      label: _SegmentLabel('Marketplace'),
                    ),
                    ButtonSegment(value: 1, label: _SegmentLabel('Businesses')),
                    ButtonSegment(value: 2, label: _SegmentLabel('Jobs')),
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

/// Segment label that never wraps mid-word; shrinks slightly on very
/// narrow phones instead.
class _SegmentLabel extends StatelessWidget {
  const _SegmentLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, maxLines: 1, softWrap: false),
  );
}
