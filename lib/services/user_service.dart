import 'package:supabase_flutter/supabase_flutter.dart';

class UserService {
  static final _supabase = Supabase.instance.client;

  static Future<Map<String, dynamic>?> createOrUpdateProfile(User user) async {
    final response = await _supabase
        .from('usuarios')
        .upsert({
          'id': user.id,
          'email': user.email,
          'nombre': user.userMetadata?['full_name'] ?? '',
          'updated_at': DateTime.now().toIso8601String(),
        })
        .select()
        .single();
    return response;
  }

  static Future<Map<String, dynamic>?> saveUserMetrics(
    String userId, {
    required double weight,
    required double heightCm,
    double? bodyFatPercentage,
    double? imc,
  }) async {
    final calculatedImc = imc ?? (weight / ((heightCm / 100) * (heightCm / 100)));

    final data = await _supabase
        .from('usuarios')
        .update({
          'peso': weight,
          'altura': heightCm / 100, // cm -> m for DB
          'grasa_corporal': bodyFatPercentage,
          'imc': double.parse(calculatedImc.toStringAsFixed(1)),
        })
        .eq('id', userId)
        .select()
        .single();

    // Insert weight into history
    if (weight > 0) {
      await _supabase.from('historial_peso').insert({
        'usuario_id': userId,
        'peso': weight,
      });
    }

    return data;
  }

  static Future<Map<String, dynamic>?> getUserMetrics(String userId) async {
    try {
      final data = await _supabase
          .from('usuarios')
          .select('peso, altura, grasa_corporal, imc, updated_at')
          .eq('id', userId)
          .single();
      return data;
    } catch (_) {
      return null;
    }
  }

  static Future<String?> uploadProfilePhoto(
      String userId, String filePath) async {
    final fileExt = filePath.split('.').last.toLowerCase();
    final fileName = '$userId/${DateTime.now().millisecondsSinceEpoch}.$fileExt';

    await _supabase.storage.from('fotos-perfil').upload(
          fileName,
          filePath as dynamic,
          fileOptions: FileOptions(contentType: 'image/$fileExt', upsert: true),
        );

    final publicUrl =
        _supabase.storage.from('fotos-perfil').getPublicUrl(fileName);

    await _supabase.auth.updateUser(
      UserAttributes(data: {'custom_avatar_url': publicUrl}),
    );

    await _supabase
        .from('usuarios')
        .update({'url_foto': publicUrl}).eq('id', userId);

    return publicUrl;
  }

  static Future<List<Map<String, dynamic>>> getWeightHistory(
    String userId, {
    int limit = 20,
  }) async {
    final data = await _supabase
        .from('historial_peso')
        .select('id, peso, created_at')
        .eq('usuario_id', userId)
        .order('created_at', ascending: true)
        .limit(limit);
    return List<Map<String, dynamic>>.from(data);
  }
}
