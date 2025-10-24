import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/lift.dart';
import '../utils/storage.dart';

class LiftProgressChartView extends StatefulWidget {
  const LiftProgressChartView({super.key});

  @override
  State<LiftProgressChartView> createState() => _LiftProgressChartViewState();
}

class _LiftProgressChartViewState extends State<LiftProgressChartView> {
  List<Lift> lifts = [];
  Lift? selectedLift;
  String selectedType = 'Strength'; // Strength | Endurance

  @override
  void initState() {
    super.initState();
    _loadLifts();
  }

  Future<void> _loadLifts() async {
    final loaded = await Storage.loadLifts();
    setState(() {
      lifts = loaded;
      if (lifts.isNotEmpty) selectedLift = lifts.first;
    });
  }

  double _calculateEstimatedLoad(int weight, int reps) {
    if (weight <= 0 || reps <= 0) return 0;
    return weight * (1 + reps / 30);
  }

  List<FlSpot> _generateChartData(Lift lift) {
    final records = lift.prHistory;
    if (records.isEmpty) return [];

    List<FlSpot> points = [];

    for (int i = 0; i < records.length; i++) {
      final record = records[i];
      double value;

      if (selectedType == 'Strength') {
        value = _calculateEstimatedLoad(
          record.strengthPR.weight,
          record.strengthPR.reps,
        );
      } else {
        value = _calculateEstimatedLoad(
          record.endurancePR.weight,
          record.endurancePR.reps,
        );
      }

      points.add(FlSpot(i.toDouble(), value));
    }

    return points;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Progress Chart'),
      ),
      body: lifts.isEmpty
          ? const Center(child: Text('No lifts found.'))
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  DropdownButton<Lift>(
                    value: selectedLift,
                    isExpanded: true,
                    hint: const Text('Select a Lift'),
                    onChanged: (lift) {
                      setState(() => selectedLift = lift);
                    },
                    items: lifts.map((lift) {
                      return DropdownMenuItem(
                        value: lift,
                        child: Text(lift.name),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButton<String>(
                    value: selectedType,
                    isExpanded: true,
                    onChanged: (value) {
                      setState(() => selectedType = value!);
                    },
                    items: const [
                      DropdownMenuItem(
                        value: 'Strength',
                        child: Text('Strength (Weight × Reps)'),
                      ),
                      DropdownMenuItem(
                        value: 'Endurance',
                        child: Text('Endurance (Weight × Reps)'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: selectedLift == null
                        ? const Center(child: Text('Select a lift to view progress'))
                        : _buildChart(selectedLift!),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildChart(Lift lift) {
  final data = _generateChartData(lift);
  if (data.isEmpty) {
    return const Center(child: Text('No data available for this lift.'));
  }

  return LineChart(
  LineChartData(
    gridData: FlGridData(
      show: true,
      horizontalInterval: 20,
      verticalInterval: 1,
      drawVerticalLine: false,
      getDrawingHorizontalLine: (value) => FlLine(
        color: Colors.white24,
        strokeWidth: 1,
      ),
    ),
    borderData: FlBorderData(
      show: true,
      border: const Border(
        left: BorderSide(color: Colors.white),
        bottom: BorderSide(color: Colors.white),
      ),
    ),
    titlesData: FlTitlesData(
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 20,
          reservedSize: 50,
          getTitlesWidget: (value, meta) {
            return Text(
              '${value.toInt()}',
              style: const TextStyle(color: Colors.white70, fontSize: 12),
            );
          },
        ),
        axisNameWidget: Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Text(
            'Estimated Load',
            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
          ),
        ),
        axisNameSize: 20,
      ),
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          interval: 1,
          getTitlesWidget: (value, meta) {
            final index = value.toInt();
            final totalPoints = lift.prHistory.length;
            if (index >= totalPoints) return const SizedBox();

            // Show every other label if too many points
            if (totalPoints > 10 && index % 2 != 0) return const SizedBox();

            final date = lift.prHistory[index].date;
            return Transform.rotate(
              angle: -0.5, // rotate ~-30 degrees
              child: Text(
                '${date.month}/${date.day}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            );
          },
        ),
        axisNameWidget: Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Text(
            'Date',
            style: TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold),
          ),
        ),
        axisNameSize: 20,
      ),
    ),
    lineBarsData: [
      LineChartBarData(
        spots: data,
        isCurved: true,
        color: selectedType == 'Strength' ? Colors.orangeAccent : Colors.lightBlueAccent,
        dotData: const FlDotData(show: true),
        belowBarData: BarAreaData(show: false),
      ),
    ],
  ),
);
}
}
