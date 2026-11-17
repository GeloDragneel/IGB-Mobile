import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../services/messenger_api.dart';
import '../screens/messenger_list_screen.dart';

/// Floating chat button – opens the web Messenger chats. Employees only.
class ChatBubble extends StatefulWidget {
  final double bottom; // move it when a screen has its own + button
  final double right;
  const ChatBubble({super.key, this.bottom = 16, this.right = 16});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> {
  int _unread = 0;
  bool _allowed = true; // false after the server says "employees only"
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    MessengerApi.employeeId = Provider.of<AuthProvider>(
      context,
      listen: false,
    ).employeeId;
    if (MessengerApi.isEmployee) {
      _check();
      // also tells the server "I'm online" (like the web, every ~20 s)
      _poll = Timer.periodic(const Duration(seconds: 20), (_) => _check());
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _check() async {
    try {
      final d = await MessengerApi.get('summary');
      if (mounted) setState(() => _unread = (d['unread'] ?? 0) as int);
    } on MessengerError catch (e) {
      if (e.status == 403 && mounted) {
        _poll?.cancel();
        setState(() => _allowed = false);
      }
    } catch (_) {}
  }

  Future<void> _open() async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MessengerListScreen()),
    );
    _check();
  }

  @override
  Widget build(BuildContext context) {
    if (!MessengerApi.isEmployee || !_allowed) return const SizedBox.shrink();
    return Positioned(
      right: widget.right,
      bottom: widget.bottom,
      child: GestureDetector(
        onTap: _open,
        child: Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            color: const Color(0xFF4F46E5),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4F46E5).withOpacity(0.35),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              const Center(
                child: Icon(Icons.chat_rounded, color: Colors.white, size: 26),
              ),
              if (_unread > 0)
                Positioned(
                  right: -2,
                  top: -2,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: 20,
                      minHeight: 20,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 5),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Text(
                      _unread > 99 ? '99+' : '$_unread',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
