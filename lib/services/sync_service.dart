import 'dart:convert';
import '../utils/storage.dart';
import '../models/lift.dart';
import 'api_client.dart';
// NEW: derive canonicalId on pull so green stays green
import '../utils/lift_normalizer.dart';

class SyncService {
  final ApiClient _api = ApiClient();

  /// Pull latest data from server for this user and save locally.
  /// Always a full-pull; client merges.
  Future<void> pullFromServer() async {
    final res = await _api.get('/sync');

    print('SYNC PULL status: ${res.statusCode}');
    if (res.statusCode != 200) {
      print('SYNC PULL body: ${res.body}');
      throw Exception('Sync pull failed (${res.statusCode})');
    }

    final data = jsonDecode(res.body) as Map<String, dynamic>;
    final serverLifts = (data['lifts'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final serverPRs = (data['pr_records'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final mergedLifts = _mergeServerData(serverLifts, serverPRs);
    await Storage.saveLifts(mergedLifts);

    // NOTE: We do NOT clear pending deletions here.
    // If client still has local deletes not pushed yet, we must preserve them.
  }

  /// Push current local lifts + PRs + pending deletions to the server.
  Future<void> pushToServer() async {
    final lifts = await Storage.loadLifts();
    final pendingDeletes = await Storage.loadPendingDeletions();

    if (lifts.isEmpty && pendingDeletes.isEmpty) {
      print('SYNC PUSH skipped (no local changes)');
      return;
    }

    final payload = _buildPushPayload(lifts, pendingDeletes);

    final res = await _api.post('/sync', payload);

    print('SYNC PUSH status: ${res.statusCode}');
    if (res.statusCode >= 400) {
      print('SYNC PUSH failed body: ${res.body}');
      throw Exception('Sync push failed (${res.statusCode})');
    }

    print('SYNC PUSH success.');
    await Storage.clearPendingDeletions();
  }

  /// Converts lifts + deletions into wire format expected by FastAPI backend.
  Map<String, dynamic> _buildPushPayload(
    List<Lift> lifts,
    List<PendingDeletion> pendingDeletes,
  ) {
    final prRecordsList = <Map<String, dynamic>>[];

    // === Build lifts array ===
    final liftList = lifts.map((lift) {
      final historyMaps = lift.prHistory.map((rec) {
        final recIso = rec.date.toIso8601String();

        final prMap = {
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

        // Push into top-level PR array as well
        prRecordsList.add(prMap);
        return prMap;
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

    // === Build deleted array ===
    final deletedList = pendingDeletes.map((d) {
      return {
        'kind': d.kind, // "lift" or "pr"
        'lift_name': d.liftName,
        'date': d.date,
        'deleted_at': d.deletedAtIso,
      };
    }).toList();

    final payload = {
      'lifts': liftList,
      'pr_records': prRecordsList,
      'deleted': deletedList,
    };

    print('SYNC payload built: '
        '${lifts.length} lifts, ${prRecordsList.length} PRs, ${deletedList.length} deletions');
    return payload;
  }

  /// Merge server lift + PR data into our Lift model list.
  List<Lift> _mergeServerData(
    List<Map<String, dynamic>> serverLifts,
    List<Map<String, dynamic>> serverPRs,
  ) {
    final Map<String, List<Map<String, dynamic>>> prByLift = {};
    for (final pr in serverPRs) {
      final ln = pr['lift_name'] as String? ?? '';
      if (ln.isEmpty) continue;
      prByLift.putIfAbsent(ln, () => []).add(pr);
    }

    final result = <Lift>[];

    for (final l in serverLifts) {
      final liftName = (l['name'] ?? '') as String;
      final historyForLift = (prByLift[liftName] ?? [])
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
            weight: (rec['strength_weight'] ?? rec['strengthPR']?['weight'] ?? 0) as int,
            reps: (rec['strength_reps'] ?? rec['strengthPR']?['reps'] ?? 0) as int,
          ),
          endurancePR: PRSet(
            weight: (rec['endurance_weight'] ?? rec['endurancePR']?['weight'] ?? 0) as int,
            reps: (rec['endurance_reps'] ?? rec['endurancePR']?['reps'] ?? 0) as int,
          ),
          date: dateParsed,
          notes: rec['notes'] ?? '',
        );
      }).toList();

      // NEW: derive canonicalId for pulled lift so recognition persists
      final matched = matchLift(liftName);

      final lift = Lift(
        name: liftName,
        notes: l['notes'] ?? '',
        lastUpdated:
            DateTime.tryParse(l['last_updated'] ?? '') ?? DateTime.now(),
        strengthPR: PRSet(
          weight: (l['strength_weight'] ??
                  l['strengthPR']?['weight'] ??
                  0) as int,
          reps: (l['strength_reps'] ?? l['strengthPR']?['reps'] ?? 0) as int,
        ),
        endurancePR: PRSet(
          weight: (l['endurance_weight'] ??
                  l['endurancePR']?['weight'] ??
                  0) as int,
          reps:
              (l['endurance_reps'] ?? l['endurancePR']?['reps'] ?? 0) as int,
        ),
        prHistory: prHistory,
        canonicalId: matched?.id, // <-- keep it green after pulls
      );

      lift.suspensionTag =
          lift.name.isNotEmpty ? lift.name[0].toUpperCase() : '#';
      result.add(lift);
    }

    // Sort alphabetically for consistent UI
    result.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return result;
  }
}
