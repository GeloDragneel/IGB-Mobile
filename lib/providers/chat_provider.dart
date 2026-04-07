import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/chat.dart';
import '../models/message.dart';
import 'package:file_picker/file_picker.dart';

class ChatProvider with ChangeNotifier {
  List<Chat> _chats = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserCount;

  List<Chat> get chats {
    final sortedChats = List<Chat>.from(_chats);
    sortedChats.sort((a, b) {
      final aTime = a.lastMessage?.timestamp ?? a.updatedAt;
      final bTime = b.lastMessage?.timestamp ?? b.updatedAt;
      return bTime.compareTo(aTime);
    });
    return sortedChats;
  }

  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId;
  String? get currentUserName => _currentUserName;
  String? get currentUserCount => _currentUserCount;

  ChatProvider() {
    _loadUserData();
    _loadChats();
  }

  Future<void> _loadUserData() async {
    final prefs = await SharedPreferences.getInstance();
    _currentUserId = prefs.getString('user_id') ?? 'user_1';
    _currentUserName = prefs.getString('user_name') ?? 'User';
    _currentUserCount = prefs.getString('user_count') ?? 'User1';
    notifyListeners();
  }

  void updateUserData(String userId, String userName, String userCount) {
    _currentUserId = userId;
    _currentUserName = userName;
    _currentUserCount = userCount;
    notifyListeners();
  }

  Future<void> reloadAfterLogin() async {
    await _loadUserData();
    await _loadChats();
  }

  Future<void> _loadChats() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (_currentUserId != null && _currentUserCount != null) {
        final url = Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/chat_get_conversations.php',
        );
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'userId': _currentUserId,
            'userCount': _currentUserCount,
          }),
        );

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          if (data['result'] == 'Success') {
            final List<dynamic> conversations = data['conversations'];
            print('>>> CONVERSATIONS: ${response.body}'); // ← add this
            _chats = conversations.map((conv) {
              final chatId = '${conv['userId']}_${conv['userType']}';
              final lastMsgTime = conv['lastMessageTime'] != null
                  ? DateTime.parse(conv['lastMessageTime'])
                  : DateTime.now();
              final lastSenderId = conv['lastSenderId']?.toString() ?? '';
              final lastSenderName = conv['lastSenderName'] ?? '';
              print('>>> currentUserId: $_currentUserId');
              print('>>> lastSenderId: ${conv['lastSenderId']}');
              print(
                '>>> match: ${conv['lastSenderId']?.toString() == _currentUserId}',
              );
              print(
                '>>> comparing: "$lastSenderId" == "$_currentUserId" → ${lastSenderId == _currentUserId}',
              );

              return Chat(
                id: chatId,
                name: conv['fullName'] ?? 'Chat',
                participantIds: [
                  _currentUserId ?? '',
                  conv['userId'].toString(),
                ],
                participantNames: [
                  _currentUserName ?? '',
                  conv['fullName'] ?? '',
                ],
                createdAt: DateTime.now(),
                updatedAt: lastMsgTime,
                unreadCount: conv['unreadCount'] ?? 0,
                lastMessage: conv['lastMessage'] != null
                    ? Message(
                        id: 'msg_${conv['userId']}',
                        chatId: chatId,
                        senderId: lastSenderId,
                        senderName: lastSenderName,
                        content: conv['lastMessage'],
                        timestamp: lastMsgTime,
                      )
                    : null,
              );
            }).toList();
          }
        }
      }
    } catch (e) {
      print('Error loading chats: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> refreshChats() async {
    await _loadChats();
  }

  Future<void> loadMessages(String chatId) async {
    _isLoading = true;
    _messages = [];
    // ✅ No notifyListeners() here — avoid triggering rebuild with empty list

    try {
      if (_currentUserId != null && _currentUserCount != null) {
        final parts = chatId.split('_');
        if (parts.length >= 2) {
          final otherUserId = parts[0];
          final otherUserType = parts[1];

          final url = Uri.parse(
            'https://igb-fems.com/LIVE/mobile_php/chat_get_messages.php',
          );
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'currentUserId': _currentUserId,
              'currentUserType': _currentUserCount,
              'otherUserId': otherUserId,
              'otherUserType': otherUserType,
            }),
          );

          if (response.statusCode == 200) {
            final data = jsonDecode(response.body);
            if (data['result'] == 'Success') {
              final List<dynamic> msgs = data['messages'];

              // Deduplicate by messageId as safety net
              final seen = <String>{};
              _messages = msgs
                  .map(
                    (msg) => Message(
                      id: msg['messageId'].toString(),
                      chatId: chatId,
                      senderId: msg['senderId'].toString(),
                      senderName: msg['senderName'] ?? '',
                      content: msg['content'] ?? '',
                      timestamp: DateTime.parse(msg['timestamp']),
                      isRead: msg['isRead'] ?? false,
                      attachmentUrl: msg['attachmentUrl'], // ✅ add
                      attachmentName: msg['attachmentName'], // ✅ add
                      attachmentType: msg['attachmentType'], // ✅ add
                    ),
                  )
                  .where((m) => seen.add(m.id))
                  .toList();

              if (_messages.isNotEmpty) {
                final latestMsg = _messages.last;
                final chatIndex = _chats.indexWhere((c) => c.id == chatId);
                if (chatIndex != -1) {
                  _chats[chatIndex] = _chats[chatIndex].copyWith(
                    lastMessage: latestMsg,
                    updatedAt: latestMsg.timestamp,
                  );
                }
              }
            }
          }
        }
      }
    } catch (e) {
      print('Error loading messages: $e');
    }

    _isLoading = false;
    notifyListeners(); // ✅ Only ONE notify at the very end
  }

  Future<void> sendMessage(
    String chatId,
    String content, {
    PlatformFile? attachment,
  }) async {
    if (content.trim().isEmpty && attachment == null) return;

    try {
      if (_currentUserId != null &&
          _currentUserCount != null &&
          _currentUserName != null) {
        final parts = chatId.split('_');
        if (parts.length >= 2) {
          final receiverId = parts[0];
          final receiverType = parts[1];

          String? attachmentBase64;
          String? attachmentName;
          String? attachmentType;

          if (attachment != null && attachment.bytes != null) {
            attachmentBase64 = base64Encode(attachment.bytes!);
            attachmentName = attachment.name;
            attachmentType = attachment.extension ?? 'file';
            print(
              '>>> Attachment: $attachmentName, type: $attachmentType, size: ${attachment.bytes!.length}',
            );
          }

          final url = Uri.parse(
            'https://igb-fems.com/LIVE/mobile_php/chat_send_message_new.php',
          );
          final response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'senderId': _currentUserId,
              'senderType': _currentUserCount,
              'receiverId': receiverId,
              'receiverType': receiverType,
              'message': content,
              'senderName': _currentUserName,
              if (attachmentBase64 != null) 'attachment': attachmentBase64,
              if (attachmentName != null) 'attachmentName': attachmentName,
              if (attachmentType != null) 'attachmentType': attachmentType,
            }),
          );

          if (response.statusCode == 200) {
            print(
              '>>> CONVERSATIONS RESPONSE: ${response.body}',
            ); // ← add temporarily
            final data = jsonDecode(response.body);
            if (data['result'] == 'Success') {
              final message = Message(
                id: data['messageId'].toString(),
                chatId: chatId,
                senderId: _currentUserId!,
                senderName: _currentUserName!,
                content: content,
                timestamp: DateTime.parse(data['timestamp']),
                isRead: false,
                attachmentUrl: data['attachmentUrl'],
                attachmentName: attachmentName,
                attachmentType: attachmentType,
              );

              _messages.add(message);

              final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
              if (chatIndex != -1) {
                _chats[chatIndex] = _chats[chatIndex].copyWith(
                  lastMessage: message,
                  updatedAt: message.timestamp,
                );
              }

              notifyListeners();
            }
          }
        }
      }
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> markChatAsRead(String chatId) async {
    final chatIndex = _chats.indexWhere((chat) => chat.id == chatId);
    if (chatIndex != -1) {
      _chats[chatIndex] = _chats[chatIndex].copyWith(unreadCount: 0);
      notifyListeners();
    }
  }

  Future<Chat> createChat(
    String name,
    List<String> participantIds,
    List<String> participantNames,
    List<String> participantUserCounts,
  ) async {
    final chatId = '${participantIds[1]}_${participantUserCounts[1]}';

    final existing = _chats.where((c) => c.id == chatId).toList();
    if (existing.isNotEmpty) return existing.first;

    final chat = Chat(
      id: chatId,
      name: name,
      participantIds: participantIds,
      participantNames: participantNames,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    _chats.insert(0, chat);
    notifyListeners();
    return chat;
  }

  Future<void> deleteChat(String chatId) async {
    _chats.removeWhere((chat) => chat.id == chatId);
    notifyListeners();
  }

  int get totalUnreadCount {
    return _chats.fold(0, (sum, chat) => sum + chat.unreadCount);
  }
}
