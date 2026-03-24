import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pressfit/services/routine_service.dart';
import 'package:pressfit/models/rutina_semanal.dart';
import 'package:pressfit/theme/app_theme.dart';

class RoutineDetailScreen extends StatefulWidget {
  final String routineId;
  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  RutinaSemanal? _routine;
  bool _loading = true;
  final _descController = TextEditingController();

  static const _dayNames = ['Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'];

  @override
  void initState() {
    super.initState();
    _loadRoutine();
  }

  @override
  void dispose() {
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadRoutine() async {
    setState(() => _loading = true);
    try {
      final routine = await RoutineService.getWeeklyRoutineWithDays(widget.routineId);
      if (mounted) setState(() { _routine = routine; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Map<String, dynamic>? _getDayData(String dayName) {
    final days = _routine?.rutinasDiarias ?? [];
    // Find template (no fecha_dia)
    final template = days.where((d) => d.nombreDia == dayName && d.fechaDia == null).firstOrNull;
    if (template != null) {
      return {'id': template.id, 'exercises': template.ejerciciosProgramados.length, 'descripcion': template.descripcion};
    }
    // Find most recent instance
    final instances = days.where((d) => d.nombreDia == dayName && d.fechaDia != null).toList()
      ..sort((a, b) => (b.fechaDia ?? '').compareTo(a.fechaDia ?? ''));
    if (instances.isNotEmpty) {
      return {'id': instances.first.id, 'exercises': instances.first.ejerciciosProgramados.length, 'descripcion': instances.first.descripcion};
    }
    return null;
  }

  void _showEditDescription(String dayName, String? dayId) {
    if (dayId == null) return;
    final dayData = _getDayData(dayName);
    _descController.text = dayData?['descripcion'] ?? '';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Descripción del día'),
        content: TextField(
          controller: _descController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Ej: Día de Piernas - Enfoque cuádriceps',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await RoutineService.updateRoutineDayDescription(dayId, _descController.text.trim());
              _loadRoutine();
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_routine?.nombre ?? 'Rutina', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                        if (_routine?.objetivo != null && _routine!.objetivo!.isNotEmpty)
                          Text(_routine!.objetivo!, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withAlpha(25)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(20),
                      children: [
                        Text('DÍAS DE LA SEMANA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color)),
                        const SizedBox(height: 16),
                        ..._dayNames.map((dayName) => _buildDayCard(theme, dayName)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayCard(ThemeData theme, String dayName) {
    final dayData = _getDayData(dayName);
    final exerciseCount = dayData?['exercises'] as int? ?? 0;
    final dayId = dayData?['id'] as String?;
    final desc = dayData?['descripcion'] as String?;

    return GestureDetector(
      onTap: () {
        if (dayId != null) {
          context.go('/weekly/day/workout', extra: {
            'workoutId': dayId,
            'dayName': dayName,
            'routineDayId': dayId,
          });
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: theme.dividerColor.withAlpha(25)),
        ),
        child: Row(
          children: [
            Expanded(
              child: Opacity(
                opacity: exerciseCount > 0 ? 1.0 : 0.6,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(dayName, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                    if (desc != null && desc.isNotEmpty)
                      Text(desc, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontStyle: FontStyle.italic)),
                    const SizedBox(height: 4),
                    Text(
                      exerciseCount > 0 ? '$exerciseCount ejercicio${exerciseCount > 1 ? 's' : ''}' : 'Sin ejercicios - Toca para añadir',
                      style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color),
                    ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.edit, size: 18, color: theme.textTheme.bodyMedium?.color),
              onPressed: () => _showEditDescription(dayName, dayId),
            ),
            Icon(Icons.chevron_right, size: 24, color: theme.textTheme.bodyMedium?.color),
          ],
        ),
      ),
    );
  }
}
