import 'package:flutter/foundation.dart';

import '../../../core/database/database_helper.dart';
import '../models/appointment.dart';

/// Repositorio que encapsula todas las operaciones CRUD sobre la tabla [appointments].
///
/// Punto clave: las fechas se almacenan en UTC ISO 8601 en SQLite.
/// La comparación lexicográfica de cadenas ISO 8601 es equivalente
/// a la comparación temporal, lo que permite usar BETWEEN y >= / <.
class RepositorioCitas {
  final DatabaseHelper _gestorBd;
  static const String _tabla = 'appointments';

  RepositorioCitas({DatabaseHelper? gestorBd})
      : _gestorBd = gestorBd ?? DatabaseHelper.instance;

  // ── INSERTAR ────────────────────────────────────────────────────────────────

  /// Inserta una nueva [cita] y devuelve el ID generado.
  Future<int> insertarCita(Appointment cita) async {
    debugPrint(
        '[RepositorioCitas] insertarCita → cliente=${cita.clienteId}, '
        'fecha=${cita.fechaHora}, id="${cita.identificacion}"');
    try {
      final db = await _gestorBd.database;
      final mapa = cita.toMap();
      debugPrint('[RepositorioCitas] Datos enviados a BD: $mapa');
      final nuevoId = await db.insert(_tabla, mapa);
      debugPrint('[RepositorioCitas] ✓ Cita insertada con id=$nuevoId');
      return nuevoId;
    } catch (e, traza) {
      debugPrint('[RepositorioCitas] ✗ ERROR en insertarCita: $e\n$traza');
      rethrow;
    }
  }

  // ── CONSULTAR ───────────────────────────────────────────────────────────────

  /// Devuelve todas las citas del mes al que pertenece [mes].
  ///
  /// Filtra entre el primer y último instante del mes usando comparación
  /// de cadenas ISO 8601 (válido porque están en UTC estricto).
  /// Esto evita cargar toda la tabla en memoria al cambiar de mes.
  Future<List<Appointment>> obtenerCitasPorMes(DateTime mes) async {
    final primerDia = DateTime.utc(mes.year, mes.month, 1).toIso8601String();
    // Primer instante del mes siguiente (límite exclusivo)
    final primerDiaSiguiente =
        DateTime.utc(mes.year, mes.month + 1, 1).toIso8601String();

    debugPrint(
        '[RepositorioCitas] obtenerCitasPorMes → ${mes.year}-${mes.month} '
        '[$primerDia, $primerDiaSiguiente)');
    try {
      final db = await _gestorBd.database;
      final filas = await db.query(
        _tabla,
        where: 'fecha_hora >= ? AND fecha_hora < ?',
        whereArgs: [primerDia, primerDiaSiguiente],
        orderBy: 'fecha_hora ASC',
      );
      final citas = filas.map(Appointment.fromMap).toList();
      debugPrint('[RepositorioCitas] ✓ ${citas.length} citas encontradas.');
      return citas;
    } catch (e, traza) {
      debugPrint('[RepositorioCitas] ✗ ERROR en obtenerCitasPorMes: $e\n$traza');
      rethrow;
    }
  }

  /// Devuelve todas las citas de un [dia] concreto (sin importar la hora).
  Future<List<Appointment>> obtenerCitasPorDia(DateTime dia) async {
    final inicio = DateTime.utc(dia.year, dia.month, dia.day).toIso8601String();
    final fin =
        DateTime.utc(dia.year, dia.month, dia.day + 1).toIso8601String();

    debugPrint(
        '[RepositorioCitas] obtenerCitasPorDia → ${dia.year}-${dia.month}-${dia.day}');
    try {
      final db = await _gestorBd.database;
      final filas = await db.query(
        _tabla,
        where: 'fecha_hora >= ? AND fecha_hora < ?',
        whereArgs: [inicio, fin],
        orderBy: 'fecha_hora ASC',
      );
      final citas = filas.map(Appointment.fromMap).toList();
      debugPrint('[RepositorioCitas] ✓ ${citas.length} citas para ese día.');
      return citas;
    } catch (e, traza) {
      debugPrint('[RepositorioCitas] ✗ ERROR en obtenerCitasPorDia: $e\n$traza');
      rethrow;
    }
  }

  /// Devuelve TODAS las citas de la base de datos ordenadas por fecha ascendente.
  ///
  /// Necesario para la proyección de citas recurrentes en meses futuros/pasados.
  Future<List<Appointment>> obtenerTodasLasCitas() async {
    debugPrint('[RepositorioCitas] obtenerTodasLasCitas → cargando todas las citas');
    try {
      final db = await _gestorBd.database;
      final filas = await db.query(_tabla, orderBy: 'fecha_hora ASC');
      final citas = filas.map(Appointment.fromMap).toList();
      debugPrint('[RepositorioCitas] ✓ ${citas.length} citas totales cargadas.');
      return citas;
    } catch (e, traza) {
      debugPrint('[RepositorioCitas] ✗ ERROR en obtenerTodasLasCitas: $e\n$traza');
      rethrow;
    }
  }

  // ── ACTUALIZAR ──────────────────────────────────────────────────────────────

  /// Actualiza una cita existente. Devuelve el número de filas modificadas.
  Future<int> actualizarCita(Appointment cita) async {
    debugPrint(
        '[RepositorioCitas] actualizarCita → id=${cita.id}, estado="${cita.estado}"');
    try {
      final db = await _gestorBd.database;
      final mapa = cita.toMap();
      debugPrint('[RepositorioCitas] Datos a actualizar: $mapa');
      final filasModificadas = await db.update(
        _tabla,
        mapa,
        where: 'id = ?',
        whereArgs: [cita.id],
      );
      debugPrint('[RepositorioCitas] ✓ Filas modificadas: $filasModificadas');
      return filasModificadas;
    } catch (e, traza) {
      debugPrint('[RepositorioCitas] ✗ ERROR en actualizarCita: $e\n$traza');
      rethrow;
    }
  }

  // ── ELIMINAR ────────────────────────────────────────────────────────────────

  /// Elimina la cita con [id]. Devuelve el número de filas eliminadas.
  Future<int> eliminarCita(int id) async {
    debugPrint('[RepositorioCitas] eliminarCita → id=$id');
    try {
      final db = await _gestorBd.database;
      final filasEliminadas =
          await db.delete(_tabla, where: 'id = ?', whereArgs: [id]);
      debugPrint('[RepositorioCitas] ✓ Filas eliminadas: $filasEliminadas');
      return filasEliminadas;
    } catch (e, traza) {
      debugPrint('[RepositorioCitas] ✗ ERROR en eliminarCita: $e\n$traza');
      rethrow;
    }
  }
}
