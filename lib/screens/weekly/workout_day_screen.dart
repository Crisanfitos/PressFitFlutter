import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/routine_service.dart';
import 'package:pressfit/models/rutina_diaria.dart';
import 'package:pressfit/screens/weekly/workout_screen.dart';
import 'package:pressfit/theme/app_theme.dart';

class WorkoutDayScreen extends StatefulWidget {
  final String date;
  final String? routineId;
  final bool isToday;

  const WorkoutDayScreen({
    super.key,
    required this.date,
    this.routineId,
    this.isToday = false,
  });

  @override
  State<WorkoutDayScreen> createState() => _WorkoutDayScreenState();
}

class _WorkoutDayScreenState extends State<WorkoutDayScreen> {
  bool _loading = true;
  RutinaDiaria? _dayData;
  bool _isCompleted = false;
  bool _isActive = false;
  int _exerciseCount = 0;
  int? _durationMinutes;

  late DateTime _selectedDate;

  static const _dayNames = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];
  static const _monthNames = ['Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun', 'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'];

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.date);
    _loadDayData();
  }

  String get _formattedDate {
    return '${_dayNames[_selectedDate.weekday % 7]}, ${_selectedDate.day} de ${_monthNames[_selectedDate.month - 1]} ${_selectedDate.year}';
  }

  String _formatDuration(int? minutes) {
    if (minutes == null) return '-';
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _loadDayData() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null || widget.routineId == null) {
      setState(() => _loading = false);
      return;
    }

    setState(() => _loading = true);

    try {
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';

      // Try instance for this date first
      var targetDay = await RoutineService.getRoutineDayByDate(widget.routineId!, dateStr);

      // Fall back to template by day name
      if (targetDay == null) {
        final dayName = _dayNames[_selectedDate.weekday % 7];
        targetDay = await RoutineService.getRoutineDayByName(widget.routineId!, dayName);
      }

      if (targetDay != null && mounted) {
        final exercises = targetDay.ejerciciosProgramados;
        final exerciseIds = exercises.map((e) => e.ejercicioId).toSet();

        int? duration;
        if (targetDay.horaInicio != null && targetDay.horaFin != null) {
          final start = DateTime.parse(targetDay.horaInicio!);
          final end = DateTime.parse(targetDay.horaFin!);
          final mins = end.difference(start).inMinutes;
          if (mins >= 5) duration = mins;
        }

        setState(() {
          _dayData = targetDay;
          _exerciseCount = exerciseIds.length;
          _durationMinutes = duration;
          _isCompleted = targetDay!.completada || targetDay.horaFin != null;
          _isActive = targetDay.horaInicio != null && !targetDay.completada && targetDay.horaFin == null;
          _loading = false;
        });
      } else {
        setState(() {
          _dayData = null;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _navigateToWorkout(String workoutId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(
          workoutId: workoutId,
          dayName: _dayData!.nombreDia,
          routineDayId: _dayData!.id,
        ),
      ),
    );
    // Refresh on return
    if (mounted) _loadDayData();
  }

  Future<void> _handleStartWorkout() async {
    if (_dayData == null) return;
    setState(() => _loading = true);

    try {
      final now = DateTime.now();
      final newWorkout = await RoutineService.startDailyWorkout(
        _dayData!.id,
        now.toIso8601String(),
        now.toIso8601String(),
      );

      if (newWorkout != null && mounted) {
        _navigateToWorkout(newWorkout.id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al crear entrenamiento')),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleContinueWorkout() {
    if (_dayData == null) return;
    _navigateToWorkout(_dayData!.id);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = _dayData?.ejerciciosProgramados ?? [];

    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildHeader(theme),

            // Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    _isCompleted ? 'Ejercicios' : 'Ejercicios (${exercises.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),

                  if (exercises.isEmpty)
                    _buildEmptyState(theme)
                  else if (_isCompleted)
                    ...exercises.map((ex) => _buildCompletedExerciseCard(theme, ex))
                  else
                    ...exercises.map((ex) => _buildExerciseCard(theme, ex)),
                ],
              ),
            ),

            // Action Button
            if (widget.isToday && exercises.isNotEmpty && !_isCompleted)
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _isActive ? _handleContinueWorkout : _handleStartWorkout,
                    icon: Icon(_isActive ? Icons.play_arrow : Icons.play_circle_filled),
                    label: Text(_isActive ? 'Continuar Entrenamiento' : 'Empezar Entrenamiento'),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: theme.dividerColor.withAlpha(25))),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => context.go('/weekly'),
              ),
              const SizedBox(width: 8),
              Text(_formattedDate, style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _dayData?.nombreDia ?? 'Sin entrenar',
            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
          ),
          if (_dayData?.descripcion != null) ...[
            const SizedBox(height: 4),
            Text(_dayData!.descripcion!, style: const TextStyle(color: AppColors.primary, fontStyle: FontStyle.italic)),
          ],
          if (_isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.success.withAlpha(51),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 18, color: AppColors.success),
                  SizedBox(width: 6),
                  Text('Completado', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.cardTheme.color,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: theme.dividerColor.withAlpha(25)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, size: 20, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text('$_exerciseCount Ejercicios', style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(width: 16),
                  const Icon(Icons.timer, size: 20, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(_formatDuration(_durationMinutes), style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                ],
              ),
            ),
          ],
          if (_isActive && !_isCompleted) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.warning.withAlpha(51),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.play_circle, size: 18, color: AppColors.warning),
                  SizedBox(width: 6),
                  Text('En Progreso', style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(Icons.fitness_center, size: 48, color: theme.textTheme.bodyMedium?.color),
            const SizedBox(height: 12),
            Text(
              'No hay ejercicios programados para este día.\nEdita tu rutina para añadir ejercicios.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseCard(ThemeData theme, dynamic ex) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(51),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.fitness_center, size: 24, color: AppColors.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ex.ejercicio?.titulo ?? 'Ejercicio',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color),
                ),
                const SizedBox(height: 4),
                Text(
                  ex.ejercicio?.grupoMuscular ?? 'Sin grupo',
                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${ex.series.length}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
              Text('series', style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedExerciseCard(ThemeData theme, dynamic ex) {
    final sortedSeries = List.from(ex.series)..sort((a, b) => a.numeroSerie.compareTo(b.numeroSerie));

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(51),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.fitness_center, size: 24, color: AppColors.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.ejercicio?.titulo ?? 'Ejercicio',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      ex.ejercicio?.grupoMuscular ?? 'Sin grupo',
                      style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          // Series
          if (sortedSeries.isEmpty)
            Text('No se registraron series.',
                style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color))
          else
            ...sortedSeries.map((set) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 60,
                        child: Text('Serie ${set.numeroSerie}',
                            style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                      ),
                      Expanded(
                        child: Text(
                          '${set.pesoUtilizado ?? 0} kg × ${set.repeticiones ?? 0} reps',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.textTheme.bodyLarge?.color),
                        ),
                      ),
                      if (set.rpe != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: theme.textTheme.bodyMedium?.color?.withAlpha(32),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('RPE ${set.rpe}',
                              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                        ),
                      if (set.descansoSegundos != null && set.descansoSegundos! > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withAlpha(32),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text('${set.descansoSegundos}s',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                )),
        ],
      ),
    );
  }
}
