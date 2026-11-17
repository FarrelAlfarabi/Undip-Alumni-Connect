import 'package:flutter/material.dart';

import '../kawung_mark.dart';
import '../theme.dart';
import '../util/app_language.dart';
import '../widgets/auth_frame.dart';
import 'verification_screen.dart';

/// Web only. Shown when someone signed in on this browser before and the
/// sign in has ended. It greets them by first name and sends them to the
/// email code step, instead of the first-time Welcome. It opens nothing by
/// itself: the person still has to sign in.
class ReturningScreen extends StatelessWidget {
  const ReturningScreen({
    super.key,
    required this.name,
    required this.onNotYou,
    this.notice,
  });

  /// First name only.
  final String name;

  /// Forget the name kept on this browser and show the first-time Welcome.
  final Future<void> Function() onNotYou;

  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('returning-screen'),
      backgroundColor: Colors.white,
      body: AuthFrame(
        phonePadding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const KawungMark(size: 56, color: AppTheme.black),
            const SizedBox(height: 12),
            Text(
              'Lingkaran',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 28),
            Text(
              trf('Selamat datang kembali, {0}', [name]),
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            const SizedBox(height: 12),
            Text(
              tr(
                'Sesi masukmu di browser ini sudah berakhir. Masuk lagi '
                'dengan kode yang kami kirim ke emailmu.',
              ),
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 28),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                key: const Key('returning-continue'),
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const VerificationScreen()),
                ),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: Text(tr('Masuk lagi')),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              key: const Key('returning-not-you'),
              onPressed: onNotYou,
              child: Text(tr('Bukan kamu? Ganti akun')),
            ),
          ],
        ),
      ),
    );
  }
}
