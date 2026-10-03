import 'package:flutter/material.dart';

import 'lock_service.dart';
import 'pin_pad.dart';

/// Asks for the current PIN before something sensitive (changing the PIN).
/// Pops `true` when the PIN is right. Wrong tries count towards the same
/// 5-try wipe as the lock screen; on the 5th, [onLockedOut] runs (local data
/// is already wiped by then).
class ConfirmPinScreen extends StatefulWidget {
  const ConfirmPinScreen({
    super.key,
    required this.lock,
    required this.onLockedOut,
  });

  final LockService lock;
  final Future<void> Function(BuildContext context) onLockedOut;

  @override
  State<ConfirmPinScreen> createState() => _ConfirmPinScreenState();
}

class _ConfirmPinScreenState extends State<ConfirmPinScreen> {
  String? _error;

  Future<void> _submit(String pin) async {
    final result = await widget.lock.checkPin(pin);
    if (!mounted) return;
    switch (result) {
      case PinOk():
        Navigator.of(context).pop(true);
      case PinWrong(:final attemptsLeft):
        setState(() {
          _error = attemptsLeft == 1
              ? 'Wrong PIN. 1 try left.'
              : 'Wrong PIN. $attemptsLeft tries left.';
        });
      case PinWait():
        setState(() => _error = 'Too many wrong tries. Wait a moment.');
      case PinLockedOut():
        await widget.onLockedOut(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      key: const Key('confirm-pin'),
      appBar: AppBar(title: const Text('Confirm your PIN')),
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
                    'Enter your current PIN',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge,
                  ),
                  const SizedBox(height: 24),
                  PinPad(onCompleted: _submit),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      key: const Key('confirm-pin-error'),
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
