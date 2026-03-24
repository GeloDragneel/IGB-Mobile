import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthProvider extends ChangeNotifier {
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  bool _isLoggedIn = false;
  String _username = '';
  String _tradeName = '';
  String _fullName = '';
  String _branchCode = '';
  String _userId = '';
  String _fromDate = '';
  String _toDate = '';
  String _branchType = '';
  String _clientNum = '';
  String _tin = '';
  String _comId = '';
  String _caid = '';

  bool get isLoggedIn => _isLoggedIn;
  String get username => _username;
  String get tradeName => _tradeName;
  String get fullName => _fullName;
  String get branchCode => _branchCode;
  String get userId => _userId;
  String get fromDate => _fromDate;
  String get toDate => _toDate;
  String get branchType => _branchType;
  String get clientNum => _clientNum;
  String get tin => _tin;
  String get comId => _comId;
  String get caid => _caid;

  set fromDate(String value) {
    _fromDate = value;
    notifyListeners();
  }

  set toDate(String value) {
    _toDate = value;
    notifyListeners();
  }

  set tradeName(String value) {
    _tradeName = value;
    notifyListeners();
  }

  set fullName(String value) {
    _fullName = value;
    notifyListeners();
  }

  Future<String> login(String username, String password) async {
    final url = Uri.parse('https://igb-fems.com/LIVE/mobile_php/login.php');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'username': username,
          'password': password,
          'loginAttempt': 0,
          'fromUsername': '',
          'fromPassword': '',
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String result = data['result'];

        if (result == 'Success') {
          _isLoggedIn = true;
          _username = username;
          _tradeName = data['tradeName'] ?? '';
          _fullName = data['fullName'] ?? '';
          _branchCode = data['branchCode'] ?? '';
          _userId = data['userId']?.toString() ?? '';
          _fromDate = data['fromDate'] ?? '';
          _toDate = data['toDate'] ?? '';
          _branchType = data['branchType'] ?? '';
          _clientNum = data['clientNum'] ?? '';
          _tin = data['TIN'] ?? '';
          _comId = data['comId']?.toString() ?? '';
          _caid = data['CAID']?.toString() ?? '';

          // Store credentials keyed by CAID so each account has its own entry
          if (_caid.isNotEmpty) {
            await _secureStorage.write(
              key: 'biometric_username_$_caid',
              value: username,
            );
            await _secureStorage.write(
              key: 'biometric_password_$_caid',
              value: password,
            );
          }

          notifyListeners();
        }
        return result;
      } else {
        return 'Error';
      }
    } catch (e) {
      debugPrint('Login error: $e');
      return 'Error';
    }
  }

  /// Login with biometric using the selected CAID.
  /// Retrieves the credentials stored for that specific CAID and logs in.
  Future<String> loginWithBiometric({required String caid}) async {
    try {
      final storedUsername = await _secureStorage.read(
        key: 'biometric_username_$caid',
      );
      final storedPassword = await _secureStorage.read(
        key: 'biometric_password_$caid',
      );

      if (storedUsername == null || storedPassword == null) {
        debugPrint('No stored credentials found for CAID: $caid');
        return 'NoBiometric';
      }

      return await login(storedUsername, storedPassword);
    } catch (e) {
      debugPrint('Biometric login error: $e');
      return 'Error';
    }
  }

  void logout() {
    _isLoggedIn = false;
    _username = '';
    _tradeName = '';
    _fullName = '';
    _branchCode = '';
    _userId = '';
    _fromDate = '';
    _toDate = '';
    _branchType = '';
    _clientNum = '';
    _tin = '';
    _comId = '';
    _caid = '';
    notifyListeners();
  }
}
