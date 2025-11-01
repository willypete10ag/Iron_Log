// lib/widgets/grouped_lift_picker.dart
import 'package:flutter/material.dart';
import '../models/lift.dart';
import '../data/canonical_lifts.dart';

/// Returns the muscle group for a lift, or "Custom / Uncategorized" when unknown.
String groupForLift(Lift l) {
  if (l.canonicalId != null && l.canonicalId!.isNotEmpty) {
    return canonicalIdToGroup[l.canonicalId!] ?? 'Custom / Uncategorized';
  }
  return 'Custom / Uncategorized';
}

/// Builds the list of groups that actually exist in the provided lifts,
/// always including "All" and "Custom / Uncategorized" when relevant.
List<String> buildGroupList(List<Lift> lifts) {
  final set = <String>{};
  for (final l in lifts) {
    set.add(groupForLift(l));
  }

  final groups = set.toList()..sort();
  // Prefer to show main “All” first, then the rest A→Z
  return ['All', ...groups];
}

/// Filters lifts by group. "All" shows everything.
List<Lift> filterLiftsByGroup(List<Lift> lifts, String group) {
  if (group == 'All') return List<Lift>.from(lifts);
  return lifts.where((l) => groupForLift(l) == group).toList();
}

class GroupedLiftPicker extends StatelessWidget {
  final List<Lift> lifts;
  final String selectedGroup;
  final String? selectedLiftName;
  final ValueChanged<String> onGroupChanged;
  final ValueChanged<String?> onLiftChanged;

  const GroupedLiftPicker({
    super.key,
    required this.lifts,
    required this.selectedGroup,
    required this.selectedLiftName,
    required this.onGroupChanged,
    required this.onLiftChanged,
  });

  Widget _statusDot(bool recognized) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: recognized ? Colors.greenAccent : Colors.redAccent,
        shape: BoxShape.circle,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final groups = buildGroupList(lifts);
    final filtered = filterLiftsByGroup(lifts, selectedGroup)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

    return Column(
      children: [
        // Group selector
        DropdownButtonFormField<String>(
          value: groups.contains(selectedGroup) ? selectedGroup : 'All',
          decoration: const InputDecoration(
            labelText: 'Muscle Group',
            border: OutlineInputBorder(),
          ),
          items: groups
              .map((g) => DropdownMenuItem(
                    value: g,
                    child: Text(g),
                  ))
              .toList(),
          onChanged: (g) {
            if (g != null) onGroupChanged(g);
          },
        ),
        const SizedBox(height: 12),
        // Lift selector (filtered)
        DropdownButtonFormField<String>(
          value: filtered.any((l) => l.name == selectedLiftName)
              ? selectedLiftName
              : (filtered.isNotEmpty ? filtered.first.name : null),
          decoration: const InputDecoration(
            labelText: 'Select Lift',
            border: OutlineInputBorder(),
          ),
          items: filtered.map((lift) {
            final hasHistory = lift.prHistory.isNotEmpty;
            return DropdownMenuItem(
              value: lift.name,
              child: Row(
                children: [
                  _statusDot(lift.isRecognized),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      lift.name,
                      style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (hasHistory) ...[
                    const SizedBox(width: 8),
                    Text(
                      '(${lift.prHistory.length})',
                      style: tt.bodySmall?.copyWith(
                        color: tt.bodySmall?.color?.withOpacity(0.7),
                      ),
                    ),
                  ],
                ],
              ),
            );
          }).toList(),
          onChanged: onLiftChanged,
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Green = recognized • Red = custom',
            style: tt.bodySmall?.copyWith(color: cs.outline),
          ),
        ),
      ],
    );
  }
}
