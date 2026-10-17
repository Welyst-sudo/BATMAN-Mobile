from pathlib import Path
import xml.etree.ElementTree as ET

manifest = Path('android/app/src/main/AndroidManifest.xml')
if manifest.exists():
    text = manifest.read_text(encoding='utf-8')
    lines = '    <uses-permission android:name="android.permission.RECORD_AUDIO" />\n    <uses-permission android:name="android.permission.INTERNET" />\n    <queries>\n        <intent><action android:name="android.speech.RecognitionService" /></intent>\n        <intent><action android:name="android.intent.action.TTS_SERVICE" /></intent>\n    </queries>\n'
    if 'android.permission.RECORD_AUDIO' not in text:
        text = text.replace('<application', lines + '    <application', 1)
    manifest.write_text(text, encoding='utf-8')

plist = Path('ios/Runner/Info.plist')
if plist.exists():
    text = plist.read_text(encoding='utf-8')
    if 'NSSpeechRecognitionUsageDescription' not in text:
        text = text.replace('</dict>', '    <key>NSMicrophoneUsageDescription</key>\n    <string>BATMAN necesita el micrófono para escuchar tus instrucciones cuando lo actives.</string>\n    <key>NSSpeechRecognitionUsageDescription</key>\n    <string>BATMAN convierte tus instrucciones habladas en texto.</string>\n</dict>', 1)
    plist.write_text(text, encoding='utf-8')
