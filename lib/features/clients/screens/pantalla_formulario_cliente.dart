import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/client.dart';
import '../providers/proveedor_clientes.dart';

/// Formulario para crear o editar un cliente.
///
/// Si [clienteExistente] es null → modo creación (nuevo cliente).
/// Si [clienteExistente] tiene valor → modo edición (modifica el existente).
///
/// Al guardar correctamente, muestra un SnackBar de confirmación
/// y regresa a la pantalla anterior con [context.pop()].
class PantallaFormularioCliente extends ConsumerStatefulWidget {
  final Client? clienteExistente;

  const PantallaFormularioCliente({super.key, this.clienteExistente});

  @override
  ConsumerState<PantallaFormularioCliente> createState() =>
      _EstadoFormularioCliente();
}

class _EstadoFormularioCliente
    extends ConsumerState<PantallaFormularioCliente> {
  // Clave global para acceder al estado de validación del formulario
  final GlobalKey<FormState> _claveFormulario = GlobalKey<FormState>();

  // Controla si el botón de guardar muestra un indicador de carga
  bool _guardando = false;

  // ── Controladores de texto ──────────────────────────────────────────────────
  late final TextEditingController _ctrlNombre;
  late final TextEditingController _ctrlNifCif;
  late final TextEditingController _ctrlDireccion;
  late final TextEditingController _ctrlCiudadCp;

  bool get _esEdicion => widget.clienteExistente != null;

  @override
  void initState() {
    super.initState();
    // Pre-rellena los campos si estamos editando un cliente existente
    final c = widget.clienteExistente;
    _ctrlNombre = TextEditingController(text: c?.nombre ?? '');
    _ctrlNifCif = TextEditingController(text: c?.nifCif ?? '');
    _ctrlDireccion = TextEditingController(text: c?.direccion ?? '');
    _ctrlCiudadCp = TextEditingController(text: c?.ciudadCp ?? '');

    debugPrint(
        '[FormularioCliente] initState → modo: ${_esEdicion ? "EDICIÓN (id=${c?.id})" : "CREACIÓN"}');
  }

  @override
  void dispose() {
    _ctrlNombre.dispose();
    _ctrlNifCif.dispose();
    _ctrlDireccion.dispose();
    _ctrlCiudadCp.dispose();
    super.dispose();
  }

  // ── Lógica de guardado ──────────────────────────────────────────────────────

  /// Valida el formulario y llama al gestor de Riverpod para guardar.
  Future<void> _guardar() async {
    // Dispara la validación de todos los campos
    final formularioValido = _claveFormulario.currentState?.validate() ?? false;
    if (!formularioValido) {
      debugPrint('[FormularioCliente] Validación fallida → no se guarda.');
      return;
    }

    setState(() => _guardando = true);
    debugPrint('[FormularioCliente] Iniciando proceso de guardado...');

    try {
      final gestor = ref.read(gestorClientesProvider.notifier);

      // Auxiliar: convierte texto vacío a null para campos opcionales
      String? vaciableANulo(String texto) =>
          texto.trim().isEmpty ? null : texto.trim();

      if (_esEdicion) {
        // ── MODO EDICIÓN ──────────────────────────────────────────────────────
        final clienteActualizado = widget.clienteExistente!.copyWith(
          nombre: _ctrlNombre.text.trim(),
          nifCif: vaciableANulo(_ctrlNifCif.text),
          clearNifCif: _ctrlNifCif.text.trim().isEmpty,
          direccion: _ctrlDireccion.text.trim(),
          ciudadCp: _ctrlCiudadCp.text.trim(),
          // coordenadas: se gestiona desde la vista de detalle, no desde el formulario
          clearCoordenadas: true,
        );
        debugPrint(
            '[FormularioCliente] Datos a actualizar: ${clienteActualizado.toMap()}');
        await gestor.modificarCliente(clienteActualizado);
      } else {
        // ── MODO CREACIÓN ─────────────────────────────────────────────────────
        final nuevoCliente = Client(
          nombre: _ctrlNombre.text.trim(),
          nifCif: vaciableANulo(_ctrlNifCif.text),
          direccion: _ctrlDireccion.text.trim(),
          ciudadCp: _ctrlCiudadCp.text.trim(),
          // coordenadas: null → se asignará desde la vista de detalle (Google Maps)
        );
        debugPrint(
            '[FormularioCliente] Datos a insertar: ${nuevoCliente.toMap()}');
        await gestor.agregarCliente(nuevoCliente);
      }

      debugPrint('[FormularioCliente] ✓ Guardado exitoso.');

      // Muestra confirmación y vuelve atrás
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _esEdicion
                  ? '✓ Cliente actualizado correctamente.'
                  : '✓ Cliente añadido correctamente.',
            ),
            backgroundColor: Theme.of(context).colorScheme.primary,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
    } catch (e, traza) {
      debugPrint('[FormularioCliente] ✗ ERROR al guardar: $e\n$traza');
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

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_esEdicion ? 'Editar Cliente' : 'Nuevo Cliente'),
      ),
      body: Form(
        key: _claveFormulario,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Nombre (obligatorio) ────────────────────────────────────────
            _CampoFormulario(
              controlador: _ctrlNombre,
              etiqueta: 'Nombre *',
              icono: Icons.person_outline,
              validador: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'El nombre del cliente es obligatorio.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── NIF / CIF (opcional) ────────────────────────────────────────
            _CampoFormulario(
              controlador: _ctrlNifCif,
              etiqueta: 'NIF / CIF',
              icono: Icons.badge_outlined,
              capitalizacion: TextCapitalization.characters,
            ),
            const SizedBox(height: 16),

            // ── Dirección (obligatoria) ─────────────────────────────────────
            _CampoFormulario(
              controlador: _ctrlDireccion,
              etiqueta: 'Dirección *',
              icono: Icons.location_on_outlined,
              validador: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'La dirección es obligatoria.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // ── Ciudad / C.P. (obligatorio) ─────────────────────────────────
            _CampoFormulario(
              controlador: _ctrlCiudadCp,
              etiqueta: 'Ciudad / C.P. *',
              icono: Icons.location_city_outlined,
              validador: (valor) {
                if (valor == null || valor.trim().isEmpty) {
                  return 'La ciudad/código postal es obligatoria.';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

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
                  : const Icon(Icons.save_outlined),
              label: Text(_guardando ? 'Guardando…' : 'Guardar Cliente'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Widget reutilizable ───────────────────────────────────────────────────────

/// Campo de texto estilizado para usar dentro del formulario de cliente.
class _CampoFormulario extends StatelessWidget {
  final TextEditingController controlador;
  final String etiqueta;
  final IconData icono;
  final String? Function(String?)? validador;
  final TextCapitalization capitalizacion;

  const _CampoFormulario({
    required this.controlador,
    required this.etiqueta,
    required this.icono,
    this.validador,
    this.capitalizacion = TextCapitalization.sentences,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controlador,
      textCapitalization: capitalizacion,
      decoration: InputDecoration(
        labelText: etiqueta,
        prefixIcon: Icon(icono),
        // Reserva espacio para que el formulario no "salte" al mostrar errores
        helperMaxLines: 2,
        errorMaxLines: 2,
      ),
      validator: validador,
    );
  }
}
