/// Modelo que representa una máquina o instalación vinculada a un cliente.
///
/// Se usa para pre-rellenar datos en el parte de mantenimiento
/// y para asociar citas a una instalación concreta.
class Maquina {
  final int? id;

  /// FK → clients.id
  final int clienteId;

  /// Nombre de referencia de la instalación (ej. "Barrera de acceso nave 3").
  final String nombreReferencia;

  /// Tipo de puerta o instalación (ej. "Seccional", "Basculante", "Barrera").
  final String tipoPuerta;

  /// Nombre del fabricante del equipo.
  final String fabricante;

  /// Referencia del modelo comercial.
  final String modelo;

  /// Número de serie del equipo.
  final String serie;

  const Maquina({
    this.id,
    required this.clienteId,
    required this.nombreReferencia,
    this.tipoPuerta = '',
    this.fabricante = '',
    this.modelo = '',
    this.serie = '',
  });

  // ── SQLite ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'cliente_id': clienteId,
        'nombre_referencia': nombreReferencia,
        'tipo_puerta': tipoPuerta,
        'fabricante': fabricante,
        'modelo': modelo,
        'serie': serie,
      };

  factory Maquina.fromMap(Map<String, dynamic> map) => Maquina(
        id: map['id'] as int?,
        clienteId: map['cliente_id'] as int,
        nombreReferencia: map['nombre_referencia'] as String,
        tipoPuerta: map['tipo_puerta'] as String? ?? '',
        fabricante: map['fabricante'] as String? ?? '',
        modelo: map['modelo'] as String? ?? '',
        serie: map['serie'] as String? ?? '',
      );

  // ── Immutable copy ──────────────────────────────────────────────────────────

  Maquina copyWith({
    int? id,
    int? clienteId,
    String? nombreReferencia,
    String? tipoPuerta,
    String? fabricante,
    String? modelo,
    String? serie,
  }) =>
      Maquina(
        id: id ?? this.id,
        clienteId: clienteId ?? this.clienteId,
        nombreReferencia: nombreReferencia ?? this.nombreReferencia,
        tipoPuerta: tipoPuerta ?? this.tipoPuerta,
        fabricante: fabricante ?? this.fabricante,
        modelo: modelo ?? this.modelo,
        serie: serie ?? this.serie,
      );

  @override
  String toString() =>
      'Maquina(id: $id, ref: "$nombreReferencia", tipo: "$tipoPuerta")';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Maquina && id == other.id;

  @override
  int get hashCode => id.hashCode;
}
