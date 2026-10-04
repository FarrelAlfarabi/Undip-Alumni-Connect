import 'package:flutter/material.dart';

/// Unobtrusive banner shown on every marketplace screen.
class MarketplaceDemoNotice extends StatelessWidget {
  const MarketplaceDemoNotice({super.key});

  static const text =
      'Lingkaran does not handle payments or delivery. Deal directly with the seller and check before you pay.';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      color: theme.colorScheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 16,
            color: theme.colorScheme.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSecondaryContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
