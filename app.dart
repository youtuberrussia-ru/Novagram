import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

class NovagramApp extends StatelessWidget {
  const NovagramApp({required this.isConfigured, super.key});

  final bool isConfigured;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Novagram',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: isConfigured
          ? const AuthGate()
          : const _ConfigurationPage(),
    );
  }
}

class _ConfigurationPage extends StatelessWidget {
  const _ConfigurationPage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.forum_rounded, size: 64, color: Color(0xFF8B7CFF)),
                const SizedBox(height: 20),
                const Text(
                  'Novagram',
                  style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Для подключения сервера добавьте SUPABASE_URL и '
                  'SUPABASE_ANON_KEY при сборке приложения. '
                  'Инструкция находится в README.md.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
