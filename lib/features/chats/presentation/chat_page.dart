import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'chat_media.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({required this.chatId, required this.title, super.key});

  final String chatId;
  final String title;

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();
  late final String _myId;
  late final Stream<List<Map<String, dynamic>>> _messages;
  bool _sending = false;
  bool _autoScrollPending = false;
  bool _enterToSend = false;
  bool _compactMessages = false;
  bool _showTime = true;
  bool _confirmDelete = true;
  bool _hapticFeedback = true;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _myId = _client.auth.currentUser!.id;
    _loadChatSettings();
    _messages = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('chat_id', widget.chatId)
        .order('created_at');
  }

  @override
  void dispose() {
    _text.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadChatSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enterToSend = prefs.getBool('setting_enter_to_send') ?? false;
      _compactMessages = prefs.getBool('setting_compact_messages') ?? false;
      _showTime = prefs.getBool('setting_show_time') ?? true;
      _confirmDelete = prefs.getBool('setting_confirm_delete') ?? true;
      _hapticFeedback = prefs.getBool('setting_haptic') ?? true;
    });
  }

  void _scheduleScroll() {
    if (_autoScrollPending) return;
    _autoScrollPending = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoScrollPending = false;
      if (!mounted || !_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  Future<String?> _getDirectPartner() async {
    final result = await _client.rpc(
      'get_direct_chat_partner',
      params: {'p_chat_id': widget.chatId},
    );
    return result as String?;
  }

  Future<void> _blockPartner() async {
    try {
      final partnerId = await _getDirectPartner();
      if (partnerId == null) {
        throw Exception('Блокировка доступна в личном чате.');
      }
      await _client.from('user_blocks').upsert({
        'blocker_id': _myId,
        'blocked_id': partnerId,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пользователь заблокирован')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось заблокировать: $error')),
        );
      }
    }
  }

  Future<void> _reportConversation() async {
    final details = TextEditingController();
    var category = 'harassment';
    final report = await showDialog<Map<String, String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Пожаловаться'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  decoration: const InputDecoration(labelText: 'Причина'),
                  items: const [
                    DropdownMenuItem(value: 'harassment', child: Text('Преследование')),
                    DropdownMenuItem(value: 'doxxing', child: Text('Публикация личных данных')),
                    DropdownMenuItem(value: 'threats', child: Text('Угрозы')),
                    DropdownMenuItem(value: 'swatting', child: Text('Угроза ложного вызова служб')),
                    DropdownMenuItem(value: 'spam', child: Text('Спам')),
                    DropdownMenuItem(value: 'impersonation', child: Text('Выдаёт себя за другого')),
                    DropdownMenuItem(value: 'other', child: Text('Другое')),
                  ],
                  onChanged: (value) {
                    if (value != null) setDialogState(() => category = value);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: details,
                  maxLength: 2000,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Подробности (необязательно)',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, {
                'category': category,
                'details': details.text.trim(),
              }),
              child: const Text('Отправить'),
            ),
          ],
        ),
      ),
    );
    final detailsText = details.text.trim();
    details.dispose();
    if (report == null || !mounted) return;

    try {
      final partnerId = await _getDirectPartner();
      await _client.from('user_reports').insert({
        'reporter_id': _myId,
        'reported_user_id': partnerId,
        'chat_id': widget.chatId,
        'category': report['category'],
        'details': detailsText,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Жалоба отправлена. Спасибо за сообщение.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить жалобу: $error')),
        );
      }
    }
  }

  bool _mayContainPrivateData(String text) {
    final email = RegExp(r'[\\w.+-]+@[\\w.-]+\\.[A-Za-z]{2,}');
    final phone = RegExp(r'\\+?\\d[\\d\\s().-]{7,}\\d');
    final ipAddress = RegExp(r'\\b(?:\\d{1,3}\\.){3}\\d{1,3}\\b');
    return email.hasMatch(text) ||
        phone.hasMatch(text) ||
        ipAddress.hasMatch(text);
  }

  Future<bool> _confirmPrivateDataWarning(String text) async {
    if (!_mayContainPrivateData(text)) return true;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Проверьте личные данные'),
        content: const Text(
          'Похоже, сообщение содержит электронную почту, номер телефона или IP-адрес. '
          'Не отправляйте чужие личные данные без разрешения. Вы уверены, что хотите продолжить?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Проверить'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Всё равно отправить'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    if (body.length > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщение слишком длинное')),
      );
      return;
    }

    final safeToSend = await _confirmPrivateDataWarning(body);
    if (!safeToSend || !mounted) return;

    if (_hapticFeedback) await HapticFeedback.selectionClick();
    setState(() => _sending = true);
    try {
      await _client.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': _myId,
        'body': body,
      });
      _text.clear();
      _focus.requestFocus();
    } on PostgrestException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось отправить: ${error.message}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка отправки: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _showMessageActions(Map<String, dynamic> message) async {
    final messageId = message['id'] as String?;
    if (messageId == null) return;
    final confirmed = !_confirmDelete
        ? true
        : (await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить сообщение?'),
        content: const Text('Сообщение будет удалено для всех участников чата.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    )) ?? false;
    if (!confirmed || !mounted) return;
    try {
      await _client
          .from('messages')
          .delete()
          .eq('id', messageId)
          .eq('sender_id', _myId);
      final mediaPath = message['media_path'] as String?;
      if (mediaPath != null) {
        try {
          await _client.storage.from('chat-media').remove([mediaPath]);
        } catch (_) {
          // The message is already deleted; a stale private object is harmless.
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось удалить сообщение: $error')),
        );
      }
    }
  }

  Widget _messageBubble(Map<String, dynamic> message) {
    final mine = message['sender_id'] == _myId;
    final body = (message['body'] as String?) ?? '';
    final type = (message['message_type'] as String?) ?? 'text';
    final mediaPath = message['media_path'] as String?;
    final time = DateTime.tryParse(message['created_at'] as String? ?? '');
    final timeLabel = time == null
        ? ''
        : '${time.toLocal().hour.toString().padLeft(2, '0')}:'
            '${time.toLocal().minute.toString().padLeft(2, '0')}';

    return GestureDetector(
      onLongPress: mine ? () => _showMessageActions(message) : null,
      child: Align(
        alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
        constraints: const BoxConstraints(maxWidth: 310),
        margin: EdgeInsets.symmetric(
          vertical: _compactMessages ? 2 : 4,
          horizontal: 8,
        ),
        padding: _compactMessages
            ? const EdgeInsets.fromLTRB(11, 7, 10, 5)
            : const EdgeInsets.fromLTRB(14, 10, 12, 7),
        decoration: BoxDecoration(
          color: mine ? const Color(0xFF5146A8) : const Color(0xFF202640),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(17),
            topRight: const Radius.circular(17),
            bottomLeft: Radius.circular(mine ? 17 : 5),
            bottomRight: Radius.circular(mine ? 5 : 17),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: type == 'text' || mediaPath == null
                  ? Text(body, style: const TextStyle(fontSize: 15))
                  : ChatMediaBubble(path: mediaPath, type: type),
            ),
            if (_showTime) ...[
              const SizedBox(height: 3),
              Text(
                timeLabel,
                style: const TextStyle(color: Colors.white60, fontSize: 10),
              ),
            ],
          ],
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Безопасность чата',
            onSelected: (value) {
              if (value == 'report') _reportConversation();
              if (value == 'block') _blockPartner();
            },
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'report',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.flag_outlined),
                  title: Text('Пожаловаться'),
                ),
              ),
              PopupMenuItem(
                value: 'block',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.block),
                  title: Text('Заблокировать'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _messages,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('Ошибка загрузки сообщений: ${snapshot.error}'),
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final messages = snapshot.data!;
                if (messages.isEmpty) {
                  return const Center(child: Text('Начните общение'));
                }
                _scheduleScroll();
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: messages.length,
                  itemBuilder: (context, index) =>
                      _messageBubble(messages[index]),
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  ChatMediaComposer(chatId: widget.chatId),
                  Expanded(
                    child: TextField(
                      controller: _text,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: _enterToSend
                          ? TextInputAction.send
                          : TextInputAction.newline,
                      onSubmitted: _enterToSend ? (_) => _send() : null,
                      decoration: const InputDecoration(
                        hintText: 'Сообщение',
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    tooltip: 'Отправить',
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
