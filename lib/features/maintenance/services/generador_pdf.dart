import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../calendar/models/appointment.dart';
import '../../machines/models/maquina.dart';
import '../models/mantenimiento.dart';

/// Servicio estático que genera un PDF A4 a partir de un [Mantenimiento]
/// y lo abre en el menú nativo de compartir del dispositivo.
class GeneradorPDF {
  GeneradorPDF._(); // No instanciable

  // ── Colores corporativos ───────────────────────────────────────────────────
  static const _colorCabecera = PdfColor.fromInt(0xFF1A237E); // azul oscuro
  static const _colorSubcabecera = PdfColor.fromInt(0xFF283593);
  static const _colorFondoFila = PdfColor.fromInt(0xFFE8EAF6);
  static const _colorTextoSec = PdfColor.fromInt(0xFF37474F);
  static const _colorVerde = PdfColor.fromInt(0xFF2E7D32);
  static const _colorNaranja = PdfColor.fromInt(0xFFE65100);
  static const _colorRojo = PdfColor.fromInt(0xFFC62828);

  /// Genera el documento PDF y devuelve los bytes junto al nombre de archivo.
  ///
  /// Método base usado tanto por [generarYCompartir] (visualización/impresión)
  /// como por la función de compartir vía share_plus (WhatsApp, Email, etc.).
  static Future<({Uint8List bytes, String nombreArchivo})> generarBytes({
    required Mantenimiento mantenimiento,
    required Appointment cita,
    required String nombreCliente,
    required String ciudadCliente,
    Maquina? maquina,
  }) async {
    debugPrint('[GeneradorPDF] generarBytes → construyendo documento...');

    final formatoFechaHora = DateFormat('dd/MM/yyyy  HH:mm', 'es_ES');
    final fechaCitaTexto = formatoFechaHora.format(cita.fechaHora);
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

    // Decodificar checklist desde JSON
    Map<String, Map<String, String>> checklist = {};
    if (mantenimiento.checklistJson.isNotEmpty &&
        mantenimiento.checklistJson != '{}') {
      try {
        final decoded =
            jsonDecode(mantenimiento.checklistJson) as Map<String, dynamic>;
        checklist = decoded.map((cat, items) => MapEntry(
              cat,
              (items as Map<String, dynamic>).cast<String, String>(),
            ));
      } catch (e) {
        debugPrint('[GeneradorPDF] ⚠ Error al decodificar checklistJson: $e');
      }
    }

    final doc = pw.Document(
      title: 'Parte de Mantenimiento',
      author: mantenimiento.operarioNombre,
    );

    // MultiPage para manejar el desbordamiento de contenido
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 36, vertical: 32),
        build: (ctx) => [
          // ── Cabecera ────────────────────────────────────────────────────────
          _construirCabecera(fechaParteTexto),
          pw.SizedBox(height: 18),

          // ── Datos del cliente / instalación ─────────────────────────────────
          _construirTituloSeccion('DATOS DEL CLIENTE / INSTALACIÓN'),
          pw.SizedBox(height: 6),
          _construirTabla([
            ['Cliente', nombreCliente],
            ['Ciudad / C.P.', ciudadCliente],
            ['Referencia de cita', cita.identificacion],
            ['Fecha de la visita', fechaCitaTexto],
            ['Periodicidad', cita.periodicidad],
            ['Operario', mantenimiento.operarioNombre],
          ]),

          // ── Datos de la máquina (si existe) ──────────────────────────────
          if (maquina != null) ...[
            pw.SizedBox(height: 14),
            _construirTituloSeccion('MÁQUINA / INSTALACIÓN'),
            pw.SizedBox(height: 6),
            _construirTabla([
              ['Referencia', maquina.nombreReferencia],
              if (maquina.tipoPuerta.isNotEmpty)
                ['Tipo de puerta', maquina.tipoPuerta],
              if (maquina.fabricante.isNotEmpty)
                ['Fabricante', maquina.fabricante],
              if (maquina.modelo.isNotEmpty) ['Modelo', maquina.modelo],
              if (maquina.serie.isNotEmpty)
                ['Nº de serie', maquina.serie],
            ]),
          ],

          pw.SizedBox(height: 14),

          // ── Resultado global de la instalación ───────────────────────────
          _construirResultadoInstalacion(mantenimiento.estadoInstalacion),
          pw.SizedBox(height: 14),

          // ── Trabajo realizado ────────────────────────────────────────────
          _construirTituloSeccion('TRABAJO REALIZADO'),
          pw.SizedBox(height: 6),
          _construirBloqueTexto(mantenimiento.detallesTrabajo.isNotEmpty
              ? mantenimiento.detallesTrabajo
              : '—'),
          pw.SizedBox(height: 14),

          // ── Observaciones / Acciones correctivas ─────────────────────────
          _construirTituloSeccion('OBSERVACIONES / ACCIONES CORRECTIVAS'),
          pw.SizedBox(height: 6),
          _construirBloqueTexto(mantenimiento.observaciones.isNotEmpty
              ? mantenimiento.observaciones
              : 'Sin observaciones.'),

          // ── Checklist de inspección ──────────────────────────────────────
          if (checklist.isNotEmpty) ...[
            pw.SizedBox(height: 14),
            _construirTituloSeccion('INSPECCIÓN TÉCNICA'),
            pw.SizedBox(height: 6),
            ...checklist.entries.map((cat) => _construirSeccionChecklist(
                  cat.key,
                  cat.value,
                )),
          ],

          pw.SizedBox(height: 14),

          // ── Firmas ───────────────────────────────────────────────────────
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
    );

    final bytes = await doc.save();
    final nombreArchivo =
        'parte_mant_${mantenimiento.id}_'
        '${DateFormat('yyyyMMdd').format(mantenimiento.fechaCreacion)}.pdf';

    debugPrint(
        '[GeneradorPDF] ✓ PDF generado (${bytes.length} bytes) → $nombreArchivo');
    return (bytes: bytes, nombreArchivo: nombreArchivo);
  }

  /// Genera el documento PDF y abre el menú nativo de visualización/impresión.
  static Future<void> generarYCompartir({
    required Mantenimiento mantenimiento,
    required Appointment cita,
    required String nombreCliente,
    required String ciudadCliente,
    Maquina? maquina,
  }) async {
    debugPrint('[GeneradorPDF] generarYCompartir → iniciando...');
    final resultado = await generarBytes(
      mantenimiento: mantenimiento,
      cita: cita,
      nombreCliente: nombreCliente,
      ciudadCliente: ciudadCliente,
      maquina: maquina,
    );
    await Printing.sharePdf(
        bytes: resultado.bytes, filename: resultado.nombreArchivo);
    debugPrint('[GeneradorPDF] ✓ PDF compartido correctamente.');
  }

  // ── Widgets internos del PDF ───────────────────────────────────────────────

  static pw.Widget _construirCabecera(String fechaTexto) {
    return pw.Container(
      width: double.infinity,
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
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

  /// Muestra el resultado de la inspección con un color indicativo.
  static pw.Widget _construirResultadoInstalacion(String estado) {
    final PdfColor colorFondo;
    final PdfColor colorTexto;
    final String icono;

    switch (estado) {
      case 'Favorable':
        colorFondo = _colorVerde;
        colorTexto = PdfColors.white;
        icono = '✓';
      case 'Favorable con observaciones':
        colorFondo = _colorNaranja;
        colorTexto = PdfColors.white;
        icono = '⚠';
      case 'Desfavorable':
        colorFondo = _colorRojo;
        colorTexto = PdfColors.white;
        icono = '✗';
      default:
        colorFondo = PdfColors.grey300;
        colorTexto = _colorTextoSec;
        icono = '–';
    }

    return pw.Container(
      width: double.infinity,
      padding:
          const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: pw.BoxDecoration(
        color: colorFondo,
        borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
      ),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            icono,
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 16,
              color: colorTexto,
            ),
          ),
          pw.SizedBox(width: 10),
          pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'RESULTADO DE LA INSPECCIÓN',
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: 8,
                  color: colorTexto,
                  letterSpacing: 0.5,
                ),
              ),
              pw.Text(
                estado.isNotEmpty ? estado.toUpperCase() : '—',
                style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 14,
                  color: colorTexto,
                ),
              ),
            ],
          ),
        ],
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
        border:
            pw.Border.all(color: PdfColors.blueGrey200, width: 0.5),
        borderRadius:
            const pw.BorderRadius.all(pw.Radius.circular(4)),
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

  /// Tabla de checklist para una categoría completa.
  static pw.Widget _construirSeccionChecklist(
    String categoria,
    Map<String, String> items,
  ) {
    final filas = items.entries.toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Cabecera de categoría
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          color: _colorFondoFila,
          child: pw.Text(
            categoria.toUpperCase(),
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 8,
              color: _colorSubcabecera,
              letterSpacing: 0.5,
            ),
          ),
        ),
        // Filas de ítems
        pw.Table(
          columnWidths: {
            0: const pw.FlexColumnWidth(4),
            1: const pw.FlexColumnWidth(1.5),
          },
          border: pw.TableBorder(
            horizontalInside: pw.BorderSide(
                color: PdfColors.blueGrey100, width: 0.3),
          ),
          children: filas.asMap().entries.map((entrada) {
            final item = entrada.value.key;
            final valor = entrada.value.value;
            final PdfColor colorValor;
            switch (valor) {
              case 'Favorable':
                colorValor = _colorVerde;
              case 'Desfavorable':
                colorValor = _colorRojo;
              default:
                colorValor = _colorTextoSec;
            }
            final fondo =
                entrada.key.isEven ? PdfColors.white : _colorFondoFila;
            return pw.TableRow(
              decoration: pw.BoxDecoration(color: fondo),
              children: [
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: pw.Text(item,
                      style: pw.TextStyle(
                          font: pw.Font.helvetica(),
                          fontSize: 8,
                          color: _colorTextoSec)),
                ),
                pw.Padding(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  child: pw.Text(valor,
                      style: pw.TextStyle(
                          font: pw.Font.helveticaBold(),
                          fontSize: 8,
                          color: colorValor)),
                ),
              ],
            );
          }).toList(),
        ),
        pw.SizedBox(height: 8),
      ],
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
          style:
              pw.TextStyle(font: pw.Font.helveticaBold(), fontSize: 8),
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
