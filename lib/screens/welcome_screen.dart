import 'package:flutter/material.dart';

import '../kawung_mark.dart';
import 'verification_screen.dart';

/// The app's actual entry screen — a proper branded landing moment in
/// front of the verification form, instead of dropping straight into a
/// bare card. Matches the pitch landing page's identity (kawung mark,
/// indigo/brass palette, Fraunces + IBM Plex Sans).
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
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
                  const SizedBox(height: 12),
                  const KawungMark(size: 48),
                  const SizedBox(height: 20),
                  Text(
                    'ALUMNI CONNECT',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 2,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  Text(
                    'UNIVERSITAS DIPONEGORO',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.6,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'A verified alumni directory,\nbuilt to move people forward.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Verify who you are, search the directory by faculty '
                    'and angkatan, and refer each other into real jobs.',
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
                      child: const Text('Get Started'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Closed beta · seeded from ILUNI UNDIP\'s member base',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 40),
                  Text(
                    'Demo build with dummy data. Placeholder visual '
                    'identity — not UNDIP\'s or ILUNI\'s official branding.',
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
