import 'package:flutter/material.dart';
import 'app_state.dart';
import 'skins.dart';

class SettingsPage extends StatefulWidget {
  final AppState app;
  const SettingsPage({super.key, required this.app});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _key;
  late final TextEditingController _model;
  late final TextEditingController _url;
  late final TextEditingController _token;

  @override
  void initState() {
    super.initState();
    final a = widget.app;
    _key = TextEditingController(text: a.apiKey);
    _model = TextEditingController(text: a.model);
    _url = TextEditingController(text: a.pcUrl);
    _token = TextEditingController(text: a.pcToken);
  }

  @override
  void dispose() {
    _key.dispose();
    _model.dispose();
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    await widget.app.saveConnection(
      apiKeyValue: _key.text,
      modelValue: _model.text,
      pcUrlValue: _url.text,
      pcTokenValue: _token.text,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardado')));
  }

  Future<void> _testPc() async {
    await _save();
    await widget.app.refreshPc();
    if (!mounted) return;
    final app = widget.app;
    final host = app.pcStatus == null ? 'tu PC' : '${app.pcStatus!["host"]}';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(app.pcError ?? 'Conectado a $host')),
    );
  }

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final app = widget.app;
        final skin = skinOf(context);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _title('Apariencia (skins)'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final s in skins)
                  GestureDetector(
                    onTap: () => app.setSkin(s),
                    child: Container(
                      width: 150,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: s.bg,
                        borderRadius: BorderRadius.circular(s.radius),
                        border: Border.all(color: s.accent, width: s.id == skin.id ? 3 : 1),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Expanded(
                              child: Text(s.name,
                                  style: TextStyle(color: s.accent, fontWeight: FontWeight.bold)),
                            ),
                            if (s.id == skin.id) Icon(Icons.check_circle, size: 16, color: s.accent),
                          ]),
                          const SizedBox(height: 4),
                          Text(s.tagline, style: TextStyle(color: s.text, fontSize: 11)),
                          const SizedBox(height: 8),
                          Row(children: [
                            Container(width: 18, height: 8, color: s.accent),
                            const SizedBox(width: 4),
                            Container(width: 18, height: 8, color: s.accent2),
                            const SizedBox(width: 4),
                            Container(width: 18, height: 8, color: s.surface),
                          ]),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            _title('Inteligencia artificial (OpenRouter)'),
            TextField(
              controller: _key,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'API key de OpenRouter', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _model,
              decoration: const InputDecoration(
                  labelText: 'Modelo (usa uno gratuito, termina en :free)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 6),
            const Text(
              'Tus mensajes al chat (y las preferencias que me pediste recordar) se envían a OpenRouter para '
              'generar la respuesta. No pegues claves ni datos sensibles en el chat.',
              style: TextStyle(fontSize: 12),
            ),
            _title('Tu PC'),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                  labelText: 'Dirección (ej. 192.168.1.20:8765)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _token,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Token del servidor del PC', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(child: FilledButton(onPressed: _save, child: const Text('Guardar'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton(onPressed: _testPc, child: const Text('Probar conexión'))),
            ]),
            _title('Voz y aprendizaje'),
            SwitchListTile(
              title: const Text('Responder en voz alta'),
              value: app.speak,
              onChanged: app.setSpeak,
            ),
            SwitchListTile(
              title: const Text('Aprender mis costumbres'),
              subtitle: const Text('Guarda solo categoría y hora de lo que haces, en este celular.'),
              value: app.learn,
              onChanged: app.setLearn,
            ),
            SwitchListTile(
              title: const Text('Aprender más rápido (pruebas)'),
              subtitle: const Text('Detecta un hábito con solo 2 repeticiones, aunque sea el mismo día.'),
              value: app.fastLearn,
              onChanged: app.setFastLearn,
            ),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }
}
