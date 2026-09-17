class Cliente {
  final String nombre;
  final String direccion;
  final String telefono;

  const Cliente({
    required this.nombre,
    required this.direccion,
    required this.telefono,
  });

  factory Cliente.fromJson(Map<String, dynamic> json) {
    return Cliente(
      nombre: json['nombre'] as String,
      direccion: json['direccion'] as String,
      telefono: (json['telefono'] as String?) ?? '',
    );
  }

  factory Cliente.fromDbMap(Map<String, Object?> map) {
    return Cliente(
      nombre: map['nombre'] as String,
      direccion: map['direccion'] as String,
      telefono: map['telefono'] as String? ?? '',
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'nombre': nombre,
      'direccion': direccion,
      'telefono': telefono,
    };
  }
}
