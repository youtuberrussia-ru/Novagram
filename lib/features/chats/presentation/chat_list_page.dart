import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/presentation/profile_page.dart';
import '../data/chat_repository.dart';
import '../domain/chat.dart';
import 'chat_page.dart';

class ChatListPage extends StatefulWidget {
  const ChatListPage({super.key});

  @override
  State<ChatListPage> createState() => _ChatListPageState();
}

class _ChatListPageState extends State<ChatListPage> {
  late final ChatRepository _repo;
  late Future<List<Chat>> _chats;

  @override
  void initState() {
    super.initState();
    _repo = ChatRepository(Supabase.instance.client);
    _chats = _repo.getMyChats();
  }

  Future<void> _refresh() async {
    final request = _repo.getMyChats();
    setState(() => _chats = request);
    await request;
  }

  Future<void> _searchUsers() async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Найти пользователя'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Имя или username'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              final navigator = Navigator.of(dialogContext);
              try {
                final users = await _repo.searchUsers(controller.text);
                if (!mounted) return;
                navigator.pop();
                if (users.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Пользователи не найдены')),
                  );
                  return;
                }
                await showModalBottomSheet<void>(
                  context: context,
                  builder: (sheetContext) => SafeArea(
                    child: ListView(
                      shrinkWrap: true,
                      children: users.map((user) {
                        final name =
                            (user['display_name'] as String?) ?? 'Пользователь';
                        return ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(name),
                          subtitle: Text((user['username'] as String?) ?? ''),
                          onTap: () async {
                            Navigator.pop(sheetContext);
                            try {
                              final id = await _repo.createDirectChat(
                                user['id'] as String,
                              );
                              await _refresh();
                              if (!mounted) return;
                              await Navigator.push<void>(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => ChatPage(
                                    chatId: id,
                                    title: name,
                                  ),
                                ),
                              );
                            } catch (error) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    'Не удалось создать чат: $error',
                                  ),
                                ),
                              );
                            }
                          },
                        );
                      }).toList(),
                    ),
                  ),
                );
              } catch (error) {
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Ошибка поиска: $error')),
                );
              }
            },
            child: const Text('Найти'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Novagram',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Найти людей',
            onPressed: _searchUsers,
            icon: const Icon(Icons.person_add_alt_1),
          ),
          IconButton(
            tooltip: 'Профиль',
            onPressed: () => Navigator.push<void>(
              context,
              MaterialPageRoute(builder: (_) => const ProfilePage()),
            ),
            icon: const Icon(Icons.account_circle_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _searchUsers,
        child: const Icon(Icons.edit),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<Chat>>(
          future: _chats,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                children: [
                  const SizedBox(height: 180),
                  Center(
                    child: Text(
                      'Ошибка загрузки чатов\n${snapshot.error}',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  TextButton(
                    onPressed: _refresh,
                    child: const Text('Повторить'),
                  ),
                ],
              );
            }
            final chats = snapshot.data ?? [];
            if (chats.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 150),
                  Icon(
                    Icons.forum_outlined,
                    size: 56,
                    color: Colors.white38,
                  ),
                  SizedBox(height: 16),
                  Center(child: Text('Пока нет чатов')),
                  Center(
                    child: Text(
                      'Нажмите ✎, чтобы найти собеседника',
                      style: TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      chat.isGroup ? Icons.groups : Icons.person,
                    ),
                  ),
                  title: Text(chat.title),
                  subtitle: Text(chat.isGroup ? 'Группа' : 'Личный чат'),
                  onTap: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(
                        chatId: chat.id,
                        title: chat.title,
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
