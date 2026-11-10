import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ChannelsPage extends StatefulWidget {
  const ChannelsPage({super.key});

  @override
  State<ChannelsPage> createState() => _ChannelsPageState();
}

class _ChannelsPageState extends State<ChannelsPage> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _channels;

  @override
  void initState() {
    super.initState();
    _channels = _loadChannels();
  }

  Future<List<Map<String, dynamic>>> _loadChannels() async {
    final rows = await _client
        .from('channels')
        .select('id,title,username,description,owner_id,created_at')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    final next = _loadChannels();
    setState(() => _channels = next);
    await next;
  }

  Future<void> _createChannel() async {
    final title = TextEditingController();
    final username = TextEditingController();
    final description = TextEditingController();
    final formKey = GlobalKey<FormState>();
    try {
      final data = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Создать канал'),
          content: Form(
            key: formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: title,
                    maxLength: 60,
                    decoration: const InputDecoration(labelText: 'Название'),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Минимум 2 символа'
                        : null,
                  ),
                  TextFormField(
                    controller: username,
                    maxLength: 32,
                    decoration: const InputDecoration(
                      labelText: 'Ссылка (username)',
                      prefixText: '@',
                    ),
                    validator: (v) {
                      final value = (v ?? '').trim().toLowerCase();
                      if (value.isEmpty) return null;
                      if (!RegExp(r'^[a-z0-9_]{4,32}$').hasMatch(value)) {
                        return '4–32: латиница, цифры и _';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: description,
                    maxLength: 500,
                    maxLines: 3,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Отмена'),
            ),
            FilledButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  Navigator.pop(dialogContext, {
                    'title': title.text.trim(),
                    'username': username.text.trim().toLowerCase(),
                    'description': description.text.trim(),
                  });
                }
              },
              child: const Text('Создать'),
            ),
          ],
        ),
      );
      if (data == null || !mounted) return;
      final user = _client.auth.currentUser;
      if (user == null) throw Exception('Сначала войдите в аккаунт');
      final row = await _client.from('channels').insert({
        'owner_id': user.id,
        'title': data['title'],
        'username': (data['username'] ?? '').isEmpty ? null : data['username'],
        'description': data['description'],
        'is_public': true,
      }).select('id,title,username,description,owner_id').single();
      await _refresh();
      if (!mounted) return;
      await Navigator.push<void>(
        context,
        MaterialPageRoute(builder: (_) => ChannelDetailPage(channel: row)),
      );
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать канал: $error')),
        );
      }
    } finally {
      title.dispose();
      username.dispose();
      description.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Каналы'),
          actions: [
            IconButton(
              tooltip: 'Создать канал',
              onPressed: _createChannel,
              icon: const Icon(Icons.add_circle_outline),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _channels,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(children: [
                  const SizedBox(height: 120),
                  const Center(child: Text('Не удалось загрузить каналы')),
                  Center(
                    child: TextButton(
                      onPressed: _refresh,
                      child: const Text('Повторить'),
                    ),
                  ),
                ]);
              }
              final channels = snapshot.data ?? [];
              if (channels.isEmpty) {
                return ListView(children: const [
                  SizedBox(height: 130),
                  Icon(Icons.campaign_outlined, size: 58, color: Colors.white38),
                  SizedBox(height: 12),
                  Center(child: Text('Пока нет публичных каналов')),
                  Center(child: Text('Создайте первый канал')),
                ]);
              }
              return ListView.separated(
                itemCount: channels.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final channel = channels[index];
                  final username = channel['username'] as String?;
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.campaign_outlined),
                    ),
                    title: Text(channel['title'] as String? ?? 'Канал'),
                    subtitle: Text(
                      username == null || username.isEmpty
                          ? (channel['description'] as String? ?? 'Публичный канал')
                          : '@$username',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      await Navigator.push<void>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ChannelDetailPage(channel: channel),
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
      );
}

class ChannelDetailPage extends StatefulWidget {
  const ChannelDetailPage({super.key, required this.channel});

  final Map<String, dynamic> channel;

  @override
  State<ChannelDetailPage> createState() => _ChannelDetailPageState();
}

class _ChannelDetailPageState extends State<ChannelDetailPage> {
  final _client = Supabase.instance.client;
  final _postController = TextEditingController();
  late Future<List<Map<String, dynamic>>> _posts;
  bool _member = false;
  bool _busy = false;

  String get _channelId => widget.channel['id'] as String;
  bool get _isOwner =>
      widget.channel['owner_id'] == _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _posts = _loadPosts();
    _loadMembership();
  }

  Future<List<Map<String, dynamic>>> _loadPosts() async {
    final rows = await _client
        .from('channel_posts')
        .select('id,body,author_id,created_at')
        .eq('channel_id', _channelId)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _loadMembership() async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    try {
      final row = await _client
          .from('channel_members')
          .select('user_id')
          .eq('channel_id', _channelId)
          .eq('user_id', user.id)
          .maybeSingle();
      if (mounted) setState(() => _member = row != null);
    } catch (_) {}
  }

  Future<void> _refresh() async {
    final next = _loadPosts();
    setState(() => _posts = next);
    await next;
  }

  Future<void> _joinOrLeave() async {
    setState(() => _busy = true);
    try {
      if (_member) {
        await _client.rpc('leave_channel', params: {'p_channel_id': _channelId});
      } else {
        await _client.rpc('join_public_channel',
            params: {'p_channel_id': _channelId});
      }
      await _loadMembership();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_member ? 'Вы подписались' : 'Вы вышли из канала')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось изменить подписку: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editChannel() async {
    final title = TextEditingController(text: widget.channel['title'] as String? ?? '');
    final username = TextEditingController(text: widget.channel['username'] as String? ?? '');
    final description = TextEditingController(text: widget.channel['description'] as String? ?? '');
    try {
      final data = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Настройки канала'),
          content: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextField(controller: title, maxLength: 60, decoration: const InputDecoration(labelText: 'Название')),
              TextField(controller: username, maxLength: 32, decoration: const InputDecoration(labelText: 'Username без @')),
              TextField(controller: description, maxLength: 500, maxLines: 3, decoration: const InputDecoration(labelText: 'Описание')),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Отмена')),
            FilledButton(
              onPressed: () {
                final normalized = username.text.trim().replaceFirst(RegExp(r'^@'), '').toLowerCase();
                final validChars = normalized.codeUnits.every((c) =>
                    (c >= 97 && c <= 122) || (c >= 48 && c <= 57) || c == 95);
                final validUsername = normalized.isEmpty ||
                    (normalized.length >= 4 && normalized.length <= 32 && validChars);
                if (title.text.trim().length >= 2 && validUsername) {
                  Navigator.pop(dialogContext, {
                    'title': title.text.trim(),
                    'username': normalized,
                    'description': description.text.trim(),
                  });
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (data == null || !mounted) return;
      setState(() => _busy = true);
      await _client.from('channels').update({
        'title': data['title'],
        'username': data['username']!.isEmpty ? null : data['username'],
        'description': data['description'],
      }).eq('id', _channelId);
      if (!mounted) return;
      setState(() {
        widget.channel['title'] = data['title'];
        widget.channel['username'] = data['username']!.isEmpty ? null : data['username'];
        widget.channel['description'] = data['description'];
      });
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Канал обновлён')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось изменить канал: ' + error.toString())));
    } finally {
      title.dispose();
      username.dispose();
      description.dispose();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteChannel() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Удалить канал?'),
        content: const Text('Канал, публикации и подписки будут удалены без возможности восстановления.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await _client.from('channels').delete().eq('id', _channelId);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось удалить канал: ' + error.toString())));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _publish() async {
    final body = _postController.text.trim();
    if (body.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await _client.from('channel_posts').insert({
        'channel_id': _channelId,
        'author_id': _client.auth.currentUser!.id,
        'body': body,
      });
      _postController.clear();
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось опубликовать: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = widget.channel['username'] as String?;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.channel['title'] as String? ?? 'Канал'),
        actions: [
          if (_isOwner)
            PopupMenuButton<String>(
              enabled: !_busy,
              tooltip: 'Управление каналом',
              onSelected: (value) {
                if (value == 'edit') _editChannel();
                if (value == 'delete') _deleteChannel();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Изменить канал')),
                PopupMenuItem(value: 'delete', child: Text('Удалить канал')),
              ],
            ),
          if (!_isOwner)
            TextButton(
              onPressed: _busy ? null : _joinOrLeave,
              child: Text(_member ? 'Выйти' : 'Подписаться'),
            ),
        ],
      ),
      body: Column(
        children: [
          if ((widget.channel['description'] as String? ?? '').isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(widget.channel['description'] as String),
            ),
          if (username != null && username.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text('@$username',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary)),
            ),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refresh,
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _posts,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return ListView(children: const [
                      SizedBox(height: 100),
                      Center(child: Text('Не удалось загрузить публикации')),
                    ]);
                  }
                  final posts = snapshot.data ?? [];
                  if (posts.isEmpty) {
                    return ListView(children: const [
                      SizedBox(height: 100),
                      Center(child: Text('Публикаций пока нет')),
                    ]);
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.all(12),
                    itemCount: posts.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final post = posts[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(post['body'] as String),
                              const SizedBox(height: 8),
                              Text(
                                (post['created_at'] as String?) ?? '',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
          if (_isOwner)
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _postController,
                        maxLength: 10000,
                        minLines: 1,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Новая публикация',
                          counterText: '',
                        ),
                      ),
                    ),
                    IconButton.filled(
                      onPressed: _busy ? null : _publish,
                      icon: const Icon(Icons.send),
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
