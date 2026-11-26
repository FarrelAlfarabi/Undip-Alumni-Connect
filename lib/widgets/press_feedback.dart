import 'package:flutter/material.dart';

/// How long the press-in and release take. Kept short on purpose: feedback
/// that is slower than the tap itself makes the app feel slower, not nicer.
const Duration kPressDownDuration = Duration(milliseconds: 80);
const Duration kPressUpDuration = Duration(milliseconds: 140);

/// Gives anything tappable an instant "pressed" response: it shrinks a little
/// the moment a finger or mouse goes down and returns on release.
///
/// Why not just the ink ripple: inside a scrolling list Flutter waits about
/// 100 ms before it shows the ripple (it first has to know whether this is a
/// scroll). This reads the raw pointer, so the response is immediate, and it
/// never takes part in the gesture contest, so taps and scrolling behave as
/// before.
///
/// It lets go as soon as the finger moves more than a few pixels (a scroll
/// has begun), and it does nothing when the device asks for reduced motion.
class PressFeedback extends StatefulWidget {
  const PressFeedback({
    super.key,
    required this.child,
    this.scale = 0.97,
    this.enabled = true,
  });

  final Widget child;

  /// Size while pressed. 0.97 for cards and buttons; smaller for icons.
  final double scale;
  final bool enabled;

  @override
  State<PressFeedback> createState() => _PressFeedbackState();
}

class _PressFeedbackState extends State<PressFeedback> {
  bool _down = false;
  Offset _start = Offset.zero;

  void _set(bool v) {
    if (_down == v || !mounted) return;
    setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || MediaQuery.disableAnimationsOf(context)) {
      return widget.child;
    }
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _start = e.position;
        _set(true);
      },
      onPointerMove: (e) {
        if (_down && (e.position - _start).distance > 10) _set(false);
      },
      onPointerUp: (_) => _set(false),
      onPointerCancel: (_) => _set(false),
      child: AnimatedScale(
        scale: _down ? widget.scale : 1.0,
        duration: _down ? kPressDownDuration : kPressUpDuration,
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}
