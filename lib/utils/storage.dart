import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lift.dart';
import '../models/user_account.dart';
import 'auth.dart';

class Storage {
  // ===================== LIFTS (now per-user) =====================
  // Old global keys (kept only for one-time migration):
  static const String oldGlobalLiftsKey = 'lifts';
  static const String dataVersionKey = 'data_version';
  static const int currentDataVersion = 3;

  // Per-user lifts live under: lifts_v3_<userId>
  static String _userLiftsKey(String userId) => 'lifts_v3_$userId';

  /// Public: load lifts for the CURRENT user (throws if not signed in)
  static Future<List<Lift>> loadLifts() async {
    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('No user signed in. Cannot load lifts.');
    }
    return _loadLiftsForUser(user.id);
  }

  /// Public: save lifts for the CURRENT user (throws if not signed in)
  static Future<void> saveLifts(List<Lift> lifts) async {
    final user = await getCurrentUser();
    if (user == null) {
      throw Exception('No user signed in. Cannot save lifts.');
    }
    await _saveLiftsForUser(user.id, lifts);
  }

  /// Internal: load per-user lifts with a one-time migration from old global key
  static Future<List<Lift>> _loadLiftsForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final perUserKey = _userLiftsKey(userId);
    String? liftsString = prefs.getString(perUserKey);

    // One-time migration: if per-user empty but old global exists, move it over
    if ((liftsString == null || liftsString == '[]') &&
        prefs.getString(oldGlobalLiftsKey) != null) {
      final migrated = await _migrateGlobalToUser(userId);
      if (migrated) {
        liftsString = prefs.getString(perUserKey);
      }
    }

    final int storedVersion = prefs.getInt('${dataVersionKey}_$userId') ?? 1;

    // Migrate structure if needed
    if (storedVersion < currentDataVersion) {
      await _migrateData(prefs, liftsString, storedVersion, userId);
      return _loadLiftsForUser(userId); // re-read after migration
    }

    // Initialize defaults if empty
    if (liftsString == null || liftsString == '[]') {
      final defaults = _createDefaultLifts();
      await _saveLiftsForUser(userId, defaults);
      return defaults;
    }

    final List<dynamic> jsonList = jsonDecode(liftsString);
    final loaded = jsonList.map((e) => Lift.fromMap(e)).toList();
    if (loaded.isEmpty) {
      final defaults = _createDefaultLifts();
      await _saveLiftsForUser(userId, defaults);
      return defaults;
    }
    return loaded;
  }

  static Future<void> _saveLiftsForUser(String userId, List<Lift> lifts) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = lifts.map((e) => e.toMap()).toList();
    await prefs.setString(_userLiftsKey(userId), jsonEncode(jsonList));
    await prefs.setInt('${dataVersionKey}_$userId', currentDataVersion);
  }

  static Future<bool> _migrateGlobalToUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final old = prefs.getString(oldGlobalLiftsKey);
    if (old == null) return false;
    // Write the old global JSON into the per-user key, then clear the global
    await prefs.setString(_userLiftsKey(userId), old);
    await prefs.remove(oldGlobalLiftsKey);
    // Note: we do NOT touch the old data_version key; next load will migrate if needed
    return true;
  }

  static Future<void> _migrateData(SharedPreferences prefs, String? liftsString, int oldVersion, String userId) async {
    if (liftsString == null) {
      // Nothing to migrate; seed defaults
      await _saveLiftsForUser(userId, _createDefaultLifts());
      await prefs.setInt('${dataVersionKey}_$userId', currentDataVersion);
      return;
    }

    final List<dynamic> jsonList = jsonDecode(liftsString);
    final List<Lift> migratedLifts = [];

    for (var json in jsonList) {
      final lift = Lift.fromMap(json);

      // Version 1→2 migration: convert current PR to first historical record
      if (oldVersion == 1 && lift.prHistory.isEmpty) {
        final initialRecord = PRRecord(
          strengthPR: lift.strengthPR,
          endurancePR: lift.endurancePR,
          date: lift.lastUpdated,
          notes: 'Initial PR',
        );
        lift.prHistory.add(initialRecord);
      }

      migratedLifts.add(lift);
    }

    await _saveLiftsForUser(userId, migratedLifts);
    await prefs.setInt('${dataVersionKey}_$userId', currentDataVersion);
  }

  static List<Lift> _createDefaultLifts() {
    final now = DateTime.now();

    return [
      Lift(
        name: 'Squat',
        strengthPR: PRSet(weight: 0, reps: 1),
        endurancePR: PRSet(weight: 0, reps: 1),
        lastUpdated: now,
        prHistory: [
          PRRecord(
            strengthPR: PRSet(weight: 0, reps: 1),
            endurancePR: PRSet(weight: 0, reps: 1),
            date: now,
            notes: 'Initial PR',
          ),
        ],
      ),
      Lift(
        name: 'Barbell Bench Press',
        strengthPR: PRSet(weight: 0, reps: 1),
        endurancePR: PRSet(weight: 0, reps: 1),
        lastUpdated: now,
        prHistory: [
          PRRecord(
            strengthPR: PRSet(weight: 0, reps: 1),
            endurancePR: PRSet(weight: 0, reps: 1),
            date: now,
            notes: 'Initial PR',
          ),
        ],
      ),
      Lift(
        name: 'Incline Bench Press',
        strengthPR: PRSet(weight: 0, reps: 1),
        endurancePR: PRSet(weight: 0, reps: 1),
        lastUpdated: now,
        prHistory: [
          PRRecord(
            strengthPR: PRSet(weight: 0, reps: 1),
            endurancePR: PRSet(weight: 0, reps: 1),
            date: now,
            notes: 'Initial PR',
          ),
        ],
      ),
    ];
  }

  // ===================== USERS (unchanged interface, slight addition) =====================
  static const String usersKey = 'users_v1';
  static const String currentUserIdKey = 'current_user_id_v1';

  static Future<List<UserAccount>> loadUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(usersKey);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> list = jsonDecode(raw);
    return list.map((e) => UserAccount.fromMap(e)).toList();
  }

  static Future<void> saveUsers(List<UserAccount> users) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      usersKey,
      jsonEncode(users.map((u) => u.toMap()).toList()),
    );
  }

  static Future<UserAccount?> getCurrentUser() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(currentUserIdKey);
    if (id == null) return null;
    final users = await loadUsers();
    try {
      return users.firstWhere((u) => u.id == id);
    } catch (_) {
      return null;
    }
  }

  static Future<void> setCurrentUser(String? userId) async {
    final prefs = await SharedPreferences.getInstance();
    if (userId == null) {
      await prefs.remove(currentUserIdKey);
    } else {
      await prefs.setString(currentUserIdKey, userId);
    }
  }

  /// Register user AND seed that user's lifts with defaults.
  static Future<UserAccount> registerUser({
    required String username,
    required String password,
  }) async {
    final users = await loadUsers();
    final uname = username.trim();
    if (uname.isEmpty || password.isEmpty) {
      throw Exception('Username and password are required.');
    }
    final exists = users.any((u) => u.username.toLowerCase() == uname.toLowerCase());
    if (exists) {
      throw Exception('Username already taken.');
    }

    final salt = Auth.generateSalt();
    final hash = Auth.hashPassword(password, salt);
    final id = Auth.userIdFromUsername(uname);
    final now = DateTime.now();

    final user = UserAccount(
      id: id,
      username: uname,
      passwordHash: hash,
      salt: salt,
      createdAt: now,
      updatedAt: now,
    );

    users.add(user);
    await saveUsers(users);
    await setCurrentUser(user.id);

    // Seed this new user's lifts (per-user)
    await _saveLiftsForUser(user.id, _createDefaultLifts());
    return user;
  }

  static Future<UserAccount?> authenticate({
    required String username,
    required String password,
  }) async {
    final users = await loadUsers();
    final uname = username.trim();
    final match = users.where((u) => u.username.toLowerCase() == uname.toLowerCase());
    if (match.isEmpty) return null;
    final user = match.first;

    final ok = Auth.verifyPassword(
      password: password,
      salt: user.salt,
      passwordHash: user.passwordHash,
    );
    if (!ok) return null;

    await setCurrentUser(user.id);
    return user;
  }

  static Future<bool> changePassword({
    required String userId,
    required String oldPassword,
    required String newPassword,
  }) async {
    final users = await loadUsers();
    final idx = users.indexWhere((u) => u.id == userId);
    if (idx < 0) return false;
    final user = users[idx];

    final validOld = Auth.verifyPassword(
      password: oldPassword,
      salt: user.salt,
      passwordHash: user.passwordHash,
    );
    if (!validOld) return false;

    final newSalt = Auth.generateSalt();
    final newHash = Auth.hashPassword(newPassword, newSalt);

    users[idx] = UserAccount(
      id: user.id,
      username: user.username,
      passwordHash: newHash,
      salt: newSalt,
      createdAt: user.createdAt,
      updatedAt: DateTime.now(),
    );
    await saveUsers(users);
    return true;
  }
}
