import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/data/admin_repository.dart';

/// Serves members in pages of 500 the way admin_members_list does.
class _PagedApi implements AdminApi {
  _PagedApi(this.total);
  final int total;
  final offsets = <int>[];

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async {
    expect(function, 'admin_members_list');
    final offset = p['p_offset'] as int;
    offsets.add(offset);
    final end = (offset + 500).clamp(0, total);
    return [
      for (var i = offset; i < end; i++) {'id': 'm$i', 'name': 'Member $i'},
    ];
  }
}

void main() {
  test('searchMembers reads every page, not only the first 1000', () async {
    final api = _PagedApi(1885);
    final found = await AdminRepository(api).searchMembers('me', '');
    expect(found.length, 1885);
    expect(found.last.id, 'm1884');
    expect(api.offsets, [0, 500, 1000, 1500]);
  });

  test('a list that is an exact multiple of the page ends cleanly', () async {
    final api = _PagedApi(1000);
    final found = await AdminRepository(api).searchMembers('me', 'x');
    expect(found.length, 1000);
    expect(api.offsets, [0, 500, 1000]);
  });
}
