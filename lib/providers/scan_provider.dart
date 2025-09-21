import 'package:flutter/material.dart';

class ScanProvider extends ChangeNotifier {
  String _scannedText = '';

  String get scannedText => _scannedText;

  void setScannedText(String text) {
    _scannedText = text;
    notifyListeners();
  }

  void clear() {
    _scannedText = '';
    notifyListeners();
  }
}