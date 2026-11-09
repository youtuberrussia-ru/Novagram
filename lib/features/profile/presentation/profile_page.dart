import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../auth/data/auth_service.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    return Scaffold(appBar: AppBar(title: const Text('Профиль')), body: Padding(
      padding: const EdgeInsets.all(24), child: Column(children: [
        const CircleAvatar(radius: 42, child: Icon(Icons.person, size: 42)),
        const SizedBox(height: 16),
        Text(user?.phone ?? 'Номер не указан', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8), const Text('Аккаунт Novagram'), const Spacer(),
        SizedBox(width: double.infinity, child: OutlinedButton.icon(
          onPressed: () async { await AuthService(Supabase.instance.client).signOut(); if (context.mounted) Navigator.of(context).pop(); },
          icon: const Icon(Icons.logout), label: const Text('Выйти из аккаунта'),
        )),
      ]),
    ));
  }
}