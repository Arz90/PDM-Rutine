import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/calendar/models/appointment.dart';
import '../../features/calendar/screens/pantalla_calendario.dart';
import '../../features/calendar/screens/pantalla_formulario_cita.dart';
import '../../features/clients/models/client.dart';
import '../../features/clients/screens/pantalla_clientes.dart';
import '../../features/clients/screens/pantalla_formulario_cliente.dart';
import '../../features/maintenance/screens/pantalla_mantenimientos.dart';
import '../../features/maintenance/screens/pantalla_formulario_mantenimiento.dart';
import '../../features/shell/shell_screen.dart';
import '../../features/templates/screens/templates_list_screen.dart';

// ── Constantes de rutas ───────────────────────────────────────────────────────
// Rutas raíz de las 4 pestañas principales
const String rutaClientes      = '/clientes';
const String rutaCalendario    = '/calendario';
const String rutaMantenimiento = '/mantenimiento';
const String rutaPlantillas    = '/plantillas';

// Rutas de pantalla completa (sin NavigationBar)
const String rutaFormularioCliente        = '/formulario-cliente';
const String rutaFormularioCita           = '/formulario-cita';
const String rutaFormularioMantenimiento  = '/formulario-mantenimiento';

/// Provider que expone el [GoRouter] configurado.
///
/// Al vivir dentro de Riverpod, puede en el futuro acceder a otros providers
/// (configuración de usuario, estados de autenticación, etc.) para
/// hacer redirecciones dinámicas sin reescribir el router.
final enrutadorAppProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: rutaCalendario,
    debugLogDiagnostics: true, // imprime en consola los cambios de ruta
    routes: [
      // ── Shell: NavigationBar compartida entre las 4 pestañas ─────────────
      // ShellRoute envuelve las rutas hijas con [ShellScreen], que contiene
      // la NavigationBar. go_router preserva el estado de cada pestaña.
      ShellRoute(
        builder: (context, estado, hijo) => ShellScreen(child: hijo),
        routes: [
          GoRoute(
            path: rutaClientes,
            builder: (context, estado) => const PantallaClientes(),
          ),
          GoRoute(
            path: rutaCalendario,
            builder: (context, estado) => const PantallaCalendario(),
          ),
          GoRoute(
            path: rutaMantenimiento,
            builder: (context, estado) => const PantallaMantenimientos(),
          ),
          GoRoute(
            path: rutaPlantillas,
            builder: (context, estado) => const TemplatesListScreen(),
          ),
        ],
      ),

      // ── Pantallas de pantalla completa (sin NavigationBar) ──────────────
      // Los formularios cubren toda la pantalla al hacer push desde cualquier tab.
      GoRoute(
        path: rutaFormularioCliente,
        builder: (context, estado) {
          // Recibe el cliente a editar a través del campo [extra].
          // Si es null, el formulario abre en modo creación.
          final clienteExistente = estado.extra as Client?;
          return PantallaFormularioCliente(clienteExistente: clienteExistente);
        },
      ),
      GoRoute(
        path: rutaFormularioCita,
        builder: (context, estado) {
          // Recibe la cita a editar a través de [extra].
          // Si es null, el formulario abre en modo creación.
          final citaExistente = estado.extra as Appointment?;
          return PantallaFormularioCita(citaExistente: citaExistente);
        },
      ),
      GoRoute(
        path: '$rutaFormularioMantenimiento/:citaId',
        builder: (context, estado) {
          final citaId = int.parse(estado.pathParameters['citaId']!);
          return PantallaFormularioMantenimiento(citaId: citaId);
        },
      ),
    ],
  );
});
