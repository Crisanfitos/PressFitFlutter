import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/progress_service.dart';
import 'package:pressfit/services/user_service.dart';
import 'package:pressfit/services/exercise_service.dart';
import 'package:pressfit/models/ejercicio.dart';
import 'package:pressfit/models/foto_progreso.dart';
import 'package:pressfit/theme/app_theme.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:image_picker/image_picker.dart';

class ProgressScreen extends StatefulWidget {
  const ProgressScreen({super.key});

  @override
  State<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends State<ProgressScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _loading = true;

  // Workout stats
  int _weeklyWorkouts = 0;
  int _weeklyMinutes = 0;
  int _monthlyWorkouts = 0;
  List<_WeekDay> _weekDays = [];

  // Weight
  List<Map<String, dynamic>> _weightHistory = [];
  double? _currentWeight;
  double? _currentBodyFat;

  // Exercise tracking
  List<Ejercicio> _trackedExercises = [];

  // Photos
  List<FotoProgreso> _photos = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadAll();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ProgressService.getWeeklyProgress(userId),
        ProgressService.getMonthlyProgress(userId),
        UserService.getWeightHistory(userId, limit: 30),
        UserService.getUserMetrics(userId),
        ExerciseService.getUserExercisesWithProgress(userId),
        ProgressService.getProgressPhotos(userId),
      ]);

      final weeklyData = results[0] as List<Map<String, dynamic>>;
      final monthlyData = results[1] as List<Map<String, dynamic>>;
      final weightData = results[2] as List<Map<String, dynamic>>;
      final metrics = results[3] as Map<String, dynamic>?;
      final exercises = results[4] as List<Ejercicio>;
      final photos = results[5] as List<FotoProgreso>;

      // Calculate weekly stats
      int totalMinutes = 0;
      final now = DateTime.now();
      final monday = now.subtract(Duration(days: now.weekday - 1));
      final dayMap = <int, bool>{};
      for (final w in weeklyData) {
        if (w['hora_inicio'] != null && w['hora_fin'] != null) {
          final start = DateTime.parse(w['hora_inicio'] as String);
          final end = DateTime.parse(w['hora_fin'] as String);
          totalMinutes += end.difference(start).inMinutes;
          final dayOffset = DateTime.parse(w['hora_fin'] as String).difference(DateTime(monday.year, monday.month, monday.day)).inDays;
          if (dayOffset >= 0 && dayOffset < 7) dayMap[dayOffset] = true;
        }
      }

      final weekDays = <_WeekDay>[];
      const dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
      for (int i = 0; i < 7; i++) {
        final dayDate = DateTime(monday.year, monday.month, monday.day + i);
        final isPast = dayDate.isBefore(DateTime(now.year, now.month, now.day));
        final isToday = dayDate.year == now.year && dayDate.month == now.month && dayDate.day == now.day;
        weekDays.add(_WeekDay(
          label: dayLabels[i],
          completed: dayMap[i] ?? false,
          isToday: isToday,
          isPast: isPast || isToday,
        ));
      }

      if (mounted) {
        setState(() {
          _weeklyWorkouts = weeklyData.length;
          _weeklyMinutes = totalMinutes;
          _monthlyWorkouts = monthlyData.length;
          _weekDays = weekDays;
          _weightHistory = weightData;
          _currentWeight = (metrics?['peso'] as num?)?.toDouble();
          _currentBodyFat = (metrics?['grasa_corporal'] as num?)?.toDouble();
          _trackedExercises = exercises;
          _photos = photos;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: _loadAll,
                child: NestedScrollView(
                  headerSliverBuilder: (context, _) => [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                        child: Text('Progreso',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                      ),
                    ),
                    SliverToBoxAdapter(
                      child: TabBar(
                        controller: _tabController,
                        labelColor: AppColors.primary,
                        unselectedLabelColor: theme.textTheme.bodyMedium?.color,
                        indicatorColor: AppColors.primary,
                        tabs: const [
                          Tab(text: 'Resumen'),
                          Tab(text: 'Ejercicios'),
                          Tab(text: 'Físico'),
                        ],
                      ),
                    ),
                  ],
                  body: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildSummaryTab(theme),
                      _buildExercisesTab(theme),
                      _buildPhysicalTab(theme),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  // ─── Summary Tab ───

  Widget _buildSummaryTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Week overview
        _buildWeekOverview(theme),
        const SizedBox(height: 20),
        // Stats cards
        Row(
          children: [
            Expanded(child: _buildStatCard(theme, 'Esta Semana', '$_weeklyWorkouts', 'entrenos', Icons.fitness_center, AppColors.primary)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(theme, 'Tiempo', '${_weeklyMinutes}m', 'esta semana', Icons.timer, AppColors.warning)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard(theme, 'Este Mes', '$_monthlyWorkouts', 'entrenos', Icons.calendar_month, AppColors.success)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard(theme, 'Peso', _currentWeight != null ? '${_currentWeight!.toStringAsFixed(1)} kg' : '-', 'actual', Icons.monitor_weight, AppColors.info)),
          ],
        ),
      ],
    );
  }

  Widget _buildWeekOverview(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Semana Actual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: _weekDays.map((day) {
              Color bgColor;
              Color textColor;
              if (day.completed) {
                bgColor = AppColors.success;
                textColor = Colors.white;
              } else if (day.isToday) {
                bgColor = AppColors.primary;
                textColor = Colors.white;
              } else if (day.isPast) {
                bgColor = AppColors.error.withAlpha(48);
                textColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
              } else {
                bgColor = theme.dividerColor.withAlpha(25);
                textColor = theme.textTheme.bodyMedium?.color ?? Colors.grey;
              }
              return Column(
                children: [
                  Text(day.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: theme.textTheme.bodyMedium?.color)),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
                    child: day.completed
                        ? const Icon(Icons.check, size: 18, color: Colors.white)
                        : Center(child: Text(day.isToday ? 'Hoy' : '', style: TextStyle(fontSize: 9, color: textColor))),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(ThemeData theme, String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
            ],
          ),
          const SizedBox(height: 12),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
          Text(subtitle, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
        ],
      ),
    );
  }

  // ─── Exercises Tab ───

  Widget _buildExercisesTab(ThemeData theme) {
    if (_trackedExercises.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fitness_center, size: 48, color: theme.textTheme.bodyMedium?.color),
              const SizedBox(height: 12),
              Text(
                'No hay ejercicios con progreso registrado.\nComienza a entrenar para ver tu progreso aquí.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, color: theme.textTheme.bodyMedium?.color),
              ),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _trackedExercises.length,
      itemBuilder: (context, index) {
        final ex = _trackedExercises[index];
        return GestureDetector(
          onTap: () => context.go('/weekly/exercise/${ex.id}'),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.cardTheme.color,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: theme.dividerColor.withAlpha(25)),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
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
                      Text(ex.titulo, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
                      if (ex.grupoMuscular != null) ...[
                        const SizedBox(height: 4),
                        Text(ex.grupoMuscular!, style: TextStyle(fontSize: 13, color: theme.textTheme.bodyMedium?.color)),
                      ],
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: theme.textTheme.bodyMedium?.color),
              ],
            ),
          ),
        );
      },
    );
  }

  // ─── Physical Tab ───

  Widget _buildPhysicalTab(ThemeData theme) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Current stats
        _buildCurrentStats(theme),
        const SizedBox(height: 20),

        // Weight chart
        if (_weightHistory.length >= 2) ...[
          _buildWeightChart(theme),
          const SizedBox(height: 20),
        ],

        // Progress photos
        _buildPhotosSection(theme),
      ],
    );
  }

  Widget _buildCurrentStats(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado Actual', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(theme, 'Peso', _currentWeight != null ? '${_currentWeight!.toStringAsFixed(1)} kg' : '-', Icons.monitor_weight),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(theme, 'Grasa Corp.', _currentBodyFat != null ? '${_currentBodyFat!.toStringAsFixed(1)}%' : '-', Icons.percent),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile(ThemeData theme, String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
          Text(label, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
        ],
      ),
    );
  }

  Widget _buildWeightChart(ThemeData theme) {
    final spots = <FlSpot>[];
    for (int i = 0; i < _weightHistory.length; i++) {
      final peso = (_weightHistory[i]['peso'] as num).toDouble();
      spots.add(FlSpot(i.toDouble(), peso));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b) - 2;
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b) + 2;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Evolución de Peso', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
          const SizedBox(height: 16),
          SizedBox(
            height: 200,
            child: LineChart(
              LineChartData(
                minY: minY,
                maxY: maxY,
                gridData: FlGridData(
                  show: true,
                  drawVerticalLine: false,
                  horizontalInterval: (maxY - minY) / 4,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: theme.dividerColor.withAlpha(25),
                    strokeWidth: 1,
                  ),
                ),
                titlesData: FlTitlesData(
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  leftTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      reservedSize: 42,
                      getTitlesWidget: (value, _) => Text(
                        '${value.toStringAsFixed(0)} kg',
                        style: TextStyle(fontSize: 10, color: theme.textTheme.bodyMedium?.color),
                      ),
                    ),
                  ),
                ),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppColors.primary,
                    barWidth: 3,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) => FlDotCirclePainter(
                        radius: 3,
                        color: AppColors.primary,
                        strokeWidth: 0,
                      ),
                    ),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppColors.primary.withAlpha(40),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPhotosSection(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Fotos de Progreso', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
              ),
              IconButton(
                icon: const Icon(Icons.add_a_photo, color: AppColors.primary),
                onPressed: _handleAddPhoto,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_photos.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text(
                  'No hay fotos de progreso.\nToca el botón para añadir una.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color, fontStyle: FontStyle.italic),
                ),
              ),
            )
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: _photos.length,
              itemBuilder: (context, index) {
                final photo = _photos[index];
                return GestureDetector(
                  onTap: () => _showPhotoDetail(photo),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      photo.urlFoto,
                      fit: BoxFit.cover,
                      errorBuilder: (ctx, error, stack) => Container(
                        color: theme.dividerColor.withAlpha(25),
                        child: const Icon(Icons.broken_image, color: Colors.grey),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Future<void> _handleAddPhoto() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null || !mounted) return;

    setState(() => _loading = true);
    try {
      await ProgressService.uploadProgressPhoto(userId, image.path, null, '');
      await _loadAll();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al subir foto')),
        );
        setState(() => _loading = false);
      }
    }
  }

  void _showPhotoDetail(FotoProgreso photo) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(photo.urlFoto, fit: BoxFit.contain),
            ),
            if (photo.comentario?.isNotEmpty == true) ...[
              const SizedBox(height: 8),
              Text(photo.comentario!, style: const TextStyle(color: Colors.white, fontSize: 14)),
            ],
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cerrar', style: TextStyle(color: Colors.white)),
                ),
                TextButton(
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ProgressService.deleteProgressPhotos([photo.id]);
                    _loadAll();
                  },
                  child: const Text('Eliminar', style: TextStyle(color: AppColors.error)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _WeekDay {
  final String label;
  final bool completed;
  final bool isToday;
  final bool isPast;

  _WeekDay({required this.label, required this.completed, required this.isToday, required this.isPast});
}
