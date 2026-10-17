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


# --- Desugaring: flutter_local_notifications lo exige para compilar en Android ---
import re

DESUGAR_VERSION = '2.1.4'
done = False

kts = Path('android/app/build.gradle.kts')
groovy = Path('android/app/build.gradle')

if kts.exists():
    text = kts.read_text(encoding='utf-8')
    if 'isCoreLibraryDesugaringEnabled' not in text:
        if re.search(r'compileOptions\s*\{', text):
            text = re.sub(r'(compileOptions\s*\{)', r'\1\n        isCoreLibraryDesugaringEnabled = true', text, count=1)
        else:
            text = re.sub(r'(android\s*\{)', r'\1\n    compileOptions {\n        isCoreLibraryDesugaringEnabled = true\n    }', text, count=1)
        text += '\ndependencies {\n    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:%s")\n}\n' % DESUGAR_VERSION
        kts.write_text(text, encoding='utf-8')
    done = True
elif groovy.exists():
    text = groovy.read_text(encoding='utf-8')
    if 'coreLibraryDesugaringEnabled' not in text:
        if re.search(r'compileOptions\s*\{', text):
            text = re.sub(r'(compileOptions\s*\{)', r'\1\n        coreLibraryDesugaringEnabled true', text, count=1)
        else:
            text = re.sub(r'(android\s*\{)', r'\1\n    compileOptions {\n        coreLibraryDesugaringEnabled true\n    }', text, count=1)
        text += "\ndependencies {\n    coreLibraryDesugaring 'com.android.tools:desugar_jdk_libs:%s'\n}\n" % DESUGAR_VERSION
        groovy.write_text(text, encoding='utf-8')
    done = True

print('Desugaring configurado' if done else 'AVISO: no encontre build.gradle de la app')
