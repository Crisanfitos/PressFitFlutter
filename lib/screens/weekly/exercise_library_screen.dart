import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/exercise_service.dart';
import 'package:pressfit/models/ejercicio.dart';
import 'package:pressfit/theme/app_theme.dart';

class ExerciseLibraryScreen extends StatefulWidget {
  final String? routineDayId;

  const ExerciseLibraryScreen({super.key, this.routineDayId});

  @override
  State<ExerciseLibraryScreen> createState() => _ExerciseLibraryScreenState();
}

class _ExerciseLibraryScreenState extends State<ExerciseLibraryScreen> {
  List<Ejercicio> _exercises = [];
  bool _loading = true;
  String _search = '';
  String? _selectedMuscle;
  String? _selectedCategory;
  String? _selectedDifficulty;
  final Set<String> _selectedIds = {};
  bool _showFilters = false;

  @override
  void initState() {
    super.initState();
    _loadExercises();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await ExerciseService.getExercises();
      if (mounted) setState(() { _exercises = exercises; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<String> get _muscleGroups {
    return _exercises
        .where((e) => e.grupoMuscular != null)
        .map((e) => e.grupoMuscular!)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get _categories {
    return _exercises
        .where((e) => e.categoria != null)
        .map((e) => e.categoria!)
        .toSet()
        .toList()
      ..sort();
  }

  List<String> get _difficulties {
    return _exercises
        .where((e) => e.dificultad != null)
        .map((e) => e.dificultad!)
        .toSet()
        .toList()
      ..sort();
  }

  List<Ejercicio> get _filteredExercises {
    return _exercises.where((ex) {
      if (_search.isNotEmpty) {
        final query = _search.toLowerCase();
        final matchTitle = ex.titulo.toLowerCase().contains(query);
        final matchMuscle = ex.grupoMuscular?.toLowerCase().contains(query) ?? false;
        if (!matchTitle && !matchMuscle) return false;
      }
      if (_selectedMuscle != null && ex.grupoMuscular != _selectedMuscle) return false;
      if (_selectedCategory != null && ex.categoria != _selectedCategory) return false;
      if (_selectedDifficulty != null && ex.dificultad != _selectedDifficulty) return false;
      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _selectedMuscle != null || _selectedCategory != null || _selectedDifficulty != null;

  void _clearFilters() {
    setState(() {
      _selectedMuscle = null;
      _selectedCategory = null;
      _selectedDifficulty = null;
    });
  }

  Future<void> _handleConfirmSelection() async {
    if (_selectedIds.isEmpty || widget.routineDayId == null) return;

    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      await ExerciseService.addExercisesToRoutineDay(
        userId,
        widget.routineDayId!,
        _selectedIds.toList(),
      );
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al añadir ejercicios')),
        );
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredExercises;
    final isSelectionMode = widget.routineDayId != null;

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
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        onPressed: () => context.pop(),
                      ),
                      Expanded(
                        child: Text(
                          isSelectionMode ? 'Añadir Ejercicios' : 'Ejercicios',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (isSelectionMode && _selectedIds.isNotEmpty)
                        ElevatedButton(
                          onPressed: _handleConfirmSelection,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: Text('Añadir (${_selectedIds.length})'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Search bar
                  TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar ejercicio...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_search.isNotEmpty)
                            IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _search = ''),
                            ),
                          IconButton(
                            icon: Badge(
                              isLabelVisible: _hasActiveFilters,
                              smallSize: 8,
                              child: const Icon(Icons.filter_list),
                            ),
                            onPressed: () => setState(() => _showFilters = !_showFilters),
                          ),
                        ],
                      ),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      filled: true,
                      fillColor: theme.inputDecorationTheme.fillColor,
                    ),
                  ),
                  // Filters
                  if (_showFilters) ...[
                    const SizedBox(height: 12),
                    _buildFilterSection(theme),
                  ],
                ],
              ),
            ),

            // Exercise list
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : filtered.isEmpty
                      ? Center(
                          child: Text('No se encontraron ejercicios',
                              style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          itemBuilder: (context, index) =>
                              _buildExerciseCard(theme, filtered[index], isSelectionMode),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection(ThemeData theme) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildFilterDropdown(theme, 'Músculo', _selectedMuscle, _muscleGroups,
                (v) => setState(() => _selectedMuscle = v))),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterDropdown(theme, 'Categoría', _selectedCategory, _categories,
                (v) => setState(() => _selectedCategory = v))),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: _buildFilterDropdown(theme, 'Dificultad', _selectedDifficulty, _difficulties,
                (v) => setState(() => _selectedDifficulty = v))),
            const SizedBox(width: 8),
            if (_hasActiveFilters)
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Limpiar'),
              )
            else
              const Spacer(),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterDropdown(
      ThemeData theme, String label, String? value, List<String> options, ValueChanged<String?> onChanged) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      hint: Text(label, style: const TextStyle(fontSize: 13)),
      isExpanded: true,
      decoration: InputDecoration(
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        filled: true,
        fillColor: theme.inputDecorationTheme.fillColor,
      ),
      items: [
        DropdownMenuItem<String>(value: null, child: Text('Todos', style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color))),
        ...options.map((o) => DropdownMenuItem(value: o, child: Text(o, style: const TextStyle(fontSize: 13)))),
      ],
      onChanged: onChanged,
    );
  }

  Widget _buildExerciseCard(ThemeData theme, Ejercicio ex, bool isSelectionMode) {
    final isSelected = _selectedIds.contains(ex.id);

    return GestureDetector(
      onTap: isSelectionMode
          ? () => setState(() {
                if (isSelected) {
                  _selectedIds.remove(ex.id);
                } else {
                  _selectedIds.add(ex.id);
                }
              })
          : () => context.go('/weekly/exercise/${ex.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withAlpha(30) : theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : theme.dividerColor.withAlpha(25),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Thumbnail
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha(51),
                borderRadius: BorderRadius.circular(12),
                image: ex.urlFoto != null
                    ? DecorationImage(image: NetworkImage(ex.urlFoto!), fit: BoxFit.cover)
                    : null,
              ),
              child: ex.urlFoto == null
                  ? const Icon(Icons.fitness_center, color: AppColors.primary)
                  : null,
            ),
            const SizedBox(width: 16),
            // Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ex.titulo,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: theme.textTheme.bodyLarge?.color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (ex.grupoMuscular != null) ...[
                        Icon(Icons.fitness_center, size: 14, color: theme.textTheme.bodyMedium?.color),
                        const SizedBox(width: 4),
                        Text(ex.grupoMuscular!,
                            style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                      ],
                      if (ex.dificultad != null) ...[
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: _difficultyColor(ex.dificultad!).withAlpha(51),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            ex.dificultad!,
                            style: TextStyle(fontSize: 11, color: _difficultyColor(ex.dificultad!), fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (isSelectionMode)
              Icon(
                isSelected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: isSelected ? AppColors.primary : theme.textTheme.bodyMedium?.color,
              )
            else
              Icon(Icons.chevron_right, color: theme.textTheme.bodyMedium?.color),
          ],
        ),
      ),
    );
  }

  Color _difficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'fácil':
      case 'facil':
        return AppColors.success;
      case 'intermedio':
      case 'medio':
        return AppColors.warning;
      case 'difícil':
      case 'dificil':
      case 'avanzado':
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }
}
