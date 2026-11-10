import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminPage extends StatefulWidget {
  const AdminPage({super.key});
  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;
  SupabaseClient get _client => Supabase.instance.client;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _client.rpc('novagram_admin_dashboard');
      if (mounted) setState(() => _data = Map<String, dynamic>.from(result as Map));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally { if (mounted) setState(() => _loading = false); }
  }

  int _count(String key) => (_data?[key] as num?)?.toInt() ?? 0;

  Future<void> _setStatus(String id, String status) async {
    try {
      await _client.rpc('novagram_admin_update_report', params: {'p_report_id': id, 'p_status': status});
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Статус жалобы обновлён')));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $error')));
    }
  }

  String _category(String value) => switch (value) {
    'doxxing' => 'Доксинг', 'threats' => 'Угрозы', 'swatting' => 'Сваттинг',
    'harassment' => 'Преследование', 'spam' => 'Спам', 'impersonation' => 'Подмена личности', _ => 'Другое',
  };
  String _status(String value) => switch (value) {
    'new' => 'Новая', 'reviewing' => 'На проверке', 'resolved' => 'Решена', 'dismissed' => 'Отклонена', _ => value,
  };

  Widget _metric(String title, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(color: const Color(0xFF171923), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0EFFFFFF))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, color: color), const Spacer(),
      Text(value, style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w800)),
      Text(title, style: const TextStyle(color: Colors.white60, fontSize: 12)),
    ]),
  );

  @override
  Widget build(BuildContext context) {
    final reports = _data?['reports'] as List<dynamic>? ?? const [];
    return Scaffold(
      appBar: AppBar(title: const Text('Центр управления'), actions: [IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh_rounded))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null
        ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.admin_panel_settings_outlined, size: 48),
            const SizedBox(height: 14),
            const Text('Доступ администратора не подтверждён', textAlign: TextAlign.center, style: TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54, fontSize: 12)),
            const SizedBox(height: 16), OutlinedButton(onPressed: _load, child: const Text('Повторить')),
          ])))
        : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
            Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), gradient: const LinearGradient(colors: [Color(0xFF29213F), Color(0xFF171923)])), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.shield_moon_outlined, size: 28, color: Color(0xFFB9ADFF)), SizedBox(height: 14),
              Text('Novagram Control', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              SizedBox(height: 5), Text('Статистика сервиса и очередь обращений', style: TextStyle(color: Colors.white60)),
            ])),
            const SizedBox(height: 14),
            GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.5, children: [
              _metric('Пользователи', _count('users').toString(), Icons.people_alt_outlined, const Color(0xFF9B8CFF)),
              _metric('Чаты', _count('chats').toString(), Icons.forum_outlined, const Color(0xFF62D5D0)),
              _metric('Сообщения', _count('messages').toString(), Icons.chat_bubble_outline, const Color(0xFFFFC36B)),
              _metric('Каналы', _count('channels').toString(), Icons.campaign_outlined, const Color(0xFF7CB9FF)),
            ]),
            const SizedBox(height: 24),
            Row(children: [
              const Expanded(child: Text('Жалобы и безопасность', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800))),
              Text(_count('pending_reports').toString() + ' новых', style: const TextStyle(color: Color(0xFFFFA1AE), fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 10),
            if (reports.isEmpty) const Padding(padding: EdgeInsets.all(24), child: Center(child: Text('Жалоб пока нет', style: TextStyle(color: Colors.white54)))),
            ...reports.map((raw) {
              final r = Map<String, dynamic>.from(raw as Map);
              final id = r['id'] as String;
              final status = r['status'] as String? ?? 'new';
              return Container(margin: const EdgeInsets.only(bottom: 10), padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: const Color(0xFF171923), borderRadius: BorderRadius.circular(18), border: Border.all(color: const Color(0x0EFFFFFF))), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [Expanded(child: Text(_category(r['category'] as String? ?? 'other'), style: const TextStyle(fontWeight: FontWeight.w800))), Text(_status(status), style: const TextStyle(color: Colors.white54, fontSize: 12))]),
                const SizedBox(height: 7),
                Text('От: ' + (r['reporter_name']?.toString() ?? 'Пользователь') + ' • На: ' + (r['reported_name']?.toString() ?? 'Не указан'), style: const TextStyle(color: Colors.white60, fontSize: 12)),
                if ((r['details'] as String? ?? '').isNotEmpty) ...[const SizedBox(height: 9), Text(r['details'] as String)],
                const SizedBox(height: 12),
                Wrap(spacing: 7, runSpacing: 7, children: [
                  if (status == 'new') OutlinedButton(onPressed: () => _setStatus(id, 'reviewing'), child: const Text('В работу')),
                  if (status != 'resolved') FilledButton.tonal(onPressed: () => _setStatus(id, 'resolved'), child: const Text('Решено')),
                  if (status != 'dismissed') TextButton(onPressed: () => _setStatus(id, 'dismissed'), child: const Text('Отклонить')),
                ]),
              ]));
            }),
          ])),
    );
  }
}
