import 'package:flutter/material.dart';

import 'biometrics.dart';
import 'lock_config.dart';
import 'lock_service.dart';
import 'pin_pad.dart';

/// PINs that are too easy to guess. Deliberately tiny; a device lock, not a
/// password policy.
bool isWeakPin(String pin) {
  if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return true; // 111111
  return const {'123456', '654321', '012345', '123123'}.contains(pin);
}

enum _Step { enter, confirm, biometric }

/// Offered right after the first successful verification: create a 6-digit
/// PIN (entered twice) and, if the device supports it, turn on biometrics.
/// Skipping is fine; the next launch then shows a "Continue" that re-runs
/// verification.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({
    super.key,
    required this.lock,
    required this.onDone,
    this.mandatory = true,
  });

  /// First sign in: the PIN cannot be skipped. From Settings the person can
  /// leave without setting one.
  final bool mandatory;

  final LockService lock;

  /// Called when the person finishes or skips. Gets this screen's context so
  /// the caller can replace it with the app.
  final Future<void> Function(BuildContext context) onDone;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  _Step _step = _Step.enter;
  String _first = '';
  String? _error;
  bool _busy = false;
  bool _bioAvailable = false;

  @override
  void initState() {
    super.initState();
    widget.lock.biometricsAvailable().then((v) {
      if (mounted) setState(() => _bioAvailable = v);
    });
  }

  Future<void> _entered(String pin) async {
    if (_step == _Step.enter) {
      if (isWeakPin(pin)) {
        setState(
          () => _error = 'PIN itu terlalu mudah ditebak. Coba yang lain.',
        );
        return;
      }
      setState(() {
        _first = pin;
        _error = null;
        _step = _Step.confirm;
      });
      return;
    }
    if (pin != _first) {
      setState(() {
        _first = '';
        _error = 'PIN tidak sama. Ulangi dari awal.';
        _step = _Step.enter;
      });
      return;
    }
    await widget.lock.setPin(pin);
    if (!mounted) return;
    if (_bioAvailable) {
      setState(() {
        _error = null;
        _step = _Step.biometric;
      });
    } else {
      await _finish();
    }
  }

  Future<void> _finish() async {
    setState(() => _busy = true);
    try {
      await widget.onDone(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _enableBiometrics() async {
    final r = await widget.lock.authenticateBiometric(
      'Konfirmasi untuk membuka dengan sidik jari atau wajah',
    );
    if (!mounted) return;
    if (r == BiometricResult.success) {
      await widget.lock.setBiometricsEnabled(true);
      await _finish();
    } else {
      setState(
        () => _error = 'Belum berhasil. Coba lagi atau lewati; PIN kamu tetap bisa dipakai.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('pin-setup'),
      appBar: AppBar(
        title: const Text('Atur PIN'),
        automaticallyImplyLeading: false,
        actions: [
          if (!widget.mandatory)
            TextButton(
              key: const Key('pin-skip'),
              onPressed: _busy ? null : _finish,
              child: const Text('Nanti saja'),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    switch (_step) {
                      _Step.enter => 'Buat PIN $kPinLength digit',
                      _Step.confirm => 'Masukkan lagi untuk konfirmasi',
                      _Step.biometric => 'Buka dengan sidik jari atau wajah?',
                    },
                    key: const Key('pin-setup-title'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _step == _Step.biometric
                        ? 'Opsional. PIN kamu tetap bisa dipakai.'
                        : 'PIN membuka Lingkaran di perangkat ini, jadi kamu tidak '
                              'perlu verifikasi tiap kali. Ini kunci praktis di '
                              'perangkat ini, bukan perlindungan tambahan untuk '
                              'akunmu.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 24),
                  if (_step == _Step.biometric) ...[
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        key: const Key('bio-enable'),
                        onPressed: _busy ? null : _enableBiometrics,
                        icon: const Icon(Icons.fingerprint),
                        label: const Text('Aktifkan'),
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('bio-skip'),
                      onPressed: _busy ? null : _finish,
                      child: const Text('Nanti saja'),
                    ),
                  ] else
                    PinPad(enabled: !_busy, onCompleted: _entered),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const Key('pin-setup-error'),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.error,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
