import 'dart:convert';

class HabitMemory {
  final String key;
  final String value;
  final int observations;
  const HabitMemory(this.key, this.value, this.observations);
  Map<String, dynamic> toJson() => {'key': key, 'value': value, 'observations': observations};
  factory HabitMemory.fromJson(Map<String, dynamic> data) => HabitMemory(
    data['key'] as String, data['value'] as String, (data['observations'] as num?)?.toInt() ?? 1);
}

class AssistantIntent {
  final String kind;
  final String payload;
  const AssistantIntent(this.kind, [this.payload = '']);
}

AssistantIntent interpret(String raw) {
  final value = raw.trim();
  final lower = value.toLowerCase();
  final remember = RegExp(r'^(?:batman[, ]*)?(?:recuerda que|recuerda|aprende que)\s+(.+)$', caseSensitive: false).firstMatch(value);
  if (remember != null) return AssistantIntent('remember', remember.group(1)!.trim());
  if (RegExp(r'^(?:batman[, ]*)?(?:qué recuerdas|que recuerdas|mi memoria|mis recuerdos)', caseSensitive: false).hasMatch(lower)) return const AssistantIntent('list');
  if (lower.contains('borra toda') && lower.contains('memoria')) return const AssistantIntent('clear');
  final forget = RegExp(r'^(?:batman[, ]*)?(?:olvida|borra recuerdo)\s+(.+)$', caseSensitive: false).firstMatch(value);
  if (forget != null) return AssistantIntent('forget', forget.group(1)!.trim());
  final music = RegExp(r'(?:busca|pon|reproduce|escuchar|música de|musica de)\s+(.+)', caseSensitive: false).firstMatch(value);
  if (lower.contains('youtube') || music != null) {
    final q = (music?.group(1) ?? value).replaceAll(RegExp(r'\s+(?:en youtube|por youtube)$', caseSensitive: false), '').trim();
    return AssistantIntent('youtube', q);
  }
  if (lower.contains('qué hora') || lower.contains('que hora')) return const AssistantIntent('time');
  return AssistantIntent('unknown', value);
}

String normalizedKey(String input) => input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

List<HabitMemory> decodeMemories(String? raw) {
  if (raw == null || raw.isEmpty) return [];
  try {
    return (jsonDecode(raw) as List).map((e) => HabitMemory.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  } catch (_) { return []; }
}

String encodeMemories(List<HabitMemory> items) => jsonEncode(items.map((e) => e.toJson()).toList());
