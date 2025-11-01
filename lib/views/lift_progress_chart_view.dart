import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/lift.dart';
import '../utils/storage.dart';
import '../widgets/grouped_lift_picker.dart'; // ← grouped selector widget

class _ChartPoint {
  final int index;
  final DateTime date;
  final int weight;
  final int reps;

  _ChartPoint({
    required this.index,
    required this.date,
    required this.weight,
    required this.reps,
  });
}

class LiftProgressChartView extends StatefulWidget {
  const LiftProgressChartView({super.key});

  @override
  State<LiftProgressChartView> createState() => _LiftProgressChartViewState();
}

class _LiftProgressChartViewState extends State<LiftProgressChartView> {
  List<Lift> lifts = [];

  // New: grouped selection state (persisted)
  String selectedGroup = 'All';
  String? selectedLiftName;

  @override
  void initState() {
    super.initState();
    _loadLifts();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    selectedGroup = prefs.getString('chart_last_group') ?? 'All';
    selectedLiftName = prefs.getString('chart_last_lift');
  }

  Future<void> _savePrefs() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('chart_last_group', selectedGroup);
    if (selectedLiftName != null) {
      await prefs.setString('chart_last_lift', selectedLiftName!);
    } else {
      await prefs.remove('chart_last_lift');
    }
  }

  Future<void> _loadLifts() async {
    await _loadPrefs();

    final loaded = await Storage.loadLifts();
    lifts = loaded;

    // Choose a sensible default based on saved group/lift
    String effectiveGroup = selectedGroup;
    final byGroup = filterLiftsByGroup(lifts, effectiveGroup);

    String? effectiveLiftName = selectedLiftName;

    if (effectiveLiftName == null ||
        !byGroup.any((l) => l.name == effectiveLiftName)) {
      // Prefer a lift with history within the group, else first in group
      if (byGroup.isNotEmpty) {
        final pick = byGroup.firstWhere(
          (l) => l.prHistory.isNotEmpty,
          orElse: () => byGroup.first,
        );
        effectiveLiftName = pick.name;
      } else {
        // Fall back to All if the selected group has no lifts
        effectiveGroup = 'All';
        final all = filterLiftsByGroup(lifts, 'All');
        if (all.isNotEmpty) {
          final pick = all.firstWhere(
            (l) => l.prHistory.isNotEmpty,
            orElse: () => all.first,
          );
          effectiveLiftName = pick.name;
        }
      }
    }

    setState(() {
      selectedGroup = effectiveGroup;
      selectedLiftName = effectiveLiftName;
    });

    await _savePrefs();
  }

  Lift? get _selectedLift {
    if (selectedLiftName == null) return null;
    return lifts.firstWhere(
      (l) => l.name == selectedLiftName,
      orElse: () => lifts.isNotEmpty ? lifts.first : Lift(name: ''),
    );
  }

  List<_ChartPoint> _strengthPointsFor(Lift lift) {
    final points = <_ChartPoint>[];
    for (final rec in lift.prHistory) {
      final w = rec.strengthPR.weight;
      final r = rec.strengthPR.reps;
      if (w <= 0 || r <= 0) continue;
      points.add(_ChartPoint(
        index: points.length,
        date: rec.date,
        weight: w,
        reps: r,
      ));
    }
    return points;
  }

  List<_ChartPoint> _endurancePointsFor(Lift lift) {
    final points = <_ChartPoint>[];
    for (final rec in lift.prHistory) {
      final w = rec.endurancePR.weight;
      final r = rec.endurancePR.reps;
      if (w <= 0 || r <= 0) continue;
      points.add(_ChartPoint(
        index: points.length,
        date: rec.date,
        weight: w,
        reps: r,
      ));
    }
    return points;
  }

  Widget _buildChartSection({
    required String title,
    required Color accentColor,
    required List<_ChartPoint> points,
  }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (points.isEmpty) {
      return Card(
        color: cs.surface.withOpacity(0.35),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'No $title PR history yet.',
            style: tt.bodyMedium?.copyWith(
              color: tt.bodyMedium?.color?.withOpacity(0.7),
            ),
          ),
        ),
      );
    }

    final spots = points
        .map((p) => FlSpot(p.index.toDouble(), p.weight.toDouble()))
        .toList();

    final axisTextStyle = tt.bodySmall?.copyWith(
      color: tt.bodySmall?.color?.withOpacity(0.8),
      fontSize: 12,
    );

    return Card(
      color: cs.surface.withOpacity(0.35),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '$title Progress',
              style: tt.titleMedium?.copyWith(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 240,
              child: LineChart(
                LineChartData(
                  clipData: FlClipData.none(),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    horizontalInterval: 20,
                    getDrawingHorizontalLine: (value) => FlLine(
                      color: tt.bodySmall?.color?.withOpacity(0.15),
                      strokeWidth: 1,
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border(
                      left: BorderSide(
                        color:
                            tt.bodySmall?.color?.withOpacity(0.6) ?? Colors.white,
                      ),
                      bottom: BorderSide(
                        color:
                            tt.bodySmall?.color?.withOpacity(0.6) ?? Colors.white,
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      axisNameWidget: Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text(
                          'Weight (lbs)',
                          style: tt.titleSmall?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      axisNameSize: 36,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        interval: 20,
                        getTitlesWidget: (value, meta) =>
                            Text('${value.toInt()}', style: axisTextStyle),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      axisNameWidget: Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Date',
                          style: tt.titleSmall?.copyWith(
                            color: accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      axisNameSize: 28,
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 32,
                        interval: 1,
                        getTitlesWidget: (value, meta) {
                          final idx = value.toInt();
                          if (idx < 0 || idx >= points.length) {
                            return const SizedBox.shrink();
                          }
                          final tooMany = points.length > 10;
                          if (tooMany && idx.isOdd) return const SizedBox.shrink();
                          final d = points[idx].date;
                          return Transform.rotate(
                            angle: -0.5,
                            child: Text(
                              '${d.month}/${d.day}',
                              style: axisTextStyle,
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    rightTitles:
                        const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  ),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((barSpot) {
                          final idx = barSpot.x.toInt();
                          if (idx < 0 || idx >= points.length) return null;
                          final p = points[idx];
                          final d = p.date;
                          final tip =
                              '${p.weight} lbs x ${p.reps}\n${d.month}/${d.day}/${d.year}';
                          return LineTooltipItem(
                            tip,
                            tt.bodySmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ) ??
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                          );
                        }).whereType<LineTooltipItem>().toList();
                      },
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: accentColor,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: false),
                      barWidth: 3,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (lifts.isEmpty) {
      return Scaffold(
        body: Center(
          child: Text('No lifts found.', style: tt.bodyLarge),
        ),
      );
    }

    final lift = _selectedLift;

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // NEW: Grouped selector (same UX as HistoryView)
            GroupedLiftPicker(
              lifts: lifts,
              selectedGroup: selectedGroup,
              selectedLiftName: selectedLiftName,
              onGroupChanged: (g) async {
                setState(() {
                  selectedGroup = g;
                });
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
            const SizedBox(height: 16),

            Expanded(
              child: lift == null
                  ? Center(
                      child: Text(
                        'Select a lift to view progress',
                        style: tt.bodyLarge,
                      ),
                    )
                  : ListView(
                      children: [
                        _buildChartSection(
                          title: 'Strength',
                          accentColor: cs.primary,
                          points: _strengthPointsFor(lift),
                        ),
                        const SizedBox(height: 24),
                        _buildChartSection(
                          title: 'Endurance',
                          accentColor: cs.secondary,
                          points: _endurancePointsFor(lift),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
