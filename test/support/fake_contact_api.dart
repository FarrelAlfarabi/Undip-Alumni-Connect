import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:undip_alumni_connect/data/contact_repository.dart';

Map<String, dynamic> incomingMap({
  String id = 'r1',
  String requesterId = 'u2',
  String name = 'Siti Azizah',
  String? message = 'Halo, boleh kenalan?',
  String status = 'pending',
}) => {
  'id': id,
  'requester_id': requesterId,
  'requester_name': name,
  'message': message,
  'status': status,
  'created_at': '2026-10-02T08:00:00+00:00',
};

Map<String, dynamic> outgoingMap({
  String id = 'o1',
  String targetId = 'u3',
  String name = 'Bagas Prasetyo',
  String status = 'pending',
}) => {
  'id': id,
  'target_id': targetId,
  'target_name': name,
  'status': status,
  'created_at': '2026-10-02T08:00:00+00:00',
};

class FakeContactApi implements ContactApi {
  final calls = <String>[];
  final params = <String, Map<String, dynamic>>{};
  final results = <String, dynamic>{};
  Object? throwOnCall;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async {
    calls.add(function);
    params[function] = p;
    final t = throwOnCall;
    if (t != null) {
      throwOnCall = null;
      throw t;
    }
    return results[function] ?? <dynamic>[];
  }
}

PostgrestException pgFail(String message) =>
    PostgrestException(message: message, code: 'P0001');
