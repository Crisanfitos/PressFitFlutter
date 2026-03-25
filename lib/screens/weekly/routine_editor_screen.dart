import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/routine_service.dart';
import 'package:pressfit/models/rutina_semanal.dart';
import 'package:pressfit/theme/app_theme.dart';

class RoutineEditorScreen extends StatefulWidget {
  const RoutineEditorScreen({super.key});

  @override
  State<RoutineEditorScreen> createState() => _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends State<RoutineEditorScreen> {
  List<RutinaSemanal> _routines = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final routines = await RoutineService.getAllWeeklyRoutines(userId);
      if (mounted) setState(() { _routines = routines; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _showCreateDialog() async {
    final nameCtrl = TextEditingController();
    final goalCtrl = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nueva Plantilla'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Nombre de la Plantilla', hintText: 'ej. Volumen 4 días', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: goalCtrl,
              decoration: const InputDecoration(labelText: 'Objetivo (opcional)', hintText: 'ej. Ganar masa muscular', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Crear'),
          ),
        ],
      ),
    );

    if (result != true || nameCtrl.text.trim().isEmpty || !mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    await RoutineService.createWeeklyRoutine({
      'usuario_id': userId,
      'nombre': nameCtrl.text.trim(),
      'objetivo': goalCtrl.text.trim().isNotEmpty ? goalCtrl.text.trim() : null,
      'es_plantilla': true,
      'activa': _routines.where((r) => r.activa).isEmpty,
    });
    _loadRoutines();
  }

  Future<void> _handleSetActive(RutinaSemanal routine) async {
    if (routine.activa) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    await RoutineService.setActiveRoutine(userId, routine.id);
    _loadRoutines();
  }

  Future<void> _handleDuplicate(RutinaSemanal routine) async {
    final nameCtrl = TextEditingController(text: '${routine.nombre} (copia)');
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Duplicar Rutina'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(
            labelText: 'Nombre de la copia',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Duplicar'),
          ),
        ],
      ),
    );

    if (result != true || nameCtrl.text.trim().isEmpty || !mounted) return;
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _loading = true);
    await RoutineService.createRoutineFromTemplate(
      userId,
      routine.id,
      nameCtrl.text.trim(),
    );
    _loadRoutines();
  }

  Future<void> _handleDelete(String routineId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar Rutina'),
        content: const Text('¿Estás seguro? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await RoutineService.deleteWeeklyRoutine(routineId);
      _loadRoutines();
    }
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
                  Text('Mis Plantillas', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                ],
              ),
            ),
            Divider(height: 1, color: theme.dividerColor.withAlpha(25)),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _routines.isEmpty
                      ? _buildEmptyState(theme)
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _routines.length,
                          itemBuilder: (context, index) => _buildRoutineCard(theme, _routines[index]),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: _routines.isNotEmpty
          ? FloatingActionButton(
              onPressed: _showCreateDialog,
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.add, color: Colors.white),
            )
          : null,
    );
  }

  Widget _buildEmptyState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.fitness_center, size: 64, color: theme.textTheme.bodyMedium?.color),
          const SizedBox(height: 16),
          Text('No tienes plantillas creadas', style: TextStyle(fontSize: 18, color: theme.textTheme.bodyMedium?.color)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _showCreateDialog,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16)),
            child: const Text('Crear Primera Plantilla', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildRoutineCard(ThemeData theme, RutinaSemanal routine) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: routine.activa ? AppColors.primary : theme.dividerColor.withAlpha(25), width: routine.activa ? 2 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(routine.nombre, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color))),
              if (routine.activa)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
                  child: const Text('ACTIVA', style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          if (routine.objetivo != null && routine.objetivo!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(routine.objetivo!, style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color)),
          ],
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (!routine.activa)
                _buildActionButton(theme, Icons.check_circle_outline, 'Activar', AppColors.primary, () => _handleSetActive(routine)),
              const SizedBox(width: 8),
              _buildActionButton(theme, Icons.copy, 'Duplicar', null, () => _handleDuplicate(routine)),
              const SizedBox(width: 8),
              _buildActionButton(theme, Icons.edit, 'Editar', null, () => context.go('/weekly/routine/${routine.id}')),
              const SizedBox(width: 8),
              _buildActionButton(theme, Icons.delete, null, AppColors.error, () => _handleDelete(routine.id), isDelete: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(ThemeData theme, IconData icon, String? label, Color? color, VoidCallback onTap, {bool isDelete = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: isDelete ? AppColors.error.withAlpha(30) : theme.inputDecorationTheme.fillColor,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: color ?? theme.textTheme.bodyLarge?.color),
            if (label != null) ...[
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 14, color: color ?? theme.textTheme.bodyLarge?.color)),
            ],
          ],
        ),
      ),
    );
  }
}
