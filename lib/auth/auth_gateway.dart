import 'package:supabase_flutter/supabase_flutter.dart';

/// What can go wrong when signing in or up, in terms a screen can explain.
enum AuthProblem {
  invalidCredentials,
  emailNotConfirmed,
  notInAlumniList,
  weakPassword,
  wrongCode,
  rateLimited,
  network,
  other,
}

class AuthFailure implements Exception {
  const AuthFailure(this.problem);
  final AuthProblem problem;
  @override
  String toString() => 'AuthFailure($problem)';
}

/// Passwords must be at least this long (also what the sign-up form checks).
const int kMinPasswordLength = 8;

/// A short, safe message for [problem]. Never shows server text.
String authProblemMessage(AuthProblem problem) => switch (problem) {
  AuthProblem.invalidCredentials => 'Wrong email or password.',
  AuthProblem.emailNotConfirmed =>
    'This email has not been confirmed yet. Please contact the admins.',
  AuthProblem.notInAlumniList =>
    "We can't find this email in the alumni list. Use the email you gave "
        'Ikafe, or ask the admins to add you.',
  AuthProblem.weakPassword =>
    'That password is too easy to guess. Try a longer one.',
  AuthProblem.wrongCode => 'That code is wrong or has expired. Try again.',
  AuthProblem.rateLimited =>
    'Too many tries. Please wait a few minutes and try again.',
  AuthProblem.network =>
    "Couldn't reach the server. Check your connection and try again.",
  AuthProblem.other => 'Something went wrong. Please try again.',
};

/// Everything the login screens need from the auth backend. The screens use
/// this, not Supabase directly, so tests can swap in a fake.
///
/// Every alumnus has an account already, with their NIM as the first
/// password (see 20261002120000_alumni_password_login.sql); there is no
/// sign-up.
abstract class AuthGateway {
  /// Signs in and returns the person's alumni profile (including
  /// `password_set`, false until they choose their own password).
  Future<Map<String, dynamic>> signIn(String email, String password);

  /// Changes the signed-in person's password and records that they chose one.
  Future<void> changePassword(String newPassword);

  Future<void> sendPasswordReset(String email);

  /// Checks the emailed code, sets the new password, signs in, and returns
  /// the person's alumni profile.
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String newPassword,
  );

  Future<void> signOut();
}

/// The real thing: Supabase Auth (email + password) plus the
/// `claim_alumni_profile()` database function, which links the new account to
/// the alumni record with the same email (only if unclaimed).
class SupabaseAuthGateway implements AuthGateway {
  const SupabaseAuthGateway();

  SupabaseClient get _client => Supabase.instance.client;
  GoTrueClient get _auth => _client.auth;

  AuthFailure _map(Object error) {
    if (error is AuthFailure) return error;
    if (error is AuthRetryableFetchException) {
      return const AuthFailure(AuthProblem.network);
    }
    if (error is AuthWeakPasswordException) {
      return const AuthFailure(AuthProblem.weakPassword);
    }
    if (error is AuthException) {
      final code = error.code ?? '';
      final text = error.message.toLowerCase();
      if (code == 'invalid_credentials' ||
          text.contains('invalid login credentials')) {
        return const AuthFailure(AuthProblem.invalidCredentials);
      }
      if (code == 'email_not_confirmed' ||
          text.contains('email not confirmed')) {
        return const AuthFailure(AuthProblem.emailNotConfirmed);
      }
      if (code == 'weak_password') {
        return const AuthFailure(AuthProblem.weakPassword);
      }
      if (code == 'otp_expired' ||
          text.contains('expired') ||
          text.contains('invalid')) {
        return const AuthFailure(AuthProblem.wrongCode);
      }
      if (code.contains('rate_limit') || error.statusCode == '429') {
        return const AuthFailure(AuthProblem.rateLimited);
      }
    }
    if (error is PostgrestException &&
        error.message.contains('No matching alumni record')) {
      return const AuthFailure(AuthProblem.notInAlumniList);
    }
    final text = error.toString();
    if (RegExp(
      r'SocketException|ClientException|XMLHttpRequest|Failed host lookup',
      caseSensitive: false,
    ).hasMatch(text)) {
      return const AuthFailure(AuthProblem.network);
    }
    return const AuthFailure(AuthProblem.other);
  }

  Future<Map<String, dynamic>> _claim() async {
    try {
      final row = await _client.rpc('claim_alumni_profile');
      return Map<String, dynamic>.from(row as Map);
    } catch (e) {
      // Signed in but no alumni record to link: don't leave a half session.
      await _auth.signOut();
      rethrow;
    }
  }

  @override
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email, password: password);
      return await _claim();
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> changePassword(String newPassword) async {
    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
      await _client.rpc('mark_password_set');
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email);
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    try {
      await _auth.verifyOTP(
        email: email,
        token: code.trim(),
        type: OtpType.recovery,
      );
      await _auth.updateUser(UserAttributes(password: newPassword));
      final profile = await _claim();
      await _client.rpc('mark_password_set');
      return {...profile, 'password_set': true};
    } catch (e) {
      throw _map(e);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (_) {
      // Nothing to sign out of, or offline: the local sign out still happens.
    }
  }
}
