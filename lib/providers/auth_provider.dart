import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String _username = '';
  String _tradeName = '';
  String _fullName = '';
  String _branchCode = '';
  String _userId = '';

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get tradeName => _tradeName;
  String get fullName => _fullName;
  String get branchCode => _branchCode;
  String get userId => _userId;

  Future<String> login(String username, String password) async {
    final url = Uri.parse('https://igb-fems.com/LIVE/mobile_php/login.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'loginAttempt': 0, // You can track login attempts if you want
          'fromUsername': '',
          'fromPassword': '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        String result = data['result'];

        if (result == "Success") {
          _isLoggedIn = true;
          _username = username;
          _tradeName = data['tradeName'] ?? '';
          _fullName = data['fullName'] ?? '';
          _branchCode = data['branchCode'] ?? '';
          _userId = data['userId'] ?? '';
          notifyListeners();
        }
        return result; // can be Success, NotCorrect, ResetPassword, etc.
      } else {
        return "Error"; // HTTP error
      }
    } catch (e) {
      print('Login error: $e');
      return "Error";
    }
  }

  void logout() {
    // ✅ Clear on logout
    _isLoggedIn = false;
    _username = '';
    _tradeName = '';
    _fullName = '';
    _branchCode = '';
    _userId = '';
    notifyListeners();
  }
}
