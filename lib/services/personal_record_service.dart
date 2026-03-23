import 'package:supabase_flutter/supabase_flutter.dart';

class PersonalRecordService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> getPersonalRecord(
    String userId,
    String exerciseId,
  ) async {
    final data = await _supabase.rpc('get_personal_record', params: {
      'p_usuario_id': userId,
      'p_ejercicio_id': exerciseId,
    });

    if (data is List && data.isNotEmpty) {
      return data[0] as Map<String, dynamic>;
    }
    return null;
  }

  static Future<List<Map<String, dynamic>>> getExerciseHistory(
    String userId,
    String exerciseId,
  ) async {
    final data = await _supabase.rpc('get_exercise_history', params: {
      'p_usuario_id': userId,
      'p_ejercicio_id': exerciseId,
    });

    return List<Map<String, dynamic>>.from(data ?? []);
  }
}
