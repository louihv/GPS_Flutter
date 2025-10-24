import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:firebase_database/firebase_database.dart';

class AuthProvider extends ChangeNotifier {
  firebase_auth.User? _user;
  Map<String, dynamic>? _userData;
  final _auth = firebase_auth.FirebaseAuth.instance;

  firebase_auth.User? get user => _user;
  Map<String, dynamic>? get userData => _userData;
  String? get role {
    final baseRole = _userData?['role'] as String? ?? 'N/A';
    final adminPosition = _userData?['adminPosition'] as String?;
    if (adminPosition != null && adminPosition != 'N/A') {
      return baseRole != 'N/A' ? '$baseRole | $adminPosition' : adminPosition;
    }
    return baseRole;
  }
  bool get isAbAdmin => role?.contains('AB ADMIN') ?? false;
  bool get isAbvn => role?.contains('ABVN') ?? false;

  AuthProvider() {
    // Listen to auth state changes
    _auth.authStateChanges().listen((firebase_auth.User? user) async {
      if (user == null) {
        _user = null;
        _userData = null;
      } else {
        _user = user;
        await loadUserData();
      }
      notifyListeners();
    });
  }

  void setUser(firebase_auth.User user, [Map<String, dynamic>? userData]) {
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

    try {
      final snapshot = await FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(_user!.uid)
          .get();

      if (snapshot.exists) {
        final data = Map<String, dynamic>.from(snapshot.value as Map);
        // Ensure all expected fields are included, with fallbacks
        _userData = {
          'role': data['role'] ?? 'N/A',
          'adminPosition': data['adminPosition'] ?? 'N/A',
          'organization': data['organization'] ?? 'Admin',
          'email': data['email'] ?? _user!.email ?? 'N/A',
          'mobile': data['mobile'] ?? 'N/A',
          'contactPerson': data['contactPerson'] ??
              (data['firstName'] != null || data['lastName'] != null
                  ? '${data['firstName'] ?? ''} ${data['lastName'] ?? ''}'.trim()
                  : 'Unknown'),
          'address': data['address'] != null
              ? Map<String, dynamic>.from(data['address'])
              : {
                  'barangay': 'N/A',
                  'city': 'N/A',
                  'province': 'N/A',
                  'region': 'N/A',
                },
          'profilePicture': data['profilePicture'] ?? '',
          'terms_agreed_version': data['terms_agreed_version'] ?? 0,
          'password_needs_reset': data['password_needs_reset'] ?? false,
        };
        setUser(_user!, _userData);
      } else {
        // Fallback data if no user document exists
        _userData = {
          'role': 'N/A',
          'adminPosition': 'N/A',
          'organization': 'Admin',
          'email': _user!.email ?? 'N/A',
          'mobile': 'N/A',
          'contactPerson': 'Unknown',
          'address': {
            'barangay': 'N/A',
            'city': 'N/A',
            'province': 'N/A',
            'region': 'N/A',
          },
          'profilePicture': '',
          'terms_agreed_version': 0,
          'password_needs_reset': false,
        };
        setUser(_user!, _userData);
      }
    } catch (e) {
      print('Error loading user data: $e');
      _userData = {
        'role': 'N/A',
        'adminPosition': 'N/A',
        'organization': 'Admin',
        'email': _user!.email ?? 'N/A',
        'mobile': 'N/A',
        'contactPerson': 'Unknown',
        'address': {
          'barangay': 'N/A',
          'city': 'N/A',
          'province': 'N/A',
          'region': 'N/A',
        },
        'profilePicture': '',
        'terms_agreed_version': 0,
        'password_needs_reset': false,
      };
      setUser(_user!, _userData);
    }
    notifyListeners();
  }

  Future<void> logout() async {
    if (_user != null) {
      try {
        await FirebaseDatabase.instance
            .ref()
            .child('users')
            .child(_user!.uid)
            .update({
          'lastLogout': DateTime.now().toIso8601String(),
        });
      } catch (e) {
        print('Error updating lastLogout: $e');
      }
    }
    await _auth.signOut();
    clearUser();
  }
}