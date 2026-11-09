import 'package:flutter/material.dart';
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

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _myId = _client.auth.currentUser!.id;
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

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    if (body.length > 10000) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Сообщение слишком длинное')),
      );
      return;
    }

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
    final confirmed = await showDialog<bool>(
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
    );
    if (confirmed != true || !mounted) return;
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
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.fromLTRB(14, 10, 12, 7),
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
            const SizedBox(height: 3),
            Text(
              timeLabel,
              style: const TextStyle(color: Colors.white60, fontSize: 10),
            ),
          ],
        ),
      ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
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
                      textInputAction: TextInputAction.newline,
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
