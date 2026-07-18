import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/repositorio_citas.dart';
import '../models/appointment.dart';

// ── Provider del repositorio ──────────────────────────────────────────────────

final repositorioCitasProvider = Provider<RepositorioCitas>(
  (ref) => RepositorioCitas(),
  name: 'repositorioCitasProvider',
);

// ── Providers de estado de la UI ──────────────────────────────────────────────

/// Mes actualmente visible en el calendario.
final mesFocalizadoProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
  name: 'mesFocalizadoProvider',
);

/// Día seleccionado (con tap) en el calendario.
/// null mientras ningún día está seleccionado explícitamente.
final diaSeleccionadoProvider = StateProvider<DateTime?>(
  (ref) => DateTime.now(), // hoy por defecto al abrir la pantalla
  name: 'diaSeleccionadoProvider',
);

// ── Funciones auxiliares de periodicidad ─────────────────────────────────────

/// Convierte la cadena de periodicidad al número de meses de intervalo.
/// Devuelve 0 para "Única visita" o valores desconocidos (sin proyección).
int _mesesDePeriodicidad(String periodicidad) {
  switch (periodicidad) {
    case 'Mensual':       return 1;
    case 'Bimensual':     return 2;
    case 'Trimestral':    return 3;
    case 'Semestral':     return 6;
    case 'Anual':         return 12;
    case 'Única visita':  return 0;
    default:              return 0;
  }
}

/// Devuelve el número de días del mes [mes] del año [anio].
int _diasEnMes(int anio, int mes) => DateTime(anio, mes + 1, 0).day;

// ── Notifier principal ────────────────────────────────────────────────────────

/// Gestiona el ciclo de vida asíncrono de TODAS las citas almacenadas.
///
/// Carga todas las citas de la BD (no solo el mes visible) para que
/// [citasPorDiaProvider] pueda proyectar las recurrencias en cualquier mes.
/// [mesFocalizadoProvider] sigue como dependencia reactiva para refrescar
/// al navegar entre meses sin tener que invalidar el notifier manualmente.
class GestorCitas extends AsyncNotifier<List<Appointment>> {
  late RepositorioCitas _repositorio;

  @override
  Future<List<Appointment>> build() async {
    _repositorio = ref.read(repositorioCitasProvider);
    // Mantener dependencia reactiva: se reconstruye si cambia el mes focalizado
    ref.watch(mesFocalizadoProvider);
    debugPrint('[GestorCitas] Estado → CARGANDO todas las citas...');
    final citas = await _repositorio.obtenerTodasLasCitas();
    debugPrint(
        '[GestorCitas] Estado → ÉXITO. ${citas.length} citas totales en memoria.');
    return citas;
  }

  /// Inserta una nueva cita y recarga todas las citas.
  Future<void> agregarCita(Appointment cita) async {
    debugPrint('[GestorCitas] agregarCita → Estado → CARGANDO');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repositorio.insertarCita(cita);
      final actualizadas = await _repositorio.obtenerTodasLasCitas();
      debugPrint(
          '[GestorCitas] agregarCita → Estado → ÉXITO. Total: ${actualizadas.length}');
      return actualizadas;
    });
    if (state.hasError) {
      debugPrint('[GestorCitas] agregarCita → ERROR: ${state.error}');
    }
  }

  /// Modifica una cita existente y recarga todas las citas.
  Future<void> modificarCita(Appointment cita) async {
    debugPrint('[GestorCitas] modificarCita → id=${cita.id} | Estado → CARGANDO');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repositorio.actualizarCita(cita);
      final actualizadas = await _repositorio.obtenerTodasLasCitas();
      debugPrint('[GestorCitas] modificarCita → Estado → ÉXITO.');
      return actualizadas;
    });
    if (state.hasError) {
      debugPrint('[GestorCitas] modificarCita → ERROR: ${state.error}');
    }
  }

  /// Elimina una cita y recarga todas las citas.
  Future<void> eliminarCita(int id) async {
    debugPrint('[GestorCitas] eliminarCita → id=$id | Estado → CARGANDO');
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      await _repositorio.eliminarCita(id);
      final actualizadas = await _repositorio.obtenerTodasLasCitas();
      debugPrint(
          '[GestorCitas] eliminarCita → Estado → ÉXITO. Restantes: ${actualizadas.length}');
      return actualizadas;
    });
    if (state.hasError) {
      debugPrint('[GestorCitas] eliminarCita → ERROR: ${state.error}');
    }
  }
}

final gestorCitasProvider =
    AsyncNotifierProvider<GestorCitas, List<Appointment>>(
  GestorCitas.new,
  name: 'gestorCitasProvider',
);

// ── Providers derivados ───────────────────────────────────────────────────────

/// Construye un mapa {día → citas} con TODAS las ocurrencias reales y proyectadas.
///
/// Para cada cita periódica, calcula todas las fechas futuras dentro del rango
/// del calendario (2020-2035) según su [periodicidad]. Si el día base no existe
/// en el mes proyectado (p.ej. 31 de enero → febrero), se usa el último día
/// de ese mes. Las ocurrencias ya existentes como citas reales tienen prioridad.
final citasPorDiaProvider = Provider<Map<DateTime, List<Appointment>>>(
  (ref) {
    final listaAsync = ref.watch(gestorCitasProvider);
    final citas = listaAsync.valueOrNull ?? [];

    final mapa = <DateTime, List<Appointment>>{};

    for (final cita in citas) {
      // 1. Insertar la cita real en su fecha original
      final claveReal = DateTime(
        cita.fechaHora.year,
        cita.fechaHora.month,
        cita.fechaHora.day,
      );
      mapa.putIfAbsent(claveReal, () => []).add(cita);

      // 2. Proyectar ocurrencias recurrentes en el rango del calendario
      final intervalo = _mesesDePeriodicidad(cita.periodicidad);
      // Sin intervalo → "Única visita" u opción desconocida: no proyectar
      if (intervalo == 0) continue;
      // Si la recurrencia fue desactivada no proyectamos nada más
      if (!cita.recurrenciaActiva) continue;

      final baseAnio = cita.fechaHora.year;
      final baseMes  = cita.fechaHora.month;
      final baseDia  = cita.fechaHora.day;
      final baseHora = cita.fechaHora.hour;
      final baseMin  = cita.fechaHora.minute;

      final ahora = DateTime.now();

      for (int anio = 2020; anio <= 2035; anio++) {
        for (int mes = 1; mes <= 12; mes++) {
          final mesDiff = (anio - baseAnio) * 12 + (mes - baseMes);
          // Solo proyectar meses futuros que son múltiplos exactos del intervalo
          if (mesDiff <= 0 || mesDiff % intervalo != 0) continue;

          // Ajustar el día si el mes proyectado tiene menos días (ej. 31→28 en feb)
          final diaProyectado = baseDia.clamp(1, _diasEnMes(anio, mes));
          final fechaProyectada =
              DateTime(anio, mes, diaProyectado, baseHora, baseMin);

          // Si la recurrencia está desactivada, solo pintamos ocurrencias pasadas
          if (!cita.recurrenciaActiva && fechaProyectada.isAfter(ahora)) {
            continue;
          }

          final claveProyectada = DateTime(anio, mes, diaProyectado);

          final lista = mapa.putIfAbsent(claveProyectada, () => []);
          // Evitar duplicar si ya hay una cita real con el mismo id en ese día
          final yaExiste = lista.any((c) => c.id == cita.id);
          if (!yaExiste) {
            lista.add(cita.copyWith(fechaHora: fechaProyectada));
          }
        }
      }
    }

    debugPrint(
        '[citasPorDiaProvider] Mapa generado con ${mapa.length} días con citas '
        '(reales + proyecciones).');
    return mapa;
  },
  name: 'citasPorDiaProvider',
);

/// Devuelve las citas del día actualmente seleccionado en el calendario.
/// Incluye tanto citas reales como proyecciones de recurrencias.
final citasDelDiaSeleccionadoProvider = Provider<List<Appointment>>(
  (ref) {
    final diaSeleccionado = ref.watch(diaSeleccionadoProvider);
    if (diaSeleccionado == null) return [];

    final citasPorDia = ref.watch(citasPorDiaProvider);
    final clave = DateTime(
      diaSeleccionado.year,
      diaSeleccionado.month,
      diaSeleccionado.day,
    );
    return citasPorDia[clave] ?? [];
  },
  name: 'citasDelDiaSeleccionadoProvider',
);
