import 'package:supabase_flutter/supabase_flutter.dart';

class AuthService {
  AuthService(this._client);

  final SupabaseClient _client;

  Future<void> sendSmsCode(String phone) async {
    await _client.auth.signInWithOtp(
      phone: phone,
      shouldCreateUser: true,
    );
  }

  Future<void> verifySmsCode({
    required String phone,
    required String code,
  }) async {
    await _client.auth.verifyOTP(
      phone: phone,
      token: code,
      type: OtpType.sms,
    );
  }

  Future<void> signOut() => _client.auth.signOut();
}
