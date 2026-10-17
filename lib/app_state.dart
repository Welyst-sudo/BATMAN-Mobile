import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';

import 'ai_client.dart';
import 'assistant_logic.dart';
import 'habits.dart';
import 'pc_client.dart';
import 'skins.dart';

class ChatMsg {
  final bool fromUser;
  final String text;
  const ChatMsg(this.fromUser, this.text);
}

const Map<String, int> habitIds = {'musica': 201, 'pc': 202, 'consulta': 203};

String pctText(dynamic v) => v is num ? '${v.round()}%' : 'n/d';

class AppState extends ChangeNotifier {
  SharedPreferences? prefs;
  final stt.SpeechToText speech = stt.SpeechToText();
  final FlutterTts tts = FlutterTts();
  final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();

  final List<ChatMsg> chat = [const ChatMsg(false, 'BATMAN en línea. Escríbeme o pulsa el micrófono.')];
  List<HabitMemory> memories = [];
  List<HabitEvent> events = [];
  Set<String> habitOn = {};

  int tab = 0;
  bool listening = false;
  bool thinking = false;
  String heard = '';

  bool speak = true;
  bool learn = true;
  bool fastLearn = false;
  bool autoHabits = false;
  String apiKey = '';
  String model = 'meta-llama/llama-3.3-70b-instruct:free';
  String pcUrl = '';
  String pcToken = '';

  bool routineEnabled = false;
  String routineText = 'Buenos días. Revisa tus tareas y organiza tu día.';
  int routineMinute = 8 * 60;

  Map<String, dynamic>? pcStatus;
  List<Map<String, dynamic>> pcTasks = [];
  String? pcError;
  bool pcLoading = false;

  // ---------------------------------------------------------------- inicio
  Future<void> init() async {
    final p = await SharedPreferences.getInstance();
    prefs = p;
    try {
      tz.initializeTimeZones();
    } catch (_) {}
    apiKey = p.getString('api_key') ?? '';
    model = p.getString('model') ?? model;
    pcUrl = p.getString('pc_url') ?? '';
    pcToken = p.getString('pc_token') ?? '';
    speak = p.getBool('speak') ?? true;
    learn = p.getBool('learn') ?? true;
    fastLearn = p.getBool('fast_learn') ?? false;
    autoHabits = p.getBool('auto_habits') ?? false;
    habitOn = (p.getStringList('habit_on') ?? <String>[]).toSet();
    routineEnabled = p.getBool('routine_enabled') ?? false;
    routineText = p.getString('routine_text') ?? routineText;
    routineMinute = p.getInt('routine_minute') ?? routineMinute;
    memories = decodeMemories(p.getString('memories'));
    events = decodeEvents(p.getString('events'));
    final skinId = p.getString('skin') ?? skins.first.id;
    currentSkin.value = skins.firstWhere((s) => s.id == skinId, orElse: () => skins.first);
    try {
      await tts.setLanguage('es-ES');
      await tts.setSpeechRate(0.48);
    } catch (_) {}
    try {
      await notifications.initialize(const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
            requestAlertPermission: true, requestBadgePermission: true, requestSoundPermission: true),
      ));
    } catch (_) {}
    notifyListeners();
    try {
      await rescheduleAll();
    } catch (_) {}
  }

  void setTab(int i) {
    tab = i;
    notifyListeners();
    if (i == 1 && pc != null) refreshPc();
  }

  // ------------------------------------------------------------- ajustes
  Future<void> setSkin(BatSkin s) async {
    currentSkin.value = s;
    await prefs?.setString('skin', s.id);
    notifyListeners();
  }

  String _normalizeUrl(String raw) {
    var u = raw.trim();
    if (u.isEmpty) return '';
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'http://$u';
    return u;
  }

  Future<void> saveConnection({
    required String apiKeyValue,
    required String modelValue,
    required String pcUrlValue,
    required String pcTokenValue,
  }) async {
    apiKey = apiKeyValue.trim();
    model = modelValue.trim().isEmpty ? model : modelValue.trim();
    pcUrl = _normalizeUrl(pcUrlValue);
    pcToken = pcTokenValue.trim();
    await prefs?.setString('api_key', apiKey);
    await prefs?.setString('model', model);
    await prefs?.setString('pc_url', pcUrl);
    await prefs?.setString('pc_token', pcToken);
    notifyListeners();
  }

  Future<void> setSpeak(bool v) async {
    speak = v;
    await prefs?.setBool('speak', v);
    notifyListeners();
  }

  Future<void> setLearn(bool v) async {
    learn = v;
    await prefs?.setBool('learn', v);
    notifyListeners();
  }

  Future<void> setFastLearn(bool v) async {
    fastLearn = v;
    await prefs?.setBool('fast_learn', v);
    notifyListeners();
    await rescheduleAll();
  }

  // -------------------------------------------------------------- hábitos
  List<LearnedHabit> get habits => learnHabits(events, fast: fastLearn);

  Future<void> recordEvent(String category) async {
    if (!learn) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day).millisecondsSinceEpoch ~/ 86400000;
    events.add(HabitEvent(category, now.hour * 60 + now.minute, today));
    events.removeWhere((e) => e.day < today - 60);
    if (events.length > 400) events = events.sublist(events.length - 400);
    await prefs?.setString('events', encodeEvents(events));
    notifyListeners();
    if (autoHabits || habitOn.isNotEmpty) {
      try {
        await rescheduleAll();
      } catch (_) {}
    }
  }

  Future<void> clearEvents() async {
    events = [];
    await prefs?.setString('events', encodeEvents(events));
    notifyListeners();
    await rescheduleAll();
  }

  Future<void> setHabit(String category, bool on) async {
    if (on) {
      habitOn.add(category);
      await requestNotificationPermission();
    } else {
      habitOn.remove(category);
    }
    await prefs?.setStringList('habit_on', habitOn.toList());
    notifyListeners();
    await rescheduleAll();
  }

  Future<void> setAutoHabits(bool v) async {
    autoHabits = v;
    if (v) await requestNotificationPermission();
    await prefs?.setBool('auto_habits', v);
    notifyListeners();
    await rescheduleAll();
  }

  Future<void> saveRoutine(bool enabled, int minute, String text) async {
    routineEnabled = enabled;
    routineMinute = minute;
    if (text.isNotEmpty) routineText = text;
    await prefs?.setBool('routine_enabled', routineEnabled);
    await prefs?.setInt('routine_minute', routineMinute);
    await prefs?.setString('routine_text', routineText);
    if (enabled) await requestNotificationPermission();
    notifyListeners();
    await rescheduleAll();
  }

  // ------------------------------------------------------- notificaciones
  Future<void> requestNotificationPermission() async {
    try {
      final android = notifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      await android?.requestNotificationsPermission();
    } catch (_) {}
  }

  NotificationDetails _details(String channelId, String channelName) => NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription: 'Recordatorios de BATMAN',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: const DarwinNotificationDetails(),
      );

  Future<void> _scheduleDaily(int id, String title, String body, int minuteOfDay, String channelId,
      String channelName) async {
    final now = DateTime.now();
    var when = DateTime(now.year, now.month, now.day, minuteOfDay ~/ 60, minuteOfDay % 60);
    if (!when.isAfter(now)) when = when.add(const Duration(days: 1));
    final at = tz.TZDateTime.from(when.toUtc(), tz.UTC);
    await notifications.zonedSchedule(
      id,
      title,
      body,
      at,
      _details(channelId, channelName),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> rescheduleAll() async {
    await notifications.cancelAll();
    if (routineEnabled) {
      await _scheduleDaily(100, 'BATMAN · Tu rutina', routineText, routineMinute, 'batman_routines',
          'Rutinas BATMAN');
    }
    for (final h in habits) {
      final id = habitIds[h.category];
      if (id == null) continue;
      if (autoHabits || habitOn.contains(h.category)) {
        await _scheduleDaily(
          id,
          'BATMAN · ${habitNames[h.category] ?? h.category}',
          habitMessages[h.category] ?? 'Es tu hora habitual.',
          h.reminderMinute,
          'batman_habits',
          'Hábitos aprendidos',
        );
      }
    }
  }

  Future<void> testNotification() async {
    await requestNotificationPermission();
    await notifications.show(1, 'BATMAN', 'Las notificaciones funcionan. Así te avisaré de tus rutinas.',
        _details('batman_habits', 'Hábitos aprendidos'));
  }

  // ----------------------------------------------------------------- chat
  void addChat(bool fromUser, String text) {
    chat.add(ChatMsg(fromUser, text));
    notifyListeners();
  }

  Future<void> say(String text) async {
    addChat(false, text);
    if (speak) {
      try {
        await tts.speak(text);
      } catch (_) {}
    }
  }

  Future<void> _saveMemories() async => prefs?.setString('memories', encodeMemories(memories));

  Future<void> clearMemories() async {
    memories = [];
    await _saveMemories();
    notifyListeners();
  }

  Future<void> forgetMemory(HabitMemory m) async {
    memories.removeWhere((x) => x.key == m.key);
    await _saveMemories();
    notifyListeners();
  }

  Future<void> send(String raw) async {
    final message = raw.trim();
    if (message.isEmpty || thinking) return;
    addChat(true, message);
    final lower = message.toLowerCase();
    final intent = interpret(message);
    switch (intent.kind) {
      case 'remember':
        final key = normalizedKey(intent.payload);
        final index = memories.indexWhere((m) => m.key == key);
        if (index < 0) {
          memories.add(HabitMemory(key, intent.payload, 1));
        } else {
          final old = memories[index];
          memories[index] = HabitMemory(key, old.value, old.observations + 1);
        }
        await _saveMemories();
        await say('Anotado. Lo recordaré.');
        return;
      case 'list':
        await say(memories.isEmpty
            ? 'Todavía no tengo preferencias guardadas.'
            : 'Recuerdo: ${memories.map((m) => m.value).join('; ')}');
        return;
      case 'forget':
        final query = normalizedKey(intent.payload);
        memories.removeWhere((m) => m.key.contains(query));
        await _saveMemories();
        await say('Listo, actualicé mi memoria.');
        return;
      case 'clear':
        await clearMemories();
        await say('He borrado toda la memoria.');
        return;
      case 'time':
        final now = TimeOfDay.now();
        await say('Son las ${now.hour} y ${now.minute.toString().padLeft(2, '0')}.');
        return;
      default:
        break;
    }
    if (intent.kind == 'youtube' && isMusicRequest(lower)) {
      await _openYoutube(intent.payload.isEmpty ? message : intent.payload);
      return;
    }
    if (mentionsPc(lower)) {
      await _handlePcRequest(lower);
      return;
    }
    await _askAi(message);
  }

  Future<void> _openYoutube(String query) async {
    await recordEvent('musica');
    final url = Uri.https('www.youtube.com', '/results', {'search_query': query});
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
      await say('Abrí la búsqueda de $query en YouTube.');
    } else {
      await say('No pude abrir YouTube.');
    }
  }

  String _systemPrompt() {
    final now = DateTime.now();
    final buffer = StringBuffer(
        'Eres BATMAN, un asistente personal que vive en el celular del usuario. Responde siempre en español, '
        'de forma breve, clara y útil. Hora local: ${formatMinute(now.hour * 60 + now.minute)}.');
    if (memories.isNotEmpty) {
      buffer.write('\nPreferencias que el usuario te pidió recordar:');
      for (final m in memories.take(15)) {
        buffer.write('\n- ${m.value}');
      }
    }
    final learned = habits;
    if (learned.isNotEmpty) {
      buffer.write('\nHábitos observados:');
      for (final h in learned) {
        buffer.write('\n- ${habitNames[h.category] ?? h.category} hacia las ${formatMinute(h.minute)}');
      }
    }
    return buffer.toString();
  }

  Future<void> _askAi(String message) async {
    await recordEvent('consulta');
    if (apiKey.trim().isEmpty) {
      await say('Aún no tengo clave de IA. Ve a Ajustes y pega tu API key de OpenRouter.');
      return;
    }
    thinking = true;
    notifyListeners();
    try {
      final history = <Map<String, String>>[
        {'role': 'system', 'content': _systemPrompt()},
      ];
      final recent = chat.length > 12 ? chat.sublist(chat.length - 12) : chat;
      for (final m in recent) {
        history.add({'role': m.fromUser ? 'user' : 'assistant', 'content': m.text});
      }
      final answer = await AiClient(apiKey.trim(), model).chat(history);
      thinking = false;
      await say(answer);
    } catch (e) {
      thinking = false;
      await say('No pude contactar a la IA ($e). Revisa tu API key, el modelo y tu conexión.');
    }
    thinking = false;
    notifyListeners();
  }

  // ------------------------------------------------------------------ voz
  Future<void> toggleListen() async {
    if (listening) {
      await speech.stop();
      listening = false;
      notifyListeners();
      return;
    }
    try {
      await tts.stop();
    } catch (_) {}
    final ready = await speech.initialize(
      onStatus: (status) {
        if (status == 'done' || status == 'notListening') {
          listening = false;
          notifyListeners();
        }
      },
      onError: (error) {
        listening = false;
        notifyListeners();
      },
    );
    if (!ready) {
      await say('No pude activar el micrófono. Revisa los permisos de voz.');
      return;
    }
    listening = true;
    heard = '';
    notifyListeners();
    await speech.listen(
      localeId: 'es_ES',
      onResult: (result) async {
        heard = result.recognizedWords;
        notifyListeners();
        if (result.finalResult) {
          listening = false;
          notifyListeners();
          await send(result.recognizedWords);
        }
      },
    );
  }

  // ------------------------------------------------------------------- PC
  PcClient? get pc => (pcUrl.trim().isEmpty || pcToken.trim().isEmpty) ? null : PcClient(pcUrl.trim(), pcToken.trim());

  Future<void> refreshPc() async {
    final c = pc;
    if (c == null) {
      pcError = 'Configura la dirección y el token de tu PC en Ajustes.';
      notifyListeners();
      return;
    }
    pcLoading = true;
    notifyListeners();
    try {
      pcStatus = await c.status();
      pcTasks = await c.tasks();
      pcError = null;
    } catch (e) {
      pcError = 'No pude conectar con el PC. ¿Está encendido, en la misma red y con el servidor abierto? ($e)';
    }
    pcLoading = false;
    notifyListeners();
  }

  Future<String> runPcTask(String id, {bool record = true}) async {
    final c = pc;
    if (c == null) return 'Configura primero el PC en Ajustes.';
    try {
      final out = await c.run(id);
      if (record) await recordEvent('pc');
      return out;
    } catch (e) {
      return 'No pude ejecutar la tarea: $e';
    }
  }

  String pcSummary(Map<String, dynamic> s) {
    return 'Tu PC ${s['host'] ?? ''}: CPU ${pctText(s['cpu'])}, RAM ${pctText(s['ram'])}, '
        'disco ${pctText(s['disk'])} usado.';
  }

  Future<void> _handlePcRequest(String lower) async {
    await recordEvent('pc');
    if (pc == null) {
      await say('Primero configura la dirección y el token de tu PC en Ajustes.');
      return;
    }
    String? task;
    if (lower.contains('optimiza') || lower.contains('limpia')) {
      task = 'limpiar_temp';
    } else if (lower.contains('bloquea')) {
      task = 'bloquear';
    }
    if (task != null) {
      await say(await runPcTask(task, record: false));
      return;
    }
    await refreshPc();
    final s = pcStatus;
    if (s == null) {
      await say(pcError ?? 'No pude leer el estado del PC.');
      return;
    }
    await say(pcSummary(s));
  }
}
