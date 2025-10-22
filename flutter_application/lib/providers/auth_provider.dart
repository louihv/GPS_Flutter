import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userData; 

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;

  void setUser(User user, [Map<String, dynamic>? userData]) {
    _user = user;
    _userData = userData;
    notifyListeners();
  }

  void clearUser() {
    _user = null;
    _userData = null;
    notifyListeners();
  }
}