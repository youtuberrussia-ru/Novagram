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

  factory Chat.fromRpcRow(Map<String, dynamic> row) {
    final isGroup = row['is_group'] as bool? ?? false;
    final groupTitle = (row['title'] as String?)?.trim();
    final displayName = (row['other_display_name'] as String?)?.trim();
    final username = (row['other_username'] as String?)?.trim();

    final title = isGroup
        ? (groupTitle == null || groupTitle.isEmpty ? 'Группа' : groupTitle)
        : (displayName == null || displayName.isEmpty
            ? (username == null || username.isEmpty ? 'Личный чат' : '@$username')
            : displayName);

    return Chat(
      id: row['id'] as String,
      title: title,
      isGroup: isGroup,
      updatedAt: DateTime.tryParse(row['updated_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
