import 'package:flutter/material.dart';

/// Pantalla principal del módulo de Fichas de Mantenimiento.
/// Mostrará el historial de fichas con filtro por cliente y fecha.
/// Pendiente de implementación completa.
class MaintenanceListScreen extends StatelessWidget {
  const MaintenanceListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Fichas de Mantenimiento')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.build,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Módulo de Mantenimiento',
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
        // TODO: context.push('/maintenance/new')
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nueva Ficha'),
      ),
    );
  }
}
