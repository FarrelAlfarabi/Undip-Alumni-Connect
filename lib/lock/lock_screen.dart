import 'dart:async';

import '../util/app_language.dart';

import 'package:flutter/material.dart';

import '../kawung_mark.dart';
import '../platform/breakpoints.dart';
import '../theme.dart';
import '../widgets/auth_frame.dart';
import '../widgets/brand_lockup.dart';
import '../widgets/sponsor_slot.dart';
import 'biometrics.dart';
import 'lock_config.dart';
import 'lock_service.dart';
import 'masking.dart';
import 'pin_pad.dart';

/// The PIN this device had before one PIN per account was typed.
const String kOldDevicePinMessage =
    'Ini PIN lama perangkat ini. Sekarang satu PIN untuk semua perangkat: '
    'pakai PIN yang kamu buat di perangkat lain, atau pilih Lupa PIN.';

/// The account PIN is not on this device yet and there is no internet.
const String kPinOfflineMessage =
    'PIN akunmu belum ada di perangkat ini. Sambungkan ke internet, lalu '
    'coba lagi.';

/// Shown to a person already verified on this device. Black and a PIN
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
    this.onResetElsewhere,
    this.autoBiometric = true,
    this.clock = DateTime.now,
    this.sponsorLoader,
  });

  /// Tests replace how sponsors load.
  final SponsorLoader? sponsorLoader;

  final LockService lock;
  final RememberedUser user;

  /// PIN or biometric accepted. The screen shows a spinner until it returns.
  final Future<void> Function() onUnlocked;
  final Future<void> Function() onSwitchAccount;
  final Future<void> Function() onForgotPin;

  /// 5th wrong PIN (local data is already wiped).
  final Future<void> Function() onLockedOut;

  /// The account PIN was removed on another device (5 wrong tries there or
  /// "Hapus PIN"). Local data is already wiped. Defaults to [onLockedOut].
  final Future<void> Function()? onResetElsewhere;

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

  /// The action waiting for "Ya, keluar" (forgot PIN or switch account).
  /// Both end the sign in, so they ask first. Inline, not a dialog: this
  /// screen can sit outside the Navigator (relock after the app was away).
  Future<void> Function()? _pendingLeave;

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
          _message = tr('PIN salah.');
        });
        _startWait(waitUntil);
      case PinWait(:final until):
        _startWait(until);
      case PinLockedOut(:final resetElsewhere):
        await _run(
          resetElsewhere
              ? (widget.onResetElsewhere ?? widget.onLockedOut)
              : widget.onLockedOut,
        );
      case PinOldDevicePin():
        setState(() => _message = tr(kOldDevicePinMessage));
      case PinOffline():
        setState(() => _message = tr(kPinOfflineMessage));
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
    final r = await widget.lock.authenticateBiometric(tr('Buka Lingkaran'));
    if (!mounted) return;
    if (r == BiometricResult.success) {
      await _run(widget.onUnlocked);
    } else {
      // Failed, cancelled or unavailable: the PIN pad is always the fallback.
      setState(() => _message = tr('Pakai PIN kamu saja.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const fg = AppTheme.black;
    final waiting = _waitUntil != null;
    // Short phones (about 568 px tall): drop the big mark, shrink the avatar.
    final compact = MediaQuery.sizeOf(context).height < 640;
    // Phones up to about 900 px tall: no big mark and tighter gaps, so the
    // PIN pad, both links and the sponsor card fit without scrolling.
    final tight = MediaQuery.sizeOf(context).height < 900;
    // Phones under about 760 px (usual with the browser bar showing): no
    // avatar and smaller keys, so everything fits above the sponsor card.
    final short = MediaQuery.sizeOf(context).height < 760;
    final phone =
        stepForWidth(MediaQuery.sizeOf(context).width) == ScreenStep.phone;

    return Scaffold(
      key: const Key('lock-screen'),
      body: SponsorFooterFrame(
        loader: widget.sponsorLoader,
        child: AuthFrame(
          maxWidth: 380,
          phonePadding: const EdgeInsets.symmetric(
            horizontal: 24,
            vertical: 16,
          ),
          phoneFill: true,
          child: Column(
            mainAxisSize: phone ? MainAxisSize.max : MainAxisSize.min,
            children: [
              // Phone: the header sits in the middle of the free space and the
              // PIN pad with the links sits low, near the thumb.
              if (phone) const Spacer(),
              if (!compact && !tight) ...[
                const KawungMark(size: 32, color: AppTheme.black),
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
              const SizedBox(height: 8),
              IkafeLogo(height: compact ? 16 : 22),
              SizedBox(height: compact ? 10 : (tight ? 14 : 20)),
              if (!short) ...[
                CircleAvatar(
                  radius: compact ? 22 : (tight ? 24 : 30),
                  backgroundColor: AppTheme.yellow,
                  child: Text(
                    initialsOf(widget.user.displayName),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: AppTheme.black,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                trf('Selamat datang kembali, {0}', [
                  _first(widget.user.displayName),
                ]),
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
              if (phone) const Spacer(flex: 2),
              SizedBox(height: tight ? 10 : 24),
              if (!_loaded)
                const CircularProgressIndicator(color: fg)
              else if (!_hasPin)
                ..._noPin(theme)
              else ...[
                IgnorePointer(
                  ignoring: _busy,
                  child: PinPad(
                    foreground: fg,
                    keyHeight: short ? 52 : 64,
                    enabled: !waiting && !_busy,
                    onCompleted: _submit,
                    onBiometric: _bio ? _tryBiometric : null,
                  ),
                ),
                const SizedBox(height: 12),
                _status(theme),
              ],
              const SizedBox(height: 8),
              if (_pendingLeave != null)
                ..._confirmLeave(theme, fg)
              else ...[
                TextButton(
                  key: const Key('lock-forgot'),
                  onPressed: _busy
                      ? null
                      : () =>
                            setState(() => _pendingLeave = widget.onForgotPin),
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: Text(tr('Lupa PIN? Verifikasi ulang')),
                ),
                TextButton(
                  key: const Key('lock-switch'),
                  onPressed: _busy
                      ? null
                      : () => setState(
                          () => _pendingLeave = widget.onSwitchAccount,
                        ),
                  style: TextButton.styleFrom(foregroundColor: fg),
                  child: Text(tr('Bukan kamu? Ganti akun')),
                ),
              ],
              SponsorInCard(loader: widget.sponsorLoader),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _confirmLeave(ThemeData theme, Color fg) => [
    Text(
      tr('Keluar dari akun ini? Kamu perlu kode email lagi untuk masuk.'),
      key: const Key('lock-confirm-text'),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(color: fg),
    ),
    const SizedBox(height: 8),
    FilledButton(
      key: const Key('lock-confirm-yes'),
      onPressed: _busy
          ? null
          : () {
              final action = _pendingLeave!;
              setState(() => _pendingLeave = null);
              _run(action);
            },
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.yellow,
        foregroundColor: AppTheme.black,
      ),
      child: Text(tr('Ya, keluar')),
    ),
    TextButton(
      key: const Key('lock-confirm-no'),
      onPressed: () => setState(() => _pendingLeave = null),
      style: TextButton.styleFrom(foregroundColor: fg),
      child: Text(tr('Batal')),
    ),
  ];

  List<Widget> _noPin(ThemeData theme) => [
    Text(
      tr('Verifikasi emailmu untuk melanjutkan.'),
      textAlign: TextAlign.center,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: AppTheme.black.withValues(alpha: 0.85),
      ),
    ),
    const SizedBox(height: 16),
    SizedBox(
      width: double.infinity,
      child: FilledButton(
        key: const Key('lock-continue'),
        onPressed: _busy ? null : () => _run(widget.onContinue),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.yellow,
          foregroundColor: AppTheme.black,
        ),
        child: Text(tr('Lanjut')),
      ),
    ),
  ];

  Widget _status(ThemeData theme) {
    final style = theme.textTheme.bodyMedium?.copyWith(
      color: AppTheme.black.withValues(alpha: 0.85),
    );
    final lines = <String>[];
    if (_waitUntil != null) {
      lines.add(trf('Coba lagi dalam {0} dtk.', [_secondsLeft]));
    } else if (_message != null) {
      lines.add(_message!);
    }
    if (_attemptsLeft < kMaxPinAttempts) {
      lines.add(
        _attemptsLeft == 1
            ? tr('Sisa 1 percobaan.')
            : trf('Sisa {0} percobaan.', [_attemptsLeft]),
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
    return n.isEmpty ? 'kamu' : n.split(RegExp(r'\s+')).first;
  }
}
