import 'package:flutter/material.dart';
import 'package:azlistview/azlistview.dart';
import '../models/lift.dart';
import '../utils/storage.dart';
import '../utils/toast.dart';
import '../services/sync_service.dart';
import 'add_edit_lift_view.dart';

enum LiftsTab { all, groups }

class LiftsView extends StatefulWidget {
  const LiftsView({super.key});

  @override
  State<LiftsView> createState() => _LiftsViewState();
}

class _LiftsViewState extends State<LiftsView> {
  final SyncService _sync = SyncService();
  List<Lift> lifts = [];
  LiftsTab tab = LiftsTab.all;

  // Preferred group ordering for the Groups view
  static const List<String> _groupOrder = [
    'Chest',
    'Triceps',
    'Shoulders',
    'Rear Delt',
    'Back / Lats',
    'Legs — Quads / General',
    'Legs — Hamstrings / Glutes',
    'Abs',
    'Custom',
  ];

  @override
  void initState() {
    super.initState();
    loadLifts();
  }

  Future<void> loadLifts() async {
    final loaded = await Storage.loadLifts();

    // Build AZ tags
    for (var l in loaded) {
      l.suspensionTag = l.name.isNotEmpty ? l.name[0].toUpperCase() : '#';
    }
    SuspensionUtil.sortListBySuspensionTag(loaded);
    SuspensionUtil.setShowSuspensionStatus(loaded);

    setState(() => lifts = loaded);
  }

  Future<void> saveLiftsAndSync() async {
    await Storage.saveLifts(lifts);

    // Rebuild AZ index
    for (var l in lifts) {
      l.suspensionTag = l.name.isNotEmpty ? l.name[0].toUpperCase() : '#';
    }
    SuspensionUtil.sortListBySuspensionTag(lifts);
    SuspensionUtil.setShowSuspensionStatus(lifts);

    if (mounted) setState(() {});

    try {
      await _sync.pushToServer();
      // intentionally no success toast (avoid blocking PR notifications)
    } catch (e) {
      debugPrint('Sync error after save: $e');
      if (mounted) showIronToast(context, 'Warning: sync failed');
    }
  }

  void addOrEditLift([Lift? lift, int? index]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditLiftView(
          lift: lift,
          lockName: false, // all lifts editable now
          onSave: (newLift) async {
            if (index == null) {
              // --- NEW LIFT ---
              final initialRecord = PRRecord(
                strengthPR: newLift.strengthPR,
                endurancePR: newLift.endurancePR,
                date: newLift.lastUpdated,
                notes: 'Initial PR',
              );
              newLift.prHistory.add(initialRecord);
              newLift.suspensionTag =
                  newLift.name.isNotEmpty ? newLift.name[0].toUpperCase() : '#';

              lifts.add(newLift);

              showIronToast(
                context,
                'New lift added: ${newLift.name}',
                leading: Icon(Icons.fitness_center,
                    color: Theme.of(context).colorScheme.primary),
              );
            } else {
              // --- EDIT EXISTING LIFT ---
              final oldLift = lifts[index];
              newLift.prHistory = List<PRRecord>.from(oldLift.prHistory);

              final currentRecord = oldLift.prHistory.isNotEmpty
                  ? oldLift.prHistory.last
                  : PRRecord(
                      strengthPR: PRSet(weight: 0, reps: 0),
                      endurancePR: PRSet(weight: 0, reps: 0),
                      date: DateTime.now(),
                    );

              final strengthPRIncreased =
                  newLift.strengthPR.isBetterThan(currentRecord.strengthPR);
              final endurancePRIncreased =
                  newLift.endurancePR.isBetterThan(currentRecord.endurancePR);

              if (strengthPRIncreased || endurancePRIncreased) {
                final newRecord = PRRecord(
                  strengthPR: newLift.strengthPR,
                  endurancePR: newLift.endurancePR,
                  date: newLift.lastUpdated,
                  notes: 'New PR',
                );
                newLift.prHistory.add(newRecord);

                final cs = Theme.of(context).colorScheme;
                if (strengthPRIncreased && endurancePRIncreased) {
                  showIronToast(
                    context,
                    'NEW STRENGTH + ENDURANCE PR!',
                    leading: Icon(Icons.emoji_events, color: cs.primary),
                  );
                } else if (strengthPRIncreased) {
                  showIronToast(
                    context,
                    'NEW STRENGTH PR!',
                    leading: Icon(Icons.emoji_events, color: cs.primary),
                  );
                } else if (endurancePRIncreased) {
                  showIronToast(
                    context,
                    'NEW ENDURANCE PR!',
                    leading: Icon(Icons.emoji_events, color: cs.secondary),
                  );
                }
              } else {
                showIronToast(
                  context,
                  'Lift updated',
                  leading: const Icon(Icons.check),
                );
              }

              newLift.suspensionTag =
                  newLift.name.isNotEmpty ? newLift.name[0].toUpperCase() : '#';
              lifts[index] = newLift;
            }

            await saveLiftsAndSync();
          },
        ),
      ),
    );
  }

  Future<void> deleteLift(int index) async {
    final removedLift = lifts.removeAt(index);

    // Queue for server deletion
    await Storage.addPendingLiftDeletion(removedLift.name);

    showIronToast(
      context,
      'Deleted ${removedLift.name}',
      leading: Icon(Icons.delete, color: Theme.of(context).colorScheme.error),
    );

    await saveLiftsAndSync();
  }

  Widget _statusDot(bool recognized) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: recognized ? Colors.greenAccent : Colors.redAccent,
        shape: BoxShape.circle,
      ),
    );
  }

  // ===== Groups View helpers =====

  Map<String, List<Lift>> _groupLifts() {
    final map = <String, List<Lift>>{};
    for (final l in lifts) {
      final g = l.group; // from Lift getter; falls back to "Custom"
      map.putIfAbsent(g, () => []).add(l);
    }
    // Sort lifts within each group by name
    for (final g in map.keys) {
      map[g]!.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return map;
  }

  List<String> _orderedGroupKeys(Map<String, List<Lift>> groups) {
    final keys = groups.keys.toList();
    keys.sort((a, b) {
      final ia = _groupOrder.indexOf(a);
      final ib = _groupOrder.indexOf(b);
      final aa = ia == -1 ? 999 : ia;
      final bb = ib == -1 ? 999 : ib;
      if (aa != bb) return aa.compareTo(bb);
      return a.toLowerCase().compareTo(b.toLowerCase());
    });
    return keys;
  }

  Widget _groupSectionHeader(String groupName, int count) {
    final tt = Theme.of(context).textTheme;
    final bg = Theme.of(context).colorScheme.surface.withOpacity(0.6);
    return Container(
      height: 34,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: bg,
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Text(
            groupName,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '($count)',
            style: tt.bodySmall?.copyWith(
              color: tt.bodySmall?.color?.withOpacity(0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _groupLiftTile(Lift lift) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      dense: false,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Row(
        children: [
          _statusDot(lift.isRecognized),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              lift.name,
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      subtitle: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: 'Strength: ${lift.strengthPR.displayString}\n',
              style: TextStyle(color: cs.primary),
            ),
            TextSpan(
              text: 'Endurance: ${lift.endurancePR.displayString}',
              style: TextStyle(color: cs.secondary),
            ),
          ],
        ),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => addOrEditLift(lift, lifts.indexOf(lift)),
            tooltip: 'Edit',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => deleteLift(lifts.indexOf(lift)),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }

  Widget _groupsBody() {
    final grouped = _groupLifts();
    final orderedKeys = _orderedGroupKeys(grouped);
    if (orderedKeys.isEmpty) {
      return Center(
        child: Text(
          'No lifts yet',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 18),
        ),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: orderedKeys.length,
      itemBuilder: (context, gIndex) {
        final groupName = orderedKeys[gIndex];
        final items = grouped[groupName]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _groupSectionHeader(groupName, items.length),
            const Divider(height: 1),
            ...items.map(_groupLiftTile),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _allBody() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (lifts.isEmpty) {
      return Center(
        child: Text(
          'No lifts yet',
          style: tt.bodyLarge?.copyWith(fontSize: 18),
        ),
      );
    }

    return AzListView(
      data: lifts,
      itemCount: lifts.length,
      itemBuilder: (context, index) {
        final lift = lifts[index];
        return ListTile(
          title: Row(
            children: [
              _statusDot(lift.isRecognized),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  lift.name,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          subtitle: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'Strength: ${lift.strengthPR.displayString}\n',
                  style: TextStyle(color: cs.primary),
                ),
                TextSpan(
                  text: 'Endurance: ${lift.endurancePR.displayString}',
                  style: TextStyle(color: cs.secondary),
                ),
              ],
            ),
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => addOrEditLift(lift, index),
                tooltip: 'Edit',
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => deleteLift(index),
                tooltip: 'Delete',
              ),
            ],
          ),
        );
      },
      indexBarOptions: IndexBarOptions(
        needRebuild: true,
        textStyle:
            TextStyle(color: tt.bodyMedium?.color ?? Colors.white),
        selectTextStyle: TextStyle(
          color: cs.secondary,
          fontWeight: FontWeight.bold,
        ),
        selectItemDecoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).dividerColor,
        ),
        indexHintAlignment: Alignment.centerRight,
      ),
      susItemBuilder: (context, index) {
        final lift = lifts[index];
        return Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Theme.of(context).colorScheme.surface.withOpacity(0.6),
          alignment: Alignment.centerLeft,
          child: Text(
            lift.suspensionTag,
            style: tt.titleMedium?.copyWith(
              color: tt.bodyMedium?.color?.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  Widget _tabSwitcher() {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: ChoiceChip(
              label: const Text('All'),
              selected: tab == LiftsTab.all,
              selectedColor: cs.primary.withOpacity(0.15),
              onSelected: (s) => setState(() => tab = LiftsTab.all),
              labelStyle: TextStyle(
                color: tab == LiftsTab.all ? cs.primary : tt.bodyMedium?.color,
                fontWeight: tab == LiftsTab.all ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ChoiceChip(
              label: const Text('Groups'),
              selected: tab == LiftsTab.groups,
              selectedColor: cs.secondary.withOpacity(0.15),
              onSelected: (s) => setState(() => tab = LiftsTab.groups),
              labelStyle: TextStyle(
                color: tab == LiftsTab.groups ? cs.secondary : tt.bodyMedium?.color,
                fontWeight: tab == LiftsTab.groups ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          _tabSwitcher(),
          Expanded(child: tab == LiftsTab.all ? _allBody() : _groupsBody()),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => addOrEditLift(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
