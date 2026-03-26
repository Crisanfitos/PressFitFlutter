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
  String? _filterSecondaryMuscle;
  String? _filterCategory;
  String? _filterDifficulty;
  final _scrollController = ScrollController();
  bool _showScrollTop = false;
  final Set<String> _expandedIds = {};

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
        if (_filterSecondaryMuscle != null &&
            e.musculosSecundarios?.toLowerCase() != _filterSecondaryMuscle!.toLowerCase()) {
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
      _filterSecondaryMuscle = null;
      _filterCategory = null;
      _filterDifficulty = null;
      _searchCtrl.clear();
    });
    _applyFilters();
  }

  bool get _hasActiveFilters =>
      _filterMuscle != null ||
      _filterSecondaryMuscle != null ||
      _filterCategory != null ||
      _filterDifficulty != null;

  Set<String> _getUniqueValues(String? Function(Ejercicio) getter) {
    return _allExercises
        .map(getter)
        .where((v) => v != null && v.isNotEmpty)
        .cast<String>()
        .toSet();
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
                if (_showFilters) _buildFilters(theme),

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
    final secondaryMuscles = _getUniqueValues((e) => e.musculosSecundarios);
    final categories = _getUniqueValues((e) => e.categoria);
    final difficulties = _getUniqueValues((e) => e.dificultad);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        children: [
          _buildFilterChips('Músculo Principal', muscles, _filterMuscle, (v) {
            setState(() => _filterMuscle = v);
            _applyFilters();
          }),
          _buildFilterChips('Músculo Secundario', secondaryMuscles, _filterSecondaryMuscle, (v) {
            setState(() => _filterSecondaryMuscle = v);
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
    final isExpanded = _expandedIds.contains(exercise.id);
    final videoId = _getYouTubeVideoId(exercise.urlVideo);
    final thumbnailUrl = videoId != null ? 'https://img.youtube.com/vi/$videoId/mqdefault.jpg' : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        children: [
          // Main row
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => context.go('/weekly/exercise/${exercise.id}'),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  // Thumbnail with video overlay
                  GestureDetector(
                    onTap: exercise.urlVideo != null && exercise.urlVideo!.isNotEmpty
                        ? () => _showVideoModal(exercise)
                        : null,
                    child: SizedBox(
                      width: 64,
                      height: 44,
                      child: Stack(
                        children: [
                          Container(
                            width: 64,
                            height: 44,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withAlpha(51),
                              borderRadius: BorderRadius.circular(8),
                              image: (thumbnailUrl ?? exercise.urlFoto) != null
                                  ? DecorationImage(
                                      image: NetworkImage(thumbnailUrl ?? exercise.urlFoto!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: (thumbnailUrl ?? exercise.urlFoto) == null
                                ? const Icon(Icons.fitness_center,
                                    size: 20, color: AppColors.primary)
                                : null,
                          ),
                          if (exercise.urlVideo != null && exercise.urlVideo!.isNotEmpty)
                            Positioned.fill(
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.black26,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.play_circle_filled,
                                    color: Colors.white, size: 22),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(exercise.titulo,
                            style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: theme.textTheme.bodyLarge?.color)),
                        Text(
                          [exercise.musculosPrimarios, exercise.dificultad]
                              .where((s) => s != null && s.isNotEmpty)
                              .join(' · '),
                          style: TextStyle(
                              fontSize: 13, color: theme.textTheme.bodyMedium?.color),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      isExpanded ? Icons.expand_less : Icons.expand_more,
                      color: theme.textTheme.bodyMedium?.color,
                    ),
                    onPressed: () => setState(() {
                      if (isExpanded) {
                        _expandedIds.remove(exercise.id);
                      } else {
                        _expandedIds.add(exercise.id);
                      }
                    }),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
            ),
          ),
          // Expanded content
          if (isExpanded)
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
                  if (exercise.descripcion != null && exercise.descripcion!.isNotEmpty) ...[
                    Text(exercise.descripcion!,
                        style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                    const SizedBox(height: 10),
                  ],
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      if (exercise.musculosPrimarios != null)
                        _buildBadge(exercise.musculosPrimarios!, AppColors.primary),
                      if (exercise.musculosSecundarios != null)
                        _buildBadge(exercise.musculosSecundarios!, Colors.blueGrey),
                      if (exercise.categoria != null)
                        _buildBadge(exercise.categoria!, Colors.indigo),
                      if (exercise.dificultad != null)
                        _buildBadge(exercise.dificultad!, _difficultyColor(exercise.dificultad!)),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
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
