import 'package:flutter/material.dart';

class ExtractedDataScreen extends StatelessWidget {
  const ExtractedDataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final String text = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(title: Text("Extracted Text")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(child: Text(text)),
      ),
    );
  }
}
