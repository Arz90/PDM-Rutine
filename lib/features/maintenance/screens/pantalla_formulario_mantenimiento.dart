import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

import '../../calendar/models/appointment.dart';
import '../../calendar/providers/proveedor_citas.dart';
import '../../clients/providers/proveedor_clientes.dart';
import '../models/mantenimiento.dart';
import '../providers/proveedor_mantenimientos.dart';
import '../services/generador_pdf.dart';

/// Pantalla para cumplimentar un parte de trabajo de mantenimiento.
///
/// Se abre desde el detalle de una cita pulsando "Iniciar Mantenimiento".
/// Recibe [citaId] desde los parámetros de ruta.
/// Al guardar: persiste el parte, marca la cita como "Completada"
/// y genera el PDF para compartir.
class PantallaFormularioMantenimiento extends ConsumerStatefulWidget {
  final int citaId;

  const PantallaFormularioMantenimiento({super.key, required this.citaId});

  @override
  ConsumerState<PantallaFormularioMantenimiento> createState() =>
      _EstadoFormularioMantenimiento();
}

class _EstadoFormularioMantenimiento
    extends ConsumerState<PantallaFormularioMantenimiento> {
  final _claveFormulario = GlobalKey<FormState>();
  final _ctrlOperario = TextEditingController();
  final _ctrlDetalles = TextEditingController();
  final _ctrlObservaciones = TextEditingController();
  late final SignatureController _ctrlFirmaTecnico;
  late final SignatureController _ctrlFirmaCliente;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    // Pre-rellena el nombre del operario desde la sesión anterior
    _ctrlOperario.text = ref.read(nombreOperarioProvider);

    _ctrlFirmaTecnico = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    _ctrlFirmaCliente = SignatureController(
      penStrokeWidth: 3,
      penColor: Colors.black,
      exportBackgroundColor: Colors.white,
    );
    debugPrint(
        '[FormularioMantenimiento] initState → citaId=${widget.citaId}');
  }

  @override
  void dispose() {
    _ctrlOperario.dispose();
    _ctrlDetalles.dispose();
    _ctrlObservaciones.dispose();
    _ctrlFirmaTecnico.dispose();
    _ctrlFirmaCliente.dispose();
    super.dispose();
  }

  // ── Guardado + PDF ────────────────────────────────────────────────────────

  Future<void> _guardarYGenerarPDF() async {
    if (!(_claveFormulario.currentState?.validate() ?? false)) {
      debugPrint('[FormularioMantenimiento] ⚠ Validación fallida.');
      return;
    }

    setState(() => _guardando = true);
    debugPrint('[FormularioMantenimiento] Iniciando guardado...');

    // Exportar firmas a PNG → Base64 ANTES de cualquier await con contextos
    final bytesFirmaTecnico = await _ctrlFirmaTecnico.toPngBytes();
    final bytesFirmaCliente = await _ctrlFirmaCliente.toPngBytes();

    final firmaTecnicoB64 =
        bytesFirmaTecnico != null ? base64Encode(bytesFirmaTecnico) : null;
    final firmaClienteB64 =
        bytesFirmaCliente != null ? base64Encode(bytesFirmaCliente) : null;

    // Capturar referencias síncronas al repositorio y provider
    final repositorio = ref.read(repositorioMantenimientosProvider);
    final gestorCitas = ref.read(gestorCitasProvider.notifier);
    final todasLasCitas = ref.read(gestorCitasProvider).valueOrNull ?? [];
    final todosLosClientes =
        ref.read(gestorClientesProvider).valueOrNull ?? [];

    try {
      // 1. Buscar la cita
      final cita = todasLasCitas.firstWhere(
        (c) => c.id == widget.citaId,
        orElse: () => throw Exception(
            'No se encontró la cita con id=${widget.citaId}'),
      );

      // 2. Buscar el cliente
      final cliente = todosLosClientes.firstWhere(
        (c) => c.id == cita.clienteId,
        orElse: () => throw Exception(
            'No se encontró el cliente con id=${cita.clienteId}'),
      );

      // 3. Crear y persistir el parte de mantenimiento
      final nuevoMantenimiento = Mantenimiento(
        citaId: widget.citaId,
        operarioNombre: _ctrlOperario.text.trim(),
        detallesTrabajo: _ctrlDetalles.text.trim(),
        observaciones: _ctrlObservaciones.text.trim(),
        firmaTecnico: firmaTecnicoB64,
        firmaCliente: firmaClienteB64,
        fechaCreacion: DateTime.now(),
      );

      final nuevoId =
          await repositorio.insertarMantenimiento(nuevoMantenimiento);
      final mantenimientoGuardado =
          nuevoMantenimiento.copyWith(id: nuevoId);
      debugPrint(
          '[FormularioMantenimiento] ✓ Parte guardado con id=$nuevoId');

      // 4. Marcar la cita como "Completada" automáticamente
      await gestorCitas.modificarCita(
          cita.copyWith(estado: 'Completada'));
      debugPrint(
          '[FormularioMantenimiento] ✓ Cita ${widget.citaId} marcada como Completada.');

      // 5. Guardar el nombre del operario para la próxima sesión
      if (!mounted) return;
      ref.read(nombreOperarioProvider.notifier).state =
          _ctrlOperario.text.trim();

      // 6. Generar y compartir el PDF
      debugPrint('[FormularioMantenimiento] Generando PDF...');
      await GeneradorPDF.generarYCompartir(
        mantenimiento: mantenimientoGuardado,
        cita: cita,
        nombreCliente: cliente.nombre,
        ciudadCliente: cliente.ciudadCp,
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('✓ Parte guardado y PDF generado.'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } catch (e, traza) {
      debugPrint(
          '[FormularioMantenimiento] ✗ ERROR al guardar: $e\n$traza');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final citasAsync = ref.watch(gestorCitasProvider);
    final clientesAsync = ref.watch(gestorClientesProvider);

    // Localizar cita y cliente para mostrar contexto en la cabecera
    final cita = citasAsync.valueOrNull
        ?.where((c) => c.id == widget.citaId)
        .firstOrNull;
    final cliente = cita == null
        ? null
        : clientesAsync.valueOrNull
            ?.where((c) => c.id == cita.clienteId)
            .firstOrNull;

    return Scaffold(
      appBar: AppBar(title: const Text('Parte de Mantenimiento')),
      body: Form(
        key: _claveFormulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Tarjeta de contexto (datos de la cita) ──────────────────────
            if (cita != null) _TarjetaContextoCita(cita: cita, cliente: cliente),
            const SizedBox(height: 20),

            // ── Sección: Operario ────────────────────────────────────────────
            _SeccionLabel(titulo: 'Datos del Operario'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ctrlOperario,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre del operario *',
                prefixIcon: Icon(Icons.badge_outlined),
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'El nombre del operario es obligatorio.'
                  : null,
            ),
            const SizedBox(height: 24),

            // ── Sección: Trabajo ─────────────────────────────────────────────
            _SeccionLabel(titulo: 'Trabajo Realizado'),
            const SizedBox(height: 8),
            TextFormField(
              controller: _ctrlDetalles,
              minLines: 4,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Descripción detallada del trabajo *',
                hintText:
                    'Describe las acciones realizadas, elementos revisados, etc.',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 60),
                  child: Icon(Icons.construction_outlined),
                ),
                alignLabelWithHint: true,
              ),
              validator: (v) => (v == null || v.trim().isEmpty)
                  ? 'La descripción del trabajo es obligatoria.'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _ctrlObservaciones,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Observaciones / Anomalías detectadas',
                hintText: 'Defectos, piezas a sustituir, advertencias...',
                prefixIcon: Padding(
                  padding: EdgeInsets.only(bottom: 30),
                  child: Icon(Icons.warning_amber_outlined),
                ),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),

            // ── Sección: Firmas ──────────────────────────────────────────────
            _SeccionLabel(titulo: 'Firmas'),
            const SizedBox(height: 8),
            _RecuadroFirma(
              etiqueta: 'Firma del Técnico',
              controlador: _ctrlFirmaTecnico,
            ),
            const SizedBox(height: 16),
            _RecuadroFirma(
              etiqueta: 'Firma del Cliente / Responsable',
              controlador: _ctrlFirmaCliente,
            ),
            const SizedBox(height: 32),

            // ── Botón principal ──────────────────────────────────────────────
            FilledButton.icon(
              onPressed: _guardando ? null : _guardarYGenerarPDF,
              icon: _guardando
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined),
              label: Text(_guardando
                  ? 'Generando PDF…'
                  : 'Guardar y Generar PDF'),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

/// Muestra el contexto de la cita en una tarjeta en la parte superior del form.
class _TarjetaContextoCita extends StatelessWidget {
  final Appointment cita;
  final dynamic cliente; // Client?

  const _TarjetaContextoCita({required this.cita, required this.cliente});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final formato = DateFormat('EEEE d MMMM y  •  HH:mm', 'es_ES');
    final fechaTexto = formato.format(cita.fechaHora);

    return Card(
      color: esquema.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.event_note,
                    size: 16, color: esquema.onPrimaryContainer),
                const SizedBox(width: 6),
                Text(
                  'Cita seleccionada',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: esquema.onPrimaryContainer,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              cita.identificacion,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 15,
                color: esquema.onPrimaryContainer,
              ),
            ),
            if (cliente != null) ...[
              const SizedBox(height: 2),
              Text(
                '${cliente!.nombre}  ·  ${cliente!.ciudadCp}',
                style: TextStyle(
                    fontSize: 12,
                    color: esquema.onPrimaryContainer.withAlpha(180)),
              ),
            ],
            const SizedBox(height: 4),
            Text(
              fechaTexto[0].toUpperCase() + fechaTexto.substring(1),
              style: TextStyle(
                  fontSize: 12,
                  color: esquema.onPrimaryContainer.withAlpha(180)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Etiqueta de sección del formulario.
class _SeccionLabel extends StatelessWidget {
  final String titulo;

  const _SeccionLabel({required this.titulo});

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

/// Recuadro blanco con lienzo de firma y botón de borrado.
class _RecuadroFirma extends StatelessWidget {
  final String etiqueta;
  final SignatureController controlador;

  const _RecuadroFirma({
    required this.etiqueta,
    required this.controlador,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(etiqueta,
            style: const TextStyle(
                fontSize: 13, fontWeight: FontWeight.w500)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: esquema.outline),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Signature(
              controller: controlador,
              backgroundColor: Colors.white,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: controlador.clear,
            icon: const Icon(Icons.delete_outline, size: 16),
            label: const Text('Borrar firma'),
            style: TextButton.styleFrom(
              foregroundColor: esquema.error,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ),
      ],
    );
  }
}
