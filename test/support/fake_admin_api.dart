import 'package:undip_alumni_connect/data/admin_repository.dart';

class FakeAdminApi implements AdminApi {
  final calls = <String>[];
  final params = <String, Map<String, dynamic>>{};
  final allParams = <Map<String, dynamic>>[];
  final results = <String, dynamic>{};
  Object? throwOnCall;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async {
    calls.add(function);
    params[function] = p;
    allParams.add(p);
    final t = throwOnCall;
    if (t != null) {
      throwOnCall = null;
      throw t;
    }
    return results[function] ?? <dynamic>[];
  }
}
