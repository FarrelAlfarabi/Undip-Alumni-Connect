import '../nav/back_guard.dart';
import '../util/app_language.dart';

import 'package:flutter/material.dart';

import '../kawung_mark.dart';
import '../theme.dart';
import '../util/app_info.dart';
import '../widgets/auth_frame.dart';
import '../widgets/sponsor_slot.dart';
import 'verification_screen.dart';

/// The app's actual entry screen — a proper branded landing moment in
/// front of the verification form, instead of dropping straight into a
/// bare card. Matches the pitch landing page's identity (kawung mark,
/// yellow, black and blue palette, Plus Jakarta Sans).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key, this.notice, this.sponsorLoader});

  /// Tests replace how sponsors load.
  final SponsorLoader? sponsorLoader;

  /// Short message shown above the heading, e.g. after a failed sign-in on
  /// this device.
  final String? notice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SponsorFooterFrame(
        loader: sponsorLoader,
        child: AuthFrame(
          phonePadding: const EdgeInsets.symmetric(
            horizontal: 28,
            vertical: 12,
          ),
          phoneAlignment: const Alignment(0, 0.9),
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
                    tr(notice!),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSecondaryContainer,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              const SizedBox(height: 0),
              const KawungMark(size: 48, color: AppTheme.black),
              const SizedBox(height: 6),
              Text(
                'Lingkaran',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                tr('by Ikafe Undip'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                tr(
                  'Jejaring alumni FEB Undip untuk saling terhubung, berbagi peluang, dan tumbuh bersama',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineMedium?.copyWith(height: 1.15),
              ),
              const SizedBox(height: 16),
              Text(
                tr(
                  'Verifikasi dirimu, cari alumni berdasarkan jurusan dan angkatan, '
                  'dukung usaha alumni, dan rekomendasikan lowongan kerja.',
                ),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    Navigator.of(context).push(
                      AppRoute(builder: (_) => const VerificationScreen()),
                    );
                  },
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(tr('Mulai')),
                ),
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              Text(
                tr('Beta. Bukan layanan resmi Universitas Diponegoro.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant.withValues(
                    alpha: 0.7,
                  ),
                ),
              ),
              SponsorInCard(loader: sponsorLoader),
            ],
          ),
        ),
      ),
    );
  }
}
