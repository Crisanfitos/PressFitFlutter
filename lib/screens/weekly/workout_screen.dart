import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/workout_service.dart';
import 'package:pressfit/models/rutina_diaria.dart';
import 'package:pressfit/models/ejercicio_programado.dart';
import 'package:pressfit/models/serie.dart';
import 'package:pressfit/theme/app_theme.dart';
import 'package:pressfit/widgets/rest_timer.dart';
import 'package:pressfit/widgets/weight_type_badge.dart';
import 'package:pressfit/widgets/personal_note_button.dart';

enum WorkoutMode { active, view, preview, missed, pending }

class WorkoutScreen extends StatefulWidget {
  final String workoutId;
  final String dayName;
  final String routineDayId;
  final WorkoutMode mode;

  const WorkoutScreen({
    super.key,
    required this.workoutId,
    required this.dayName,
    required this.routineDayId,
    this.mode = WorkoutMode.active,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  RutinaDiaria? _workout;
  bool _loading = true;
  bool _saving = false;
  int _timerSeconds = 0;
  Timer? _timer;
  bool _showRestTimer = false;
  String? _activeTimerSetId;
  final Set<String> _savedTimerSetIds = {};
  Set<String> _collapsedExercises = {};
  // Ghost values: exerciseId -> list of series from previous workout
  Map<String, List<Serie>> _ghostValues = {};
  late WorkoutMode _mode;

  @override
  void initState() {
    super.initState();
    _mode = widget.mode;
    _loadWorkout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _isEditable => _mode == WorkoutMode.active;
  bool get _isStructureEditable => _mode == WorkoutMode.active;

  Future<void> _loadWorkout() async {
    setState(() => _loading = true);
    try {
      final data = await WorkoutService.getWorkoutDetails(widget.workoutId);
      if (data != null && mounted) {
        // Determine mode
        if (data.completada) {
          _mode = WorkoutMode.view;
        } else if (data.horaInicio != null) {
          _mode = WorkoutMode.active;
          // Calculate elapsed time
          final start = DateTime.parse(data.horaInicio!);
          _timerSeconds = DateTime.now().difference(start).inSeconds;
          // Auto-complete if > 3 hours
          if (_timerSeconds > 10800) {
            await WorkoutService.completeWorkout(widget.workoutId);
            if (mounted) context.pop();
            return;
          }
          _startTimer();
        }

        // Collapse all except first
        final exercises = data.ejerciciosProgramados;
        _collapsedExercises = exercises.length > 1
            ? exercises.skip(1).map((e) => e.ejercicioId).toSet()
            : {};

        // Load ghost values for active mode
        if (_mode == WorkoutMode.active) {
          _loadGhostValues();
        }

        setState(() {
          _workout = data;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadGhostValues() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    try {
      final prev = await WorkoutService.getLastCompletedWorkoutForDay(
        userId,
        widget.routineDayId,
      );
      if (prev != null && mounted) {
        final ghost = <String, List<Serie>>{};
        for (final ex in prev.ejerciciosProgramados) {
          if (ex.series.isNotEmpty) {
            ghost[ex.ejercicioId] = ex.series;
          }
        }
        setState(() => _ghostValues = ghost);
      }
    } catch (_) {}
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _timerSeconds++);
    });
  }

  String get _formattedTimer {
    final h = (_timerSeconds ~/ 3600).toString().padLeft(2, '0');
    final m = ((_timerSeconds % 3600) ~/ 60).toString().padLeft(2, '0');
    final s = (_timerSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  Future<void> _handleAddSets(String exerciseId, int count) async {
    final exercises = _workout?.ejerciciosProgramados ?? [];
    final ex = exercises.where((e) => e.ejercicioId == exerciseId).firstOrNull;
    final currentCount = ex?.series.length ?? 0;
    final lastSet = ex?.series.isNotEmpty == true ? ex!.series.last : null;

    for (int i = 0; i < count; i++) {
      await WorkoutService.addSet(
        widget.workoutId,
        exerciseId,
        currentCount + 1 + i,
        lastSet?.pesoUtilizado ?? 0,
        lastSet?.repeticiones ?? 0,
      );
    }
    _loadWorkout();
  }

  void _showAddSetsModal(String exerciseId) {
    int setsToAdd = 1;
    showModalBottomSheet(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Añadir Series',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: setsToAdd > 1
                        ? () => setModalState(() => setsToAdd--)
                        : null,
                    icon: const Icon(Icons.remove_circle_outline, size: 32),
                    color: AppColors.primary,
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text('$setsToAdd',
                        style: const TextStyle(
                            fontSize: 32, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    onPressed: () => setModalState(() => setsToAdd++),
                    icon: const Icon(Icons.add_circle_outline, size: 32),
                    color: AppColors.primary,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _handleAddSets(exerciseId, setsToAdd);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.primaryText,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: Text('Añadir $setsToAdd serie${setsToAdd > 1 ? 's' : ''}'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _handleUpdateSet(String setId,
      {double? weight, int? reps, int? rpe}) async {
    // Update local state immediately for responsiveness
    if (mounted) {
      setState(() {
        final exercises = _workout?.ejerciciosProgramados ?? [];
        for (final ex in exercises) {
          for (int i = 0; i < ex.series.length; i++) {
            if (ex.series[i].id == setId) {
              final old = ex.series[i];
              ex.series[i] = Serie(
                id: old.id,
                ejercicioProgramadoId: old.ejercicioProgramadoId,
                numeroSerie: old.numeroSerie,
                pesoUtilizado: weight ?? old.pesoUtilizado,
                repeticiones: reps ?? old.repeticiones,
                rpe: rpe ?? old.rpe,
                descansoSegundos: old.descansoSegundos,
                createdAt: old.createdAt,
              );
              break;
            }
          }
        }
      });
    }
    await WorkoutService.updateSet(setId, weight: weight, reps: reps, rpe: rpe);
  }

  Future<void> _handleDeleteSet(String setId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Serie'),
        content: const Text('¿Eliminar esta serie?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await WorkoutService.deleteSet(setId);
      _loadWorkout();
    }
  }

  Future<void> _handleFinishWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Entrenamiento'),
        content: const Text(
            '¿Estás seguro de que quieres terminar este entrenamiento?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Finalizar')),
        ],
      ),
    );

    if (confirm == true && mounted) {
      setState(() => _saving = true);
      _timer?.cancel();
      await WorkoutService.completeWorkout(widget.workoutId);
      if (mounted) context.go('/weekly');
    }
  }

  Future<void> _handleRemoveExercise(EjercicioProgramado ex) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Ejercicio'),
        content: Text(
            '¿Eliminar "${ex.ejercicio?.titulo ?? 'ejercicio'}" del entrenamiento?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await WorkoutService.removeExerciseFromRoutine(ex.id);
      _loadWorkout();
    }
  }

  void _handleRestTimerStop(int seconds, String? setId) {
    setState(() => _showRestTimer = false);
    if (setId != null) {
      WorkoutService.updateSet(setId, descansoSegundos: seconds);
      setState(() => _savedTimerSetIds.add(setId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final exercises = _workout?.ejerciciosProgramados ?? [];

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(theme),
                Expanded(
                  child: exercises.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: exercises.length +
                              (_isStructureEditable ? 1 : 0),
                          itemBuilder: (context, index) {
                            if (index == exercises.length) {
                              return _buildAddExerciseButton(theme);
                            }
                            return _buildExerciseSection(
                                theme, exercises[index]);
                          },
                        ),
                ),
              ],
            ),
            if (_showRestTimer)
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: RestTimer(
                  onDismiss: () => setState(() => _showRestTimer = false),
                  onTimerStop: (seconds) =>
                      _handleRestTimerStop(seconds, _activeTimerSetId),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        border: Border(
            bottom: BorderSide(color: theme.dividerColor.withAlpha(25))),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.pop(),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(widget.dayName,
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.bodyLarge?.color)),
                if (_mode == WorkoutMode.active) ...[
                  const SizedBox(height: 2),
                  Text(_formattedTimer,
                      style: const TextStyle(
                          fontSize: 16,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w600)),
                ],
                if (_mode == WorkoutMode.view)
                  Text('Completado',
                      style: TextStyle(
                          fontSize: 14, color: AppColors.success)),
              ],
            ),
          ),
          if (_mode == WorkoutMode.active) ...[
            IconButton(
              onPressed: () =>
                  setState(() => _showRestTimer = !_showRestTimer),
              icon: Icon(Icons.timer,
                  color: _showRestTimer
                      ? AppColors.primary
                      : theme.textTheme.bodyMedium?.color),
            ),
            ElevatedButton(
              onPressed: _saving ? null : _handleFinishWorkout,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                foregroundColor: Colors.white,
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Finalizar'),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.fitness_center,
              size: 64, color: theme.textTheme.bodyMedium?.color),
          const SizedBox(height: 16),
          Text('Día de descanso',
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 8),
          Text('No hay ejercicios programados.',
              style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
          if (_isStructureEditable) ...[
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => context.go('/weekly/day/workout/exercises',
                  extra: {'routineDayId': widget.routineDayId}),
              icon: const Icon(Icons.add),
              label: const Text('Añadir Ejercicio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.primaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseSection(ThemeData theme, EjercicioProgramado ex) {
    final isCollapsed = _collapsedExercises.contains(ex.ejercicioId);
    final ghostSeries = _ghostValues[ex.ejercicioId] ?? [];

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
          // Exercise header - tappable to collapse/expand
          GestureDetector(
            onTap: () {
              setState(() {
                if (isCollapsed) {
                  _collapsedExercises.remove(ex.ejercicioId);
                } else {
                  _collapsedExercises.add(ex.ejercicioId);
                }
              });
            },
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(51),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.fitness_center,
                      size: 20, color: AppColors.primary),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ex.ejercicio?.titulo ?? 'Ejercicio',
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color),
                      ),
                      if (ex.ejercicio?.grupoMuscular != null)
                        Text(ex.ejercicio!.grupoMuscular!,
                            style: TextStyle(
                                fontSize: 13,
                                color: theme.textTheme.bodyMedium?.color)),
                    ],
                  ),
                ),
                // Info button -> ExerciseDetail
                IconButton(
                  icon: Icon(Icons.info_outline,
                      size: 20, color: theme.textTheme.bodyMedium?.color),
                  onPressed: () =>
                      context.go('/weekly/exercise/${ex.ejercicioId}'),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
                // Collapse indicator
                Icon(
                  isCollapsed
                      ? Icons.keyboard_arrow_down
                      : Icons.keyboard_arrow_up,
                  color: theme.textTheme.bodyMedium?.color,
                ),
                if (_isStructureEditable)
                  PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'remove') _handleRemoveExercise(ex);
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                          value: 'remove',
                          child: Text('Eliminar',
                              style: TextStyle(color: AppColors.error))),
                    ],
                  ),
              ],
            ),
          ),

          if (!isCollapsed) ...[
            // Weight type badge and personal note
            const SizedBox(height: 8),
            Row(
              children: [
                WeightTypeBadge(
                  tipoPeso: ex.tipoPeso,
                  editable: _isEditable,
                  onSelect: (tipo) async {
                    await WorkoutService.updateWeightType(ex.id, tipo);
                    _loadWorkout();
                  },
                ),
                const SizedBox(width: 8),
                PersonalNoteButton(exerciseId: ex.ejercicioId),
              ],
            ),
            const SizedBox(height: 12),

            // Series header
            Row(
              children: [
                SizedBox(
                    width: 40,
                    child: Text('Serie',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyMedium?.color))),
                Expanded(
                    child: Center(
                        child: Text('Kg',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyMedium?.color)))),
                Expanded(
                    child: Center(
                        child: Text('Reps',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyMedium?.color)))),
                Expanded(
                    child: Center(
                        child: Text('RPE',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyMedium?.color)))),
                if (_isEditable) const SizedBox(width: 72),
              ],
            ),
            const Divider(height: 16),

            // Series rows
            ...ex.series.asMap().entries.map((entry) {
              final idx = entry.key;
              final set = entry.value;
              // Find corresponding ghost value
              Serie? ghost;
              if (idx < ghostSeries.length) {
                ghost = ghostSeries[idx];
              }
              return _buildSetRow(theme, set, ex.ejercicioId, ghost);
            }),

            // Add set button
            if (_isEditable) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton.icon(
                  onPressed: () => _showAddSetsModal(ex.ejercicioId),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Añadir Serie'),
                  style: TextButton.styleFrom(foregroundColor: AppColors.primary),
                ),
              ),
            ],
          ] else ...[
            // Collapsed summary
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                '${ex.series.length} serie${ex.series.length != 1 ? 's' : ''}',
                style: TextStyle(
                    fontSize: 13, color: theme.textTheme.bodyMedium?.color),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSetRow(
      ThemeData theme, Serie set, String exerciseId, Serie? ghost) {
    final bool timerSaved = _savedTimerSetIds.contains(set.id);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            child: Text('${set.numeroSerie}',
                style: TextStyle(
                    fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
          ),
          Expanded(
            child: _SetInput(
              value: set.pesoUtilizado?.toString() ?? '',
              ghostValue: ghost?.pesoUtilizado?.toString(),
              onChanged: _isEditable
                  ? (v) =>
                      _handleUpdateSet(set.id, weight: double.tryParse(v))
                  : null,
              theme: theme,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SetInput(
              value: set.repeticiones?.toString() ?? '',
              ghostValue: ghost?.repeticiones?.toString(),
              onChanged: _isEditable
                  ? (v) => _handleUpdateSet(set.id, reps: int.tryParse(v))
                  : null,
              theme: theme,
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SetInput(
              value: set.rpe?.toString() ?? '',
              ghostValue: ghost?.rpe?.toString(),
              onChanged: _isEditable
                  ? (v) => _handleUpdateSet(set.id, rpe: int.tryParse(v))
                  : null,
              theme: theme,
            ),
          ),
          if (_isEditable) ...[
            // Rest timer button per set
            SizedBox(
              width: 36,
              child: IconButton(
                icon: Icon(
                  timerSaved ? Icons.timer : Icons.timer_outlined,
                  size: 18,
                  color: timerSaved
                      ? AppColors.success
                      : theme.textTheme.bodyMedium?.color,
                ),
                onPressed: timerSaved
                    ? null
                    : () {
                        setState(() {
                          _activeTimerSetId = set.id;
                          _showRestTimer = true;
                        });
                      },
                padding: EdgeInsets.zero,
              ),
            ),
            // Delete set button
            SizedBox(
              width: 36,
              child: IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 18, color: AppColors.error.withAlpha(178)),
                onPressed: () => _handleDeleteSet(set.id),
                padding: EdgeInsets.zero,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAddExerciseButton(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: OutlinedButton.icon(
        onPressed: () {
          context.go('/weekly/day/workout/exercises', extra: {
            'routineDayId': widget.routineDayId,
          });
        },
        icon: const Icon(Icons.add),
        label: const Text('Añadir Ejercicio'),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _SetInput extends StatefulWidget {
  final String value;
  final String? ghostValue;
  final ValueChanged<String>? onChanged;
  final ThemeData theme;

  const _SetInput({
    required this.value,
    this.ghostValue,
    this.onChanged,
    required this.theme,
  });

  @override
  State<_SetInput> createState() => _SetInputState();
}

class _SetInputState extends State<_SetInput> {
  late TextEditingController _controller;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
        text: widget.value == '0' || widget.value == '0.0'
            ? ''
            : widget.value);
  }

  @override
  void didUpdateWidget(_SetInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_isFocused) {
      final newText = widget.value == '0' || widget.value == '0.0'
          ? ''
          : widget.value;
      if (_controller.text != newText) {
        _controller.text = newText;
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _placeholder {
    if (_controller.text.isNotEmpty) return null;
    final ghost = widget.ghostValue;
    if (ghost == null || ghost == '0' || ghost == '0.0') return null;
    return ghost;
  }

  @override
  Widget build(BuildContext context) {
    final bool readOnly = widget.onChanged == null;

    return Focus(
      onFocusChange: (focused) => setState(() => _isFocused = focused),
      child: TextField(
        controller: _controller,
        readOnly: readOnly,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textAlign: TextAlign.center,
        style: TextStyle(
            fontSize: 14, color: widget.theme.textTheme.bodyLarge?.color),
        decoration: InputDecoration(
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
          filled: true,
          fillColor: readOnly
              ? widget.theme.cardTheme.color
              : widget.theme.inputDecorationTheme.fillColor,
          hintText: _placeholder,
          hintStyle: TextStyle(
            fontSize: 14,
            color: widget.theme.textTheme.bodyMedium?.color?.withAlpha(100),
          ),
        ),
        onChanged: widget.onChanged,
      ),
    );
  }
}
