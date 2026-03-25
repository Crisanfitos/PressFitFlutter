import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:pressfit/services/exercise_service.dart';
import 'package:pressfit/models/ejercicio.dart';
import 'package:pressfit/theme/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

class ExerciseCatalogScreen extends StatefulWidget {
  const ExerciseCatalogScreen({super.key});

  @override
  State<ExerciseCatalogScreen> createState() => _ExerciseCatalogScreenState();
}

class _ExerciseCatalogScreenState extends State<ExerciseCatalogScreen> {
  List<Ejercicio> _allExercises = [];
  List<Ejercicio> _filtered = [];
  bool _loading = true;
  final _searchCtrl = TextEditingController();
  bool _showFilters = false;
  String? _filterMuscle;
  String? _filterCategory;
  String? _filterDifficulty;
  final _scrollController = ScrollController();
  bool _showScrollTop = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
    _scrollController.addListener(() {
      final show = _scrollController.offset > 400;
      if (show != _showScrollTop) setState(() => _showScrollTop = show);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await ExerciseService.getExercises();
      if (mounted) {
        setState(() {
          _allExercises = exercises;
          _filtered = exercises;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _applyFilters() {
    final query = _searchCtrl.text.toLowerCase();
    setState(() {
      _filtered = _allExercises.where((e) {
        if (query.isNotEmpty && !e.titulo.toLowerCase().contains(query)) {
          return false;
        }
        if (_filterMuscle != null &&
            e.musculosPrimarios?.toLowerCase() != _filterMuscle!.toLowerCase()) {
          return false;
        }
        if (_filterCategory != null &&
            e.categoria?.toLowerCase() != _filterCategory!.toLowerCase()) {
          return false;
        }
        if (_filterDifficulty != null &&
            e.dificultad?.toLowerCase() != _filterDifficulty!.toLowerCase()) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  void _clearFilters() {
    setState(() {
      _filterMuscle = null;
      _filterCategory = null;
      _filterDifficulty = null;
      _searchCtrl.clear();
    });
    _applyFilters();
  }

  bool get _hasActiveFilters =>
      _filterMuscle != null ||
      _filterCategory != null ||
      _filterDifficulty != null;

  Set<String> _getUniqueValues(String? Function(Ejercicio) getter) {
    return _allExercises
        .map(getter)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  void _showVideoModal(Ejercicio exercise) {
    if (exercise.urlVideo == null || exercise.urlVideo!.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(exercise.titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (exercise.urlFoto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  exercise.urlFoto!,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (ctx, error, stack) => const SizedBox.shrink(),
                ),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final uri = Uri.parse(exercise.urlVideo!);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Ver en YouTube'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Catálogo de Ejercicios'),
      ),
      floatingActionButton: _showScrollTop
          ? FloatingActionButton.small(
              onPressed: () => _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOut),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchCtrl,
                          decoration: InputDecoration(
                            hintText: 'Buscar ejercicio...',
                            prefixIcon: const Icon(Icons.search),
                            suffixIcon: _searchCtrl.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear),
                                    onPressed: () {
                                      _searchCtrl.clear();
                                      _applyFilters();
                                    },
                                  )
                                : null,
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                          ),
                          onChanged: (_) => _applyFilters(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Badge(
                        isLabelVisible: _hasActiveFilters,
                        child: IconButton(
                          onPressed: () =>
                              setState(() => _showFilters = !_showFilters),
                          icon: Icon(
                            _showFilters
                                ? Icons.filter_list_off
                                : Icons.filter_list,
                            color: _hasActiveFilters
                                ? AppColors.primary
                                : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Filters
                if (_showFilters)
                  _buildFilters(theme),

                // Results count
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('${_filtered.length} ejercicios',
                          style: TextStyle(
                              fontSize: 13,
                              color: theme.textTheme.bodyMedium?.color)),
                      if (_hasActiveFilters)
                        TextButton(
                          onPressed: _clearFilters,
                          child: const Text('Limpiar Filtros',
                              style: TextStyle(fontSize: 13)),
                        ),
                    ],
                  ),
                ),

                // Exercise list
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Text(
                            _hasActiveFilters || _searchCtrl.text.isNotEmpty
                                ? 'No se encontraron ejercicios con estos filtros'
                                : 'No hay ejercicios disponibles',
                            style: TextStyle(
                                color: theme.textTheme.bodyMedium?.color),
                          ),
                        )
                      : ListView.builder(
                          controller: _scrollController,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _filtered.length,
                          itemBuilder: (context, index) =>
                              _buildExerciseItem(theme, _filtered[index]),
                        ),
                ),
              ],
            ),
    );
  }

  Widget _buildFilters(ThemeData theme) {
    final muscles = _getUniqueValues((e) => e.musculosPrimarios);
    final categories = _getUniqueValues((e) => e.categoria);
    final difficulties = _getUniqueValues((e) => e.dificultad);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _buildFilterChips('Músculo', muscles, _filterMuscle, (v) {
            setState(() => _filterMuscle = v);
            _applyFilters();
          }),
          _buildFilterChips('Categoría', categories, _filterCategory, (v) {
            setState(() => _filterCategory = v);
            _applyFilters();
          }),
          _buildFilterChips('Dificultad', difficulties, _filterDifficulty, (v) {
            setState(() => _filterDifficulty = v);
            _applyFilters();
          }),
        ],
      ),
    );
  }

  Widget _buildFilterChips(
    String label,
    Set<String> options,
    String? selected,
    ValueChanged<String?> onSelected,
  ) {
    if (options.isEmpty) return const SizedBox.shrink();
    final sorted = options.toList()..sort();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Theme.of(context).textTheme.bodyMedium?.color)),
        const SizedBox(height: 4),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: const Text('Todos'),
                  selected: selected == null,
                  onSelected: (_) => onSelected(null),
                  visualDensity: VisualDensity.compact,
                ),
              ),
              ...sorted.map((opt) => Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(opt, style: const TextStyle(fontSize: 12)),
                      selected: selected == opt,
                      onSelected: (sel) => onSelected(sel ? opt : null),
                      visualDensity: VisualDensity.compact,
                    ),
                  )),
            ],
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildExerciseItem(ThemeData theme, Ejercicio exercise) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(51),
            borderRadius: BorderRadius.circular(10),
          ),
          child: exercise.urlFoto != null
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(exercise.urlFoto!,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stack) => const Icon(
                          Icons.fitness_center,
                          size: 20,
                          color: AppColors.primary)),
                )
              : const Icon(Icons.fitness_center,
                  size: 20, color: AppColors.primary),
        ),
        title: Text(exercise.titulo,
            style: TextStyle(
                fontWeight: FontWeight.w600,
                color: theme.textTheme.bodyLarge?.color)),
        subtitle: Text(
          [exercise.grupoMuscular, exercise.dificultad]
              .where((s) => s != null && s.isNotEmpty)
              .join(' · '),
          style: TextStyle(
              fontSize: 13, color: theme.textTheme.bodyMedium?.color),
        ),
        trailing: exercise.urlVideo != null && exercise.urlVideo!.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.play_circle_outline,
                    color: AppColors.primary),
                onPressed: () => _showVideoModal(exercise),
              )
            : null,
        onTap: () => context.go('/weekly/exercise/${exercise.id}'),
      ),
    );
  }
}
