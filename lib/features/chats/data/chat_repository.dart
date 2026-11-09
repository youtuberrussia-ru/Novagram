import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/chat.dart';

class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  Future<List<Chat>> getMyChats() async {
    if (_client.auth.currentUser == null) return [];
    final rows = await _client.rpc('get_my_chats') as List<dynamic>;
    return rows
        .map((row) => Chat.fromRpcRow(Map<String, dynamic>.from(row as Map)))
        .toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> searchUsers(String query) async {
    final me = _client.auth.currentUser?.id;
    final normalized = query.trim();
    if (me == null || normalized.length < 2) return [];
    final rows = await _client.rpc(
      'search_profiles',
      params: {'p_query': normalized},
    ) as List<dynamic>;
    return rows
        .map((row) => Map<String, dynamic>.from(row as Map))
        .where((row) => row['id'] != me)
        .toList(growable: false);
  }

  Future<String> createDirectChat(String otherUserId) async {
    final result = await _client.rpc(
      'create_direct_chat',
      params: {'p_other_user': otherUserId},
    );
    return result as String;
  }

  Future<String> createGroupChat({
    required String title,
    required List<String> userIds,
  }) async {
    final result = await _client.rpc(
      'create_group_chat',
      params: {
        'p_title': title.trim(),
        'p_user_ids': userIds,
      },
    );
    return result as String;
  }
}
