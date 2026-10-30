import 'package:flutter/material.dart';

const kIkafeLogoAsset = 'assets/brand/ikafe_undip_logo.png';

/// The Ikafe UNDIP logo on a white chip. The logo has black letters, so it
/// always sits on white, whatever the background around it is.
class IkafeLogo extends StatelessWidget {
  const IkafeLogo({super.key, this.height = 22});

  final double height;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Image.asset(
          kIkafeLogoAsset,
          height: height,
          semanticLabel: 'Ikafe UNDIP',
          // Decode at the drawn size so the 1600 px file stays cheap.
          cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).ceil(),
          filterQuality: FilterQuality.medium,
        ),
      ),
    );
  }
}

/// "Lingkaran by Ikafe UNDIP": the logo chip next to the app name.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Scales down instead of overflowing on narrow screens or large text.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const IkafeLogo(),
          const SizedBox(width: 10),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Lingkaran',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  height: 1.1,
                ),
              ),
              Text(
                'by Ikafe UNDIP',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
