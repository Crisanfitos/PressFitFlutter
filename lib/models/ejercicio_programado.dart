import 'package:pressfit/models/ejercicio.dart';
import 'package:pressfit/models/serie.dart';
import 'package:pressfit/models/tipo_peso.dart';

class EjercicioProgramado {
  final String id;
  final String rutinaDiariaId;
  final String ejercicioId;
  final int ordenEjecucion;
  final String? notasSesion;
  final TipoPeso tipoPeso;
  final Ejercicio? ejercicio;
  final List<Serie> series;

  EjercicioProgramado({
    required this.id,
    required this.rutinaDiariaId,
    required this.ejercicioId,
    required this.ordenEjecucion,
    this.notasSesion,
    this.tipoPeso = TipoPeso.total,
    this.ejercicio,
    this.series = const [],
  });

  factory EjercicioProgramado.fromJson(Map<String, dynamic> json) {
    return EjercicioProgramado(
      id: json['id'] as String,
      rutinaDiariaId: json['rutina_diaria_id'] as String,
      ejercicioId: json['ejercicio_id'] as String,
      ordenEjecucion: json['orden_ejecucion'] as int? ?? 0,
      notasSesion: json['notas_sesion'] as String?,
      tipoPeso: TipoPeso.fromString(json['tipo_peso'] as String?),
      ejercicio: json['ejercicio'] != null
          ? Ejercicio.fromJson(json['ejercicio'] as Map<String, dynamic>)
          : null,
      series: () {
        final list = (json['series'] as List<dynamic>?)
            ?.map((s) => Serie.fromJson(s as Map<String, dynamic>))
            .toList() ?? [];
        list.sort((a, b) => a.numeroSerie.compareTo(b.numeroSerie));
        return list;
      }(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'rutina_diaria_id': rutinaDiariaId,
        'ejercicio_id': ejercicioId,
        'orden_ejecucion': ordenEjecucion,
        'notas_sesion': notasSesion,
        'tipo_peso': tipoPeso.dbValue,
      };
}
