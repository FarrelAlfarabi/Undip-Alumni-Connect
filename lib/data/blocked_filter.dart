import 'block_list.dart';

/// Leaves out profile rows of people I blocked (Directory, Nearby). Waits for
/// the block list first, so nothing blocked shows just because the screen was
/// built before the list arrived.
Future<List<Map<String, dynamic>>> withoutBlockedProfiles(
  List<Map<String, dynamic>> rows,
) async {
  await BlockList.shared.ensureLoaded();
  return BlockList.shared.filter(rows, (p) => p['id'] as String?);
}
