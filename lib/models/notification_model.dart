class NotificationModel {
  final String id;
  final String recipientId;
  final String title;
  final String body;
  final String type;
  final String? entityType;
  final String? entityId;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;

  const NotificationModel({
    required this.id,
    required this.recipientId,
    required this.title,
    required this.body,
    required this.type,
    required this.createdAt,
    this.entityType,
    this.entityId,
    this.isRead = false,
    this.metadata,
  });

  NotificationModel copyWith({bool? isRead}) {
    return NotificationModel(
      id: id,
      recipientId: recipientId,
      title: title,
      body: body,
      type: type,
      entityType: entityType,
      entityId: entityId,
      isRead: isRead ?? this.isRead,
      metadata: metadata,
      createdAt: createdAt,
    );
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) {
    final rawMetadata = json['metadata'];
    return NotificationModel(
      id: json['id']?.toString() ?? '',
      recipientId: json['recipient_id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Notification',
      body: json['body']?.toString() ?? '',
      type: json['type']?.toString() ?? 'general',
      entityType: json['entity_type']?.toString(),
      entityId: json['entity_id']?.toString(),
      isRead: json['is_read'] == true || json['is_read'] == 1,
      metadata: rawMetadata is Map<String, dynamic>
          ? rawMetadata
          : rawMetadata is Map
              ? Map<String, dynamic>.from(rawMetadata)
              : null,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}