import 'package:pressfit/models/rutina_diaria.dart';

class RutinaSemanal {
  final String id;
  final String usuarioId;
  final String nombre;
  final String? objetivo;
  final bool esPlantilla;
  final bool activa;
  final String? copiadaDeId;
  final String? fechaInicioSemana;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final List<RutinaDiaria> rutinasDiarias;

  RutinaSemanal({
    required this.id,
    required this.usuarioId,
    required this.nombre,
    this.objetivo,
    this.esPlantilla = false,
    this.activa = false,
    this.copiadaDeId,
    this.fechaInicioSemana,
    this.createdAt,
    this.updatedAt,
    this.rutinasDiarias = const [],
  });

  factory RutinaSemanal.fromJson(Map<String, dynamic> json) {
    return RutinaSemanal(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String,
      nombre: json['nombre'] as String? ?? '',
      objetivo: json['objetivo'] as String?,
      esPlantilla: json['es_plantilla'] as bool? ?? false,
      activa: json['activa'] as bool? ?? false,
      copiadaDeId: json['copiada_de_id'] as String?,
      fechaInicioSemana: json['fecha_inicio_semana'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
      rutinasDiarias: (json['rutinas_diarias'] as List<dynamic>?)
              ?.map((d) => RutinaDiaria.fromJson(d as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'usuario_id': usuarioId,
        'nombre': nombre,
        'objetivo': objetivo,
        'es_plantilla': esPlantilla,
        'activa': activa,
        'copiada_de_id': copiadaDeId,
        'fecha_inicio_semana': fechaInicioSemana,
      };
}
