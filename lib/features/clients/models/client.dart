/// Modelo que representa un cliente en la base de datos.
///
/// Convenciones de serialización:
/// - [toMap]   → para insertar/actualizar en SQLite.
/// - [fromMap] → para leer filas de SQLite.
/// - [toJson]  → para serialización JSON externa (p.ej. exportar).
/// - [fromJson]→ para deserializar desde JSON externo.
class Client {
  final int? id;
  final String nombre;
  final String? nifCif;
  final String direccion;
  final String ciudadCp;
  final String? coordenadas;

  const Client({
    this.id,
    required this.nombre,
    this.nifCif,
    required this.direccion,
    required this.ciudadCp,
    this.coordenadas,
  });

  // ── SQLite ──────────────────────────────────────────────────────────────────

  /// Convierte el modelo a un mapa listo para insertar en SQLite.
  /// Si [id] es null (registro nuevo), no se incluye para que SQLite
  /// genere el AUTOINCREMENT.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'nombre': nombre,
      'nif_cif': nifCif,
      'direccion': direccion,
      'ciudad_cp': ciudadCp,
      'coordenadas': coordenadas,
    };
  }

  /// Construye un [Client] a partir de una fila de SQLite.
  factory Client.fromMap(Map<String, dynamic> map) {
    return Client(
      id: map['id'] as int?,
      nombre: map['nombre'] as String,
      nifCif: map['nif_cif'] as String?,
      direccion: map['direccion'] as String,
      ciudadCp: map['ciudad_cp'] as String,
      coordenadas: map['coordenadas'] as String?,
    );
  }

  // ── JSON ────────────────────────────────────────────────────────────────────

  /// Serialización JSON (estructura idéntica a [toMap] en este modelo,
  /// ya que no hay tipos especiales como DateTime o Map).
  Map<String, dynamic> toJson() => toMap();

  factory Client.fromJson(Map<String, dynamic> json) => Client.fromMap(json);

  // ── Immutable copy ──────────────────────────────────────────────────────────

  /// Devuelve una copia del objeto con los campos indicados reemplazados.
  /// Los campos [nifCif] y [coordenadas] aceptan `null` explícito para
  /// poder limpiarlos. Usa el flag [clearNifCif] / [clearCoordenadas].
  Client copyWith({
    int? id,
    String? nombre,
    String? nifCif,
    bool clearNifCif = false,
    String? direccion,
    String? ciudadCp,
    String? coordenadas,
    bool clearCoordenadas = false,
  }) {
    return Client(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      nifCif: clearNifCif ? null : (nifCif ?? this.nifCif),
      direccion: direccion ?? this.direccion,
      ciudadCp: ciudadCp ?? this.ciudadCp,
      coordenadas: clearCoordenadas ? null : (coordenadas ?? this.coordenadas),
    );
  }

  @override
  String toString() =>
      'Client(id: $id, nombre: $nombre, nifCif: $nifCif, '
      'direccion: $direccion, ciudadCp: $ciudadCp)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Client && runtimeType == other.runtimeType && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
