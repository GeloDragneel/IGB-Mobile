import 'package:flutter/material.dart';
import '../models/user.dart';

class AppProvider with ChangeNotifier {
  User? user;

  void login(String username) {
    user = User(username: username);
    notifyListeners();
  }

  void logout() {
    user = null;
    notifyListeners();
  }
}