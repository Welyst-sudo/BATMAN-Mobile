import 'package:flutter/material.dart';

class BatSkin {
  final String id;
  final String name;
  final String tagline;
  final Color bg;
  final Color surface;
  final Color accent;
  final Color accent2;
  final Color text;
  final Color onAccent;
  final double radius;
  final bool outlined;
  final bool light;
  const BatSkin({
    required this.id,
    required this.name,
    required this.tagline,
    required this.bg,
    required this.surface,
    required this.accent,
    required this.accent2,
    required this.text,
    required this.onAccent,
    required this.radius,
    required this.outlined,
    required this.light,
  });

  ThemeData theme() {
    final base = ColorScheme.fromSeed(
      seedColor: accent,
      brightness: light ? Brightness.light : Brightness.dark,
    );
    final scheme = base.copyWith(
      primary: accent,
      onPrimary: onAccent,
      secondary: accent2,
      surface: surface,
      onSurface: text,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      appBarTheme: AppBarTheme(backgroundColor: bg, foregroundColor: text, elevation: 0),
    );
  }
}

const List<BatSkin> skins = <BatSkin>[
  BatSkin(
    id: 'gotham', name: 'Gotham', tagline: 'Negro y amarillo clásico',
    bg: Color(0xFF0B0B0D), surface: Color(0xFF17171B), accent: Color(0xFFDFC24A), accent2: Color(0xFFFFE680),
    text: Color(0xFFEDEDED), onAccent: Color(0xFF111111), radius: 14, outlined: false, light: false),
  BatSkin(
    id: 'batmovil', name: 'Batmóvil', tagline: 'Azul neón, bordes angulares',
    bg: Color(0xFF070D14), surface: Color(0xFF0F1B28), accent: Color(0xFF29B6F6), accent2: Color(0xFF80D8FF),
    text: Color(0xFFE3F2FD), onAccent: Color(0xFF04121C), radius: 3, outlined: true, light: false),
  BatSkin(
    id: 'rojo', name: 'Murciélago Rojo', tagline: 'Rojo intenso, formas redondas',
    bg: Color(0xFF120708), surface: Color(0xFF1F0D10), accent: Color(0xFFFF4D4D), accent2: Color(0xFFFF9E80),
    text: Color(0xFFFFEBEE), onAccent: Color(0xFF1A0000), radius: 24, outlined: false, light: false),
  BatSkin(
    id: 'nightwing', name: 'Nightwing', tagline: 'Violeta y cian con contornos',
    bg: Color(0xFF07070F), surface: Color(0xFF121224), accent: Color(0xFF7C4DFF), accent2: Color(0xFF18FFFF),
    text: Color(0xFFEDE7F6), onAccent: Color(0xFFFFFFFF), radius: 10, outlined: true, light: false),
  BatSkin(
    id: 'senal', name: 'Bat-Señal', tagline: 'Claro, para usar a la luz del día',
    bg: Color(0xFFF4F1E8), surface: Color(0xFFFFFFFF), accent: Color(0xFF1C1C1C), accent2: Color(0xFFE0A800),
    text: Color(0xFF1C1C1C), onAccent: Color(0xFFFFFFFF), radius: 18, outlined: false, light: true),
];

final ValueNotifier<BatSkin> currentSkin = ValueNotifier<BatSkin>(skins.first);

/// Devuelve la skin activa y registra la dependencia con el tema para reconstruir al cambiarla.
BatSkin skinOf(BuildContext context) {
  Theme.of(context);
  return currentSkin.value;
}

class BatCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;
  const BatCard({super.key, required this.child, this.onTap, this.padding = const EdgeInsets.all(14)});

  @override
  Widget build(BuildContext context) {
    final s = skinOf(context);
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: s.surface,
        borderRadius: BorderRadius.circular(s.radius),
        border: Border.all(
          color: s.outlined ? s.accent : s.accent.withAlpha(45),
          width: s.outlined ? 1.4 : 1,
        ),
      ),
      child: child,
    );
    final tap = onTap;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: tap == null ? box : GestureDetector(onTap: tap, child: box),
    );
  }
}
