import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pressfit/providers/auth_provider.dart';
import 'package:pressfit/services/routine_service.dart';
import 'package:pressfit/models/rutina_semanal.dart';
import 'package:pressfit/theme/app_theme.dart';

class MonthlyCalendarScreen extends StatefulWidget {
  const MonthlyCalendarScreen({super.key});

  @override
  State<MonthlyCalendarScreen> createState() => _MonthlyCalendarScreenState();
}

class _MonthlyCalendarScreenState extends State<MonthlyCalendarScreen> {
  DateTime _currentDate = DateTime.now();
  RutinaSemanal? _selectedRoutine;
  List<RutinaSemanal> _routines = [];
  Set<String> _completedDays = {};
  Set<String> _inProgressDays = {};
  Set<String> _missedDays = {};
  bool _showRoutineSelector = false;
  bool _loading = true;
  final _scaffoldKey = GlobalKey<ScaffoldState>();

  int get _year => _currentDate.year;
  int get _month => _currentDate.month;

  static const _monthNames = [
    'Enero', 'Febrero', 'Marzo', 'Abril', 'Mayo', 'Junio',
    'Julio', 'Agosto', 'Septiembre', 'Octubre', 'Noviembre', 'Diciembre'
  ];
  static const _weekDays = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];
  static const _dayNames = ['Domingo', 'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado'];

  @override
  void initState() {
    super.initState();
    _loadRoutines();
  }

  Future<void> _loadRoutines() async {
    final userId = context.read<AuthProvider>().user?.id;
    if (userId == null) return;

    try {
      final routines = await RoutineService.getAllWeeklyRoutines(userId);
      debugPrint('Calendar: loaded ${routines.length} routines');
      if (!mounted) return;
      setState(() {
        _routines = routines;
        _selectedRoutine = routines.where((r) => r.activa).firstOrNull ?? routines.firstOrNull;
        _loading = false;
      });
      if (_selectedRoutine != null) {
        debugPrint('Calendar: selected routine "${_selectedRoutine!.nombre}" (${_selectedRoutine!.id})');
        _loadWorkoutStats();
      }
    } catch (e) {
      debugPrint('Calendar._loadRoutines error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadWorkoutStats() async {
    if (_selectedRoutine == null) return;

    final startDate = DateTime(_year, _month, 1).toIso8601String();
    final endDate = DateTime(_year, _month + 1, 0).toIso8601String();

    try {
      final workouts = await RoutineService.getWorkoutsForDateRange(
        [_selectedRoutine!.id],
        startDate,
        endDate,
      );

      final completed = <String>{};
      final inProgress = <String>{};

      for (final w in workouts) {
        final fecha = w.fechaDia;
        if (fecha != null) {
          if (w.completada) {
            completed.add(fecha);
          } else if (w.horaInicio != null && w.horaFin == null) {
            inProgress.add(fecha);
          }
        }
      }

      // Calculate missed days: past days with exercises in template but no workout
      final missed = <String>{};
      try {
        if (_selectedRoutine != null) {
          final routine = await RoutineService.getWeeklyRoutineWithDays(_selectedRoutine!.id);
          if (routine != null) {
            // Build map of dayName -> has exercises
            final templateDays = <String, bool>{};
            for (final day in routine.rutinasDiarias) {
              if (day.fechaDia == null && day.ejerciciosProgramados.isNotEmpty) {
                templateDays[day.nombreDia] = true;
              }
            }

            final now = DateTime.now();
            final today = DateTime(now.year, now.month, now.day);
            final firstDay = DateTime(_year, _month, 1);
            final lastDay = DateTime(_year, _month + 1, 0);

            for (int d = 1; d <= lastDay.day; d++) {
              final date = DateTime(_year, _month, d);
              if (date.isAfter(today) || date.isBefore(firstDay)) continue;
              final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
              if (completed.contains(dateStr) || inProgress.contains(dateStr)) continue;

              // Check if this day of week had exercises in template
              final dayName = _dayNames[date.weekday % 7];
              if (templateDays[dayName] == true && date.isBefore(today)) {
                missed.add(dateStr);
              }
            }
          }
        }
      } catch (_) {}

      if (mounted) {
        setState(() {
          _completedDays = completed;
          _inProgressDays = inProgress;
          _missedDays = missed;
        });
      }
    } catch (e) {
      debugPrint('Calendar._loadWorkoutStats error: $e');
    }
  }

  List<DateTime?> get _calendarDays {
    final firstDay = DateTime(_year, _month, 1);
    final lastDay = DateTime(_year, _month + 1, 0);
    final startWeekday = (firstDay.weekday - 1) % 7; // Monday = 0

    final days = <DateTime?>[];
    for (int i = 0; i < startWeekday; i++) {
      days.add(null);
    }
    for (int d = 1; d <= lastDay.day; d++) {
      days.add(DateTime(_year, _month, d));
    }
    return days;
  }

  bool _isInCurrentWeek(DateTime date) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    final mondayStart = DateTime(monday.year, monday.month, monday.day);
    final sundayEnd = DateTime(sunday.year, sunday.month, sunday.day, 23, 59, 59);
    return date.isAfter(mondayStart.subtract(const Duration(seconds: 1))) &&
        date.isBefore(sundayEnd.add(const Duration(seconds: 1)));
  }

  void _handleDayPress(DateTime? date) {
    if (date == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selected = DateTime(date.year, date.month, date.day);
    if (selected.isAfter(today)) return;

    context.go('/weekly/day', extra: {
      'date': date.toIso8601String(),
      'routineId': _selectedRoutine?.id,
      'isToday': selected.isAtSameMomentAs(today),
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isCurrentMonth = DateTime.now().year == _year && DateTime.now().month == _month;

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(theme),
      floatingActionButton: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.primary.withAlpha(221)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withAlpha(100),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton(
          onPressed: () => context.go('/weekly/routines'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: const Icon(Icons.edit_note, color: Colors.white),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : RefreshIndicator(
                onRefresh: () async {
                  await _loadRoutines();
                },
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // Header with menu
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.menu),
                          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        const Spacer(),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Routine Selector
                    _buildRoutineSelector(theme),
                    const SizedBox(height: 20),

                    // Month Navigator
                    _buildMonthNavigator(theme),
                    const SizedBox(height: 16),

                    // Week Day Labels
                    Row(
                      children: _weekDays
                          .map((d) => Expanded(
                                child: Center(
                                  child: Text(d,
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: theme.textTheme.bodyMedium?.color,
                                      )),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 8),

                    // Calendar Grid
                    _buildCalendarGrid(theme, isCurrentMonth),

                    const SizedBox(height: 24),
                    // Legend
                    _buildLegend(theme),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildRoutineSelector(ThemeData theme) {
    return Container(
      decoration: BoxDecoration(
        color: theme.cardTheme.color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withAlpha(25)),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () => setState(() => _showRoutineSelector = !_showRoutineSelector),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, color: AppColors.primary, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _selectedRoutine?.nombre ?? 'Seleccionar Rutina',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: theme.textTheme.bodyLarge?.color,
                      ),
                    ),
                  ),
                  Icon(
                    _showRoutineSelector ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: theme.textTheme.bodyMedium?.color,
                  ),
                ],
              ),
            ),
          ),
          if (_showRoutineSelector)
            ..._routines.map((routine) => Container(
                  decoration: BoxDecoration(
                    border: Border(top: BorderSide(color: theme.dividerColor.withAlpha(25))),
                  ),
                  child: ListTile(
                    title: Text(
                      routine.nombre,
                      style: TextStyle(
                        color: routine.activa
                            ? theme.textTheme.bodyLarge?.color
                            : theme.textTheme.bodyMedium?.color,
                        fontWeight: routine.activa ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                    trailing: routine.activa
                        ? const Icon(Icons.check_circle, color: AppColors.primary, size: 22)
                        : IconButton(
                            icon: Icon(Icons.radio_button_unchecked,
                                color: theme.textTheme.bodyMedium?.color, size: 22),
                            onPressed: () async {
                              final userId = context.read<AuthProvider>().user?.id;
                              if (userId == null) return;
                              await RoutineService.setActiveRoutine(userId, routine.id);
                              _loadRoutines();
                            },
                          ),
                    onTap: () {
                      setState(() {
                        _selectedRoutine = routine;
                        _showRoutineSelector = false;
                      });
                      _loadWorkoutStats();
                    },
                  ),
                )),
        ],
      ),
    );
  }

  Widget _buildMonthNavigator(ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          style: IconButton.styleFrom(backgroundColor: theme.cardTheme.color),
          icon: const Icon(Icons.chevron_left, size: 28),
          onPressed: () {
            setState(() => _currentDate = DateTime(_year, _month - 1));
            _loadWorkoutStats();
          },
        ),
        Text(
          '${_monthNames[_month - 1]} $_year',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: theme.textTheme.bodyLarge?.color,
          ),
        ),
        IconButton(
          style: IconButton.styleFrom(backgroundColor: theme.cardTheme.color),
          icon: const Icon(Icons.chevron_right, size: 28),
          onPressed: () {
            setState(() => _currentDate = DateTime(_year, _month + 1));
            _loadWorkoutStats();
          },
        ),
      ],
    );
  }

  Widget _buildCalendarGrid(ThemeData theme, bool isCurrentMonth) {
    final days = _calendarDays;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daySize = (MediaQuery.of(context).size.width - 48) / 7;

    return Wrap(
      children: days.map((date) {
        if (date == null) {
          return SizedBox(width: daySize, height: daySize);
        }

        final dateNorm = DateTime(date.year, date.month, date.day);
        final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
        final isToday = dateNorm.isAtSameMomentAs(today);
        final isFuture = dateNorm.isAfter(today);
        final inCurrentWeek = isCurrentMonth && _isInCurrentWeek(date);
        final isCompleted = _completedDays.contains(dateStr);
        final isInProgress = _inProgressDays.contains(dateStr);
        final isMissed = _missedDays.contains(dateStr);

        Color? bgColor;
        Color textColor = theme.textTheme.bodyLarge?.color ?? Colors.white;
        FontWeight fontWeight = FontWeight.w500;

        if (isCompleted) {
          bgColor = AppColors.success;
          textColor = Colors.white;
          fontWeight = FontWeight.bold;
        } else if (isInProgress) {
          bgColor = AppColors.warning;
          textColor = Colors.white;
          fontWeight = FontWeight.bold;
        } else if (isToday) {
          bgColor = AppColors.primary;
          textColor = AppColors.primaryText;
          fontWeight = FontWeight.bold;
        } else if (isMissed) {
          bgColor = AppColors.error.withAlpha(48);
        }

        return GestureDetector(
          onTap: isFuture ? null : () => _handleDayPress(date),
          child: SizedBox(
            width: daySize,
            height: daySize,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (inCurrentWeek)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.primary.withAlpha(21),
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                Container(
                  width: daySize - 8,
                  height: daySize - 8,
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: Opacity(
                    opacity: isFuture ? 0.4 : 1.0,
                    child: Text(
                      '${date.day}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: fontWeight,
                        color: textColor,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDrawer(ThemeData theme) {
    return Drawer(
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.fitness_center, color: AppColors.primary, size: 28),
                  const SizedBox(width: 12),
                  Text('PressFit',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: theme.textTheme.bodyLarge?.color)),
                ],
              ),
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.library_books, color: AppColors.primary),
              title: const Text('Catálogo de Ejercicios'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(context);
                context.go('/weekly/catalog');
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(ThemeData theme) {
    final items = [
      ('Hoy', AppColors.primary),
      ('Completado', AppColors.success),
      ('En Progreso', AppColors.warning),
      ('Sin Completar', AppColors.error.withAlpha(48)),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 8,
      children: items.map((item) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(color: item.$2, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(item.$1, style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color)),
          ],
        );
      }).toList(),
    );
  }
}
