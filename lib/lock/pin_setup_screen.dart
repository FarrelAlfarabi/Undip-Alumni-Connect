import 'package:flutter/material.dart';

import '../screens/welcome_screen.dart';
import '../util/app_language.dart';
import '../widgets/auth_frame.dart';

import 'biometrics.dart';
import 'lock_config.dart';
import 'lock_service.dart';
import 'pin_pad.dart';
import 'session.dart';

/// PINs that are too easy to guess. Deliberately tiny; a device lock, not a
/// password policy.
bool isWeakPin(String pin) {
  if (RegExp(r'^(\d)\1+$').hasMatch(pin)) return true; // 111111
  return const {'123456', '654321', '012345', '123123'}.contains(pin);
}

enum _Step { enter, confirm, biometric }

/// The account could not be reached while saving the PIN.
const String kPinNotSavedMessage =
    'PIN belum tersimpan. Periksa internet, lalu coba lagi.';

/// The account has a PIN and this sign in may not replace it.
const String kPinNeedsOldMessage =
    'Akunmu sudah punya PIN. Buka dengan PIN itu dulu, atau pilih Lupa PIN '
    'lalu masuk lagi dengan kode email.';

/// Offered right after the first successful verification: create a 6-digit
/// PIN (entered twice) and, if the device supports it, turn on biometrics.
/// It can only be skipped when [mandatory] is false (from Settings).
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
          () => _error = tr('PIN itu terlalu mudah ditebak. Coba yang lain.'),
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
        _error = tr('PIN tidak sama. Ulangi dari awal.');
        _step = _Step.enter;
      });
      return;
    }
    try {
      await widget.lock.setPin(pin);
    } on PinSyncException catch (e) {
      if (!mounted) return;
      setState(() {
        _first = '';
        _error = tr(e.needsOldPin ? kPinNeedsOldMessage : kPinNotSavedMessage);
        _step = _Step.enter;
      });
      return;
    }
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

  /// A forced PIN setup (web) must still have a way out for someone on the
  /// wrong account.
  Future<void> _leave() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('Ganti akun?')),
        content: Text(
          tr('Keluar dari akun ini? Kamu perlu kode email lagi untuk masuk.'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(tr('Batal')),
          ),
          FilledButton(
            key: const Key('pin-setup-switch-yes'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(tr('Ya, keluar')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await signOutTo(
      context,
      const WelcomeScreen(),
      lock: widget.lock,
      forget: true,
    );
  }

  Future<void> _enableBiometrics() async {
    final r = await widget.lock.authenticateBiometric(
      tr('Konfirmasi untuk membuka dengan sidik jari atau wajah'),
    );
    if (!mounted) return;
    if (r == BiometricResult.success) {
      await widget.lock.setBiometricsEnabled(true);
      await _finish();
    } else {
      setState(
        () => _error = tr(
          'Belum berhasil. Coba lagi atau lewati; PIN kamu tetap bisa dipakai.',
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('pin-setup'),
      appBar: AppBar(
        title: Text(tr('Atur PIN')),
        automaticallyImplyLeading: false,
        actions: [
          if (!widget.mandatory)
            TextButton(
              key: const Key('pin-skip'),
              onPressed: _busy ? null : _finish,
              child: Text(tr('Nanti saja')),
            ),
        ],
      ),
      body: AuthFrame(
        maxWidth: 380,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              switch (_step) {
                _Step.enter => trf('Buat PIN {0} digit', [kPinLength]),
                _Step.confirm => tr('Masukkan lagi untuk konfirmasi'),
                _Step.biometric => tr('Buka dengan sidik jari atau wajah?'),
              },
              key: const Key('pin-setup-title'),
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              _step == _Step.biometric
                  ? tr('Opsional. PIN kamu tetap bisa dipakai.')
                  : tr(
                      'PIN membuka Lingkaran di perangkat ini, jadi kamu tidak '
                      'perlu verifikasi tiap kali. Ini kunci praktis di '
                      'perangkat ini, bukan perlindungan tambahan untuk '
                      'akunmu.',
                    ),
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
                  label: Text(tr('Aktifkan')),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                key: const Key('bio-skip'),
                onPressed: _busy ? null : _finish,
                child: Text(tr('Nanti saja')),
              ),
            ] else
              PinPad(enabled: !_busy, onCompleted: _entered),
            if (widget.mandatory) ...[
              const SizedBox(height: 12),
              TextButton(
                key: const Key('pin-setup-switch'),
                onPressed: _busy ? null : _leave,
                child: Text(tr('Bukan kamu? Ganti akun')),
              ),
            ],
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
    );
  }
}
