import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pressfit/models/rutina_diaria.dart';
import 'package:pressfit/models/serie.dart';
import 'package:pressfit/models/tipo_peso.dart';

class WorkoutService {
  static final _supabase = Supabase.instance.client;

  static Future<RutinaDiaria?> getWorkoutDetails(String workoutId) async {
    final data = await _supabase
        .from('rutinas_diarias')
        .select('''
          *,
          ejercicios_programados (
            *,
            ejercicio:ejercicios (*),
            series (*)
          )
        ''')
        .eq('id', workoutId)
        .single();
    return RutinaDiaria.fromJson(data);
  }

  static Future<RutinaDiaria?> completeWorkout(String workoutId) async {
    final data = await _supabase
        .from('rutinas_diarias')
        .update({
          'completada': true,
          'hora_fin': DateTime.now().toIso8601String(),
        })
        .eq('id', workoutId)
        .select()
        .single();
    return RutinaDiaria.fromJson(data);
  }

  static Future<List<Serie>> getSeriesForExercise(
    String workoutId,
    String exerciseId,
  ) async {
    final scheduled = await _supabase
        .from('ejercicios_programados')
        .select('id')
        .eq('rutina_diaria_id', workoutId)
        .eq('ejercicio_id', exerciseId)
        .maybeSingle();

    if (scheduled == null) return [];

    final series = await _supabase
        .from('series')
        .select()
        .eq('ejercicio_programado_id', scheduled['id'])
        .order('numero_serie', ascending: true);

    return (series as List).map((s) => Serie.fromJson(s)).toList();
  }

  static Future<Serie?> addSet(
    String workoutId,
    String exerciseId,
    int setNumber,
    double weight,
    int reps,
  ) async {
    // Find or create scheduled exercise
    var scheduled = await _supabase
        .from('ejercicios_programados')
        .select('id')
        .eq('rutina_diaria_id', workoutId)
        .eq('ejercicio_id', exerciseId)
        .maybeSingle();

    if (scheduled == null) {
      final maxOrderData = await _supabase
          .from('ejercicios_programados')
          .select('orden_ejecucion')
          .eq('rutina_diaria_id', workoutId)
          .order('orden_ejecucion', ascending: false)
          .limit(1)
          .maybeSingle();

      final nextOrder =
          ((maxOrderData?['orden_ejecucion'] as int?) ?? 0) + 1;

      scheduled = await _supabase
          .from('ejercicios_programados')
          .insert({
            'rutina_diaria_id': workoutId,
            'ejercicio_id': exerciseId,
            'orden_ejecucion': nextOrder,
          })
          .select()
          .single();
    }

    final data = await _supabase
        .from('series')
        .insert({
          'ejercicio_programado_id': scheduled['id'],
          'numero_serie': setNumber,
          'peso_utilizado': weight,
          'repeticiones': reps,
        })
        .select()
        .single();

    return Serie.fromJson(data);
  }

  static Future<Serie?> updateSet(
    String setId, {
    double? weight,
    int? reps,
    int? rpe,
    int? descansoSegundos,
  }) async {
    final updates = <String, dynamic>{};
    if (weight != null) updates['peso_utilizado'] = weight;
    if (reps != null) updates['repeticiones'] = reps;
    if (rpe != null) updates['rpe'] = rpe;
    if (descansoSegundos != null) updates['descanso_segundos'] = descansoSegundos;

    final data = await _supabase
        .from('series')
        .update(updates)
        .eq('id', setId)
        .select()
        .single();
    return Serie.fromJson(data);
  }

  static Future<void> deleteSet(String setId) async {
    await _supabase.from('series').delete().eq('id', setId);
  }

  static Future<void> removeExerciseFromRoutine(
      String routineExerciseId) async {
    await _supabase
        .from('ejercicios_programados')
        .delete()
        .eq('id', routineExerciseId);
  }

  static Future<void> removeExerciseFromWorkout(
    String workoutId,
    String exerciseId,
  ) async {
    await _supabase
        .from('ejercicios_programados')
        .delete()
        .eq('rutina_diaria_id', workoutId)
        .eq('ejercicio_id', exerciseId);
  }

  static Future<Map<String, dynamic>?> addExerciseToWorkout(
    String workoutId,
    String exerciseId,
  ) async {
    final maxOrderData = await _supabase
        .from('ejercicios_programados')
        .select('orden_ejecucion')
        .eq('rutina_diaria_id', workoutId)
        .order('orden_ejecucion', ascending: false)
        .limit(1)
        .maybeSingle();

    final nextOrder =
        ((maxOrderData?['orden_ejecucion'] as int?) ?? 0) + 1;

    final data = await _supabase
        .from('ejercicios_programados')
        .insert({
          'rutina_diaria_id': workoutId,
          'ejercicio_id': exerciseId,
          'orden_ejecucion': nextOrder,
        })
        .select('*, ejercicio:ejercicios (*)')
        .single();
    return data;
  }

  static Future<List<Map<String, dynamic>>> getExerciseHistory(
    String userId,
    String exerciseId,
  ) async {
    final data = await _supabase
        .from('series')
        .select('''
          id, numero_serie, peso_utilizado, repeticiones, rpe,
          ejercicios_programados!inner(
            ejercicio_id, tipo_peso,
            rutinas_diarias!inner(
              id, fecha_dia,
              rutinas_semanales!inner(usuario_id)
            )
          )
        ''')
        .eq('ejercicios_programados.ejercicio_id', exerciseId)
        .eq('ejercicios_programados.rutinas_diarias.rutinas_semanales.usuario_id', userId)
        .not('ejercicios_programados.rutinas_diarias.fecha_dia', 'is', null)
        .not('peso_utilizado', 'is', null);

    final history = (data as List).map((row) {
      final ep = row['ejercicios_programados'] as Map<String, dynamic>;
      final rd = ep['rutinas_diarias'] as Map<String, dynamic>;
      return {
        'id': row['id'],
        'numero_serie': row['numero_serie'],
        'peso_utilizado': row['peso_utilizado'],
        'repeticiones': row['repeticiones'],
        'rpe': row['rpe'],
        'tipo_peso': ep['tipo_peso'] ?? 'total',
        'fecha': rd['fecha_dia'],
        'rutina_id': rd['id'],
      };
    }).toList()
      ..sort((a, b) => (a['fecha'] as String).compareTo(b['fecha'] as String));

    return history;
  }

  static Future<void> updateWeightType(
    String scheduledExerciseId,
    TipoPeso tipoPeso,
  ) async {
    await _supabase
        .from('ejercicios_programados')
        .update({'tipo_peso': tipoPeso.dbValue})
        .eq('id', scheduledExerciseId);
  }
}
