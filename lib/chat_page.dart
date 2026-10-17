import 'package:flutter/material.dart';
import 'app_state.dart';
import 'skins.dart';

class ChatPage extends StatefulWidget {
  final AppState app;
  const ChatPage({super.key, required this.app});
  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _input.text;
    _input.clear();
    await widget.app.send(text);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final app = widget.app;
        final skin = skinOf(context);
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Wrap(
                spacing: 8,
                children: [
                  ActionChip(label: const Text('Estado de mi PC'), onPressed: () => app.send('¿Cómo está mi PC?')),
                  ActionChip(label: const Text('¿Qué recuerdas?'), onPressed: () => app.send('qué recuerdas')),
                  ActionChip(label: const Text('Optimiza mi PC'), onPressed: () => app.send('optimiza mi PC')),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: app.chat.length,
                itemBuilder: (context, i) {
                  final m = app.chat[app.chat.length - 1 - i];
                  return Align(
                    alignment: m.fromUser ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                      decoration: BoxDecoration(
                        color: m.fromUser ? skin.accent : skin.surface,
                        borderRadius: BorderRadius.circular(skin.radius),
                        border: m.fromUser ? null : Border.all(color: skin.accent.withAlpha(60)),
                      ),
                      child: SelectableText(
                        m.text,
                        style: TextStyle(color: m.fromUser ? skin.onAccent : skin.text),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (app.thinking) const LinearProgressIndicator(minHeight: 3),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      decoration: InputDecoration(
                        hintText: app.listening
                            ? (app.heard.isEmpty ? 'Escuchando…' : app.heard)
                            : 'Escribe o habla…',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(skin.radius)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filledTonal(
                    onPressed: app.toggleListen,
                    icon: Icon(app.listening ? Icons.stop : Icons.mic),
                  ),
                  IconButton.filled(onPressed: _submit, icon: const Icon(Icons.send)),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
