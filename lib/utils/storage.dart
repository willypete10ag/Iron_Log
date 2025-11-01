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

  Map<String, dynamic> toMap() => {
        'kind': kind,
        'lift_name': liftName,
        'date': date,
        'deleted_at': deletedAtIso,
      };

  factory PendingDeletion.fromMap(Map<String, dynamic> map) => PendingDeletion(
        kind: map['kind'] ?? 'lift',
        liftName: map['lift_name'] ?? '',
        date: map['date'],
        deletedAtIso: map['deleted_at'] ?? DateTime.now().toIso8601String(),
      );
}

class Storage {
  static const int currentDataVersion = 3;

  /// User-specific key set
  static Future<_UserKeys> _getUserKeys() async {
    final userInfo = await Session.user;
    final userId = (userInfo?['id'] ?? '_anon').toString();
    return _UserKeys(
      liftsKey: 'lifts_$userId',
      dataVersionKey: 'data_version_$userId',
      deletedKey: 'deleted_$userId',
    );
  }

  // === LIFTS ===

  static Future<List<Lift>> loadLifts() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();

    final liftsString = prefs.getString(keys.liftsKey);
    final int storedVersion = prefs.getInt(keys.dataVersionKey) ?? 1;

    if (liftsString == null || liftsString == '[]') {
      final defaultLifts = _createDefaultLifts();
      await _saveLiftsInternal(prefs, keys, defaultLifts);
      return defaultLifts;
    }

    if (storedVersion < currentDataVersion) {
      await _migrateData(prefs, liftsString, storedVersion, keys);
      return loadLifts();
    }

    final List<dynamic> jsonList = jsonDecode(liftsString);
    final lifts = jsonList.map((e) => Lift.fromMap(e)).toList();
    return lifts;
  }

  static Future<void> saveLifts(List<Lift> lifts) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();
    await _saveLiftsInternal(prefs, keys, lifts);
  }

  static Future<void> _saveLiftsInternal(
      SharedPreferences prefs, _UserKeys keys, List<Lift> lifts) async {
    final jsonList = lifts.map((e) => e.toMap()).toList();
    await prefs.setString(keys.liftsKey, jsonEncode(jsonList));
    await prefs.setInt(keys.dataVersionKey, currentDataVersion);
  }

  static Future<void> _migrateData(
    SharedPreferences prefs,
    String liftsString,
    int oldVersion,
    _UserKeys keys,
  ) async {
    final List<dynamic> jsonList = jsonDecode(liftsString);
    final migratedLifts = <Lift>[];

    for (var json in jsonList) {
      final lift = Lift.fromMap(json);

      // Version 1 → 2 migration: seed first PR into history
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

  // === DELETION QUEUE ===

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

  static Future<void> savePendingDeletions(
      List<PendingDeletion> deletions) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();
    final jsonList = deletions.map((d) => d.toMap()).toList();
    await prefs.setString(keys.deletedKey, jsonEncode(jsonList));
  }

  static Future<void> addPendingLiftDeletion(String liftName) async {
    final deletions = await loadPendingDeletions();
    deletions.add(PendingDeletion(
      kind: 'lift',
      liftName: liftName,
      deletedAtIso: DateTime.now().toIso8601String(),
    ));
    await savePendingDeletions(deletions);
  }

  static Future<void> addPendingPRDeletion({
    required String liftName,
    required DateTime prDate,
  }) async {
    final deletions = await loadPendingDeletions();
    deletions.add(PendingDeletion(
      kind: 'pr',
      liftName: liftName,
      date: prDate.toIso8601String(),
      deletedAtIso: DateTime.now().toIso8601String(),
    ));
    await savePendingDeletions(deletions);
  }

  static Future<void> clearPendingDeletions() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = await _getUserKeys();
    await prefs.remove(keys.deletedKey);
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
