/// Yearly sales bands, from the official Indonesian UMKM definition
/// (PP 7/2021, Art. 35). The names match the database values.
enum BusinessBand {
  micro('Micro', 'Up to Rp 2 miliar a year'),
  small('Small', 'Over Rp 2 miliar, up to Rp 15 miliar a year'),
  medium('Medium', 'Over Rp 15 miliar, up to Rp 50 miliar a year'),
  large('Large (not UMKM)', 'Over Rp 50 miliar a year');

  const BusinessBand(this.label, this.range);

  /// Short name, for example "Micro".
  final String label;

  /// Plain words with the Rp amounts.
  final String range;

  /// "Micro: Up to Rp 2 miliar a year".
  String get described => '$label: $range';

  static BusinessBand? fromName(String? name) {
    for (final b in values) {
      if (b.name == name) return b;
    }
    return null;
  }
}

enum BusinessStatus {
  pending('Waiting for review'),
  approved('Approved'),
  rejected('Not approved'),
  suspended('Suspended');

  const BusinessStatus(this.label);
  final String label;

  static BusinessStatus fromName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return BusinessStatus.pending;
  }
}

/// Same list as the marketplace, so a business and its products agree.
const List<String> kBusinessCategories = [
  'Food & Drink',
  'Fashion',
  'Electronics',
  'Services',
  'Other',
];

class Business {
  const Business({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.category,
    required this.status,
    this.socialLink,
    this.websiteLink,
    this.requestedBand,
    this.approvedBand,
    this.rejectionReason,
    this.unlimitedUntil,
    this.createdAt,
    this.ownerName,
    this.hiddenAt,
    this.hiddenReason,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String category;
  final BusinessStatus status;
  final String? socialLink;
  final String? websiteLink;
  final BusinessBand? requestedBand;
  final BusinessBand? approvedBand;
  final String? rejectionReason;

  /// Unlimited product posting until this day (inclusive). Set in the
  /// dashboard only.
  final DateTime? unlimitedUntil;
  final DateTime? createdAt;
  final String? ownerName;

  /// Set when an admin hid this business. Others cannot see it.
  final DateTime? hiddenAt;
  final String? hiddenReason;

  bool get isHidden => hiddenAt != null;

  bool get isApproved => status == BusinessStatus.approved;

  /// Works for rows from `business_my` and `business_directory` (the
  /// directory rows have no status, so they count as approved).
  factory Business.fromMap(Map<String, dynamic> m) {
    DateTime? date(Object? v) => v == null ? null : DateTime.tryParse('$v');
    return Business(
      id: m['id'] as String,
      ownerId: m['owner_id'] as String,
      name: m['name'] as String? ?? '',
      description: m['description'] as String? ?? '',
      category: m['category'] as String? ?? 'Other',
      status: m.containsKey('status')
          ? BusinessStatus.fromName(m['status'] as String?)
          : BusinessStatus.approved,
      socialLink: m['social_link'] as String?,
      websiteLink: m['website_link'] as String?,
      requestedBand: BusinessBand.fromName(m['requested_band'] as String?),
      approvedBand: BusinessBand.fromName(m['approved_band'] as String?),
      rejectionReason: m['rejection_reason'] as String?,
      unlimitedUntil: date(m['unlimited_until']),
      createdAt: date(m['created_at']),
      ownerName: m['owner_name'] as String?,
      hiddenAt: date(m['hidden_at']),
      hiddenReason: m['hidden_reason'] as String?,
    );
  }
}

/// What the owner types in the form.
class BusinessInput {
  const BusinessInput({
    required this.name,
    required this.description,
    required this.category,
    this.socialLink,
    this.websiteLink,
    this.band,
  });

  final String name;
  final String description;
  final String category;
  final String? socialLink;
  final String? websiteLink;

  /// Only used when registering. The band cannot be changed afterwards.
  final BusinessBand? band;
}

/// How many products a business has, and how many it may have. Comes from the
/// database function `business_my_usage` (the limit is data in the database,
/// never a number in the app).
class BusinessUsage {
  const BusinessUsage({
    required this.businessId,
    required this.freeLimit,
    required this.used,
    required this.unlimitedActive,
    required this.canPost,
  });

  final String businessId;
  final int freeLimit;
  final int used;
  final bool unlimitedActive;
  final bool canPost;

  bool get overLimit => !unlimitedActive && used > freeLimit;

  factory BusinessUsage.fromMap(Map<String, dynamic> m) => BusinessUsage(
    businessId: m['business_id'] as String,
    freeLimit: (m['free_post_limit'] as num?)?.toInt() ?? 0,
    used: (m['products_used'] as num?)?.toInt() ?? 0,
    unlimitedActive: m['unlimited_active'] == true,
    canPost: m['can_post'] == true,
  );
}
