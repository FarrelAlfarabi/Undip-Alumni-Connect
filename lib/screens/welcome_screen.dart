import '../widgets/closed_test_notice.dart';

import 'package:flutter/material.dart';

import '../kawung_mark.dart';
import '../theme.dart';
import '../util/app_info.dart';
import 'verification_screen.dart';

/// The app's actual entry screen — a proper branded landing moment in
/// front of the verification form, instead of dropping straight into a
/// bare card. Matches the pitch landing page's identity (kawung mark,
/// yellow, black and blue palette, Fraunces + IBM Plex Sans).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.notice});

  /// Short message shown above the heading, e.g. after a failed sign-in on
  /// this device.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (notice != null) ...[
                    Container(
                      key: const Key('welcome-notice'),
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.secondaryContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        notice!,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSecondaryContainer,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  const SizedBox(height: 12),
                  const KawungMark(size: 64, color: AppTheme.black),
                  const SizedBox(height: 12),
                  Text(
                    'Lingkaran',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    'by Ikafe Undip',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Jejaring alumni FEB Undip untuk saling terhubung, berbagi peluang, dan tumbuh bersama',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verifikasi dirimu, cari alumni berdasarkan jurusan dan angkatan, '
                    'dukung usaha alumni, dan rekomendasikan lowongan kerja.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 36),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const VerificationScreen(),
                          ),
                        );
                      },
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: const Text('Mulai'),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const ClosedTestNotice(),
                  const SizedBox(height: 12),
                  Text(
                    'Beta tertutup · data awal dari anggota Ikafe',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  FutureBuilder<AppInfo>(
                    future: AppInfo.load(),
                    builder: (context, snap) => Text(
                      'BETA${snap.data == null ? '' : ' · ${snap.data!.short}'}',
                      key: const Key('welcome-version'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Beta tertutup. Tampilan sementara, bukan identitas resmi '
                    'UNDIP atau Ikafe.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(
                        alpha: 0.7,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
