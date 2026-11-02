import 'package:flutter/material.dart';

/// The LinkedIn "in" mark: white letters on a rounded square in LinkedIn blue.
/// Drawn in code so the app needs no extra image or package.
class LinkedInLogo extends StatelessWidget {
  const LinkedInLogo({super.key, this.size = 24});

  final double size;

  static const _linkedInBlue = Color(0xFF0A66C2);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: _linkedInBlue,
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      child: Text(
        'in',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.6,
          fontWeight: FontWeight.w800,
          height: 1,
        ),
      ),
    );
  }
}
