import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/exercise_service.dart';
import 'package:pressfit/services/workout_service.dart';
import 'package:pressfit/models/ejercicio.dart';
import 'package:pressfit/models/tipo_peso.dart';
import 'package:pressfit/theme/app_theme.dart';

class ExerciseProgressDetailScreen extends StatefulWidget {
  final String exerciseId;
  const ExerciseProgressDetailScreen({super.key, required this.exerciseId});

  @override
  State<ExerciseProgressDetailScreen> createState() => _ExerciseProgressDetailScreenState();
}

class _ExerciseProgressDetailScreenState extends State<ExerciseProgressDetailScreen> {
  bool _loading = true;
  Ejercicio? _exercise;
  List<Map<String, dynamic>> _history = [];
  String _chartMode = 'peso'; // 'peso' or 'volumen'

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ExerciseService.getExerciseById(widget.exerciseId),
        WorkoutService.getExerciseHistory(userId, widget.exerciseId),
      ]);
      if (mounted) {
        setState(() {
          _exercise = results[0] as Ejercicio?;
          _history = results[1] as List<Map<String, dynamic>>;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // Group by date for chart: max weight or total volume per session
  List<_SessionData> get _sessions {
    final map = <String, _SessionData>{};
    for (final set in _history) {
      final date = set['fecha'] as String? ?? '';
      final weight = (set['peso_utilizado'] as num?)?.toDouble() ?? 0;
      final reps = (set['repeticiones'] as num?)?.toInt() ?? 0;
      final volume = weight * reps;
      if (!map.containsKey(date)) {
        map[date] = _SessionData(date: date, maxWeight: weight, totalVolume: volume);
      } else {
        final s = map[date]!;
        map[date] = _SessionData(
          date: date,
          maxWeight: weight > s.maxWeight ? weight : s.maxWeight,
          totalVolume: s.totalVolume + volume,
        );
      }
    }
    return map.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  }

  String get _recommendation {
    if (_history.isEmpty) return 'Aún no hay suficientes datos para dar recomendaciones.';

    final recentSets = _history.length > 5 ? _history.sublist(_history.length - 5) : _history;
    final highRpe = recentSets.where((s) => ((s['rpe'] as num?) ?? 0) >= 9.5).length;
    if (highRpe >= 3) {
      return 'Estás entrenando al fallo muy seguido últimamente (RPE 9.5 - 10). Considera bajar un poco el RPE en tus próximas sesiones para mejorar la recuperación.';
    }

    final lowRpe = recentSets.where((s) {
      final rpe = (s['rpe'] as num?)?.toDouble() ?? 0;
      return rpe <= 6 && rpe > 0;
    }).length;
    if (lowRpe >= 3) {
      return 'Tus últimas series se sienten bastante ligeras (RPE bajo). Si te sientes con energía, podrías intentar aumentar un poco el peso.';
    }

    final sessions = _sessions;
    if (sessions.length >= 4) {
      final half = sessions.length ~/ 2;
      final firstAvg = sessions.sublist(0, half).fold(0.0, (sum, s) => sum + (_chartMode == 'peso' ? s.maxWeight : s.totalVolume)) / half;
      final secondAvg = sessions.sublist(half).fold(0.0, (sum, s) => sum + (_chartMode == 'peso' ? s.maxWeight : s.totalVolume)) / (sessions.length - half);

      if (secondAvg > firstAvg * 1.05) {
        return '¡Excelente! Hay una tendencia clara de progreso. Tus números están mejorando, sigue así.';
      } else if (secondAvg < firstAvg * 0.95) {
        return 'Parece que el progreso ha retrocedido ligeramente. Asegúrate de descansar y comer bien. Tal vez sea momento de una semana de descarga.';
      }
      return 'Tus números se han mantenido estables. Si sientes estancamiento, intenta variar el rango de repeticiones o la variación del ejercicio.';
    }

    return 'Sigue registrando tus series para obtener recomendaciones personalizadas.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final sessions = _sessions;

    if (_loading) {
      return Scaffold(body: SafeArea(child: Column(children: [
        Row(children: [IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()), const Expanded(child: Center(child: Text('Cargando...')))]),
        const Expanded(child: Center(child: CircularProgressIndicator())),
      ])));
    }

    // Group history by date for list
    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final s in _history) {
      final d = s['fecha'] as String? ?? '';
      grouped.putIfAbsent(d, () => []).add(s);
    }
    final sortedDates = grouped.keys.toList()..sort((a, b) => b.compareTo(a));

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
                Expanded(child: Center(child: Text(_exercise?.titulo ?? 'Progreso', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis))),
                const SizedBox(width: 48),
              ],
            ),
            Divider(height: 1, color: theme.dividerColor.withAlpha(25)),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Chart
                  _buildChart(theme, sessions),
                  const SizedBox(height: 16),
                  // Recommendation
                  _buildRecommendation(theme),
                  const SizedBox(height: 16),
                  // History
                  Text('Historial de Series', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: theme.textTheme.bodyLarge?.color)),
                  const SizedBox(height: 12),
                  ...sortedDates.map((date) => _buildSessionCard(theme, date, grouped[date]!)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChart(ThemeData theme, List<_SessionData> sessions) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        children: [
          // Toggle
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(30),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Expanded(child: _buildToggle(theme, 'Max Peso', 'peso')),
                Expanded(child: _buildToggle(theme, 'Volumen Total', 'volumen')),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (sessions.length >= 2)
            SizedBox(
              height: 200,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(color: theme.dividerColor.withAlpha(25), strokeWidth: 1),
                  ),
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true, reservedSize: 45,
                        getTitlesWidget: (v, _) => Text('${v.toInt()} kg', style: TextStyle(fontSize: 10, color: theme.textTheme.bodyMedium?.color)),
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: sessions.asMap().entries.map((e) {
                        final v = _chartMode == 'peso' ? e.value.maxWeight : e.value.totalVolume;
                        return FlSpot(e.key.toDouble(), v);
                      }).toList(),
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(show: true, color: AppColors.primary.withAlpha(30)),
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text('No hay datos suficientes para la gráfica.', style: TextStyle(color: theme.textTheme.bodyMedium?.color)),
            ),
        ],
      ),
    );
  }

  Widget _buildToggle(ThemeData theme, String label, String mode) {
    final active = _chartMode == mode;
    return GestureDetector(
      onTap: () => setState(() => _chartMode = mode),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Center(
          child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: active ? Colors.white : AppColors.primary)),
        ),
      ),
    );
  }

  Widget _buildRecommendation(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withAlpha(20),
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: AppColors.primary, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Análisis de IA', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.primary)),
            ],
          ),
          const SizedBox(height: 8),
          Text(_recommendation, style: TextStyle(fontSize: 14, height: 1.5, color: theme.textTheme.bodyLarge?.color)),
        ],
      ),
    );
  }

  Widget _buildSessionCard(ThemeData theme, String date, List<Map<String, dynamic>> sets) {
    sets.sort((a, b) => ((a['numero_serie'] as num?) ?? 0).compareTo((b['numero_serie'] as num?) ?? 0));

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
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
              const Icon(Icons.event, size: 20, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(date, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: theme.textTheme.bodyLarge?.color)),
            ],
          ),
          const Divider(height: 16),
          ...sets.map((set) {
            final tipoPeso = TipoPeso.fromString(set['tipo_peso'] as String?);
            final weightLabel = tipoPeso == TipoPeso.corporal
                ? 'BW'
                : '${set['peso_utilizado'] ?? 0} ${tipoPeso.shortLabel.toLowerCase()}';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(width: 70, child: Text('Serie ${set['numero_serie'] ?? '-'}', style: TextStyle(fontSize: 14, color: theme.textTheme.bodyMedium?.color))),
                  Expanded(child: Text('$weightLabel × ${set['repeticiones'] ?? 0} reps', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: theme.textTheme.bodyLarge?.color))),
                  if (set['rpe'] != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: theme.dividerColor.withAlpha(25),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text('RPE ${set['rpe']}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: theme.textTheme.bodyMedium?.color)),
                    )
                  else
                    const SizedBox(width: 50),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _SessionData {
  final String date;
  final double maxWeight;
  final double totalVolume;
  _SessionData({required this.date, required this.maxWeight, required this.totalVolume});
}
