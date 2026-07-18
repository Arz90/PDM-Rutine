import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../calendar/models/appointment.dart';
import '../models/mantenimiento.dart';

/// Servicio estático que genera un PDF en formato A4 a partir de un [Mantenimiento]
/// y lo abre en el menú nativo de compartir del dispositivo.
class GeneradorPDF {
  GeneradorPDF._(); // No instanciable

  // ── Colores corporativos ───────────────────────────────────────────────────
  static const _colorCabecera = PdfColor.fromInt(0xFF1A237E); // azul oscuro
  static const _colorSubcabecera = PdfColor.fromInt(0xFF283593);
  static const _colorFondoFila = PdfColor.fromInt(0xFFE8EAF6);
  static const _colorTextoSec = PdfColor.fromInt(0xFF37474F);

  /// Genera el documento PDF y abre el menú de compartir de Android/iOS.
  static Future<void> generarYCompartir({
    required Mantenimiento mantenimiento,
    required Appointment cita,
    required String nombreCliente,
    required String ciudadCliente,
  }) async {
    debugPrint('[GeneradorPDF] Iniciando generación del PDF...');

    final formatoFechaHora =
        DateFormat('dd/MM/yyyy  HH:mm', 'es_ES');
    final fechaCitaTexto =
        formatoFechaHora.format(cita.fechaHora);
    final fechaParteTexto =
        formatoFechaHora.format(mantenimiento.fechaCreacion);

    // Decodificar firmas desde Base64 → bytes PNG
    pw.MemoryImage? imagenFirmaTecnico;
    pw.MemoryImage? imagenFirmaCliente;

    if (mantenimiento.firmaTecnico?.isNotEmpty == true) {
      imagenFirmaTecnico =
          pw.MemoryImage(base64Decode(mantenimiento.firmaTecnico!));
    }
    if (mantenimiento.firmaCliente?.isNotEmpty == true) {
      imagenFirmaCliente =
          pw.MemoryImage(base64Decode(mantenimiento.firmaCliente!));
    }

    final doc = pw.Document(
      title: 'Parte de Mantenimiento',
      author: mantenimiento.operarioNombre,
    );

    doc.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            // ── Cabecera ──────────────────────────────────────────────────────
            _construirCabecera(fechaParteTexto),
            pw.SizedBox(height: 18),

            // ── Datos del cliente e instalación ───────────────────────────────
            _construirTituloSeccion('DATOS DEL CLIENTE / INSTALACIÓN'),
            pw.SizedBox(height: 6),
            _construirTabla([
              ['Cliente', nombreCliente],
              ['Ciudad / C.P.', ciudadCliente],
              ['Instalación / Referencia', cita.identificacion],
              ['Fecha de la visita', fechaCitaTexto],
              ['Periodicidad', cita.periodicidad],
              ['Operario', mantenimiento.operarioNombre],
            ]),
            pw.SizedBox(height: 14),

            // ── Trabajo realizado ─────────────────────────────────────────────
            _construirTituloSeccion('TRABAJO REALIZADO'),
            pw.SizedBox(height: 6),
            _construirBloqueTexto(mantenimiento.detallesTrabajo),
            pw.SizedBox(height: 14),

            // ── Observaciones ─────────────────────────────────────────────────
            _construirTituloSeccion('OBSERVACIONES / ANOMALÍAS DETECTADAS'),
            pw.SizedBox(height: 6),
            _construirBloqueTexto(
              mantenimiento.observaciones.isEmpty
                  ? 'Sin observaciones.'
                  : mantenimiento.observaciones,
            ),

            pw.Spacer(),

            // ── Firmas ────────────────────────────────────────────────────────
            pw.Divider(color: _colorCabecera, thickness: 0.5),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceEvenly,
              children: [
                _construirBloqueFirma(
                  'Firma del Técnico',
                  mantenimiento.operarioNombre,
                  imagenFirmaTecnico,
                ),
                _construirBloqueFirma(
                  'Firma del Cliente / Responsable',
                  nombreCliente,
                  imagenFirmaCliente,
                ),
              ],
            ),
          ],
        ),
      ),
    );

    final bytes = await doc.save();
    debugPrint('[GeneradorPDF] ✓ PDF generado (${bytes.length} bytes). Compartiendo...');

    final nombreArchivo =
        'parte_mant_${mantenimiento.id}_'
        '${DateFormat('yyyyMMdd').format(mantenimiento.fechaCreacion)}.pdf';

    await Printing.sharePdf(bytes: bytes, filename: nombreArchivo);
    debugPrint('[GeneradorPDF] ✓ PDF compartido correctamente.');
  }

  // ── Widgets internos del PDF ───────────────────────────────────────────────

  static pw.Widget _construirCabecera(String fechaTexto) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: const pw.BoxDecoration(color: _colorCabecera),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            'PARTE DE TRABAJO Y MANTENIMIENTO',
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 17,
              color: PdfColors.white,
            ),
            textAlign: pw.TextAlign.center,
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            'Fecha del parte: $fechaTexto',
            style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 9,
              color: PdfColors.blueGrey100,
            ),
            textAlign: pw.TextAlign.center,
          ),
        ],
      ),
    );
  }

  static pw.Widget _construirTituloSeccion(String titulo) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: const pw.BoxDecoration(color: _colorSubcabecera),
      child: pw.Text(
        titulo,
        style: pw.TextStyle(
          font: pw.Font.helveticaBold(),
          fontSize: 9,
          color: PdfColors.white,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  /// Tabla de dos columnas: etiqueta (izquierda) y valor (derecha).
  static pw.Widget _construirTabla(List<List<String>> filas) {
    return pw.Table(
      columnWidths: {
        0: const pw.FlexColumnWidth(1.8),
        1: const pw.FlexColumnWidth(3.2),
      },
      children: filas.asMap().entries.map((entrada) {
        final fondo =
            entrada.key.isEven ? _colorFondoFila : PdfColors.white;
        return pw.TableRow(
          decoration: pw.BoxDecoration(color: fondo),
          children: [
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              child: pw.Text(
                entrada.value[0],
                style: pw.TextStyle(
                    font: pw.Font.helveticaBold(), fontSize: 9),
              ),
            ),
            pw.Padding(
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
              child: pw.Text(
                entrada.value[1],
                style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 9,
                    color: _colorTextoSec),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }

  static pw.Widget _construirBloqueTexto(String texto) {
    return pw.Container(
      width: double.infinity,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
        color: PdfColors.white,
      ),
      child: pw.Text(
        texto,
        style: pw.TextStyle(
            font: pw.Font.helvetica(),
            fontSize: 9,
            lineSpacing: 2,
            color: _colorTextoSec),
      ),
    );
  }

  static pw.Widget _construirBloqueFirma(
    String titulo,
    String nombreFirmante,
    pw.MemoryImage? imagen,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        // Recuadro de la firma
        pw.Container(
          width: 200,
          height: 70,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.5),
            borderRadius:
                const pw.BorderRadius.all(pw.Radius.circular(4)),
            color: PdfColors.white,
          ),
          alignment: pw.Alignment.center,
          child: imagen != null
              ? pw.Image(imagen, fit: pw.BoxFit.contain)
              : pw.Text(
                  'Sin firma',
                  style: pw.TextStyle(
                      font: pw.Font.helvetica(),
                      fontSize: 8,
                      color: PdfColors.blueGrey300),
                ),
        ),
        pw.SizedBox(height: 4),
        pw.Text(
          titulo,
          style: pw.TextStyle(
              font: pw.Font.helveticaBold(), fontSize: 8),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          nombreFirmante,
          style: pw.TextStyle(
              font: pw.Font.helvetica(),
              fontSize: 8,
              color: _colorTextoSec),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }
}
