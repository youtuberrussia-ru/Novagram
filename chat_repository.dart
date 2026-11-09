import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  Future<List<Chat>> getMyChats() async {
    final String? userId = _client.auth.currentUser?.id;
    if (userId == null) return <Chat>[];

    final List<Map<String, dynamic>> rows = await _client
        .from('chat_members')
        .select('chat_id, chats!inner(id, title, is_group, updated_at)')
        .eq('user_id', userId)
        .order('joined_at', ascending: false);

    return rows.map(Chat.fromMembershipRow).toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final String? currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null || query.trim().length < 2) {
      return <Map<String, dynamic>>[];
    }

    final dynamic rows = await _client.rpc(
      'search_profiles',
      params: <String, dynamic>{'p_query': query.trim()},
    );
    return (rows as List<dynamic>)
        .map((dynamic row) => Map<String, dynamic>.from(row as Map))
        .where((Map<String, dynamic> row) => row['id'] != currentUserId)
        .toList(growable: false);
  }

  Future<String> createDirectChat(String otherUserId) async {
    final dynamic result = await _client.rpc(
      'create_direct_chat',
      params: <String, dynamic>{'p_other_user': otherUserId},
    );
    return result as String;
  }
}
