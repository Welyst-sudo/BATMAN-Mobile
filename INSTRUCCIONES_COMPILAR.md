# BATMAN Mobile — Compilación automática desde Windows

## Android: APK listo para pruebas

1. Crea una cuenta gratuita en https://github.com si no tienes una.
2. Crea un repositorio **privado** vacío llamado `batman-mobile`.
3. En GitHub, usa **Add file > Upload files** y sube **todo el contenido** de esta carpeta, incluyendo `.github/workflows/android.yml` (los archivos ocultos pueden requerir Git o subir el ZIP extraído con GitHub Desktop).
4. Abre la pestaña **Actions** y selecciona **BATMAN Android APK** > **Run workflow**.
5. Cuando termine correctamente, abre la ejecución y descarga el artefacto **BATMAN-Mobile-Android-APK**.
6. Descomprime el artefacto, pasa `app-debug.apk` al teléfono Android e instálalo aceptando la instalación de aplicaciones de esa fuente si confías en el APK.

**El APK es de pruebas, firmado con la clave de depuración del proceso de compilación; no es una versión para Play Store.** Para actualizaciones estables se necesita una clave de firma propia y consistente.

## Abrir con la voz

- Android: di **«Hey Google, abre BATMAN Mobile»** si tu asistente del sistema admite abrir aplicaciones instaladas.
- iPhone: di **«Oye Siri, abre BATMAN Mobile»** una vez instalada la aplicación y reconocida por Siri; puedes crear un atajo en Atajos para darle otro nombre.
- Dentro de BATMAN, pulsa el micrófono para dictar. **No se implementó escucha permanente con la app cerrada ni activación propia por la palabra «Batman».**

## iPhone

El flujo **BATMAN iOS Build Check** comprueba la compilación en un equipo macOS remoto, pero **no genera una IPA instalable** porque carece de firma Apple. Para instalar en tu iPhone por TestFlight hace falta una cuenta Apple Developer, configurar certificados y perfiles, y publicar la compilación con App Store Connect (por ejemplo, mediante Codemagic o Xcode Cloud). No introduzcas certificados ni contraseñas en el repositorio: usa secretos del proveedor de compilación.

## Alcance real del código actual

La versión 0.1 ofrece voz al pulsar, respuesta hablada, memoria de preferencias local mediante `shared_preferences`, búsqueda YouTube y un recordatorio diario. **No ofrece todavía cifrado de la base de datos, IA híbrida/OpenRouter, clima, noticias, aprendizaje avanzado ni control general de aplicaciones.** No trates este prototipo como un asistente con esas funciones terminadas. Los permisos de voz se solicitan en el sistema.

## Diagnóstico

Si falla Actions, abre la ejecución > trabajo `android` > paso fallido y comparte el texto del error. No se ha ejecutado esta compilación en GitHub desde este entorno.
