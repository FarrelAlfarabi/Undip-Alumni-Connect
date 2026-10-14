import 'package:supabase_flutter/supabase_flutter.dart';

/// Real login switch. Off by default, so the app behaves exactly as before
/// (email match, no code). A build made with `--dart-define=REAL_LOGIN=true`
/// asks for an emailed 6 digit code instead. Turn it on only together with
/// supabase/cutover_real_login.sql, see docs/REAL_LOGIN.md.
const bool kRealLogin = bool.fromEnvironment('REAL_LOGIN');

/// Email code login. One screen asks for the email, then for the code.
abstract class LoginApi {
  /// True when an alumni record exists for [email] (so a code is worth
  /// sending).
  Future<bool> emailKnown(String email);

  /// Emails a 6 digit code.
  Future<void> sendCode(String email);

  /// Checks the code and links the sign in to the alumni profile. Returns
  /// the profile, or null when this sign in has no usable verified profile.
  Future<Map<String, dynamic>?> verifyCode(String email, String code);

  /// True when a signed in session is stored on this device.
  bool get hasSession;

  Future<void> signOut();
}

class SupabaseLoginApi implements LoginApi {
  SupabaseLoginApi([SupabaseClient? client]) : _client = client;

  final SupabaseClient? _client;
  SupabaseClient get _c => _client ?? Supabase.instance.client;

  @override
  Future<bool> emailKnown(String email) async {
    final r = await _c.rpc('login_email_known', params: {'p_email': email});
    return r == true;
  }

  @override
  Future<void> sendCode(String email) =>
      _c.auth.signInWithOtp(email: email, shouldCreateUser: true);

  @override
  Future<Map<String, dynamic>?> verifyCode(String email, String code) async {
    await _c.auth.verifyOTP(
      email: email,
      token: code.trim(),
      type: OtpType.email,
    );
    final r = await _c.rpc('claim_alumni_profile');
    Object? row = r;
    if (r is List) row = r.isEmpty ? null : r.first;
    if (row is! Map) {
      await signOut();
      return null;
    }
    final profile = Map<String, dynamic>.from(row);
    if (profile['verification_status'] != 'verified') {
      await signOut();
      return null;
    }
    return profile;
  }

  @override
  bool get hasSession => _c.auth.currentSession != null;

  @override
  Future<void> signOut() => _c.auth.signOut();
}
