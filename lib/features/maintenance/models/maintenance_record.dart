import 'dart:convert';

/// Modelo que representa una ficha de mantenimiento completada.
///
/// Punto clave de serialización:
/// - [datosInspeccion] es un [Map<String, dynamic>] en Dart.
/// - En SQLite se guarda como TEXT usando [jsonEncode] / [jsonDecode].
/// - En JSON externo permanece como Map (no se re-stringifica).
///
/// [firmaOperario] almacena la ruta local de la imagen de firma (no Base64).
class MaintenanceRecord {
  final int? id;

  /// FK → appointments.id
  final int citaId;

  /// Tipo de puerta / instalación intervenida (ej. "Seccional", "Rápida").
  final String tipoPuerta;

  final String? marcaMotor;
  final String? modeloMotor;

  /// Campos de inspección dinámicos (checklist, mediciones, etc.).
  /// Se guarda serializado como JSON en SQLite.
  final Map<String, dynamic> datosInspeccion;

  final String? observaciones;
  final String? accionesCorrectivas;
  final String? incidencias;

  /// Estado general de la instalación: "Correcto" | "Deficiente" | "Peligroso".
  final String estadoInstalacion;

  /// Ruta local del archivo de imagen con la firma del operario.
  final String? firmaOperario;

  const MaintenanceRecord({
    this.id,
    required this.citaId,
    required this.tipoPuerta,
    this.marcaMotor,
    this.modeloMotor,
    required this.datosInspeccion,
    this.observaciones,
    this.accionesCorrectivas,
    this.incidencias,
    required this.estadoInstalacion,
    this.firmaOperario,
  });

  // ── SQLite ──────────────────────────────────────────────────────────────────

  /// Convierte el modelo a mapa para SQLite.
  /// [datosInspeccion] se serializa a JSON String con [jsonEncode].
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cita_id': citaId,
      'tipo_puerta': tipoPuerta,
      'marca_motor': marcaMotor,
      'modelo_motor': modeloMotor,
      'datos_inspeccion': jsonEncode(datosInspeccion),
      'observaciones': observaciones,
      'acciones_correctivas': accionesCorrectivas,
      'incidencias': incidencias,
      'estado_instalacion': estadoInstalacion,
      'firma_operario': firmaOperario,
    };
  }

  /// Construye un [MaintenanceRecord] desde una fila de SQLite.
  /// [datosInspeccion] se deserializa desde JSON String con [jsonDecode].
  factory MaintenanceRecord.fromMap(Map<String, dynamic> map) {
    return MaintenanceRecord(
      id: map['id'] as int?,
      citaId: map['cita_id'] as int,
      tipoPuerta: map['tipo_puerta'] as String,
      marcaMotor: map['marca_motor'] as String?,
      modeloMotor: map['modelo_motor'] as String?,
      datosInspeccion:
          jsonDecode(map['datos_inspeccion'] as String) as Map<String, dynamic>,
      observaciones: map['observaciones'] as String?,
      accionesCorrectivas: map['acciones_correctivas'] as String?,
      incidencias: map['incidencias'] as String?,
      estadoInstalacion: map['estado_instalacion'] as String,
      firmaOperario: map['firma_operario'] as String?,
    );
  }

  // ── JSON ────────────────────────────────────────────────────────────────────

  /// Serialización JSON. [datosInspeccion] permanece como Map (no se stringifica),
  /// ya que en JSON ya es un tipo nativo.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'cita_id': citaId,
      'tipo_puerta': tipoPuerta,
      'marca_motor': marcaMotor,
      'modelo_motor': modeloMotor,
      'datos_inspeccion': datosInspeccion,
      'observaciones': observaciones,
      'acciones_correctivas': accionesCorrectivas,
      'incidencias': incidencias,
      'estado_instalacion': estadoInstalacion,
      'firma_operario': firmaOperario,
    };
  }

  /// Construye desde JSON externo. [datosInspeccion] ya viene como Map.
  factory MaintenanceRecord.fromJson(Map<String, dynamic> json) {
    return MaintenanceRecord(
      id: json['id'] as int?,
      citaId: json['cita_id'] as int,
      tipoPuerta: json['tipo_puerta'] as String,
      marcaMotor: json['marca_motor'] as String?,
      modeloMotor: json['modelo_motor'] as String?,
      datosInspeccion: json['datos_inspeccion'] as Map<String, dynamic>,
      observaciones: json['observaciones'] as String?,
      accionesCorrectivas: json['acciones_correctivas'] as String?,
      incidencias: json['incidencias'] as String?,
      estadoInstalacion: json['estado_instalacion'] as String,
      firmaOperario: json['firma_operario'] as String?,
    );
  }

  // ── Immutable copy ──────────────────────────────────────────────────────────

  MaintenanceRecord copyWith({
    int? id,
    int? citaId,
    String? tipoPuerta,
    String? marcaMotor,
    bool clearMarcaMotor = false,
    String? modeloMotor,
    bool clearModeloMotor = false,
    Map<String, dynamic>? datosInspeccion,
    String? observaciones,
    bool clearObservaciones = false,
    String? accionesCorrectivas,
    bool clearAccionesCorrectivas = false,
    String? incidencias,
    bool clearIncidencias = false,
    String? estadoInstalacion,
    String? firmaOperario,
    bool clearFirmaOperario = false,
  }) {
    return MaintenanceRecord(
      id: id ?? this.id,
      citaId: citaId ?? this.citaId,
      tipoPuerta: tipoPuerta ?? this.tipoPuerta,
      marcaMotor: clearMarcaMotor ? null : (marcaMotor ?? this.marcaMotor),
      modeloMotor: clearModeloMotor ? null : (modeloMotor ?? this.modeloMotor),
      datosInspeccion: datosInspeccion ?? this.datosInspeccion,
      observaciones:
          clearObservaciones ? null : (observaciones ?? this.observaciones),
      accionesCorrectivas: clearAccionesCorrectivas
          ? null
          : (accionesCorrectivas ?? this.accionesCorrectivas),
      incidencias: clearIncidencias ? null : (incidencias ?? this.incidencias),
      estadoInstalacion: estadoInstalacion ?? this.estadoInstalacion,
      firmaOperario:
          clearFirmaOperario ? null : (firmaOperario ?? this.firmaOperario),
    );
  }

  @override
  String toString() =>
      'MaintenanceRecord(id: $id, citaId: $citaId, '
      'tipoPuerta: $tipoPuerta, estado: $estadoInstalacion)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MaintenanceRecord &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
