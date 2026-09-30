import 'package:undip_alumni_connect/data/marketplace_repository.dart';

/// A listings row as the API returns it. Override fields per test.
Map<String, dynamic> listingMap({
  String id = 'l1',
  String status = 'approved',
  String title = 'Kopi Arabika',
  int priceIdr = 85000,
  String category = 'Food & Drink',
  String city = 'Semarang',
  String? shopUrl,
  String? contactInfo = 'WA 0800-0000-0000',
  Object? seller,
  String? rejectedReason,
  String? approvedAt = '2026-09-20T10:00:00+00:00',
  String createdAt = '2026-09-19T08:00:00+00:00',
}) => {
  'id': id,
  'seller_id': 's1',
  'title': title,
  'description': 'Sangrai medium',
  'price_idr': priceIdr,
  'category': category,
  'city': city,
  'image_url': 'https://picsum.photos/seed/x/600/400',
  'shop_url': shopUrl,
  'contact_info': contactInfo,
  'status': status,
  'rejected_reason': rejectedReason,
  'created_at': createdAt,
  'updated_at': createdAt,
  'approved_at': approvedAt,
  'seller': seller,
};

const sellerMap = {
  'id': 's1',
  'name': 'Bunga Citra Ayu',
  'faculty': 'Fakultas Ekonomika dan Bisnis',
  'major': 'Akuntansi',
  'graduation_year': 2016,
  'city': 'Jakarta',
};

class FakeApi implements MarketplaceApi {
  final calls = <String>[];
  final params = <String, Map<String, dynamic>>{};
  final reports = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> approved = [];
  Map<String, dynamic>? profile;
  dynamic rpcResult;
  Object? throwOnCall;

  @override
  Future<List<Map<String, dynamic>>> selectApprovedListings() async {
    calls.add('select');
    if (throwOnCall != null) throw throwOnCall!;
    return approved;
  }

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> p) async {
    calls.add(function);
    params[function] = p;
    if (throwOnCall != null) throw throwOnCall!;
    return rpcResult;
  }

  @override
  Future<void> insertReport(Map<String, dynamic> row) async {
    calls.add('report');
    if (throwOnCall != null) throw throwOnCall!;
    reports.add(row);
  }

  @override
  Future<Map<String, dynamic>?> selectProfile(String id) async {
    calls.add('profile');
    return profile;
  }
}
