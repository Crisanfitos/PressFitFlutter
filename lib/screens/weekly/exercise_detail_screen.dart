import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/exercise_service.dart';
import 'package:pressfit/services/personal_record_service.dart';
import 'package:pressfit/services/workout_service.dart';
import 'package:pressfit/models/ejercicio.dart';
import 'package:pressfit/theme/app_theme.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final String exerciseId;

  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  Ejercicio? _exercise;
  Map<String, dynamic>? _personalRecord;
  List<Map<String, dynamic>> _history = [];
  String? _personalNote;
  bool _loading = true;
  bool _editingNote = false;
  late TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    try {
      final results = await Future.wait([
        ExerciseService.getExerciseById(widget.exerciseId),
        PersonalRecordService.getPersonalRecord(userId, widget.exerciseId),
        WorkoutService.getExerciseHistory(userId, widget.exerciseId),
        ExerciseService.getPersonalNote(userId, widget.exerciseId),
      ]);

      if (mounted) {
        setState(() {
          _exercise = results[0] as Ejercicio?;
          _personalRecord = results[1] as Map<String, dynamic>?;
          _history = results[2] as List<Map<String, dynamic>>;
          _personalNote = results[3] as String?;
          _noteController.text = _personalNote ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNote() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    await ExerciseService.savePersonalNote(userId, widget.exerciseId, _noteController.text);
    setState(() {
      _personalNote = _noteController.text;
      _editingNote = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_exercise == null) {
      return Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                  const Text('Ejercicio no encontrado'),
                ]),
              ),
            ],
          ),
        ),
      );
    }

    final ex = _exercise!;
    final muscles = <String>[];
    if (ex.musculosPrimarios != null) muscles.addAll(ex.musculosPrimarios!.split(',').map((s) => s.trim()));
    if (ex.musculosSecundarios != null) muscles.addAll(ex.musculosSecundarios!.split(',').map((s) => s.trim()));

    return Scaffold(
      body: SafeArea(
        child: ListView(
          children: [
            // Header image/video area
            Stack(
              children: [
                Container(
                  height: 220,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha(30),
                    image: ex.urlFoto != null
                        ? DecorationImage(image: NetworkImage(ex.urlFoto!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: ex.urlFoto == null
                      ? const Center(child: Icon(Icons.fitness_center, size: 64, color: AppColors.primary))
                      : null,
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => context.pop(),
                    ),
                  ),
                ),
              ],
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and muscle group
                  Text(
                    ex.titulo,
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color),
                  ),
                  if (ex.grupoMuscular != null) ...[
                    const SizedBox(height: 4),
                    Text(ex.grupoMuscular!, style: TextStyle(fontSize: 16, color: AppColors.primary, fontWeight: FontWeight.w500)),
                  ],

                  // Muscle tags
                  if (muscles.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: muscles.map((m) => Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withAlpha(30),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(m, style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                      )).toList(),
                    ),
                  ],

                  // Difficulty & Category
                  if (ex.dificultad != null || ex.categoria != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (ex.dificultad != null)
                          _buildInfoChip(theme, Icons.signal_cellular_alt, ex.dificultad!),
                        if (ex.categoria != null) ...[
                          if (ex.dificultad != null) const SizedBox(width: 12),
                          _buildInfoChip(theme, Icons.category, ex.categoria!),
                        ],
                      ],
                    ),
                  ],

                  // Description
                  if (ex.descripcion != null) ...[
                    const SizedBox(height: 20),
                    Text('Instrucciones', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                    const SizedBox(height: 8),
                    Text(ex.descripcion!, style: TextStyle(fontSize: 15, height: 1.5, color: theme.textTheme.bodyMedium?.color)),
                  ],

                  // Personal Record
                  if (_personalRecord != null) ...[
                    const SizedBox(height: 24),
                    _buildPersonalRecord(theme),
                  ],

                  // Personal Note
                  const SizedBox(height: 24),
                  _buildPersonalNote(theme),

                  // History
                  if (_history.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _buildHistorySection(theme),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(ThemeData theme, IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.textTheme.bodyMedium?.color),
          const SizedBox(width: 6),
          Text(label, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
        ],
      ),
    );
  }

  Widget _buildPersonalRecord(ThemeData theme) {
    final pr = _personalRecord!;
    final weight = pr['peso_utilizado'] ?? 0;
    final reps = pr['repeticiones'] ?? 0;
    final date = pr['fecha'] as String?;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary.withAlpha(40), AppColors.primary.withAlpha(15)],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withAlpha(60)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_events, color: AppColors.primary, size: 24),
              const SizedBox(width: 8),
              Text('Récord Personal', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text('$weight', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                    Text('kg', style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
              Container(width: 1, height: 40, color: theme.dividerColor.withAlpha(50)),
              Expanded(
                child: Column(
                  children: [
                    Text('$reps', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                    Text('reps', style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                  ],
                ),
              ),
            ],
          ),
          if (date != null) ...[
            const SizedBox(height: 8),
            Text('Fecha: $date', style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
          ],
        ],
      ),
    );
  }

  Widget _buildPersonalNote(ThemeData theme) {
    return Container(
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
              Icon(Icons.note, size: 20, color: theme.textTheme.bodyMedium?.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Notas Personales', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
              ),
              IconButton(
                icon: Icon(_editingNote ? Icons.check : Icons.edit, size: 20, color: AppColors.primary),
                onPressed: _editingNote ? _saveNote : () => setState(() => _editingNote = true),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_editingNote)
            TextField(
              controller: _noteController,
              maxLines: 4,
              decoration: InputDecoration(
                hintText: 'Escribe tus notas aquí...',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                filled: true,
                fillColor: theme.inputDecorationTheme.fillColor,
              ),
            )
          else
            Text(
              _personalNote?.isNotEmpty == true ? _personalNote! : 'Sin notas. Toca editar para añadir.',
              style: TextStyle(
                fontSize: 14,
                color: _personalNote?.isNotEmpty == true
                    ? theme.textTheme.bodyLarge?.color
                    : theme.textTheme.bodyMedium?.color,
                fontStyle: _personalNote?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildHistorySection(ThemeData theme) {
    // Group history by date
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final entry in _history) {
      final date = entry['fecha'] as String? ?? 'Sin fecha';
      grouped.putIfAbsent(date, () => []).add(entry);
    }

    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Historial', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
        const SizedBox(height: 12),
        ...sortedDates.take(10).map((date) {
          final sets = grouped[date]!..sort((a, b) => (a['numero_serie'] as int? ?? 0).compareTo(b['numero_serie'] as int? ?? 0));
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withAlpha(25)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(date, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary)),
                const SizedBox(height: 8),
                // Header
                Row(
                  children: [
                    SizedBox(width: 50, child: Text('Serie', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color))),
                    Expanded(child: Text('Kg', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color))),
                    Expanded(child: Text('Reps', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color))),
                    SizedBox(width: 50, child: Text('RPE', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color))),
                  ],
                ),
                const Divider(height: 12),
                ...sets.map((set) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(width: 50, child: Text('${set['numero_serie'] ?? '-'}', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color))),
                      Expanded(child: Text('${set['peso_utilizado'] ?? 0}', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color))),
                      Expanded(child: Text('${set['repeticiones'] ?? 0}', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyLarge?.color))),
                      SizedBox(width: 50, child: Text(set['rpe'] != null ? '${set['rpe']}' : '-', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color))),
                    ],
                  ),
                )),
              ],
            ),
          );
        }),
      ],
    );
  }
}
