import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../chats/presentation/chat_list_page.dart';
import 'email_auth_page.dart';
import 'mfa_challenge_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final client = Supabase.instance.client;
    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? client.auth.currentSession;
        if (snapshot.hasError) {
          return const Scaffold(
            body: Center(
              child: Text('Ошибка проверки входа. Перезапустите приложение.'),
            ),
          );
        }
        if (session == null) return const EmailAuthPage();
        return _MfaAwareGate(key: ValueKey(session.accessToken));
      },
    );
  }
}

class _MfaAwareGate extends StatefulWidget {
  const _MfaAwareGate({super.key});

  @override
  State<_MfaAwareGate> createState() => _MfaAwareGateState();
}

class _MfaAwareGateState extends State<_MfaAwareGate> {
  late bool _requiresMfa;

  @override
  void initState() {
    super.initState();
    _checkMfa();
  }

  void _checkMfa() {
    final level = Supabase.instance.client.auth.mfa
        .getAuthenticatorAssuranceLevel();
    _requiresMfa =
        level.nextLevel != null && level.nextLevel != level.currentLevel;
  }

  @override
  Widget build(BuildContext context) {
    if (_requiresMfa) {
      return MfaChallengePage(
        onVerified: () => setState(() => _requiresMfa = false),
      );
    }
    return const ChatListPage();
  }
}
