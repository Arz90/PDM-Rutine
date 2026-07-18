import 'package:flutter/material.dart';

/// Define los temas claro y oscuro de la app con Material Design 3.
///
/// La paleta entera se genera automáticamente a partir de [_seedColor]
/// mediante el algoritmo HCT de Material 3.
class AppTheme {
  // Color semilla: azul técnico/industrial
  static const _seedColor = Color(0xFF1565C0);

  static ThemeData get lightTheme => _buildTheme(Brightness.light);
  static ThemeData get darkTheme => _buildTheme(Brightness.dark);

  static ThemeData _buildTheme(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seedColor,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,

      // AppBar sin elevación visible (estilo M3 plano)
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 2,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
      ),

      // Tarjetas con esquinas redondeadas estilo M3
      cardTheme: CardThemeData(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // FABs con forma de estadio (pill shape)
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        shape: StadiumBorder(),
      ),

      // Inputs con borde redondeado
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
      ),
    );
  }
}
