import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../machines/data/repositorio_maquinas.dart';
import '../../machines/models/maquina.dart';
import '../models/entrada_historial.dart';
import '../providers/proveedor_mantenimientos.dart';
import '../services/generador_pdf.dart';

/// Pantalla del Tab 2: historial completo de partes de mantenimiento.
///
/// Carga todos los mantenimientos registrados ordenados del más reciente
/// al más antiguo. Cada tarjeta muestra la cita, operario y un indicador
/// visual del resultado de la instalación. El botón de documento regenera
/// y comparte el PDF técnico.
class PantallaMantenimientos extends ConsumerWidget {
  const PantallaMantenimientos({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historialAsync = ref.watch(historialMantenimientosProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Historial de Mantenimientos')),
      body: historialAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Error al cargar el historial:\n$error'),
          ),
        ),
        data: (entradas) {
          if (entradas.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.assignment_outlined,
                    size: 72,
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Sin partes registrados',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Los partes de mantenimiento aparecerán aquí',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            itemCount: entradas.length,
            itemBuilder: (context, indice) =>
                _TarjetaMantenimiento(entrada: entradas[indice]),
          );
        },
      ),
    );
  }
}

// ── Tarjeta individual ────────────────────────────────────────────────────────

class _TarjetaMantenimiento extends ConsumerStatefulWidget {
  const _TarjetaMantenimiento({required this.entrada});
  final EntradaHistorial entrada;

  @override
  ConsumerState<_TarjetaMantenimiento> createState() =>
      _TarjetaMantenimientoState();
}

class _TarjetaMantenimientoState
    extends ConsumerState<_TarjetaMantenimiento> {
  bool _generandoPdf = false;
  bool _compartiendoPdf = false;

  Color _colorEstado(String estado) {
    switch (estado) {
      case 'Favorable':
        return Colors.green;
      case 'Favorable con observaciones':
        return Colors.orange;
      case 'Desfavorable':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _generarPdf() async {
    debugPrint(
        '[PantallaMantenimientos] _generarPdf → '
        'mantenimientoId=${widget.entrada.mantenimiento.id}');
    setState(() => _generandoPdf = true);

    try {
      Maquina? maquina;
      final maquinaId = widget.entrada.cita.maquinaId;
      if (maquinaId != null) {
        debugPrint(
            '[PantallaMantenimientos] Consultando máquina id=$maquinaId...');
        maquina = await RepositorioMaquinas().obtenerMaquina(maquinaId);
        debugPrint(maquina != null
            ? '[PantallaMantenimientos] ✓ Máquina: ${maquina.nombreReferencia}'
            : '[PantallaMantenimientos] ⚠ Máquina no encontrada id=$maquinaId');
      }

      await GeneradorPDF.generarYCompartir(
        mantenimiento: widget.entrada.mantenimiento,
        cita: widget.entrada.cita,
        nombreCliente: widget.entrada.nombreCliente,
        ciudadCliente: widget.entrada.ciudadCliente,
        maquina: maquina,
      );
      debugPrint('[PantallaMantenimientos] ✓ PDF compartido.');
    } catch (e) {
      debugPrint('[PantallaMantenimientos] ✗ Error generando PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al generar el PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _generandoPdf = false);
    }
  }

  Future<void> _compartirPdf() async {
    debugPrint(
        '[PantallaMantenimientos] _compartirPdf → '
        'mantenimientoId=${widget.entrada.mantenimiento.id}');
    setState(() => _compartiendoPdf = true);

    try {
      Maquina? maquina;
      final maquinaId = widget.entrada.cita.maquinaId;
      if (maquinaId != null) {
        maquina = await RepositorioMaquinas().obtenerMaquina(maquinaId);
      }

      // Generar bytes del PDF sin abrir el diálogo de impresión
      final resultado = await GeneradorPDF.generarBytes(
        mantenimiento: widget.entrada.mantenimiento,
        cita: widget.entrada.cita,
        nombreCliente: widget.entrada.nombreCliente,
        ciudadCliente: widget.entrada.ciudadCliente,
        maquina: maquina,
      );

      // Guardar en directorio temporal para poder adjuntarlo
      final dirTemporal = await getTemporaryDirectory();
      final rutaArchivo = '${dirTemporal.path}/${resultado.nombreArchivo}';
      await File(rutaArchivo).writeAsBytes(resultado.bytes);
      debugPrint('[PantallaMantenimientos] ✓ PDF guardado en $rutaArchivo');

      // Abrir menú nativo de compartir (WhatsApp, Gmail, etc.)
      await Share.shareXFiles(
        [XFile(rutaArchivo)],
        text: 'Adjunto informe técnico de mantenimiento.',
      );
      debugPrint('[PantallaMantenimientos] ✓ PDF compartido vía share_plus.');
    } catch (e) {
      debugPrint('[PantallaMantenimientos] ✗ Error al compartir PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al compartir el PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _compartiendoPdf = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entrada = widget.entrada;
    final mantenimiento = entrada.mantenimiento;
    final cita = entrada.cita;
    final colorEstado = _colorEstado(mantenimiento.estadoInstalacion);
    final formatoFecha = DateFormat('dd/MM/yyyy', 'es_ES');

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: IntrinsicHeight(
        child: Row(
          children: [
            // Barra lateral coloreada según resultado de la instalación
            Container(width: 6, color: colorEstado),

            // Contenido principal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila superior: referencia de cita + fecha
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            cita.identificacion,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          formatoFecha.format(cita.fechaHora),
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.outline,
                              ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),

                    // Nombre del cliente
                    Text(
                      entrada.nombreCliente,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 6),

                    // Fila inferior: operario + chip de estado
                    Row(
                      children: [
                        Icon(
                          Icons.person_outline,
                          size: 14,
                          color: Theme.of(context).colorScheme.outline,
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            mantenimiento.operarioNombre,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Chip indicador de estado
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorEstado.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: colorEstado.withValues(alpha: 0.5),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            mantenimiento.estadoInstalacion.isNotEmpty
                                ? mantenimiento.estadoInstalacion
                                : 'Sin estado',
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: colorEstado,
                                  fontWeight: FontWeight.w600,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Botones de acción: ver PDF y compartir
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Ver / imprimir PDF
                _generandoPdf
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.picture_as_pdf_outlined),
                        tooltip: 'Ver PDF',
                        onPressed: _generarPdf,
                      ),
                // Compartir PDF (WhatsApp, Email, etc.)
                _compartiendoPdf
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : IconButton(
                        icon: const Icon(Icons.share_outlined),
                        tooltip: 'Compartir PDF',
                        onPressed: _compartirPdf,
                      ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
