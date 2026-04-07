import 'message.dart';

class Group {
  final String id;
  final String name;
  final String createdBy;
  final String createdByType;
  final int unreadCount;
  final Message? lastMessage;
  final DateTime updatedAt;

  Group({
    required this.id,
    required this.name,
    required this.createdBy,
    required this.createdByType,
    this.unreadCount = 0,
    this.lastMessage,
    required this.updatedAt,
  });

  Group copyWith({
    String? id,
    String? name,
    String? createdBy,
    String? createdByType,
    int? unreadCount,
    Message? lastMessage,
    DateTime? updatedAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      createdBy: createdBy ?? this.createdBy,
      createdByType: createdByType ?? this.createdByType,
      unreadCount: unreadCount ?? this.unreadCount,
      lastMessage: lastMessage ?? this.lastMessage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
