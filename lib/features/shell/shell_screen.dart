import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';

/// Shell que envuelve cada pestaña con la [NavigationBar] de Material 3.
///
/// go_router mantiene el estado de cada tab gracias al [ShellRoute]:
/// al volver a una pestaña, el scroll y los widgets internos se conservan.
class ShellScreen extends StatelessWidget {
  final Widget child;

  const ShellScreen({super.key, required this.child});

  /// Calcula el índice activo comparando la ruta actual con las rutas raíz.
  int _indiceActivo(BuildContext context) {
    final ruta = GoRouterState.of(context).uri.path;
    if (ruta.startsWith(rutaClientes)) return 1;
    if (ruta.startsWith(rutaMantenimiento)) return 2;
    if (ruta.startsWith(rutaPlantillas)) return 3;
    return 0; // Calendario por defecto
  }

  /// Navega a la ruta raíz de la pestaña seleccionada.
  void _alSeleccionar(BuildContext context, int indice) {
    switch (indice) {
      case 0:
        context.go(rutaCalendario);
      case 1:
        context.go(rutaClientes);
      case 2:
        context.go(rutaMantenimiento);
      case 3:
        context.go(rutaPlantillas);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: child,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _indiceActivo(context),
        onDestinationSelected: (indice) => _alSeleccionar(context, indice),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month),
            label: 'Calendario',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline),
            selectedIcon: Icon(Icons.people),
            label: 'Clientes',
          ),
          NavigationDestination(
            icon: Icon(Icons.build_outlined),
            selectedIcon: Icon(Icons.build),
            label: 'Mantenimiento',
          ),
          NavigationDestination(
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
            label: 'Plantillas',
          ),
        ],
      ),
    );
  }
}
