import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/progress_service.dart';
import 'package:pressfit/theme/app_theme.dart';

class MonthlyProgressScreen extends StatefulWidget {
  const MonthlyProgressScreen({super.key});

  @override
  State<MonthlyProgressScreen> createState() => _MonthlyProgressScreenState();
}

class _MonthlyProgressScreenState extends State<MonthlyProgressScreen> {
  DateTime _currentDate = DateTime.now();
  bool _loading = true;
  List<_WeekData> _weeklyData = [];
  int _totalWorkouts = 0;
  int _totalMinutes = 0;

  static const _months = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final data = await ProgressService.getMonthlyProgress(
        userId,
        year: _currentDate.year,
        month: _currentDate.month,
      );

      // Group by week
      final firstDay = DateTime(_currentDate.year, _currentDate.month, 1);
      final lastDay = DateTime(_currentDate.year, _currentDate.month + 1, 0);
      final weeks = <_WeekData>[];
      int totalMin = 0;

      var weekStart = firstDay;
      int weekNum = 1;
      while (weekStart.isBefore(lastDay) || weekStart.isAtSameMomentAs(lastDay)) {
        var weekEnd = weekStart.add(const Duration(days: 6));
        if (weekEnd.isAfter(lastDay)) weekEnd = lastDay;

        int durationMin = 0;
        int count = 0;
        for (final w in data) {
          if (w['hora_inicio'] != null && w['hora_fin'] != null) {
            final fin = DateTime.parse(w['hora_fin'] as String);
            final fechaDia = w['fecha_dia'] as String?;
            DateTime? workoutDate;
            if (fechaDia != null) {
              workoutDate = DateTime.tryParse(fechaDia);
            } else {
              workoutDate = fin;
            }
            if (workoutDate != null &&
                !workoutDate.isBefore(weekStart) &&
                !workoutDate.isAfter(weekEnd)) {
              final start = DateTime.parse(w['hora_inicio'] as String);
              durationMin += fin.difference(start).inMinutes;
              count++;
            }
          }
        }
        totalMin += durationMin;

        weeks.add(_WeekData(
          label: 'S$weekNum',
          durationMinutes: durationMin,
          workouts: count,
          startDate: '${weekStart.day.toString().padLeft(2, '0')}/${weekStart.month.toString().padLeft(2, '0')}',
          endDate: '${weekEnd.day.toString().padLeft(2, '0')}/${weekEnd.month.toString().padLeft(2, '0')}',
        ));

        weekStart = weekEnd.add(const Duration(days: 1));
        weekNum++;
      }

      if (mounted) {
        setState(() {
          _weeklyData = weeks;
          _totalWorkouts = data.length;
          _totalMinutes = totalMin;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _goPrevMonth() {
    setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month - 1));
    _loadData();
  }

  void _goNextMonth() {
    final now = DateTime.now();
    if (_currentDate.year < now.year ||
        (_currentDate.year == now.year && _currentDate.month < now.month)) {
      setState(() => _currentDate = DateTime(_currentDate.year, _currentDate.month + 1));
      _loadData();
    }
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _currentDate.year == now.year && _currentDate.month == now.month;
  }

  String _formatDuration() {
    final hours = _totalMinutes ~/ 60;
    final mins = _totalMinutes % 60;
    if (hours == 0) return 'Este mes has entrenado un total de $mins minutos';
    if (mins == 0) return 'Este mes has entrenado un total de $hours ${hours == 1 ? 'hora' : 'horas'}';
    return 'Este mes has entrenado un total de $hours ${hours == 1 ? 'hora' : 'horas'} y $mins minutos';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxDuration = _weeklyData.isNotEmpty
        ? _weeklyData.map((w) => w.durationMinutes).reduce((a, b) => a > b ? a : b).clamp(1, double.infinity).toInt()
        : 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                const Expanded(child: Center(child: Text('Progreso Mensual', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)))),
                const SizedBox(width: 48),
              ],
            ),
            Divider(height: 1, color: theme.dividerColor.withAlpha(25)),

            // Month selector
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                border: Border(bottom: BorderSide(color: theme.dividerColor.withAlpha(25))),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(icon: const Icon(Icons.chevron_left), onPressed: _goPrevMonth),
                  Text('${_months[_currentDate.month - 1]} ${_currentDate.year}',
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                  IconButton(
                    icon: Icon(Icons.chevron_right, color: _isCurrentMonth ? theme.dividerColor : null),
                    onPressed: _isCurrentMonth ? null : _goNextMonth,
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Duration text + bar chart
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: theme.dividerColor.withAlpha(25)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_formatDuration(),
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: theme.textTheme.bodyLarge?.color)),
                              const SizedBox(height: 16),
                              SizedBox(
                                height: 200,
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: _weeklyData.map((week) {
                                    final pct = week.durationMinutes / maxDuration;
                                    return Expanded(
                                      child: GestureDetector(
                                        onTap: () => _showWeekInfo(week),
                                        child: Column(
                                          mainAxisAlignment: MainAxisAlignment.end,
                                          children: [
                                            Text('${week.durationMinutes}m',
                                                style: TextStyle(fontSize: 10, color: theme.textTheme.bodyMedium?.color)),
                                            const SizedBox(height: 4),
                                            Container(
                                              width: 30,
                                              height: (150 * pct).clamp(4, 150),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                            Text(week.label,
                                                style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                                          ],
                                        ),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Summary card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.cardTheme.color,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            children: [
                              const Icon(Icons.fitness_center, size: 32, color: AppColors.primary),
                              const SizedBox(height: 8),
                              Text('$_totalWorkouts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                              Text('Entrenamientos', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showWeekInfo(_WeekData week) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('del ${week.startDate} al ${week.endDate}: ${week.workouts} entrenos, ${week.durationMinutes}min'),
        duration: const Duration(seconds: 2),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _WeekData {
  final String label;
  final int durationMinutes;
  final int workouts;
  final String startDate;
  final String endDate;
  _WeekData({required this.label, required this.durationMinutes, required this.workouts, required this.startDate, required this.endDate});
}
