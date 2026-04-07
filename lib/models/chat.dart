import 'message.dart';

class Chat {
  final String id;
  final String name;
  final List<String> participantIds;
  final List<String> participantNames;
  final Message? lastMessage;
  final DateTime createdAt;
  final DateTime updatedAt;
  final int unreadCount;
  final String? avatarUrl;

  Chat({
    required this.id,
    required this.name,
    required this.participantIds,
    required this.participantNames,
    this.lastMessage,
    required this.createdAt,
    required this.updatedAt,
    this.unreadCount = 0,
    this.avatarUrl,
  });

  factory Chat.fromJson(Map<String, dynamic> json) {
    return Chat(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      participantIds: List<String>.from(json['participantIds'] ?? []),
      participantNames: List<String>.from(json['participantNames'] ?? []),
      lastMessage: json['lastMessage'] != null
          ? Message.fromJson(json['lastMessage'])
          : null,
      createdAt: DateTime.parse(
        json['createdAt'] ?? DateTime.now().toIso8601String(),
      ),
      updatedAt: DateTime.parse(
        json['updatedAt'] ?? DateTime.now().toIso8601String(),
      ),
      unreadCount: json['unreadCount'] ?? 0,
      avatarUrl: json['avatarUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'participantIds': participantIds,
      'participantNames': participantNames,
      'lastMessage': lastMessage?.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'unreadCount': unreadCount,
      'avatarUrl': avatarUrl,
    };
  }

  Chat copyWith({
    String? id,
    String? name,
    List<String>? participantIds,
    List<String>? participantNames,
    Message? lastMessage,
    DateTime? createdAt,
    DateTime? updatedAt,
    int? unreadCount,
    String? avatarUrl,
  }) {
    return Chat(
      id: id ?? this.id,
      name: name ?? this.name,
      participantIds: participantIds ?? this.participantIds,
      participantNames: participantNames ?? this.participantNames,
      lastMessage: lastMessage ?? this.lastMessage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      unreadCount: unreadCount ?? this.unreadCount,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }
}
