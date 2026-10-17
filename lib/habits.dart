import 'dart:convert';

/// Una acción del usuario registrada localmente (solo categoría y hora, nunca el texto).
class HabitEvent {
  final String category;
  final int minute; // minuto del día, 0..1439
  final int day; // número de día local (para contar días distintos)
  const HabitEvent(this.category, this.minute, this.day);
  Map<String, dynamic> toJson() => {'c': category, 'm': minute, 'd': day};
  factory HabitEvent.fromJson(Map<String, dynamic> j) =>
      HabitEvent(j['c'] as String, (j['m'] as num).toInt(), (j['d'] as num).toInt());
}

/// Un hábito detectado: categoría + hora típica.
class LearnedHabit {
  final String category;
  final int minute;
  final int count;
  final int days;
  const LearnedHabit(this.category, this.minute, this.count, this.days);

  /// El aviso llega 10 minutos antes de la hora habitual.
  int get reminderMinute => (minute - 10 + 1440) % 1440;
}

const Map<String, String> habitNames = {
  'musica': 'Música',
  'pc': 'Control del PC',
  'consulta': 'Consultas al asistente',
};

const Map<String, String> habitMessages = {
  'musica': 'Sueles escuchar música a esta hora. Abre BATMAN y pídeme algo.',
  'pc': 'Sueles revisar tu PC a esta hora. ¿Miramos cómo está?',
  'consulta': 'Sueles consultarme a esta hora. ¿En qué te ayudo?',
};

bool mentionsPc(String lower) =>
    RegExp(r'\b(pc|computadora|compu|ordenador|laptop)\b').hasMatch(lower);

bool isMusicRequest(String lower) =>
    lower.contains('youtube') ||
    lower.contains('música') ||
    lower.contains('musica') ||
    lower.contains('canción') ||
    lower.contains('cancion') ||
    RegExp(r'^(pon|reproduce|escuchar)\s').hasMatch(lower);

String formatMinute(int minute) {
  final h = (minute ~/ 60).toString().padLeft(2, '0');
  final m = (minute % 60).toString().padLeft(2, '0');
  return '$h:$m';
}

int _offset(int m, int c) => ((m - c + 720) % 1440 + 1440) % 1440 - 720;
int _dist(int a, int b) => _offset(a, b).abs();

/// Detecta hábitos: acciones de una misma categoría que se repiten a la misma hora
/// (ventana de ±45 min) en al menos 2 días distintos. En modo rápido basta con 2 repeticiones.
List<LearnedHabit> learnHabits(List<HabitEvent> events, {bool fast = false, int windowMinutes = 45}) {
  final minCount = fast ? 2 : 3;
  final minDays = fast ? 1 : 2;
  final byCategory = <String, List<HabitEvent>>{};
  for (final e in events) {
    byCategory.putIfAbsent(e.category, () => <HabitEvent>[]).add(e);
  }
  final result = <LearnedHabit>[];
  byCategory.forEach((category, list) {
    var bestCount = 0;
    var bestCenter = 0;
    for (final c in list) {
      final n = list.where((e) => _dist(e.minute, c.minute) <= windowMinutes).length;
      if (n > bestCount) {
        bestCount = n;
        bestCenter = c.minute;
      }
    }
    if (bestCount < minCount) return;
    final near = list.where((e) => _dist(e.minute, bestCenter) <= windowMinutes).toList();
    var sum = 0;
    for (final e in near) {
      sum += _offset(e.minute, bestCenter);
    }
    final minute = (bestCenter + (sum / near.length).round() + 1440) % 1440;
    final days = near.map((e) => e.day).toSet().length;
    if (days < minDays) return;
    result.add(LearnedHabit(category, minute, near.length, days));
  });
  result.sort((a, b) => b.count.compareTo(a.count));
  return result;
}

List<HabitEvent> decodeEvents(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    return (jsonDecode(raw) as List)
        .map((e) => HabitEvent.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  } catch (_) {
    return [];
  }
}

String encodeEvents(List<HabitEvent> items) => jsonEncode(items.map((e) => e.toJson()).toList());
