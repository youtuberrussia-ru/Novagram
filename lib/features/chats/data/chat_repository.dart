import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/chat.dart';

class ChatRepository {
  ChatRepository(this._client);
  final SupabaseClient _client;
  Future<List<Chat>> getMyChats() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) return [];
    final rows = await _client.from('chat_members').select('chat_id, chats!inner(id, title, is_group, updated_at)').eq('user_id', userId).order('joined_at', ascending: false);
    return rows.map(Chat.fromMembershipRow).toList(growable: false);
  }
  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final me = _client.auth.currentUser?.id;
    if (me == null || query.trim().length < 2) return [];
    final rows = await _client.rpc('search_profiles', params: {'p_query': query.trim()}) as List<dynamic>;
    return rows.map((row) => Map<String, dynamic>.from(row as Map)).where((row) => row['id'] != me).toList(growable: false);
  }
  Future<String> createDirectChat(String otherUserId) async {
    final result = await _client.rpc('create_direct_chat', params: {'p_other_user': otherUserId});
    return result as String;
  }
}