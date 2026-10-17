import 'package:flutter/material.dart';
import 'app_state.dart';
import 'assistant_logic.dart';
import 'habits.dart';
import 'skins.dart';

class HabitsPage extends StatelessWidget {
  final AppState app;
  const HabitsPage({super.key, required this.app});

  Widget _title(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
      );

  Future<bool> _confirm(BuildContext context, String title, String body) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Borrar')),
        ],
      ),
    );
    return ok == true;
  }

  Future<void> _routineDialog(BuildContext context) async {
    final controller = TextEditingController(text: app.routineText);
    var enabled = app.routineEnabled;
    var selected = TimeOfDay(hour: app.routineMinute ~/ 60, minute: app.routineMinute % 60);
    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Rutina diaria'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: const Text('Recordatorio diario'),
                value: enabled,
                onChanged: (v) => update(() => enabled = v),
              ),
              TextField(
                controller: controller,
                maxLines: 2,
                decoration: const InputDecoration(labelText: 'Texto del recordatorio'),
              ),
              TextButton(
                onPressed: () async {
                  final t = await showTimePicker(context: ctx, initialTime: selected);
                  if (t != null) update(() => selected = t);
                },
                child: Text('Hora: ${selected.format(ctx)}'),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Guardar')),
          ],
        ),
      ),
    );
    if (save == true) {
      await app.saveRoutine(enabled, selected.hour * 60 + selected.minute, controller.text.trim());
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        final skin = skinOf(context);
        final habits = app.habits;
        final items = <Widget>[];

        items.add(_title('Lo que BATMAN aprendió de ti'));
        if (habits.isEmpty) {
          items.add(BatCard(
            child: Text(
              'Todavía estoy observando (${app.events.length} acciones registradas). '
              'Cuando repitas algo a la misma hora en varios días, aparecerá aquí y podré avisarte '
              '10 minutos antes. Solo guardo la categoría y la hora, nunca el texto de tus mensajes.',
            ),
          ));
        }
        for (final h in habits) {
          final active = app.autoHabits || app.habitOn.contains(h.category);
          items.add(BatCard(
            child: Row(children: [
              Icon(Icons.auto_awesome, color: skin.accent2),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(habitNames[h.category] ?? h.category, style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    'Sueles hacerlo hacia las ${formatMinute(h.minute)} (${h.count} veces en ${h.days} días). '
                    'Aviso a las ${formatMinute(h.reminderMinute)}.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ]),
              ),
              Switch(
                value: active,
                onChanged: app.autoHabits ? null : (v) => app.setHabit(h.category, v),
              ),
            ]),
          ));
        }
        items.add(BatCard(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          child: SwitchListTile(
            title: const Text('Avisarme de todos los hábitos que aprenda'),
            subtitle: const Text('Programa las notificaciones solo, sin que tengas que activarlas una por una.'),
            value: app.autoHabits,
            onChanged: app.setAutoHabits,
          ),
        ));
        items.add(Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: FilledButton.tonalIcon(
            onPressed: app.testNotification,
            icon: const Icon(Icons.notifications_active),
            label: const Text('Probar notificación ahora'),
          ),
        ));

        items.add(_title('Rutina manual'));
        items.add(BatCard(
          onTap: () => _routineDialog(context),
          child: Row(children: [
            Icon(Icons.alarm, color: skin.accent2),
            const SizedBox(width: 12),
            Expanded(
              child: Text(app.routineEnabled
                  ? 'Activa a las ${formatMinute(app.routineMinute)}: ${app.routineText}'
                  : 'Desactivada. Toca para configurarla.'),
            ),
            const Icon(Icons.edit, size: 18),
          ]),
        ));

        items.add(_title('Preferencias que me pediste recordar'));
        if (app.memories.isEmpty) {
          items.add(const BatCard(child: Text('Nada guardado. Dime, por ejemplo: "recuerda que me gusta la bachata".')));
        }
        for (final HabitMemory m in app.memories) {
          items.add(BatCard(
            padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
            child: Row(children: [
              Expanded(child: Text(m.value)),
              IconButton(onPressed: () => app.forgetMemory(m), icon: const Icon(Icons.delete_outline)),
            ]),
          ));
        }
        items.add(Row(children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                if (await _confirm(context, 'Borrar memoria', 'Se eliminarán todas las preferencias guardadas.')) {
                  await app.clearMemories();
                }
              },
              child: const Text('Borrar memoria'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: () async {
                if (await _confirm(context, 'Olvidar hábitos', 'BATMAN empezará a aprender desde cero.')) {
                  await app.clearEvents();
                }
              },
              child: const Text('Olvidar hábitos'),
            ),
          ),
        ]));
        items.add(const SizedBox(height: 24));
        return ListView(padding: const EdgeInsets.all(16), children: items);
      },
    );
  }
}
