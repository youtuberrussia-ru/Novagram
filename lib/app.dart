import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'core/widgets/novagram_logo.dart';
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
  Widget build(BuildContext context) => const Scaffold(
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  NovagramLogo(size: 76),
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
