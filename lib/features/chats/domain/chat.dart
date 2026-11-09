class Chat {
  const Chat({required this.id, required this.title, required this.isGroup, required this.updatedAt});
  final String id, title;
  final bool isGroup;
  final DateTime updatedAt;
  factory Chat.fromMembershipRow(Map<String, dynamic> row) {
    final data = Map<String, dynamic>.from(row['chats'] as Map);
    final title = (data['title'] as String?)?.trim();
    return Chat(id: data['id'] as String, title: title == null || title.isEmpty ? 'Новый чат' : title,
      isGroup: data['is_group'] as bool? ?? false,
      updatedAt: DateTime.tryParse(data['updated_at'] as String? ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0));
  }
}