import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/data/auth_service.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _bio = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _loggingOut = false;
  String? _error;
  String? _email;
  String? _avatarPath;
  bool _avatarBusy = false;
  final _imagePicker = ImagePicker();

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _name.dispose();
    _username.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = _client.auth.currentUser;
    _email = user?.email;
    if (user == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final row = await _client
          .from('profiles')
          .select('display_name, username, bio, avatar_url')
          .eq('id', user.id)
          .maybeSingle();
      if (row != null) {
        _name.text = (row['display_name'] as String?) ?? '';
        _username.text = (row['username'] as String?) ?? '';
        _bio.text = (row['bio'] as String?) ?? '';
        _avatarPath = row['avatar_url'] as String?;
      } else {
        _name.text = 'Пользователь';
      }
    } catch (error) {
      _error = 'Не удалось загрузить профиль: $error';
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? get _avatarUrl {
    final path = _avatarPath;
    if (path == null || path.isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) return path;
    return _client.storage.from('profile-avatars').getPublicUrl(path);
  }

  Future<void> _pickAvatar() async {
    if (_avatarBusy) return;
    try {
      final image = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 88,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (image == null) return;
      final file = File(image.path);
      if (await file.length() > 8 * 1024 * 1024) {
        if (mounted) setState(() => _error = 'Фото должно быть меньше 8 МБ.');
        return;
      }
      final user = _client.auth.currentUser;
      if (user == null) return;
      setState(() {
        _avatarBusy = true;
        _error = null;
      });
      final ext = image.path.split('.').last.toLowerCase();
      final safeExt = ext == 'png' || ext == 'webp' ? ext : 'jpg';
      final path = '${user.id}/avatar.$safeExt';
      await _client.storage.from('profile-avatars').upload(
        path,
        file,
        fileOptions: FileOptions(
          upsert: true,
          contentType: safeExt == 'png'
              ? 'image/png'
              : safeExt == 'webp'
                  ? 'image/webp'
                  : 'image/jpeg',
        ),
      );
      await _client.from('profiles').update({'avatar_url': path}).eq('id', user.id);
      if (mounted) setState(() => _avatarPath = path);
    } catch (error) {
      if (mounted) setState(() => _error = 'Не удалось обновить фото: $error');
    } finally {
      if (mounted) setState(() => _avatarBusy = false);
    }
  }

  Future<void> _save() async {
    final user = _client.auth.currentUser;
    final name = _name.text.trim();
    final username = _username.text.trim().toLowerCase();
    final bio = _bio.text.trim();

    if (user == null) return;
    if (name.length < 2 || name.length > 40) {
      setState(() => _error = 'Имя должно содержать от 2 до 40 символов.');
      return;
    }
    if (username.isNotEmpty &&
        !RegExp(r'^[a-z0-9_]{3,24}$').hasMatch(username)) {
      setState(() => _error =
          'Username: 3–24 символа, только латинские буквы, цифры и _.');
      return;
    }
    if (bio.length > 160) {
      setState(() => _error = 'Описание не должно превышать 160 символов.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _client.from('profiles').upsert({
        'id': user.id,
        'display_name': name,
        'username': username.isEmpty ? null : username,
        'bio': bio,
        'avatar_url': _avatarPath,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Профиль сохранён')),
      );
    } on PostgrestException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.code == '23505'
            ? 'Этот username уже занят. Выберите другой.'
            : 'Не удалось сохранить профиль: ${error.message}';
      });
    } catch (error) {
      if (mounted) setState(() => _error = 'Ошибка сохранения: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _logout() async {
    setState(() => _loggingOut = true);
    try {
      await AuthService(_client).signOut();
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        setState(() {
          _loggingOut = false;
          _error = 'Не удалось выйти: $error';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Мой профиль')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  Center(
                    child: InkWell(
                      onTap: _avatarBusy ? null : _pickAvatar,
                      customBorder: const CircleBorder(),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundImage: _avatarUrl == null
                                ? null
                                : NetworkImage(_avatarUrl!),
                            child: _avatarUrl == null
                                ? const Icon(Icons.person, size: 46)
                                : null,
                          ),
                          if (_avatarBusy)
                            const CircleAvatar(
                              radius: 48,
                              backgroundColor: Colors.black54,
                              child: CircularProgressIndicator(),
                            )
                          else
                            const Positioned(
                              right: 0,
                              bottom: 0,
                              child: CircleAvatar(
                                radius: 17,
                                child: Icon(Icons.camera_alt, size: 18),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Center(
                    child: Text(
                      'Нажмите на фото, чтобы изменить аватар',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      _email ?? 'Аккаунт Novagram',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 26),
                  TextField(
                    controller: _name,
                    maxLength: 40,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Отображаемое имя',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _username,
                    maxLength: 24,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      labelText: 'Username',
                      hintText: 'novagram_user',
                      prefixIcon: Icon(Icons.alternate_email),
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(left: 4, top: 2),
                    child: Text(
                      'Можно оставить пустым. Username должен быть уникальным.',
                      style: TextStyle(color: Colors.white54, fontSize: 12),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _bio,
                    maxLength: 160,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'О себе',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.notes),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      _error!,
                      style: const TextStyle(color: Color(0xFFFF8791)),
                    ),
                  ],
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: _saving
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: const Text('Сохранить профиль'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: _loggingOut ? null : _logout,
                    icon: const Icon(Icons.logout),
                    label: Text(
                      _loggingOut ? 'Выходим…' : 'Выйти из аккаунта',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
