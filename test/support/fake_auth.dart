import 'package:undip_alumni_connect/auth/auth_gateway.dart';

import 'fake_lock.dart';

/// An in-memory auth backend for screen tests.
class FakeAuth implements AuthGateway {
  FakeAuth({
    Map<String, dynamic>? profile,
    this.password = 'correct-horse',
    this.passwordSet = true,
    this.signInError,
  }) : profile = profile ?? {...testProfile(), 'nim': 'NIM-0001'};

  final Map<String, dynamic> profile;
  String password;
  bool passwordSet;

  /// Thrown by every call when set.
  Object? signInError;

  int signOuts = 0;
  int resets = 0;
  String? changedTo;

  static const goodCode = '123456';

  Map<String, dynamic> get _profile => {
    ...profile,
    'password_set': passwordSet,
  };

  @override
  Future<Map<String, dynamic>> signIn(String email, String password) async {
    if (signInError != null) throw signInError!;
    if (email != profile['email'] || password != this.password) {
      throw const AuthFailure(AuthProblem.invalidCredentials);
    }
    return _profile;
  }

  @override
  Future<void> changePassword(String newPassword) async {
    if (signInError != null) throw signInError!;
    password = newPassword;
    changedTo = newPassword;
    passwordSet = true;
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    if (signInError != null) throw signInError!;
    resets++;
  }

  @override
  Future<Map<String, dynamic>> resetPassword(
    String email,
    String code,
    String newPassword,
  ) async {
    if (code != goodCode) throw const AuthFailure(AuthProblem.wrongCode);
    password = newPassword;
    passwordSet = true;
    return _profile;
  }

  @override
  Future<void> signOut() async => signOuts++;
}
