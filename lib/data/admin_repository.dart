import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/business.dart';
import 'business_repository.dart';
import 'ikafe_contact.dart';
import 'report_repository.dart';

enum AdminErrorCode {
  notAdmin,
  invalidView,
  invalidBand,
  reasonRequired,
  invalidState,
  invalidAction,
  notFound,
  invalidInput,
  unknown,
}

class AdminException implements Exception {
  const AdminException(this.code, this.message);
  final AdminErrorCode code;
  final String message;

  @override
  String toString() => 'AdminException(${code.name}): $message';
}

/// Plain sentence for a failed admin action. Never shows raw errors.
String adminErrorMessage(Object error) {
  if (error is AdminException) {
    switch (error.code) {
      case AdminErrorCode.notAdmin:
        return 'You are not an admin.';
      case AdminErrorCode.invalidBand:
        return 'Choose one of the four bands.';
      case AdminErrorCode.reasonRequired:
        return 'A reason is required.';
      case AdminErrorCode.invalidState:
        return 'That is not possible right now. You cannot suspend an admin or '
            'yourself. Otherwise reload the list.';
      case AdminErrorCode.notFound:
        return 'This item no longer exists.';
      case AdminErrorCode.invalidInput:
        return 'Title and message are required, and must not be too long.';
      case AdminErrorCode.invalidView:
      case AdminErrorCode.invalidAction:
      case AdminErrorCode.unknown:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}

/// Thin seam over the Supabase client (every call is a database function).
abstract class AdminApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);
}

class SupabaseAdminApi implements AdminApi {
  SupabaseAdminApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);
}

/// Admin calls. The admin id is sent with every call and checked by the
/// database against app_admins. With no real login that id is NOT
/// authenticated: accepted for the closed beta only (see docs/DECISIONS.md).
class AdminRepository {
  AdminRepository([AdminApi? api]) : _api = api ?? SupabaseAdminApi();
  final AdminApi _api;

  /// Asked once per session. Never cached on the device.
  Future<bool> isAdmin(String profileId) async {
    final r = await _guard(
      () => _api.rpc('is_app_admin', {'p_profile': profileId}),
    );
    return r == true;
  }

  /// [status] null means every business. Pending ones come first.
  Future<List<Business>> businesses(String adminId, {String? status}) async {
    final rows = await _guard(
      () => _api.rpc('admin_businesses_list', {
        'p_admin': adminId,
        'p_status': status,
      }),
    );
    final photos = await BusinessRepository.photoUrls(
      () => _api.rpc('admin_business_photo_urls', {'p_admin': adminId}),
    );
    return BusinessRepository.withPhotos(
      (rows as List)
          .map((r) => Business.fromMap(Map<String, dynamic>.from(r as Map)))
          .toList(),
      photos,
    );
  }

  Future<Business> approve(
    String adminId,
    String businessId,
    BusinessBand band,
  ) => _decide(adminId, businessId, 'approve', band: band.name);

  Future<Business> reject(String adminId, String businessId, String reason) =>
      _decide(adminId, businessId, 'reject', reason: reason);

  Future<Business> suspend(
    String adminId,
    String businessId, {
    String? reason,
  }) => _decide(adminId, businessId, 'suspend', reason: reason);

  Future<Business> restore(String adminId, String businessId) =>
      _decide(adminId, businessId, 'restore');

  Future<Business> _decide(
    String adminId,
    String businessId,
    String action, {
    String? band,
    String? reason,
  }) async {
    final row = await _guard(
      () => _api.rpc('admin_business_decide', {
        'p_admin': adminId,
        'p_business': businessId,
        'p_action': action,
        'p_band': band,
        'p_reason': reason?.trim(),
      }),
    );
    final map = row is List ? row.first : row;
    return Business.fromMap(Map<String, dynamic>.from(map as Map));
  }

  /// Open reports (one row per reported thing, with counts and reasons), or
  /// everything an admin has hidden. Marketplace reports are included.
  Future<List<AdminReport>> reports(
    String adminId, {
    bool hidden = false,
  }) async {
    final rows = await _guard(
      () => _api.rpc('admin_reports_list', {
        'p_admin': adminId,
        'p_view': hidden ? 'hidden' : 'open',
      }),
    );
    return (rows as List)
        .map((r) => AdminReport.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Open reports no admin has looked at yet (the badge on Reports).
  Future<int> unseenReportsCount(String adminId) async {
    final n = await _guard(
      () => _api.rpc('admin_reports_unseen_count', {'p_admin': adminId}),
    );
    return (n as num?)?.toInt() ?? 0;
  }

  /// Marks every open report as seen (called when the Reports list opens).
  Future<void> markReportsSeen(String adminId) async {
    await _guard(
      () => _api.rpc('admin_reports_mark_seen', {'p_admin': adminId}),
    );
  }

  Future<void> dismissReports(String adminId, AdminReport r) =>
      _reportAction(adminId, r, 'dismiss');

  Future<void> markActioned(String adminId, AdminReport r) =>
      _reportAction(adminId, r, 'mark_actioned');

  Future<void> hideContent(String adminId, AdminReport r, String reason) =>
      _reportAction(adminId, r, 'hide', reason: reason);

  Future<void> restoreContent(String adminId, AdminReport r) =>
      _reportAction(adminId, r, 'restore');

  /// Blocks the reported person (or the sender of a reported contact
  /// request) from signing in and removes them from the Directory.
  Future<void> suspendUser(String adminId, AdminReport r, String reason) =>
      _reportAction(adminId, r, 'suspend_user', reason: reason);

  Future<void> unsuspendUser(String adminId, AdminReport r) =>
      _reportAction(adminId, r, 'unsuspend_user');

  Future<void> _reportAction(
    String adminId,
    AdminReport r,
    String action, {
    String? reason,
  }) async {
    await _guard(
      () => _api.rpc('admin_reports_decide', {
        'p_admin': adminId,
        'p_type': r.targetType.value,
        'p_target': r.targetId,
        'p_action': action,
        'p_reason': reason?.trim(),
      }),
    );
  }

  /// Feedback reports, newest first. Rows are only readable through this
  /// admin function (the app role cannot read the table).
  Future<List<FeedbackItem>> feedback(String adminId) async {
    final rows = await _guard(
      () => _api.rpc('admin_feedback_list', {'p_admin': adminId}),
    );
    return (rows as List)
        .map((r) => FeedbackItem.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<int> newFeedbackCount(String adminId) async {
    final n = await _guard(
      () => _api.rpc('admin_feedback_new_count', {'p_admin': adminId}),
    );
    return (n as num?)?.toInt() ?? 0;
  }

  /// [status] is `new`, `seen` or `done`.
  Future<void> setFeedbackStatus(
    String adminId,
    String id,
    String status,
  ) async {
    await _guard(
      () => _api.rpc('admin_feedback_set_status', {
        'p_admin': adminId,
        'p_id': id,
        'p_status': status,
      }),
    );
  }

  /// Announcements, newest first. Same rows the News screen shows, plus who
  /// posted each one.
  Future<List<AdminAnnouncement>> announcements(String adminId) async {
    final rows = await _guard(
      () => _api.rpc('admin_announcement_list', {'p_admin': adminId}),
    );
    return (rows as List)
        .map(
          (r) => AdminAnnouncement.fromMap(Map<String, dynamic>.from(r as Map)),
        )
        .toList();
  }

  /// Posts one announcement. Only the database decides who may: the call is
  /// refused with `not_admin` for anyone not in app_admins.
  Future<void> createAnnouncement(
    String adminId, {
    required String title,
    required String body,
  }) async {
    await _guard(
      () => _api.rpc('admin_announcement_create', {
        'p_admin': adminId,
        'p_title': title.trim(),
        'p_body': body.trim(),
      }),
    );
  }

  /// Every Kontak Ikafe row, hidden ones too.
  Future<List<IkafeContact>> ikafeContacts(String adminId) async {
    final rows = await _guard(
      () => _api.rpc('admin_ikafe_contact_list', {'p_admin': adminId}),
    );
    return [
      for (final r in rows as List)
        ?IkafeContact.tryFromMap(Map<String, dynamic>.from(r as Map)),
    ];
  }

  /// Adds a Kontak Ikafe row, or changes it when [id] is given.
  Future<void> saveIkafeContact(
    String adminId, {
    String? id,
    required IkafeContactKind kind,
    required String label,
    required String value,
    required int sortOrder,
    required bool active,
  }) async {
    await _guard(
      () => _api.rpc('admin_ikafe_contact_save', {
        'p_admin': adminId,
        'p_id': id,
        'p_kind': kind.name,
        'p_label': label.trim(),
        'p_value': value.trim(),
        'p_sort': sortOrder,
        'p_active': active,
      }),
    );
  }

  Future<void> deleteIkafeContact(String adminId, String id) async {
    await _guard(
      () => _api.rpc('admin_ikafe_contact_delete', {
        'p_admin': adminId,
        'p_id': id,
      }),
    );
  }

  /// Products ('listing') or jobs ('job') for the Home order screen: every
  /// pinned item (any status) and every item Home could show.
  Future<List<HomeOrderItem>> homeOrderItems(
    String adminId,
    String kind,
  ) async {
    final rows = await _guard(
      () => _api.rpc('admin_home_order_list', {
        'p_admin': adminId,
        'p_kind': kind,
      }),
    );
    return (rows as List)
        .map((r) => HomeOrderItem.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  /// Saves the whole pinned list of one kind in one call: [ids] in order
  /// become 1, 2, 3... and every other item of that kind is unpinned.
  Future<void> setHomeOrder({
    required String adminId,
    required String kind,
    required List<String> ids,
  }) async {
    await _guard(
      () => _api.rpc('admin_set_home_order', {
        'p_admin': adminId,
        'p_kind': kind,
        'p_ids': ids,
      }),
    );
  }

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw AdminException(_code(e.message), e.message);
    }
  }

  AdminErrorCode _code(String m) => switch (m) {
    'not_admin' => AdminErrorCode.notAdmin,
    'invalid_band' => AdminErrorCode.invalidBand,
    'reason_required' => AdminErrorCode.reasonRequired,
    'invalid_state' => AdminErrorCode.invalidState,
    'invalid_action' => AdminErrorCode.invalidAction,
    'invalid_view' => AdminErrorCode.invalidView,
    'not_found' => AdminErrorCode.notFound,
    'invalid_input' => AdminErrorCode.invalidInput,
    _ => AdminErrorCode.unknown,
  };
}

/// One reported thing, as the admin sees it.
class AdminReport {
  const AdminReport({
    required this.targetType,
    required this.targetId,
    required this.title,
    required this.ownerName,
    required this.reportCount,
    required this.reasons,
    required this.notes,
    required this.isHidden,
    this.hiddenReason,
    this.lastReported,
  });

  final ReportTarget targetType;
  final String targetId;
  final String title;
  final String? ownerName;
  final int reportCount;
  final List<ContentReportReason> reasons;
  final List<String> notes;
  final bool isHidden;
  final String? hiddenReason;

  /// When it was last reported (for a hidden item: when it was hidden).
  final DateTime? lastReported;

  /// A reported person, or the sender of a reported contact request, can be
  /// suspended. Never offered once they are suspended (it shows in Hidden).
  bool get canSuspend =>
      targetType == ReportTarget.profile ||
      targetType == ReportTarget.contactRequest;

  /// Jobs, products and businesses can be hidden. Profiles and contact
  /// requests can only be dismissed or marked as handled.
  bool get canHide =>
      targetType == ReportTarget.job ||
      targetType == ReportTarget.product ||
      targetType == ReportTarget.business;

  factory AdminReport.fromMap(Map<String, dynamic> m) {
    final type = ReportTarget.values.firstWhere(
      (t) => t.value == m['target_type'],
      orElse: () => ReportTarget.profile,
    );
    List<String> strings(Object? v) =>
        (v as List? ?? const []).map((e) => '$e').toList();
    return AdminReport(
      targetType: type,
      targetId: m['target_id'] as String,
      title: m['title'] as String? ?? '(no longer available)',
      ownerName: m['owner_name'] as String?,
      reportCount: (m['report_count'] as num?)?.toInt() ?? 0,
      reasons: [
        for (final v in strings(m['reasons']))
          if (ContentReportReason.fromValue(v) != null)
            ContentReportReason.fromValue(v)!,
      ],
      notes: strings(m['notes']),
      isHidden: m['is_hidden'] == true,
      hiddenReason: m['hidden_reason'] as String?,
      lastReported: DateTime.tryParse('${m['last_reported']}'),
    );
  }
}

/// One feedback report, as the admin sees it.
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.status,
    required this.createdAt,
    this.profileName,
    this.message,
    this.errorText,
    this.screen,
    this.appVersion,
    this.buildNumber,
    this.platform,
  });

  final String id;
  final String status;
  final DateTime createdAt;
  final String? profileName;
  final String? message;
  final String? errorText;
  final String? screen;
  final String? appVersion;
  final String? buildNumber;
  final String? platform;

  bool get isNew => status == 'new';

  factory FeedbackItem.fromMap(Map<String, dynamic> m) => FeedbackItem(
    id: m['id'] as String,
    status: m['status'] as String? ?? 'new',
    createdAt: DateTime.tryParse('${m['created_at']}') ?? DateTime.now(),
    profileName: m['profile_name'] as String?,
    message: m['message'] as String?,
    errorText: m['error_text'] as String?,
    screen: m['screen'] as String?,
    appVersion: m['app_version'] as String?,
    buildNumber: m['build_number'] as String?,
    platform: m['platform'] as String?,
  );
}

/// One announcement in the admin list.
class AdminAnnouncement {
  const AdminAnnouncement({
    required this.id,
    required this.title,
    required this.body,
    required this.postedByName,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final String? postedByName;
  final DateTime createdAt;

  factory AdminAnnouncement.fromMap(Map<String, dynamic> m) =>
      AdminAnnouncement(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        postedByName: m['posted_by_name'] as String?,
        createdAt: DateTime.parse(m['created_at'] as String),
      );
}

/// One product or job on the Home order screen.
class HomeOrderItem {
  const HomeOrderItem({
    required this.id,
    required this.title,
    required this.ownerName,
    required this.status,
    required this.rank,
  });

  final String id;
  final String title;
  final String? ownerName;

  /// Products: pending, approved, rejected, sold or hidden. Jobs: active or
  /// hidden.
  final String status;

  /// Place in the pinned list (1 first). Null: not pinned.
  final int? rank;

  /// True when Home would show this item if it were pinned.
  bool get isShown => status == 'approved' || status == 'active';

  /// Plain label for a status Home does not show. Null when it shows.
  String? get statusLabel => switch (status) {
    'sold' => 'Terjual',
    'hidden' => 'Disembunyikan',
    'rejected' => 'Ditolak',
    'pending' => 'Menunggu tinjauan',
    'approved' || 'active' => null,
    _ => 'Tidak aktif',
  };

  factory HomeOrderItem.fromMap(Map<String, dynamic> m) => HomeOrderItem(
    id: m['id'] as String,
    title: m['title'] as String? ?? '',
    ownerName: m['owner_name'] as String?,
    status: m['status'] as String? ?? 'approved',
    rank: (m['home_rank'] as num?)?.toInt(),
  );
}
