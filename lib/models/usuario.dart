class Usuario {
  final String id;
  final String email;
  final String? nombre;
  final String? apellidos;
  final double? peso;
  final double? altura; // stored in meters in DB, converted to cm in app
  final double? imc;
  final double? grasaCorporal;
  final String? urlFoto;
  final DateTime? updatedAt;

  Usuario({
    required this.id,
    required this.email,
    this.nombre,
    this.apellidos,
    this.peso,
    this.altura,
    this.imc,
    this.grasaCorporal,
    this.urlFoto,
    this.updatedAt,
  });

  factory Usuario.fromJson(Map<String, dynamic> json) {
    final alturaRaw = json['altura'] as num?;
    return Usuario(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      nombre: json['nombre'] as String?,
      apellidos: json['apellidos'] as String?,
      peso: (json['peso'] as num?)?.toDouble(),
      altura: alturaRaw != null ? alturaRaw.toDouble() * 100 : null, // m -> cm
      imc: (json['imc'] as num?)?.toDouble(),
      grasaCorporal: (json['grasa_corporal'] as num?)?.toDouble(),
      urlFoto: json['url_foto'] as String?,
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'email': email,
        'nombre': nombre,
        'apellidos': apellidos,
        'peso': peso,
        'altura': altura != null ? altura! / 100 : null, // cm -> m
        'imc': imc,
        'grasa_corporal': grasaCorporal,
        'url_foto': urlFoto,
      };
}
