import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lock_config.dart';

/// A 6-digit PIN pad: dots on top, 3x4 keys below. Calls [onCompleted] when
/// the 6th digit is entered, ignores taps while that call is running, then
/// clears itself. [onBiometric], when set, shows a fingerprint key.
class PinPad extends StatefulWidget {
  const PinPad({
    super.key,
    required this.onCompleted,
    this.enabled = true,
    this.onBiometric,
    this.foreground,
  });

  final Future<void> Function(String pin) onCompleted;
  final bool enabled;
  final VoidCallback? onBiometric;

  /// Colour of dots and digits; defaults to the theme's `onSurface`.
  final Color? foreground;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _pin = '';
  bool _busy = false;

  bool get _canType => widget.enabled && !_busy;

  Future<void> _digit(String d) async {
    if (!_canType || _pin.length >= kPinLength) return;
    setState(() => _pin += d);
    if (_pin.length == kPinLength) {
      final entered = _pin;
      setState(() => _busy = true);
      try {
        await widget.onCompleted(entered);
      } finally {
        if (mounted) {
          setState(() {
            _pin = '';
            _busy = false;
          });
        }
      }
    }
  }

  void _back() {
    if (!_canType || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  /// Computer keyboard: number keys (top row and number pad) and Backspace.
  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final ch = event.character;
    if (key == LogicalKeyboardKey.backspace ||
        key == LogicalKeyboardKey.delete) {
      _back();
      return KeyEventResult.handled;
    }
    final digit =
        _digitOf(key) ??
        (ch != null && RegExp(r'^[0-9]$').hasMatch(ch) ? ch : null);
    if (digit != null) {
      _digit(digit);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  static String? _digitOf(LogicalKeyboardKey k) {
    const top = [
      LogicalKeyboardKey.digit0,
      LogicalKeyboardKey.digit1,
      LogicalKeyboardKey.digit2,
      LogicalKeyboardKey.digit3,
      LogicalKeyboardKey.digit4,
      LogicalKeyboardKey.digit5,
      LogicalKeyboardKey.digit6,
      LogicalKeyboardKey.digit7,
      LogicalKeyboardKey.digit8,
      LogicalKeyboardKey.digit9,
    ];
    const pad = [
      LogicalKeyboardKey.numpad0,
      LogicalKeyboardKey.numpad1,
      LogicalKeyboardKey.numpad2,
      LogicalKeyboardKey.numpad3,
      LogicalKeyboardKey.numpad4,
      LogicalKeyboardKey.numpad5,
      LogicalKeyboardKey.numpad6,
      LogicalKeyboardKey.numpad7,
      LogicalKeyboardKey.numpad8,
      LogicalKeyboardKey.numpad9,
    ];
    final a = top.indexOf(k);
    if (a >= 0) return '$a';
    final b = pad.indexOf(k);
    return b >= 0 ? '$b' : null;
  }

  @override
  Widget build(BuildContext context) {
    final fg = widget.foreground ?? Theme.of(context).colorScheme.onSurface;
    final dim = fg.withValues(alpha: widget.enabled ? 1 : 0.4);
    return Focus(autofocus: true, onKeyEvent: _onKey, child: _pad(dim));
  }

  Widget _pad(Color dim) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          key: const Key('pin-dots'),
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < kPinLength; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 7),
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: dim, width: 1.5),
                  color: i < _pin.length ? dim : Colors.transparent,
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [for (final d in row) _key(d, dim)],
          ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.onBiometric != null)
              _iconKey(
                const Key('pin-biometric'),
                Icons.fingerprint,
                'Use fingerprint or face',
                dim,
                widget.enabled ? widget.onBiometric : null,
              )
            else
              const SizedBox(width: 76, height: 64),
            _key('0', dim),
            _iconKey(
              const Key('pin-back'),
              Icons.backspace_outlined,
              'Delete',
              dim,
              _back,
            ),
          ],
        ),
      ],
    );
  }

  Widget _key(String d, Color color) {
    return SizedBox(
      width: 76,
      height: 64,
      child: TextButton(
        key: Key('pin-$d'),
        onPressed: () => _digit(d),
        style: TextButton.styleFrom(
          foregroundColor: color,
          shape: const CircleBorder(),
        ),
        child: Text(
          d,
          style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(color: color, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }

  Widget _iconKey(
    Key key,
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap,
  ) {
    // A Semantics label instead of `tooltip`: the lock screen can sit
    // outside the Navigator's Overlay (relock after background), and
    // tooltips need one.
    return SizedBox(
      width: 76,
      height: 64,
      child: Semantics(
        label: label,
        button: true,
        excludeSemantics: true,
        child: IconButton(
          key: key,
          onPressed: onTap,
          icon: Icon(icon, color: color),
        ),
      ),
    );
  }
}
