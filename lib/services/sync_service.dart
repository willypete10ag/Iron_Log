import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/session.dart';
import '../utils/storage.dart';
import '../models/lift.dart';
import 'api_client.dart';

class SyncService {
  final ApiClient _api = ApiClient();

  /// Pull latest data from server for this user and save locally.
  /// We pass `since` in future to do incremental sync, but for now we'll just full-pull.
  Future<void> pullFromServer() async {
    // we need auth header, ApiClient.get() already does that
    final res = await _api.get('/sync');

    // debug
    print('SYNC PULL status: ${res.statusCode}');
    print('SYNC PULL body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Sync pull failed (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    // data['lifts'] is a list of maps shaped like server lifts table rows
    // data['pr_records'] is list of PR rows
    // We need to convert that into our Lift model shape and save via Storage.saveLifts()

    final serverLifts = (data['lifts'] as List).cast<Map<String, dynamic>>();
    final serverPRs = (data['pr_records'] as List).cast<Map<String, dynamic>>();

    // Build lifts with their PR history attached
    final mergedLifts = _mergeServerData(serverLifts, serverPRs);

    // Save them locally for current user
    await Storage.saveLifts(mergedLifts);
  }

  /// Push our current local lifts + PRs to the server.
  Future<void> pushToServer() async {
    // 1. Get current local lifts
    final lifts = await Storage.loadLifts();

    // 2. Convert to server wire format
    final payload = _buildPushPayload(lifts);

    // 3. POST /sync
    final res = await _api.post('/sync', payload);

    print('SYNC PUSH status: ${res.statusCode}');
    print('SYNC PUSH body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Sync push failed (${res.statusCode})');
    }

    // Optional: after successful push, you could re-pull to ensure we have
    // whatever the server merged. We'll skip that for now.
  }

  /// Helper: turn local Lift objects into the body shape expected by sync_push (your backend).
  Map<String, dynamic> _buildPushPayload(List<Lift> lifts) {
    final prRecordsList = <Map<String, dynamic>>[];

    // We'll flatten lift.prHistory into standalone pr_records in addition to embedding history.
    final liftList = lifts.map((lift) {
      // Track PR history for this lift
      final historyMaps = lift.prHistory.map((rec) {
        prRecordsList.add({
          'lift_name': lift.name,
          'date': rec.date.toIso8601String(),
          'strengthPR': {
            'weight': rec.strengthPR.weight,
            'reps': rec.strengthPR.reps,
          },
          'endurancePR': {
            'weight': rec.endurancePR.weight,
            'reps': rec.endurancePR.reps,
          },
          'notes': rec.notes,
          'updated_at': rec.date.toIso8601String(),
        });

        return {
          'lift_name': lift.name,
          'date': rec.date.toIso8601String(),
          'strengthPR': {
            'weight': rec.strengthPR.weight,
            'reps': rec.strengthPR.reps,
          },
          'endurancePR': {
            'weight': rec.endurancePR.weight,
            'reps': rec.endurancePR.reps,
          },
          'notes': rec.notes,
          'updated_at': rec.date.toIso8601String(),
        };
      }).toList();

      return {
        'name': lift.name,
        'notes': lift.notes,
        'last_updated': lift.lastUpdated.toIso8601String(),
        'strengthPR': {
          'weight': lift.strengthPR.weight,
          'reps': lift.strengthPR.reps,
        },
        'endurancePR': {
          'weight': lift.endurancePR.weight,
          'reps': lift.endurancePR.reps,
        },
        'pr_history': historyMaps,
      };
    }).toList();

    // For now we don't support deletions in the app UI yet, so send empty.
    return {
      'lifts': liftList,
      'pr_records': prRecordsList,
      'deleted': <Map<String, dynamic>>[],
    };
  }

  /// Helper: merge lifts + pr_records from server into Lift model list.
  ///
  /// serverLifts rows look like:
  /// {
  ///   "id": "...",
  ///   "name": "Squat",
  ///   "notes": "...",
  ///   "last_updated": "2025-10-24T20:31:16.249963+00:00",
  ///   "strength_weight": 225,
  ///   "strength_reps": 5,
  ///   "endurance_weight": 135,
  ///   "endurance_reps": 15
  /// }
  ///
  /// serverPRs rows look like:
  /// {
  ///   "id": "...",
  ///   "lift_name": "Squat",
  ///   "date": "2025-10-24T20:31:16.249963+00:00",
  ///   "strength_weight": 225,
  ///   "strength_reps": 5,
  ///   "endurance_weight": 135,
  ///   "endurance_reps": 15,
  ///   "notes": "New PR",
  ///   "updated_at": "2025-10-24T20:31:16.249963+00:00"
  /// }
  ///
  List<Lift> _mergeServerData(
    List<Map<String, dynamic>> serverLifts,
    List<Map<String, dynamic>> serverPRs,
  ) {
    // Group PRs by lift_name
    final Map<String, List<Map<String, dynamic>>> prByLift = {};
    for (final pr in serverPRs) {
      final ln = pr['lift_name'] as String;
      prByLift.putIfAbsent(ln, () => []);
      prByLift[ln]!.add(pr);
    }

    // For each lift, build its Lift object and attach its PR history
    final result = <Lift>[];

    for (final l in serverLifts) {
      final liftName = l['name'] as String;

      // Build PR history list for this lift
      final historyForLift = (prByLift[liftName] ?? [])
          // sort oldest -> newest by date, just like HistoryView expects
          ..sort((a, b) {
            final da = DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
            final db = DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
            return da.compareTo(db);
          });

      final prHistory = historyForLift.map((rec) {
        final dateParsed =
            DateTime.tryParse(rec['date'] ?? '') ?? DateTime.now();
        return PRRecord(
          strengthPR: PRSet(
            weight: (rec['strength_weight'] ?? 0) as int,
            reps: (rec['strength_reps'] ?? 0) as int,
          ),
          endurancePR: PRSet(
            weight: (rec['endurance_weight'] ?? 0) as int,
            reps: (rec['endurance_reps'] ?? 0) as int,
          ),
          date: dateParsed,
          notes: rec['notes'] ?? '',
        );
      }).toList();

      final lift = Lift(
        name: liftName,
        notes: l['notes'] ?? '',
        lastUpdated:
            DateTime.tryParse(l['last_updated'] ?? '') ?? DateTime.now(),
        strengthPR: PRSet(
          weight: (l['strength_weight'] ?? 0) as int,
          reps: (l['strength_reps'] ?? 0) as int,
        ),
        endurancePR: PRSet(
          weight: (l['endurance_weight'] ?? 0) as int,
          reps: (l['endurance_reps'] ?? 0) as int,
        ),
        prHistory: prHistory,
      );

      // We also need suspensionTag for AzListView
      lift.suspensionTag = lift.name.isNotEmpty
          ? lift.name[0].toUpperCase()
          : '#';

      result.add(lift);
    }

    // Sort same way LiftsView does
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }
}
