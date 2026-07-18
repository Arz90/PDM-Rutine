import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositorio_maquinas.dart';
import '../models/maquina.dart';

// ── Provider del repositorio ──────────────────────────────────────────────────

final repositorioMaquinasProvider = Provider<RepositorioMaquinas>(
  (ref) => RepositorioMaquinas(),
  name: 'repositorioMaquinasProvider',
);

// ── Notifier: máquinas de un cliente concreto ─────────────────────────────────

/// Gestiona la lista de [Maquina] asociadas a un cliente.
///
/// Se instancia con [.family] pasando el [clienteId] como parámetro,
/// de modo que Riverpod mantiene una instancia independiente por cliente.
class GestorMaquinas
    extends AutoDisposeFamilyAsyncNotifier<List<Maquina>, int> {
  late RepositorioMaquinas _repositorio;

  @override
  Future<List<Maquina>> build(int arg) async {
    _repositorio = ref.read(repositorioMaquinasProvider);
    debugPrint(
        '[GestorMaquinas] Cargando máquinas del cliente id=$arg...');
    final lista = await _repositorio.obtenerMaquinasPorCliente(arg);
    debugPrint('[GestorMaquinas] ✓ ${lista.length} máquinas cargadas.');
    return lista;
  }

  /// Añade localmente una máquina sin recargar desde BD (actualización optimista).
  ///
  /// Equivalente a [agregarClienteLocalmente] en [GestorClientes]:
  /// la máquina ya está en BD (insertada por el diálogo), solo sincronizamos memoria.
  void agregarMaquinaLocalmente(Maquina maquina) {
    final lista = state.valueOrNull ?? [];
    state = AsyncValue.data([...lista, maquina]);
    debugPrint(
        '[GestorMaquinas] ✓ Máquina añadida localmente: "${maquina.nombreReferencia}"');
  }
}

final gestorMaquinasProvider = AutoDisposeAsyncNotifierProviderFamily<
    GestorMaquinas, List<Maquina>, int>(
  GestorMaquinas.new,
  name: 'gestorMaquinasProvider',
);
