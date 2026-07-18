/// Modelo que representa un parte de trabajo de mantenimiento.
///
/// Se vincula a una [Appointment] mediante [citaId].
/// Las firmas se almacenan como cadenas Base64 de una imagen PNG.
class Mantenimiento {
  final int? id;

  /// FK → appointments.id
  final int citaId;

  /// Nombre del operario que realizó el trabajo.
  final String operarioNombre;

  /// Descripción detallada del trabajo realizado.
  final String detallesTrabajo;

  /// Observaciones o anomalías detectadas durante la visita.
  final String observaciones;

  /// PNG de la firma del técnico codificado en Base64. Nullable si no firmó.
  final String? firmaTecnico;

  /// PNG de la firma del cliente codificado en Base64. Nullable si no firmó.
  final String? firmaCliente;

  /// Fecha y hora de creación del parte (hora local del dispositivo).
  final DateTime fechaCreacion;

  const Mantenimiento({
    this.id,
    required this.citaId,
    required this.operarioNombre,
    required this.detallesTrabajo,
    this.observaciones = '',
    this.firmaTecnico,
    this.firmaCliente,
    required this.fechaCreacion,
  });

  // ── SQLite ──────────────────────────────────────────────────────────────────

  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cita_id': citaId,
      'operario_nombre': operarioNombre,
      'detalles_trabajo': detallesTrabajo,
      'observaciones': observaciones,
      'firma_tecnico': firmaTecnico,
      'firma_cliente': firmaCliente,
      'fecha_creacion': fechaCreacion.toUtc().toIso8601String(),
    };
  }

  factory Mantenimiento.fromMap(Map<String, dynamic> map) {
    return Mantenimiento(
      id: map['id'] as int?,
      citaId: map['cita_id'] as int,
      operarioNombre: map['operario_nombre'] as String,
      detallesTrabajo: map['detalles_trabajo'] as String,
      observaciones: map['observaciones'] as String? ?? '',
      firmaTecnico: map['firma_tecnico'] as String?,
      firmaCliente: map['firma_cliente'] as String?,
      fechaCreacion:
          DateTime.parse(map['fecha_creacion'] as String).toLocal(),
    );
  }

  // ── Immutable copy ──────────────────────────────────────────────────────────

  Mantenimiento copyWith({
    int? id,
    int? citaId,
    String? operarioNombre,
    String? detallesTrabajo,
    String? observaciones,
    String? firmaTecnico,
    String? firmaCliente,
    DateTime? fechaCreacion,
  }) {
    return Mantenimiento(
      id: id ?? this.id,
      citaId: citaId ?? this.citaId,
      operarioNombre: operarioNombre ?? this.operarioNombre,
      detallesTrabajo: detallesTrabajo ?? this.detallesTrabajo,
      observaciones: observaciones ?? this.observaciones,
      firmaTecnico: firmaTecnico ?? this.firmaTecnico,
      firmaCliente: firmaCliente ?? this.firmaCliente,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
    );
  }

  @override
  String toString() =>
      'Mantenimiento(id: $id, citaId: $citaId, '
      'operario: $operarioNombre, fecha: $fechaCreacion)';
}
