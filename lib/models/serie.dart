class Serie {
  final String id;
  final String ejercicioProgramadoId;
  final int numeroSerie;
  final int? repeticiones;
  final double? pesoUtilizado;
  final int? rpe;
  final int? descansoSegundos;
  final DateTime? createdAt;

  Serie({
    required this.id,
    required this.ejercicioProgramadoId,
    required this.numeroSerie,
    this.repeticiones,
    this.pesoUtilizado,
    this.rpe,
    this.descansoSegundos,
    this.createdAt,
  });

  factory Serie.fromJson(Map<String, dynamic> json) {
    return Serie(
      id: json['id'] as String,
      ejercicioProgramadoId: json['ejercicio_programado_id'] as String,
      numeroSerie: json['numero_serie'] as int? ?? 0,
      repeticiones: json['repeticiones'] as int?,
      pesoUtilizado: (json['peso_utilizado'] as num?)?.toDouble(),
      rpe: json['rpe'] as int?,
      descansoSegundos: json['descanso_segundos'] as int?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'ejercicio_programado_id': ejercicioProgramadoId,
        'numero_serie': numeroSerie,
        'repeticiones': repeticiones,
        'peso_utilizado': pesoUtilizado,
        'rpe': rpe,
        'descanso_segundos': descansoSegundos,
      };
}
