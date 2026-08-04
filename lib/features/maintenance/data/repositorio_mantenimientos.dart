import 'package:flutter/foundation.dart';

import '../../../core/database/database_helper.dart';
import '../models/entrada_historial.dart';
import '../models/mantenimiento.dart';

/// Repositorio con las operaciones CRUD sobre la tabla [mantenimientos].
class RepositorioMantenimientos {
  final DatabaseHelper _gestorBd;
  static const String _tabla = 'mantenimientos';

  RepositorioMantenimientos({DatabaseHelper? gestorBd})
      : _gestorBd = gestorBd ?? DatabaseHelper.instance;

  // ── INSERTAR ────────────────────────────────────────────────────────────────

  /// Inserta un nuevo [mantenimiento] y devuelve el ID generado.
  Future<int> insertarMantenimiento(Mantenimiento mantenimiento) async {
    debugPrint(
        '[RepositorioMantenimientos] insertarMantenimiento → '
        'citaId=${mantenimiento.citaId}, operario="${mantenimiento.operarioNombre}"');
    try {
      final db = await _gestorBd.database;
      final mapa = mantenimiento.toMap();
      final nuevoId = await db.insert(_tabla, mapa);
      debugPrint(
          '[RepositorioMantenimientos] ✓ Mantenimiento insertado con id=$nuevoId');
      return nuevoId;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMantenimientos] ✗ ERROR en insertarMantenimiento: $e\n$traza');
      rethrow;
    }
  }

  // ── CONSULTAR ───────────────────────────────────────────────────────────────

  /// Devuelve todos los mantenimientos vinculados a [citaId].
  Future<List<Mantenimiento>> obtenerMantenimientosPorCita(int citaId) async {
    debugPrint(
        '[RepositorioMantenimientos] obtenerMantenimientosPorCita → citaId=$citaId');
    try {
      final db = await _gestorBd.database;
      final filas = await db.query(
        _tabla,
        where: 'cita_id = ?',
        whereArgs: [citaId],
        orderBy: 'fecha_creacion DESC',
      );
      final lista = filas.map(Mantenimiento.fromMap).toList();
      debugPrint(
          '[RepositorioMantenimientos] ✓ ${lista.length} mantenimientos encontrados.');
      return lista;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMantenimientos] ✗ ERROR en obtenerMantenimientosPorCita: $e\n$traza');
      rethrow;
    }
  }

  /// Devuelve todos los mantenimientos, ordenados del más reciente al más antiguo.
  Future<List<Mantenimiento>> obtenerTodosLosMantenimientos() async {
    debugPrint('[RepositorioMantenimientos] obtenerTodosLosMantenimientos');
    try {
      final db = await _gestorBd.database;
      final filas =
          await db.query(_tabla, orderBy: 'fecha_creacion DESC');
      final lista = filas.map(Mantenimiento.fromMap).toList();
      debugPrint(
          '[RepositorioMantenimientos] ✓ ${lista.length} mantenimientos totales.');
      return lista;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMantenimientos] ✗ ERROR en obtenerTodosLosMantenimientos: $e\n$traza');
      rethrow;
    }
  }

  // ── ACTUALIZAR ──────────────────────────────────────────────────────────────

  /// Actualiza un mantenimiento existente. Devuelve el número de filas modificadas.
  Future<int> actualizarMantenimiento(Mantenimiento mantenimiento) async {
    debugPrint(
        '[RepositorioMantenimientos] actualizarMantenimiento → id=${mantenimiento.id}');
    try {
      final db = await _gestorBd.database;
      final filasModificadas = await db.update(
        _tabla,
        mantenimiento.toMap(),
        where: 'id = ?',
        whereArgs: [mantenimiento.id],
      );
      debugPrint(
          '[RepositorioMantenimientos] ✓ Filas modificadas: $filasModificadas');
      return filasModificadas;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMantenimientos] ✗ ERROR en actualizarMantenimiento: $e\n$traza');
      rethrow;
    }
  }

  // ── HISTORIAL (JOIN) ────────────────────────────────────────────────────────

  /// Devuelve todas las entradas del historial con datos de cita y cliente,
  /// ordenadas del más reciente al más antiguo.
  ///
  /// Ejecuta un JOIN de 3 tablas para evitar queries N+1 en la lista.
  Future<List<EntradaHistorial>> obtenerHistorial() async {
    debugPrint('[RepositorioMantenimientos] obtenerHistorial → JOIN 3 tablas');
    try {
      final db = await _gestorBd.database;
      final filas = await db.rawQuery('''
        SELECT
          m.id           AS m_id,
          m.cita_id,
          m.operario_nombre,
          m.detalles_trabajo,
          m.observaciones,
          m.firma_tecnico,
          m.firma_cliente,
          m.fecha_creacion,
          m.estado_instalacion,
          m.checklist_json,
          a.id           AS a_id,
          a.cliente_id,
          a.fecha_hora,
          a.identificacion,
          a.periodicidad,
          a.estado       AS a_estado,
          a.recurrencia_activa,
          a.es_guardia,
          a.maquina_id,
          c.nombre       AS nombre_cliente,
          c.ciudad_cp    AS ciudad_cliente
        FROM mantenimientos m
        JOIN appointments  a ON m.cita_id    = a.id
        JOIN clients       c ON a.cliente_id = c.id
        ORDER BY m.fecha_creacion DESC
      ''');
      final lista = filas.map(EntradaHistorial.fromJoinRow).toList();
      debugPrint(
          '[RepositorioMantenimientos] ✓ ${lista.length} entradas en historial.');
      return lista;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMantenimientos] ✗ ERROR en obtenerHistorial: $e\n$traza');
      rethrow;
    }
  }

  // ── ELIMINAR ────────────────────────────────────────────────────────────────

  /// Elimina el mantenimiento con [id]. Devuelve el número de filas eliminadas.
  Future<int> eliminarMantenimiento(int id) async {
    debugPrint('[RepositorioMantenimientos] eliminarMantenimiento → id=$id');
    try {
      final db = await _gestorBd.database;
      final filasEliminadas =
          await db.delete(_tabla, where: 'id = ?', whereArgs: [id]);
      debugPrint(
          '[RepositorioMantenimientos] ✓ Filas eliminadas: $filasEliminadas');
      return filasEliminadas;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMantenimientos] ✗ ERROR en eliminarMantenimiento: $e\n$traza');
      rethrow;
    }
  }
}
