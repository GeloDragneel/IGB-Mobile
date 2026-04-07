import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import '../models/group.dart';
import '../models/message.dart';

class GroupProvider with ChangeNotifier {
  List<Group> _groups = [];
  List<Message> _messages = [];
  bool _isLoading = false;
  String? _currentUserId;
  String? _currentUserName;
  String? _currentUserCount;

  List<Group> get groups => _groups;
  List<Message> get messages => _messages;
  bool get isLoading => _isLoading;
  String? get currentUserId => _currentUserId;
  String? get currentUserCount => _currentUserCount;

  void updateUserData(String userId, String userName, String userCount) {
    _currentUserId = userId;
    _currentUserName = userName;
    _currentUserCount = userCount;
    notifyListeners();
  }

  Future<void> loadGroups() async {
    _isLoading = true;
    notifyListeners();

    try {
      final response = await http.post(
        Uri.parse('https://igb-fems.com/LIVE/mobile_php/group_get_list.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': _currentUserId,
          'userCount': _currentUserCount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          final List<dynamic> groupList = data['groups'];
          _groups = groupList.map((g) {
            final lastMsgTime = g['lastMessageTime'] != null
                ? DateTime.parse(g['lastMessageTime'])
                : DateTime.now();
            return Group(
              id: g['groupId'].toString(),
              name: g['groupName'],
              createdBy: g['createdBy'].toString(),
              createdByType: g['createdByType'],
              unreadCount: g['unreadCount'] ?? 0,
              updatedAt: lastMsgTime,
              lastMessage: (g['lastMessage'] != null && g['lastMessage'] != '')
                  ? Message(
                      id: 'grp_last_${g['groupId']}',
                      chatId: g['groupId'].toString(),
                      senderId: g['lastSenderId'].toString(),
                      senderName: g['lastSenderName'] ?? '',
                      content: g['lastMessage'],
                      timestamp: lastMsgTime,
                    )
                  : null,
            );
          }).toList();
        }
      }
    } catch (e) {
      print('Error loading groups: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadMessages(String groupId) async {
    _isLoading = true;
    _messages = [];

    try {
      final response = await http.post(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/group_get_messages.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'userId': _currentUserId,
          'userType': _currentUserCount,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          final List<dynamic> msgs = data['messages'];
          final seen = <String>{};
          _messages = msgs
              .map(
                (msg) => Message(
                  id: msg['messageId'].toString(),
                  chatId: groupId,
                  senderId: msg['senderId'].toString(),
                  senderName: msg['senderName'] ?? '',
                  content: msg['content'] ?? '',
                  timestamp: DateTime.parse(msg['timestamp']),
                  isRead: msg['isRead'] ?? true,
                  attachmentUrl: msg['attachmentUrl'],
                  attachmentName: msg['attachmentName'],
                  attachmentType: msg['attachmentType'],
                ),
              )
              .where((m) => seen.add(m.id))
              .toList();
        }
      }
    } catch (e) {
      print('Error loading group messages: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> sendMessage(
    String groupId,
    String content, {
    PlatformFile? attachment,
  }) async {
    if (content.trim().isEmpty && attachment == null) return;

    try {
      String? attachmentBase64;
      String? attachmentName;
      String? attachmentType;

      if (attachment != null && attachment.bytes != null) {
        attachmentBase64 = base64Encode(attachment.bytes!);
        attachmentName = attachment.name;
        attachmentType = attachment.extension ?? 'file';
      }

      final response = await http.post(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/group_send_message.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'senderId': _currentUserId,
          'senderType': _currentUserCount,
          'senderName': _currentUserName,
          'message': content,
          if (attachmentBase64 != null) 'attachment': attachmentBase64,
          if (attachmentName != null) 'attachmentName': attachmentName,
          if (attachmentType != null) 'attachmentType': attachmentType,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          final message = Message(
            id: data['messageId'].toString(),
            chatId: groupId,
            senderId: _currentUserId!,
            senderName: _currentUserName!,
            content: content,
            timestamp: DateTime.parse(data['timestamp']),
            isRead: true,
            attachmentUrl: data['attachmentUrl'],
            attachmentName: attachmentName,
            attachmentType: attachmentType,
          );
          _messages.add(message);

          final idx = _groups.indexWhere((g) => g.id == groupId);
          if (idx != -1) {
            _groups[idx] = _groups[idx].copyWith(
              lastMessage: message,
              updatedAt: message.timestamp,
            );
          }
          notifyListeners();
        }
      }
    } catch (e) {
      print('Error sending group message: $e');
    }
  }

  Future<bool> createGroup(
    String groupName,
    List<Map<String, String>> members,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('https://igb-fems.com/LIVE/mobile_php/group_create.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupName': groupName,
          'createdBy': _currentUserId,
          'createdByType': _currentUserCount,
          'members': members,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          await loadGroups();
          return true;
        }
      }
    } catch (e) {
      print('Error creating group: $e');
    }
    return false;
  }

  int get totalUnreadCount {
    return _groups.fold(0, (sum, g) => sum + g.unreadCount);
  }

  Future<List<Map<String, dynamic>>> getMembers(String groupId) async {
    try {
      final response = await http.post(
        Uri.parse('https://igb-fems.com/LIVE/mobile_php/group_get_members.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'groupId': groupId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          return List<Map<String, dynamic>>.from(data['members']);
        }
      }
    } catch (e) {
      print('Error getting members: $e');
    }
    return [];
  }

  Future<bool> leaveGroup(String groupId) async {
    try {
      final response = await http.post(
        Uri.parse('https://igb-fems.com/LIVE/mobile_php/group_leave.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'groupId': groupId,
          'userId': _currentUserId,
          'userType': _currentUserCount,
        }),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          _groups.removeWhere((g) => g.id == groupId);
          notifyListeners();
          return true;
        }
      }
    } catch (e) {
      print('Error leaving group: $e');
    }
    return false;
  }

  Future<List<Map<String, dynamic>>> getAvailableUsers(String groupId) async {
    try {
      final response = await http.post(
        Uri.parse(
          'https://igb-fems.com/LIVE/mobile_php/group_get_available_users.php',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'groupId': groupId}),
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['result'] == 'Success') {
          return List<Map<String, dynamic>>.from(data['users']);
        }
      }
    } catch (e) {
      print('Error getting available users: $e');
    }
    return [];
  }

  Future<bool> addMembers(
    String groupId,
    List<Map<String, dynamic>> users,
  ) async {
    try {
      final payload = {
        'groupId': groupId,
        'addedBy': _currentUserId,
        'members': users
            .map((u) => {'userId': u['userId'], 'userType': u['userType']})
            .toList(),
      };

      final response = await http.post(
        Uri.parse('https://igb-fems.com/LIVE/mobile_php/group_add_members.php'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['result'] == 'Success';
      }
    } catch (e) {
      print('>>> addMembers error: $e');
    }
    return false;
  }
}
