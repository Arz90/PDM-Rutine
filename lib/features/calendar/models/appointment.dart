// Centinela para distinguir "no pasado" de "null explícito" en copyWith.
const Object _sentinel = Object();

/// Modelo que representa una cita / aviso de mantenimiento.
///
/// [fechaHora] se almacena como String ISO 8601 en SQLite y se
/// convierte a/desde [DateTime] automáticamente en [toMap]/[fromMap].
class Appointment {
  final int? id;

  /// FK → clients.id
  final int clienteId;

  /// Fecha y hora de la cita (almacenada en UTC ISO 8601 en SQLite).
  final DateTime fechaHora;

  /// Identificación o código del aviso (ej. "AV-2025-001").
  final String identificacion;

  /// Frecuencia del mantenimiento: "Mensual", "Trimestral", "Anual", etc.
  final String periodicidad;

  /// Estado actual: "Pendiente" | "Completada" | "Cancelada".
  final String estado;

  /// Si es false, el proveedor no proyecta ocurrencias futuras de esta cita.
  /// Permite "cerrar" una serie recurrente sin eliminarla.
  final bool recurrenciaActiva;

  /// Si es true, la cita es un servicio de guardia / fuera de horario habitual.
  final bool esGuardia;

  /// FK → machines.id (opcional). Vincula la cita a una instalación concreta.
  final int? maquinaId;

  const Appointment({
    this.id,
    required this.clienteId,
    required this.fechaHora,
    required this.identificacion,
    required this.periodicidad,
    required this.estado,
    this.recurrenciaActiva = true,
    this.esGuardia = false,
    this.maquinaId,
  });

  // ── SQLite ──────────────────────────────────────────────────────────────────

  /// Convierte el modelo a mapa para SQLite.
  /// [fechaHora] se guarda en formato ISO 8601 (UTC) como TEXT.
  Map<String, dynamic> toMap() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'fecha_hora': fechaHora.toUtc().toIso8601String(),
      'identificacion': identificacion,
      'periodicidad': periodicidad,
      'estado': estado,
      'recurrencia_activa': recurrenciaActiva ? 1 : 0,
      'es_guardia': esGuardia ? 1 : 0,
      if (maquinaId != null) 'maquina_id': maquinaId,
    };
  }

  /// Construye un [Appointment] desde una fila de SQLite.
  /// Parsea la cadena ISO 8601 y la convierte a hora local del dispositivo.
  factory Appointment.fromMap(Map<String, dynamic> map) {
    return Appointment(
      id: map['id'] as int?,
      clienteId: map['cliente_id'] as int,
      fechaHora: DateTime.parse(map['fecha_hora'] as String).toLocal(),
      identificacion: map['identificacion'] as String,
      periodicidad: map['periodicidad'] as String,
      estado: map['estado'] as String,
      // El ?? maneja registros anteriores a la migración v2 (SQLite devuelve null)
      recurrenciaActiva: (map['recurrencia_activa'] as int? ?? 1) == 1,
      esGuardia: (map['es_guardia'] as int? ?? 0) == 1,
      maquinaId: map['maquina_id'] as int?,
    );
  }

  // ── JSON ────────────────────────────────────────────────────────────────────

  /// Serialización JSON. [fechaHora] se incluye como String ISO 8601.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'cliente_id': clienteId,
      'fecha_hora': fechaHora.toUtc().toIso8601String(),
      'identificacion': identificacion,
      'periodicidad': periodicidad,
      'estado': estado,
      'recurrencia_activa': recurrenciaActiva,
      'es_guardia': esGuardia,
    };
  }

  factory Appointment.fromJson(Map<String, dynamic> json) =>
      Appointment.fromMap(json);

  // ── Immutable copy ──────────────────────────────────────────────────────────

  Appointment copyWith({
    int? id,
    int? clienteId,
    DateTime? fechaHora,
    String? identificacion,
    String? periodicidad,
    String? estado,
    bool? recurrenciaActiva,
    bool? esGuardia,
    Object? maquinaId = _sentinel,
  }) {
    return Appointment(
      id: id ?? this.id,
      clienteId: clienteId ?? this.clienteId,
      fechaHora: fechaHora ?? this.fechaHora,
      identificacion: identificacion ?? this.identificacion,
      periodicidad: periodicidad ?? this.periodicidad,
      estado: estado ?? this.estado,
      recurrenciaActiva: recurrenciaActiva ?? this.recurrenciaActiva,
      esGuardia: esGuardia ?? this.esGuardia,
      maquinaId: identical(maquinaId, _sentinel) ? this.maquinaId : maquinaId as int?,
    );
  }

  @override
  String toString() =>
      'Appointment(id: $id, clienteId: $clienteId, '
      'fechaHora: $fechaHora, estado: $estado)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Appointment &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
