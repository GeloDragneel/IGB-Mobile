import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../providers/group_provider.dart';
import '../models/group.dart';
import '../models/message.dart';
import '../l10n/app_localizations.dart';

class GroupConversationScreen extends StatefulWidget {
  final Group group;
  const GroupConversationScreen({super.key, required this.group});

  @override
  State<GroupConversationScreen> createState() =>
      _GroupConversationScreenState();
}

class _GroupConversationScreenState extends State<GroupConversationScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  PlatformFile? _selectedFile;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GroupProvider>().loadMessages(widget.group.id);
      Future.delayed(const Duration(milliseconds: 600), _scrollToBottom);
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.any,
      allowMultiple: false,
      withData: true,
    );
    if (result != null && result.files.isNotEmpty) {
      setState(() => _selectedFile = result.files.first);
    }
  }

  void _sendMessage() {
    final content = _messageController.text.trim();
    if (content.isNotEmpty || _selectedFile != null) {
      context.read<GroupProvider>().sendMessage(
        widget.group.id,
        content,
        attachment: _selectedFile,
      );
      _messageController.clear();
      setState(() => _selectedFile = null);
      Future.delayed(const Duration(milliseconds: 200), _scrollToBottom);
    }
  }

  bool _isImageUrl(String? url) {
    if (url == null) return false;
    final lower = url.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.webp');
  }

  void _openImageFullscreen(String imageUrl) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: Center(
            child: InteractiveViewer(
              minScale: 0.5,
              maxScale: 5.0,
              child: Image.network(imageUrl, fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  // ── Group Info Bottom Sheet ───────────────────────────────────────────────
  void _showGroupInfo(BuildContext context) async {
    final groupProvider = context.read<GroupProvider>();
    final members = await groupProvider.getMembers(widget.group.id);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0e1726),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 1.0,
          minChildSize: 1.0,
          maxChildSize: 1.0,
          expand: false,
          builder: (context, scrollController) {
            return SafeArea(
              child: Column(
                children: [
                  // ================= TOP BAR (LIKE IMAGE) =================
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          onPressed: () => Navigator.pop(context),
                        ),

                        // Using Expanded to ensure the text occupies available space
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              children: [
                                TextSpan(
                                  text: widget.group.name,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                TextSpan(
                                  text:
                                      " • ${members.length} ${AppLocalizations.of(context).members}",
                                  style: TextStyle(
                                    color: Colors.grey,
                                    fontSize: 13,
                                    fontWeight: FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                            overflow: TextOverflow
                                .ellipsis, // Ensures text doesn't overflow
                            maxLines: 1, // Limit to a single line
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Divider(color: Colors.white12),

                  // ================= ACTION BUTTONS (REPLACES ALL / ADMINS) =================
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        // ADD MEMBERS (was "All")
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final rootContext = this.context;
                              Navigator.pop(context);

                              Future.delayed(
                                const Duration(milliseconds: 200),
                                () {
                                  Navigator.push(
                                    rootContext,
                                    MaterialPageRoute(
                                      builder: (_) => _AddMembersScreen(
                                        groupId: widget.group.id,
                                        groupProvider: rootContext
                                            .read<GroupProvider>(),
                                        parentContext: rootContext,
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0084FF),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context).addMembers,
                            ),
                          ),
                        ),

                        const SizedBox(width: 10),

                        // LEAVE GROUP (was "Admins")
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _confirmLeaveGroup(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.red.withOpacity(0.2),
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              AppLocalizations.of(context).leaveGroup,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 10),

                  // ================= MEMBERS LIST =================
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: members.length,
                      itemBuilder: (context, index) {
                        final member = members[index];

                        final isMe =
                            member['userId'].toString() ==
                            groupProvider.currentUserId;

                        final isAdmin = member['isAdmin'] == true;

                        final addedByName =
                            member['addedByName']?.toString() ?? '';

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: isAdmin
                                ? const Color(0xFFFFD700)
                                : const Color(0xFF0084FF),
                            child: Text(
                              (member['fullName'] ?? 'U')[0].toUpperCase(),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),

                          title: Text(
                            member['fullName'] ?? 'Xxxxxx',
                            style: const TextStyle(color: Colors.white),
                          ),

                          subtitle: Text(
                            isAdmin
                                ? AppLocalizations.of(context).admin
                                : "${AppLocalizations.of(context).addedBy} ${addedByName.isNotEmpty ? addedByName : 'Xxxxxx'}",
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 12,
                            ),
                          ),

                          trailing: isMe
                              ? Text(
                                  AppLocalizations.of(context).you,
                                  style: TextStyle(
                                    color: Color(0xFF0084FF),
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Confirm Leave Group ───────────────────────────────────────────────────
  void _confirmLeaveGroup(BuildContext context) {
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A2332),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          '${AppLocalizations.of(context).leaveGroup}?',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        content: Text(
          '${AppLocalizations.of(context).leaveConfirmation} "${widget.group.name}"?',
          style: const TextStyle(color: Colors.white70),
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
              Navigator.pop(context);
              final success = await context.read<GroupProvider>().leaveGroup(
                widget.group.id,
              );
              if (success && context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context).youLeftTheGroup),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              AppLocalizations.of(context).leave,
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0F1A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A0F1A),
        foregroundColor: Colors.white,
        elevation: 0,
        title: GestureDetector(
          onTap: () => _showGroupInfo(context),
          child: Row(
            children: [
              const CircleAvatar(
                radius: 20,
                backgroundColor: Color(0xFF0084FF),
                child: Icon(Icons.group, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      AppLocalizations.of(context).tapForGroupInfo,
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () => _showGroupInfo(context),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Consumer<GroupProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading) {
                  return const Center(
                    child: CircularProgressIndicator(color: Colors.white),
                  );
                }

                final messages = provider.messages;

                if (messages.isEmpty) {
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
                            Icons.group,
                            size: 40,
                            color: Colors.grey[600],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          AppLocalizations.of(context).noMessagesYet,
                          style: TextStyle(
                            color: Colors.grey[400],
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppLocalizations.of(
                            context,
                          ).startTheGroupConversation,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message.senderId == provider.currentUserId;
                    return _buildMessageBubble(message, isMe);
                  },
                );
              },
            ),
          ),
          _buildMessageInput(),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMe) {
    final hasAttachment =
        message.attachmentUrl != null && message.attachmentUrl!.isNotEmpty;
    final isImage = _isImageUrl(message.attachmentUrl);

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMe ? const Color(0xFF0084FF) : const Color(0xFF1A2332),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: isMe ? const Radius.circular(18) : Radius.zero,
            bottomRight: isMe ? Radius.zero : const Radius.circular(18),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe)
              Padding(
                padding: const EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: 10,
                  bottom: 2,
                ),
                child: Text(
                  message.senderName,
                  style: const TextStyle(
                    color: Color(0xFF0084FF),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

            // Image
            if (hasAttachment && isImage)
              GestureDetector(
                onTap: () => _openImageFullscreen(message.attachmentUrl!),
                child: ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(18),
                    topRight: Radius.circular(18),
                  ),
                  child: Stack(
                    children: [
                      Image.network(
                        message.attachmentUrl!,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Container(
                            height: 180,
                            color: Colors.black26,
                            child: const Center(
                              child: CircularProgressIndicator(
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) => Container(
                          height: 180,
                          color: Colors.black26,
                          child: const Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.white,
                              size: 48,
                            ),
                          ),
                        ),
                      ),
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.zoom_in,
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // File
            if (hasAttachment && !isImage)
              Padding(
                padding: EdgeInsets.only(
                  left: 12,
                  right: 12,
                  top: isMe ? 10 : 4,
                  bottom: message.content.isEmpty ? 4 : 0,
                ),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          _getAttachmentIcon(message.attachmentType),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              message.attachmentName ??
                                  AppLocalizations.of(context).attachment,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              (message.attachmentType ??
                                      AppLocalizations.of(context).file)
                                  .toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.6),
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.download_rounded,
                        color: Colors.white.withOpacity(0.8),
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ),

            // Text
            if (message.content.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(
                  left: 16,
                  right: 16,
                  top: hasAttachment ? 6 : (isMe ? 10 : 4),
                  bottom: 4,
                ),
                child: Text(
                  message.content,
                  style: const TextStyle(color: Colors.white, fontSize: 15),
                ),
              ),

            // Timestamp
            Padding(
              padding: const EdgeInsets.only(
                left: 16,
                right: 16,
                top: 2,
                bottom: 8,
              ),
              child: Text(
                _formatTime(message.timestamp),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_selectedFile != null)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: const Color(0xFF1A2332),
            child: Row(
              children: [
                const Icon(
                  Icons.attach_file,
                  color: Color(0xFF0084FF),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _selectedFile!.name,
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                  onPressed: () => setState(() => _selectedFile = null),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A0F1A),
            border: Border(top: BorderSide(color: Colors.grey[800]!)),
          ),
          child: SafeArea(
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.add_circle_outline,
                    color: Color(0xFF0084FF),
                  ),
                  onPressed: _pickFile,
                ),
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A2332),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: TextField(
                      controller: _messageController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText:
                            '${AppLocalizations.of(context).messageGroup}...',
                        hintStyle: TextStyle(color: Colors.grey[500]),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _sendMessage,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      color: Color(0xFF0084FF),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.send,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  IconData _getAttachmentIcon(String? type) {
    if (type == null) return Icons.attach_file;
    final t = type.toLowerCase();
    if (t.contains('pdf')) return Icons.picture_as_pdf;
    if (t.contains('word') || t.contains('doc')) return Icons.description;
    if (t.contains('excel') || t.contains('sheet')) return Icons.table_chart;
    if (t.contains('video') || t.contains('mp4')) return Icons.videocam;
    if (t.contains('audio') || t.contains('mp3')) return Icons.audiotrack;
    if (t.contains('zip') || t.contains('rar')) return Icons.folder_zip;
    return Icons.insert_drive_file;
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour.toString().padLeft(2, '0');
    final minute = dateTime.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}

// ── Add Members Screen ────────────────────────────────────────────────────────
class _AddMembersScreen extends StatefulWidget {
  final String groupId;
  final GroupProvider groupProvider;
  final BuildContext parentContext;

  const _AddMembersScreen({
    required this.groupId,
    required this.groupProvider,
    required this.parentContext,
  });

  @override
  State<_AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<_AddMembersScreen> {
  List<Map<String, dynamic>> _availableUsers = [];
  final List<Map<String, dynamic>> _selectedUsers = [];
  bool _isLoading = true;
  bool _isAdding = false;

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    final users = await widget.groupProvider.getAvailableUsers(widget.groupId);
    if (mounted) {
      setState(() {
        _availableUsers = users;
        _isLoading = false;
      });
    }
  }

  Future<void> _addMembers() async {
    if (_selectedUsers.isEmpty || _isAdding) return;
    setState(() => _isAdding = true);

    final count = _selectedUsers.length;

    final success = await widget.groupProvider.addMembers(
      widget.groupId,
      _selectedUsers,
    );

    if (!mounted) return;
    Navigator.pop(context);

    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      SnackBar(
        content: Text(
          success
              ? '$count ${AppLocalizations.of(context).membersAddedSuccessfully}'
              : AppLocalizations.of(context).failedAddMember,
        ),
        backgroundColor: success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0e1726),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0e1726),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          AppLocalizations.of(context).addMembers,
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (_selectedUsers.isNotEmpty)
            _isAdding
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TextButton(
                      onPressed: _addMembers,
                      style: TextButton.styleFrom(
                        backgroundColor: const Color(0xFF0084FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      child: Text(
                        '${AppLocalizations.of(context).add} (${_selectedUsers.length})',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF0084FF)),
            )
          : _availableUsers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 48, color: Colors.grey[600]),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context).noUsersAvailableToAdd,
                    style: TextStyle(color: Colors.grey[500], fontSize: 14),
                  ),
                ],
              ),
            )
          : ListView.builder(
              itemCount: _availableUsers.length,
              itemBuilder: (context, index) {
                final user = _availableUsers[index];
                final isSelected = _selectedUsers.any(
                  (u) => u['userId'].toString() == user['userId'].toString(),
                );

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? const Color(0xFF0084FF)
                        : const Color(0xFF1A2332),
                    child: Text(
                      (user['fullName'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(
                    user['fullName'] ?? 'Xxxxxx',
                    style: const TextStyle(color: Colors.white),
                  ),
                  subtitle: Text(
                    '@${user['username'] ?? ''}',
                    style: const TextStyle(
                      color: Color(0xFF0084FF),
                      fontSize: 12,
                    ),
                  ),
                  trailing: isSelected
                      ? const Icon(Icons.check_circle, color: Color(0xFF0084FF))
                      : Icon(Icons.circle_outlined, color: Colors.grey[600]),
                  onTap: () {
                    setState(() {
                      if (isSelected) {
                        _selectedUsers.removeWhere(
                          (u) =>
                              u['userId'].toString() ==
                              user['userId'].toString(),
                        );
                      } else {
                        _selectedUsers.add(user);
                      }
                    });
                  },
                );
              },
            ),
    );
  }
}
