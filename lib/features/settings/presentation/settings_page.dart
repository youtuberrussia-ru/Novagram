import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  bool _showOnline = true;
  bool _readReceipts = true;
  bool _allowGroupInvites = true;
  String _profileVisibility = 'everyone';
  String _messagePermissions = 'everyone';
  bool _privacySaving = false;
  List<Map<String, dynamic>> _blockedUsers = [];

  SupabaseClient get _client => Supabase.instance.client;

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
    });

    try {
      final userId = _client.auth.currentUser?.id;
      if (userId != null) {
        final privacy = await _client
            .from('user_privacy_settings')
            .select()
            .eq('user_id', userId)
            .maybeSingle();
        if (privacy != null && mounted) {
          setState(() {
            _showOnline = privacy['show_online'] as bool? ?? true;
            _readReceipts = privacy['read_receipts'] as bool? ?? true;
            _allowGroupInvites =
                privacy['allow_group_invites'] as bool? ?? true;
            _profileVisibility =
                (privacy['profile_visibility'] == 'nobody') ? 'nobody' : 'everyone';
            _messagePermissions =
                (privacy['message_permissions'] == 'nobody') ? 'nobody' : 'everyone';
          });
        }
        final blocks = await _client
            .from('user_blocks')
            .select('blocked_id')
            .eq('blocker_id', userId);
        final ids = (blocks as List)
            .map((row) => row['blocked_id'] as String)
            .toList();
        if (ids.isNotEmpty) {
          final profiles = await _client
              .from('profiles')
              .select('id, display_name, username')
              .inFilter('id', ids);
          if (mounted) {
            setState(() => _blockedUsers =
                List<Map<String, dynamic>>.from(profiles));
          }
        }
      }
    } catch (_) {
      // A missing migration should not prevent access to ordinary settings.
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _set(String key, bool value, void Function() update) async {
    setState(update);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _savePrivacy() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null || _privacySaving) return;
    setState(() => _privacySaving = true);
    try {
      await _client.from('user_privacy_settings').upsert({
        'user_id': userId,
        'profile_visibility': _profileVisibility,
        'message_permissions': _messagePermissions,
        'show_online': _showOnline,
        'read_receipts': _readReceipts,
        'allow_group_invites': _allowGroupInvites,
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить приватность: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _privacySaving = false);
    }
  }

  Future<void> _configureTwoFactor() async {
    final codeController = TextEditingController();
    String? factorId;
    try {
      final factors = await _client.auth.mfa.listFactors();
      if (factors.totp.any((factor) => factor.status == FactorStatus.verified)) {
        final factor = factors.totp.firstWhere(
          (item) => item.status == FactorStatus.verified,
        );
        final disable = await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Двухфакторная защита включена'),
            content: const Text('Для аккаунта уже подтверждён код из приложения-аутентификатора.'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Оставить'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Отключить'),
              ),
            ],
          ),
        );
        if (disable == true) {
          await _client.auth.mfa.unenroll(factor.id);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Двухфакторная защита отключена')),
            );
          }
        }
        return;
      }

      final enrollment = await _client.auth.mfa.enroll(
        factorType: FactorType.totp,
        issuer: 'Novagram',
        friendlyName: 'Novagram authenticator',
      );
      factorId = enrollment.id;
      if (!mounted) return;
      final accepted = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Подключение 2FA'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Добавьте ключ в приложение-аутентификатор. Не отправляйте его другим людям.'),
                const SizedBox(height: 12),
                SelectableText(
                  enrollment.totp.secret,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  decoration: const InputDecoration(labelText: 'Код из приложения'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Подтвердить'),
            ),
          ],
        ),
      );
      if (accepted != true || !mounted) {
        if (factorId != null) await _client.auth.mfa.unenroll(factorId);
        return;
      }
      final code = codeController.text.trim();
      if (!RegExp(r'^\d{6}$').hasMatch(code)) {
        throw Exception('Введите шестизначный код');
      }
      final challenge = await _client.auth.mfa.challenge(factorId: factorId!);
      await _client.auth.mfa.verify(
        factorId: factorId!,
        challengeId: challenge.id,
        code: code,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Двухфакторная защита включена')),
        );
      }
    } catch (error) {
      if (factorId != null) {
        try {
          final pending = await _client.auth.mfa.listFactors();
          final stillPending = pending.all.any((item) => item.id == factorId && item.status != FactorStatus.verified);
          if (stillPending) await _client.auth.mfa.unenroll(factorId!);
        } catch (_) {}
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось настроить 2FA: $error')),
        );
      }
    } finally {
      codeController.dispose();
    }
  }

  Future<void> _unblock(Map<String, dynamic> user) async {
    final userId = _client.auth.currentUser?.id;
    final blockedId = user['id'] as String?;
    if (userId == null || blockedId == null) return;
    try {
      await _client.from('user_blocks').delete()
          .eq('blocker_id', userId).eq('blocked_id', blockedId);
      if (mounted) {
        setState(() => _blockedUsers.removeWhere((item) => item['id'] == blockedId));
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось разблокировать: $error')),
        );
      }
    }
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

  Widget _visibilityTile({
    required String title,
    required String subtitle,
    required String value,
    required ValueChanged<String?> onChanged,
  }) =>
      ListTile(
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: DropdownButton<String>(
          value: value,
          items: const [
            DropdownMenuItem(value: 'everyone', child: Text('Все')),
            DropdownMenuItem(value: 'nobody', child: Text('Никто')),
          ],
          onChanged: onChanged,
        ),
      );

  Future<void> _showBlockedUsers() async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Заблокированные пользователи'),
        content: SizedBox(
          width: 380,
          child: _blockedUsers.isEmpty
              ? const Text('Список пока пуст.')
              : ListView(
                  shrinkWrap: true,
                  children: _blockedUsers.map((user) {
                    final name =
                        user['display_name'] as String? ?? 'Пользователь';
                    final username = user['username'] as String? ?? '';
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(name),
                      subtitle: username.isEmpty ? null : Text('@$username'),
                      trailing: TextButton(
                        onPressed: () async {
                          await _unblock(user);
                          if (dialogContext.mounted) {
                            Navigator.pop(dialogContext);
                          }
                        },
                        child: const Text('Снять блок'),
                      ),
                    );
                  }).toList(),
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

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
                    onChanged: (v) => _set('setting_enter_to_send', v,
                        () => _enterToSend = v),
                  ),
                  _switch(
                    title: 'Компактные сообщения',
                    subtitle: 'Уменьшить отступы между сообщениями',
                    value: _compactMessages,
                    onChanged: (v) => _set('setting_compact_messages', v,
                        () => _compactMessages = v),
                  ),
                  _switch(
                    title: 'Показывать время',
                    subtitle: 'Отображать время отправки под сообщениями',
                    value: _showTime,
                    onChanged: (v) => _set('setting_show_time', v,
                        () => _showTime = v),
                  ),
                  _switch(
                    title: 'Подтверждать удаление',
                    subtitle: 'Спрашивать перед удалением сообщения',
                    value: _confirmDelete,
                    onChanged: (v) => _set('setting_confirm_delete', v,
                        () => _confirmDelete = v),
                  ),
                ]),
                _section('Удобство', Icons.tune_rounded, [
                  _switch(
                    title: 'Тактильный отклик',
                    subtitle: 'Лёгкая вибрация при отправке сообщения',
                    value: _hapticFeedback,
                    onChanged: (v) => _set('setting_haptic', v,
                        () => _hapticFeedback = v),
                  ),
                ]),
                _section('Приватность и защита', Icons.shield_outlined, [
                  _visibilityTile(
                    title: 'Кто видит мой профиль',
                    subtitle: 'Управление доступностью профиля',
                    value: _profileVisibility,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _profileVisibility = v);
                      _savePrivacy();
                    },
                  ),
                  _visibilityTile(
                    title: 'Кто может писать',
                    subtitle: 'Ограничение входящих сообщений',
                    value: _messagePermissions,
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() => _messagePermissions = v);
                      _savePrivacy();
                    },
                  ),
                  _switch(
                    title: 'Показывать онлайн',
                    subtitle: 'Разрешить другим видеть статус активности',
                    value: _showOnline,
                    onChanged: (v) {
                      setState(() => _showOnline = v);
                      _savePrivacy();
                    },
                  ),
                  _switch(
                    title: 'Отчёты о прочтении',
                    subtitle: 'Разрешить показывать отметки прочтения',
                    value: _readReceipts,
                    onChanged: (v) {
                      setState(() => _readReceipts = v);
                      _savePrivacy();
                    },
                  ),
                  _switch(
                    title: 'Приглашения в группы',
                    subtitle: 'Разрешить добавлять меня в групповые чаты',
                    value: _allowGroupInvites,
                    onChanged: (v) {
                      setState(() => _allowGroupInvites = v);
                      _savePrivacy();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.block),
                    title: const Text('Заблокированные пользователи'),
                    subtitle: Text('В списке: ${_blockedUsers.length}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: _showBlockedUsers,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      'Настройки приватности сохраняются в аккаунте. Защита не может полностью исключить скриншоты или копирование уже увиденной информации.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  if (_privacySaving)
                    const LinearProgressIndicator(minHeight: 2),
                ]),
                _section('Novagram Shield', Icons.security, const [
                  ListTile(
                    leading: Icon(Icons.report_gmailerrorred),
                    title: Text('Жалобы на угрозы и доксинг'),
                    subtitle: Text('Система жалоб готовится к подключению модерации'),
                  ),
                  ListTile(
                    leading: Icon(Icons.phonelink_lock),
                    title: Text('Управление устройствами'),
                    subtitle: Text('Управление сессиями будет доступно после подключения серверной функции'),
                  ),
                  ListTile(
                    leading: Icon(Icons.verified_user_outlined),
                    title: Text('Двухфакторная защита (TOTP)'),
                    subtitle: Text('Подтверждение входа кодом из приложения-аутентификатора'),
                    trailing: Icon(Icons.chevron_right),
                    onTap: _configureTwoFactor,
                  ),
                ]),
                _section('Novagram', Icons.info_outline, const [
                  ListTile(
                    title: Text('Версия приложения'),
                    subtitle: Text('0.2.0 • Обновление безопасности'),
                  ),
                ]),
              ],
            ),
    );
  }
}
