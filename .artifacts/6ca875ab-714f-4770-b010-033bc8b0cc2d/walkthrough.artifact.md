# Solución de Errores de Compilación y Configuración

He realizado las siguientes correcciones para permitir que la aplicación se ejecute en el emulador Pixel 8 (Android 16 / API 36).

## Cambios realizados

### 1. Configuración de Android y Permisos
He actualizado el `AndroidManifest.xml` para incluir:
*   **Permiso de Internet**: Esencial para que Flutter conecte el depurador.
*   **Permiso de Notificaciones**: Necesario para Android 13+ (Pixel 8), evitando que la app crashee al inicializar el plugin de notificaciones.
*   **Queries de Email**: Permite que `flutter_email_sender` encuentre aplicaciones de correo electrónico instaladas.

### 2. Limpieza de Conflictos
*   He forzado la detención de procesos que bloqueaban la carpeta de construcción (`pdm_rutine.exe`).
*   He ejecutado una limpieza profunda de la caché (`flutter clean` y eliminación de `.gradle`).

### 3. Diagnóstico del Error de Gradle
El error `AndroidLocationsBuildService` es un fallo interno de Gradle que ocurre cuando no puede acceder a la carpeta de configuración del usuario en Windows o cuando hay archivos bloqueados por el sistema.

> [!WARNING]
> **Acción necesaria por tu parte:**
> Como he detectado que varios archivos estaban bloqueados por el sistema (Error de "Acceso Denegado"), te recomiendo **reiniciar Android Studio** y el emulador. Esto liberará cualquier bloqueo residual y permitirá que Gradle se inicialice correctamente con la nueva configuración que he aplicado.

## Verificación
*   `AndroidManifest.xml` actualizado con éxito.
*   Caché de Flutter purgada.
*   Procesos bloqueantes terminados.

Una vez reinicies el IDE, intenta ejecutar de nuevo:
```bash
flutter run -d emulator-5554
```
