import '../../calendar/models/appointment.dart';
import 'mantenimiento.dart';

/// DTO que combina un [Mantenimiento] con los datos de su [Appointment]
/// y del cliente, resultado de un JOIN de 3 tablas.
///
/// Se usa exclusivamente en el historial (Tab 2) para evitar N+1 queries.
class EntradaHistorial {
  final Mantenimiento mantenimiento;
  final Appointment cita;
  final String nombreCliente;
  final String ciudadCliente;

  const EntradaHistorial({
    required this.mantenimiento,
    required this.cita,
    required this.nombreCliente,
    required this.ciudadCliente,
  });

  /// Construye una [EntradaHistorial] desde una fila del JOIN SQL.
  ///
  /// Las columnas de mantenimientos llevan prefijo [m_], las de appointments
  /// llevan prefijo [a_], para evitar colisiones de nombres en el JOIN.
  factory EntradaHistorial.fromJoinRow(Map<String, dynamic> fila) {
    final mantenimiento = Mantenimiento(
      id: fila['m_id'] as int?,
      citaId: fila['cita_id'] as int,
      operarioNombre: fila['operario_nombre'] as String,
      detallesTrabajo: fila['detalles_trabajo'] as String,
      observaciones: fila['observaciones'] as String? ?? '',
      firmaTecnico: fila['firma_tecnico'] as String?,
      firmaCliente: fila['firma_cliente'] as String?,
      fechaCreacion:
          DateTime.parse(fila['fecha_creacion'] as String).toLocal(),
      estadoInstalacion: fila['estado_instalacion'] as String? ?? '',
      checklistJson: fila['checklist_json'] as String? ?? '{}',
    );

    final cita = Appointment(
      id: fila['a_id'] as int?,
      clienteId: fila['cliente_id'] as int,
      fechaHora: DateTime.parse(fila['fecha_hora'] as String).toLocal(),
      identificacion: fila['identificacion'] as String,
      periodicidad: fila['periodicidad'] as String,
      estado: fila['a_estado'] as String,
      recurrenciaActiva: (fila['recurrencia_activa'] as int? ?? 1) == 1,
      esGuardia: (fila['es_guardia'] as int? ?? 0) == 1,
      maquinaId: fila['maquina_id'] as int?,
    );

    return EntradaHistorial(
      mantenimiento: mantenimiento,
      cita: cita,
      nombreCliente: fila['nombre_cliente'] as String,
      ciudadCliente: fila['ciudad_cliente'] as String,
    );
  }
}
