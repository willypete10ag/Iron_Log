import 'dart:convert';
import '../utils/storage.dart';
import '../models/lift.dart';
import 'api_client.dart';

class SyncService {
  final ApiClient _api = ApiClient();

  /// Pull latest data from server for this user and save locally.
  /// For now we just full-pull.
  Future<void> pullFromServer() async {
    final res = await _api.get('/sync');

    print('SYNC PULL status: ${res.statusCode}');
    print('SYNC PULL body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Sync pull failed (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;

    final serverLifts = (data['lifts'] as List).cast<Map<String, dynamic>>();
    final serverPRs =
        (data['pr_records'] as List).cast<Map<String, dynamic>>();

    final mergedLifts = _mergeServerData(serverLifts, serverPRs);

    // Save merged lifts locally
    await Storage.saveLifts(mergedLifts);

    // NOTE: We are NOT clearing pending deletions here. If the client
    // had local deletes but hasn't pushed yet, we still want to push them.
  }

  /// Push our current local lifts + PRs + pending deletions to the server.
  Future<void> pushToServer() async {
    // 1. Get current local state
    final lifts = await Storage.loadLifts();
    final pendingDeletes = await Storage.loadPendingDeletions();

    // 2. Convert to server wire format
    final payload = _buildPushPayload(lifts, pendingDeletes);

    // 3. POST /sync
    final res = await _api.post('/sync', payload);

    print('SYNC PUSH status: ${res.statusCode}');
    print('SYNC PUSH body: ${res.body}');

    if (res.statusCode != 200) {
      throw Exception('Sync push failed (${res.statusCode})');
    }

    // 4. If push succeeded, clear deletions since server knows now.
    await Storage.clearPendingDeletions();
  }

  /// Helper: turn local Lift objects and pending deletions into
  /// the body shape expected by sync_push (backend FastAPI).
  Map<String, dynamic> _buildPushPayload(
    List<Lift> lifts,
    List<PendingDeletion> pendingDeletes,
  ) {
    final prRecordsList = <Map<String, dynamic>>[];

    // Build the "lifts" array
    final liftList = lifts.map((lift) {
      // Build embedded pr_history (also flatten separately below)
      final historyMaps = lift.prHistory.map((rec) {
        final recIso = rec.date.toIso8601String();

        // Also push this onto prRecordsList for top-level "pr_records"
        prRecordsList.add({
          'lift_name': lift.name,
          'date': recIso,
          'strengthPR': {
            'weight': rec.strengthPR.weight,
            'reps': rec.strengthPR.reps,
          },
          'endurancePR': {
            'weight': rec.endurancePR.weight,
            'reps': rec.endurancePR.reps,
          },
          'notes': rec.notes,
          'updated_at': recIso,
        });

        return {
          'lift_name': lift.name,
          'date': recIso,
          'strengthPR': {
            'weight': rec.strengthPR.weight,
            'reps': rec.strengthPR.reps,
          },
          'endurancePR': {
            'weight': rec.endurancePR.weight,
            'reps': rec.endurancePR.reps,
          },
          'notes': rec.notes,
          'updated_at': recIso,
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

    // Build the "deleted" array from pendingDeletes
    final deletedList = pendingDeletes.map((d) {
      return {
        'kind': d.kind, // "lift" or "pr"
        'lift_name': d.liftName,
        // For lift deletes, backend ignores 'date', so it's fine if null
        'date': d.date,
        'deleted_at': d.deletedAtIso,
      };
    }).toList();

    return {
      'lifts': liftList,
      'pr_records': prRecordsList,
      'deleted': deletedList,
    };
  }

  /// Helper: merge lifts + pr_records from server into Lift model list.
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

    final result = <Lift>[];

    for (final l in serverLifts) {
      final liftName = l['name'] as String;

      // Build PR history (oldest -> newest)
      final historyForLift = (prByLift[liftName] ?? [])
        ..sort((a, b) {
          final da =
              DateTime.tryParse(a['date'] ?? '') ?? DateTime.now();
          final db =
              DateTime.tryParse(b['date'] ?? '') ?? DateTime.now();
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

      lift.suspensionTag =
          lift.name.isNotEmpty ? lift.name[0].toUpperCase() : '#';

      result.add(lift);
    }

    // Sort alphabetically for consistency with LiftsView
    result.sort(
      (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
    );

    return result;
  }
}
