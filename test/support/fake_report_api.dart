import 'package:undip_alumni_connect/data/block_list.dart';
import 'package:undip_alumni_connect/data/report_repository.dart';

class FakeReportApi implements ReportApi {
  final calls = <String>[];
  final params = <String, Map<String, dynamic>>{};
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
    return null;
  }
}

class FakeBlockApi implements BlockApi {
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
