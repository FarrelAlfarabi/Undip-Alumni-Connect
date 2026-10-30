import 'package:flutter/material.dart';

import '../screens/welcome_screen.dart';
import 'lock_service.dart';
import 'pin_pad.dart';
import 'pin_setup_screen.dart';
import 'session.dart';

enum _Mode { menu, verifyChange, verifyRemove }

/// Profile > PIN lock. Set a PIN if there is none, or change or remove the
/// one there is. Changing or removing asks for the current PIN first, using the
/// same wrong-try counter as the lock screen (5 wrong PINs wipe this device).
/// This is a convenience lock on the device, not account security.
class PinSettingsScreen extends StatefulWidget {
  const PinSettingsScreen({super.key, required this.lock});

  final LockService lock;

  @override
  State<PinSettingsScreen> createState() => _PinSettingsScreenState();
}

class _PinSettingsScreenState extends State<PinSettingsScreen> {
  _Mode _mode = _Mode.menu;
  bool? _hasPin;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final has = await widget.lock.hasPin();
    if (mounted) {
      setState(() {
        _hasPin = has;
        _mode = _Mode.menu;
        _error = null;
      });
    }
  }

  Future<void> _openSetup() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PinSetupScreen(
          lock: widget.lock,
          onDone: (ctx) async => Navigator.of(ctx).pop(),
        ),
      ),
    );
    if (mounted) await _refresh();
  }

  Future<void> _verified(String pin) async {
    final result = await widget.lock.checkPin(pin);
    if (!mounted) return;
    switch (result) {
      case PinOk():
        if (_mode == _Mode.verifyChange) {
          setState(() => _error = null);
          await _openSetup();
        } else {
          await _confirmRemove();
        }
      case PinWrong(:final attemptsLeft):
        setState(() => _error = 'PIN salah. Sisa $attemptsLeft kesempatan.');
      case PinWait():
        setState(
          () => _error = 'Terlalu banyak percobaan salah. Tunggu sebentar, lalu coba lagi.',
        );
      case PinLockedOut():
        // The lock wiped this device's unlock data. Start again from Welcome.
        await signOutTo(context, const WelcomeScreen(), lock: widget.lock);
    }
  }

  Future<void> _confirmRemove() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus PIN?'),
        content: const Text(
          'Lingkaran akan terbuka di ponsel ini tanpa PIN. Kamu bisa membuat '
          'PIN baru kapan saja.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            key: const Key('pin-remove-confirm'),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Hapus PIN'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await widget.lock.removePin();
      if (mounted) await _refresh();
    } else if (mounted) {
      setState(() {
        _mode = _Mode.menu;
        _error = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PopScope(
      canPop: _mode == _Mode.menu,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          setState(() {
            _mode = _Mode.menu;
            _error = null;
          });
        }
      },
      child: Scaffold(
        key: const Key('pin-settings'),
        appBar: AppBar(title: const Text('PIN')),
        body: SafeArea(
          child: _hasPin == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: _mode == _Mode.menu ? _menu(theme) : _verify(theme),
                ),
        ),
      ),
    );
  }

  Widget _menu(ThemeData theme) {
    final has = _hasPin ?? false;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          has
              ? 'PIN membuka Lingkaran di ponsel ini. Ini pengaman praktis di '
                    'perangkat, bukan perlindungan tambahan untuk akunmu.'
              : 'Belum ada PIN. Lingkaran terbuka di ponsel ini tanpa PIN.',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        if (!has)
          FilledButton(
            key: const Key('pin-set'),
            onPressed: _openSetup,
            child: const Text('Atur PIN'),
          )
        else ...[
          ListTile(
            key: const Key('pin-change'),
            leading: const Icon(Icons.password),
            title: const Text('Ubah PIN'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _mode = _Mode.verifyChange),
          ),
          ListTile(
            key: const Key('pin-remove'),
            leading: Icon(Icons.lock_open, color: theme.colorScheme.error),
            title: Text(
              'Hapus PIN',
              style: TextStyle(color: theme.colorScheme.error),
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => setState(() => _mode = _Mode.verifyRemove),
          ),
        ],
      ],
    );
  }

  Widget _verify(ThemeData theme) => Column(
    children: [
      Text(
        'Masukkan PIN kamu saat ini',
        key: const Key('pin-verify-title'),
        style: theme.textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      const SizedBox(height: 16),
      PinPad(onCompleted: _verified),
      if (_error != null) ...[
        const SizedBox(height: 12),
        Text(
          _error!,
          key: const Key('pin-verify-error'),
          style: TextStyle(color: theme.colorScheme.error),
          textAlign: TextAlign.center,
        ),
      ],
    ],
  );
}
