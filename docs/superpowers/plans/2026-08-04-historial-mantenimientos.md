# Historial de Mantenimientos — Plan de Implementación

> **For agentic workers:** REQUIRED: Use superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Completar el Tab 2 con una pantalla de historial que lista todos los partes de mantenimiento ordenados del más reciente al más antiguo, con indicador visual de estado y botón para regenerar el PDF. Limpiar archivos legacy del proyecto.

**Architecture:** Query SQL con JOIN de 3 tablas (mantenimientos + appointments + clients) que devuelve un DTO `EntradaHistorial`. La pantalla consume un `FutureProvider` simple. Para el PDF se consulta `Maquina?` de forma lazy al pulsar el botón.

**Tech Stack:** Flutter, Riverpod (FutureProvider), SQFlite (rawQuery con JOIN), go_router, pdf+printing, flutter_riverpod.

---

## Chunk 1: Limpieza y rama

### Task 1: Crear rama y eliminar archivos legacy

**Files:**
- Delete: `lib/features/calendar/screens/calendar_screen.dart`
- Delete: `lib/features/clients/screens/clients_list_screen.dart`
- Delete: `lib/features/maintenance/models/maintenance_record.dart`
- Delete: `lib/features/maintenance/screens/maintenance_list_screen.dart`

- [ ] Crear rama desde main:
```bash
git checkout main
git checkout -b feat/historial-mantenimientos
```

- [ ] Verificar que ningún archivo a eliminar es importado por el router o main:
```bash
grep -r "calendar_screen\|clients_list_screen\|maintenance_record\|maintenance_list_screen" lib/
```
Esperado: solo aparecen los propios archivos, no imports externos (el router ya usa `pantalla_mantenimientos` en el stub actual, pero vamos a reemplazarlo).

- [ ] Eliminar los 4 archivos:
```bash
rm lib/features/calendar/screens/calendar_screen.dart
rm lib/features/clients/screens/clients_list_screen.dart
rm lib/features/maintenance/models/maintenance_record.dart
rm lib/features/maintenance/screens/maintenance_list_screen.dart
```

- [ ] Verificar que `flutter analyze` no reporta errores por los archivos eliminados:
```bash
flutter analyze
```

- [ ] Commit:
```bash
git add -A
git commit -m "chore: eliminar archivos legacy reemplazados"
```

---

## Chunk 2: Modelo DTO

### Task 2: Crear EntradaHistorial

**Files:**
- Create: `lib/features/maintenance/models/entrada_historial.dart`

El DTO agrupa los datos de una fila del JOIN (mantenimiento + cita + datos del cliente). Contiene todo lo necesario para mostrar la tarjeta y para llamar a `GeneradorPDF.generarYCompartir`.

- [ ] Crear el archivo con el siguiente contenido:

```dart
import '../../calendar/models/appointment.dart';
import 'mantenimiento.dart';

/// DTO que combina un [Mantenimiento] con los datos de su [Appointment]
/// y del cliente, resultado de un JOIN de 3 tablas.
///
/// Se usa exclusivamente en el historial (Tab 2) para evitar N+1 queries.
class EntradaHistorial {
  final Mantenimiento mantenimiento;
  final Appointment cita;
  final String nombreCliente;
  final String ciudadCliente;

  const EntradaHistorial({
    required this.mantenimiento,
    required this.cita,
    required this.nombreCliente,
    required this.ciudadCliente,
  });

  /// Construye una [EntradaHistorial] desde una fila del JOIN SQL.
  ///
  /// Las columnas de mantenimientos llevan prefijo `m_`, las de appointments
  /// llevan prefijo `a_`, para evitar colisiones de nombres en el JOIN.
  factory EntradaHistorial.fromJoinRow(Map<String, dynamic> fila) {
    final mantenimiento = Mantenimiento(
      id: fila['m_id'] as int?,
      citaId: fila['cita_id'] as int,
      operarioNombre: fila['operario_nombre'] as String,
      detallesTrabajo: fila['detalles_trabajo'] as String,
      observaciones: fila['observaciones'] as String? ?? '',
      firmaTecnico: fila['firma_tecnico'] as String?,
      firmaCliente: fila['firma_cliente'] as String?,
      fechaCreacion:
          DateTime.parse(fila['fecha_creacion'] as String).toLocal(),
      estadoInstalacion: fila['estado_instalacion'] as String? ?? '',
      checklistJson: fila['checklist_json'] as String? ?? '{}',
    );

    final cita = Appointment(
      id: fila['a_id'] as int?,
      clienteId: fila['cliente_id'] as int,
      fechaHora: DateTime.parse(fila['fecha_hora'] as String).toLocal(),
      identificacion: fila['identificacion'] as String,
      periodicidad: fila['periodicidad'] as String,
      estado: fila['a_estado'] as String,
      recurrenciaActiva: (fila['recurrencia_activa'] as int? ?? 1) == 1,
      esGuardia: (fila['es_guardia'] as int? ?? 0) == 1,
      maquinaId: fila['maquina_id'] as int?,
    );

    return EntradaHistorial(
      mantenimiento: mantenimiento,
      cita: cita,
      nombreCliente: fila['nombre_cliente'] as String,
      ciudadCliente: fila['ciudad_cliente'] as String,
    );
  }
}
```

- [ ] Commit:
```bash
git add lib/features/maintenance/models/entrada_historial.dart
git commit -m "feat: añadir DTO EntradaHistorial para JOIN mantenimientos+citas+clientes"
```

---

## Chunk 3: Capa de datos

### Task 3: Añadir obtenerHistorial() al repositorio

**Files:**
- Modify: `lib/features/maintenance/data/repositorio_mantenimientos.dart`

Añadir un método `obtenerHistorial()` que ejecuta el JOIN de 3 tablas y devuelve `List<EntradaHistorial>` ordenada por `fecha_creacion DESC`.

- [ ] Añadir el import del DTO al inicio del archivo (después de los imports existentes):
```dart
import '../models/entrada_historial.dart';
```

- [ ] Añadir el método al final de la clase `RepositorioMantenimientos`, antes del cierre `}`:

```dart
  /// Devuelve todas las entradas del historial con datos de cita y cliente,
  /// ordenadas del más reciente al más antiguo.
  ///
  /// Ejecuta un JOIN de 3 tablas para evitar queries N+1 en la lista.
  Future<List<EntradaHistorial>> obtenerHistorial() async {
    debugPrint('[RepositorioMantenimientos] obtenerHistorial → JOIN 3 tablas');
    try {
      final db = await _gestorBd.database;
      final filas = await db.rawQuery('''
        SELECT
          m.id           AS m_id,
          m.cita_id,
          m.operario_nombre,
          m.detalles_trabajo,
          m.observaciones,
          m.firma_tecnico,
          m.firma_cliente,
          m.fecha_creacion,
          m.estado_instalacion,
          m.checklist_json,
          a.id           AS a_id,
          a.cliente_id,
          a.fecha_hora,
          a.identificacion,
          a.periodicidad,
          a.estado       AS a_estado,
          a.recurrencia_activa,
          a.es_guardia,
          a.maquina_id,
          c.nombre       AS nombre_cliente,
          c.ciudad_cp    AS ciudad_cliente
        FROM mantenimientos m
        JOIN appointments  a ON m.cita_id    = a.id
        JOIN clients       c ON a.cliente_id = c.id
        ORDER BY m.fecha_creacion DESC
      ''');
      final lista = filas.map(EntradaHistorial.fromJoinRow).toList();
      debugPrint(
          '[RepositorioMantenimientos] ✓ ${lista.length} entradas en historial.');
      return lista;
    } catch (e, traza) {
      debugPrint(
          '[RepositorioMantenimientos] ✗ ERROR en obtenerHistorial: $e\n$traza');
      rethrow;
    }
  }
```

- [ ] Commit:
```bash
git add lib/features/maintenance/data/repositorio_mantenimientos.dart
git commit -m "feat: añadir obtenerHistorial() con JOIN mantenimientos+appointments+clients"
```

---

## Chunk 4: Capa de estado (Provider)

### Task 4: Añadir historialMantenimientosProvider

**Files:**
- Modify: `lib/features/maintenance/providers/proveedor_mantenimientos.dart`

Añadir un `FutureProvider` que expone la lista completa de `EntradaHistorial`. Se auto-refresca cuando se invalida.

- [ ] Añadir el import del DTO al inicio del archivo:
```dart
import '../models/entrada_historial.dart';
```

- [ ] Añadir el provider al final del archivo (después de `gestorMantenimientosProvider`):

```dart
// ── Provider: historial completo (Tab 2) ─────────────────────────────────────

/// Carga el historial completo de mantenimientos con datos de cita y cliente.
/// Retorna los partes ordenados del más reciente al más antiguo.
final historialMantenimientosProvider =
    FutureProvider<List<EntradaHistorial>>((ref) async {
  final repositorio = ref.read(repositorioMantenimientosProvider);
  debugPrint('[historialMantenimientosProvider] Cargando historial...');
  final lista = await repositorio.obtenerHistorial();
  debugPrint(
      '[historialMantenimientosProvider] ✓ ${lista.length} entradas cargadas.');
  return lista;
}, name: 'historialMantenimientosProvider');
```

- [ ] Commit:
```bash
git add lib/features/maintenance/providers/proveedor_mantenimientos.dart
git commit -m "feat: añadir historialMantenimientosProvider (FutureProvider)"
```

---

## Chunk 5: Pantalla y router

### Task 5: Crear pantalla_mantenimientos.dart

**Files:**
- Create: `lib/features/maintenance/screens/pantalla_mantenimientos.dart`

Pantalla `ConsumerWidget` que muestra un `ListView.builder` con tarjetas. Cada tarjeta tiene una barra lateral coloreada según `estadoInstalacion` y un botón de PDF.

La lógica de color:
- `'Favorable'` → `Colors.green`
- `'Favorable con observaciones'` → `Colors.orange`
- `'Desfavorable'` → `Colors.red`
- cualquier otro → `Colors.grey`

El botón PDF:
1. Muestra un `CircularProgressIndicator` mientras trabaja.
2. Consulta `Maquina?` desde `gestorMaquinasProvider` si `cita.maquinaId != null`.
3. Llama a `GeneradorPDF.generarYCompartir(...)`.
4. En caso de error muestra un `SnackBar`.

- [ ] Crear el archivo con el siguiente contenido:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../machines/data/repositorio_maquinas.dart';
import '../../machines/models/maquina.dart';
import '../models/entrada_historial.dart';
import '../providers/proveedor_mantenimientos.dart';
import '../services/generador_pdf.dart';

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
          child: Text('Error al cargar el historial:\n$error'),
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
        '[PantallaMantenimientos] _generarPdf → mantenimientoId=${widget.entrada.mantenimiento.id}');
    setState(() => _generandoPdf = true);

    try {
      Maquina? maquina;
      final maquinaId = widget.entrada.cita.maquinaId;
      if (maquinaId != null) {
        debugPrint(
            '[PantallaMantenimientos] Consultando máquina id=$maquinaId...');
        maquina = await RepositorioMaquinas().obtenerMaquinaPorId(maquinaId);
        debugPrint(maquina != null
            ? '[PantallaMantenimientos] ✓ Máquina encontrada: ${maquina.nombreReferencia}'
            : '[PantallaMantenimientos] ⚠ Máquina no encontrada para id=$maquinaId');
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
            // Barra lateral de color según estado
            Container(width: 6, color: colorEstado),

            // Contenido principal
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fila superior: identificación + fecha cita
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

                    // Cliente
                    Text(
                      entrada.nombreCliente,
                      style: Theme.of(context).textTheme.bodyMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),

                    // Fila inferior: operario + chip estado
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
                                  color:
                                      Theme.of(context).colorScheme.outline,
                                ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Chip indicador de estado
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: colorEstado.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: colorEstado.withOpacity(0.5),
                                width: 0.8),
                          ),
                          child: Text(
                            mantenimiento.estadoInstalacion.isNotEmpty
                                ? mantenimiento.estadoInstalacion
                                : 'Sin estado',
                            style:
                                Theme.of(context).textTheme.labelSmall?.copyWith(
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

            // Botón PDF
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _generandoPdf
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
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] Commit:
```bash
git add lib/features/maintenance/screens/pantalla_mantenimientos.dart
git commit -m "feat: crear PantallaMantenimientos con lista de partes y botón PDF"
```

---

### Task 6: Actualizar el router

**Files:**
- Modify: `lib/core/router/app_router.dart`

Reemplazar el import de `maintenance_list_screen.dart` (ya eliminado) por `pantalla_mantenimientos.dart`, y actualizar la ruta del Tab 2.

- [ ] En `app_router.dart`, reemplazar:
```dart
import '../../features/maintenance/screens/maintenance_list_screen.dart';
```
por:
```dart
import '../../features/maintenance/screens/pantalla_mantenimientos.dart';
```

- [ ] En el `ShellRoute`, reemplazar:
```dart
GoRoute(
  path: rutaMantenimiento,
  builder: (context, estado) => const MaintenanceListScreen(),
),
```
por:
```dart
GoRoute(
  path: rutaMantenimiento,
  builder: (context, estado) => const PantallaMantenimientos(),
),
```

- [ ] Verificar que el proyecto compila sin errores:
```bash
flutter analyze
```

- [ ] Commit:
```bash
git add lib/core/router/app_router.dart
git commit -m "chore: conectar Tab 2 a PantallaMantenimientos"
```

---

### Task 7: Verificar que RepositorioMaquinas tiene obtenerMaquinaPorId

**Files:**
- Modify si falta: `lib/features/machines/data/repositorio_maquinas.dart`

La pantalla llama a `RepositorioMaquinas().obtenerMaquinaPorId(maquinaId)`. Verificar que este método existe.

- [ ] Revisar el archivo:
```bash
grep -n "obtenerMaquinaPorId" lib/features/machines/data/repositorio_maquinas.dart
```

- [ ] Si NO existe, añadirlo en `repositorio_maquinas.dart`:
```dart
/// Devuelve la máquina con [id], o null si no existe.
Future<Maquina?> obtenerMaquinaPorId(int id) async {
  debugPrint('[RepositorioMaquinas] obtenerMaquinaPorId → id=$id');
  try {
    final db = await _gestorBd.database;
    final filas = await db.query(
      _tabla,
      where: 'id = ?',
      whereArgs: [id],
      limit: 1,
    );
    if (filas.isEmpty) return null;
    final maquina = Maquina.fromMap(filas.first);
    debugPrint('[RepositorioMaquinas] ✓ Máquina encontrada: ${maquina.nombreReferencia}');
    return maquina;
  } catch (e, traza) {
    debugPrint('[RepositorioMaquinas] ✗ ERROR en obtenerMaquinaPorId: $e\n$traza');
    rethrow;
  }
}
```

- [ ] Commit si se modificó:
```bash
git add lib/features/machines/data/repositorio_maquinas.dart
git commit -m "feat: añadir obtenerMaquinaPorId al repositorio de máquinas"
```

---

### Task 8: Merge a main

- [ ] Mergear y mantener rama:
```bash
git checkout main
git merge feat/historial-mantenimientos
git push origin main
git push origin feat/historial-mantenimientos
```
