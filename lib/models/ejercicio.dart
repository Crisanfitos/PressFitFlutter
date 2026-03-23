class Ejercicio {
  final String id;
  final String titulo;
  final String? descripcion;
  final String? grupoMuscular;
  final String? musculosPrimarios;
  final String? musculosSecundarios;
  final String? urlVideo;
  final String? urlFoto;
  final String? dificultad;
  final String? categoria;

  Ejercicio({
    required this.id,
    required this.titulo,
    this.descripcion,
    this.grupoMuscular,
    this.musculosPrimarios,
    this.musculosSecundarios,
    this.urlVideo,
    this.urlFoto,
    this.dificultad,
    this.categoria,
  });

  factory Ejercicio.fromJson(Map<String, dynamic> json) {
    return Ejercicio(
      id: json['id'] as String,
      titulo: json['titulo'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      grupoMuscular: json['grupo_muscular'] as String?,
      musculosPrimarios: json['musculos_primarios'] as String?,
      musculosSecundarios: json['musculos_secundarios'] as String?,
      urlVideo: json['url_video'] as String?,
      urlFoto: json['url_foto'] as String?,
      dificultad: json['dificultad'] as String?,
      categoria: json['categoria'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'titulo': titulo,
        'descripcion': descripcion,
        'grupo_muscular': grupoMuscular,
        'musculos_primarios': musculosPrimarios,
        'musculos_secundarios': musculosSecundarios,
        'url_video': urlVideo,
        'url_foto': urlFoto,
        'dificultad': dificultad,
        'categoria': categoria,
      };
}
