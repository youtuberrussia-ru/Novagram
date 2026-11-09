import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../data/auth_service.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});
  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}
class _PhoneAuthPageState extends State<PhoneAuthPage> {
  final _phone = TextEditingController();
  final _code = TextEditingController();
  late final AuthService _auth;
  bool _codeSent = false, _busy = false;
  String? _error;
  @override
  void initState() { super.initState(); _auth = AuthService(Supabase.instance.client); }
  @override
  void dispose() { _phone.dispose(); _code.dispose(); super.dispose(); }
  Future<void> _run(Future<void> Function() action) async {
    setState(() { _busy = true; _error = null; });
    try { await action(); }
    on AuthException catch (e) { if (mounted) setState(() => _error = e.message); }
    catch (_) { if (mounted) setState(() => _error = 'Не удалось выполнить запрос. Проверьте интернет и настройки SMS.'); }
    finally { if (mounted) setState(() => _busy = false); }
  }
  Future<void> _send() async {
    final phone = _phone.text.trim();
    if (!RegExp(r'^\+[1-9]\d{6,14}$').hasMatch(phone)) { setState(() => _error = 'Введите номер в международном формате, например +79991234567.'); return; }
    await _run(() async { await _auth.sendSmsCode(phone); if (mounted) setState(() => _codeSent = true); });
  }
  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) { setState(() => _error = 'Введите код из SMS.'); return; }
    await _run(() => _auth.verifySmsCode(phone: _phone.text.trim(), code: code));
  }
  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(child: Center(child: SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 440), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Icon(Icons.forum_rounded, size: 68, color: Color(0xFF8B7CFF)),
          const SizedBox(height: 18),
          const Text('Novagram', textAlign: TextAlign.center, style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(_codeSent ? 'Введите код подтверждения из SMS' : 'Общение начинается здесь', textAlign: TextAlign.center),
          const SizedBox(height: 32),
          TextField(controller: _phone, keyboardType: TextInputType.phone, enabled: !_codeSent && !_busy, decoration: const InputDecoration(labelText: 'Номер телефона', hintText: '+79991234567', prefixIcon: Icon(Icons.phone))),
          if (_codeSent) ...[const SizedBox(height: 14), TextField(controller: _code, keyboardType: TextInputType.number, enabled: !_busy, maxLength: 8, decoration: const InputDecoration(labelText: 'SMS-код', prefixIcon: Icon(Icons.verified_user_outlined)))],
          if (_error != null) ...[const SizedBox(height: 12), Text(_error!, style: const TextStyle(color: Color(0xFFFF8791)))],
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : (_codeSent ? _verify : _send), child: Padding(padding: const EdgeInsets.symmetric(vertical: 14), child: _busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_codeSent ? 'Подтвердить номер' : 'Получить SMS-код'))),
          if (_codeSent) TextButton(onPressed: _busy ? null : () => setState(() { _codeSent = false; _code.clear(); _error = null; }), child: const Text('Изменить номер')),
        ],
      )),
    ))),
  );
}