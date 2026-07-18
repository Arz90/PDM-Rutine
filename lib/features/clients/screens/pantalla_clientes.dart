import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../models/client.dart';
import '../providers/proveedor_clientes.dart';

/// Pantalla principal del módulo de Clientes.
///
/// Muestra la lista filtrable de todos los clientes registrados.
/// Desde aquí se puede crear, editar y eliminar clientes.
class PantallaClientes extends ConsumerStatefulWidget {
  const PantallaClientes({super.key});

  @override
  ConsumerState<PantallaClientes> createState() => _EstadoPantallaClientes();
}

class _EstadoPantallaClientes extends ConsumerState<PantallaClientes> {
  final TextEditingController _controladorBusqueda = TextEditingController();

  @override
  void dispose() {
    _controladorBusqueda.dispose();
    // Limpia el texto de búsqueda al salir de la pantalla
    super.dispose();
  }

  /// Limpia el campo de búsqueda y resetea el provider.
  void _limpiarBusqueda() {
    _controladorBusqueda.clear();
    ref.read(textoBusquedaClientesProvider.notifier).state = '';
  }

  @override
  Widget build(BuildContext context) {
    final listaAsync = ref.watch(clientesFiltradosProvider);
    final textoBusqueda = ref.watch(textoBusquedaClientesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Clientes'),
        // Campo de búsqueda integrado en el AppBar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _controladorBusqueda,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o ciudad…',
                prefixIcon: const Icon(Icons.search),
                // Botón de limpiar solo visible cuando hay texto
                suffixIcon: textoBusqueda.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        tooltip: 'Limpiar búsqueda',
                        onPressed: _limpiarBusqueda,
                      )
                    : null,
              ),
              onChanged: (valor) {
                ref.read(textoBusquedaClientesProvider.notifier).state = valor;
              },
            ),
          ),
        ),
      ),
      body: listaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, traza) => _VistaError(
          mensaje: error.toString(),
          alReintentar: () => ref.invalidate(gestorClientesProvider),
        ),
        data: (clientes) => clientes.isEmpty
            ? _VistaVacia(busquedaActiva: textoBusqueda.isNotEmpty)
            : _ListaClientes(clientes: clientes),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(rutaFormularioCliente),
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Cliente'),
      ),
    );
  }
}

// ── Widgets privados ──────────────────────────────────────────────────────────

/// Construye el [ListView] con una tarjeta por cada cliente.
class _ListaClientes extends StatelessWidget {
  final List<Client> clientes;

  const _ListaClientes({required this.clientes});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100), // margen para el FAB
      itemCount: clientes.length,
      itemBuilder: (context, indice) =>
          _TarjetaCliente(cliente: clientes[indice]),
    );
  }
}

/// Tarjeta visual de un cliente con menú contextual para editar/eliminar.
class _TarjetaCliente extends ConsumerWidget {
  final Client cliente;

  const _TarjetaCliente({required this.cliente});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final esquema = Theme.of(context).colorScheme;
    final estiloTexto = Theme.of(context).textTheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        // Avatar con la inicial del nombre del cliente
        leading: CircleAvatar(
          backgroundColor: esquema.primaryContainer,
          child: Text(
            cliente.nombre.isNotEmpty ? cliente.nombre[0].toUpperCase() : '?',
            style: TextStyle(
              color: esquema.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        title: Text(
          cliente.nombre,
          style: estiloTexto.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(cliente.ciudadCp),
            if (cliente.nifCif != null)
              Text(
                cliente.nifCif!,
                style: TextStyle(
                    color: esquema.outline, fontSize: 12),
              ),
          ],
        ),
        isThreeLine: cliente.nifCif != null,
        // Menú de opciones (editar / eliminar)
        trailing: PopupMenuButton<String>(
          tooltip: 'Opciones',
          onSelected: (opcion) =>
              _gestionarOpcion(context, ref, opcion),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'editar',
              child: ListTile(
                leading: Icon(Icons.edit),
                title: Text('Editar'),
                contentPadding: EdgeInsets.zero,
              ),
            ),
            PopupMenuItem(
              value: 'eliminar',
              child: ListTile(
                leading: Icon(Icons.delete,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Eliminar',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.error)),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ],
        ),
        onTap: () => context.push(rutaFormularioCliente, extra: cliente),
      ),
    );
  }

  /// Gestiona la opción seleccionada en el menú contextual.
  Future<void> _gestionarOpcion(
      BuildContext context, WidgetRef ref, String opcion) async {
    if (opcion == 'editar') {
      context.push(rutaFormularioCliente, extra: cliente);
      return;
    }

    if (opcion == 'eliminar') {
      final confirmado = await _mostrarDialogoEliminacion(context);
      if (confirmado == true && cliente.id != null) {
        await ref
            .read(gestorClientesProvider.notifier)
            .eliminarCliente(cliente.id!);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('"${cliente.nombre}" eliminado correctamente.'),
              action: SnackBarAction(
                label: 'OK',
                onPressed: () {},
              ),
            ),
          );
        }
      }
    }
  }

  /// Muestra un diálogo de confirmación antes de eliminar.
  Future<bool?> _mostrarDialogoEliminacion(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(Icons.warning_amber,
            color: Theme.of(ctx).colorScheme.error, size: 40),
        title: const Text('Eliminar cliente'),
        content: Text(
          '¿Seguro que deseas eliminar a "${cliente.nombre}"?\n\n'
          'Se borrarán también todas sus citas y fichas de mantenimiento asociadas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }
}

/// Pantalla vacía cuando no hay resultados.
class _VistaVacia extends StatelessWidget {
  /// Indica si el vacío se debe a una búsqueda sin resultados.
  final bool busquedaActiva;

  const _VistaVacia({this.busquedaActiva = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              busquedaActiva ? Icons.search_off : Icons.people_outline,
              size: 80,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              busquedaActiva
                  ? 'Sin resultados'
                  : 'Aún no hay clientes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              busquedaActiva
                  ? 'Prueba con otro nombre o ciudad.'
                  : 'Pulsa el botón "+" para añadir el primero.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: Theme.of(context).colorScheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pantalla de error con botón para reintentar la carga.
class _VistaError extends StatelessWidget {
  final String mensaje;
  final VoidCallback alReintentar;

  const _VistaError({required this.mensaje, required this.alReintentar});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline,
                size: 64, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Error al cargar los clientes',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              mensaje,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 12),
            ),
            const SizedBox(height: 24),
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
