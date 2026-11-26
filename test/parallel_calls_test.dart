import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';
import 'package:undip_alumni_connect/data/business_repository.dart';

import 'support/fake_business_api.dart';

class _RecordingAdminApi implements AdminApi {
  final calls = <String>[];

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) async {
    calls.add(function);
    if (function == 'admin_business_edit_pending_count') return 3;
    return [
      {'businesses': 1, 'listings': 2, 'reports': 0, 'feedback': 4},
    ];
  }
}

void main() {
  test('the business list asks its three questions at the same time', () {
    final api = FakeBusinessApi();
    final done = BusinessRepository(api).directory('me');
    // Checked before anything had time to answer.
    expect(api.calls, [
      'business_directory',
      'business_photo_urls',
      'business_nib_verified_ids',
    ]);
    return done;
  });

  test('admin red tags ask both counts at the same time', () async {
    final api = _RecordingAdminApi();
    final future = AdminRepository(api).pendingCounts('a');
    expect(
      api.calls,
      unorderedEquals([
        'admin_pending_counts',
        'admin_business_edit_pending_count',
      ]),
    );
    final counts = await future;
    expect(counts.businesses, 1);
    expect(counts.listings, 2);
    expect(counts.feedback, 4);
    expect(counts.businessEdits, 3);
  });
}
