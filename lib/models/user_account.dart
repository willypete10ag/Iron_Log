import 'dart:convert';

class UserAccount {
  final String id;           // stable id (sha256(username))
  final String username;     // unique (case-insensitive)
  final String passwordHash; // sha256(salt + password)
  final String salt;         // base64
  final DateTime createdAt;
  final DateTime updatedAt;

  UserAccount({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'username': username,
        'passwordHash': passwordHash,
        'salt': salt,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  factory UserAccount.fromMap(Map<String, dynamic> map) => UserAccount(
        id: map['id'] ?? '',
        username: map['username'] ?? '',
        passwordHash: map['passwordHash'] ?? '',
        salt: map['salt'] ?? '',
        createdAt:
            DateTime.tryParse(map['createdAt'] ?? '') ?? DateTime.now(),
        updatedAt:
            DateTime.tryParse(map['updatedAt'] ?? '') ?? DateTime.now(),
      );

  String toJson() => jsonEncode(toMap());

  factory UserAccount.fromJson(String source) =>
      UserAccount.fromMap(jsonDecode(source));
}
