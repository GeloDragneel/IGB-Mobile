import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:provider/provider.dart';
import '../providers/scan_provider.dart';
import '../widgets/navigation_drawer.dart';

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  File? _image;
  bool _isProcessing = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.camera);
    if (picked != null) {
      setState(() {
        _image = File(picked.path);
        _isProcessing = true;
      });
      await _performOCR(_image!);
    }
  }

  Future<void> _performOCR(File imageFile) async {
    final inputImage = InputImage.fromFile(imageFile);
    final textRecognizer = TextRecognizer();
    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    String scannedText = recognizedText.text;
    Provider.of<ScanProvider>(context, listen: false).setScannedText(scannedText);
    textRecognizer.close();
    setState(() {
      _isProcessing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final scannedText = Provider.of<ScanProvider>(context).scannedText;
    return Scaffold(
      appBar: AppBar(title: Text('Scan')),
      drawer: AppDrawer(selectedIndex: 2),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            ElevatedButton.icon(
              icon: Icon(Icons.camera_alt),
              label: Text('Scan Image'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFF8f72ec),
                foregroundColor: Colors.white,
              ),
              onPressed: _isProcessing ? null : _pickImage,
            ),
            if (_isProcessing) ...[
              SizedBox(height: 20),
              CircularProgressIndicator(color: Colors.white),
            ],
            if (_image != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Image.file(_image!, height: 180),
              ),
            if (scannedText.isNotEmpty)
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: EdgeInsets.all(12),
                  color: Color(0xFF101222),
                  child: SingleChildScrollView(
                    child: Text(
                      scannedText,
                      style: TextStyle(fontFamily: 'monospace', fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}