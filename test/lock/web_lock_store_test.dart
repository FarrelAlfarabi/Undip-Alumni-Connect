import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:undip_alumni_connect/lock/lock_store.dart';

void main() {
  test('web store keeps the remembered person across a restart', () async {
    SharedPreferences.setMockInitialValues({});
    const first = WebLockStore();
    await first.write('id', 'abc');
    // A new store object (new page load) still reads it.
    expect(await const WebLockStore().read('id'), 'abc');
    await const WebLockStore().delete('id');
    expect(await const WebLockStore().read('id'), isNull);
  });
}
