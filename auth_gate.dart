import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'phone_auth_page.dart';
import '../../chats/presentation/chat_list_page.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final SupabaseClient client = Supabase.instance.client;

    return StreamBuilder<AuthState>(
      stream: client.auth.onAuthStateChange,
      builder: (BuildContext context, AsyncSnapshot<AuthState> snapshot) {
        final Session? session =
            snapshot.data?.session ?? client.auth.currentSession;

        if (snapshot.hasError) {
          return const _AuthErrorPage();
        }
        if (session == null) {
          return const PhoneAuthPage();
        }
        return const ChatListPage();
      },
    );
  }
}

class _AuthErrorPage extends StatelessWidget {
  const _AuthErrorPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: Text('Не удалось проверить авторизацию. Перезапустите приложение.')),
    );
  }
}
