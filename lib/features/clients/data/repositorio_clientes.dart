import 'package:flutter/foundation.dart';

import '../../../core/database/database_helper.dart';
import '../models/client.dart';

/// Repositorio que encapsula todas las operaciones CRUD sobre la tabla [clients].
///
/// Este repositorio es la única clase que toca directamente la base de datos
/// para el módulo de clientes. El resto de la app interactúa con él a través
/// del [GestorClientes] (Riverpod).
class RepositorioClientes {
  final DatabaseHelper _gestorBd;

  /// Permite inyectar un [DatabaseHelper] personalizado (útil en tests).
  RepositorioClientes({DatabaseHelper? gestorBd})
      : _gestorBd = gestorBd ?? DatabaseHelper.instance;

  static const String _tabla = 'clients';

  // ── INSERTAR ────────────────────────────────────────────────────────────────

  /// Inserta un [cliente] nuevo en la BD y devuelve el ID generado.
  /// Lanza una excepción si la operación falla.
  Future<int> insertarCliente(Client cliente) async {
    debugPrint(
        '[RepositorioClientes] insertarCliente → nombre: "${cliente.nombre}"');
    try {
      final db = await _gestorBd.database;
      final mapa = cliente.toMap();
      debugPrint('[RepositorioClientes] Datos enviados a BD: $mapa');

      final nuevoId = await db.insert(_tabla, mapa);
      debugPrint('[RepositorioClientes] ✓ Cliente insertado con id=$nuevoId');
      return nuevoId;
    } catch (e, traza) {
      debugPrint('[RepositorioClientes] ✗ ERROR en insertarCliente: $e\n$traza');
      rethrow;
    }
  }

  // ── CONSULTAR ───────────────────────────────────────────────────────────────

  /// Devuelve la lista completa de clientes ordenados por nombre (A→Z).
  Future<List<Client>> obtenerClientes() async {
    debugPrint('[RepositorioClientes] obtenerClientes → consultando BD...');
    try {
      final db = await _gestorBd.database;
      final filas = await db.query(_tabla, orderBy: 'nombre ASC');
      final clientes = filas.map(Client.fromMap).toList();
      debugPrint(
          '[RepositorioClientes] ✓ Obtenidos ${clientes.length} clientes.');
      return clientes;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioClientes] ✗ ERROR en obtenerClientes: $e\n$traza');
      rethrow;
    }
  }

  /// Devuelve un único [Client] por su [id], o null si no existe.
  Future<Client?> obtenerClientePorId(int id) async {
    debugPrint('[RepositorioClientes] obtenerClientePorId → id=$id');
    try {
      final db = await _gestorBd.database;
      final filas =
          await db.query(_tabla, where: 'id = ?', whereArgs: [id], limit: 1);

      if (filas.isEmpty) {
        debugPrint(
            '[RepositorioClientes] ⚠ No se encontró cliente con id=$id');
        return null;
      }
      final cliente = Client.fromMap(filas.first);
      debugPrint(
          '[RepositorioClientes] ✓ Cliente encontrado: "${cliente.nombre}"');
      return cliente;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioClientes] ✗ ERROR en obtenerClientePorId: $e\n$traza');
      rethrow;
    }
  }

  // ── ACTUALIZAR ──────────────────────────────────────────────────────────────

  /// Actualiza los datos de un [cliente] existente.
  /// Devuelve el número de filas modificadas (debería ser 1).
  Future<int> actualizarCliente(Client cliente) async {
    debugPrint(
        '[RepositorioClientes] actualizarCliente → id=${cliente.id}, nombre="${cliente.nombre}"');
    try {
      final db = await _gestorBd.database;
      final mapa = cliente.toMap();
      debugPrint('[RepositorioClientes] Datos a actualizar: $mapa');

      final filasModificadas = await db.update(
        _tabla,
        mapa,
        where: 'id = ?',
        whereArgs: [cliente.id],
      );
      debugPrint(
          '[RepositorioClientes] ✓ Filas modificadas: $filasModificadas');
      return filasModificadas;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioClientes] ✗ ERROR en actualizarCliente: $e\n$traza');
      rethrow;
    }
  }

  // ── ELIMINAR ────────────────────────────────────────────────────────────────

  /// Elimina el cliente con el [id] dado.
  /// Gracias a ON DELETE CASCADE, también se borran sus citas y fichas.
  /// Devuelve el número de filas eliminadas.
  Future<int> eliminarCliente(int id) async {
    debugPrint('[RepositorioClientes] eliminarCliente → id=$id');
    try {
      final db = await _gestorBd.database;
      final filasEliminadas =
          await db.delete(_tabla, where: 'id = ?', whereArgs: [id]);
      debugPrint(
          '[RepositorioClientes] ✓ Filas eliminadas: $filasEliminadas');
      return filasEliminadas;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioClientes] ✗ ERROR en eliminarCliente: $e\n$traza');
      rethrow;
    }
  }

  // ── BUSCAR ──────────────────────────────────────────────────────────────────

  /// Busca clientes cuyo nombre o ciudad_cp contengan el texto [consulta].
  /// La comparación es insensible a mayúsculas gracias a LOWER().
  Future<List<Client>> buscarClientes(String consulta) async {
    debugPrint(
        '[RepositorioClientes] buscarClientes → consulta: "$consulta"');
    try {
      final db = await _gestorBd.database;
      final patron = '%${consulta.toLowerCase()}%';
      final filas = await db.query(
        _tabla,
        where: 'LOWER(nombre) LIKE ? OR LOWER(ciudad_cp) LIKE ?',
        whereArgs: [patron, patron],
        orderBy: 'nombre ASC',
      );
      final clientes = filas.map(Client.fromMap).toList();
      debugPrint(
          '[RepositorioClientes] ✓ Encontrados ${clientes.length} resultados para "$consulta".');
      return clientes;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioClientes] ✗ ERROR en buscarClientes: $e\n$traza');
      rethrow;
    }
  }
}
