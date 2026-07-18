import 'package:flutter/material.dart';

/// Pantalla principal del módulo de Calendario.
/// Mostrará un calendario mensual (table_calendar) con las citas programadas.
/// Pendiente de implementación completa.
class CalendarScreen extends StatelessWidget {
  const CalendarScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Calendario')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_month,
              size: 72,
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
            const SizedBox(height: 16),
            Text(
              'Módulo de Calendario',
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
        // TODO: context.push('/calendar/new-appointment')
        onPressed: () {},
        icon: const Icon(Icons.add),
        label: const Text('Nueva Cita'),
      ),
    );
  }
}
