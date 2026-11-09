import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class ChatMediaComposer extends StatefulWidget {
  const ChatMediaComposer({required this.chatId, super.key});

  final String chatId;

  @override
  State<ChatMediaComposer> createState() => _ChatMediaComposerState();
}

class _ChatMediaComposerState extends State<ChatMediaComposer> {
  final _recorder = AudioRecorder();
  final _picker = ImagePicker();
  bool _recording = false;
  bool _busy = false;
  DateTime? _recordStarted;

  SupabaseClient get _client => Supabase.instance.client;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _startVoice() async {
    try {
      if (!await _recorder.hasPermission()) {
        _show('Разрешите доступ к микрофону');
        return;
      }
      final directory = await getTemporaryDirectory();
      final path =
          '${directory.path}/novagram_voice_${DateTime.now().millisecondsSinceEpoch}.m4a';
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 96000),
        path: path,
      );
      if (!mounted) return;
      setState(() {
        _recording = true;
        _recordStarted = DateTime.now();
      });
    } catch (error) {
      _show('Не удалось начать запись: $error');
    }
  }

  Future<void> _stopVoice() async {
    if (!_recording || _busy) return;
    setState(() {
      _recording = false;
      _busy = true;
    });
    try {
      final path = await _recorder.stop();
      if (path == null) return;
      final duration = _recordStarted == null
          ? 0
          : DateTime.now().difference(_recordStarted!).inMilliseconds;
      if (duration < 700) {
        _show('Запись слишком короткая');
        return;
      }
      await _uploadAndSend(
        File(path),
        type: 'voice',
        body: 'Голосовое сообщение',
        contentType: 'audio/mp4',
        extension: 'm4a',
        durationMs: duration,
      );
    } catch (error) {
      _show('Не удалось отправить голосовое: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickPhoto() async {
    if (_busy || _recording) return;
    try {
      final photo = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );
      if (photo == null) return;
      final file = File(photo.path);
      if (await file.length() > 15 * 1024 * 1024) {
        _show('Фото превышает лимит 15 МБ');
        return;
      }
      final extension = photo.path.split('.').last.toLowerCase();
      final mime = switch (extension) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' || 'heif' => 'image/heic',
        _ => 'image/jpeg',
      };
      setState(() => _busy = true);
      await _uploadAndSend(
        file,
        type: 'image',
        body: 'Фотография',
        contentType: mime,
        extension: extension == 'png' || extension == 'webp' ||
                extension == 'heic' || extension == 'heif'
            ? extension
            : 'jpg',
      );
    } catch (error) {
      _show('Не удалось отправить фото: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _recordCircle() async {
    if (_busy || _recording) return;
    try {
      final video = await _picker.pickVideo(
        source: ImageSource.camera,
        maxDuration: const Duration(seconds: 60),
        preferredCameraDevice: CameraDevice.front,
      );
      if (video == null) return;
      final file = File(video.path);
      final length = await file.length();
      if (length > 50 * 1024 * 1024) {
        _show('Видео превышает лимит 50 МБ');
        return;
      }
      setState(() => _busy = true);
      await _uploadAndSend(
        file,
        type: 'video_circle',
        body: 'Видеокружок',
        contentType: 'video/mp4',
        extension: 'mp4',
      );
    } catch (error) {
      _show('Не удалось записать кружок: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _uploadAndSend(
    File file, {
    required String type,
    required String body,
    required String contentType,
    required String extension,
    int? durationMs,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw Exception('Сначала войдите в аккаунт');
    final filename =
        '${DateTime.now().microsecondsSinceEpoch}.$extension';
    final objectPath = '${widget.chatId}/${user.id}/$filename';
    await _client.storage.from('chat-media').upload(
          objectPath,
          file,
          fileOptions: FileOptions(
            contentType: contentType,
            upsert: false,
          ),
        );
    try {
      await _client.from('messages').insert({
        'chat_id': widget.chatId,
        'sender_id': user.id,
        'body': body,
        'message_type': type,
        'media_path': objectPath,
        if (durationMs != null) 'media_duration_ms': durationMs,
      });
    } catch (_) {
      await _client.storage.from('chat-media').remove([objectPath]);
      rethrow;
    }
  }

  void _show(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Отправить фото',
          onPressed: _busy || _recording ? null : _pickPhoto,
          icon: const Icon(Icons.photo_outlined),
        ),
        IconButton(
          tooltip: _recording ? 'Остановить и отправить' : 'Записать голосовое',
          onPressed: _busy
              ? null
              : (_recording ? _stopVoice : _startVoice),
          color: _recording ? Colors.redAccent : null,
          icon: Icon(_recording ? Icons.stop_circle : Icons.mic_none),
        ),
        IconButton(
          tooltip: 'Записать видеокружок',
          onPressed: _busy || _recording ? null : _recordCircle,
          icon: const Icon(Icons.video_camera_front_outlined),
        ),
        if (_busy)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
      ],
    );
  }
}

class ChatMediaBubble extends StatefulWidget {
  const ChatMediaBubble({
    required this.path,
    required this.type,
    super.key,
  });

  final String path;
  final String type;

  @override
  State<ChatMediaBubble> createState() => _ChatMediaBubbleState();
}

class _ChatMediaBubbleState extends State<ChatMediaBubble> {
  late Future<String> _url;

  @override
  void initState() {
    super.initState();
    _url = _signedUrl();
  }

  Future<String> _signedUrl() => Supabase.instance.client.storage
      .from('chat-media')
      .createSignedUrl(widget.path, 3600);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _url,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Text('Не удалось загрузить медиа');
        }
        if (!snapshot.hasData) {
          return const SizedBox(
            width: 180,
            height: 54,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        if (widget.type == 'voice') {
          return _VoicePlayer(url: snapshot.data!);
        }
        if (widget.type == 'image') {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.network(
              snapshot.data!,
              width: 220,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : const SizedBox(
                      width: 220,
                      height: 160,
                      child: Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, error, stack) =>
                  const SizedBox(width: 220, child: Text('Фото недоступно')),
            ),
          );
        }
        return _CirclePlayer(url: snapshot.data!);
      },
    );
  }
}

class _VoicePlayer extends StatefulWidget {
  const _VoicePlayer({required this.url});
  final String url;

  @override
  State<_VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends State<_VoicePlayer> {
  final _player = AudioPlayer();
  bool _ready = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _prepare();
  }

  Future<void> _prepare() async {
    try {
      await _player.setUrl(widget.url);
      if (mounted) setState(() => _ready = true);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 210,
        child: Row(
          children: [
            IconButton(
              onPressed: !_ready || _failed
                  ? null
                  : () => _player.playing ? _player.pause() : _player.play(),
              icon: StreamBuilder<PlayerState>(
                stream: _player.playerStateStream,
                builder: (context, snapshot) => Icon(
                  snapshot.data?.playing == true
                      ? Icons.pause_circle_filled
                      : Icons.play_circle_fill,
                  size: 34,
                ),
              ),
            ),
            Expanded(
              child: _failed
                  ? const Text('Аудио недоступно')
                  : StreamBuilder<Duration>(
                      stream: _player.positionStream,
                      builder: (context, snapshot) {
                        final duration = _player.duration ?? Duration.zero;
                        final position = snapshot.data ?? Duration.zero;
                        final value = duration.inMilliseconds == 0
                            ? 0.0
                            : (position.inMilliseconds /
                                    duration.inMilliseconds)
                                .clamp(0.0, 1.0).toDouble();
                        return Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Slider(
                              value: value,
                              onChanged: !_ready
                                  ? null
                                  : (v) => _player.seek(Duration(
                                        milliseconds:
                                            (duration.inMilliseconds * v)
                                                .round(),
                                      )),
                            ),
                            Text(
                              '${position.inSeconds ~/ 60}:${(position.inSeconds % 60).toString().padLeft(2, '0')}',
                              style: const TextStyle(fontSize: 11),
                            ),
                          ],
                        );
                      },
                    ),
            ),
          ],
        ),
      );
}

class _CirclePlayer extends StatefulWidget {
  const _CirclePlayer({required this.url});
  final String url;

  @override
  State<_CirclePlayer> createState() => _CirclePlayerState();
}

class _CirclePlayerState extends State<_CirclePlayer> {
  late final VideoPlayerController _controller;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() => _ready = true);
      }).catchError((_) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: !_ready
          ? null
          : () {
              setState(() {
                _controller.value.isPlaying
                    ? _controller.pause()
                    : _controller.play();
              });
            },
      child: ClipOval(
        child: Container(
          width: 190,
          height: 190,
          color: Colors.black26,
          child: !_ready
              ? const Center(child: CircularProgressIndicator())
              : Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox.expand(
                      child: FittedBox(
                        fit: BoxFit.cover,
                        child: SizedBox(
                          width: _controller.value.size.width,
                          height: _controller.value.size.height,
                          child: VideoPlayer(_controller),
                        ),
                      ),
                    ),
                    if (!_controller.value.isPlaying)
                      const Icon(Icons.play_circle_fill,
                          size: 52, color: Colors.white),
                  ],
                ),
        ),
      ),
    );
  }
}
