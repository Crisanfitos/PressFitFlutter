import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/routine_service.dart';
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
  String? _errorMessage;

  // Raw day data (instance or template)
  Map<String, dynamic>? _rawDayData;
  List<dynamic> _exercises = [];

  // Derived stats
  bool _isCompleted = false;
  bool _isActive = false;
  String? _activeWorkoutId;
  int _exerciseCount = 0;
  int? _durationMinutes;
  String _dayName = '';
  String? _dayDescription;

  late DateTime _selectedDate;

  static const _dayNames = [
    'Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'
  ];
  static const _monthNames = [
    'Ene', 'Feb', 'Mar', 'Abr', 'May', 'Jun',
    'Jul', 'Ago', 'Sep', 'Oct', 'Nov', 'Dic'
  ];

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

  /// Replicates exactly the RN loadDayData logic:
  /// 1. Try getRoutineDayByDate (finds workout instance for specific date)
  /// 2. Fallback to getRoutineDayByName (gets template)
  /// 3. Derive all stats from the found data
  Future<void> _loadDayData() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null || widget.routineId == null) {
      setState(() {
        _loading = false;
        _errorMessage = 'No se pudo cargar datos del día';
      });
      return;
    }

    setState(() {
      _loading = true;
      _errorMessage = null;
    });

    try {
      final dateStr =
          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      final dayName = _dayNames[_selectedDate.weekday % 7];

      debugPrint('WorkoutDay: loading data for $dateStr, routine=${widget.routineId}, dayName=$dayName');

      // Step 1: Try to find workout instance by date (direct Supabase query)
      Map<String, dynamic>? targetDay;
      try {
        final data = await RoutineService.supabase
            .from('rutinas_diarias')
            .select('''
              *,
              ejercicios_programados (
                id, ejercicio_id, orden_ejecucion, tipo_peso, notas_sesion,
                ejercicio:ejercicios (*),
                series (*)
              )
            ''')
            .eq('rutina_semanal_id', widget.routineId!)
            .eq('fecha_dia', dateStr)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();
        targetDay = data;
        debugPrint('WorkoutDay: instance by date: ${targetDay != null ? "found" : "not found"}');
      } catch (e) {
        debugPrint('WorkoutDay: getByDate error: $e');
      }

      // Step 2: Fallback to template by day name
      if (targetDay == null) {
        try {
          final data = await RoutineService.supabase
              .from('rutinas_diarias')
              .select('''
                *,
                ejercicios_programados (
                  id, ejercicio_id, orden_ejecucion, tipo_peso, notas_sesion,
                  ejercicio:ejercicios (*),
                  series (*)
                )
              ''')
              .eq('rutina_semanal_id', widget.routineId!)
              .eq('nombre_dia', dayName)
              .isFilter('fecha_dia', null)
              .limit(1)
              .maybeSingle();
          targetDay = data;
          debugPrint('WorkoutDay: template by name: ${targetDay != null ? "found" : "not found"}');
        } catch (e) {
          debugPrint('WorkoutDay: getByName error: $e');
        }
      }

      if (targetDay != null && mounted) {
        // Sort exercises by orden_ejecucion
        final rawExercises =
            (targetDay['ejercicios_programados'] as List<dynamic>?) ?? [];
        rawExercises.sort((a, b) =>
            ((a['orden_ejecucion'] ?? 0) as int)
                .compareTo((b['orden_ejecucion'] ?? 0) as int));

        // Sort series within each exercise
        for (final ex in rawExercises) {
          final series = (ex['series'] as List<dynamic>?) ?? [];
          series.sort((a, b) =>
              ((a['numero_serie'] ?? 0) as int)
                  .compareTo((b['numero_serie'] ?? 0) as int));
        }

        final uniqueExerciseIds =
            rawExercises.map((e) => e['ejercicio_id']).toSet();

        // Calculate duration
        int? duration;
        if (targetDay['hora_inicio'] != null &&
            targetDay['hora_fin'] != null) {
          final start = DateTime.parse(targetDay['hora_inicio'] as String);
          final end = DateTime.parse(targetDay['hora_fin'] as String);
          final mins = end.difference(start).inMinutes;
          if (mins >= 5) duration = mins;
        }

        final isCompleted =
            (targetDay['completada'] == true) || targetDay['hora_fin'] != null;
        final isActive = targetDay['hora_inicio'] != null &&
            targetDay['completada'] != true &&
            targetDay['hora_fin'] == null;

        debugPrint('WorkoutDay: exercises=${rawExercises.length}, completed=$isCompleted, active=$isActive');

        setState(() {
          _rawDayData = targetDay;
          _exercises = rawExercises;
          _dayName = targetDay!['nombre_dia'] as String? ?? dayName;
          _dayDescription = targetDay['descripcion'] as String?;
          _exerciseCount = uniqueExerciseIds.length;
          _durationMinutes = duration;
          _isCompleted = isCompleted;
          _isActive = isActive;
          _activeWorkoutId =
              isActive ? targetDay['id'] as String? : null;
          _loading = false;
        });
      } else {
        debugPrint('WorkoutDay: no data found for this day');
        setState(() {
          _rawDayData = null;
          _exercises = [];
          _dayName = dayName;
          _loading = false;
          _errorMessage = 'No hay datos para este día';
        });
      }
    } catch (e) {
      debugPrint('WorkoutDay._loadDayData error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _errorMessage = 'Error al cargar: $e';
        });
      }
    }
  }

  Future<void> _navigateToWorkout(String workoutId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => WorkoutScreen(
          workoutId: workoutId,
          dayName: _dayName,
          routineDayId: _rawDayData?['id'] as String? ?? '',
        ),
      ),
    );
    if (mounted) _loadDayData();
  }

  Future<void> _handleStartWorkout() async {
    if (_rawDayData == null) return;
    setState(() => _loading = true);

    try {
      final dayId = _rawDayData!['id'] as String;
      final now = DateTime.now();
      final newWorkout = await RoutineService.startDailyWorkout(
        dayId,
        now.toIso8601String(),
        now.toIso8601String(),
      );

      if (newWorkout != null && mounted) {
        _navigateToWorkout(newWorkout.id);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error: no se creó el entrenamiento')),
          );
          setState(() => _loading = false);
        }
      }
    } catch (e) {
      debugPrint('handleStartWorkout error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al crear entrenamiento: $e')),
        );
        setState(() => _loading = false);
      }
    }
  }

  void _handleContinueWorkout() {
    if (_activeWorkoutId != null) {
      _navigateToWorkout(_activeWorkoutId!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(_errorMessage!,
                          style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                    ),
                  Text(
                    _isCompleted
                        ? 'Ejercicios'
                        : 'Ejercicios (${_exercises.length})',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_exercises.isEmpty)
                    _buildEmptyState(theme)
                  else if (_isCompleted)
                    ..._exercises.map((ex) => _buildCompletedExerciseCard(theme, ex))
                  else
                    ..._exercises.map((ex) => _buildExerciseCard(theme, ex)),
                ],
              ),
            ),
            // Action button
            if (_exercises.isNotEmpty) _buildActionButton(theme),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme) {
    if (_isCompleted) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () {
              final id = _rawDayData?['id'] as String?;
              if (id != null) _navigateToWorkout(id);
            },
            icon: const Icon(Icons.visibility),
            label: const Text('Ver Entrenamiento'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      );
    }

    if (widget.isToday && !_isCompleted) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _isActive ? _handleContinueWorkout : _handleStartWorkout,
            icon: Icon(_isActive ? Icons.play_arrow : Icons.play_circle_filled),
            label: Text(
                _isActive ? 'Continuar Entrenamiento' : 'Empezar Entrenamiento'),
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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
              Text(_formattedDate,
                  style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color)),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _dayName.isNotEmpty ? _dayName : 'Sin entrenar',
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
          ),
          if (_dayDescription != null) ...[
            const SizedBox(height: 4),
            Text(_dayDescription!,
                style: const TextStyle(color: AppColors.primary, fontStyle: FontStyle.italic)),
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
                  Text('Completado',
                      style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w600)),
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
                  Text('$_exerciseCount Ejercicios',
                      style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(width: 16),
                  const Icon(Icons.timer, size: 20, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(_formatDuration(_durationMinutes),
                      style: TextStyle(fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
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
                  Text('En Progreso',
                      style: TextStyle(color: AppColors.warning, fontWeight: FontWeight.w600)),
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
    final ejercicio = ex['ejercicio'] as Map<String, dynamic>?;
    final series = (ex['series'] as List<dynamic>?) ?? [];

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
            width: 48, height: 48,
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
                Text(ejercicio?['titulo'] as String? ?? 'Ejercicio',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                const SizedBox(height: 4),
                Text(ejercicio?['grupo_muscular'] as String? ?? 'Sin grupo',
                    style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
              ],
            ),
          ),
          Column(
            children: [
              Text('${series.length}',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
              Text('series', style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedExerciseCard(ThemeData theme, dynamic ex) {
    final ejercicio = ex['ejercicio'] as Map<String, dynamic>?;
    final series = (ex['series'] as List<dynamic>?) ?? [];

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
          Row(
            children: [
              Container(
                width: 48, height: 48,
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
                    Text(ejercicio?['titulo'] as String? ?? 'Ejercicio',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                    const SizedBox(height: 2),
                    Text(ejercicio?['grupo_muscular'] as String? ?? 'Sin grupo',
                        style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
            ],
          ),
          const Divider(height: 24),
          if (series.isEmpty)
            Text('No se registraron series.',
                style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color))
          else
            ...series.map((set) {
              final peso = set['peso_utilizado'];
              final reps = set['repeticiones'];
              final rpe = set['rpe'];
              final descanso = set['descanso_segundos'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                      width: 60,
                      child: Text('Serie ${set['numero_serie'] ?? 0}',
                          style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                    ),
                    Expanded(
                      child: Text('${peso ?? 0} kg × ${reps ?? 0} reps',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.textTheme.bodyLarge?.color)),
                    ),
                    if (rpe != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: theme.textTheme.bodyMedium?.color?.withAlpha(32),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('RPE $rpe',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                      ),
                    if (descanso != null && (descanso as int) > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(32),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text('${descanso}s',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.primary)),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}
