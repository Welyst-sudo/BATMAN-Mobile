import 'package:flutter/material.dart';
import 'app_state.dart';
import 'chat_page.dart';
import 'habits_page.dart';
import 'pc_page.dart';
import 'settings_page.dart';
import 'skins.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final app = AppState();
  try {
    await app.init();
  } catch (_) {}
  runApp(BatmanApp(app: app));
}

class BatmanApp extends StatelessWidget {
  final AppState app;
  const BatmanApp({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<BatSkin>(
      valueListenable: currentSkin,
      builder: (context, skin, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'BATMAN Mobile',
        theme: skin.theme(),
        home: Shell(app: app),
      ),
    );
  }
}

class Shell extends StatelessWidget {
  final AppState app;
  const Shell({super.key, required this.app});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app,
      builder: (context, _) {
        const titles = ['🦇 BATMAN', '🖥️ Mi PC', '🧠 Hábitos', '⚙️ Ajustes'];
        return Scaffold(
          appBar: AppBar(title: Text(titles[app.tab])),
          body: SafeArea(
            child: IndexedStack(
              index: app.tab,
              children: [
                ChatPage(app: app),
                PcPage(app: app),
                HabitsPage(app: app),
                SettingsPage(app: app),
              ],
            ),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: app.tab,
            onDestinationSelected: app.setTab,
            destinations: const [
              NavigationDestination(icon: Icon(Icons.chat_bubble_outline), label: 'Chat'),
              NavigationDestination(icon: Icon(Icons.computer), label: 'PC'),
              NavigationDestination(icon: Icon(Icons.auto_awesome), label: 'Hábitos'),
              NavigationDestination(icon: Icon(Icons.settings), label: 'Ajustes'),
            ],
          ),
        );
      },
    );
  }
}
