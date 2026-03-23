import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pressfit/services/workout_service.dart';
import 'package:pressfit/models/rutina_diaria.dart';
import 'package:pressfit/models/ejercicio_programado.dart';
import 'package:pressfit/models/serie.dart';
import 'package:pressfit/theme/app_theme.dart';

class WorkoutScreen extends StatefulWidget {
  final String workoutId;
  final String dayName;
  final String routineDayId;

  const WorkoutScreen({
    super.key,
    required this.workoutId,
    required this.dayName,
    required this.routineDayId,
  });

  @override
  State<WorkoutScreen> createState() => _WorkoutScreenState();
}

class _WorkoutScreenState extends State<WorkoutScreen> {
  RutinaDiaria? _workout;
  bool _loading = true;
  int _timerSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadWorkout();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadWorkout() async {
    setState(() => _loading = true);
    try {
      final data = await WorkoutService.getWorkoutDetails(widget.workoutId);
      if (data != null && mounted) {
        // Calculate elapsed time
        if (data.horaInicio != null && !data.completada) {
          final start = DateTime.parse(data.horaInicio!);
          _timerSeconds = DateTime.now().difference(start).inSeconds;
          _startTimer();
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

  void _startTimer() {
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

  Future<void> _handleAddSet(String exerciseId) async {
    final exercises = _workout?.ejerciciosProgramados ?? [];
    final ex = exercises.where((e) => e.ejercicioId == exerciseId).firstOrNull;
    final currentCount = ex?.series.length ?? 0;
    final lastSet = ex?.series.isNotEmpty == true ? ex!.series.last : null;

    await WorkoutService.addSet(
      widget.workoutId,
      exerciseId,
      currentCount + 1,
      lastSet?.pesoUtilizado ?? 0,
      lastSet?.repeticiones ?? 0,
    );
    _loadWorkout();
  }

  Future<void> _handleUpdateSet(String setId, {double? weight, int? reps, int? rpe}) async {
    await WorkoutService.updateSet(setId, weight: weight, reps: reps, rpe: rpe);
  }

  Future<void> _handleDeleteSet(String setId) async {
    await WorkoutService.deleteSet(setId);
    _loadWorkout();
  }

  Future<void> _handleFinishWorkout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Finalizar Entrenamiento'),
        content: const Text('¿Estás seguro de que quieres terminar este entrenamiento?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Finalizar')),
        ],
      ),
    );

    if (confirm == true) {
      _timer?.cancel();
      await WorkoutService.completeWorkout(widget.workoutId);
      if (mounted) context.go('/weekly');
    }
  }

  Future<void> _handleRemoveExercise(EjercicioProgramado ex) async {
    await WorkoutService.removeExerciseFromRoutine(ex.id);
    _loadWorkout();
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
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: theme.dividerColor.withAlpha(25))),
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
                            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                        const SizedBox(height: 4),
                        Text(_formattedTimer,
                            style: const TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _handleFinishWorkout,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.success,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Finalizar'),
                  ),
                ],
              ),
            ),

            // Exercises
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: exercises.length + 1, // +1 for add exercise button
                itemBuilder: (context, index) {
                  if (index == exercises.length) {
                    return _buildAddExerciseButton(theme);
                  }
                  return _buildExerciseSection(theme, exercises[index]);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExerciseSection(ThemeData theme, EjercicioProgramado ex) {
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
          // Exercise header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha(51),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.fitness_center, size: 20, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ex.ejercicio?.titulo ?? 'Ejercicio',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                    ),
                    if (ex.ejercicio?.grupoMuscular != null)
                      Text(ex.ejercicio!.grupoMuscular!,
                          style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'remove') _handleRemoveExercise(ex);
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'remove', child: Text('Eliminar')),
                ],
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Series header
          Row(
            children: [
              SizedBox(width: 50, child: Text('Serie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color))),
              Expanded(child: Center(child: Text('Kg', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color)))),
              Expanded(child: Center(child: Text('Reps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color)))),
              Expanded(child: Center(child: Text('RPE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color)))),
              const SizedBox(width: 40),
            ],
          ),
          const Divider(height: 16),

          // Series rows
          ...ex.series.map((set) => _buildSetRow(theme, set, ex.ejercicioId)),

          const SizedBox(height: 8),

          // Add set button
          Center(
            child: TextButton.icon(
              onPressed: () => _handleAddSet(ex.ejercicioId),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Añadir Serie'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSetRow(ThemeData theme, Serie set, String exerciseId) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 50,
            child: Text('${set.numeroSerie}',
                style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
          ),
          Expanded(
            child: _SetInput(
              value: set.pesoUtilizado?.toString() ?? '',
              onChanged: (v) => _handleUpdateSet(set.id, weight: double.tryParse(v)),
              theme: theme,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SetInput(
              value: set.repeticiones?.toString() ?? '',
              onChanged: (v) => _handleUpdateSet(set.id, reps: int.tryParse(v)),
              theme: theme,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _SetInput(
              value: set.rpe?.toString() ?? '',
              onChanged: (v) => _handleUpdateSet(set.id, rpe: int.tryParse(v)),
              theme: theme,
            ),
          ),
          SizedBox(
            width: 40,
            child: IconButton(
              icon: Icon(Icons.delete_outline, size: 18, color: AppColors.error.withAlpha(178)),
              onPressed: () => _handleDeleteSet(set.id),
              padding: EdgeInsets.zero,
            ),
          ),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}

class _SetInput extends StatefulWidget {
  final String value;
  final ValueChanged<String> onChanged;
  final ThemeData theme;

  const _SetInput({required this.value, required this.onChanged, required this.theme});

  @override
  State<_SetInput> createState() => _SetInputState();
}

class _SetInputState extends State<_SetInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value == '0' || widget.value == '0.0' ? '' : widget.value);
  }

  @override
  void didUpdateWidget(_SetInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newText = widget.value == '0' || widget.value == '0.0' ? '' : widget.value;
    if (_controller.text != newText && !_controller.text.contains('.') || _controller.text.isEmpty) {
      _controller.text = newText;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 14, color: widget.theme.textTheme.bodyLarge?.color),
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: widget.theme.inputDecorationTheme.fillColor,
      ),
      onChanged: widget.onChanged,
    );
  }
}
