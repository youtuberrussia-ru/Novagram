import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class BotsPage extends StatefulWidget {
  const BotsPage({super.key});

  @override
  State<BotsPage> createState() => _BotsPageState();
}

class _BotsPageState extends State<BotsPage> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _bots;

  @override
  void initState() {
    super.initState();
    _bots = _load();
  }

  Future<List<Map<String, dynamic>>> _load() async {
    final rows = await _client
        .from('bot_profiles')
        .select('id,owner_id,display_name,username,description,is_public')
        .eq('is_public', true)
        .order('created_at', ascending: false)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _refresh() async {
    final next = _load();
    setState(() => _bots = next);
    await next;
  }

  Future<void> _createBot() async {
    final name = TextEditingController();
    final username = TextEditingController();
    final description = TextEditingController();
    final key = GlobalKey<FormState>();
    try {
      final data = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Создать профиль бота'),
          content: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: name,
                    maxLength: 40,
                    decoration: const InputDecoration(labelText: 'Название'),
                    validator: (v) => (v?.trim().length ?? 0) < 2
                        ? 'Минимум 2 символа'
                        : null,
                  ),
                  TextFormField(
                    controller: username,
                    maxLength: 32,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      prefixText: '@',
                    ),
                    validator: (v) => RegExp(r'^[a-zA-Z0-9_]{4,32}$')
                            .hasMatch((v ?? '').trim())
                        ? null
                        : '4–32 символа: латиница, цифры, _',
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
                if (key.currentState!.validate()) {
                  Navigator.pop(dialogContext, {
                    'name': name.text.trim(),
                    'username': username.text.trim(),
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
      await _client.from('bot_profiles').insert({
        'owner_id': _client.auth.currentUser!.id,
        'display_name': data['name'],
        'username': data['username'],
        'description': data['description'],
        'is_public': true,
        'is_verified': false,
      });
      await _refresh();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось создать профиль бота: $error')),
        );
      }
    } finally {
      name.dispose();
      username.dispose();
      description.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Каталог ботов'),
          actions: [
            IconButton(
              tooltip: 'Добавить бота',
              onPressed: _createBot,
              icon: const Icon(Icons.add),
            ),
          ],
        ),
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Map<String, dynamic>>>(
            future: _bots,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Каталог пока недоступен')),
                ]);
              }
              final bots = snapshot.data ?? [];
              if (bots.isEmpty) {
                return ListView(children: const [
                  SizedBox(height: 130),
                  Icon(Icons.smart_toy_outlined,
                      size: 58, color: Colors.white38),
                  SizedBox(height: 12),
                  Center(child: Text('Публичных ботов пока нет')),
                  Center(child: Text('Добавьте профиль своего бота')),
                ]);
              }
              return ListView.separated(
                itemCount: bots.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final bot = bots[index];
                  return ListTile(
                    leading: const CircleAvatar(
                      child: Icon(Icons.smart_toy_outlined),
                    ),
                    title: Text(bot['display_name'] as String),
                    subtitle: Text('@${bot['username']}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BotDetailsPage(bot: bot),
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

class BotDetailsPage extends StatefulWidget {
  const BotDetailsPage({super.key, required this.bot});

  final Map<String, dynamic> bot;

  @override
  State<BotDetailsPage> createState() => _BotDetailsPageState();
}

class _BotDetailsPageState extends State<BotDetailsPage> {
  final _client = Supabase.instance.client;
  late Future<List<Map<String, dynamic>>> _commands;

  bool get _owner => widget.bot['owner_id'] == _client.auth.currentUser?.id;

  @override
  void initState() {
    super.initState();
    _commands = _loadCommands();
  }

  Future<List<Map<String, dynamic>>> _loadCommands() async {
    final rows = await _client
        .from('bot_commands')
        .select('id,command,description,response_text,is_enabled')
        .eq('bot_id', widget.bot['id'])
        .eq('is_enabled', true)
        .order('command');
    return List<Map<String, dynamic>>.from(rows);
  }

  Future<void> _runCommand(Map<String, dynamic> command) async {
    final response = (command['response_text'] as String? ?? '').trim();
    if (response.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('У команды пока нет ответа')),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(command['command'] as String? ?? 'Ответ бота'),
        content: SingleChildScrollView(
          child: SelectableText(response),
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

  Future<void> _addCommand() async {
    final command = TextEditingController(text: '/start');
    final description = TextEditingController();
    final response = TextEditingController();
    final key = GlobalKey<FormState>();
    try {
      final data = await showDialog<Map<String, String>>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Новая команда'),
          content: Form(
            key: key,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: command,
                    decoration: const InputDecoration(labelText: 'Команда'),
                    validator: (v) => RegExp(r'^/[a-z0-9_]{1,32}$')
                            .hasMatch((v ?? '').trim())
                        ? null
                        : 'Формат: /command',
                  ),
                  TextFormField(
                    controller: description,
                    maxLength: 120,
                    decoration: const InputDecoration(labelText: 'Описание'),
                  ),
                  TextFormField(
                    controller: response,
                    maxLength: 2000,
                    maxLines: 4,
                    decoration: const InputDecoration(labelText: 'Ответ бота'),
                    validator: (v) =>
                        (v?.trim().isNotEmpty ?? false) ? null : 'Введите ответ',
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
                if (key.currentState!.validate()) {
                  Navigator.pop(dialogContext, {
                    'command': command.text.trim(),
                    'description': description.text.trim(),
                    'response': response.text.trim(),
                  });
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      );
      if (data == null || !mounted) return;
      await _client.from('bot_commands').insert({
        'bot_id': widget.bot['id'],
        'command': data['command'],
        'description': data['description'],
        'response_text': data['response'],
      });
      setState(() => _commands = _loadCommands());
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Не удалось сохранить команду: $error')),
        );
      }
    } finally {
      command.dispose();
      description.dispose();
      response.dispose();
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: Text(widget.bot['display_name'] as String),
          actions: [
            if (_owner)
              IconButton(
                tooltip: 'Добавить команду',
                onPressed: _addCommand,
                icon: const Icon(Icons.add),
              ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 32,
                    child: Icon(Icons.smart_toy_outlined, size: 32),
                  ),
                  const SizedBox(height: 10),
                  Text('@${widget.bot['username']}'),
                  const SizedBox(height: 8),
                  Text(widget.bot['description'] as String? ?? ''),
                  const SizedBox(height: 8),
                  const Text(
                    'Это каталог команд. Выполнение произвольного кода и выдача API-токенов пока не подключены.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _commands,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return const Center(child: Text('Не удалось загрузить команды'));
                  }
                  final commands = snapshot.data ?? [];
                  if (commands.isEmpty) {
                    return const Center(child: Text('Команд пока нет'));
                  }
                  return ListView.builder(
                    itemCount: commands.length,
                    itemBuilder: (context, index) {
                      final item = commands[index];
                      return ListTile(
                        leading: const Icon(Icons.terminal),
                        title: Text(item['command'] as String),
                        subtitle: Text(
                          (item['description'] as String? ?? '').isEmpty
                              ? item['response_text'] as String? ?? ''
                              : item['description'] as String,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: IconButton(
                          tooltip: 'Проверить ответ',
                          onPressed: () => _runCommand(item),
                          icon: const Icon(Icons.play_arrow_rounded),
                        ),
                        onTap: () => _runCommand(item),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      );
}
