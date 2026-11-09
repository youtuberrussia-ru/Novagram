import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/auth_service.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();

  late final AuthService _authService;
  bool _codeSent = false;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _authService = AuthService(Supabase.instance.client);
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    final String phone = _phoneController.text.trim();
    if (!phone.startsWith('+') || phone.length < 8) {
      setState(() => _error = 'Введите номер в международном формате, например +34123456789.');
      return;
    }

    await _runSafely(() async {
      await _authService.sendSmsCode(phone);
      if (mounted) setState(() => _codeSent = true);
    });
  }

  Future<void> _verifyCode() async {
    final String phone = _phoneController.text.trim();
    final String code = _codeController.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Проверьте SMS-код.');
      return;
    }

    await _runSafely(() async {
      await _authService.verifySmsCode(phone: phone, code: code);
    });
  }

  Future<void> _runSafely(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AuthException catch (exception) {
      if (mounted) setState(() => _error = exception.message);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Не удалось выполнить запрос. Проверьте соединение и настройки SMS.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Icon(Icons.forum_rounded, size: 68, color: Color(0xFF8B7CFF)),
                  const SizedBox(height: 18),
                  const Text(
                    'Novagram',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _codeSent
                        ? 'Введите код подтверждения из SMS'
                        : 'Общение начинается здесь',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 32),
                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    enabled: !_codeSent && !_busy,
                    decoration: const InputDecoration(
                      labelText: 'Номер телефона',
                      hintText: '+34123456789',
                      prefixIcon: Icon(Icons.phone_rounded),
                    ),
                  ),
                  if (_codeSent) ...[
                    const SizedBox(height: 14),
                    TextField(
                      controller: _codeController,
                      keyboardType: TextInputType.number,
                      enabled: !_busy,
                      maxLength: 8,
                      decoration: const InputDecoration(
                        labelText: 'SMS-код',
                        prefixIcon: Icon(Icons.verified_user_outlined),
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Color(0xFFFF8791))),
                  ],
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _busy ? null : (_codeSent ? _verifyCode : _sendCode),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: _busy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_codeSent ? 'Подтвердить номер' : 'Получить SMS-код'),
                    ),
                  ),
                  if (_codeSent)
                    TextButton(
                      onPressed: _busy
                          ? null
                          : () => setState(() {
                                _codeSent = false;
                                _codeController.clear();
                                _error = null;
                              }),
                      child: const Text('Изменить номер'),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Продолжая, вы подтверждаете, что имеете право использовать указанный номер.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
