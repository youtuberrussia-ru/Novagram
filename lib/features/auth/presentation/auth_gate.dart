import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../chats/presentation/chat_list_page.dart';
import 'email_auth_page.dart';

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
        return session == null ? const EmailAuthPage() : const ChatListPage();
      },
    );
  }
}
