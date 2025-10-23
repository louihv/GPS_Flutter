// providers/auth_provider.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class AuthProvider extends ChangeNotifier {
  User? _user;
  Map<String, dynamic>? _userData;   // <-- contains the whole user doc from RTDB

  User? get user => _user;
  Map<String, dynamic>? get userData => _userData;

  String? get role => _userData?['role'] as String?;
  bool get isAbAdmin => role == 'AB ADMIN';

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

  Future<void> loadUserData() async {
    if (_user == null) return;

    final snapshot = await FirebaseDatabase.instance
        .ref()
        .child('users')
        .child(_user!.uid)
        .get();

    if (snapshot.exists) {
      final data = Map<String, dynamic>.from(snapshot.value as Map);
      setUser(_user!, data);
    }
  }
}