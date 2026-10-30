import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/platform/platform_caps.dart';

void main() {
  test('web: file picker only, no camera, biometrics or push', () {
    const c = PlatformCaps.web();
    expect(c.camera, isFalse);
    expect(c.biometrics, isFalse);
    expect(c.push, isFalse);
    expect(c.filePicker, isTrue);
  });

  test('phone: camera and biometrics, push not built yet', () {
    const c = PlatformCaps.phone();
    expect(c.camera, isTrue);
    expect(c.biometrics, isTrue);
    expect(c.push, isFalse);
  });
}
