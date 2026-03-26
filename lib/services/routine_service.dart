import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pressfit/models/rutina_semanal.dart';
import 'package:pressfit/models/rutina_diaria.dart';

class RoutineService {
  static final _supabase = Supabase.instance.client;
  static SupabaseClient get supabase => _supabase;

  static Future<RutinaSemanal?> getWeeklyRoutineWithDays(
      String routineId) async {
    final data = await _supabase
        .from('rutinas_semanales')
        .select('''
          *,
          rutinas_diarias (
            *,
            ejercicios_programados (
              *,
              ejercicio:ejercicios (*),
              series (*)
            )
          )
        ''')
        .eq('id', routineId)
        .single();
    return RutinaSemanal.fromJson(data);
  }

  static Future<List<RutinaSemanal>> getUserRoutines(String userId) async {
    final data = await _supabase
        .from('rutinas_semanales')
        .select('''
          *,
          rutinas_diarias!inner (
            *,
            ejercicios_programados (
              *,
              ejercicio:ejercicios (*)
            )
          )
        ''')
        .eq('usuario_id', userId)
        .eq('es_plantilla', true)
        .isFilter('rutinas_diarias.fecha_dia', null)
        .order('created_at', ascending: false);
    return (data as List).map((r) => RutinaSemanal.fromJson(r)).toList();
  }

  static Future<RutinaDiaria?> getRoutineDayById(String routineDayId) async {
    final data = await _supabase
        .from('rutinas_diarias')
        .select('''
          *,
          ejercicios_programados (
            id, ejercicio_id, orden_ejecucion, tipo_peso,
            ejercicio:ejercicios (*),
            series (*)
          )
        ''')
        .eq('id', routineDayId)
        .single();
    return RutinaDiaria.fromJson(data);
  }

  static Future<RutinaDiaria?> getRoutineDayByDate(
      String routineId, String fechaDia) async {
    try {
      final data = await _supabase
          .from('rutinas_diarias')
          .select('''
            *,
            ejercicios_programados (
              id, ejercicio_id, orden_ejecucion, tipo_peso,
              ejercicio:ejercicios (*),
              series (*)
            )
          ''')
          .eq('rutina_semanal_id', routineId)
          .eq('fecha_dia', fechaDia)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return RutinaDiaria.fromJson(data);
    } catch (e) {
      debugPrint('getRoutineDayByDate error: $e');
      return null;
    }
  }

  static Future<RutinaDiaria?> getRoutineDayByName(
      String routineId, String nombreDia) async {
    try {
      final data = await _supabase
          .from('rutinas_diarias')
          .select('''
            *,
            ejercicios_programados (
              id, ejercicio_id, orden_ejecucion, tipo_peso,
              ejercicio:ejercicios (*),
              series (*)
            )
          ''')
          .eq('rutina_semanal_id', routineId)
          .eq('nombre_dia', nombreDia)
          .isFilter('fecha_dia', null)
          .limit(1)
          .maybeSingle();
      if (data == null) return null;
      return RutinaDiaria.fromJson(data);
    } catch (e) {
      debugPrint('getRoutineDayByName error: $e');
      return null;
    }
  }

  static String getMondayOfCurrentWeek() {
    final now = DateTime.now();
    final day = now.weekday; // 1=Monday, 7=Sunday
    final monday = now.subtract(Duration(days: day - 1));
    return '${monday.year}-${monday.month.toString().padLeft(2, '0')}-${monday.day.toString().padLeft(2, '0')}';
  }

  static Future<List<RutinaSemanal>> getAllWeeklyRoutines(
      String userId) async {
    try {
      final data = await _supabase
          .from('rutinas_semanales')
          .select()
          .eq('usuario_id', userId)
          .order('created_at', ascending: false);
      debugPrint('getAllWeeklyRoutines: got ${(data as List).length} routines');
      return data.map((r) => RutinaSemanal.fromJson(r)).toList();
    } catch (e) {
      debugPrint('getAllWeeklyRoutines error: $e');
      return [];
    }
  }

  static Future<RutinaSemanal?> createWeeklyRoutine(
      Map<String, dynamic> routineData) async {
    final data = await _supabase
        .from('rutinas_semanales')
        .insert({
          ...routineData,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();

    final routine = RutinaSemanal.fromJson(data);

    const daysOfWeek = [
      'Lunes', 'Martes', 'Miércoles', 'Jueves', 'Viernes', 'Sábado', 'Domingo'
    ];

    await _supabase.from('rutinas_diarias').insert(
      daysOfWeek.map((day) => {
        'rutina_semanal_id': routine.id,
        'nombre_dia': day,
        'fecha_dia': null,
      }).toList(),
    );

    return routine;
  }

  static Future<RutinaSemanal?> updateWeeklyRoutine(
      String id, Map<String, dynamic> updates) async {
    final data = await _supabase
        .from('rutinas_semanales')
        .update({
          ...updates,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return RutinaSemanal.fromJson(data);
  }

  static Future<void> deleteWeeklyRoutine(String id) async {
    await _supabase.from('rutinas_semanales').delete().eq('id', id);
  }

  static Future<RutinaDiaria?> startDailyWorkout(
    String routineDayId,
    String date,
    String startTime,
  ) async {
    final templateDay = await _supabase
        .from('rutinas_diarias')
        .select('*, ejercicios_programados (*, series (*))')
        .eq('id', routineDayId)
        .single();

    // Look for previous completed workout series
    final prevSeriesMap = <String, List<dynamic>>{};
    try {
      final prevWorkouts = await _supabase
          .from('rutinas_diarias')
          .select('id, ejercicios_programados (ejercicio_id, series (numero_serie, peso_utilizado, repeticiones, rpe))')
          .eq('rutina_semanal_id', templateDay['rutina_semanal_id'])
          .eq('nombre_dia', templateDay['nombre_dia'])
          .eq('completada', true)
          .not('fecha_dia', 'is', null)
          .order('fecha_dia', ascending: false)
          .limit(1);

      if (prevWorkouts.isNotEmpty) {
        for (final ex in prevWorkouts[0]['ejercicios_programados'] ?? []) {
          if (ex['series'] != null && (ex['series'] as List).isNotEmpty) {
            prevSeriesMap[ex['ejercicio_id'] as String] = ex['series'] as List;
          }
        }
      }
    } catch (_) {}

    final fechaDia = date.split('T')[0];
    final newWorkout = await _supabase
        .from('rutinas_diarias')
        .insert({
          'rutina_semanal_id': templateDay['rutina_semanal_id'],
          'nombre_dia': templateDay['nombre_dia'],
          'fecha_dia': fechaDia,
          'hora_inicio': startTime,
          'completada': false,
        })
        .select()
        .single();

    for (final templateEx in templateDay['ejercicios_programados'] ?? []) {
      try {
        final newEx = await _supabase
            .from('ejercicios_programados')
            .insert({
              'rutina_diaria_id': newWorkout['id'],
              'ejercicio_id': templateEx['ejercicio_id'],
              'orden_ejecucion': templateEx['orden_ejecucion'],
              'notas_sesion': templateEx['notas_sesion'],
              'tipo_peso': templateEx['tipo_peso'] ?? 'total',
            })
            .select('id')
            .single();

        final prevSeries = prevSeriesMap[templateEx['ejercicio_id'] as String];
        final sourceSeries = (prevSeries != null && prevSeries.isNotEmpty)
            ? prevSeries
            : (templateEx['series'] as List?) ?? [];

        if (sourceSeries.isNotEmpty) {
          await _supabase.from('series').insert(
            sourceSeries
                .map((s) => {
                      'ejercicio_programado_id': newEx['id'],
                      'numero_serie': s['numero_serie'],
                      'peso_utilizado': s['peso_utilizado'] ?? 0,
                      'repeticiones': 0,
                    })
                .toList(),
          );
        }
      } catch (_) {}
    }

    return RutinaDiaria.fromJson(newWorkout);
  }

  static Future<List<RutinaDiaria>> getWorkoutsForDateRange(
    List<String> routineWeeklyIds,
    String startDate,
    String endDate,
  ) async {
    final data = await _supabase
        .from('rutinas_diarias')
        .select('''
          id, rutina_semanal_id, nombre_dia, fecha_dia,
          hora_inicio, hora_fin, completada,
          ejercicios_programados (id, ejercicio_id)
        ''')
        .inFilter('rutina_semanal_id', routineWeeklyIds)
        .not('fecha_dia', 'is', null)
        .gte('fecha_dia', startDate.split('T')[0])
        .lte('fecha_dia', endDate.split('T')[0])
        .order('fecha_dia', ascending: true);

    return (data as List).map((d) => RutinaDiaria.fromJson(d)).toList();
  }

  static Future<RutinaSemanal?> startWeeklySession(
      String routineId, String startDate) async {
    final data = await _supabase
        .from('rutinas_semanales')
        .update({
          'activa': true,
          'fecha_inicio_semana': startDate,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', routineId)
        .select()
        .single();
    return RutinaSemanal.fromJson(data);
  }

  static Future<RutinaSemanal?> setActiveRoutine(
      String userId, String routineId) async {
    // Deactivate all
    await _supabase
        .from('rutinas_semanales')
        .update({
          'activa': false,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('usuario_id', userId);

    // Activate selected
    final data = await _supabase
        .from('rutinas_semanales')
        .update({
          'activa': true,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', routineId)
        .select()
        .single();
    return RutinaSemanal.fromJson(data);
  }

  static Future<RutinaSemanal?> createRoutineFromTemplate(
    String userId,
    String templateId,
    String newName,
  ) async {
    // Get the template with all days and exercises
    final template = await getWeeklyRoutineWithDays(templateId);
    if (template == null) return null;

    // Create new routine
    final newRoutine = await createWeeklyRoutine({
      'usuario_id': userId,
      'nombre': newName,
      'objetivo': template.objetivo,
      'es_plantilla': true,
      'activa': false,
    });
    if (newRoutine == null) return null;

    // Get the new routine's days
    final newRoutineWithDays = await getWeeklyRoutineWithDays(newRoutine.id);
    if (newRoutineWithDays == null) return newRoutine;

    // Copy exercises from template days to new days
    for (final templateDay in template.rutinasDiarias) {
      final matchingDay = newRoutineWithDays.rutinasDiarias
          .where((d) => d.nombreDia == templateDay.nombreDia)
          .firstOrNull;
      if (matchingDay == null) continue;

      // Update description
      if (templateDay.descripcion != null) {
        await updateRoutineDayDescription(matchingDay.id, templateDay.descripcion!);
      }

      // Copy exercises
      for (final ex in templateDay.ejerciciosProgramados) {
        final newEx = await _supabase
            .from('ejercicios_programados')
            .insert({
              'rutina_diaria_id': matchingDay.id,
              'ejercicio_id': ex.ejercicioId,
              'orden_ejecucion': ex.ordenEjecucion,
              'tipo_peso': ex.tipoPeso.dbValue,
              'notas_sesion': ex.notasSesion,
            })
            .select('id')
            .single();

        // Copy series
        if (ex.series.isNotEmpty) {
          await _supabase.from('series').insert(
            ex.series.map((s) => {
              'ejercicio_programado_id': newEx['id'],
              'numero_serie': s.numeroSerie,
              'peso_utilizado': s.pesoUtilizado ?? 0,
              'repeticiones': s.repeticiones ?? 0,
            }).toList(),
          );
        }
      }
    }

    return newRoutine;
  }

  /// Get workout stats for a specific routine day (current week).
  /// Returns exerciseCount, duration, isCompleted, startTime, endTime.
  static Future<Map<String, dynamic>?> getWorkoutStatsForRoutineDay(
    String userId,
    String routineDayId,
  ) async {
    try {
      // Get template day info
      final templateDay = await getRoutineDayById(routineDayId);
      if (templateDay == null) return null;

      final startOfWeek = getMondayOfCurrentWeek();

      // Find the most recent workout for this day name in current week
      final data = await _supabase
          .from('rutinas_diarias')
          .select('''
            *,
            ejercicios_programados (
              *,
              ejercicio:ejercicios(*)
            )
          ''')
          .eq('rutina_semanal_id', templateDay.rutinaSemanalId)
          .eq('nombre_dia', templateDay.nombreDia)
          .not('fecha_dia', 'is', null)
          .gte('fecha_dia', startOfWeek)
          .order('updated_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (data == null) {
        return {'exerciseCount': 0, 'duration': null, 'isCompleted': false};
      }

      final exercises = data['ejercicios_programados'] as List? ?? [];
      final uniqueExerciseIds = exercises.map((e) => e['ejercicio_id']).toSet();

      int? duration;
      if (data['completada'] == true &&
          data['hora_inicio'] != null &&
          data['hora_fin'] != null) {
        final start = DateTime.parse(data['hora_inicio'] as String);
        final end = DateTime.parse(data['hora_fin'] as String);
        final mins = end.difference(start).inMinutes;
        if (mins >= 5) duration = mins;
      }

      return {
        'exerciseCount': uniqueExerciseIds.length,
        'duration': duration,
        'isCompleted': data['completada'] == true,
        'startTime': data['hora_inicio'],
        'endTime': data['hora_fin'],
      };
    } catch (e) {
      debugPrint('getWorkoutStatsForRoutineDay error: $e');
      return {'exerciseCount': 0, 'duration': null, 'isCompleted': false};
    }
  }

  /// Get the active (started but not completed) workout for a routine day.
  static Future<Map<String, dynamic>?> getActiveWorkout(
    String userId,
    String routineDayId,
  ) async {
    try {
      final templateDay = await getRoutineDayById(routineDayId);
      if (templateDay == null) return null;

      final startOfWeek = getMondayOfCurrentWeek();

      final data = await _supabase
          .from('rutinas_diarias')
          .select('id, hora_inicio, hora_fin, completada, fecha_dia')
          .eq('rutina_semanal_id', templateDay.rutinaSemanalId)
          .eq('nombre_dia', templateDay.nombreDia)
          .not('fecha_dia', 'is', null)
          .gte('fecha_dia', startOfWeek)
          .not('hora_inicio', 'is', null)
          .eq('completada', false)
          .limit(1)
          .maybeSingle();

      return data;
    } catch (e) {
      debugPrint('getActiveWorkout error: $e');
      return null;
    }
  }

  static Future<void> updateRoutineDayDescription(
      String dayId, String descripcion) async {
    await _supabase
        .from('rutinas_diarias')
        .update({'descripcion': descripcion}).eq('id', dayId);
  }
}
