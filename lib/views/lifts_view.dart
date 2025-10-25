import 'package:flutter/material.dart';
import 'package:azlistview/azlistview.dart';
import '../models/lift.dart';
import '../utils/storage.dart';
import 'add_edit_lift_view.dart';

class LiftsView extends StatefulWidget {
  const LiftsView({super.key});

  @override
  State<LiftsView> createState() => _LiftsViewState();
}

class _LiftsViewState extends State<LiftsView> {
  List<Lift> lifts = [];

  @override
  void initState() {
    super.initState();
    loadLifts();
  }

  Future<void> loadLifts() async {
    final loaded = await Storage.loadLifts();

    // Set suspensionTag for AZListView
    for (var lift in loaded) {
      lift.suspensionTag =
          lift.name.isNotEmpty ? lift.name[0].toUpperCase() : '#';
    }

    SuspensionUtil.sortListBySuspensionTag(loaded);
    SuspensionUtil.setShowSuspensionStatus(loaded);

    setState(() => lifts = loaded);
  }

  Future<void> saveLifts() async {
    await Storage.saveLifts(lifts);

    // Re-run sorting/tag logic after save so UI stays clean
    for (var l in lifts) {
      l.suspensionTag =
          l.name.isNotEmpty ? l.name[0].toUpperCase() : '#';
    }
    SuspensionUtil.sortListBySuspensionTag(lifts);
    SuspensionUtil.setShowSuspensionStatus(lifts);

    setState(() {});
  }

  void addOrEditLift([Lift? lift, int? index]) {
    final bool isEditingExisting = index != null;
    final bool lockNameField = isEditingExisting && (lift?.isMainLift ?? false);

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddEditLiftView(
          lift: lift,
          lockName: lockNameField, // will be added in AddEditLiftView
          onSave: (newLift) {
            // BASIC VALIDATION:
            // Prevent user from "adding" another pinned lift by name.
            if (index == null && newLift.isMainLift) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'That lift already exists and can’t be added again.',
                  ),
                ),
              );
              return;
            }

            if (index == null) {
              // NEW LIFT
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
            } else {
              // EDIT EXISTING LIFT
              final oldLift = lifts[index];

              // keep history
              newLift.prHistory = List<PRRecord>.from(oldLift.prHistory);

              // compare vs last record to see if PR improved
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
              }

              // Belt-and-suspenders: if it's a pinned lift, force the original name.
              if (oldLift.isMainLift) {
                newLift.name = oldLift.name;
              }

              newLift.suspensionTag = newLift.name.isNotEmpty
                  ? newLift.name[0].toUpperCase()
                  : '#';

              lifts[index] = newLift;
            }

            saveLifts();
          },
        ),
      ),
    );
  }

  void deleteLift(int index) {
    final lift = lifts[index];

    if (!lift.canDelete) {
      // shouldn't show delete for main lifts, but guard anyway
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${lift.name} is a core lift and cannot be deleted.',
          ),
        ),
      );
      return;
    }

    // Remove from local list
    final _removedLift = lifts.removeAt(index);

    // TODO (sync): queue this deletion so it propagates to the backend.
    // e.g. SyncService.queueLiftDeletion(_removedLift);

    saveLifts();
  }

  @override
  Widget build(BuildContext context) {
    if (lifts.isEmpty) {
      // With pinned enforcement this should basically never show,
      // but we'll keep it graceful.
      return Scaffold(
        body: const Center(
          child: Text(
            'No lifts yet',
            style: TextStyle(fontSize: 18),
          ),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => addOrEditLift(),
          child: const Icon(Icons.add),
        ),
      );
    }

    return Scaffold(
      body: AzListView(
        data: lifts,
        itemCount: lifts.length,
        itemBuilder: (context, index) {
          final lift = lifts[index];
          return ListTile(
            title: Text(
              lift.name,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,        // <— new
                fontSize: 16,               // optional readability boost
              ),
            ),
            subtitle: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text:
                        'Strength: ${lift.strengthPR.displayString}\n',
                    style: const TextStyle(color: Colors.orangeAccent),
                  ),
                  TextSpan(
                    text:
                        'Endurance: ${lift.endurancePR.displayString}',
                    style: const TextStyle(color: Colors.lightBlueAccent),
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
                ),
                if (lift.canDelete)
                  IconButton(
                    icon: const Icon(Icons.delete),
                    onPressed: () => deleteLift(index),
                  ),
              ],
            ),
          );
        },
        indexBarOptions: const IndexBarOptions(
          needRebuild: true,
          textStyle: TextStyle(color: Colors.white),
          selectTextStyle: TextStyle(
            color: Colors.orangeAccent,
            fontWeight: FontWeight.bold,
          ),
          selectItemDecoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black54,
          ),
          indexHintAlignment: Alignment.centerRight,
        ),
        susItemBuilder: (context, index) {
          final lift = lifts[index];
          return Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: Colors.grey[900],
            alignment: Alignment.centerLeft,
            child: Text(
              lift.suspensionTag,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => addOrEditLift(),
        child: const Icon(Icons.add),
      ),
    );
  }
}
