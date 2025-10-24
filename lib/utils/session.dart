import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class Session {
  static const _kToken = 'remote_access_token_v1';
  static const _kUserJson = 'remote_user_v1';

  static Future<void> saveToken(String token) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kToken, token);
  }

  static Future<String?> get token async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kToken);
  }

  static Future<void> clear() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kToken);
    await p.remove(_kUserJson);
  }

  static Future<void> saveUser(Map<String, dynamic> user) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kUserJson, jsonEncode(user));
  }

  static Future<Map<String, dynamic>?> get user async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString(_kUserJson);
    if (s == null) return null;
    return jsonDecode(s) as Map<String, dynamic>;
  }
}
