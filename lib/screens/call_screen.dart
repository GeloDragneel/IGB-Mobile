import 'package:flutter/material.dart';
import '../models/chat.dart';

class CallScreen extends StatelessWidget {
  final Chat chat;
  final bool isVideo;

  const CallScreen({super.key, required this.chat, required this.isVideo});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          if (isVideo)
            Container(
              color: Colors.black,
              child: const Center(
                child: Text(
                  "Video Stream Here",
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ),

          // Top info
          Positioned(
            top: 60,
            left: 0,
            right: 0,
            child: Column(
              children: [
                CircleAvatar(radius: 40, child: Text(chat.name[0])),
                const SizedBox(height: 10),
                Text(
                  chat.name,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Text(
                  isVideo ? "Video Calling..." : "Voice Calling...",
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),

          // Bottom controls
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _circleButton(Icons.mic, Colors.grey),
                const SizedBox(width: 20),
                _circleButton(
                  Icons.call_end,
                  Colors.red,
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                const SizedBox(width: 20),
                if (isVideo) _circleButton(Icons.videocam, Colors.grey),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, Color color, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 60,
        height: 60,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        child: Icon(icon, color: Colors.white),
      ),
    );
  }
}
