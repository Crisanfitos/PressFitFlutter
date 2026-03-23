import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:pressfit/models/foto_progreso.dart';

class ProgressService {
  static final _supabase = Supabase.instance.client;

  static Future<List<Map<String, dynamic>>> getDailyProgress(
    String userId,
    DateTime date,
  ) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1)).subtract(const Duration(milliseconds: 1));

    final data = await _supabase
        .from('rutinas_diarias')
        .select('''
          *,
          rutina_semanal:rutinas_semanales!inner(usuario_id),
          ejercicios_programados (
            *,
            ejercicio:ejercicios (*),
            series (*)
          )
        ''')
        .eq('rutina_semanal.usuario_id', userId)
        .gte('hora_fin', startOfDay.toIso8601String())
        .lte('hora_fin', endOfDay.toIso8601String())
        .order('hora_fin', ascending: false);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getWeeklyProgress(
      String userId) async {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday % 7));
    final startOfWeekClean =
        DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    final data = await _supabase
        .from('rutinas_diarias')
        .select('''
          id, hora_inicio, hora_fin,
          rutina_semanal:rutinas_semanales!inner(usuario_id)
        ''')
        .eq('rutina_semanal.usuario_id', userId)
        .gte('hora_fin', startOfWeekClean.toIso8601String())
        .not('hora_fin', 'is', null);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<Map<String, dynamic>>> getMonthlyProgress(
    String userId, {
    int? year,
    int? month,
  }) async {
    final now = DateTime.now();
    final targetYear = year ?? now.year;
    final targetMonth = month ?? now.month;

    final startOfMonth = DateTime(targetYear, targetMonth, 1);
    final endOfMonth = DateTime(targetYear, targetMonth + 1, 0, 23, 59, 59);

    final data = await _supabase
        .from('rutinas_diarias')
        .select('''
          id, hora_inicio, hora_fin, fecha_dia,
          rutina_semanal:rutinas_semanales!inner(usuario_id)
        ''')
        .eq('rutina_semanal.usuario_id', userId)
        .gte('hora_fin', startOfMonth.toIso8601String())
        .lte('hora_fin', endOfMonth.toIso8601String())
        .not('hora_fin', 'is', null);

    return List<Map<String, dynamic>>.from(data);
  }

  static Future<List<FotoProgreso>> getProgressPhotos(String userId) async {
    final data = await _supabase
        .from('fotos_progreso')
        .select()
        .eq('usuario_id', userId)
        .order('created_at', ascending: false);

    final photos = <FotoProgreso>[];
    for (final photo in data) {
      try {
        final path =
            (photo['url_foto'] as String).split('/fotos-progreso/').last;
        final signedData = await _supabase.storage
            .from('fotos-progreso')
            .createSignedUrl(path, 3600);
        photo['url_foto'] = signedData;
      } catch (_) {}
      photos.add(FotoProgreso.fromJson(photo));
    }

    return photos;
  }

  static Future<FotoProgreso?> uploadProgressPhoto(
    String userId,
    String photoPath,
    DateTime? date,
    String comment,
  ) async {
    final fileExt = photoPath.split('.').last.toLowerCase();
    final fileName =
        '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _supabase.storage.from('fotos-progreso').upload(
          fileName,
          photoPath as dynamic,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
        );

    final publicUrl =
        _supabase.storage.from('fotos-progreso').getPublicUrl(fileName);

    final insertData = await _supabase
        .from('fotos_progreso')
        .insert({
          'usuario_id': userId,
          'url_foto': publicUrl,
          'comentario': comment,
          'created_at': (date ?? DateTime.now()).toIso8601String(),
        })
        .select()
        .single();

    return FotoProgreso.fromJson(insertData);
  }

  static Future<void> updateProgressPhoto(
    String photoId,
    Map<String, dynamic> updates,
  ) async {
    await _supabase.from('fotos_progreso').update(updates).eq('id', photoId);
  }

  static Future<void> deleteProgressPhotos(List<String> photoIds) async {
    final photos = await _supabase
        .from('fotos_progreso')
        .select('id, url_foto')
        .inFilter('id', photoIds);

    final filePaths = (photos as List)
        .map((p) => (p['url_foto'] as String).split('/fotos-progreso/').last)
        .where((p) => p.isNotEmpty)
        .toList();

    if (filePaths.isNotEmpty) {
      await _supabase.storage.from('fotos-progreso').remove(filePaths);
    }

    await _supabase.from('fotos_progreso').delete().inFilter('id', photoIds);
  }
}
