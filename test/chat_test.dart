import 'package:flutter_test/flutter_test.dart';
import 'package:novagram/features/chats/domain/chat.dart';

void main() {
  group('Chat.fromRpcRow', () {
    test('uses the group title and trims its text', () {
      final chat = Chat.fromRpcRow({
        'id': 'group-1',
        'title': '  Friends  ',
        'is_group': true,
        'updated_at': '2026-11-10T08:00:00Z',
        'last_message': '  Hello  ',
      });

      expect(chat.id, 'group-1');
      expect(chat.title, 'Friends');
      expect(chat.isGroup, isTrue);
      expect(chat.lastMessage, 'Hello');
      expect(chat.updatedAt, DateTime.parse('2026-11-10T08:00:00Z'));
    });

    test('uses the other participant display name for a direct chat', () {
      final chat = Chat.fromRpcRow({
        'id': 'direct-1',
        'is_group': false,
        'other_display_name': '  Alex  ',
        'other_username': 'alex_1',
        'updated_at': '2026-11-10T08:00:00Z',
      });

      expect(chat.title, 'Alex');
      expect(chat.isGroup, isFalse);
    });

    test('falls back safely when optional chat fields are empty', () {
      final group = Chat.fromRpcRow({
        'id': 'group-2',
        'is_group': true,
        'title': ' ',
      });
      final direct = Chat.fromRpcRow({
        'id': 'direct-2',
        'is_group': false,
        'other_display_name': ' ',
        'other_username': ' ',
      });

      expect(group.title, 'Группа');
      expect(direct.title, 'Личный чат');
      expect(group.updatedAt, DateTime.fromMillisecondsSinceEpoch(0));
    });

    test('uses username when a direct display name is absent', () {
      final chat = Chat.fromRpcRow({
        'id': 'direct-3',
        'is_group': false,
        'other_username': '  alex_2 ',
      });

      expect(chat.title, '@alex_2');
    });
  });
}
