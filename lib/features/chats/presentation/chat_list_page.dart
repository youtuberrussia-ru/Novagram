import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../profile/presentation/profile_page.dart';
import '../../admin/presentation/admin_page.dart';
import '../../../core/widgets/novagram_logo.dart';
import '../../channels/presentation/channels_page.dart';
import '../../bots/presentation/bots_page.dart';
import '../../settings/presentation/settings_page.dart';
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
  String _chatQuery = '';

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
    final users = await showDialog<List<Map<String, dynamic>>>(
      context: context,
      builder: (_) => _UserSearchDialog(onSearch: _repo.searchUsers),
    );
    if (!mounted || users == null) return;
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
            final name = (user['display_name'] as String?) ?? 'Пользователь';
            final username = (user['username'] as String?) ?? '';
            final avatarPath = user['avatar_url'] as String?;
            final avatar = avatarPath == null || avatarPath.isEmpty
                ? null
                : (avatarPath.startsWith('http://') || avatarPath.startsWith('https://')
                    ? avatarPath
                    : Supabase.instance.client.storage
                        .from('profile-avatars')
                        .getPublicUrl(avatarPath));
            return ListTile(
              leading: CircleAvatar(
                backgroundImage: avatar == null || avatar.isEmpty
                    ? null
                    : NetworkImage(avatar),
                child: avatar == null || avatar.isEmpty
                    ? const Icon(Icons.person)
                    : null,
              ),
              title: Text(name),
              subtitle: Text(username.isEmpty ? '' : '@$username'),
              onTap: () async {
                Navigator.pop(sheetContext);
                try {
                  final id = await _repo.createDirectChat(user['id'] as String);
                  await _refresh();
                  if (!mounted) return;
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ChatPage(chatId: id, title: name),
                    ),
                  );
                  if (mounted) await _refresh();
                } catch (error) {
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Не удалось создать чат: $error')),
                  );
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  Future<void> _createGroupChat() async {
    final titleController = TextEditingController();
    final queryController = TextEditingController();
    final selectedUsers = <String>{};
    List<Map<String, dynamic>> foundUsers = [];
    var searching = false;
    var creating = false;
    String? dialogError;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (_, setDialogState) {
          Future<void> searchMembers() async {
            final query = queryController.text.trim();
            if (query.length < 2) {
              setDialogState(() {
                dialogError = 'Введите минимум 2 символа для поиска.';
              });
              return;
            }
            setDialogState(() {
              searching = true;
              dialogError = null;
            });
            try {
              final users = await _repo.searchUsers(query);
              if (!dialogContext.mounted) return;
              setDialogState(() => foundUsers = users);
            } catch (error) {
              if (dialogContext.mounted) {
                setDialogState(() => dialogError = 'Ошибка поиска: $error');
              }
            } finally {
              if (dialogContext.mounted) {
                setDialogState(() => searching = false);
              }
            }
          }

          return AlertDialog(
            title: const Text('Новая группа'),
            content: SizedBox(
              width: 380,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: titleController,
                      maxLength: 50,
                      decoration: const InputDecoration(
                        labelText: 'Название группы',
                        hintText: 'Например, Друзья',
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: queryController,
                            decoration: const InputDecoration(
                              labelText: 'Найти участников',
                              hintText: 'Имя или username',
                            ),
                            onSubmitted: (_) => searchMembers(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filled(
                          tooltip: 'Поиск',
                          onPressed: searching ? null : searchMembers,
                          icon: searching
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.search),
                        ),
                      ],
                    ),
                    if (selectedUsers.isNotEmpty) ...[
                      const SizedBox(height: 10),
                      Text('Выбрано участников: ${selectedUsers.length}'),
                    ],
                    if (foundUsers.isNotEmpty)
                      SizedBox(
                        height: 220,
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: foundUsers.length,
                          itemBuilder: (context, index) {
                            final user = foundUsers[index];
                            final id = user['id'] as String;
                            final name = (user['display_name'] as String?) ??
                                'Пользователь';
                            final username =
                                (user['username'] as String?) ?? '';
                            return CheckboxListTile(
                              dense: true,
                              value: selectedUsers.contains(id),
                              controlAffinity:
                                  ListTileControlAffinity.leading,
                              title: Text(name),
                              subtitle: username.isEmpty
                                  ? null
                                  : Text('@$username'),
                              onChanged: (checked) {
                                setDialogState(() {
                                  if (checked == true) {
                                    selectedUsers.add(id);
                                  } else {
                                    selectedUsers.remove(id);
                                  }
                                });
                              },
                            );
                          },
                        ),
                      )
                    else
                      const Padding(
                        padding: EdgeInsets.only(top: 14),
                        child: Text(
                          'Найдите людей и отметьте тех, кого хотите добавить.',
                          style: TextStyle(color: Colors.white54),
                        ),
                      ),
                    if (dialogError != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        dialogError!,
                        style: const TextStyle(color: Color(0xFFFF8791)),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: creating
                    ? null
                    : () => Navigator.pop(dialogContext),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: creating
                    ? null
                    : () async {
                        final title = titleController.text.trim();
                        if (title.length < 2 || title.length > 50) {
                          setDialogState(() {
                            dialogError =
                                'Название должно содержать от 2 до 50 символов.';
                          });
                          return;
                        }
                        if (selectedUsers.isEmpty) {
                          setDialogState(() {
                            dialogError = 'Добавьте хотя бы одного участника.';
                          });
                          return;
                        }
                        setDialogState(() {
                          creating = true;
                          dialogError = null;
                        });
                        try {
                          final id = await _repo.createGroupChat(
                            title: title,
                            userIds: selectedUsers.toList(),
                          );
                          if (!mounted || !dialogContext.mounted) return;
                          Navigator.pop(dialogContext);
                          await _refresh();
                          if (!mounted) return;
                          await Navigator.push<void>(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ChatPage(chatId: id, title: title),
                            ),
                          );
                          if (mounted) await _refresh();
                        } catch (error) {
                          if (dialogContext.mounted) {
                            setDialogState(() {
                              dialogError =
                                  'Не удалось создать группу: $error';
                              creating = false;
                            });
                          }
                        }
                      },
                child: creating
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Создать'),
              ),
            ],
          );
        },
      ),
    );

    titleController.dispose();
    queryController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const NovagramLogo(showWordmark: true, size: 34),
        actions: [
          IconButton(
            tooltip: 'Найти пользователя',
            onPressed: _searchUsers,
            icon: const Icon(Icons.search_rounded),
          ),
          PopupMenuButton<String>(
            tooltip: 'Дополнительно',
            onSelected: (value) {
              switch (value) {
                case 'group':
                  _createGroupChat();
                  break;
                case 'channels':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const ChannelsPage()),
                  );
                  break;
                case 'bots':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const BotsPage()),
                  );
                  break;
                case 'profile':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                  break;
                case 'settings':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const SettingsPage()),
                  );
                  break;
                case 'admin':
                  Navigator.push<void>(
                    context,
                    MaterialPageRoute(builder: (_) => const AdminPage()),
                  );
                  break;
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'group', child: ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.group_add_outlined), title: Text('Новая группа'))),
              PopupMenuItem(value: 'channels', child: ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.campaign_outlined), title: Text('Каналы'))),
              PopupMenuItem(value: 'bots', child: ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.smart_toy_outlined), title: Text('Боты'))),
              PopupMenuDivider(),
              PopupMenuItem(value: 'profile', child: ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.account_circle_outlined), title: Text('Профиль'))),
              PopupMenuItem(value: 'settings', child: ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.settings_outlined), title: Text('Настройки'))),
              PopupMenuDivider(),
              PopupMenuItem(value: 'admin', child: ListTile(
                dense: true, contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.admin_panel_settings_outlined), title: Text('Панель управления'))),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _searchUsers,
        child: const Icon(Icons.edit),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: TextField(
              onChanged: (value) => setState(() => _chatQuery = value.trim().toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Поиск по чатам',
                prefixIcon: Icon(Icons.search_rounded),
                isDense: true,
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
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
            final allChats = snapshot.data ?? [];
            final chats = allChats.where((chat) => chat.title.toLowerCase().contains(_chatQuery) || (chat.lastMessage ?? '').toLowerCase().contains(_chatQuery)).toList();
            if (chats.isEmpty) {
              return ListView(
                children: [
                  SizedBox(height: 150),
                  Icon(
                    Icons.forum_outlined,
                    size: 56,
                    color: Colors.white38,
                  ),
                  SizedBox(height: 16),
                  Center(child: Text(allChats.isEmpty ? 'Пока нет чатов' : 'Ничего не найдено')),
                  Center(
                    child: Text(
                      allChats.isEmpty ? 'Нажмите ✎, чтобы найти собеседника' : 'Измените запрос поиска',
                      style: const TextStyle(color: Colors.white54),
                    ),
                  ),
                ],
              );
            }
            return ListView.separated(
              itemCount: chats.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 66, endIndent: 12),
              itemBuilder: (context, index) {
                final chat = chats[index];
                return ListTile(
                  dense: true,
                  visualDensity: const VisualDensity(horizontal: 0, vertical: -2),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 1),
                  minLeadingWidth: 48,
                  leading: CircleAvatar(
                    radius: 25,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      chat.isGroup ? Icons.groups : Icons.person,
                    ),
                  ),
                  title: Text(
                    chat.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    chat.lastMessage?.isNotEmpty == true
                        ? chat.lastMessage!
                        : (chat.isGroup ? 'Группа' : 'Личный чат'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12.5, color: Colors.white60),
                  ),
                  onTap: () async {
                    await Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          chatId: chat.id,
                          title: chat.title,
                        ),
                      ),
                    );
                    if (mounted) await _refresh();
                  },
                );
              },
            );
          },
              ),
            ),
          ),
        ],
      ),
    );
  }
}


class _UserSearchDialog extends StatefulWidget {
  const _UserSearchDialog({required this.onSearch});

  final Future<List<Map<String, dynamic>>> Function(String query) onSearch;

  @override
  State<_UserSearchDialog> createState() => _UserSearchDialogState();
}

class _UserSearchDialogState extends State<_UserSearchDialog> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final query = _controller.text.trim();
    if (query.length < 2) {
      setState(() => _error = 'Введите минимум 2 символа.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await widget.onSearch(query);
      if (mounted) Navigator.of(context).pop(users);
    } catch (error) {
      if (mounted) setState(() => _error = 'Ошибка поиска: $error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: const Text('Найти пользователя'),
        content: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            hintText: 'Имя или username',
            errorText: _error,
          ),
        ),
        actions: [
          TextButton(
            onPressed: _loading ? null : () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: _loading ? null : _search,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Найти'),
          ),
        ],
      );
}
