import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/auth_gate.dart';

class NovagramApp extends StatelessWidget {
  const NovagramApp({required this.isConfigured, super.key});

  final bool isConfigured;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Novagram',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        home: isConfigured ? const AuthGate() : const _ConfigurationPage(),
      );
}

class _ConfigurationPage extends StatelessWidget {
  const _ConfigurationPage();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: const SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.forum_rounded,
                    size: 64,
                    color: Color(0xFF8B7CFF),
                  ),
                  SizedBox(height: 20),
                  Text(
                    'Novagram',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Для запуска подключите Supabase: добавьте '
                    'SUPABASE_URL и SUPABASE_PUBLISHABLE_KEY '
                    'в GitHub Actions Variables и запустите сборку.',
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
