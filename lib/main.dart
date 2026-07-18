import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:timezone/data/latest.dart' as tz;

import 'core/database/database_helper.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

/// Instancia global del plugin de notificaciones.
/// Se declara aquí para ser accesible desde cualquier servicio de la app.
final FlutterLocalNotificationsPlugin notificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  // Garantiza que los bindings de Flutter estén listos antes de
  // realizar operaciones asíncronas (DB, plugins, etc.)
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa la base de datos SQLite al arrancar
  await DatabaseHelper.instance.database;

  // Carga los símbolos de fecha/hora en español para table_calendar e intl
  await initializeDateFormatting('es_ES', null);

  // Carga las definiciones de zonas horarias (necesario para
  // notificaciones programadas con flutter_local_notifications)
  tz.initializeTimeZones();

  // Configura el plugin de notificaciones para Android e iOS
  await _initNotifications();

  runApp(
    // ProviderScope es el contenedor raíz de Riverpod.
    // Todos los providers deben vivir dentro de este widget.
    const ProviderScope(
      child: PDMRutineApp(),
    ),
  );
}

/// Configura los ajustes iniciales del plugin de notificaciones locales.
Future<void> _initNotifications() async {
  const androidSettings =
      AndroidInitializationSettings('@mipmap/ic_launcher');

  const iosSettings = DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );

  await notificationsPlugin.initialize(
    const InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    ),
  );
}

/// Widget raíz de la aplicación.
/// ConsumerWidget permite leer providers de Riverpod en el build.
class PDMRutineApp extends ConsumerWidget {
  const PDMRutineApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(enrutadorAppProvider);

    return MaterialApp.router(
      title: 'PDM Rutine',
      debugShowCheckedModeBanner: false,

      // Material Design 3 con tema claro/oscuro automático
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,

      // Localización en español (necesaria para DatePicker, TimePicker, etc.)
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('es', 'ES')],
      locale: const Locale('es', 'ES'),

      // Rutas gestionadas por go_router
      routerConfig: router,
    );
  }
}
