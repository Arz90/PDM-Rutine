import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/router/app_router.dart';
import '../../clients/providers/proveedor_clientes.dart';
import '../models/appointment.dart';
import '../providers/proveedor_citas.dart';

/// Pantalla principal del módulo de Calendario.
///
/// Muestra un [TableCalendar] mensual con marcadores en los días con citas.
/// Al seleccionar un día, aparece debajo la lista de citas de ese día,
/// con el nombre del cliente cruzado desde [gestorClientesProvider].
class PantallaCalendario extends ConsumerWidget {
  const PantallaCalendario({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mesFocalizado = ref.watch(mesFocalizadoProvider);
    final diaSeleccionado = ref.watch(diaSeleccionadoProvider);
    final citasPorDia = ref.watch(citasPorDiaProvider);
    final citasDelDia = ref.watch(citasDelDiaSeleccionadoProvider);
    final citasAsync = ref.watch(gestorCitasProvider);
    final esquema = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario de Citas')),
      body: Column(
        children: [
          // ── Calendario mensual ──────────────────────────────────────────────
          TableCalendar<Appointment>(
            locale: 'es_ES',
            firstDay: DateTime.utc(2020, 1, 1),
            lastDay: DateTime.utc(2035, 12, 31),
            focusedDay: mesFocalizado,

            // Carga las citas del día para pintar los marcadores
            eventLoader: (dia) {
              final clave = DateTime(dia.year, dia.month, dia.day);
              return citasPorDia[clave] ?? [];
            },

            // Resalta el día seleccionado
            selectedDayPredicate: (dia) => isSameDay(dia, diaSeleccionado),

            // Al tocar un día: actualiza el día seleccionado y el mes focalizado
            onDaySelected: (diaSelec, diaFocal) {
              ref.read(diaSeleccionadoProvider.notifier).state = diaSelec;
              ref.read(mesFocalizadoProvider.notifier).state = diaFocal;
            },

            // Al deslizar al mes siguiente/anterior: recarga las citas del nuevo mes
            onPageChanged: (diaFocal) {
              ref.read(mesFocalizadoProvider.notifier).state = diaFocal;
            },

            // ── Estilos Material 3 ────────────────────────────────────────────
            calendarStyle: CalendarStyle(
              // Marcadores (puntitos) bajo los días con citas
              markerDecoration: BoxDecoration(
                color: esquema.primary,
                shape: BoxShape.circle,
              ),
              // Día seleccionado
              selectedDecoration: BoxDecoration(
                color: esquema.primary,
                shape: BoxShape.circle,
              ),
              selectedTextStyle:
                  TextStyle(color: esquema.onPrimary, fontWeight: FontWeight.bold),
              // Día de hoy (sin seleccionar)
              todayDecoration: BoxDecoration(
                color: esquema.primaryContainer,
                shape: BoxShape.circle,
              ),
              todayTextStyle: TextStyle(
                color: esquema.onPrimaryContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            headerStyle: const HeaderStyle(
              formatButtonVisible: false, // oculta el botón de formato (mes/semana)
              titleCentered: true,
            ),
          ),

          const Divider(height: 1),

          // ── Cabecera del listado ────────────────────────────────────────────
          _CabeceraDia(diaSeleccionado: diaSeleccionado),

          // ── Lista de citas del día seleccionado ─────────────────────────────
          Expanded(
            child: citasAsync.isLoading
                ? const Center(child: CircularProgressIndicator())
                : citasAsync.hasError
                    ? _VistaError(
                        mensaje: citasAsync.error.toString(),
                        alReintentar: () => ref.invalidate(gestorCitasProvider),
                      )
                    : citasDelDia.isEmpty
                        ? const _VistaSinCitas()
                        : _ListaCitasDelDia(citasDelDia: citasDelDia),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(rutaFormularioCita),
        icon: const Icon(Icons.add),
        label: const Text('Nueva Cita'),
      ),
    );
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

/// Muestra la fecha del día seleccionado como encabezado del listado.
class _CabeceraDia extends StatelessWidget {
  final DateTime? diaSeleccionado;

  const _CabeceraDia({required this.diaSeleccionado});

  @override
  Widget build(BuildContext context) {
    final etiqueta = diaSeleccionado == null
        ? 'Selecciona un día'
        : _formatearFecha(diaSeleccionado!);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.event_note,
              size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 8),
          Text(
            etiqueta,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.primary,
                ),
          ),
        ],
      ),
    );
  }

  String _formatearFecha(DateTime fecha) {
    final formateado = DateFormat('EEEE, d MMMM y', 'es_ES').format(fecha);
    // Capitaliza la primera letra
    return formateado[0].toUpperCase() + formateado.substring(1);
  }
}

/// Lista de tarjetas de cita para el día seleccionado.
class _ListaCitasDelDia extends ConsumerWidget {
  final List<Appointment> citasDelDia;

  const _ListaCitasDelDia({required this.citasDelDia});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      itemCount: citasDelDia.length,
      itemBuilder: (context, indice) =>
          _TarjetaCita(cita: citasDelDia[indice]),
    );
  }
}

/// Tarjeta individual que muestra los datos de una cita.
///
/// Cruza el [clienteId] de la cita con [gestorClientesProvider]
/// para mostrar el nombre del cliente sin una consulta adicional a BD.
class _TarjetaCita extends ConsumerWidget {
  final Appointment cita;

  const _TarjetaCita({required this.cita});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Obtenemos el nombre del cliente desde el provider (ya en memoria)
    final clientesAsync = ref.watch(gestorClientesProvider);
    final nombreCliente = clientesAsync.whenOrNull(
          data: (clientes) {
            final encontrado =
                clientes.where((c) => c.id == cita.clienteId).firstOrNull;
            return encontrado?.nombre;
          },
        ) ??
        'Cliente #${cita.clienteId}';

    final hora = DateFormat('HH:mm').format(cita.fechaHora);

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: _ChipHora(hora: hora),
        title: Row(
          children: [
            Expanded(
              child: Text(
                cita.identificacion,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (cita.esGuardia) const _ChipGuardia(),
          ],
        ),
        subtitle: Text(nombreCliente),
        trailing: _ChipEstado(estado: cita.estado),
        onTap: () => _mostrarDetalleCita(context, ref, cita),
      ),
    );
  }
}

/// Abre un [ModalBottomSheet] con el detalle de [cita] y controles para
/// cambiar su estado. Llama a [gestorCitasProvider] para persistir el cambio.
void _mostrarDetalleCita(
    BuildContext context, WidgetRef ref, Appointment cita) {
  debugPrint('[Calendario] Abriendo detalle para cita id=${cita.id}');
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _HojaDetalleCita(cita: cita),
  );
}

/// Hoja de detalle de una cita con selector de estado.
///
/// Widget separado (con su propio [ConsumerStatefulWidget]) para gestionar
/// correctamente el ciclo de vida y el estado local de carga,
/// sin interferir con el árbol de widgets del calendario.
class _HojaDetalleCita extends ConsumerStatefulWidget {
  final Appointment cita;

  const _HojaDetalleCita({required this.cita});

  @override
  ConsumerState<_HojaDetalleCita> createState() => _EstadoHojaDetalleCita();
}

class _EstadoHojaDetalleCita extends ConsumerState<_HojaDetalleCita> {
  late String _estadoActual;
  late bool _recurrenciaActiva;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.cita.estado;
    _recurrenciaActiva = widget.cita.recurrenciaActiva;
  }

  /// Genera una cita actualizada con los valores locales actuales.
  Appointment _citaConCambios({String? estado, bool? recurrenciaActiva}) {
    return widget.cita.copyWith(
      estado: estado ?? _estadoActual,
      recurrenciaActiva: recurrenciaActiva ?? _recurrenciaActiva,
    );
  }

  /// Persiste el nuevo estado de la cita en BD y actualiza la UI.
  Future<void> _cambiarEstado(String nuevoEstado) async {
    if (nuevoEstado == _estadoActual || _guardando) return;

    debugPrint(
        '[DetalleCita] Cambiando estado: "$_estadoActual" → "$nuevoEstado"');
    setState(() {
      _estadoActual = nuevoEstado;
      _guardando = true;
    });

    try {
      await ref
          .read(gestorCitasProvider.notifier)
          .modificarCita(_citaConCambios());
      debugPrint('[DetalleCita] ✓ Estado actualizado correctamente.');
    } catch (e, traza) {
      debugPrint('[DetalleCita] ✗ ERROR al actualizar estado: $e\n$traza');
      if (mounted) setState(() => _estadoActual = widget.cita.estado);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  /// Activa o desactiva la proyección de ocurrencias futuras de esta serie.
  Future<void> _cambiarRecurrencia(bool activa) async {
    if (_guardando) return;

    debugPrint(
        '[DetalleCita] ${activa ? "Activando" : "Desactivando"} recurrencia...');
    setState(() {
      _recurrenciaActiva = activa;
      _guardando = true;
    });

    try {
      await ref
          .read(gestorCitasProvider.notifier)
          .modificarCita(_citaConCambios());
      debugPrint('[DetalleCita] ✓ Recurrencia actualizada correctamente.');
    } catch (e, traza) {
      debugPrint('[DetalleCita] ✗ ERROR al actualizar recurrencia: $e\n$traza');
      if (mounted) setState(() => _recurrenciaActiva = !activa);
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    // Obtiene el nombre del cliente desde el provider en memoria
    final clientesAsync = ref.watch(gestorClientesProvider);
    final nombreCliente = clientesAsync.whenOrNull(
          data: (clientes) => clientes
              .where((c) => c.id == widget.cita.clienteId)
              .firstOrNull
              ?.nombre,
        ) ??
        'Cliente #${widget.cita.clienteId}';

    final formatoFecha =
        DateFormat('EEEE, d MMMM y  •  HH:mm', 'es_ES');
    final fechaTexto = formatoFecha.format(widget.cita.fechaHora);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Indicador de arrastre ─────────────────────────────────────────
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: esquema.outlineVariant,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // ── Identificación ───────────────────────────────────────────────
          Text(
            widget.cita.identificacion,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            nombreCliente,
            style: TextStyle(color: esquema.primary, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),

          // ── Fecha y periodicidad ─────────────────────────────────────────
          _FilaDetalle(
            icono: Icons.calendar_today_outlined,
            texto: fechaTexto[0].toUpperCase() + fechaTexto.substring(1),
          ),
          const SizedBox(height: 8),
          _FilaDetalle(
            icono: Icons.repeat_outlined,
            texto: 'Periodicidad: ${widget.cita.periodicidad}',
          ),
          const SizedBox(height: 24),

          // ── Selector de estado ───────────────────────────────────────────
          Text(
            'Estado de la cita',
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: esquema.primary,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          _guardando
              ? const Center(child: CircularProgressIndicator())
              : Wrap(
                  spacing: 8,
                  children: ['Pendiente', 'Completada', 'Cancelada']
                      .map((estado) => _ChipEstadoSeleccionable(
                            estado: estado,
                            seleccionado: estado == _estadoActual,
                            alSeleccionar: () => _cambiarEstado(estado),
                          ))
                      .toList(),
                ),

          // ── Toggle de recurrencia (solo en citas periódicas) ─────────────
          if (widget.cita.periodicidad != 'Única visita') ...[
            const SizedBox(height: 16),
            const Divider(),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.repeat_outlined,
                color: _recurrenciaActiva
                    ? esquema.primary
                    : esquema.outline,
              ),
              title: const Text('Recurrencia activa'),
              subtitle: Text(
                _recurrenciaActiva
                    ? 'Las citas futuras se seguirán generando.'
                    : 'Serie detenida: no se generarán citas futuras.',
              ),
              value: _recurrenciaActiva,
              onChanged: _guardando ? null : _cambiarRecurrencia,
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de información (icono + texto) para el detalle de la cita.
class _FilaDetalle extends StatelessWidget {
  final IconData icono;
  final String texto;

  const _FilaDetalle({required this.icono, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icono, size: 16, color: Theme.of(context).colorScheme.outline),
        const SizedBox(width: 8),
        Expanded(
          child: Text(texto,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ),
      ],
    );
  }
}

/// Chip seleccionable para cambiar el estado de la cita.
class _ChipEstadoSeleccionable extends StatelessWidget {
  final String estado;
  final bool seleccionado;
  final VoidCallback alSeleccionar;

  const _ChipEstadoSeleccionable({
    required this.estado,
    required this.seleccionado,
    required this.alSeleccionar,
  });

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (estado) {
      case 'Completada':
        color = Colors.green;
      case 'Cancelada':
        color = Colors.red;
      default:
        color = Colors.orange;
    }

    return FilterChip(
      label: Text(estado),
      selected: seleccionado,
      onSelected: (_) => alSeleccionar(),
      selectedColor: color.withAlpha(51),
      checkmarkColor: color,
      labelStyle: TextStyle(
        color: seleccionado ? color : Theme.of(context).colorScheme.onSurface,
        fontWeight: seleccionado ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(color: seleccionado ? color : Colors.transparent),
    );
  }
}

/// Etiqueta compacta de color rojo que indica servicio de guardia.
class _ChipGuardia extends StatelessWidget {
  const _ChipGuardia();

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: const Icon(Icons.warning_amber_rounded,
          size: 14, color: Colors.white),
      label: const Text('Guardia',
          style: TextStyle(fontSize: 10, color: Colors.white)),
      backgroundColor: Colors.red,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Badge circular que muestra la hora de la cita.
class _ChipHora extends StatelessWidget {
  final String hora;

  const _ChipHora({required this.hora});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      alignment: Alignment.center,
      child: Text(
        hora,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: Theme.of(context).colorScheme.onSecondaryContainer,
        ),
      ),
    );
  }
}

/// Chip de color que indica el estado de la cita.
class _ChipEstado extends StatelessWidget {
  final String estado;

  const _ChipEstado({required this.estado});

  @override
  Widget build(BuildContext context) {
    final Color color;
    switch (estado) {
      case 'Completada':
        color = Colors.green;
      case 'Cancelada':
        color = Colors.red;
      default: // Pendiente
        color = Colors.orange;
    }

    return Chip(
      label: Text(estado,
          style: const TextStyle(fontSize: 11, color: Colors.white)),
      backgroundColor: color,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}

/// Vista cuando no hay citas para el día seleccionado.
class _VistaSinCitas extends StatelessWidget {
  const _VistaSinCitas();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available,
              size: 56,
              color: Theme.of(context).colorScheme.outlineVariant),
          const SizedBox(height: 12),
          Text('Sin citas este día',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          Text(
            'Pulsa "+" para agendar una.',
            style:
                TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ],
      ),
    );
  }
}

/// Vista de error con botón para reintentar la carga.
class _VistaError extends StatelessWidget {
  final String mensaje;
  final VoidCallback alReintentar;

  const _VistaError({required this.mensaje, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 56, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 12),
            const Text('Error al cargar las citas'),
            const SizedBox(height: 8),
            Text(mensaje,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.outline)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: alReintentar,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
