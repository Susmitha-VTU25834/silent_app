import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider with ChangeNotifier {
  String? _token;
  String? _userId;
  String? _name;
  String? _email;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    clientId: '842784249407-lpti9qb3ctsa2fu2p2uc1us1hbqvej90.apps.googleusercontent.com',
    scopes: ['email', 'profile'],
  );
  
  // Toggle to switch between local Wi-Fi testing and public cloud deployment
  static const bool isProduction = true;
  static const String prodUrl = "https://silent-app.onrender.com/api/auth";
  static const String localUrl = "http://10.0.2.2:3000/api/auth";

  static String get baseUrl {
    if (isProduction) {
      return prodUrl;
    }
    if (kIsWeb) {
      return "http://localhost:3000/api/auth";
    } else {
      return localUrl;
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

  Future<Map<String, dynamic>> sendOtp(String email) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/send-otp'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email}),
      );
      final responseData = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true,
          'otp': responseData['otp'],
          'message': responseData['message'] ?? 'OTP sent successfully',
        };
      } else {
        return {
          'success': false,
          'message': responseData['error'] ?? 'Failed to send OTP',
        };
      }
    } catch (e) {
      print("Send OTP Connection Error: $e");
      return {
        'success': false,
        'message': 'Connection error occurred. Please try again.',
      };
    }
  }

  Future<Map<String, dynamic>> signup(String name, String email, String password, String otp) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/signup'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'name': name,
          'email': email,
          'password': password,
          'otp': otp,
        }),
      );
      final responseData = json.decode(response.body);
      if (response.statusCode == 201) {
        final loginSuccess = await login(email, password);
        return {
          'success': loginSuccess,
          'message': 'Signup successful!',
        };
      } else {
        print("Signup Failed: HTTP ${response.statusCode} - ${response.body}");
        return {
          'success': false,
          'message': responseData['error'] ?? 'Signup failed',
        };
      }
    } catch (e) {
      print("Signup Connection Error: $e");
      return {
        'success': false,
        'message': 'Connection error occurred. Please try again.',
      };
    }
  }

  Future<bool> loginWithGoogle() async {
    try {
      // Trigger Google Sign-In flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        print("Google Sign-In aborted by user.");
        return false;
      }

      // Obtain authentication details from request
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        print("Google Sign-In failed: idToken is null.");
        return false;
      }

      // Send idToken to our backend
      final response = await http.post(
        Uri.parse('$baseUrl/google'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'idToken': idToken,
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _token = responseData['token'];
        _userId = responseData['userId'];
        _name = responseData['name'];
        _email = responseData['email'];

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userData', json.encode({
          'token': _token,
          'userId': _userId,
          'name': _name,
          'email': _email,
        }));

        notifyListeners();
        return true;
      } else {
        print("Google Auth Failed on Backend: HTTP ${response.statusCode} - ${response.body}");
        return false;
      }
    } catch (e) {
      print("Google Sign-In Connection/OAuth Error: $e");
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
