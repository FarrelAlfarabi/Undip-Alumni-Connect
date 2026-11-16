import 'package:flutter/foundation.dart' show kIsWeb;

/// What this device can do. Screens ask this instead of checking `kIsWeb`.
class PlatformCaps {
  const PlatformCaps({
    required this.camera,
    required this.biometrics,
    required this.push,
    required this.filePicker,
  });

  /// Browser: file picker only (the CSP blocks the camera).
  const PlatformCaps.web()
      : camera = false,
        biometrics = false,
        push = false,
        filePicker = true;

  /// Phone: push is not built yet, so it stays false.
  const PlatformCaps.phone()
      : camera = true,
        biometrics = true,
        push = false,
        filePicker = true;

  final bool camera;
  final bool biometrics;
  final bool push;
  final bool filePicker;

  static PlatformCaps get current =>
      kIsWeb ? const PlatformCaps.web() : const PlatformCaps.phone();
}
