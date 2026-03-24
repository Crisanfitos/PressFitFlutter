import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/progress_service.dart';
import 'package:pressfit/theme/app_theme.dart';

class WeeklyProgressScreen extends StatefulWidget {
  const WeeklyProgressScreen({super.key});

  @override
  State<WeeklyProgressScreen> createState() => _WeeklyProgressScreenState();
}

class _WeeklyProgressScreenState extends State<WeeklyProgressScreen> {
  bool _loading = true;
  List<_DayData> _dayData = [];
  int _totalWorkouts = 0;
  int _totalDuration = 0;

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
      final data = await ProgressService.getWeeklyProgress(userId);

      const dayLabels = ['D', 'L', 'M', 'X', 'J', 'V', 'S'];
      final days = List.generate(7, (i) => _DayData(day: dayLabels[i], workouts: 0, duration: 0));

      for (final w in data) {
        if (w['hora_inicio'] != null && w['hora_fin'] != null) {
          final fin = DateTime.parse(w['hora_fin'] as String);
          final start = DateTime.parse(w['hora_inicio'] as String);
          final dayIndex = fin.weekday % 7; // Sunday=0
          days[dayIndex] = _DayData(
            day: days[dayIndex].day,
            workouts: days[dayIndex].workouts + 1,
            duration: days[dayIndex].duration + fin.difference(start).inMinutes,
          );
        }
      }

      if (mounted) {
        setState(() {
          _dayData = days;
          _totalWorkouts = data.length;
          _totalDuration = days.fold(0, (sum, d) => sum + d.duration);
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final maxDuration = _dayData.isNotEmpty
        ? _dayData.map((d) => d.duration).reduce((a, b) => a > b ? a : b).clamp(1, double.infinity).toInt()
        : 1;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                const Expanded(child: Center(child: Text('Progreso Semanal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 48),
              ],
            ),
            Divider(height: 1, color: theme.dividerColor.withAlpha(25)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _totalWorkouts == 0
                      ? _buildEmptyState(theme)
                      : ListView(
                          padding: const EdgeInsets.all(16),
                          children: [
                            // Summary
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: theme.cardTheme.color,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        const Icon(Icons.fitness_center, size: 24, color: AppColors.primary),
                                        const SizedBox(height: 8),
                                        Text('$_totalWorkouts', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                                        Text('Entrenamientos', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                                      ],
                                    ),
                                  ),
                                  Container(width: 1, height: 50, color: theme.dividerColor.withAlpha(50)),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        const Icon(Icons.timer, size: 24, color: AppColors.primary),
                                        const SizedBox(height: 8),
                                        Text('$_totalDuration', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                                        Text('Minutos Totales', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Bar chart
                            Text('Duración por Día', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                            const SizedBox(height: 16),
                            SizedBox(
                              height: 200,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: _dayData.map((d) {
                                  final pct = d.duration > 0 ? d.duration / maxDuration : 0.0;
                                  return Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 24,
                                          height: (160 * pct).clamp(4, 160),
                                          decoration: BoxDecoration(
                                            color: d.duration > 0 ? AppColors.primary : theme.dividerColor.withAlpha(50),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(d.day, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Details
                            Text('Detalles', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                            const SizedBox(height: 12),
                            ..._dayData.where((d) => d.workouts > 0).map((d) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: theme.cardTheme.color,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(d.day, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                                          Text('${d.workouts} entrenamiento(s)', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                                        ],
                                      ),
                                      Text('${d.duration} min', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                    ],
                                  ),
                                )),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.trending_up, size: 64, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 24),
            Text('¡Empieza tu semana fuerte!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Entrena esta semana y verás tu progreso reflejado aquí', style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DayData {
  final String day;
  final int workouts;
  final int duration;
  _DayData({required this.day, required this.workouts, required this.duration});
}
