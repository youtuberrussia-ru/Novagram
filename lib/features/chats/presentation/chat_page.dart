import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({required this.chatId, required this.title, super.key});
  final String chatId, title;
  @override
  State<ChatPage> createState() => _ChatPageState();
}
class _ChatPageState extends State<ChatPage> {
  final _text = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;
  late final String _myId;
  @override
  void initState() { super.initState(); _myId = Supabase.instance.client.auth.currentUser!.id; }
  @override
  void dispose() { _text.dispose(); _scroll.dispose(); super.dispose(); }
  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await Supabase.instance.client.from('messages').insert({'chat_id': widget.chatId, 'sender_id': _myId, 'body': body});
      _text.clear();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось отправить сообщение: $e')));
    } finally { if (mounted) setState(() => _sending = false); }
  }
  @override
  Widget build(BuildContext context) {
    final stream = Supabase.instance.client.from('messages').stream(primaryKey: ['id']).eq('chat_id', widget.chatId).order('created_at');
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Column(children: [
        Expanded(child: StreamBuilder<List<Map<String, dynamic>>>(
          stream: stream, builder: (context, snapshot) {
            if (snapshot.hasError) return Center(child: Text('Ошибка загрузки: ${snapshot.error}'));
            if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
            final messages = snapshot.data!;
            if (messages.isEmpty) return const Center(child: Text('Начните общение'));
            return ListView.builder(controller: _scroll, padding: const EdgeInsets.all(12), itemCount: messages.length, itemBuilder: (context, i) {
              final message = messages[i]; final mine = message['sender_id'] == _myId;
              return Align(alignment: mine ? Alignment.centerRight : Alignment.centerLeft, child: Container(
                constraints: const BoxConstraints(maxWidth: 300), margin: const EdgeInsets.symmetric(vertical: 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(color: mine ? const Color(0xFF5146A8) : const Color(0xFF202640), borderRadius: BorderRadius.circular(16)),
                child: Text(message['body'] as String),
              ));
            });
          },
        )),
        SafeArea(top: false, child: Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 12), child: Row(children: [
          Expanded(child: TextField(controller: _text, minLines: 1, maxLines: 5, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(hintText: 'Сообщение', contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12)))),
          const SizedBox(width: 8),
          IconButton.filled(onPressed: _sending ? null : _send, icon: _sending ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.send)),
        ]))),
      ]),
    );
  }
}