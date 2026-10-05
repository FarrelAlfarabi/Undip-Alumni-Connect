import 'package:supabase_flutter/supabase_flutter.dart';

/// What can be reported (the database values).
enum ReportTarget {
  job('job'),
  product('product'),
  business('business'),
  profile('profile'),
  contactRequest('contact_request');

  const ReportTarget(this.value);
  final String value;
}

/// Why (the database values), with plain words for the picker.
enum ContentReportReason {
  spamOrScam('spam_or_scam', 'Spam or scam'),
  inappropriate('inappropriate', 'Inappropriate'),
  fakeOrImpersonation(
    'fake_or_impersonation',
    'Fake or pretending to be someone',
  ),
  wrongInfo('wrong_info', 'Wrong information'),
  other('other', 'Other');

  const ContentReportReason(this.value, this.label);
  final String value;
  final String label;

  static ContentReportReason? fromValue(String? v) {
    for (final r in values) {
      if (r.value == v) return r;
    }
    return null;
  }
}

/// Longest note (also enforced in the database).
const int kReportNoteMax = 300;

const String kReportThanks =
    'Thank you. An admin will take a look. The person is not told who '
    'reported.';

enum ReportErrorCode {
  notVerified,
  cannotReportOwn,
  alreadyReported,
  targetNotFound,
  noteTooLong,
  unknown,
}

class ReportException implements Exception {
  const ReportException(this.code, this.message);
  final ReportErrorCode code;
  final String message;

  @override
  String toString() => 'ReportException(${code.name}): $message';
}

String reportErrorMessage(Object error) {
  if (error is ReportException) {
    switch (error.code) {
      case ReportErrorCode.notVerified:
        return 'Only verified alumni can send reports.';
      case ReportErrorCode.cannotReportOwn:
        return 'You cannot report your own content.';
      case ReportErrorCode.alreadyReported:
        return 'You already reported this. An admin will take a look.';
      case ReportErrorCode.targetNotFound:
        return 'This content no longer exists.';
      case ReportErrorCode.noteTooLong:
        return 'The note is too long (300 characters at most).';
      case ReportErrorCode.unknown:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}

/// Thin seam over the Supabase client (every call is a database function).
abstract class ReportApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);
}

class SupabaseReportApi implements ReportApi {
  SupabaseReportApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);
}

class ReportRepository {
  ReportRepository([ReportApi? api]) : _api = api ?? SupabaseReportApi();
  final ReportApi _api;

  Future<void> report({
    required String reporterId,
    required ReportTarget type,
    required String targetId,
    required ContentReportReason reason,
    String? note,
  }) async {
    final text = note?.trim();
    try {
      await _api.rpc('content_report_create', {
        'p_reporter': reporterId,
        'p_type': type.value,
        'p_target': targetId,
        'p_reason': reason.value,
        'p_note': (text == null || text.isEmpty) ? null : text,
      });
    } on PostgrestException catch (e) {
      throw ReportException(_code(e.message), e.message);
    }
  }

  ReportErrorCode _code(String m) => switch (m) {
    'not_verified' => ReportErrorCode.notVerified,
    'cannot_report_own' => ReportErrorCode.cannotReportOwn,
    'already_reported' => ReportErrorCode.alreadyReported,
    'target_not_found' => ReportErrorCode.targetNotFound,
    'note_too_long' => ReportErrorCode.noteTooLong,
    _ => ReportErrorCode.unknown,
  };
}
