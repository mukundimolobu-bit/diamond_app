import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AuthUser {
  const AuthUser({
    required this.id,
    required this.email,
    required this.isEmailConfirmed,
    this.displayName,
    this.avatarUrl,
  });

  final String id;
  final String email;
  final bool isEmailConfirmed;
  final String? displayName;
  final String? avatarUrl;
}

class SignUpResult {
  const SignUpResult({required this.user, required this.hasSession});

  final AuthUser? user;
  final bool hasSession;
}

abstract interface class AuthGateway {
  AuthUser? get currentUser;
  Stream<AuthUser?> get authStateChanges;

  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  });
  Future<void> signIn({required String email, required String password});
  Future<bool> signInWithGoogle({required String redirectTo});
  Future<void> sendPasswordReset(String email);
  Future<void> signOut();
}

class SupabaseAuthGateway implements AuthGateway {
  SupabaseAuthGateway(this._client);

  final SupabaseClient _client;

  AuthUser? _mapUser(User? user) {
    if (user == null) return null;
    return AuthUser(
      id: user.id,
      email: user.email ?? '',
      isEmailConfirmed: user.emailConfirmedAt != null,
      displayName:
          (user.userMetadata?['full_name'] ?? user.userMetadata?['name'])
              ?.toString(),
      avatarUrl:
          (user.userMetadata?['avatar_url'] ?? user.userMetadata?['picture'])
              ?.toString(),
    );
  }

  @override
  AuthUser? get currentUser => _mapUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> get authStateChanges => _client.auth.onAuthStateChange.map(
    (event) => _mapUser(event.session?.user),
  );

  @override
  Future<SignUpResult> signUp({
    required String fullName,
    required String email,
    required String password,
  }) async {
    final response = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'full_name': fullName},
    );
    return SignUpResult(
      user: _mapUser(response.user),
      hasSession: response.session != null,
    );
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    await _client.auth.signInWithPassword(email: email, password: password);
  }

  @override
  Future<bool> signInWithGoogle({required String redirectTo}) {
    if (!kIsWeb) {
      throw UnsupportedError(
        'Google sign-in on Android and iOS is unavailable until native '
        'redirect configuration is added.',
      );
    }
    return _client.auth.signInWithOAuth(
      OAuthProvider.google,
      redirectTo: redirectTo,
    );
  }

  @override
  Future<void> sendPasswordReset(String email) async {
    await _client.auth.resetPasswordForEmail(email);
  }

  @override
  Future<void> signOut() => _client.auth.signOut();
}
