import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositorio_clientes.dart';
import '../models/client.dart';

// ── Provider del repositorio ──────────────────────────────────────────────────

/// Instancia única del [RepositorioClientes] accesible en toda la app.
/// Se puede sobreescribir en tests con [ProviderScope(overrides: [...])].
final repositorioClientesProvider = Provider<RepositorioClientes>(
  (ref) => RepositorioClientes(),
  name: 'repositorioClientesProvider',
);

// ── Provider del texto de búsqueda ────────────────────────────────────────────

/// Almacena el texto que el usuario escribe en el campo de búsqueda.
/// Cuando cambia, [clientesFiltradosProvider] se recalcula automáticamente.
final textoBusquedaClientesProvider = StateProvider<String>(
  (ref) => '',
  name: 'textoBusquedaClientesProvider',
);

// ── Notifier principal ────────────────────────────────────────────────────────

/// Gestiona el estado asíncrono de la lista de clientes.
///
/// Flujo:
/// 1. Al crearse ([build]), carga todos los clientes desde la BD.
/// 2. Las operaciones CRUD actualizan el estado y recargan la lista.
/// 3. Los estados posibles son: [AsyncLoading], [AsyncData], [AsyncError].
class GestorClientes extends AsyncNotifier<List<Client>> {
  late RepositorioClientes _repositorio;

  @override
  Future<List<Client>> build() async {
    _repositorio = ref.read(repositorioClientesProvider);
    return _recargarClientes();
  }

  /// Consulta la BD y devuelve la lista actualizada.
  Future<List<Client>> _recargarClientes() async {
    debugPrint('[GestorClientes] Estado → CARGANDO...');
    final clientes = await _repositorio.obtenerClientes();
    debugPrint(
        '[GestorClientes] Estado → ÉXITO. ${clientes.length} clientes en memoria.');
    return clientes;
  }

  // ── Operaciones públicas ──────────────────────────────────────────────────

  /// Añade un nuevo [cliente] y refresca el estado.
  Future<void> agregarCliente(Client cliente) async {
    debugPrint(
        '[GestorClientes] agregarCliente → "${cliente.nombre}" | Estado → CARGANDO');
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _repositorio.insertarCliente(cliente);
      final actualizados = await _recargarClientes();
      debugPrint(
          '[GestorClientes] agregarCliente → Estado → ÉXITO. Total: ${actualizados.length}');
      return actualizados;
    });

    if (state.hasError) {
      debugPrint(
          '[GestorClientes] agregarCliente → Estado → ERROR: ${state.error}');
    }
  }

  /// Actualiza un [cliente] existente y refresca el estado.
  Future<void> modificarCliente(Client cliente) async {
    debugPrint(
        '[GestorClientes] modificarCliente → id=${cliente.id} | Estado → CARGANDO');
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _repositorio.actualizarCliente(cliente);
      final actualizados = await _recargarClientes();
      debugPrint('[GestorClientes] modificarCliente → Estado → ÉXITO.');
      return actualizados;
    });

    if (state.hasError) {
      debugPrint(
          '[GestorClientes] modificarCliente → Estado → ERROR: ${state.error}');
    }
  }

  /// Añade [cliente] al estado en memoria sin releer la BD.
  ///
  /// Usado para actualización optimista tras una inserción directa desde otro
  /// formulario (p.ej. creación rápida en [PantallaFormularioCita]).
  /// Asume que [cliente] ya tiene el [id] asignado por la BD.
  void agregarClienteLocalmente(Client cliente) {
    debugPrint(
        '[GestorClientes] agregarClienteLocalmente → "${cliente.nombre}" (id=${cliente.id})');
    final listaActual = state.valueOrNull ?? [];
    state = AsyncValue.data([...listaActual, cliente]);
    debugPrint(
        '[GestorClientes] ✓ Cliente añadido localmente. Total: ${listaActual.length + 1}');
  }

  /// Elimina el cliente con [id] y refresca el estado.
  Future<void> eliminarCliente(int id) async {
    debugPrint(
        '[GestorClientes] eliminarCliente → id=$id | Estado → CARGANDO');
    state = const AsyncValue.loading();

    state = await AsyncValue.guard(() async {
      await _repositorio.eliminarCliente(id);
      final actualizados = await _recargarClientes();
      debugPrint(
          '[GestorClientes] eliminarCliente → Estado → ÉXITO. Restantes: ${actualizados.length}');
      return actualizados;
    });

    if (state.hasError) {
      debugPrint(
          '[GestorClientes] eliminarCliente → Estado → ERROR: ${state.error}');
    }
  }
}

/// Provider principal del módulo. Expone el [GestorClientes] y su estado.
final gestorClientesProvider =
    AsyncNotifierProvider<GestorClientes, List<Client>>(
  GestorClientes.new,
  name: 'gestorClientesProvider',
);

// ── Provider derivado: lista filtrada ─────────────────────────────────────────

/// Devuelve la lista de clientes filtrada según [textoBusquedaClientesProvider].
///
/// Si el texto está vacío, devuelve la lista completa sin filtrar.
/// Se recalcula automáticamente cuando cambia la lista o el texto de búsqueda.
final clientesFiltradosProvider = Provider<AsyncValue<List<Client>>>(
  (ref) {
    final listaAsync = ref.watch(gestorClientesProvider);
    final textoBusqueda = ref.watch(textoBusquedaClientesProvider).trim();

    // Sin texto de búsqueda: devuelve la lista completa tal cual
    if (textoBusqueda.isEmpty) return listaAsync;

    // Con texto: filtra sobre los datos disponibles sin hacer otra llamada a BD
    return listaAsync.whenData((clientes) {
      final texto = textoBusqueda.toLowerCase();
      final filtrados = clientes
          .where((c) =>
              c.nombre.toLowerCase().contains(texto) ||
              c.ciudadCp.toLowerCase().contains(texto))
          .toList();
      debugPrint(
          '[clientesFiltradosProvider] Filtrado "$textoBusqueda" → ${filtrados.length} resultados.');
      return filtrados;
    });
  },
  name: 'clientesFiltradosProvider',
);
