import 'package:flutter/material.dart';

/// Pantalla principal del módulo de Clientes.
/// Mostrará el listado de clientes con opciones de búsqueda y CRUD.
/// Pendiente de implementación completa.
class ClientsListScreen extends StatelessWidget {
  const ClientsListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Clientes')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Módulo de Clientes',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Pendiente de desarrollo',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        // TODO: context.push('/clients/new')
        onPressed: () {},
        icon: const Icon(Icons.person_add),
        label: const Text('Nuevo Cliente'),
      ),
    );
  }
}
