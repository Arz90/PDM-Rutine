// Smoke test básico para PDM Rutine.
//
// Verifica únicamente que el árbol de widgets raíz se construye sin errores.
// PDMRutineApp requiere ProviderScope (Riverpod) y MaterialApp.router
// (go_router); este test garantiza que la integración entre ambos es correcta.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdm_rutine/main.dart';

void main() {
  testWidgets('smoke test: PDMRutineApp arranca dentro de ProviderScope',
      (WidgetTester tester) async {
    // Construye la app envuelta en ProviderScope y bombea un frame inicial.
    await tester.pumpWidget(
      const ProviderScope(child: PDMRutineApp()),
    );

    // El widget raíz de la aplicación está presente en el árbol.
    expect(find.byType(PDMRutineApp), findsOneWidget);
  });
}
