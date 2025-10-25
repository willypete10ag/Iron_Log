import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/env.dart';
import '../utils/session.dart';

class ApiClient {
  final String baseUrl;
  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? Env.apiBaseUrl;

  Future<http.Response> post(String path, Map<String, dynamic> body) async {
    final token = await Session.token;
    final uri = Uri.parse('$baseUrl$path');

    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    final jsonBody = jsonEncode(body);

    // Debug to console to confirm what we're sending
    // ignore: avoid_print
    print('POST $uri');
    // ignore: avoid_print
    print('Headers: $headers');
    // ignore: avoid_print
    print('Body: $jsonBody');

    return http.post(
      uri,
      headers: headers,
      body: jsonBody,
    );
  }

  Future<http.Response> get(String path) async {
    final token = await Session.token;
    final uri = Uri.parse('$baseUrl$path');

    final headers = <String, String>{};
    if (token != null) {
      headers['Authorization'] = 'Bearer $token';
    }

    // ignore: avoid_print
    print('GET $uri');
    // ignore: avoid_print
    print('Headers: $headers');

    return http.get(
      uri,
      headers: headers,
    );
  }
}
