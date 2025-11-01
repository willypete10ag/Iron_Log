import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lift.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../services/sync_service.dart';
import '../widgets/grouped_lift_picker.dart'; // ← new widget

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  final SyncService _sync = SyncService();

  List<Lift> lifts = [];

  // New: chosen group + lift
  String selectedGroup = 'All';
  String? selectedLiftName;

  PRType selectedPRType = PRType.strengthPR;

  @override
  void initState() {
    super.initState();
    loadLifts();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    selectedGroup = prefs.getString('history_last_group') ?? 'All';
    selectedLiftName = prefs.getString('history_last_lift');
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('history_last_group', selectedGroup);
    if (selectedLiftName != null) {
      await prefs.setString('history_last_lift', selectedLiftName!);
    } else {
      await prefs.remove('history_last_lift');
    }
  }

  Future<void> loadLifts() async {
    await _loadPrefs();

    final loaded = await Storage.loadLifts();
    lifts = loaded;

    // If no lift chosen yet, pick a reasonable default:
    // Prefer a lift (in current group) that has history; else first in group; else fall back to All.
    String effectiveGroup = selectedGroup;
    final byGroup = filterLiftsByGroup(lifts, effectiveGroup);

    String? effectiveLiftName = selectedLiftName;

    // If saved lift not in this group, or missing, try to pick one:
    if (effectiveLiftName == null ||
        !byGroup.any((l) => l.name == effectiveLiftName)) {
      // Try to pick a lift with history in this group
      final withHist =
          byGroup.firstWhere((l) => l.prHistory.isNotEmpty, orElse: () => byGroup.isNotEmpty ? byGroup.first : Lift(name: ''));
      if (withHist.name.isNotEmpty) {
        effectiveLiftName = withHist.name;
      } else {
        // If group was empty, fall back to All
        effectiveGroup = 'All';
        final all = filterLiftsByGroup(lifts, 'All');
        if (all.isNotEmpty) {
          final withHistAll =
              all.firstWhere((l) => l.prHistory.isNotEmpty, orElse: () => all.first);
          effectiveLiftName = withHistAll.name;
        }
      }
    }

    setState(() {
      selectedGroup = effectiveGroup;
      selectedLiftName = effectiveLiftName;
    });

    await _savePrefs();
  }

  Future<void> _saveAndSyncWithToast(String toastMsg) async {
    await Storage.saveLifts(lifts);
    try {
      await _sync.pushToServer();
      if (mounted) showIronToast(context, toastMsg); // e.g., "PR deleted"
    } catch (e) {
      debugPrint('Sync error in HistoryView: $e');
      if (mounted) showIronToast(context, 'Warning: sync failed');
    }
    if (mounted) setState(() {});
  }

  void deletePRRecord(int recordIndex) async {
    final lift = selectedLiftObject;
    if (lift == null || recordIndex < 0 || recordIndex >= lift.prHistory.length) return;

    final cs = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        final pr = lift.prHistory[recordIndex];
        final prettyDate = '${pr.date.month}/${pr.date.day}/${pr.date.year}';

        return AlertDialog(
          title: const Text('Delete PR Record?'),
          content: Text(
            'Are you sure you want to delete this PR from $prettyDate?\n'
            'This will also update your current PR if it was your latest.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await _performDelete(recordIndex);
              },
              child: Text('Delete', style: TextStyle(color: cs.error)),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performDelete(int recordIndex) async {
    final lift = selectedLiftObject;
    if (lift == null) return;

    // Capture BEFORE removal to queue deletion
    final prToDelete = lift.prHistory[recordIndex];
    await Storage.addPendingPRDeletion(
      liftName: lift.name,
      prDate: prToDelete.date,
    );

    // Remove locally
    lift.prHistory.removeAt(recordIndex);

    // Recompute current PR and lastUpdated
    if (lift.prHistory.isEmpty) {
      lift.strengthPR = PRSet(weight: 0, reps: 0);
      lift.endurancePR = PRSet(weight: 0, reps: 0);
      lift.lastUpdated = DateTime.now();
    } else {
      final mostRecentRecord = lift.prHistory.last;
      lift.strengthPR = mostRecentRecord.strengthPR;
      lift.endurancePR = mostRecentRecord.endurancePR;
      lift.lastUpdated = mostRecentRecord.date;
    }

    await _saveAndSyncWithToast('PR deleted');
  }

  Lift? get selectedLiftObject {
    if (selectedLiftName == null) return null;
    return lifts.firstWhere(
      (lift) => lift.name == selectedLiftName,
      orElse: () => lifts.isNotEmpty ? lifts.first : Lift(name: ''),
    );
  }

  List<ChartData> getChartData() {
    final lift = selectedLiftObject;
    if (lift == null || lift.prHistory.isEmpty) return [];

    final sortedHistory = List<PRRecord>.from(lift.prHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    return sortedHistory.map((record) {
      final recordSet = selectedPRType == PRType.strengthPR
          ? record.strengthPR
          : record.endurancePR;

      final estTotal = recordSet.weight * recordSet.reps;
      final valueStr = '${recordSet.weight} lbs x ${recordSet.reps} reps ($estTotal total)';

      return ChartData(
        date: record.date,
        valueString: valueStr,
        note: record.notes,
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final chartData = getChartData();
    final hasData = chartData.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      body: Column(
        children: [
          // NEW: Grouped selector block
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GroupedLiftPicker(
              lifts: lifts,
              selectedGroup: selectedGroup,
              selectedLiftName: selectedLiftName,
              onGroupChanged: (g) async {
                setState(() {
                  selectedGroup = g;
                });
                // When group changes, choose a sensible first lift in that group
                final filtered = filterLiftsByGroup(lifts, selectedGroup)
                  ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
                Lift? pick;
                if (filtered.isNotEmpty) {
                  pick = filtered.firstWhere(
                    (l) => l.prHistory.isNotEmpty,
                    orElse: () => filtered.first,
                  );
                }
                setState(() => selectedLiftName = pick?.name);
                await _savePrefs();
              },
              onLiftChanged: (name) async {
                setState(() => selectedLiftName = name);
                await _savePrefs();
              },
            ),
          ),

          // PR TYPE TOGGLE (Strength / Endurance)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Strength'),
                    selected: selectedPRType == PRType.strengthPR,
                    selectedColor: cs.primary.withOpacity(0.2),
                    onSelected: (selected) {
                      if (selected) setState(() => selectedPRType = PRType.strengthPR);
                    },
                    labelStyle: TextStyle(
                      color: selectedPRType == PRType.strengthPR ? cs.primary : tt.bodyMedium?.color,
                      fontWeight: selectedPRType == PRType.strengthPR ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Endurance'),
                    selected: selectedPRType == PRType.endurancePR,
                    selectedColor: cs.secondary.withOpacity(0.2),
                    onSelected: (selected) {
                      if (selected) setState(() => selectedPRType = PRType.endurancePR);
                    },
                    labelStyle: TextStyle(
                      color: selectedPRType == PRType.endurancePR ? cs.secondary : tt.bodyMedium?.color,
                      fontWeight: selectedPRType == PRType.endurancePR ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 16),

          Expanded(
            child: hasData ? _buildPRList(chartData) : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildPRList(List<ChartData> data) {
    final latestIndex = data.length - 1;
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) {
          final point = data[index];
          final isLatest = index == latestIndex;

          final bgColor = isLatest ? cs.surface.withOpacity(0.25) : Colors.transparent;

          final titleStyle = tt.titleMedium?.copyWith(
            fontSize: 18,
            fontWeight: isLatest ? FontWeight.bold : FontWeight.w600,
            color: isLatest ? cs.secondary : tt.titleMedium?.color,
          );

          return Card(
            color: bgColor,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isLatest ? cs.primary : Theme.of(context).dividerColor,
                child: Icon(
                  isLatest ? Icons.emoji_events : Icons.fitness_center,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              title: Text(point.valueString, style: titleStyle),
              subtitle: Text(
                '${point.date.month}/${point.date.day}/${point.date.year}'
                '${point.note.isNotEmpty ? " · ${point.note}" : ""}',
                style: tt.bodySmall?.copyWith(
                  color: tt.bodySmall?.color?.withOpacity(isLatest ? 0.9 : 0.7),
                  fontWeight: isLatest ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete, size: 20),
                onPressed: () => deletePRRecord(index),
                color: cs.error,
                tooltip: 'Delete record',
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    final tt = Theme.of(context).textTheme;
    final iconColor = tt.bodyMedium?.color?.withOpacity(0.6);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph, size: 64, color: iconColor),
          const SizedBox(height: 16),
          Text('No PR History Yet', style: tt.titleMedium?.copyWith(fontSize: 18)),
          const SizedBox(height: 8),
          Text(
            'Edit your lifts to see progress over time',
            style: tt.bodyMedium?.copyWith(color: tt.bodyMedium?.color?.withOpacity(0.7)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum PRType { strengthPR, endurancePR }

class ChartData {
  final DateTime date;
  final String valueString;
  final String note;

  ChartData({
    required this.date,
    required this.valueString,
    required this.note,
  });
}
