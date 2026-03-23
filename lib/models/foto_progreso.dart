class FotoProgreso {
  final String id;
  final String usuarioId;
  final String urlFoto;
  final String? comentario;
  final DateTime createdAt;

  FotoProgreso({
    required this.id,
    required this.usuarioId,
    required this.urlFoto,
    this.comentario,
    required this.createdAt,
  });

  factory FotoProgreso.fromJson(Map<String, dynamic> json) {
    return FotoProgreso(
      id: json['id'] as String,
      usuarioId: json['usuario_id'] as String? ?? '',
      urlFoto: json['url_foto'] as String? ?? '',
      comentario: json['comentario'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'usuario_id': usuarioId,
        'url_foto': urlFoto,
        'comentario': comentario,
        'created_at': createdAt.toIso8601String(),
      };
}
