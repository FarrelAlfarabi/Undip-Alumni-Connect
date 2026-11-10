import 'package:supabase_flutter/supabase_flutter.dart';

import 'marketplace_image_picker.dart';
import 'marketplace_repository.dart' show imageContentType;

/// One sponsor as the admin sees it (hidden and out-of-date ones too).
/// Members only get id, name, image_url and link_url from `home_sponsors()`.
class Sponsor {
  const Sponsor({
    required this.id,
    required this.name,
    required this.imageUrl,
    required this.linkUrl,
    required this.startsOn,
    required this.endsOn,
    required this.rank,
    required this.active,
    this.views = 0,
    this.taps = 0,
  });

  final String id;
  final String name;
  final String imageUrl;
  final String linkUrl;

  /// Null: no start date. Null [endsOn]: no end date.
  final DateTime? startsOn;
  final DateTime? endsOn;

  /// Place in the carousel (1 first).
  final int rank;
  final bool active;

  /// Totals over all days (numbers only; nothing about who).
  final int views;
  final int taps;

  /// True when members see this sponsor on [today] (the same rule as the
  /// database function `home_sponsors()`).
  bool isLive(DateTime today) {
    final d = DateTime(today.year, today.month, today.day);
    if (!active) return false;
    if (startsOn != null && startsOn!.isAfter(d)) return false;
    if (endsOn != null && endsOn!.isBefore(d)) return false;
    return true;
  }

  static DateTime? _date(Object? v) {
    final t = DateTime.tryParse('${v ?? ''}');
    return t == null ? null : DateTime(t.year, t.month, t.day);
  }

  factory Sponsor.fromMap(Map<String, dynamic> m) => Sponsor(
    id: m['id'] as String,
    name: (m['name'] as String?) ?? '',
    imageUrl: (m['image_url'] as String?) ?? '',
    linkUrl: (m['link_url'] as String?) ?? '',
    startsOn: _date(m['starts_on']),
    endsOn: _date(m['ends_on']),
    rank: (m['rank'] as num?)?.toInt() ?? 0,
    active: (m['active'] as bool?) ?? true,
    views: (m['views'] as num?)?.toInt() ?? 0,
    taps: (m['taps'] as num?)?.toInt() ?? 0,
  );
}

/// Plain `yyyy-MM-dd` for the database.
String? sponsorDate(DateTime? d) => d == null
    ? null
    : '${d.year.toString().padLeft(4, '0')}-'
          '${d.month.toString().padLeft(2, '0')}-'
          '${d.day.toString().padLeft(2, '0')}';

typedef SponsorImageUploader = Future<String> Function(PickedImage image);

/// Uploads to the public `sponsor-images` bucket and returns the link. Only
/// the admin screen calls this; a file nobody saved on a sponsor is never
/// shown anywhere.
Future<String> uploadSponsorImage(PickedImage image) async {
  final safe = image.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
  final path = '${DateTime.now().millisecondsSinceEpoch}_$safe';
  final bucket = Supabase.instance.client.storage.from('sponsor-images');
  await bucket.uploadBinary(
    path,
    image.bytes,
    fileOptions: FileOptions(contentType: imageContentType(image.name)),
  );
  return bucket.getPublicUrl(path);
}
