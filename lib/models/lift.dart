import 'package:azlistview/azlistview.dart';

class Lift extends ISuspensionBean {
  String name;
  PRSet strengthPR;
  PRSet endurancePR;
  String notes;
  DateTime lastUpdated;
  List<PRRecord> prHistory;

  // Added for AZListView alphabetical headers
  String suspensionTag = '';

  Lift({
    required this.name,
    PRSet? strengthPR,
    PRSet? endurancePR,
    this.notes = '',
    DateTime? lastUpdated,
    List<PRRecord>? prHistory,
  })  : strengthPR = strengthPR ?? PRSet(weight: 0, reps: 0),
        endurancePR = endurancePR ?? PRSet(weight: 0, reps: 0),
        lastUpdated = lastUpdated ?? DateTime.now(),
        prHistory = prHistory ?? [];

  bool get isMainLift =>
      ['Barbell Bench Press', 'Incline Bench Press', 'Squat'].contains(name);

  /// Check if any PR increased compared to another lift
  bool hasPRsIncreasedComparedTo(Lift other) {
    return strengthPR.isBetterThan(other.strengthPR) ||
        endurancePR.isBetterThan(other.endurancePR);
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'strengthPR': strengthPR.toMap(),
      'endurancePR': endurancePR.toMap(),
      'notes': notes,
      'lastUpdated': lastUpdated.toIso8601String(),
      'prHistory': prHistory.map((record) => record.toMap()).toList(),
    };
  }

  factory Lift.fromMap(Map<String, dynamic> map) {
    return Lift(
      name: map['name'] ?? '',
      strengthPR: PRSet.fromMap(map['strengthPR'] ?? {}),
      endurancePR: PRSet.fromMap(map['endurancePR'] ?? {}),
      notes: map['notes'] ?? '',
      lastUpdated:
          DateTime.tryParse(map['lastUpdated'] ?? '') ?? DateTime.now(),
      prHistory: (map['prHistory'] as List?)
              ?.map((e) => PRRecord.fromMap(e))
              .toList() ??
          [],
    );
  }

  /// AZListView: return the tag used for alphabetical header
  @override
  String getSuspensionTag() => suspensionTag;
}

class PRRecord {
  PRSet strengthPR;
  PRSet endurancePR;
  DateTime date;
  String notes;

  PRRecord({
    required this.strengthPR,
    required this.endurancePR,
    required this.date,
    this.notes = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'strengthPR': strengthPR.toMap(),
      'endurancePR': endurancePR.toMap(),
      'date': date.toIso8601String(),
      'notes': notes,
    };
  }

  factory PRRecord.fromMap(Map<String, dynamic> map) {
    return PRRecord(
      strengthPR: PRSet.fromMap(map['strengthPR'] ?? {}),
      endurancePR: PRSet.fromMap(map['endurancePR'] ?? {}),
      date: DateTime.tryParse(map['date'] ?? '') ?? DateTime.now(),
      notes: map['notes'] ?? '',
    );
  }
}

class PRSet {
  int weight;
  int reps;

  PRSet({
    required this.weight,
    required this.reps,
  });

  /// Comparison logic: higher weight wins, or same weight but more reps
  bool isBetterThan(PRSet other) {
    return weight > other.weight ||
        (weight == other.weight && reps > other.reps);
  }

  String get displayString {
    if (weight == 0 && reps == 0) return 'Not set';
    return '$weight lbs x $reps reps';
  }

  Map<String, dynamic> toMap() {
    return {
      'weight': weight,
      'reps': reps,
    };
  }

  factory PRSet.fromMap(Map<String, dynamic> map) {
    return PRSet(
      weight: map['weight'] ?? 0,
      reps: map['reps'] ?? 0,
    );
  }
}
