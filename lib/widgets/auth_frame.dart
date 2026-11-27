import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../platform/breakpoints.dart';
import '../theme.dart';

/// Body of the start screens (Welcome, returning, PIN lock, PIN setup).
///
/// Phone width: the content scrolls, centred, straight on [phoneColor], as
/// before. Tablet and desktop: the same content sits in one centred card on
/// the paper background, so it does not float alone on a wide screen.
class AuthFrame extends StatelessWidget {
  const AuthFrame({
    super.key,
    required this.child,
    this.maxWidth = 440,
    this.phoneColor,
    this.cardColor = AppTheme.paperRaised,
    this.phonePadding = const EdgeInsets.all(24),
    this.phoneAlignment = Alignment.center,
    this.phoneFill = false,
  });

  final Widget child;

  /// Widest the content gets, on any screen.
  final double maxWidth;

  /// Page colour on a phone. Null leaves the Scaffold's own colour.
  final Color? phoneColor;

  /// Card colour on wide screens (black for the PIN lock).
  final Color cardColor;

  final EdgeInsets phonePadding;

  /// Where the content sits on a phone. A little below centre puts the main
  /// button or the PIN pad within easier thumb reach.
  final Alignment phoneAlignment;

  /// Phone only: the content is at least as tall as the screen, so a Column
  /// with Spacers can push part of it to the bottom. Still scrolls when the
  /// content is taller than the screen.
  final bool phoneFill;

  static const double _cardPadding = 36;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = stepForWidth(constraints.maxWidth) != ScreenStep.phone;
        final content = ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxWidth),
          child: child,
        );
        if (!wide) {
          final body = SafeArea(
            child: phoneFill
                ? LayoutBuilder(
                    builder: (context, box) => SingleChildScrollView(
                      padding: phonePadding,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(
                          minHeight: math.max(
                            0,
                            box.maxHeight - phonePadding.vertical,
                          ),
                        ),
                        child: IntrinsicHeight(child: Center(child: content)),
                      ),
                    ),
                  )
                : Align(
                    alignment: phoneAlignment,
                    child: SingleChildScrollView(
                      padding: phonePadding,
                      child: content,
                    ),
                  ),
          );
          return phoneColor == null
              ? body
              : ColoredBox(color: phoneColor!, child: body);
        }
        return ColoredBox(
          color: AppTheme.paper,
          child: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  key: const Key('auth-card'),
                  constraints: BoxConstraints(
                    maxWidth: maxWidth + _cardPadding * 2,
                  ),
                  padding: const EdgeInsets.all(_cardPadding),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.hairline),
                  ),
                  child: Center(heightFactor: 1, child: content),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
