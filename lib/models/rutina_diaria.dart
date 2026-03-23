import 'package:pressfit/models/ejercicio_programado.dart';

class RutinaDiaria {
  final String id;
  final String rutinaSemanalId;
  final String nombreDia;
  final String? fechaDia;
  final String? horaInicio;
  final String? horaFin;
  final bool completada;
  final String? descripcion;
  final List<EjercicioProgramado> ejerciciosProgramados;

  RutinaDiaria({
    required this.id,
    required this.rutinaSemanalId,
    required this.nombreDia,
    this.fechaDia,
    this.horaInicio,
    this.horaFin,
    this.completada = false,
    this.descripcion,
    this.ejerciciosProgramados = const [],
  });

  factory RutinaDiaria.fromJson(Map<String, dynamic> json) {
    return RutinaDiaria(
      id: json['id'] as String,
      rutinaSemanalId: json['rutina_semanal_id'] as String,
      nombreDia: json['nombre_dia'] as String? ?? '',
      fechaDia: json['fecha_dia'] as String?,
      horaInicio: json['hora_inicio'] as String?,
      horaFin: json['hora_fin'] as String?,
      completada: json['completada'] as bool? ?? false,
      descripcion: json['descripcion'] as String?,
      ejerciciosProgramados: () {
        final list = (json['ejercicios_programados'] as List<dynamic>?)
            ?.map((e) => EjercicioProgramado.fromJson(e as Map<String, dynamic>))
            .toList() ?? [];
        list.sort((a, b) => a.ordenEjecucion.compareTo(b.ordenEjecucion));
        return list;
      }(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rutina_semanal_id': rutinaSemanalId,
        'nombre_dia': nombreDia,
        'fecha_dia': fechaDia,
        'hora_inicio': horaInicio,
        'hora_fin': horaFin,
        'completada': completada,
        'descripcion': descripcion,
      };
}
