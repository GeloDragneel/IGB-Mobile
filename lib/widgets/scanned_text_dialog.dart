import 'package:flutter/material.dart';

class ScannedTextDialog extends StatelessWidget {
  final String scannedText;
  final String title;

  const ScannedTextDialog({
    super.key,
    required this.scannedText,
    required this.title,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: const Color(0xFF121826),
      title: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: Container(
        width: double.maxFinite,
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.6,
        ),
        child: SingleChildScrollView(
          child: Text(
            scannedText,
            style: const TextStyle(
              fontFamily: 'monospace',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Close',
            style: TextStyle(color: Color(0xFF8f72ec)),
          ),
        ),
      ],
    );
  }

  static void show(BuildContext context, String scannedText, String title) {
    showDialog(
      context: context,
      builder: (context) => ScannedTextDialog(
        scannedText: scannedText,
        title: title,
      ),
    );
  }
}