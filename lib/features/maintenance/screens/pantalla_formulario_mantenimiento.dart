import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:signature/signature.dart';

import '../../calendar/models/appointment.dart';
import '../../calendar/providers/proveedor_citas.dart';
import '../../clients/providers/proveedor_clientes.dart';
import '../../machines/models/maquina.dart';
import '../../machines/providers/proveedor_maquinas.dart';
import '../models/mantenimiento.dart';
import '../providers/proveedor_mantenimientos.dart';
import '../services/generador_pdf.dart';

// ── Datos del checklist de inspección ─────────────────────────────────────────

/// Mapa de categorías → ítems para el checklist técnico de inspección.
const Map<String, List<String>> kCategoriasChecklist = {
  'Inspección General': [
    'Brazo articulado / Guía deslizante',
    'Estado de guías, bisagras y anclajes',
    'Ruedas y/o poleas',
    'Señalización y placas CE / advertencias legibles',
    'Verificación de protecciones (cizallamiento, aplastamiento)',
    'Limpieza general',
  ],
  'Componentes Mecánicos': [
    'Revisión de cables, cadenas, correas o piñones',
    'Revisión de muelles de torsión / compensación',
    'Inspección de motores / reductores',
    'Comprobación del nivel de aceite',
  ],
  'Dispositivos de Seguridad': [
    'Comprobación de paros de emergencia',
    'Comprobación de pulsadores de maniobra',
    'Prueba funcional de fotocélulas, bordes sensibles y cortinas',
    'Prueba funcional de fuerza de apertura y cierre',
    'Ensayo de fuerza de impacto / maniobra',
  ],
  'Funcionamiento y Maniobra': [
    'Comprobación de finales de carrera y enclavamientos',
    'Verificación de funcionamiento manual y estado de desbloqueo',
    'Verificación de velocidad de apertura y cierre',
    'Ensayo de dispositivos de mando a distancia',
  ],
  'Seguridad Eléctrica': [
    'Prueba de continuidad de tierra',
    'Prueba de aislamiento de motor',
  ],
};

const List<String> kEstadosInstalacion = [
  'Favorable',
  'Favorable con observaciones',
  'Desfavorable',
];

const List<String> kValoresChecklist = ['Favorable', 'Desfavorable', 'N/A'];

// ── Widget principal ──────────────────────────────────────────────────────────

/// Pantalla para cumplimentar un parte de trabajo de mantenimiento.
///
/// Utiliza un [Stepper] de 3 pasos:
///   1. Datos y Resultado Final (operario + estado_instalacion)
///   2. Inspección General (checklist por categorías)
///   3. Detalles y Firmas (trabajo + observaciones + firmas digitales)
///
/// Se abre desde [_HojaDetalleCita] pulsando "Iniciar Mantenimiento".
/// Recibe [citaId] desde los parámetros de ruta.
class PantallaFormularioMantenimiento extends ConsumerStatefulWidget {
  final int citaId;

  const PantallaFormularioMantenimiento({super.key, required this.citaId});

  @override
  ConsumerState<PantallaFormularioMantenimiento> createState() =>
      _EstadoFormularioMantenimiento();
}

class _EstadoFormularioMantenimiento
    extends ConsumerState<PantallaFormularioMantenimiento> {
  // ── Paso 1 ─────────────────────────────────────────────────────────────────
  final _ctrlOperario = TextEditingController();
  String _estadoInstalacion = kEstadosInstalacion.first;

  // ── Paso 2 ─────────────────────────────────────────────────────────────────
  // Estructura: categoría → (ítem → valor seleccionado)
  final Map<String, Map<String, String>> _checklist = {
    for (final cat in kCategoriasChecklist.entries)
      cat.key: {for (final item in cat.value) item: 'N/A'},
  };

  // ── Paso 3 ─────────────────────────────────────────────────────────────────
  final _ctrlDetalles = TextEditingController();
  final _ctrlObservaciones = TextEditingController();
  late final SignatureController _ctrlFirmaTecnico;
  late final SignatureController _ctrlFirmaCliente;

  // ── Modo edición ───────────────────────────────────────────────────────────
  /// Mantenimiento existente cargado de la BD. Null si es modo creación.
  Mantenimiento? _mantenimientoExistente;
  /// Preview de firmas guardadas (bytes PNG decodificados de Base64).
  Uint8List? _firmaTecnicoExistente;
  Uint8List? _firmaClienteExistente;
  /// Mientras se consulta la BD al iniciar, se muestra un indicador.
  bool _cargandoExistente = true;

  // ── Stepper ────────────────────────────────────────────────────────────────
  int _pasoActual = 0;
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
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

    // Verificar si ya existe un parte para esta cita (modo edición)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarMantenimientoExistente();
    });
  }

  /// Consulta la BD para detectar si existe un parte para [citaId].
  /// Si lo encuentra, puebla todos los controladores con los datos guardados.
  Future<void> _cargarMantenimientoExistente() async {
    debugPrint(
        '[FormularioMantenimiento] _cargarMantenimientoExistente → citaId=${widget.citaId}');
    final repositorio = ref.read(repositorioMantenimientosProvider);
    try {
      final lista =
          await repositorio.obtenerMantenimientosPorCita(widget.citaId);

      if (!mounted) return;

      if (lista.isEmpty) {
        debugPrint(
            '[FormularioMantenimiento] ✓ Sin partes previos → modo creación.');
        setState(() => _cargandoExistente = false);
        return;
      }

      final existente = lista.first;
      debugPrint(
          '[FormularioMantenimiento] ✓ Parte existente id=${existente.id} → modo edición.');

      // Poblar controladores de texto
      _ctrlOperario.text = existente.operarioNombre;
      _ctrlDetalles.text = existente.detallesTrabajo;
      _ctrlObservaciones.text = existente.observaciones;

      // Restaurar estado del checklist desde JSON
      if (existente.checklistJson.isNotEmpty &&
          existente.checklistJson != '{}') {
        try {
          final decoded = jsonDecode(existente.checklistJson)
              as Map<String, dynamic>;
          for (final entrada in decoded.entries) {
            if (_checklist.containsKey(entrada.key)) {
              final items =
                  (entrada.value as Map<String, dynamic>).cast<String, String>();
              _checklist[entrada.key]!.addAll(items);
            }
          }
        } catch (e) {
          debugPrint(
              '[FormularioMantenimiento] ⚠ Error parseando checklist: $e');
        }
      }

      // Decodificar firmas existentes para mostrar como preview
      Uint8List? firmaTecnico;
      Uint8List? firmaCliente;
      if (existente.firmaTecnico?.isNotEmpty == true) {
        firmaTecnico = base64Decode(existente.firmaTecnico!);
      }
      if (existente.firmaCliente?.isNotEmpty == true) {
        firmaCliente = base64Decode(existente.firmaCliente!);
      }

      setState(() {
        _mantenimientoExistente = existente;
        _estadoInstalacion =
            existente.estadoInstalacion.isNotEmpty
                ? existente.estadoInstalacion
                : kEstadosInstalacion.first;
        _firmaTecnicoExistente = firmaTecnico;
        _firmaClienteExistente = firmaCliente;
        _cargandoExistente = false;
      });
    } catch (e, traza) {
      debugPrint(
          '[FormularioMantenimiento] ✗ Error cargando existente: $e\n$traza');
      if (mounted) setState(() => _cargandoExistente = false);
    }
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

  // ── Navegación entre pasos ─────────────────────────────────────────────────

  void _siguientePaso() {
    if (_pasoActual == 0) {
      if (_ctrlOperario.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('⚠ El nombre del operario es obligatorio.'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
    }
    if (_pasoActual < 2) setState(() => _pasoActual++);
  }

  void _pasoPrevio() {
    if (_pasoActual > 0) setState(() => _pasoActual--);
  }

  // ── Guardado + PDF ─────────────────────────────────────────────────────────

  Future<void> _guardarYGenerarPDF() async {
    if (_ctrlDetalles.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              const Text('⚠ La descripción del trabajo es obligatoria.'),
          backgroundColor: Theme.of(context).colorScheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _guardando = true);
    debugPrint('[FormularioMantenimiento] Iniciando guardado...');

    // Exportar firmas a PNG → Base64 ANTES de cualquier await con contextos.
    // Si el pad está vacío, se conserva la firma guardada (si la hay).
    final bytesFirmaTecnico = await _ctrlFirmaTecnico.toPngBytes();
    final bytesFirmaCliente = await _ctrlFirmaCliente.toPngBytes();

    final firmaTecnicoB64 = bytesFirmaTecnico != null
        ? base64Encode(bytesFirmaTecnico)
        : _mantenimientoExistente?.firmaTecnico;
    final firmaClienteB64 = bytesFirmaCliente != null
        ? base64Encode(bytesFirmaCliente)
        : _mantenimientoExistente?.firmaCliente;

    // Capturar referencias síncronas al repositorio y providers
    final repositorio = ref.read(repositorioMantenimientosProvider);
    final gestorCitas = ref.read(gestorCitasProvider.notifier);
    final todasLasCitas = ref.read(gestorCitasProvider).valueOrNull ?? [];
    final todosLosClientes =
        ref.read(gestorClientesProvider).valueOrNull ?? [];

    try {
      // 1. Buscar la cita
      final cita = todasLasCitas.firstWhere(
        (c) => c.id == widget.citaId,
        orElse: () =>
            throw Exception('No se encontró la cita id=${widget.citaId}'),
      );

      // 2. Buscar el cliente
      final cliente = todosLosClientes.firstWhere(
        (c) => c.id == cita.clienteId,
        orElse: () => throw Exception(
            'No se encontró el cliente id=${cita.clienteId}'),
      );

      // 3. Buscar la máquina (opcional)
      Maquina? maquina;
      if (cita.maquinaId != null) {
        maquina = ref
            .read(gestorMaquinasProvider(cita.clienteId))
            .valueOrNull
            ?.where((m) => m.id == cita.maquinaId)
            .firstOrNull;
      }

      // 4. Construir el parte (con id si es edición, sin id si es creación)
      final mantenimiento = Mantenimiento(
        id: _mantenimientoExistente?.id,
        citaId: widget.citaId,
        operarioNombre: _ctrlOperario.text.trim(),
        detallesTrabajo: _ctrlDetalles.text.trim(),
        observaciones: _ctrlObservaciones.text.trim(),
        firmaTecnico: firmaTecnicoB64,
        firmaCliente: firmaClienteB64,
        fechaCreacion:
            _mantenimientoExistente?.fechaCreacion ?? DateTime.now(),
        estadoInstalacion: _estadoInstalacion,
        checklistJson: jsonEncode(_checklist),
      );

      // 5. Upsert: INSERT si es nuevo, UPDATE si ya existe
      final int idGuardado;
      if (_mantenimientoExistente == null) {
        idGuardado = await repositorio.insertarMantenimiento(mantenimiento);
        debugPrint(
            '[FormularioMantenimiento] ✓ Parte creado con id=$idGuardado');
      } else {
        await repositorio.actualizarMantenimiento(mantenimiento);
        idGuardado = _mantenimientoExistente!.id!;
        debugPrint(
            '[FormularioMantenimiento] ✓ Parte actualizado id=$idGuardado');
      }
      final mantenimientoGuardado = mantenimiento.copyWith(id: idGuardado);

      // 6. Marcar la cita como "Completada" solo en modo creación
      if (_mantenimientoExistente == null) {
        await gestorCitas.modificarCita(cita.copyWith(estado: 'Completada'));
        debugPrint(
            '[FormularioMantenimiento] ✓ Cita ${widget.citaId} marcada como Completada.');
      }

      // 6. Guardar el nombre del operario para la próxima sesión
      if (!mounted) return;
      ref.read(nombreOperarioProvider.notifier).state =
          _ctrlOperario.text.trim();

      // 7. Generar y compartir el PDF
      debugPrint('[FormularioMantenimiento] Generando PDF...');
      await GeneradorPDF.generarYCompartir(
        mantenimiento: mantenimientoGuardado,
        cita: cita,
        nombreCliente: cliente.nombre,
        ciudadCliente: cliente.ciudadCp,
        maquina: maquina,
      );

      if (!mounted) return;

      // Invalidar el historial ANTES de hacer pop, para que cuando la pantalla
      // de historial vuelva a verse ya tenga los datos actualizados listos.
      ref.invalidate(historialMantenimientosProvider);

      final mensajeExito = _mantenimientoExistente == null
          ? '✓ Parte guardado y PDF generado.'
          : '✓ Parte actualizado y PDF generado.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(mensajeExito),
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

  // ── Constructores de pasos ─────────────────────────────────────────────────

  Widget _construirPaso1() {
    final esquema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          controller: _ctrlOperario,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nombre del operario *',
            prefixIcon: Icon(Icons.badge_outlined),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Resultado global de la instalación *',
          style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: esquema.onSurface),
        ),
        const SizedBox(height: 8),
        ...kEstadosInstalacion.map((estado) {
          final Color color;
          switch (estado) {
            case 'Favorable':
              color = Colors.green;
            case 'Favorable con observaciones':
              color = Colors.orange;
            default:
              color = Colors.red;
          }
          final seleccionado = _estadoInstalacion == estado;
          return RadioListTile<String>(
            value: estado,
            // ignore: deprecated_member_use
            groupValue: _estadoInstalacion,
            contentPadding: EdgeInsets.zero,
            // ignore: deprecated_member_use
            onChanged: (v) {
              if (v != null) setState(() => _estadoInstalacion = v);
            },
            title: Text(
              estado,
              style: TextStyle(
                fontWeight:
                    seleccionado ? FontWeight.bold : FontWeight.normal,
                color: seleccionado ? color : null,
              ),
            ),
            activeColor: color,
          );
        }),
      ],
    );
  }

  Widget _construirPaso2() {
    final esquema = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final categoria in kCategoriasChecklist.entries) ...[
          // Cabecera de categoría
          Container(
            width: double.infinity,
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            margin: const EdgeInsets.only(bottom: 4),
            decoration: BoxDecoration(
              color: esquema.secondaryContainer,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              categoria.key,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                color: esquema.onSecondaryContainer,
              ),
            ),
          ),
          // Ítems de la categoría
          for (final item in categoria.value)
            _FilaChecklistItem(
              item: item,
              valorActual: _checklist[categoria.key]![item]!,
              alCambiar: (nuevoValor) {
                setState(() =>
                    _checklist[categoria.key]![item] = nuevoValor);
              },
            ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  Widget _construirPaso3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _ctrlObservaciones,
          minLines: 2,
          maxLines: 4,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            labelText: 'Observaciones / Acciones correctivas',
            hintText: 'Defectos, piezas sustituidas, advertencias...',
            prefixIcon: Padding(
              padding: EdgeInsets.only(bottom: 30),
              child: Icon(Icons.warning_amber_outlined),
            ),
            alignLabelWithHint: true,
          ),
        ),
        const SizedBox(height: 24),

        // Firma del técnico
        _RecuadroFirma(
          etiqueta: 'Firma del Técnico',
          controlador: _ctrlFirmaTecnico,
          firmaExistente: _firmaTecnicoExistente,
        ),
        const SizedBox(height: 16),

        // Firma del cliente
        _RecuadroFirma(
          etiqueta: 'Firma del Cliente / Responsable',
          controlador: _ctrlFirmaCliente,
          firmaExistente: _firmaClienteExistente,
        ),
        const SizedBox(height: 24),

        // Botón final
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
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
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  // ── UI principal ───────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final citasAsync = ref.watch(gestorCitasProvider);
    final clientesAsync = ref.watch(gestorClientesProvider);

    final cita = citasAsync.valueOrNull
        ?.where((c) => c.id == widget.citaId)
        .firstOrNull;
    final cliente = cita == null
        ? null
        : clientesAsync.valueOrNull
            ?.where((c) => c.id == cita.clienteId)
            .firstOrNull;

    // Cargar máquina si la cita tiene una asociada
    Maquina? maquina;
    if (cita?.maquinaId != null) {
      maquina = ref
          .watch(gestorMaquinasProvider(cita!.clienteId))
          .valueOrNull
          ?.where((m) => m.id == cita.maquinaId)
          .firstOrNull;
    }

    if (_cargandoExistente) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tituloAppBar = _mantenimientoExistente != null
        ? 'Editar Parte'
        : 'Parte de Mantenimiento';

    return Scaffold(
      appBar: AppBar(title: Text(tituloAppBar)),
      body: Column(
        children: [
          // Tarjeta de contexto de la cita
          if (cita != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _TarjetaContextoCita(
                  cita: cita, cliente: cliente, maquina: maquina),
            ),

          // Stepper principal
          Expanded(
            child: Stepper(
              currentStep: _pasoActual,
              onStepTapped: (paso) => setState(() => _pasoActual = paso),
              onStepContinue: _siguientePaso,
              onStepCancel: _pasoPrevio,
              controlsBuilder: (context, details) {
                // En el paso 3 el botón de guardado vive dentro del contenido
                if (details.currentStep == 2) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      FilledButton(
                        onPressed: details.onStepContinue,
                        child: const Text('Siguiente'),
                      ),
                      if (details.currentStep > 0) ...[
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Anterior'),
                        ),
                      ],
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Datos y Resultado'),
                  subtitle: Text(_estadoInstalacion),
                  isActive: _pasoActual >= 0,
                  state: _pasoActual > 0
                      ? StepState.complete
                      : StepState.indexed,
                  content: _construirPaso1(),
                ),
                Step(
                  title: const Text('Inspección'),
                  subtitle: const Text('Checklist técnico por categorías'),
                  isActive: _pasoActual >= 1,
                  state: _pasoActual > 1
                      ? StepState.complete
                      : StepState.indexed,
                  content: _construirPaso2(),
                ),
                Step(
                  title: const Text('Detalles y Firmas'),
                  isActive: _pasoActual >= 2,
                  content: _construirPaso3(),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

/// Tarjeta con el contexto de la cita en la cabecera del formulario.
class _TarjetaContextoCita extends StatelessWidget {
  final Appointment cita;
  final dynamic cliente;
  final Maquina? maquina;

  const _TarjetaContextoCita(
      {required this.cita, required this.cliente, this.maquina});

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;
    final fechaTexto =
        DateFormat('EEEE d MMMM y  •  HH:mm', 'es_ES').format(cita.fechaHora);

    return Card(
      color: esquema.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(Icons.event_note, size: 14, color: esquema.onPrimaryContainer),
              const SizedBox(width: 6),
              Text('Cita seleccionada',
                  style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: esquema.onPrimaryContainer)),
            ]),
            const SizedBox(height: 6),
            Text(cita.identificacion,
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: esquema.onPrimaryContainer)),
            if (maquina != null) ...[
              const SizedBox(height: 2),
              Text(
                '${maquina!.nombreReferencia}'
                '${maquina!.tipoPuerta.isNotEmpty ? "  ·  ${maquina!.tipoPuerta}" : ""}',
                style: TextStyle(
                    fontSize: 12,
                    color: esquema.onPrimaryContainer.withAlpha(200)),
              ),
            ],
            if (cliente != null) ...[
              const SizedBox(height: 2),
              Text('${cliente!.nombre}  ·  ${cliente!.ciudadCp}',
                  style: TextStyle(
                      fontSize: 12,
                      color: esquema.onPrimaryContainer.withAlpha(180))),
            ],
            const SizedBox(height: 4),
            Text(
              fechaTexto[0].toUpperCase() + fechaTexto.substring(1),
              style: TextStyle(
                  fontSize: 11,
                  color: esquema.onPrimaryContainer.withAlpha(170)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Fila de un ítem del checklist con RadioButtons (Favorable / Desfavorable / N/A).
class _FilaChecklistItem extends StatelessWidget {
  final String item;
  final String valorActual;
  final ValueChanged<String> alCambiar;

  const _FilaChecklistItem({
    required this.item,
    required this.valorActual,
    required this.alCambiar,
  });

  @override
  Widget build(BuildContext context) {
    final esquema = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(
              item,
              style: TextStyle(fontSize: 13, color: esquema.onSurface),
            ),
          ),
          Row(
            children: kValoresChecklist.map((valor) {
              final Color color;
              switch (valor) {
                case 'Favorable':
                  color = Colors.green;
                case 'Desfavorable':
                  color = Colors.red;
                default:
                  color = esquema.outline;
              }
              return Expanded(
                child: RadioListTile<String>(
                  value: valor,
                  // ignore: deprecated_member_use
                  groupValue: valorActual,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  visualDensity: VisualDensity.compact,
                  activeColor: color,
                  // ignore: deprecated_member_use
                  onChanged: (v) {
                    if (v != null) alCambiar(v);
                  },
                  title: Text(
                    valor,
                    style: TextStyle(
                      fontSize: 11,
                      color: valorActual == valor ? color : null,
                      fontWeight: valorActual == valor
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          Divider(height: 1, color: esquema.outlineVariant),
        ],
      ),
    );
  }
}

/// Recuadro de firma digital con lienzo blanco y botón de borrado.
///
/// En modo edición, si [firmaExistente] tiene datos, muestra la firma
/// guardada como preview. El lienzo permite dibujar una nueva firma;
/// si se deja vacío al guardar, se conserva la firma existente.
class _RecuadroFirma extends StatelessWidget {
  final String etiqueta;
  final SignatureController controlador;
  /// Bytes PNG de la firma guardada. Null si es modo creación o sin firma.
  final Uint8List? firmaExistente;

  const _RecuadroFirma({
    required this.etiqueta,
    required this.controlador,
    this.firmaExistente,
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

        // Preview de firma guardada (solo en modo edición)
        if (firmaExistente != null) ...[
          Row(
            children: [
              Icon(Icons.check_circle_outline,
                  size: 14, color: esquema.primary),
              const SizedBox(width: 4),
              Text(
                'Firma guardada (dejar lienzo vacío para conservarla)',
                style: TextStyle(
                    fontSize: 11, color: esquema.outline),
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 70,
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(
                    color: esquema.primary.withAlpha(100), width: 1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Image.memory(
                firmaExistente!,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Nueva firma (opcional):',
            style: TextStyle(fontSize: 11, color: esquema.outline),
          ),
          const SizedBox(height: 4),
        ],

        // Lienzo de firma (siempre visible)
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: 150,
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
            label: const Text('Borrar'),
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
