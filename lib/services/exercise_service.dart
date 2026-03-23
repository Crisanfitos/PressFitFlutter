import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pressfit/models/ejercicio.dart';

class ExerciseService {
  static final _supabase = Supabase.instance.client;

  static Future<List<Ejercicio>> getExercises() async {
    final data =
        await _supabase.from('ejercicios').select().order('titulo');
    return (data as List).map((e) => Ejercicio.fromJson(e)).toList();
  }

  static Future<Ejercicio?> getExerciseById(String id) async {
    final data =
        await _supabase.from('ejercicios').select().eq('id', id).single();
    return Ejercicio.fromJson(data);
  }

  static Future<List<Map<String, dynamic>>> addExercisesToRoutineDay(
    String userId,
    String routineDayId,
    List<String> exerciseIds,
  ) async {
    // Get current max order
    final currentExercises = await _supabase
        .from('ejercicios_programados')
        .select('orden_ejecucion')
        .eq('rutina_diaria_id', routineDayId)
        .order('orden_ejecucion', ascending: false)
        .limit(1);

    int nextIndex =
        (currentExercises.isNotEmpty ? currentExercises[0]['orden_ejecucion'] as int : 0) + 1;

    final inserts = exerciseIds.asMap().entries.map((entry) => {
          'rutina_diaria_id': routineDayId,
          'ejercicio_id': entry.value,
          'orden_ejecucion': nextIndex + entry.key,
        }).toList();

    final data = await _supabase
        .from('ejercicios_programados')
        .insert(inserts)
        .select();
    return List<Map<String, dynamic>>.from(data);
  }

  static Future<String?> getPersonalNote(
      String userId, String exerciseId) async {
    try {
      final data = await _supabase
          .from('notas_personales_ejercicios')
          .select('contenido_nota')
          .eq('usuario_id', userId)
          .eq('ejercicio_id', exerciseId)
          .single();
      return data['contenido_nota'] as String?;
    } catch (_) {
      return null;
    }
  }

  static Future<void> savePersonalNote(
    String userId,
    String exerciseId,
    String content,
  ) async {
    await _supabase.from('notas_personales_ejercicios').upsert(
      {
        'usuario_id': userId,
        'ejercicio_id': exerciseId,
        'contenido_nota': content,
        'updated_at': DateTime.now().toIso8601String(),
      },
      onConflict: 'usuario_id, ejercicio_id',
    );
  }

  static Future<List<Ejercicio>> getUserExercisesWithProgress(
      String userId) async {
    final seriesData = await _supabase
        .from('series')
        .select('''
          ejercicio_programado:ejercicios_programados!inner(
            ejercicio_id,
            rutina_diaria:rutinas_diarias!inner(
              rutina_semanal:rutinas_semanales!inner(
                usuario_id
              )
            )
          )
        ''')
        .not('peso_utilizado', 'is', null);

    final exerciseIds = <String>{};
    for (final serie in seriesData) {
      final ep = serie['ejercicio_programado'] as Map<String, dynamic>?;
      final rd = ep?['rutina_diaria'] as Map<String, dynamic>?;
      final rs = rd?['rutina_semanal'] as Map<String, dynamic>?;
      if (rs?['usuario_id'] == userId && ep?['ejercicio_id'] != null) {
        exerciseIds.add(ep!['ejercicio_id'] as String);
      }
    }

    if (exerciseIds.isEmpty) return [];

    final exercises = await _supabase
        .from('ejercicios')
        .select()
        .inFilter('id', exerciseIds.toList())
        .order('titulo');

    return (exercises as List).map((e) => Ejercicio.fromJson(e)).toList();
  }
}
