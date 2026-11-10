import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MfaChallengePage extends StatefulWidget {
  const MfaChallengePage({super.key, required this.onVerified});

  final VoidCallback onVerified;

  @override
  State<MfaChallengePage> createState() => _MfaChallengePageState();
}

class _MfaChallengePageState extends State<MfaChallengePage> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      setState(() => _error = 'Введите шестизначный код.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final client = Supabase.instance.client;
      final factors = await client.auth.mfa.listFactors();
      if (factors.totp.isEmpty) {
        throw Exception('Не найден подтверждённый фактор. Обратитесь в поддержку.');
      }
      final factorId = factors.totp.first.id;
      final challenge = await client.auth.mfa.challenge(factorId: factorId);
      await client.auth.mfa.verify(
        factorId: factorId,
        challengeId: challenge.id,
        code: code,
      );
      widget.onVerified();
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Код не подошёл. Проверьте его и попробуйте снова.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    await Supabase.instance.client.auth.signOut();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Дополнительная проверка'),
          automaticallyImplyLeading: false,
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.shield_outlined, size: 56),
                  const SizedBox(height: 16),
                  Text(
                    'Подтвердите вход',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Введите код из приложения-аутентификатора, подключённого к Novagram.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    maxLength: 6,
                    textAlign: TextAlign.center,
                    decoration: InputDecoration(
                      labelText: 'Шестизначный код',
                      errorText: _error,
                    ),
                    onSubmitted: (_) => _busy ? null : _verify(),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _verify,
                    child: _busy
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Подтвердить'),
                  ),
                  TextButton(
                    onPressed: _busy ? null : _signOut,
                    child: const Text('Выйти из аккаунта'),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}
