class HistorialPeso {
  final String id;
  final String usuarioId;
  final double peso;
  final DateTime createdAt;

  HistorialPeso({
    required this.id,
    required this.usuarioId,
    required this.peso,
    required this.createdAt,
  });

  factory HistorialPeso.fromJson(Map<String, dynamic> json) {
    return HistorialPeso(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String? ?? '',
      peso: (json['peso'] as num).toDouble(),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
