import 'package:flutter_test/flutter_test.dart';
import 'package:undip_alumni_connect/screens/directory_screen.dart';

void main() {
  test('fetchAllPages keeps asking until a short page comes back', () async {
    final calls = <List<int>>[];
    final rows = await fetchAllPages(
      (from, to) async {
        calls.add([from, to]);
        final total = 2300;
        final end = to + 1 > total ? total : to + 1;
        return [
          for (var i = from; i < end; i++) {'i': i},
        ];
      },
      pageSize: 1000,
      maxRows: 5000,
    );
    expect(rows.length, 2300);
    expect(calls, [
      [0, 999],
      [1000, 1999],
      [2000, 2999],
    ]);
  });

  test('fetchAllPages can ask two pages in one go', () async {
    final started = <List<int>>[];
    final rows = await fetchAllPages(
      (from, to) async {
        started.add([from, to]);
        await Future<void>.delayed(const Duration(milliseconds: 10));
        const total = 1900;
        final end = to + 1 > total ? total : to + 1;
        return [
          for (var i = from; i < end; i++) {'i': i},
        ];
      },
      pageSize: 1000,
      maxRows: 5000,
      ahead: 2,
    );
    expect(rows.length, 1900);
    expect(rows.first['i'], 0);
    expect(rows.last['i'], 1899);
    // Both pages were asked before the first answered; no third page.
    expect(started, [
      [0, 999],
      [1000, 1999],
    ]);
  });

  test('fetchAllPages stops at maxRows', () async {
    final rows = await fetchAllPages(
      (from, to) async => [
        for (var i = from; i <= to; i++) {'i': i},
      ],
      pageSize: 1000,
      maxRows: 2500,
    );
    expect(rows.length, 2500);
  });
}
