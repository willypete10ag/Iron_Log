import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lift.dart';
import '../utils/session.dart';

class PendingDeletion {
  final String kind; // "lift" or "pr"
  final String liftName;
  final String? date; // only for kind == "pr"
  final String deletedAtIso;

  PendingDeletion({
    required this.kind,
    required this.liftName,
    this.date,
    required this.deletedAtIso,
  });

  Map<String, dynamic> toMap() {
    return {
      'kind': kind,
      'lift_name': liftName,
      'date': date,
      'deleted_at': deletedAtIso,
    };
  }

  factory PendingDeletion.fromMap(Map<String, dynamic> map) {
    return PendingDeletion(
      kind: map['kind'] ?? 'lift',
      liftName: map['lift_name'] ?? '',
      date: map['date'],
      deletedAtIso:
          map['deleted_at'] ?? DateTime.now().toIso8601String(),
    );
  }
}

class Storage {
  static const int currentDataVersion = 3;

  /// These are the "pinned" lifts that must always exist for every user.
  /// They cannot be deleted or renamed.
  static const List<String> _pinnedLiftNames = [
    'Squat',
    'Barbell Bench Press',
    'Incline Bench Press',
  ];

  /// Helper that tells us what keys to use for the *current* signed-in user.
  static Future<_UserKeys> _getUserKeys() async {
    final userInfo = await Session.user;
    final userId = (userInfo?['id'] ?? '_anon').toString();
    return _UserKeys(
      liftsKey: 'lifts_$userId',
      dataVersionKey: 'data_version_$userId',
      deletedKey: 'deleted_$userId',
    );
  }

  static Future<List<Lift>> loadLifts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();

    final liftsString = prefs.getString(keys.liftsKey);
    final int storedVersion = prefs.getInt(keys.dataVersionKey) ?? 1;

    // CASE 1: completely new user
    if (liftsString == null || liftsString == '[]') {
      final defaultLifts = _createDefaultLifts();
      await _saveLiftsInternal(prefs, keys, defaultLifts);
      return defaultLifts;
    }

    // CASE 2: migration path
    if (storedVersion < currentDataVersion) {
      await _migrateData(prefs, liftsString, storedVersion, keys);
      return loadLifts();
    }

    // CASE 3: normal load
    final List<dynamic> jsonList = jsonDecode(liftsString);
    List<Lift> loadedLifts =
        jsonList.map((e) => Lift.fromMap(e)).toList();

    // Edge case: empty after decode
    if (loadedLifts.isEmpty) {
      final defaultLifts = _createDefaultLifts();
      await _saveLiftsInternal(prefs, keys, defaultLifts);
      return defaultLifts;
    }

    // Ensure pinned lifts are there
    final ensured = _ensurePinnedLifts(loadedLifts);

    if (ensured.length != loadedLifts.length) {
      await _saveLiftsInternal(prefs, keys, ensured);
      return ensured;
    }

    return ensured;
  }

  static Future<void> saveLifts(List<Lift> lifts) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();

    // Re-add pinned if someone tried to delete them
    final sanitized = _ensurePinnedLifts(lifts);

    await _saveLiftsInternal(prefs, keys, sanitized);
  }

  /// Load any pending deletions for this user that haven't been pushed yet.
  static Future<List<PendingDeletion>> loadPendingDeletions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();
    final raw = prefs.getString(keys.deletedKey);
    if (raw == null || raw.isEmpty) return [];
    final List<dynamic> jsonList = jsonDecode(raw);
    return jsonList
        .map((e) => PendingDeletion.fromMap(e as Map<String, dynamic>))
        .toList();
  }

  /// Overwrite pending deletions list.
  static Future<void> savePendingDeletions(
      List<PendingDeletion> deletions) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();
    final jsonList = deletions.map((d) => d.toMap()).toList();
    await prefs.setString(keys.deletedKey, jsonEncode(jsonList));
  }

  /// Append a new pending deletion (e.g. when you delete a custom lift).
  static Future<void> addPendingLiftDeletion(String liftName) async {
    final deletions = await loadPendingDeletions();
    deletions.add(
      PendingDeletion(
        kind: 'lift',
        liftName: liftName,
        deletedAtIso: DateTime.now().toIso8601String(),
      ),
    );
    await savePendingDeletions(deletions);
  }

  /// After a successful sync push, clear deletions because server is aware.
  static Future<void> clearPendingDeletions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();
    await prefs.remove(keys.deletedKey);
  }

  /// Internal helper so we consistently bump version + write lifts
  static Future<void> _saveLiftsInternal(
    SharedPreferences prefs,
    _UserKeys keys,
    List<Lift> lifts,
  ) async {
    final jsonList = lifts.map((e) => e.toMap()).toList();
    await prefs.setString(keys.liftsKey, jsonEncode(jsonList));
    await prefs.setInt(keys.dataVersionKey, currentDataVersion);
  }

  /// Migration only runs when we already have previous data.
  static Future<void> _migrateData(
    SharedPreferences prefs,
    String liftsString,
    int oldVersion,
    _UserKeys keys,
  ) async {
    final List<dynamic> jsonList = jsonDecode(liftsString);
    final List<Lift> migratedLifts = [];

    for (var json in jsonList) {
      final lift = Lift.fromMap(json);

      // Version 1→2 migration: seed first PR into history
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

    final ensured = _ensurePinnedLifts(migratedLifts);

    await _saveLiftsInternal(prefs, keys, ensured);
  }

  /// Guarantees the 3 pinned lifts exist in the list.
  static List<Lift> _ensurePinnedLifts(List<Lift> current) {
    final List<Lift> result = List<Lift>.from(current);
    final existingNames = result.map((l) => l.name).toSet();

    for (final pinnedName in _pinnedLiftNames) {
      if (!existingNames.contains(pinnedName)) {
        result.add(_newPinnedLiftTemplate(pinnedName));
      }
    }

    return result;
  }

  static Lift _newPinnedLiftTemplate(String name) {
    final now = DateTime.now();
    final baseStrength = PRSet(weight: 0, reps: 1);
    final baseEndurance = PRSet(weight: 0, reps: 1);

    return Lift(
      name: name,
      strengthPR: baseStrength,
      endurancePR: baseEndurance,
      lastUpdated: now,
      prHistory: [
        PRRecord(
          strengthPR: baseStrength,
          endurancePR: baseEndurance,
          date: now,
          notes: 'Initial PR',
        ),
      ],
    );
  }

  /// Used for a brand-new account.
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
}

class _UserKeys {
  final String liftsKey;
  final String dataVersionKey;
  final String deletedKey;

  _UserKeys({
    required this.liftsKey,
    required this.dataVersionKey,
    required this.deletedKey,
  });
}
