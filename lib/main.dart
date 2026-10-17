import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'assistant_logic.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  runApp(const BatmanApp());
}

class BatmanApp extends StatelessWidget {
  const BatmanApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'BATMAN Mobile',
    theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFDFC24A), brightness: Brightness.dark), useMaterial3: true),
    home: const HomePage(),
  );
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final _speech = stt.SpeechToText();
  final _tts = FlutterTts();
  final _notifications = FlutterLocalNotificationsPlugin();
  final _input = TextEditingController();
  SharedPreferences? _prefs;
  List<HabitMemory> _memories = [];
  final List<String> _history = ['BATMAN listo. Pulsa el micrófono o escribe una orden.'];
  bool _listening = false;
  bool _speak = true;
  bool _autoLearn = false;
  String _routineText = 'Buenos días. Revisa tus tareas y organiza tu día.';
  TimeOfDay _routineTime = const TimeOfDay(hour: 8, minute: 0);
  bool _routineEnabled = false;

  @override void initState() { super.initState(); _initialize(); }
  Future<void> _initialize() async {
    final p = await SharedPreferences.getInstance();
    await _tts.setLanguage('es-ES');
    await _tts.setSpeechRate(0.48);
    await _notifications.initialize(const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true)));
    if (!mounted) return;
    setState(() {
      _prefs = p;
      _memories = decodeMemories(p.getString('memories'));
      _speak = p.getBool('speak') ?? true;
      _autoLearn = p.getBool('learn') ?? false;
      _routineEnabled = p.getBool('routine_enabled') ?? false;
      _routineText = p.getString('routine_text') ?? _routineText;
      _routineTime = TimeOfDay(hour: p.getInt('routine_hour') ?? 8, minute: p.getInt('routine_minute') ?? 0);
    });
  }
  Future<void> _say(String response) async {
    if (!mounted) return;
    setState(() => _history.insert(0, 'BATMAN: $response'));
    if (_speak) await _tts.speak(response);
  }
  Future<void> _saveMemories() async => _prefs?.setString('memories', encodeMemories(_memories));
  Future<void> _process(String raw) async {
    final message = raw.trim();
    if (message.isEmpty) return;
    _input.clear();
    setState(() => _history.insert(0, 'Tú: $message'));
    final intent = interpret(message);
    switch (intent.kind) {
      case 'remember':
        final key = normalizedKey(intent.payload);
        final index = _memories.indexWhere((m) => m.key == key);
        setState(() {
          if (index < 0) { _memories.add(HabitMemory(key, intent.payload, 1)); }
          else { final old = _memories[index]; _memories[index] = HabitMemory(key, old.value, old.observations + 1); }
        });
        await _saveMemories();
        await _say('He guardado esa preferencia en la memoria local.');
        break;
      case 'list':
        await _say(_memories.isEmpty ? 'No tengo preferencias guardadas.' : 'Recuerdo: ${_memories.map((m) => m.value).join('; ')}');
        break;
      case 'forget':
        final query = normalizedKey(intent.payload);
        setState(() => _memories.removeWhere((m) => m.key.contains(query)));
        await _saveMemories();
        await _say('He actualizado tu memoria.');
        break;
      case 'clear':
        await _confirmClear();
        break;
      case 'youtube':
        final q = intent.payload.isEmpty ? message : intent.payload;
        final url = Uri.https('www.youtube.com', '/results', {'search_query': q});
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
          await _say('Abrí la búsqueda de $q en YouTube.');
        } else { await _say('No pude abrir YouTube.'); }
        if (_autoLearn) await _recordInterest('Música: $q');
        break;
      case 'time':
        final now = TimeOfDay.now();
        await _say('Son las ${now.hour} y ${now.minute.toString().padLeft(2, '0')}.');
        break;
      default:
        await _say('Puedo recordar preferencias, buscar en YouTube, decir la hora y programar una rutina diaria. Todavía no tengo conversación general con inteligencia artificial.');
    }
  }
  Future<void> _recordInterest(String value) async {
    final key = normalizedKey(value);
    final index = _memories.indexWhere((m) => m.key == key);
    setState(() {
      if (index < 0) { _memories.add(HabitMemory(key, value, 1)); }
      else { final old = _memories[index]; _memories[index] = HabitMemory(key, value, old.observations + 1); }
    });
    await _saveMemories();
  }
  Future<void> _listen() async {
    if (_listening) { await _speech.stop(); setState(() => _listening = false); return; }
    final ready = await _speech.initialize(onStatus: (status) { if (mounted && (status == 'done' || status == 'notListening')) setState(() => _listening = false); }, onError: (error) { if (mounted) setState(() => _listening = false); });
    if (!ready) { await _say('No pude activar el micrófono. Revisa los permisos de voz.'); return; }
    setState(() => _listening = true);
    await _speech.listen(localeId: 'es_ES', onResult: (result) async {
      _input.text = result.recognizedWords;
      if (result.finalResult) { setState(() => _listening = false); await _process(result.recognizedWords); }
    });
  }
  Future<void> _confirmClear() async {
    final confirmed = await showDialog<bool>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Borrar memoria'), content: const Text('Se eliminarán todas las preferencias guardadas en este dispositivo.'),
      actions: [TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar'))]));
    if (confirmed == true) { setState(() => _memories.clear()); await _saveMemories(); await _say('Memoria eliminada.'); }
  }
  Future<void> _scheduleRoutine() async {
    final android = _notifications.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();
    await _notifications.cancel(100);
    if (_routineEnabled) {
      // Horario local del dispositivo, sin asumir una zona geográfica fija.
      final now = DateTime.now();
      var scheduled = DateTime(now.year, now.month, now.day, _routineTime.hour, _routineTime.minute);
      if (!scheduled.isAfter(now)) scheduled = scheduled.add(const Duration(days: 1));
      final local = tz.TZDateTime.from(scheduled.toUtc(), tz.UTC);
      await _notifications.zonedSchedule(100, 'BATMAN · Tu rutina', _routineText, local,
        const NotificationDetails(android: AndroidNotificationDetails('batman_routines', 'Rutinas BATMAN', channelDescription: 'Recordatorios autorizados', importance: Importance.high), iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time);
    }
    await _prefs?.setBool('routine_enabled', _routineEnabled);
    await _prefs?.setString('routine_text', _routineText);
    await _prefs?.setInt('routine_hour', _routineTime.hour);
    await _prefs?.setInt('routine_minute', _routineTime.minute);
    await _say(_routineEnabled ? 'Rutina diaria programada.' : 'Rutina desactivada.');
  }
  Future<void> _routineDialog() async {
    final controller = TextEditingController(text: _routineText);
    var enabled = _routineEnabled;
    var selected = _routineTime;
    await showDialog<void>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (context, update) => AlertDialog(
      title: const Text('Rutina autorizada'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        SwitchListTile(title: const Text('Recordatorio diario'), value: enabled, onChanged: (v) => update(() => enabled = v)),
        TextField(controller: controller, maxLines: 2, decoration: const InputDecoration(labelText: 'Texto del recordatorio')),
        TextButton(onPressed: () async { final t = await showTimePicker(context: context, initialTime: selected); if (t != null) update(() => selected = t); }, child: Text('Hora: ${selected.format(context)}')),
      ]),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancelar')),
        FilledButton(onPressed: () { _routineEnabled = enabled; _routineTime = selected; _routineText = controller.text.trim().isEmpty ? 'Tu recordatorio BATMAN' : controller.text.trim(); Navigator.pop(dialogContext); _scheduleRoutine(); }, child: const Text('Guardar'))],
    )));
    controller.dispose();
  }
  @override void dispose() { _input.dispose(); _speech.stop(); _tts.stop(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('🦇 BATMAN Mobile'), actions: [IconButton(tooltip: 'Rutina', icon: const Icon(Icons.schedule), onPressed: _routineDialog), IconButton(tooltip: 'Memoria', icon: const Icon(Icons.psychology), onPressed: () => showModalBottomSheet<void>(context: context, isScrollControlled: true, builder: (ctx) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text('Memoria local', style: TextStyle(fontSize: 22)), const SizedBox(height: 12), ..._memories.take(12).map((m) => ListTile(title: Text(m.value), subtitle: Text('Observaciones: ${m.observations}'), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { setState(() => _memories.remove(m)); await _saveMemories(); if (ctx.mounted) Navigator.pop(ctx); }))), TextButton(onPressed: () { Navigator.pop(ctx); _confirmClear(); }, child: const Text('Borrar toda la memoria'))]))))]),
    body: SafeArea(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [
      Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(children: [
        SwitchListTile(title: const Text('Responder por voz'), subtitle: const Text('BATMAN leerá sus respuestas'), value: _speak, onChanged: (v) { setState(() => _speak = v); _prefs?.setBool('speak', v); }),
        SwitchListTile(title: const Text('Aprender intereses musicales'), subtitle: const Text('Solo registra búsquedas realizadas dentro de BATMAN'), value: _autoLearn, onChanged: (v) { setState(() => _autoLearn = v); _prefs?.setBool('learn', v); }),
      ]))),
      const SizedBox(height: 8),
      Expanded(child: ListView.builder(reverse: true, itemCount: _history.length, itemBuilder: (ctx, i) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Text(_history[_history.length - 1 - i]))))),
      Row(children: [Expanded(child: TextField(controller: _input, decoration: const InputDecoration(hintText: 'Habla o escribe...', border: OutlineInputBorder()), onSubmitted: _process)),
        IconButton(tooltip: 'Enviar', icon: const Icon(Icons.send), onPressed: () => _process(_input.text)),
        IconButton(tooltip: _listening ? 'Detener escucha' : 'Hablar', icon: Icon(_listening ? Icons.stop_circle : Icons.mic), onPressed: _listen)]),
    ]))),
  );
}
