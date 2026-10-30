import 'package:flutter/material.dart';

import '../platform/breakpoints.dart';

/// Gives a page its width step and centres it under the step's max width.
class ResponsivePage extends StatelessWidget {
  const ResponsivePage({super.key, required this.builder});

  final Widget Function(BuildContext context, ScreenStep step) builder;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final step = stepForWidth(constraints.maxWidth);
      return Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxContentWidth(step)),
          child: builder(context, step),
        ),
      );
    });
  }
}
