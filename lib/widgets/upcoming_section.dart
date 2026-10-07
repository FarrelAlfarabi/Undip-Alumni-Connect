import 'package:flutter/material.dart';

/// Shown in every preview sheet. Kept as one constant so tests and copy
/// stay in sync.
const String kPreviewNotice =
    'This feature is a preview and is not available yet.';

class _PreviewFeature {
  const _PreviewFeature(this.key, this.icon, this.name, this.description);
  final String key;
  final IconData icon;
  final String name;
  final String description;
}

// No dates, no promises, no money features.
const _features = [
  _PreviewFeature(
    'preview-events',
    Icons.event_outlined,
    'Events',
    'Sports, reunions and sharing sessions with fellow alumni.',
  ),
  _PreviewFeature(
    'preview-mentoring',
    Icons.school_outlined,
    'Mentoring',
    'Connect with alumni for career guidance.',
  ),
];

/// "Upcoming" section on Home: two non-functional Preview tiles. Tapping
/// one only opens an info sheet. Nothing navigates, nothing is tracked.
class UpcomingSection extends StatelessWidget {
  const UpcomingSection({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      key: const Key('upcoming-section'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Upcoming',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        for (final f in _features) ...[
          _PreviewTile(feature: f),
          const SizedBox(height: 8),
        ],
      ],
    );
  }
}

class _PreviewTile extends StatelessWidget {
  const _PreviewTile({required this.feature});

  final _PreviewFeature feature;

  void _open(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(child: _PreviewSheet(feature: feature)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    return Material(
      key: Key(feature.key),
      color: scheme.surfaceContainer.withValues(alpha: 0.45),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        customBorder: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
        onTap: () => _open(context),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(feature.icon, color: muted),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  feature.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(color: muted),
                ),
              ),
              const SizedBox(width: 8),
              const PreviewBadge(),
            ],
          ),
        ),
      ),
    );
  }
}

class PreviewBadge extends StatelessWidget {
  const PreviewBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        'Preview',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: scheme.onSecondaryContainer,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PreviewSheet extends StatelessWidget {
  const _PreviewSheet({required this.feature});

  final _PreviewFeature feature;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          key: const Key('preview-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(feature.name, style: theme.textTheme.titleLarge),
                ),
                const SizedBox(width: 8),
                const PreviewBadge(),
              ],
            ),
            const SizedBox(height: 8),
            Text(feature.description, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 12),
            Text(
              kPreviewNotice,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
