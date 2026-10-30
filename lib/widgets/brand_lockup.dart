import 'package:flutter/material.dart';

const kIkafeLogoAsset = 'assets/brand/ikafe_undip_logo.png';

/// The Ikafe UNDIP logo, the one place that draws the image. The logo has
/// black letters on white, so by default it sits on a white chip. On a white
/// surface (the Home header) pass `chip: false` so no box shows.
class IkafeLogo extends StatelessWidget {
  const IkafeLogo({super.key, this.height = 22, this.chip = true});

  final double height;
  final bool chip;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      kIkafeLogoAsset,
      height: height,
      semanticLabel: 'IKAFE UNDIP',
      // Decode at the drawn size so the 1600 px file stays cheap.
      cacheHeight: (height * MediaQuery.devicePixelRatioOf(context)).ceil(),
      filterQuality: FilterQuality.medium,
    );
    if (!chip) return image;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: image,
      ),
    );
  }
}

/// Home header content: only the logo, 28 px high, on the white app bar.
class BrandLockup extends StatelessWidget {
  const BrandLockup({super.key});

  @override
  Widget build(BuildContext context) =>
      const IkafeLogo(height: 28, chip: false);
}
