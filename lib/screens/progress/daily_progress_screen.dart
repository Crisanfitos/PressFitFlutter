import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/progress_service.dart';
import 'package:pressfit/theme/app_theme.dart';

class DailyProgressScreen extends StatefulWidget {
  const DailyProgressScreen({super.key});

  @override
  State<DailyProgressScreen> createState() => _DailyProgressScreenState();
}

class _DailyProgressScreenState extends State<DailyProgressScreen> {
  bool _loading = true;
  _DailyStats? _stats;

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
      final data = await ProgressService.getDailyProgress(userId, DateTime.now());

      if (data.isEmpty) {
        if (mounted) setState(() { _stats = null; _loading = false; });
        return;
      }

      int exercises = 0;
      int sets = 0;
      int duration = 0;
      double totalWeight = 0;

      for (final workout in data) {
        if (workout['hora_inicio'] != null && workout['hora_fin'] != null) {
          final start = DateTime.parse(workout['hora_inicio'] as String);
          final end = DateTime.parse(workout['hora_fin'] as String);
          duration += end.difference(start).inMinutes;
        }
        final eps = workout['ejercicios_programados'] as List? ?? [];
        exercises += eps.length;
        for (final ep in eps) {
          final series = ep['series'] as List? ?? [];
          sets += series.length;
          for (final s in series) {
            totalWeight += ((s['peso_utilizado'] as num?) ?? 0) * ((s['repeticiones'] as num?) ?? 0);
          }
        }
      }

      if (mounted) {
        setState(() {
          _stats = _DailyStats(exercises: exercises, sets: sets, duration: duration, totalWeight: totalWeight.round());
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

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                const Expanded(child: Center(child: Text('Progreso Diario', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)))),
                const SizedBox(width: 48),
              ],
            ),
            Divider(height: 1, color: theme.dividerColor.withAlpha(25)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _stats == null
                      ? _buildEmptyState(theme)
                      : Padding(
                          padding: const EdgeInsets.all(16),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: [
                              _buildStatCard(theme, Icons.fitness_center, '${_stats!.exercises}', 'Ejercicios'),
                              _buildStatCard(theme, Icons.repeat, '${_stats!.sets}', 'Series'),
                              _buildStatCard(theme, Icons.timer, '${_stats!.duration}', 'Minutos'),
                              _buildStatCard(theme, Icons.speed, '${_stats!.totalWeight}', 'Kg Totales'),
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, IconData icon, String value, String label) {
    return SizedBox(
      width: (MediaQuery.of(context).size.width - 44) / 2,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 28, color: AppColors.primary),
            const SizedBox(height: 8),
            Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
            Text(label, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
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
            Icon(Icons.today, size: 64, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 24),
            Text('Sin entrenamientos hoy', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color), textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text('Completa un entrenamiento para ver tu progreso del día', style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _DailyStats {
  final int exercises, sets, duration, totalWeight;
  _DailyStats({required this.exercises, required this.sets, required this.duration, required this.totalWeight});
}
