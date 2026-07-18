import 'package:flutter/material.dart';

/// Pantalla principal del módulo de Plantillas.
/// Mostrará las plantillas guardadas para reutilizar en nuevas fichas.
/// Pendiente de implementación completa.
class TemplatesListScreen extends StatelessWidget {
  const TemplatesListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Plantillas')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.description,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Módulo de Plantillas',
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
        // TODO: context.push('/templates/new')
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nueva Plantilla'),
      ),
    );
  }
}
