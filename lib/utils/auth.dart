import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';

class Auth {
  static String _hash(String input) {
    final bytes = utf8.encode(input);
    return sha256.convert(bytes).toString();
  }

  /// Generate random salt, base64-encoded
  static String generateSalt({int length = 16}) {
    final rand = Random.secure();
    final List<int> bytes = List<int>.generate(length, (_) => rand.nextInt(256));
    return base64Encode(bytes);
  }

  /// Derive an id from username (stable, for local-only use)
  static String userIdFromUsername(String username) {
    return _hash(username.trim().toLowerCase());
  }

  static String hashPassword(String password, String salt) {
    return _hash('$salt::$password');
  }

  static bool verifyPassword({
    required String password,
    required String salt,
    required String passwordHash,
  }) {
    return hashPassword(password, salt) == passwordHash;
  }
}
