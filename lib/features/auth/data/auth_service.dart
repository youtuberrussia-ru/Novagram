import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Future<AuthResponse> register({
    required String email,
    required String password,
    required String displayName,
  }) {
    return _client.auth.signUp(
      email: email,
      password: password,
      data: {'display_name': displayName},
    );
  }

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
