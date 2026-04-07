import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/chat.dart';
import 'chat_conversation_screen.dart';
import '../l10n/app_localizations.dart';
import '../providers/group_provider.dart';
import '../models/group.dart';
import 'group_conversation_screen.dart';

class ChatListScreen extends StatefulWidget {
  const ChatListScreen({super.key});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _contactList = [];
  bool _isLoadingUsers = false;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChatProvider>();
      _loadContactList();

      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final groupProvider = context.read<GroupProvider>();
      groupProvider.updateUserData(
        authProvider.userId,
        authProvider.fullName,
        authProvider.userCount,
      );
      groupProvider.loadGroups();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadContactList() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoadingUsers = true);
    try {
      final response = await http.post(
        Uri.parse('https://igb-fems.com/LIVE/mobile_php/get_user2_list.php'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': authProvider.userId,
          'userCount': authProvider.userCount,
        }),
      );
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true) {
          setState(() {
            _contactList = List<Map<String, dynamic>>.from(data['users']);
          });
        }
      }
    } catch (e) {
      print('Error loading contacts: $e');
    } finally {
      setState(() => _isLoadingUsers = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final isUser2 = authProvider.userCount == 'User2';

    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        leading: isUser2
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    Navigator.pushReplacementNamed(context, '/dashboard'),
              ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              authProvider.fullName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (!isUser2)
              Text(
                authProvider.tradeName,
                style: TextStyle(color: Colors.grey[400], fontSize: 12),
                overflow: TextOverflow.ellipsis,
              ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white),
            onPressed: () => _showLogoutDialog(context, authProvider),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(30),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: const Color(0xFF0084FF),
                borderRadius: BorderRadius.circular(25),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.grey,
              dividerColor: Colors.transparent,
              labelStyle: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
              tabs: [
                Tab(text: AppLocalizations.of(context).all),
                Tab(text: AppLocalizations.of(context).groups),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildAllTab(authProvider), _buildGroupsTab()],
      ),
      // ── FAB: only User2 on Groups tab ────────────────────────────────────
      floatingActionButton: Consumer<AuthProvider>(
        builder: (context, auth, child) {
          final isUser2 = auth.userCount == 'User2';
          return AnimatedBuilder(
            animation: _tabController,
            builder: (context, child) {
              // All tab → no FAB for anyone
              if (_tabController.index == 0) return const SizedBox.shrink();
              // Groups tab → only User2
              if (!isUser2) return const SizedBox.shrink();
              return FloatingActionButton(
                onPressed: () => _showCreateGroupDialog(context),
                backgroundColor: const Color(0xFF0084FF),
                child: const Icon(Icons.group_add, color: Colors.white),
              );
            },
          );
        },
      ),
    );
  }

  // ── Tab 1: All ────────────────────────────────────────────────────────────
  Widget _buildAllTab(AuthProvider authProvider) {
    final isUser1Or3 =
        authProvider.userCount == 'User1' || authProvider.userCount == 'User3';

    return Column(
      children: [
        // Search bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF1A2332),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                Icon(Icons.search, color: Colors.grey[500], size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: AppLocalizations.of(context).search,
                      hintStyle: TextStyle(color: Colors.grey[500]),
                      border: InputBorder.none,
                    ),
                    onChanged: (value) {},
                  ),
                ),
              ],
            ),
          ),
        ),

        // Contact list
        if (_contactList.isNotEmpty)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isUser1Or3
                      ? AppLocalizations.of(context).messageStaff
                      : AppLocalizations.of(context).messageColleague,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 100,
                  child: _isLoadingUsers
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: _contactList.length,
                          itemBuilder: (context, index) =>
                              _buildContactTile(context, _contactList[index]),
                        ),
                ),
              ],
            ),
          ),

        // Chat list
        Expanded(
          child: Consumer<ChatProvider>(
            builder: (context, chatProvider, child) {
              if (chatProvider.isLoading) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                );
              }

              final chats = chatProvider.chats;

              if (chats.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: Color(0xFF1A2332),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.chat_bubble_outline,
                          size: 40,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context).noConversationYet,
                        style: TextStyle(
                          color: Colors.grey[400],
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context).startANewChat,
                        style: TextStyle(color: Colors.grey[600], fontSize: 14),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                itemCount: chats.length,
                itemBuilder: (context, index) =>
                    _buildChatTile(context, chats[index], chatProvider),
              );
            },
          ),
        ),
      ],
    );
  }

  // ── Tab 2: Groups ─────────────────────────────────────────────────────────
  Widget _buildGroupsTab() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final isUser2 = authProvider.userCount == 'User2';

    return Consumer<GroupProvider>(
      builder: (context, groupProvider, child) {
        if (groupProvider.isLoading) {
          return const Center(
            child: CircularProgressIndicator(color: Colors.white),
          );
        }

        final groups = groupProvider.groups;

        if (groups.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1A2332),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.group_outlined,
                    size: 40,
                    color: Color(0xFF0084FF),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  AppLocalizations.of(context).noGroupsYet,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isUser2
                      ? AppLocalizations.of(context).tapPlusToCreateAGroup
                      : AppLocalizations.of(
                          context,
                        ).youWillAppearHereOnceAddedToAGroup,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: groups.length,
          itemBuilder: (context, index) =>
              _buildGroupTile(context, groups[index], groupProvider),
        );
      },
    );
  }

  Widget _buildGroupTile(
    BuildContext context,
    Group group,
    GroupProvider groupProvider,
  ) {
    final lastMessage = group.lastMessage;
    final timeString = lastMessage != null
        ? _formatTime(lastMessage.timestamp)
        : _formatTime(group.updatedAt);

    String preview = AppLocalizations.of(context).noMessagesYet;
    if (lastMessage != null) {
      final isMe = lastMessage.senderId == groupProvider.currentUserId;
      if (isMe) {
        preview = lastMessage.content.isNotEmpty
            ? '${AppLocalizations.of(context).you}: ${lastMessage.content}'
            : AppLocalizations.of(context).youSentAnAttachment;
      } else {
        preview = lastMessage.content.isNotEmpty
            ? '${lastMessage.senderName}: ${lastMessage.content}'
            : '${lastMessage.senderName} ${AppLocalizations.of(context).sentAnAttachment}';
      }
    }

    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => GroupConversationScreen(group: group),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFF0084FF),
                  child: Icon(Icons.group, color: Colors.white, size: 28),
                ),
                if (group.unreadCount > 0)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        group.unreadCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          group.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: group.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        timeString,
                        style: TextStyle(
                          color: group.unreadCount > 0
                              ? const Color(0xFF0084FF)
                              : Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    preview,
                    style: TextStyle(
                      color: group.unreadCount > 0
                          ? Colors.white70
                          : Colors.grey[500],
                      fontSize: 14,
                      fontWeight: group.unreadCount > 0
                          ? FontWeight.w500
                          : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChatTile(
    BuildContext context,
    Chat chat,
    ChatProvider chatProvider,
  ) {
    final lastMessage = chat.lastMessage;
    final timeString = lastMessage != null
        ? _formatTime(lastMessage.timestamp)
        : _formatTime(chat.updatedAt);

    String lastMessagePreview = AppLocalizations.of(context).noMessagesYet;
    if (lastMessage != null) {
      final isMe = lastMessage.senderId == chatProvider.currentUserId;
      if (isMe) {
        lastMessagePreview = lastMessage.content.isNotEmpty
            ? '${AppLocalizations.of(context).you}: ${lastMessage.content}'
            : AppLocalizations.of(context).youSentAnAttachment;
      } else {
        lastMessagePreview = lastMessage.content.isNotEmpty
            ? lastMessage.content
            : '${chat.name} ${AppLocalizations.of(context).sentAnAttachment}';
      }
    }

    return InkWell(
      onTap: () {
        chatProvider.markChatAsRead(chat.id);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(chat: chat),
          ),
        );
      },
      onLongPress: () => _showChatOptions(context, chat, chatProvider),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: const Color(0xFF1A2332),
                  backgroundImage: NetworkImage(
                    'https://api.dicebear.com/7.x/micah/png?seed=${chat.name}',
                  ),
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: const Color(0xFF4CAF50),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF0A0F1A),
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.name,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.bold
                                : FontWeight.w500,
                          ),
                        ),
                      ),
                      Text(
                        timeString,
                        style: TextStyle(
                          color: chat.unreadCount > 0
                              ? const Color(0xFF0084FF)
                              : Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lastMessagePreview,
                          style: TextStyle(
                            color: chat.unreadCount > 0
                                ? Colors.white70
                                : Colors.grey[500],
                            fontSize: 14,
                            fontWeight: chat.unreadCount > 0
                                ? FontWeight.w500
                                : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (chat.unreadCount > 0)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0084FF),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            chat.unreadCount.toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContactTile(BuildContext context, Map<String, dynamic> user) {
    final name = user['fullName'] ?? 'Xxxxx';
    return GestureDetector(
      onTap: () => _startChat(context, user),
      child: Container(
        width: 80,
        margin: const EdgeInsets.only(right: 12),
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              padding: const EdgeInsets.all(1),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0084FF), width: 2),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xFF1A2332),
                backgroundImage: NetworkImage(
                  'https://api.dicebear.com/7.x/micah/png?seed=$name',
                ),
              ),
            ),
            const SizedBox(height: 4),
            Flexible(
              child: Text(
                name,
                style: const TextStyle(color: Colors.white, fontSize: 12),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _startChat(
    BuildContext context,
    Map<String, dynamic> user,
  ) async {
    final chatProvider = context.read<ChatProvider>();
    final authProvider = context.read<AuthProvider>();
    final otherUserId = user['userId'].toString();

    Chat? existingChat;
    try {
      existingChat = chatProvider.chats.firstWhere(
        (chat) =>
            chat.participantIds.contains(otherUserId) &&
            chat.participantIds.contains(authProvider.userId) &&
            chat.participantIds.length == 2,
      );
    } catch (_) {
      existingChat = null;
    }

    if (existingChat != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatConversationScreen(chat: existingChat!),
        ),
      );
      return;
    }

    await chatProvider.createChat(
      user['fullName'] ?? 'Xxxxxx',
      [authProvider.userId, otherUserId],
      [authProvider.fullName, user['fullName'] ?? ''],
      [authProvider.userCount, user['userCount'] ?? 'User2'],
    );

    if (chatProvider.chats.isNotEmpty) {
      Chat? newChat;
      try {
        newChat = chatProvider.chats.firstWhere(
          (chat) =>
              chat.participantIds.contains(otherUserId) &&
              chat.participantIds.contains(authProvider.userId),
        );
      } catch (_) {
        newChat = chatProvider.chats.first;
      }
      if (newChat != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => ChatConversationScreen(chat: newChat!),
          ),
        );
      }
    }
  }

  void _showCreateGroupDialog(BuildContext context) {
    final nameController = TextEditingController();
    final groupProvider = context.read<GroupProvider>();
    List<Map<String, dynamic>> selectedMembers = [];

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1A2332),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                AppLocalizations.of(context).createGroup,
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: nameController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: AppLocalizations.of(context).groupName,
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        filled: true,
                        fillColor: const Color(0xFF0A0F1A),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        AppLocalizations.of(context).addMembers,
                        style: TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxHeight: 250),
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: _contactList.length,
                        itemBuilder: (context, index) {
                          final user = _contactList[index];
                          final userId = user['userId'].toString();
                          final isSelected = selectedMembers.any(
                            (m) => m['userId'] == userId,
                          );
                          return CheckboxListTile(
                            value: isSelected,
                            onChanged: (val) {
                              setDialogState(() {
                                if (val == true) {
                                  selectedMembers.add({
                                    'userId': userId,
                                    'userType': user['userCount'] ?? 'User2',
                                  });
                                } else {
                                  selectedMembers.removeWhere(
                                    (m) => m['userId'] == userId,
                                  );
                                }
                              });
                            },
                            title: Text(
                              user['fullName'] ?? 'Xxxxx',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                              ),
                            ),
                            activeColor: const Color(0xFF0084FF),
                            checkColor: Colors.white,
                            side: const BorderSide(color: Colors.grey),
                            contentPadding: EdgeInsets.zero,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    AppLocalizations.of(context).cancel,
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) return;
                    if (selectedMembers.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context).addAtleastOneMember,
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.pop(context);
                    final success = await groupProvider.createGroup(
                      nameController.text.trim(),
                      selectedMembers
                          .map(
                            (m) => {
                              'userId': m['userId'].toString(),
                              'userType': m['userType'].toString(),
                            },
                          )
                          .toList(),
                    );
                    if (success && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            AppLocalizations.of(context).groupCrated,
                          ),
                          backgroundColor: Color(0xFF0084FF),
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0084FF),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    AppLocalizations.of(context).create,
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    if (difference.inDays > 0)
      return '${difference.inDays}${AppLocalizations.of(context).dAgo}';
    if (difference.inHours > 0)
      return '${difference.inHours}${AppLocalizations.of(context).hAgo}';
    if (difference.inMinutes > 0)
      return '${difference.inMinutes}${AppLocalizations.of(context).mAgo}';
    return AppLocalizations.of(context).justNow;
  }

  void _showChatOptions(
    BuildContext context,
    Chat chat,
    ChatProvider chatProvider,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0e1726),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.info_outline, color: Colors.white),
                title: Text(
                  AppLocalizations.of(context).chatInfo,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(
                  Icons.notifications_off,
                  color: Colors.white,
                ),
                title: Text(
                  AppLocalizations.of(context).mute,
                  style: const TextStyle(color: Colors.white),
                ),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: Text(
                  AppLocalizations.of(context).deleteChat,
                  style: const TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteConfirmation(context, chat, chatProvider);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDeleteConfirmation(
    BuildContext context,
    Chat chat,
    ChatProvider chatProvider,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF0e1726),
          title: Text(
            AppLocalizations.of(context).deleteChat,
            style: const TextStyle(color: Colors.white),
          ),
          content: Text(
            AppLocalizations.of(context).deleteChatConfirmation,
            style: const TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            TextButton(
              onPressed: () {
                chatProvider.deleteChat(chat.id);
                Navigator.pop(context);
              },
              child: Text(
                AppLocalizations.of(context).delete,
                style: const TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1A2332),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            AppLocalizations.of(context).logout,
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          content: Text(
            AppLocalizations.of(context).logoutConfirmation,
            style: TextStyle(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context).cancel,
                style: TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                authProvider.logout();
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/');
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                AppLocalizations.of(context).logout,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }
}
