class Chat {
  const Chat({
    required this.id,
    required this.title,
    required this.isGroup,
    required this.updatedAt,
  });

  final String id;
  final String title;
  final bool isGroup;
  final DateTime updatedAt;

  factory Chat.fromMembershipRow(Map<String, dynamic> row) {
    final Map<String, dynamic> data =
        Map<String, dynamic>.from(row['chats'] as Map);
    return Chat(
      id: data['id'] as String,
      title: (data['title'] as String?)?.trim().isNotEmpty == true
          ? data['title'] as String
          : 'Новый чат',
      isGroup: data['is_group'] as bool? ?? false,
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
