// Marketplace demo models. Plain Dart, no Supabase imports, so they are
// easy to unit test.

const List<String> kMarketplaceCategories = [
  'Food & Drink',
  'Fashion',
  'Electronics',
  'Services',
  'Other',
];

enum ListingStatus {
  pending,
  approved,
  rejected,
  sold;

  static ListingStatus parse(String? value) {
    return ListingStatus.values.firstWhere(
      (s) => s.name == value,
      orElse: () => throw FormatException('Unknown listing status: $value'),
    );
  }
}

/// The seller fields the UI shows on a listing (joined from
/// alumni_profiles). Deliberately excludes email.
class MarketplaceSeller {
  const MarketplaceSeller({
    required this.id,
    required this.name,
    this.faculty,
    this.major,
    this.graduationYear,
    this.city,
  });

  final String id;
  final String name;
  final String? faculty;
  final String? major;
  final int? graduationYear;
  final String? city;

  factory MarketplaceSeller.fromMap(Map<String, dynamic> map) {
    return MarketplaceSeller(
      id: map['id'] as String,
      name: map['name'] as String? ?? 'Alumni',
      faculty: map['faculty'] as String?,
      major: map['major'] as String?,
      graduationYear: (map['graduation_year'] as num?)?.toInt(),
      city: map['city'] as String?,
    );
  }
}

class MarketplaceListing {
  const MarketplaceListing({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.description,
    required this.priceIdr,
    required this.category,
    required this.city,
    required this.imageUrl,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.shopUrl,
    this.contactInfo,
    this.rejectedReason,
    this.approvedAt,
    this.seller,
    this.businessId,
  });

  final String id;
  final String sellerId;
  final String title;
  final String description;

  /// Whole rupiah.
  final int priceIdr;
  final String category;
  final String city;
  final String imageUrl;
  final String? shopUrl;
  final String? contactInfo;
  final ListingStatus status;
  final String? rejectedReason;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? approvedAt;

  /// Only present when the query joined alumni_profiles (browse/detail).
  final MarketplaceSeller? seller;

  /// The business this product belongs to. Null for the old seed listings.
  final String? businessId;

  MarketplaceListing withSeller(MarketplaceSeller? seller) {
    return MarketplaceListing(
      id: id,
      sellerId: sellerId,
      title: title,
      description: description,
      priceIdr: priceIdr,
      category: category,
      city: city,
      imageUrl: imageUrl,
      status: status,
      createdAt: createdAt,
      updatedAt: updatedAt,
      shopUrl: shopUrl,
      contactInfo: contactInfo,
      rejectedReason: rejectedReason,
      approvedAt: approvedAt,
      seller: seller,
      businessId: businessId,
    );
  }

  factory MarketplaceListing.fromMap(Map<String, dynamic> map) {
    final sellerMap = map['seller'];
    return MarketplaceListing(
      id: map['id'] as String,
      sellerId: map['seller_id'] as String,
      title: map['title'] as String,
      description: map['description'] as String? ?? '',
      priceIdr: (map['price_idr'] as num).toInt(),
      category: map['category'] as String,
      city: map['city'] as String? ?? '',
      imageUrl: map['image_url'] as String? ?? '',
      shopUrl: map['shop_url'] as String?,
      contactInfo: map['contact_info'] as String?,
      status: ListingStatus.parse(map['status'] as String?),
      rejectedReason: map['rejected_reason'] as String?,
      createdAt: DateTime.parse(map['created_at'] as String),
      updatedAt: DateTime.parse(map['updated_at'] as String),
      approvedAt: map['approved_at'] == null
          ? null
          : DateTime.parse(map['approved_at'] as String),
      seller: sellerMap is Map<String, dynamic>
          ? MarketplaceSeller.fromMap(sellerMap)
          : null,
      businessId: map['business_id'] as String?,
    );
  }
}

/// What the seller types into the create/edit form.
class MarketplaceListingInput {
  const MarketplaceListingInput({
    required this.title,
    required this.description,
    required this.priceIdr,
    required this.category,
    required this.city,
    required this.imageUrl,
    this.shopUrl,
    this.contactInfo,
  });

  final String title;
  final String description;
  final int priceIdr;
  final String category;
  final String city;
  final String imageUrl;
  final String? shopUrl;
  final String? contactInfo;
}

enum ReportReason {
  spam('Spam'),
  prohibited('Prohibited item'),
  misleading('Misleading'),
  other('Other');

  const ReportReason(this.label);
  final String label;
}

/// Admin view: how many reports a listing has received.
class ReportCount {
  const ReportCount({required this.listingId, required this.count});

  final String listingId;
  final int count;

  factory ReportCount.fromMap(Map<String, dynamic> map) => ReportCount(
    listingId: map['listing_id'] as String,
    count: (map['report_count'] as num).toInt(),
  );
}
