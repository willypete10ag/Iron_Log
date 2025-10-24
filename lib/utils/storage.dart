import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/lift.dart';
import '../utils/session.dart';

class Storage {
  static const int currentDataVersion = 3;

  /// Helper that tells us what keys to use for the *current* signed-in user.
  static Future<_UserKeys> _getUserKeys() async {
    final userInfo = await Session.user;
    final userId = (userInfo?['id'] ?? '_anon').toString();
    return _UserKeys(
      liftsKey: 'lifts_$userId',
      dataVersionKey: 'data_version_$userId',
    );
  }

  static Future<List<Lift>> loadLifts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();

    final liftsString = prefs.getString(keys.liftsKey);
    final int storedVersion = prefs.getInt(keys.dataVersionKey) ?? 1;

    // CASE 1: completely new user, nothing stored yet
    // We should NOT try to migrate. We just bootstrap defaults and write version.
    if (liftsString == null || liftsString == '[]') {
      final defaultLifts = _createDefaultLifts();
      await _saveLiftsInternal(prefs, keys, defaultLifts);
      return defaultLifts;
    }

    // CASE 2: we DO have data, but maybe it's older version
    if (storedVersion < currentDataVersion) {
      await _migrateData(prefs, liftsString, storedVersion, keys);
      // after migration, load again (now version will be updated)
      return loadLifts();
    }

    // CASE 3: normal load
    final List<dynamic> jsonList = jsonDecode(liftsString);
    final loadedLifts = jsonList.map((e) => Lift.fromMap(e)).toList();

    // Edge case: list somehow ended empty
    if (loadedLifts.isEmpty) {
      final defaultLifts = _createDefaultLifts();
      await _saveLiftsInternal(prefs, keys, defaultLifts);
      return defaultLifts;
    }

    return loadedLifts;
  }

  static Future<void> saveLifts(List<Lift> lifts) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();
    await _saveLiftsInternal(prefs, keys, lifts);
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

  /// Migration now only runs when we *actually* have previous data.
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

      // Version 1→2 migration: move current PR to first historical record
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

    await _saveLiftsInternal(prefs, keys, migratedLifts);
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
}

class _UserKeys {
  final String liftsKey;
  final String dataVersionKey;

  _UserKeys({
    required this.liftsKey,
    required this.dataVersionKey,
  });
}
