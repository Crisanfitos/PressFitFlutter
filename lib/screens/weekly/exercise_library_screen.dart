import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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
  String? _selectedSecondaryMuscle;
  String? _selectedCategory;
  String? _selectedDifficulty;
  final Set<String> _selectedIds = {};
  final Set<String> _expandedIds = {};
  bool _showFilters = false;
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
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadExercises() async {
    try {
      final exercises = await ExerciseService.getExercises();
      if (mounted) setState(() { _exercises = exercises; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Set<String> _getUniqueValues(String? Function(Ejercicio) getter) {
    return _exercises
        .map(getter)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet();
  }

  List<Ejercicio> get _filteredExercises {
    return _exercises.where((ex) {
      if (_search.isNotEmpty) {
        final query = _search.toLowerCase();
        final matchTitle = ex.titulo.toLowerCase().contains(query);
        final matchMuscle = ex.musculosPrimarios?.toLowerCase().contains(query) ?? false;
        if (!matchTitle && !matchMuscle) return false;
      }
      if (_selectedMuscle != null && ex.musculosPrimarios != _selectedMuscle) return false;
      if (_selectedSecondaryMuscle != null && ex.musculosSecundarios != _selectedSecondaryMuscle) return false;
      if (_selectedCategory != null && ex.categoria != _selectedCategory) return false;
      if (_selectedDifficulty != null && ex.dificultad != _selectedDifficulty) return false;
      return true;
    }).toList();
  }

  bool get _hasActiveFilters =>
      _selectedMuscle != null ||
      _selectedSecondaryMuscle != null ||
      _selectedCategory != null ||
      _selectedDifficulty != null;

  void _clearFilters() {
    setState(() {
      _selectedMuscle = null;
      _selectedSecondaryMuscle = null;
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
      if (mounted) context.pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al añadir ejercicios')),
        );
        setState(() => _loading = false);
      }
    }
  }

  String? _getYouTubeVideoId(String? url) {
    if (url == null || url.isEmpty) return null;
    final uri = Uri.tryParse(url);
    if (uri == null) return null;
    if (uri.host.contains('youtube.com')) return uri.queryParameters['v'];
    if (uri.host.contains('youtu.be')) return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
    return null;
  }

  void _showVideoModal(Ejercicio exercise) {
    if (exercise.urlVideo == null || exercise.urlVideo!.isEmpty) return;
    final videoId = _getYouTubeVideoId(exercise.urlVideo);
    final thumbnailUrl = videoId != null ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : null;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(exercise.titulo),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (thumbnailUrl != null || exercise.urlFoto != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  thumbnailUrl ?? exercise.urlFoto!,
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cerrar')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final filtered = _filteredExercises;
    final isSelectionMode = widget.routineDayId != null;

    return Scaffold(
      floatingActionButton: _showScrollTop
          ? FloatingActionButton.small(
              onPressed: () => _scrollController.animateTo(0,
                  duration: const Duration(milliseconds: 300), curve: Curves.easeOut),
              backgroundColor: AppColors.primary,
              child: const Icon(Icons.arrow_upward, color: Colors.white),
            )
          : null,
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
                          isSelectionMode
                              ? (_selectedIds.isEmpty
                                  ? 'Añadir Ejercicios'
                                  : '${_selectedIds.length} Seleccionados')
                              : 'Biblioteca de Ejercicios',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                      ),
                      if (isSelectionMode && _selectedIds.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.check, color: AppColors.primary),
                          onPressed: _handleConfirmSelection,
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
                          controller: _scrollController,
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
    final muscles = _getUniqueValues((e) => e.musculosPrimarios);
    final secondaryMuscles = _getUniqueValues((e) => e.musculosSecundarios);
    final categories = _getUniqueValues((e) => e.categoria);
    final difficulties = _getUniqueValues((e) => e.dificultad);

    return Column(
      children: [
        _buildFilterChips('Músculo Principal', muscles, _selectedMuscle, (v) {
          setState(() => _selectedMuscle = v);
        }),
        _buildFilterChips('Músculo Secundario', secondaryMuscles, _selectedSecondaryMuscle, (v) {
          setState(() => _selectedSecondaryMuscle = v);
        }),
        _buildFilterChips('Categoría', categories, _selectedCategory, (v) {
          setState(() => _selectedCategory = v);
        }),
        _buildFilterChips('Dificultad', difficulties, _selectedDifficulty, (v) {
          setState(() => _selectedDifficulty = v);
        }),
        if (_hasActiveFilters)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _clearFilters,
              child: const Text('Limpiar Filtros'),
            ),
          ),
      ],
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

  Widget _buildExerciseCard(ThemeData theme, Ejercicio ex, bool isSelectionMode) {
    final isSelected = _selectedIds.contains(ex.id);
    final isExpanded = _expandedIds.contains(ex.id);
    final videoId = _getYouTubeVideoId(ex.urlVideo);
    final thumbnailUrl = videoId != null ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withAlpha(30) : theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSelected ? AppColors.primary : theme.dividerColor.withAlpha(25),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Column(
        children: [
          // Main row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: isSelectionMode
                ? () => setState(() {
                      if (isSelected) {
                        _selectedIds.remove(ex.id);
                      } else {
                        _selectedIds.add(ex.id);
                      }
                    })
                : () => context.go('/weekly/exercise/${ex.id}'),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Thumbnail with video play overlay
                  GestureDetector(
                    onTap: ex.urlVideo != null && ex.urlVideo!.isNotEmpty
                        ? () => _showVideoModal(ex)
                        : null,
                    child: SizedBox(
                      width: 80,
                      height: 54,
                      child: Stack(
                        children: [
                          Container(
                            width: 80,
                            height: 54,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                              image: (thumbnailUrl ?? ex.urlFoto) != null
                                  ? DecorationImage(
                                      image: NetworkImage(thumbnailUrl ?? ex.urlFoto!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (thumbnailUrl ?? ex.urlFoto) == null
                                ? const Icon(Icons.fitness_center, color: AppColors.primary)
                                : null,
                          ),
                          if (ex.urlVideo != null && ex.urlVideo!.isNotEmpty)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.play_circle_filled,
                                    color: Colors.white, size: 28),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Title and muscle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ex.titulo,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: theme.textTheme.bodyLarge?.color,
                          ),
                        ),
                        if (ex.musculosPrimarios != null) ...[
                          const SizedBox(height: 2),
                          Text(ex.musculosPrimarios!,
                              style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                        ],
                      ],
                    ),
                  ),
                  // Action icons
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    onPressed: () => setState(() {
                      if (isExpanded) {
                        _expandedIds.remove(ex.id);
                      } else {
                        _expandedIds.add(ex.id);
                      }
                    }),
                    visualDensity: VisualDensity.compact,
                  ),
                  if (isSelectionMode) ...[
                    IconButton(
                      icon: const Icon(Icons.info_outline, size: 20),
                      color: theme.textTheme.bodyMedium?.color,
                      onPressed: () => context.push('/weekly/exercise/${ex.id}'),
                      visualDensity: VisualDensity.compact,
                    ),
                    Icon(
                      isSelected ? Icons.check_circle : Icons.add_circle_outline,
                      color: isSelected ? AppColors.primary : theme.textTheme.bodyMedium?.color,
                    ),
                  ] else
                    Icon(Icons.chevron_right, color: theme.textTheme.bodyMedium?.color),
                ],
              ),
            ),
          ),
          // Expanded content
          if (isExpanded) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: theme.dividerColor.withAlpha(25))),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  if (ex.descripcion != null && ex.descripcion!.isNotEmpty) ...[
                    Text(ex.descripcion!,
                        style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (ex.musculosPrimarios != null)
                        _buildBadge(ex.musculosPrimarios!, AppColors.primary, theme),
                      if (ex.musculosSecundarios != null)
                        _buildBadge(ex.musculosSecundarios!, Colors.blueGrey, theme),
                      if (ex.categoria != null)
                        _buildBadge(ex.categoria!, Colors.indigo, theme),
                      if (ex.dificultad != null)
                        _buildBadge(ex.dificultad!, _difficultyColor(ex.dificultad!), theme),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
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
