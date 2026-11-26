import '../util/app_language.dart';
import 'business.dart';

enum BusinessEditStatus {
  pending,
  approved,
  rejected,
  cancelled;

  static BusinessEditStatus fromName(String? name) {
    for (final s in values) {
      if (s.name == name) return s;
    }
    return BusinessEditStatus.pending;
  }
}

/// The values of a business that an owner can ask to change.
class BusinessValues {
  const BusinessValues({
    required this.name,
    required this.description,
    required this.category,
    this.socialLink,
    this.websiteLink,
    this.isPersonal = false,
    this.nib,
    this.photoUrl,
  });

  factory BusinessValues.of(Business b) => BusinessValues(
    name: b.name,
    description: b.description,
    category: b.category,
    socialLink: b.socialLink,
    websiteLink: b.websiteLink,
    isPersonal: b.isPersonal,
    nib: b.nib,
    photoUrl: b.photoUrl,
  );

  final String name;
  final String description;
  final String category;
  final String? socialLink;
  final String? websiteLink;
  final bool isPersonal;
  final String? nib;
  final String? photoUrl;
}

/// One field that differs between the old and the new version.
class EditChange {
  const EditChange(this.field, this.label, this.oldText, this.newText);

  /// A stable key, for tests and widget keys: name, description, category,
  /// social, website, personal, nib, photo.
  final String field;
  final String label;
  final String oldText;
  final String newText;
}

String _none() => tr('(kosong)');

/// The fields that differ, in the order the form shows them. The photo is
/// shown as a word, not a link, in the text columns; screens that can show
/// pictures read the two photo links from the values themselves.
List<EditChange> changesBetween(BusinessValues old, BusinessValues next) {
  String text(String? v) => (v == null || v.isEmpty) ? _none() : v;
  String kind(bool v) => v ? tr('Usaha perorangan') : tr('Usaha');
  String photo(String? v) =>
      (v == null || v.isEmpty) ? _none() : tr('Ada foto');
  final out = <EditChange>[];
  if (old.name != next.name) {
    out.add(EditChange('name', tr('Nama bisnis'), old.name, next.name));
  }
  if (old.description != next.description) {
    out.add(
      EditChange(
        'description',
        tr('Deskripsi'),
        old.description,
        next.description,
      ),
    );
  }
  if (old.category != next.category) {
    out.add(
      EditChange('category', tr('Kategori'), old.category, next.category),
    );
  }
  if (old.isPersonal != next.isPersonal) {
    out.add(
      EditChange(
        'personal',
        tr('Jenis'),
        kind(old.isPersonal),
        kind(next.isPersonal),
      ),
    );
  }
  if (old.socialLink != next.socialLink) {
    out.add(
      EditChange(
        'social',
        tr('Instagram'),
        text(old.socialLink),
        text(next.socialLink),
      ),
    );
  }
  if (old.websiteLink != next.websiteLink) {
    out.add(
      EditChange(
        'website',
        'Website',
        text(old.websiteLink),
        text(next.websiteLink),
      ),
    );
  }
  if (old.nib != next.nib) {
    out.add(EditChange('nib', 'NIB', text(old.nib), text(next.nib)));
  }
  if (old.photoUrl != next.photoUrl) {
    out.add(
      EditChange(
        'photo',
        tr('Foto'),
        photo(old.photoUrl),
        photo(next.photoUrl),
      ),
    );
  }
  return out;
}

/// A change request for an approved business. The business keeps its old
/// values until an admin approves.
class BusinessEditRequest {
  const BusinessEditRequest({
    required this.id,
    required this.businessId,
    required this.ownerId,
    required this.status,
    required this.proposed,
    this.current,
    this.ownerName,
    this.rejectReason,
    this.currentNibVerified = false,
    this.createdAt,
    this.decidedAt,
  });

  final String id;
  final String businessId;
  final String ownerId;
  final BusinessEditStatus status;

  /// What the owner asks for.
  final BusinessValues proposed;

  /// What the business has now. Only in the admin list.
  final BusinessValues? current;
  final String? ownerName;
  final String? rejectReason;
  final bool currentNibVerified;
  final DateTime? createdAt;
  final DateTime? decidedAt;

  bool get isPending => status == BusinessEditStatus.pending;

  /// Fields that differ from [from] (default: the current values, admin list).
  List<EditChange> changes([BusinessValues? from]) {
    final base = from ?? current;
    return base == null ? const [] : changesBetween(base, proposed);
  }

  static DateTime? _date(Object? v) =>
      v == null ? null : DateTime.tryParse('$v');

  /// A row from `business_edit_request_my`.
  factory BusinessEditRequest.fromOwnerRow(Map<String, dynamic> m) =>
      BusinessEditRequest(
        id: '${m['id']}',
        businessId: '${m['business_id']}',
        ownerId: '${m['owner_id']}',
        status: BusinessEditStatus.fromName(m['status'] as String?),
        proposed: BusinessValues(
          name: m['name'] as String? ?? '',
          description: m['description'] as String? ?? '',
          category: m['category'] as String? ?? 'Other',
          socialLink: m['social_link'] as String?,
          websiteLink: m['website_link'] as String?,
          isPersonal: m['is_personal'] == true,
          nib: m['nib'] as String?,
          photoUrl: m['photo_url'] as String?,
        ),
        rejectReason: m['reject_reason'] as String?,
        createdAt: _date(m['created_at']),
        decidedAt: _date(m['decided_at']),
      );

  /// A row from `admin_business_edit_requests` (new_* and old_* columns).
  factory BusinessEditRequest.fromAdminRow(Map<String, dynamic> m) =>
      BusinessEditRequest(
        id: '${m['request_id']}',
        businessId: '${m['business_id']}',
        ownerId: '${m['owner_id']}',
        ownerName: m['owner_name'] as String?,
        status: BusinessEditStatus.fromName(m['req_status'] as String?),
        proposed: BusinessValues(
          name: m['new_name'] as String? ?? '',
          description: m['new_description'] as String? ?? '',
          category: m['new_category'] as String? ?? 'Other',
          socialLink: m['new_social_link'] as String?,
          websiteLink: m['new_website_link'] as String?,
          isPersonal: m['new_is_personal'] == true,
          nib: m['new_nib'] as String?,
          photoUrl: m['new_photo_url'] as String?,
        ),
        current: BusinessValues(
          name: m['old_name'] as String? ?? '',
          description: m['old_description'] as String? ?? '',
          category: m['old_category'] as String? ?? 'Other',
          socialLink: m['old_social_link'] as String?,
          websiteLink: m['old_website_link'] as String?,
          isPersonal: m['old_is_personal'] == true,
          nib: m['old_nib'] as String?,
          photoUrl: m['old_photo_url'] as String?,
        ),
        currentNibVerified: m['old_nib_verified'] == true,
        rejectReason: m['reject_reason'] as String?,
        createdAt: _date(m['created_at']),
        decidedAt: _date(m['decided_at']),
      );
}
