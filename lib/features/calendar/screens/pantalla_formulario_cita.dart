import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../clients/models/client.dart';
import '../../clients/providers/proveedor_clientes.dart';
import '../../machines/models/maquina.dart';
import '../../machines/providers/proveedor_maquinas.dart';
import '../models/appointment.dart';
import '../providers/proveedor_citas.dart';

// ── Constantes de dominio ─────────────────────────────────────────────────────

/// Opciones de periodicidad disponibles para una cita.
/// 'Única visita' no genera proyecciones recurrentes en el calendario.
const List<String> kPeriodicidades = [
  'Mensual',
  'Bimensual',
  'Trimestral',
  'Semestral',
  'Anual',
  'Única visita',
];

/// Estados posibles de una cita.
const List<String> kEstadosCita = [
  'Pendiente',
  'Completada',
  'Cancelada',
];

// ── Widget principal ──────────────────────────────────────────────────────────

/// Formulario para crear o editar una cita de mantenimiento.
///
/// [citaExistente] null → modo creación.
/// [citaExistente] con valor → modo edición.
///
/// La fecha inicial se pre-rellena desde [diaSeleccionadoProvider]
/// si viene de pulsar un día en el calendario.
class PantallaFormularioCita extends ConsumerStatefulWidget {
  final Appointment? citaExistente;

  const PantallaFormularioCita({super.key, this.citaExistente});

  @override
  ConsumerState<PantallaFormularioCita> createState() =>
      _EstadoFormularioCita();
}

class _EstadoFormularioCita extends ConsumerState<PantallaFormularioCita> {
  final GlobalKey<FormState> _claveFormulario = GlobalKey<FormState>();
  bool _guardando = false;

  // ── Estado del formulario ─────────────────────────────────────────────────
  Client? _clienteSeleccionado;
  Maquina? _maquinaSeleccionada;
  late DateTime _fechaSeleccionada;
  late TimeOfDay _horaSeleccionada;
  final TextEditingController _ctrlIdentificacion = TextEditingController();
  String _periodicidadSeleccionada = kPeriodicidades.first;
  String _estadoSeleccionado = kEstadosCita.first;
  bool _esGuardia = false;

  bool get _esEdicion => widget.citaExistente != null;

  @override
  void initState() {
    super.initState();
    final cita = widget.citaExistente;

    if (cita != null) {
      // ── Modo edición: pre-rellena con datos existentes ────────────────────
      _fechaSeleccionada = cita.fechaHora;
      _horaSeleccionada = TimeOfDay.fromDateTime(cita.fechaHora);
      _ctrlIdentificacion.text = cita.identificacion;
      _periodicidadSeleccionada = cita.periodicidad;
      _estadoSeleccionado = cita.estado;
      _esGuardia = cita.esGuardia;
      debugPrint('[FormularioCita] initState → EDICIÓN (id=${cita.id})');
    } else {
      // ── Modo creación: usa el día seleccionado en el calendario ──────────
      final diaSelec = ref.read(diaSeleccionadoProvider) ?? DateTime.now();
      _fechaSeleccionada = diaSelec;
      _horaSeleccionada = TimeOfDay.now();
      debugPrint('[FormularioCita] initState → CREACIÓN (fecha: $diaSelec)');
    }
  }

  @override
  void dispose() {
    _ctrlIdentificacion.dispose();
    super.dispose();
  }

  // ── Selectores ────────────────────────────────────────────────────────────

  /// Abre el DatePicker y actualiza [_fechaSeleccionada].
  Future<void> _seleccionarFecha() async {
    final fechaPick = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      locale: const Locale('es', 'ES'),
    );
    if (fechaPick != null) {
      debugPrint('[FormularioCita] Fecha seleccionada: $fechaPick');
      setState(() => _fechaSeleccionada = fechaPick);
    }
  }

  /// Abre el TimePicker y actualiza [_horaSeleccionada].
  Future<void> _seleccionarHora() async {
    final horaPick = await showTimePicker(
      context: context,
      initialTime: _horaSeleccionada,
    );
    if (horaPick != null) {
      debugPrint('[FormularioCita] Hora seleccionada: $horaPick');
      setState(() => _horaSeleccionada = horaPick);
    }
  }

  // ── Creación rápida de máquina ────────────────────────────────────────────

  /// Abre [_DialogoNuevaMaquina] y espera la [Maquina] creada.
  Future<void> _abrirDialogoCreacionRapidaMaquina() async {
    if (_clienteSeleccionado == null) return;
    debugPrint('[FormularioCita] Abriendo diálogo de creación rápida de máquina.');

    final nuevaMaquina = await showDialog<Maquina>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _DialogoNuevaMaquina(clienteId: _clienteSeleccionado!.id!),
    );

    if (nuevaMaquina == null || !mounted) return;

    debugPrint(
        '[FormularioCita] ✓ Máquina recibida: "${nuevaMaquina.nombreReferencia}" (id=${nuevaMaquina.id})');

    ref
        .read(gestorMaquinasProvider(_clienteSeleccionado!.id!).notifier)
        .agregarMaquinaLocalmente(nuevaMaquina);

    setState(() => _maquinaSeleccionada = nuevaMaquina);
  }

  // ── Creación rápida de cliente ────────────────────────────────────────────

  /// Abre [_DialogoNuevoCliente] y espera el [Client] creado.
  ///
  /// El diálogo se encarga de su propio ciclo de vida y devuelve el cliente
  /// completo (con id) mediante [Navigator.pop]. Solo cuando el diálogo
  /// está totalmente cerrado y eliminado del árbol actualizamos los providers
  /// y el estado local, evitando la aserción _dependents.isEmpty de Riverpod.
  Future<void> _abrirDialogoCreacionRapida() async {
    debugPrint('[FormularioCita] Abriendo diálogo de creación rápida de cliente.');

    final nuevoCliente = await showDialog<Client>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const _DialogoNuevoCliente(),
    );

    // El diálogo está completamente cerrado y fuera del árbol de widgets.
    if (nuevoCliente == null || !mounted) return;

    debugPrint(
        '[FormularioCita] ✓ Cliente recibido: "${nuevoCliente.nombre}" (id=${nuevoCliente.id})');

    // Actualización optimista: el cliente ya está en BD, lo añadimos en memoria.
    ref
        .read(gestorClientesProvider.notifier)
        .agregarClienteLocalmente(nuevoCliente);

    // Auto-selecciona el nuevo cliente en el desplegable.
    setState(() => _clienteSeleccionado = nuevoCliente);
  }

  // ── Guardado ──────────────────────────────────────────────────────────────

  Future<void> _guardar() async {
    if (!(_claveFormulario.currentState?.validate() ?? false)) {
      debugPrint('[FormularioCita] Validación fallida → no se guarda.');
      return;
    }

    setState(() => _guardando = true);
    debugPrint('[FormularioCita] Iniciando proceso de guardado...');

    try {
      // Combina la fecha y la hora en un único DateTime y convierte a UTC
      final fechaHoraCombinada = DateTime(
        _fechaSeleccionada.year,
        _fechaSeleccionada.month,
        _fechaSeleccionada.day,
        _horaSeleccionada.hour,
        _horaSeleccionada.minute,
      );
      final gestor = ref.read(gestorCitasProvider.notifier);

      if (_esEdicion) {
        // Construimos el objeto completo para poder asignar/limpiar maquinaId
        final citaActualizada = Appointment(
          id: widget.citaExistente!.id,
          clienteId: _clienteSeleccionado!.id!,
          fechaHora: fechaHoraCombinada,
          identificacion: _ctrlIdentificacion.text.trim(),
          periodicidad: _periodicidadSeleccionada,
          estado: _estadoSeleccionado,
          esGuardia: _esGuardia,
          recurrenciaActiva: widget.citaExistente!.recurrenciaActiva,
          maquinaId: _maquinaSeleccionada?.id,
        );
        debugPrint('[FormularioCita] Datos a actualizar: ${citaActualizada.toMap()}');
        await gestor.modificarCita(citaActualizada);
      } else {
        final nuevaCita = Appointment(
          clienteId: _clienteSeleccionado!.id!,
          fechaHora: fechaHoraCombinada,
          identificacion: _ctrlIdentificacion.text.trim(),
          periodicidad: _periodicidadSeleccionada,
          estado: _estadoSeleccionado,
          esGuardia: _esGuardia,
          maquinaId: _maquinaSeleccionada?.id,
          // recurrenciaActiva: true por defecto (se gestiona desde el detalle)
        );
        debugPrint('[FormularioCita] Datos a insertar: ${nuevaCita.toMap()}');
        await gestor.agregarCita(nuevaCita);
      }

      debugPrint('[FormularioCita] ✓ Guardado exitoso.');

      if (mounted) {
        // Actualiza el día seleccionado para que el calendario lo muestre
        ref.read(diaSeleccionadoProvider.notifier).state = _fechaSeleccionada;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _esEdicion
                  ? '✓ Cita actualizada correctamente.'
                  : '✓ Cita agendada correctamente.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e, traza) {
      debugPrint('[FormularioCita] ✗ ERROR al guardar: $e\n$traza');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final clientesAsync = ref.watch(gestorClientesProvider);
    final formatoFecha = DateFormat('EEEE, d MMMM y', 'es_ES');
    final fechaTexto = formatoFecha.format(_fechaSeleccionada);
    final horaTexto = _horaSeleccionada.format(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Cita' : 'Nueva Cita'),
      ),
      body: Form(
        key: _claveFormulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Sección: Cliente ────────────────────────────────────────────
            _SeccionFormulario(titulo: 'Cliente'),
            const SizedBox(height: 8),
            clientesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error al cargar clientes: $e',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.error)),
              data: (clientes) {
                // Pre-seleccionar cliente si estamos editando
                if (_esEdicion && _clienteSeleccionado == null) {
                  _clienteSeleccionado = clientes
                      .where((c) => c.id == widget.citaExistente!.clienteId)
                      .firstOrNull;
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<Client>(
                        // ignore: deprecated_member_use
                        value: _clienteSeleccionado,
                        decoration: const InputDecoration(
                          labelText: 'Cliente *',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                        hint: const Text('Selecciona un cliente'),
                        items: clientes
                            .map((c) => DropdownMenuItem(
                                  value: c,
                                  child: Text(c.nombre),
                                ))
                            .toList(),
                        onChanged: (c) => setState(() {
                          _clienteSeleccionado = c;
                          _maquinaSeleccionada = null; // reset al cambiar cliente
                        }),
                        validator: (valor) =>
                            valor == null ? 'Selecciona un cliente.' : null,
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Botón para crear un cliente nuevo sin salir del formulario
                    Tooltip(
                      message: 'Crear cliente rápido',
                      child: IconButton.outlined(
                        onPressed: _abrirDialogoCreacionRapida,
                        icon: const Icon(Icons.person_add_outlined),
                      ),
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 24),

            // ── Sección: Máquina / Instalación (opcional) ───────────────────
            _SeccionFormulario(titulo: 'Máquina / Instalación (opcional)'),
            const SizedBox(height: 8),
            if (_clienteSeleccionado == null)
              Text(
                'Selecciona primero un cliente para ver sus instalaciones.',
                style: TextStyle(
                    color: Theme.of(context).colorScheme.outline,
                    fontSize: 13),
              )
            else
              ref.watch(gestorMaquinasProvider(_clienteSeleccionado!.id!)).when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Error al cargar máquinas: $e',
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    data: (maquinas) {
                      // Pre-selección en modo edición
                      if (_esEdicion &&
                          _maquinaSeleccionada == null &&
                          widget.citaExistente!.maquinaId != null) {
                        _maquinaSeleccionada = maquinas
                            .where(
                                (m) => m.id == widget.citaExistente!.maquinaId)
                            .firstOrNull;
                      }
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<Maquina?>(
                              // ignore: deprecated_member_use
                              value: _maquinaSeleccionada,
                              decoration: const InputDecoration(
                                labelText: 'Instalación',
                                prefixIcon:
                                    Icon(Icons.settings_outlined),
                              ),
                              hint: const Text('Sin instalación asignada'),
                              items: [
                                const DropdownMenuItem<Maquina?>(
                                  value: null,
                                  child: Text('— Ninguna —'),
                                ),
                                ...maquinas.map((m) => DropdownMenuItem(
                                      value: m,
                                      child: Text(m.nombreReferencia),
                                    )),
                              ],
                              onChanged: (m) =>
                                  setState(() => _maquinaSeleccionada = m),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Tooltip(
                            message: 'Crear instalación rápida',
                            child: IconButton.outlined(
                              onPressed: _abrirDialogoCreacionRapidaMaquina,
                              icon: const Icon(Icons.add_circle_outline),
                            ),
                          ),
                        ],
                      );
                    },
                  ),

            const SizedBox(height: 24),

            // ── Sección: Fecha y Hora ───────────────────────────────────────
            _SeccionFormulario(titulo: 'Fecha y Hora'),
            const SizedBox(height: 8),
            Row(
              children: [
                // Botón de fecha
                Expanded(
                  child: _BotonSelector(
                    icono: Icons.calendar_today_outlined,
                    etiqueta: 'Fecha',
                    valor: fechaTexto[0].toUpperCase() +
                        fechaTexto.substring(1),
                    alPresionar: _seleccionarFecha,
                  ),
                ),
                const SizedBox(width: 12),
                // Botón de hora
                SizedBox(
                  width: 110,
                  child: _BotonSelector(
                    icono: Icons.access_time_outlined,
                    etiqueta: 'Hora',
                    valor: horaTexto,
                    alPresionar: _seleccionarHora,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // ── Sección: Detalles ───────────────────────────────────────────
            _SeccionFormulario(titulo: 'Detalles'),
            const SizedBox(height: 8),

            // Identificación de la máquina / aviso
            TextFormField(
              controller: _ctrlIdentificacion,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Identificación *',
                hintText: 'Ej: Puerta seccional nave 3',
                prefixIcon: Icon(Icons.label_outline),
              ),
              validator: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'La identificación es obligatoria.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Periodicidad
            DropdownButtonFormField<String>(
              // ignore: deprecated_member_use
              value: _periodicidadSeleccionada,
              decoration: const InputDecoration(
                labelText: 'Periodicidad *',
                prefixIcon: Icon(Icons.repeat_outlined),
              ),
              items: kPeriodicidades
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (valor) {
                if (valor != null) {
                  setState(() => _periodicidadSeleccionada = valor);
                }
              },
            ),

            const SizedBox(height: 16),

            // Servicio de guardia / fuera de horario
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(
                Icons.warning_amber_rounded,
                color: _esGuardia
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.outline,
              ),
              title: const Text('Servicio de Guardia'),
              subtitle: const Text('Visita fuera de horario habitual'),
              value: _esGuardia,
              onChanged: (valor) => setState(() => _esGuardia = valor),
            ),

            // Estado (visible solo en edición)
            if (_esEdicion) ...[
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                // ignore: deprecated_member_use
                value: _estadoSeleccionado,
                decoration: const InputDecoration(
                  labelText: 'Estado',
                  prefixIcon: Icon(Icons.flag_outlined),
                ),
                items: kEstadosCita
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
                onChanged: (valor) {
                  if (valor != null) {
                    setState(() => _estadoSeleccionado = valor);
                  }
                },
              ),
            ],

            const SizedBox(height: 32),

            // ── Botón guardar ───────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _guardando ? null : _guardar,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.event_available_outlined),
              label: Text(_guardando ? 'Guardando…' : 'Guardar Cita'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widgets de apoyo ──────────────────────────────────────────────────────────

/// Encabezado de sección dentro del formulario.
class _SeccionFormulario extends StatelessWidget {
  final String titulo;

  const _SeccionFormulario({required this.titulo});

  @override
  Widget build(BuildContext context) {
    return Text(
      titulo,
      style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
    );
  }
}

/// Botón estilizado para selectores de fecha/hora.
/// Muestra el valor actual y abre el picker al presionar.
class _BotonSelector extends StatelessWidget {
  final IconData icono;
  final String etiqueta;
  final String valor;
  final VoidCallback alPresionar;

  const _BotonSelector({
    required this.icono,
    required this.etiqueta,
    required this.valor,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return InkWell(
      onTap: alPresionar,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
        decoration: BoxDecoration(
          border: Border.all(color: esquema.outline),
          borderRadius: BorderRadius.circular(12),
          color: esquema.surfaceContainerLowest,
        ),
        child: Row(
          children: [
            Icon(icono, size: 20, color: esquema.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(etiqueta,
                      style: TextStyle(
                          fontSize: 11, color: esquema.onSurfaceVariant)),
                  const SizedBox(height: 2),
                  Text(valor,
                      style: const TextStyle(
                          fontWeight: FontWeight.w500, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Diálogo independiente para crear máquina rápida ───────────────────────────

/// Diálogo para crear una nueva instalación/máquina vinculada a un cliente.
///
/// Sigue el mismo patrón seguro que [_DialogoNuevoCliente]:
/// cierra primero el diálogo y devuelve la [Maquina] al padre,
/// evitando accesos a context/ref tras el await.
class _DialogoNuevaMaquina extends ConsumerStatefulWidget {
  final int clienteId;

  const _DialogoNuevaMaquina({required this.clienteId});

  @override
  ConsumerState<_DialogoNuevaMaquina> createState() =>
      _EstadoDialogoNuevaMaquina();
}

class _EstadoDialogoNuevaMaquina
    extends ConsumerState<_DialogoNuevaMaquina> {
  final _claveFormulario = GlobalKey<FormState>();
  final _ctrlNombre = TextEditingController();
  final _ctrlTipo = TextEditingController();
  final _ctrlFabricante = TextEditingController();
  final _ctrlModelo = TextEditingController();
  final _ctrlSerie = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlTipo.dispose();
    _ctrlFabricante.dispose();
    _ctrlModelo.dispose();
    _ctrlSerie.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_claveFormulario.currentState?.validate() ?? false)) return;

    setState(() => _guardando = true);
    debugPrint('[DialogoNuevaMaquina] Guardando máquina rápida...');

    final repositorio = ref.read(repositorioMaquinasProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final colorError = Theme.of(context).colorScheme.error;

    try {
      final nuevaMaquina = Maquina(
        clienteId: widget.clienteId,
        nombreReferencia: _ctrlNombre.text.trim(),
        tipoPuerta: _ctrlTipo.text.trim(),
        fabricante: _ctrlFabricante.text.trim(),
        modelo: _ctrlModelo.text.trim(),
        serie: _ctrlSerie.text.trim(),
      );
      final nuevoId = await repositorio.insertarMaquina(nuevaMaquina);
      final maquinaConId = nuevaMaquina.copyWith(id: nuevoId);
      debugPrint('[DialogoNuevaMaquina] ✓ Máquina creada con id=$nuevoId');

      if (!mounted) return;
      navigator.pop(maquinaConId); // CIERRA PRIMERO, devuelve al padre
    } catch (e, traza) {
      debugPrint('[DialogoNuevaMaquina] ✗ ERROR: $e\n$traza');
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al crear la instalación: $e'),
          backgroundColor: colorError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nueva instalación'),
      content: Form(
        key: _claveFormulario,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _ctrlNombre,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Nombre / Referencia *',
                  hintText: 'Ej: Barrera de acceso nave 3',
                  prefixIcon: Icon(Icons.label_outline),
                ),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? 'El nombre es obligatorio.'
                    : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlTipo,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Tipo de puerta',
                  hintText: 'Ej: Seccional, Basculante, Barrera',
                  prefixIcon: Icon(Icons.door_sliding_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlFabricante,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Fabricante',
                  prefixIcon: Icon(Icons.factory_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlModelo,
                decoration: const InputDecoration(
                  labelText: 'Modelo',
                  prefixIcon: Icon(Icons.inventory_2_outlined),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ctrlSerie,
                decoration: const InputDecoration(
                  labelText: 'Número de serie',
                  prefixIcon: Icon(Icons.qr_code_outlined),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando
              ? null
              : () {
                  debugPrint('[DialogoNuevaMaquina] Cancelado por el usuario.');
                  Navigator.of(context).pop();
                },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}

// ── Diálogo independiente para crear cliente rápido ───────────────────────────

/// Diálogo para crear un nuevo cliente con Nombre y Ciudad.
///
/// Al guardar con éxito, cierra el diálogo devolviendo el [Client] recién
/// creado (con su id asignado) mediante [Navigator.pop]. El padre recibe ese
/// objeto y actualiza su estado DESPUÉS de que el árbol de widgets del diálogo
/// haya sido completamente eliminado, evitando la aserción _dependents.isEmpty.
class _DialogoNuevoCliente extends ConsumerStatefulWidget {
  const _DialogoNuevoCliente();

  @override
  ConsumerState<_DialogoNuevoCliente> createState() =>
      _EstadoDialogoNuevoCliente();
}

class _EstadoDialogoNuevoCliente
    extends ConsumerState<_DialogoNuevoCliente> {
  final _claveFormulario = GlobalKey<FormState>();
  final _ctrlNombre = TextEditingController();
  final _ctrlCiudad = TextEditingController();
  bool _guardando = false;

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlCiudad.dispose();
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!(_claveFormulario.currentState?.validate() ?? false)) return;

    setState(() => _guardando = true);
    debugPrint('[DialogoNuevoCliente] Guardando cliente rápido...');

    // Capturamos referencias síncronas ANTES del await para no acceder
    // a BuildContext o ref en un hueco asíncrono.
    final repositorio = ref.read(repositorioClientesProvider);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final colorError = Theme.of(context).colorScheme.error;

    try {
      final nuevoCliente = Client(
        nombre: _ctrlNombre.text.trim(),
        direccion: '',
        ciudadCp: _ctrlCiudad.text.trim(),
      );
      final nuevoId = await repositorio.insertarCliente(nuevoCliente);
      final clienteConId = nuevoCliente.copyWith(id: nuevoId);
      debugPrint('[DialogoNuevoCliente] ✓ Cliente creado con id=$nuevoId');

      // REGLA DE ORO: cerrar primero, devolver el resultado al padre.
      // El padre actualiza los providers DESPUÉS de que este widget se elimine.
      if (!mounted) return;
      navigator.pop(clienteConId);
    } catch (e, traza) {
      debugPrint('[DialogoNuevoCliente] ✗ ERROR: $e\n$traza');
      if (!mounted) return;
      setState(() => _guardando = false);
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error al crear el cliente: $e'),
          backgroundColor: colorError,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nuevo cliente'),
      content: Form(
        key: _claveFormulario,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              controller: _ctrlNombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre *',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El nombre es obligatorio.'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ctrlCiudad,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Ciudad *',
                prefixIcon: Icon(Icons.location_city_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'La ciudad es obligatoria.'
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _guardando
              ? null
              : () {
                  debugPrint('[DialogoNuevoCliente] Cancelado por el usuario.');
                  Navigator.of(context).pop();
                },
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _guardando ? null : _guardar,
          child: _guardando
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Guardar'),
        ),
      ],
    );
  }
}
