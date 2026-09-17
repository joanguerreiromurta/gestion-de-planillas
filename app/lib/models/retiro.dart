class Retiro {
  final String id;
  final DateTime fecha;
  final String chofer;
  final String generador;
  final String direccion;
  final double litros;
  final double importe;
  final bool sincronizado;

  const Retiro({
    required this.id,
    required this.fecha,
    required this.chofer,
    required this.generador,
    required this.direccion,
    required this.litros,
    required this.importe,
    this.sincronizado = false,
  });

  Retiro copyWith({bool? sincronizado}) {
    return Retiro(
      id: id,
      fecha: fecha,
      chofer: chofer,
      generador: generador,
      direccion: direccion,
      litros: litros,
      importe: importe,
      sincronizado: sincronizado ?? this.sincronizado,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'chofer': chofer,
      'generador': generador,
      'direccion': direccion,
      'litros': litros,
      'importe': importe,
      'sincronizado': sincronizado ? 1 : 0,
    };
  }

  factory Retiro.fromDbMap(Map<String, Object?> map) {
    return Retiro(
      id: map['id'] as String,
      fecha: DateTime.parse(map['fecha'] as String),
      chofer: map['chofer'] as String,
      generador: map['generador'] as String,
      direccion: map['direccion'] as String,
      litros: (map['litros'] as num).toDouble(),
      importe: (map['importe'] as num).toDouble(),
      sincronizado: (map['sincronizado'] as int) == 1,
    );
  }

  Map<String, Object?> toSyncPayload() {
    return {
      'id': id,
      'fecha': fecha.toIso8601String(),
      'chofer': chofer,
      'generador': generador,
      'direccion': direccion,
      'litros': litros,
      'importe': importe,
    };
  }
}
