import 'dart:convert';
import 'package:http/http.dart' as http;
import 'api_client.dart';
import '../utils/session.dart';

class AuthApi {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> register(String username, String password) async {
    final res = await _api.post(
      '/auth/register',
      {'username': username, 'password': password},
    );
    return _handleAuthResponse(res);
  }

  Future<Map<String, dynamic>> login(String username, String password) async {
    final res = await _api.post(
      '/auth/login',
      {'username': username, 'password': password},
    );
    return _handleAuthResponse(res);
  }

  Future<Map<String, dynamic>> _handleAuthResponse(http.Response res) async {
    // Debug print to console so we can see what the proxy / backend said
    // (shows up in `flutter run` output)
    // ignore: avoid_print
    print('Auth response status: ${res.statusCode}');
    // ignore: avoid_print
    print('Auth response body: ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);

      // store token locally for session persistence
      final token = data['access_token'];
      if (token is String && token.isNotEmpty) {
        await Session.saveToken(token);
      }

      return data as Map<String, dynamic>;
    }

    // Try to parse detail message
    try {
      final body = jsonDecode(res.body);
      throw Exception(body['detail']?.toString() ?? 'HTTP ${res.statusCode}');
    } catch (_) {
      throw Exception('HTTP ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _api.get('/me');

    // ignore: avoid_print
    print('ME response status: ${res.statusCode}');
    // ignore: avoid_print
    print('ME response body: ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      await Session.saveUser(data);
      return data as Map<String, dynamic>;
    }

    try {
      final body = jsonDecode(res.body);
      throw Exception(body['detail']?.toString() ?? 'HTTP ${res.statusCode}');
    } catch (_) {
      throw Exception('HTTP ${res.statusCode}');
    }
  }
}
