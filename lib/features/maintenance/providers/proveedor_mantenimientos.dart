import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositorio_mantenimientos.dart';
import '../models/mantenimiento.dart';

// ── Provider del repositorio ──────────────────────────────────────────────────

final repositorioMantenimientosProvider = Provider<RepositorioMantenimientos>(
  (ref) => RepositorioMantenimientos(),
  name: 'repositorioMantenimientosProvider',
);

// ── Nombre del operario (persiste durante la sesión) ─────────────────────────

/// Almacena el nombre del último operario que usó el formulario.
/// Se rellena automáticamente en la siguiente visita.
final nombreOperarioProvider = StateProvider<String>(
  (ref) => '',
  name: 'nombreOperarioProvider',
);

// ── Notifier: mantenimientos de una cita concreta ────────────────────────────

/// Gestiona la lista de [Mantenimiento] asociados a una cita específica.
///
/// Se instancia con [.family] pasando el [citaId] como parámetro,
/// por lo que Riverpod mantiene una instancia independiente por cita.
class GestorMantenimientos
    extends AutoDisposeFamilyAsyncNotifier<List<Mantenimiento>, int> {
  late RepositorioMantenimientos _repositorio;

  @override
  Future<List<Mantenimiento>> build(int arg) async {
    _repositorio = ref.read(repositorioMantenimientosProvider);
    final citaId = arg;
    debugPrint(
        '[GestorMantenimientos] Cargando mantenimientos de cita id=$citaId...');
    final lista = await _repositorio.obtenerMantenimientosPorCita(citaId);
    debugPrint(
        '[GestorMantenimientos] ✓ ${lista.length} mantenimientos cargados.');
    return lista;
  }

  /// Inserta un [mantenimiento] y refresca la lista.
  Future<Mantenimiento> agregarMantenimiento(Mantenimiento mantenimiento) async {
    debugPrint(
        '[GestorMantenimientos] agregarMantenimiento → citaId=${mantenimiento.citaId}');
    state = const AsyncValue.loading();
    late Mantenimiento guardado;
    state = await AsyncValue.guard(() async {
      final nuevoId = await _repositorio.insertarMantenimiento(mantenimiento);
      guardado = mantenimiento.copyWith(id: nuevoId);
      final actualizados =
          await _repositorio.obtenerMantenimientosPorCita(mantenimiento.citaId);
      debugPrint(
          '[GestorMantenimientos] ✓ Añadido. Total cita: ${actualizados.length}');
      return actualizados;
    });
    if (state.hasError) {
      debugPrint('[GestorMantenimientos] ✗ ERROR: ${state.error}');
    }
    return guardado;
  }
}

final gestorMantenimientosProvider =
    AutoDisposeAsyncNotifierProviderFamily<GestorMantenimientos,
        List<Mantenimiento>, int>(
  GestorMantenimientos.new,
  name: 'gestorMantenimientosProvider',
);
