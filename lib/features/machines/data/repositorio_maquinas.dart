import 'package:flutter/foundation.dart';

import '../../../core/database/database_helper.dart';
import '../models/maquina.dart';

/// Repositorio con las operaciones CRUD sobre la tabla [machines].
class RepositorioMaquinas {
  final DatabaseHelper _gestorBd;
  static const String _tabla = 'machines';

  RepositorioMaquinas({DatabaseHelper? gestorBd})
      : _gestorBd = gestorBd ?? DatabaseHelper.instance;

  // ── INSERTAR ────────────────────────────────────────────────────────────────

  /// Inserta una nueva [maquina] y devuelve el ID generado.
  Future<int> insertarMaquina(Maquina maquina) async {
    debugPrint(
        '[RepositorioMaquinas] insertarMaquina → '
        'clienteId=${maquina.clienteId}, ref="${maquina.nombreReferencia}"');
    try {
      final db = await _gestorBd.database;
      final nuevoId = await db.insert(_tabla, maquina.toMap());
      debugPrint('[RepositorioMaquinas] ✓ Máquina insertada con id=$nuevoId');
      return nuevoId;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMaquinas] ✗ ERROR en insertarMaquina: $e\n$traza');
      rethrow;
    }
  }

  // ── CONSULTAR ───────────────────────────────────────────────────────────────

  /// Devuelve todas las máquinas asociadas a [clienteId], ordenadas por nombre.
  Future<List<Maquina>> obtenerMaquinasPorCliente(int clienteId) async {
    debugPrint(
        '[RepositorioMaquinas] obtenerMaquinasPorCliente → clienteId=$clienteId');
    try {
      final db = await _gestorBd.database;
      final filas = await db.query(
        _tabla,
        where: 'cliente_id = ?',
        whereArgs: [clienteId],
        orderBy: 'nombre_referencia ASC',
      );
      final lista = filas.map(Maquina.fromMap).toList();
      debugPrint(
          '[RepositorioMaquinas] ✓ ${lista.length} máquinas encontradas.');
      return lista;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMaquinas] ✗ ERROR en obtenerMaquinasPorCliente: $e\n$traza');
      rethrow;
    }
  }

  /// Devuelve la máquina con [id], o null si no existe.
  Future<Maquina?> obtenerMaquina(int id) async {
    debugPrint('[RepositorioMaquinas] obtenerMaquina → id=$id');
    try {
      final db = await _gestorBd.database;
      final filas = await db.query(_tabla, where: 'id = ?', whereArgs: [id]);
      if (filas.isEmpty) return null;
      return Maquina.fromMap(filas.first);
    } catch (e, traza) {
      debugPrint('[RepositorioMaquinas] ✗ ERROR en obtenerMaquina: $e\n$traza');
      rethrow;
    }
  }

  // ── ACTUALIZAR ──────────────────────────────────────────────────────────────

  /// Actualiza una máquina existente. Devuelve el número de filas modificadas.
  Future<int> actualizarMaquina(Maquina maquina) async {
    debugPrint('[RepositorioMaquinas] actualizarMaquina → id=${maquina.id}');
    try {
      final db = await _gestorBd.database;
      final filas = await db.update(
        _tabla,
        maquina.toMap(),
        where: 'id = ?',
        whereArgs: [maquina.id],
      );
      debugPrint('[RepositorioMaquinas] ✓ Filas modificadas: $filas');
      return filas;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMaquinas] ✗ ERROR en actualizarMaquina: $e\n$traza');
      rethrow;
    }
  }

  // ── ELIMINAR ────────────────────────────────────────────────────────────────

  /// Elimina la máquina con [id]. Devuelve el número de filas eliminadas.
  Future<int> eliminarMaquina(int id) async {
    debugPrint('[RepositorioMaquinas] eliminarMaquina → id=$id');
    try {
      final db = await _gestorBd.database;
      final filas =
          await db.delete(_tabla, where: 'id = ?', whereArgs: [id]);
      debugPrint('[RepositorioMaquinas] ✓ Filas eliminadas: $filas');
      return filas;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMaquinas] ✗ ERROR en eliminarMaquina: $e\n$traza');
      rethrow;
    }
  }
}
