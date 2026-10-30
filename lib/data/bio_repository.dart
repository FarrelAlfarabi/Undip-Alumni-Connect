import 'package:supabase_flutter/supabase_flutter.dart';

/// The longest bio the database accepts (also a check on the column).
const int kBioMaxLength = 200;

/// Thin seam over the Supabase client for the profile bio.
abstract class BioApi {
  Future<dynamic> rpc(String function, Map<String, dynamic> params);
}

class SupabaseBioApi implements BioApi {
  SupabaseBioApi([SupabaseClient? client])
    : _client = client ?? Supabase.instance.client;
  final SupabaseClient _client;

  @override
  Future<dynamic> rpc(String function, Map<String, dynamic> params) =>
      _client.rpc(function, params: params);
}

/// Saves the bio through profile_set_bio. The column itself is locked for the
/// app, so this function is the only way in.
class ProfileBioRepository {
  ProfileBioRepository([BioApi? api]) : _api = api ?? SupabaseBioApi();
  final BioApi _api;

  /// An empty or blank [bio] removes it. Throws when the save fails.
  Future<void> save(String profileId, String bio) => _api.rpc(
    'profile_set_bio',
    {'p_profile': profileId, 'p_bio': bio.trim()},
  );
}
