import 'package:flutter/material.dart';
import '../models/lift.dart';
import '../utils/storage.dart';

class HistoryView extends StatefulWidget {
  const HistoryView({super.key});

  @override
  State<HistoryView> createState() => _HistoryViewState();
}

class _HistoryViewState extends State<HistoryView> {
  List<Lift> lifts = [];
  String? selectedLift;
  PRType selectedPRType = PRType.strengthPR;

  @override
  void initState() {
    super.initState();
    loadLifts();
  }

  Future<void> loadLifts() async {
    final loaded = await Storage.loadLifts();
    setState(() {
      lifts = loaded;
      if (lifts.isNotEmpty) {
        selectedLift = lifts.firstWhere(
          (lift) => lift.prHistory.isNotEmpty,
          orElse: () => lifts.first,
        ).name;
      }
    });
  }

  Future<void> saveLifts() async {
    await Storage.saveLifts(lifts);
    setState(() {});
  }

  void deletePRRecord(int recordIndex) {
    final lift = selectedLiftObject;
    if (lift == null || recordIndex < 0 || recordIndex >= lift.prHistory.length) return;

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete PR Record?'),
          content: const Text(
            'Are you sure you want to delete this PR record? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _performDelete(recordIndex);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.red)),
            ),
          ],
        );
      },
    );
  }

  void _performDelete(int recordIndex) {
    final lift = selectedLiftObject;
    if (lift == null) return;

    setState(() {
      lift.prHistory.removeAt(recordIndex);

      if (lift.prHistory.isEmpty) {
        lift.strengthPR = PRSet(weight: 0, reps: 0);
        lift.endurancePR = PRSet(weight: 0, reps: 0);
      } else {
        final mostRecentRecord = lift.prHistory.last;
        lift.strengthPR = mostRecentRecord.strengthPR;
        lift.endurancePR = mostRecentRecord.endurancePR;
        lift.lastUpdated = mostRecentRecord.date;
      }
    });

    saveLifts();
  }

  Lift? get selectedLiftObject {
    return lifts.firstWhere(
      (lift) => lift.name == selectedLift,
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

      final calculatedWeight = recordSet.weight * recordSet.reps;
      final valueStr = '${recordSet.weight} lbs x ${recordSet.reps} reps ($calculatedWeight total)';

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

    return Scaffold(
      appBar: AppBar(title: const Text('PR History')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: DropdownButtonFormField<String>(
              initialValue: selectedLift,
              decoration: const InputDecoration(
                labelText: 'Select Lift',
                border: OutlineInputBorder(),
              ),
              items: lifts.map((lift) {
                final hasHistory = lift.prHistory.isNotEmpty;
                return DropdownMenuItem(
                  value: lift.name,
                  child: Row(
                    children: [
                      Text(lift.name),
                      if (hasHistory) ...[
                        const SizedBox(width: 8),
                        Text(
                          '(${lift.prHistory.length} records)',
                          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                        ),
                      ],
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedLift = value;
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Strength'),
                    selected: selectedPRType == PRType.strengthPR,
                    onSelected: (selected) {
                      setState(() {
                        selectedPRType = PRType.strengthPR;
                      });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Endurance'),
                    selected: selectedPRType == PRType.endurancePR,
                    onSelected: (selected) {
                      setState(() {
                        selectedPRType = PRType.endurancePR;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: hasData ? _buildChart(chartData) : _buildEmptyState(),
          ),
        ],
      ),
    );
  }

  Widget _buildChart(List<ChartData> data) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView.builder(
        itemCount: data.length,
        itemBuilder: (context, index) {
          final point = data[index];
          final isLatest = index == data.length - 1;
          return Card(
            color: isLatest ? Colors.blue[50] : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isLatest ? Colors.blue : Colors.grey,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
              title: Text(
                point.valueString,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: isLatest ? FontWeight.bold : FontWeight.normal,
                  color: isLatest ? Colors.blue : null,
                ),
              ),
              subtitle:
                  Text('${point.date.month}/${point.date.day}/${point.date.year}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (point.note.isNotEmpty) const Icon(Icons.note, size: 16),
                  IconButton(
                    icon: const Icon(Icons.delete, size: 20),
                    onPressed: () => deletePRRecord(index),
                    color: Colors.red,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.auto_graph, size: 64, color: Colors.grey),
          SizedBox(height: 16),
          Text('No PR History Yet',
              style: TextStyle(fontSize: 18, color: Colors.grey)),
          SizedBox(height: 8),
          Text('Edit your lifts to see progress over time',
              style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
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
