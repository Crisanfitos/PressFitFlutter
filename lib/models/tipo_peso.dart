enum TipoPeso {
  total,
  porLado,
  corporal;

  String get dbValue {
    switch (this) {
      case TipoPeso.total:
        return 'total';
      case TipoPeso.porLado:
        return 'por_lado';
      case TipoPeso.corporal:
        return 'corporal';
    }
  }

  String get label {
    switch (this) {
      case TipoPeso.total:
        return 'Peso Total';
      case TipoPeso.porLado:
        return 'Por Lado';
      case TipoPeso.corporal:
        return 'Peso Corporal';
    }
  }

  String get shortLabel {
    switch (this) {
      case TipoPeso.total:
        return 'KG';
      case TipoPeso.porLado:
        return 'KG/lado';
      case TipoPeso.corporal:
        return 'BW';
    }
  }

  static TipoPeso fromString(String? value) {
    switch (value) {
      case 'por_lado':
        return TipoPeso.porLado;
      case 'corporal':
        return TipoPeso.corporal;
      default:
        return TipoPeso.total;
    }
  }
}
