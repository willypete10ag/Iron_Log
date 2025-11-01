import 'dart:convert';
import 'package:http/http.dart' as http;

import 'api_client.dart';
import '../utils/session.dart';
import '../utils/storage.dart';
import '../services/sync_service.dart';

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
    // Debug
    print('Auth response status: ${res.statusCode}');
    print('Auth response body: ${res.body}');

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body) as Map<String, dynamic>;

      // 1. Save token so ApiClient can send Authorization header going forward
      final token = data['access_token'];
      if (token is String && token.isNotEmpty) {
        await Session.saveToken(token);
      }

      // 2. Save user info for this session (so Storage knows which keys to use)
      // We expect backend to return:
      // {
      //   "access_token": "...",
      //   "user_id": "hex...",
      //   "username": "test10"
      // }
      final userObj = {
        'id': data['user_id'],
        'username': data['username'],
      };
      await Session.saveUser(userObj);

      // 3. Try to pull from server for this user
      final syncService = SyncService();
      bool pulledOkay = false;
      try {
        await syncService.pullFromServer();
        pulledOkay = true;
        print('✅ pullFromServer after login succeeded');
      } catch (e) {
        print('❌ pullFromServer after login failed: $e');
      }

      // 4. Bootstrap case:
      // If server had nothing for this user, we just pulled an "empty" state.
      // BUT we might already have local lifts (like defaults + edits).
      //
      // So the rule is:
      // - If we *successfully* pulled
      // - AND after that pull, local lifts are still basically empty / defaults-only?
      //      -> do nothing, that's fine.
      // - ELSE IF we failed to pull OR server was empty but we have meaningful local data:
      //      -> push local up so the server becomes source of truth for future logins.
      //
      // We'll approximate "meaningful local data" as: we have >0 lifts locally.
      // (Later we could get fancier and detect if it's ONLY the 3 pinned with all zeros,
      //  but this is already a huge step forward.)
      try {
        final localLifts = await Storage.loadLifts();
        final hasAnyLocal = localLifts.isNotEmpty;

        // We only consider pushing if there's anything local at all.
        // If pull succeeded and local is empty, that means server is also empty for this brand new user,
        // so it's fine not to push.
        //
        // But if pull failed OR we actually *do* have some local stuff (like edited Squat numbers),
        // push it now so it's captured in the backend for the next login.
        if (!pulledOkay && hasAnyLocal) {
          print('ℹ️ pull failed, attempting pushToServer to seed backend...');
          await syncService.pushToServer();
          print('✅ pushToServer after login bootstrap complete');
        } else if (pulledOkay && hasAnyLocal) {
          // pulledOkay == true means we just overwrote local with whatever server had
          // BUT: Storage.loadLifts() we just called above already reflects latest local state,
          // which after pullFromServer() should match server state unless server was empty.
          //
          // If server was empty, localLifts will basically be the default template for that user.
          // Pushing that is actually desirable: it seeds their account in the backend.
          print('ℹ️ seeding backend with local lifts after fresh login...');
          await syncService.pushToServer();
          print('✅ backend seeded for this user');
        }
      } catch (e) {
        print('❌ bootstrap sync push after login failed: $e');
      }

      return data;
    }

    // If not 200, try to surface server's "detail" field as the error
    try {
      final body = jsonDecode(res.body);
      throw Exception(body['detail']?.toString() ?? 'HTTP ${res.statusCode}');
    } catch (_) {
      throw Exception('HTTP ${res.statusCode}');
    }
  }

  Future<Map<String, dynamic>> me() async {
    final res = await _api.get('/me');

    print('ME response status: ${res.statusCode}');
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
