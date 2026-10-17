from pathlib import Path

manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    text = manifest.read_text(encoding='utf-8')
    # Permite hablar con el servidor del PC por http dentro de la red local.
    if 'usesCleartextTraffic' not in text:
        text = text.replace('<application', '<application\n        android:usesCleartextTraffic="true"', 1)
    wanted = [
        ('android.permission.RECORD_AUDIO', '    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n'),
        ('android.permission.INTERNET', '    <uses-permission android:name="android.permission.INTERNET" />\n'),
        ('android.permission.POST_NOTIFICATIONS', '    <uses-permission android:name="android.permission.POST_NOTIFICATIONS" />\n'),
        ('android.permission.RECEIVE_BOOT_COMPLETED', '    <uses-permission android:name="android.permission.RECEIVE_BOOT_COMPLETED" />\n'),
    ]
    lines = ''.join(line for key, line in wanted if key not in text)
    if 'android.speech.RecognitionService' not in text:
        lines += ('    <queries>\n'
                  '        <intent><action android:name="android.speech.RecognitionService" /></intent>\n'
                  '        <intent><action android:name="android.intent.action.TTS_SERVICE" /></intent>\n'
                  '    </queries>\n')
    if lines:
        text = text.replace('<application', lines + '    <application', 1)
    manifest.write_text(text, encoding='utf-8')

plist = Path('ios/Runner/Info.plist')
if plist.exists():
    text = plist.read_text(encoding='utf-8')
    if 'NSSpeechRecognitionUsageDescription' not in text:
        text = text.replace('</dict>', '    <key>NSMicrophoneUsageDescription</key>\n    <string>BATMAN necesita el micrófono para escuchar tus instrucciones cuando lo actives.</string>\n    <key>NSSpeechRecognitionUsageDescription</key>\n    <string>BATMAN convierte tus instrucciones habladas en texto.</string>\n</dict>', 1)
        plist.write_text(text, encoding='utf-8')
