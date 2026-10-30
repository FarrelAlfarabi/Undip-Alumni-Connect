import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/lock/lock_service.dart';

void main() {
  test('the lock is on for web too (decided 30 Oct)', () {
    expect(LockService.forPlatform(web: true).enabled, isTrue);
    expect(LockService.forPlatform(web: false).enabled, isTrue);
  });
}
