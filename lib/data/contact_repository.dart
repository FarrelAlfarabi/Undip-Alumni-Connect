import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/contact_request.dart';

/// Longest message and longest shared contact (also enforced in the database).
const int kContactMessageMax = 200;
const int kSharedContactMax = 200;

enum ContactErrorCode {
  notVerified,
  cannotRequestSelf,
  requestAlreadyOpen,
  cooldownActive,
  dailyLimitReached,
  messageTooLong,
  sharedRequired,
  sharedTooLong,
  notFound,
  notTarget,
  notRequester,
  notAccepted,
  invalidState,
  blocked,
  unknown,
}

class ContactException implements Exception {
  const ContactException(this.code, this.message);
  final ContactErrorCode code;
  final String message;

  @override
  String toString() => 'ContactException(${code.name}): $message';
}

/// Plain sentence for a failed contact action. Never shows raw errors.
String contactErrorMessage(Object error) {
  if (error is ContactException) {
    switch (error.code) {
      case ContactErrorCode.notVerified:
        return 'Only verified alumni can use this.';
      case ContactErrorCode.cannotRequestSelf:
        return 'You cannot send a request to yourself.';
      case ContactErrorCode.requestAlreadyOpen:
        return 'You already have an open request to this person. Please '
            'wait for an answer.';
      case ContactErrorCode.cooldownActive:
      case ContactErrorCode.blocked:
        return 'You cannot send a request to this person right now.';
      case ContactErrorCode.dailyLimitReached:
        return 'You have sent 5 requests today. Please try again tomorrow.';
      case ContactErrorCode.messageTooLong:
        return 'The message is too long (200 characters at most).';
      case ContactErrorCode.sharedRequired:
        return 'Type what you want to share.';
      case ContactErrorCode.sharedTooLong:
        return 'That is too long (200 characters at most).';
      case ContactErrorCode.notFound:
        return 'This request no longer exists.';
      case ContactErrorCode.notTarget:
      case ContactErrorCode.notRequester:
        return 'This request is not yours.';
      case ContactErrorCode.notAccepted:
        return 'This request was not accepted.';
      case ContactErrorCode.invalidState:
        return 'This request was already answered.';
      case ContactErrorCode.unknown:
        break;
    }
  }
  return 'Something went wrong. Please try again.';
}

/// Thin seam over the Supabase client (every call is a database function).
abstract class ContactApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);
}

class SupabaseContactApi implements ContactApi {
  SupabaseContactApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);
}

class ContactRepository {
  ContactRepository([ContactApi? api]) : _api = api ?? SupabaseContactApi();
  final ContactApi _api;

  Future<void> send({
    required String requesterId,
    required String targetId,
    String? message,
  }) async {
    final text = message?.trim();
    await _guard(
      () => _api.rpc('contact_request_send', {
        'p_requester': requesterId,
        'p_target': targetId,
        'p_message': (text == null || text.isEmpty) ? null : text,
      }),
    );
  }

  Future<List<IncomingRequest>> incoming(String targetId) async {
    final rows = await _guard(
      () => _api.rpc('contact_requests_incoming', {'p_target': targetId}),
    );
    return _rows(rows).map(IncomingRequest.fromMap).toList();
  }

  Future<List<OutgoingRequest>> outgoing(String requesterId) async {
    final rows = await _guard(
      () => _api.rpc('contact_requests_outgoing', {'p_requester': requesterId}),
    );
    return _rows(rows).map(OutgoingRequest.fromMap).toList();
  }

  /// Requests waiting for an answer (the badge on Home).
  Future<int> pendingCount(String targetId) async {
    final n = await _guard(
      () => _api.rpc('contact_requests_pending_count', {'p_target': targetId}),
    );
    return (n as num?)?.toInt() ?? 0;
  }

  Future<void> accept({
    required String targetId,
    required String requestId,
    required String sharedContact,
  }) async {
    await _guard(
      () => _api.rpc('contact_request_respond', {
        'p_target': targetId,
        'p_request': requestId,
        'p_accept': true,
        'p_shared': sharedContact.trim(),
      }),
    );
  }

  Future<void> reject({
    required String targetId,
    required String requestId,
  }) async {
    await _guard(
      () => _api.rpc('contact_request_respond', {
        'p_target': targetId,
        'p_request': requestId,
        'p_accept': false,
        'p_shared': null,
      }),
    );
  }

  /// What the target chose to share. Only works once accepted, and only for
  /// the requester.
  Future<String> sharedContact({
    required String requesterId,
    required String requestId,
  }) async {
    final text = await _guard(
      () => _api.rpc('contact_request_shared_contact', {
        'p_requester': requesterId,
        'p_request': requestId,
      }),
    );
    return '$text';
  }

  List<Map<String, dynamic>> _rows(dynamic rows) =>
      (rows as List).map((r) => Map<String, dynamic>.from(r as Map)).toList();

  Future<T> _guard<T>(Future<T> Function() run) async {
    try {
      return await run();
    } on PostgrestException catch (e) {
      throw ContactException(_code(e.message), e.message);
    }
  }

  ContactErrorCode _code(String message) => switch (message) {
    'not_verified' => ContactErrorCode.notVerified,
    'cannot_request_self' => ContactErrorCode.cannotRequestSelf,
    'request_already_open' => ContactErrorCode.requestAlreadyOpen,
    'cooldown_active' => ContactErrorCode.cooldownActive,
    'daily_limit_reached' => ContactErrorCode.dailyLimitReached,
    'message_too_long' => ContactErrorCode.messageTooLong,
    'shared_required' => ContactErrorCode.sharedRequired,
    'shared_too_long' => ContactErrorCode.sharedTooLong,
    'not_found' => ContactErrorCode.notFound,
    'not_target' => ContactErrorCode.notTarget,
    'not_requester' => ContactErrorCode.notRequester,
    'not_accepted' => ContactErrorCode.notAccepted,
    'invalid_state' => ContactErrorCode.invalidState,
    'blocked' => ContactErrorCode.blocked,
    _ => ContactErrorCode.unknown,
  };
}
