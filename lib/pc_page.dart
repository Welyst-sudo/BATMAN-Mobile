import 'dart:async';
import 'package:flutter/material.dart';
import 'app_state.dart';
import 'skins.dart';

class PcPage extends StatefulWidget {
  final AppState app;
  const PcPage({super.key, required this.app});
  @override
  State<PcPage> createState() => _PcPageState();
}

class _PcPageState extends State<PcPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) {
      final a = widget.app;
      if (a.tab == 1 && a.pc != null && !a.pcLoading) a.refreshPc();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Widget _meter(BatSkin skin, String label, dynamic value, String detail) {
    final v = value is num ? value.toDouble() : null;
    final hot = v != null && v >= 85;
    final fill = v == null ? 0.0 : (v / 100).clamp(0.0, 1.0).toDouble();
    return BatCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(v == null ? 'n/d' : '${v.round()}%'),
          ]),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: fill,
            minHeight: 8,
            color: hot ? Colors.redAccent : skin.accent,
            backgroundColor: skin.accent.withAlpha(35),
          ),
          if (detail.isNotEmpty)
            Padding(padding: const EdgeInsets.only(top: 6), child: Text(detail, style: const TextStyle(fontSize: 12))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.app,
      builder: (context, _) {
        final app = widget.app;
        final skin = skinOf(context);
        final s = app.pcStatus;
        final items = <Widget>[];

        if (app.pc == null) {
          items.add(BatCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Conecta tu PC', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 6),
                const Text('1. En tu PC abre pc_server (iniciar_servidor_pc.bat).\n'
                    '2. Copia la dirección y el token que muestra.\n'
                    '3. Pégalos en Ajustes. El celular y la PC deben estar en el mismo Wi-Fi.'),
                const SizedBox(height: 10),
                FilledButton(onPressed: () => app.setTab(3), child: const Text('Ir a Ajustes')),
              ],
            ),
          ));
        } else {
          if (app.pcLoading) items.add(const LinearProgressIndicator(minHeight: 3));
          if (app.pcError != null) {
            items.add(BatCard(child: Text(app.pcError!, style: const TextStyle(color: Colors.redAccent))));
          }
          if (s != null) {
            items.add(BatCard(
              child: Row(children: [
                Icon(Icons.computer, color: skin.accent2),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('${s["host"] ?? "PC"}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('${s["os"] ?? ""}  ·  encendido ${s["uptime_h"] ?? "?"} h', style: const TextStyle(fontSize: 12)),
                  ]),
                ),
              ]),
            ));
            items.add(_meter(skin, 'Procesador', s['cpu'], ''));
            items.add(_meter(skin, 'Memoria RAM', s['ram'], '${s["ram_used_gb"] ?? "?"} de ${s["ram_total_gb"] ?? "?"} GB'));
            items.add(_meter(skin, 'Disco', s['disk'], '${s["disk_free_gb"] ?? "?"} GB libres'));
            if (s['battery'] is num) {
              items.add(_meter(skin, s['plugged'] == true ? 'Batería (cargando)' : 'Batería', s['battery'], ''));
            }
            final top = s['top'];
            if (top is List && top.isNotEmpty) {
              final lines = top.map((e) => '${e["name"]}: ${e["mem_mb"]} MB').join('\n');
              items.add(BatCard(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Programas que más memoria usan', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(lines, style: const TextStyle(fontSize: 12)),
                ]),
              ));
            }
          }
          if (app.pcTasks.isNotEmpty) {
            items.add(const Padding(
              padding: EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text('Tareas y optimización', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ));
          }
          for (final t in app.pcTasks) {
            final id = t['id'].toString();
            final label = (t['label'] ?? id).toString();
            items.add(Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.play_arrow),
                label: Text(label),
                onPressed: () async {
                  if (t['confirm'] == true) {
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(label),
                        content: const Text('¿Seguro que quieres ejecutar esta acción en tu PC?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ejecutar')),
                        ],
                      ),
                    );
                    if (ok != true) return;
                  }
                  final msg = await app.runPcTask(id);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                },
              ),
            ));
          }
        }
        return RefreshIndicator(
          onRefresh: app.refreshPc,
          child: ListView(padding: const EdgeInsets.all(16), children: items),
        );
      },
    );
  }
}
