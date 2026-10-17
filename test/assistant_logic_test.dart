import 'package:flutter_test/flutter_test.dart';
import 'package:batman_mobile/assistant_logic.dart';
void main() {
  test('memoria explícita', () { expect(interpret('recuerda que me gusta la bachata').kind, 'remember'); });
  test('consulta recuerdos', () { expect(interpret('qué recuerdas').kind, 'list'); });
  test('búsqueda musical', () { expect(interpret('pon Romeo Santos').kind, 'youtube'); });
  test('memoria JSON', () { final s = encodeMemories([const HabitMemory('a', 'A', 2)]); expect(decodeMemories(s).first.observations, 2); });
}
