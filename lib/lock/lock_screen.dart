import 'dart:async';

import 'package:flutter/material.dart';

import '../kawung_mark.dart';
import '../theme.dart';
import 'biometrics.dart';
import 'lock_config.dart';
import 'lock_service.dart';
import 'masking.dart';
import 'pin_pad.dart';

/// Shown to a person already verified on this device. Dark indigo and a PIN
/// pad, so it reads as a different screen from the first-time Welcome.
///
/// This is a device-level convenience lock, not real security (see README).
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.lock,
    required this.user,
    required this.onUnlocked,
    required this.onSwitchAccount,
    required this.onForgotPin,
    required this.onLockedOut,
    required this.onContinue,
    this.autoBiometric = true,
    this.clock = DateTime.now,
  });

  final LockService lock;
  final RememberedUser user;

  /// PIN or biometric accepted. The screen shows a spinner until it returns.
  final Future<void> Function() onUnlocked;
  final Future<void> Function() onSwitchAccount;
  final Future<void> Function() onForgotPin;

  /// 5th wrong PIN (local data is already wiped).
  final Future<void> Function() onLockedOut;

  /// Shown instead of the PIN pad when no PIN was ever set.
  final Future<void> Function() onContinue;

  final bool autoBiometric;
  final DateTime Function() clock;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  bool _loaded = false;
  bool _hasPin = false;
  bool _bio = false;
  bool _busy = false;
  int _attemptsLeft = kMaxPinAttempts;
  DateTime? _waitUntil;
  String? _message;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _init();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _init() async {
    final hasPin = await widget.lock.hasPin();
    final bio = hasPin && await widget.lock.biometricsEnabled();
    final left = await widget.lock.attemptsLeft();
    final wait = await widget.lock.waitUntil();
    if (!mounted) return;
    setState(() {
      _hasPin = hasPin;
      _bio = bio;
      _attemptsLeft = left;
      _loaded = true;
    });
    _startWait(wait);
    if (bio && wait == null && widget.autoBiometric) _tryBiometric();
  }

  void _startWait(DateTime? until) {
    _ticker?.cancel();
    if (until == null) {
      setState(() => _waitUntil = null);
      return;
    }
    setState(() => _waitUntil = until);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (!widget.clock().isBefore(until)) {
        _ticker?.cancel();
        setState(() {
          _waitUntil = null;
          _message = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  int get _secondsLeft {
    final until = _waitUntil;
    if (until == null) return 0;
    final ms = until.difference(widget.clock()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  Future<void> _submit(String pin) async {
    final result = await widget.lock.checkPin(pin);
    if (!mounted) return;
    switch (result) {
      case PinOk():
        await _run(widget.onUnlocked);
      case PinWrong(:final attemptsLeft, :final waitUntil):
        setState(() {
          _attemptsLeft = attemptsLeft;
          _message = 'Wrong PIN.';
        });
        _startWait(waitUntil);
      case PinWait(:final until):
        _startWait(until);
      case PinLockedOut():
        await _run(widget.onLockedOut);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _tryBiometric() async {
    if (_busy) return;
    final r = await widget.lock.authenticateBiometric('Unlock Lingkaran');
    if (!mounted) return;
    if (r == BiometricResult.success) {
      await _run(widget.onUnlocked);
    } else {
      // Failed, cancelled or unavailable: the PIN pad is always the fallback.
      setState(() => _message = 'Use your PIN instead.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const fg = AppTheme.paper;
    final waiting = _waitUntil != null;
    // Short phones (about 568 px tall): drop the big mark, shrink the avatar.
    final compact = MediaQuery.sizeOf(context).height < 640;

    return Scaffold(
      key: const Key('lock-screen'),
      backgroundColor: AppTheme.indigo,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (!compact) ...[
                    const KawungMark(size: 32, color: AppTheme.goldBright),
                    const SizedBox(height: 6),
                  ],
                  Text(
                    'LINGKARAN',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: fg,
                      letterSpacing: 2,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: compact ? 10 : 20),
                  CircleAvatar(
                    radius: compact ? 22 : 30,
                    backgroundColor: AppTheme.gold,
                    child: Text(
                      initialsOf(widget.user.displayName),
                      style: theme.textTheme.titleLarge?.copyWith(color: fg),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Welcome back, ${_first(widget.user.displayName)}',
                    key: const Key('lock-welcome'),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(color: fg),
                  ),
                  if (widget.user.maskedEmail.isNotEmpty)
                    Text(
                      widget.user.maskedEmail,
                      key: const Key('lock-masked-email'),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: fg.withValues(alpha: 0.75),
                      ),
                    ),
                  const SizedBox(height: 24),
                  if (!_loaded)
                    const CircularProgressIndicator(color: fg)
                  else if (!_hasPin)
                    ..._noPin(theme)
                  else ...[
                    IgnorePointer(
                      ignoring: _busy,
                      child: PinPad(
                        foreground: fg,
                        enabled: !waiting && !_busy,
                        onCompleted: _submit,
                        onBiometric: _bio ? _tryBiometric : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _status(theme),
                  ],
                  const SizedBox(height: 16),
                  TextButton(
                    key: const Key('lock-forgot'),
                    onPressed: _busy ? null : () => _run(widget.onForgotPin),
                    style: TextButton.styleFrom(foregroundColor: fg),
                    child: const Text('Forgot PIN? Verify again'),
                  ),
                  TextButton(
                    key: const Key('lock-switch'),
                    onPressed: _busy
                        ? null
                        : () => _run(widget.onSwitchAccount),
                    style: TextButton.styleFrom(foregroundColor: fg),
                    child: const Text('Not you? Switch account'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _noPin(ThemeData theme) => [
    Text(
      'Verify your email to continue.',
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: AppTheme.paper.withValues(alpha: 0.85),
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const Key('lock-continue'),
        onPressed: _busy ? null : () => _run(widget.onContinue),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.gold,
          foregroundColor: AppTheme.paper,
        ),
        child: const Text('Continue'),
      ),
    ),
  ];

  Widget _status(ThemeData theme) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: AppTheme.paper.withValues(alpha: 0.85),
    );
    final lines = <String>[];
    if (_waitUntil != null) {
      lines.add('Try again in ${_secondsLeft}s.');
    } else if (_message != null) {
      lines.add(_message!);
    }
    if (_attemptsLeft < kMaxPinAttempts) {
      lines.add(
        _attemptsLeft == 1
            ? '1 attempt left.'
            : '$_attemptsLeft attempts left.',
      );
    }
    return Text(
      lines.join(' '),
      key: const Key('lock-status'),
      textAlign: TextAlign.center,
      style: style,
    );
  }

  String _first(String name) {
    final n = name.trim();
    return n.isEmpty ? 'there' : n.split(RegExp(r'\s+')).first;
  }
}
