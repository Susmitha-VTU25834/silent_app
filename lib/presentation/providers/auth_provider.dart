import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _name;
  String? _email;
  
  // Dynamic URL detection
  static String get baseUrl {
    if (kIsWeb) {
      return "http://localhost:3000/api/auth";
    } else {
      // Use your PC's actual LAN IP for physical device testing instead of 10.0.2.2 (Emulator only)
      return "http://192.168.31.75:3000/api/auth";
    }
  }

  bool get isAuthenticated => _token != null;
  String? get token => _token;
  String? get userId => _userId;
  String? get name => _name;
  String? get email => _email;

  Future<void> tryAutoLogin() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey('userData')) return;
    
    final userData = json.decode(prefs.getString('userData')!) as Map<String, dynamic>;
    _token = userData['token'];
    _userId = userData['userId'];
    _name = userData['name'];
    _email = userData['email'];
    notifyListeners();
  }

  Future<bool> signup(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );
      if (response.statusCode == 201) {
        return login(email, password);
      } else {
        print("Signup Failed: HTTP ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("Signup Connection Error: $e");
      return false;
    }
  }

  Future<bool> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _token = responseData['token'];
        _userId = responseData['userId'];
        _name = responseData['name'];
        _email = responseData['email'];

        final prefs = await SharedPreferences.getInstance();
        prefs.setString('userData', json.encode({
          'token': _token,
          'userId': _userId,
          'name': _name,
          'email': _email,
        }));

        notifyListeners();
        return true;
      } else {
        print("Login Failed: HTTP ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("Login Connection Error: $e");
      return false;
    }
  }

  Future<void> logout() async {
    _token = null;
    _userId = null;
    _name = null;
    _email = null;
    final prefs = await SharedPreferences.getInstance();
    prefs.remove('userData');
    notifyListeners();
  }
}
