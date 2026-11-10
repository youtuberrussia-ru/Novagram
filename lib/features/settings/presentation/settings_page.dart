import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = true;
  bool _enterToSend = false;
  bool _compactMessages = false;
  bool _showTime = true;
  bool _confirmDelete = true;
  bool _hapticFeedback = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enterToSend = prefs.getBool('setting_enter_to_send') ?? false;
      _compactMessages = prefs.getBool('setting_compact_messages') ?? false;
      _showTime = prefs.getBool('setting_show_time') ?? true;
      _confirmDelete = prefs.getBool('setting_confirm_delete') ?? true;
      _hapticFeedback = prefs.getBool('setting_haptic') ?? true;
      _loading = false;
    });
  }

  Future<void> _set(String key, bool value, void Function() update) async {
    setState(update);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Widget _section(String title, IconData icon, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                child: Row(
                  children: [
                    Icon(icon, color: Theme.of(context).colorScheme.primary),
                    const SizedBox(width: 10),
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                  ],
                ),
              ),
              ...children,
            ],
          ),
        ),
      );

  Widget _switch({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) =>
      SwitchListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(subtitle),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Настройки')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _section('Сообщения', Icons.chat_bubble_outline, [
                  _switch(
                    title: 'Отправлять по Enter',
                    subtitle: 'Enter отправляет сообщение, перенос строки отключён',
                    value: _enterToSend,
                    onChanged: (v) => _set(
                      'setting_enter_to_send',
                      v,
                      () => _enterToSend = v,
                    ),
                  ),
                  _switch(
                    title: 'Компактные сообщения',
                    subtitle: 'Уменьшить отступы между сообщениями',
                    value: _compactMessages,
                    onChanged: (v) => _set(
                      'setting_compact_messages',
                      v,
                      () => _compactMessages = v,
                    ),
                  ),
                  _switch(
                    title: 'Показывать время',
                    subtitle: 'Отображать время отправки под сообщениями',
                    value: _showTime,
                    onChanged: (v) => _set(
                      'setting_show_time',
                      v,
                      () => _showTime = v,
                    ),
                  ),
                  _switch(
                    title: 'Подтверждать удаление',
                    subtitle: 'Спрашивать перед удалением сообщения',
                    value: _confirmDelete,
                    onChanged: (v) => _set(
                      'setting_confirm_delete',
                      v,
                      () => _confirmDelete = v,
                    ),
                  ),
                ]),
                _section('Удобство', Icons.tune_rounded, [
                  _switch(
                    title: 'Тактильный отклик',
                    subtitle: 'Лёгкая вибрация при отправке сообщения',
                    value: _hapticFeedback,
                    onChanged: (v) => _set(
                      'setting_haptic',
                      v,
                      () => _hapticFeedback = v,
                    ),
                  ),
                ]),
                _section('Аккаунт и безопасность', Icons.shield_outlined, [
                  const ListTile(
                    leading: Icon(Icons.email_outlined),
                    title: Text('Вход по электронной почте'),
                    subtitle: Text('Ваш аккаунт защищён авторизацией Supabase'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.lock_outline),
                    title: Text('Конфиденциальность'),
                    subtitle: Text('Расширенные настройки приватности появятся в следующих обновлениях'),
                  ),
                ]),
                _section('Novagram', Icons.info_outline, const [
                  ListTile(
                    title: Text('Версия приложения'),
                    subtitle: Text('0.1.0 • Ранняя версия'),
                  ),
                ]),
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'Некоторые функции, например push-уведомления и управление активными сеансами, ещё разрабатываются и не отображаются как готовые.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
              ],
            ),
    );
  }
}
