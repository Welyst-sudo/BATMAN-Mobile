# BATMAN Mobile 1.0

App Flutter para Android (y iOS de prueba) con:

- **Chat con IA real** por texto y voz (OpenRouter, modelo gratuito).
- **Aprende tus costumbres**: guarda solo categoría y hora de lo que haces (música, PC, consultas).
- **Notificaciones locales** 10 min antes de tus horas habituales, también con la app cerrada.
- **Control remoto del PC** en tu red Wi-Fi: estado en vivo y tareas permitidas (optimizar, bloquear...).
- **5 skins**: Gotham, Batmóvil, Murciélago Rojo, Nightwing y Bat-Señal (claro).

## Cómo usarla
1. Sube esta carpeta a tu repositorio (reemplaza archivos) y ejecuta **Actions > BATMAN Android APK**.
2. Instala el APK en tu Android.
3. En **Ajustes** pega tu API key de OpenRouter (y el modelo gratuito que uses en tu asistente de escritorio).
4. Para el PC: en tu PC instala Python, abre `pc_server/iniciar_servidor_pc.bat`, y pega en Ajustes la
   dirección y el token que muestra la ventana. Celular y PC en el mismo Wi-Fi.

## Seguridad
- El servidor del PC NO acepta comandos libres: solo las tareas de `bat_pc_config.json`.
- Todo exige el token. No abras el puerto 8765 en tu router; fuera de casa usa Tailscale.
- La API key se guarda solo en el celular. Nunca la escribas en el código ni en GitHub.
