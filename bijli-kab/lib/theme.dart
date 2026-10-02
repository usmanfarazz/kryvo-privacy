import 'package:flutter/material.dart';

/// One selectable colour theme.
class BPalette {
  final String id;
  final String name;
  final String emoji;
  final bool dark;
  final Color bg, bg2, panel, panel2, line, txt, muted, accent, accent2;
  final Color on, off;
  const BPalette({
    required this.id,
    required this.name,
    required this.emoji,
    required this.dark,
    required this.bg,
    required this.bg2,
    required this.panel,
    required this.panel2,
    required this.line,
    required this.txt,
    required this.muted,
    required this.accent,
    required this.accent2,
    this.on = const Color(0xFF22E58B),
    this.off = const Color(0xFFFF4D5E),
  });
}

/// Runtime-switchable palette. Every screen reads these getters, so changing
/// [BK.current] and rebuilding re-themes the whole app.
class BK {
  static const List<BPalette> palettes = [
    BPalette(
      id: 'volt',
      name: 'Neon Volt',
      emoji: '⚡',
      dark: true,
      bg: Color(0xFF0A0B10),
      bg2: Color(0xFF15131F),
      panel: Color(0xFF15161F),
      panel2: Color(0xFF1C1D29),
      line: Color(0xFF2A2B3A),
      txt: Color(0xFFF4F4F8),
      muted: Color(0xFF9A9BB0),
      accent: Color(0xFFFFD60A),
      accent2: Color(0xFFFF8A00),
    ),
    BPalette(
      id: 'midnight',
      name: 'Midnight Blue',
      emoji: '🌙',
      dark: true,
      bg: Color(0xFF0B0F17),
      bg2: Color(0xFF101A2E),
      panel: Color(0xFF131A26),
      panel2: Color(0xFF18212F),
      line: Color(0xFF243044),
      txt: Color(0xFFE7EDF5),
      muted: Color(0xFF93A1B5),
      accent: Color(0xFF4F8CFF),
      accent2: Color(0xFF00D4FF),
    ),
    BPalette(
      id: 'amoled',
      name: 'Pure Black',
      emoji: '🖤',
      dark: true,
      bg: Color(0xFF000000),
      bg2: Color(0xFF07070A),
      panel: Color(0xFF0E0E11),
      panel2: Color(0xFF17171B),
      line: Color(0xFF26262C),
      txt: Color(0xFFF2F2F2),
      muted: Color(0xFF9A9AA2),
      accent: Color(0xFFFFFFFF),
      accent2: Color(0xFFB0B0B8),
    ),
    BPalette(
      id: 'cyber',
      name: 'Cyber Pink',
      emoji: '🌆',
      dark: true,
      bg: Color(0xFF0D0716),
      bg2: Color(0xFF1A0B2A),
      panel: Color(0xFF180F26),
      panel2: Color(0xFF211533),
      line: Color(0xFF34224D),
      txt: Color(0xFFF6EEFF),
      muted: Color(0xFFAE9BC6),
      accent: Color(0xFFFF2E93),
      accent2: Color(0xFF8B5CF6),
    ),
    BPalette(
      id: 'sunset',
      name: 'Solar Sunset',
      emoji: '🌇',
      dark: true,
      bg: Color(0xFF140D0A),
      bg2: Color(0xFF2A130B),
      panel: Color(0xFF21150F),
      panel2: Color(0xFF2A1B13),
      line: Color(0xFF3A281E),
      txt: Color(0xFFF6ECE6),
      muted: Color(0xFFB8A195),
      accent: Color(0xFFFF7A45),
      accent2: Color(0xFFFFC145),
    ),
    BPalette(
      id: 'ocean',
      name: 'Ocean Teal',
      emoji: '🌊',
      dark: true,
      bg: Color(0xFF07151A),
      bg2: Color(0xFF0A2229),
      panel: Color(0xFF0D2027),
      panel2: Color(0xFF102830),
      line: Color(0xFF1D3A44),
      txt: Color(0xFFE3F2F5),
      muted: Color(0xFF8FB3BC),
      accent: Color(0xFF00D1C1),
      accent2: Color(0xFF00A3FF),
    ),
    BPalette(
      id: 'royal',
      name: 'Royal Purple',
      emoji: '👑',
      dark: true,
      bg: Color(0xFF0F0B1A),
      bg2: Color(0xFF1B1233),
      panel: Color(0xFF1A1428),
      panel2: Color(0xFF211A33),
      line: Color(0xFF2F2647),
      txt: Color(0xFFEEE9F8),
      muted: Color(0xFFA59DBB),
      accent: Color(0xFFA78BFA),
      accent2: Color(0xFFF0ABFC),
    ),
    BPalette(
      id: 'emerald',
      name: 'Emerald',
      emoji: '💚',
      dark: true,
      bg: Color(0xFF07130E),
      bg2: Color(0xFF0B2218),
      panel: Color(0xFF0E2018),
      panel2: Color(0xFF12291F),
      line: Color(0xFF1E3D2F),
      txt: Color(0xFFE4F3EC),
      muted: Color(0xFF8FB5A3),
      accent: Color(0xFF22C55E),
      accent2: Color(0xFFA3E635),
    ),
    BPalette(
      id: 'gold',
      name: 'Black Gold',
      emoji: '🏆',
      dark: true,
      bg: Color(0xFF0C0A06),
      bg2: Color(0xFF1A150A),
      panel: Color(0xFF17140C),
      panel2: Color(0xFF1E1A10),
      line: Color(0xFF2F2918),
      txt: Color(0xFFF6F0E1),
      muted: Color(0xFFB3A781),
      accent: Color(0xFFEAB308),
      accent2: Color(0xFFF59E0B),
    ),
    BPalette(
      id: 'light',
      name: 'Clean White',
      emoji: '🤍',
      dark: false,
      bg: Color(0xFFF4F6FB),
      bg2: Color(0xFFE6ECF8),
      panel: Color(0xFFFFFFFF),
      panel2: Color(0xFFEDF1F7),
      line: Color(0xFFD9E1EE),
      txt: Color(0xFF1A2230),
      muted: Color(0xFF66748C),
      accent: Color(0xFF2B64D6),
      accent2: Color(0xFF7C3AED),
      on: Color(0xFF0FA968),
      off: Color(0xFFE5394B),
    ),
    BPalette(
      id: 'sunrise',
      name: 'Sunrise Light',
      emoji: '🌅',
      dark: false,
      bg: Color(0xFFFFF8EF),
      bg2: Color(0xFFFFE9CC),
      panel: Color(0xFFFFFFFF),
      panel2: Color(0xFFFFF1E0),
      line: Color(0xFFF1DEC4),
      txt: Color(0xFF2A1D10),
      muted: Color(0xFF85705A),
      accent: Color(0xFFF08A00),
      accent2: Color(0xFFE5484D),
      on: Color(0xFF0FA968),
      off: Color(0xFFE5394B),
    ),
    BPalette(
      id: 'mint',
      name: 'Mint Light',
      emoji: '🌿',
      dark: false,
      bg: Color(0xFFF2FAF6),
      bg2: Color(0xFFDDF3E8),
      panel: Color(0xFFFFFFFF),
      panel2: Color(0xFFE6F4ED),
      line: Color(0xFFCFE6DA),
      txt: Color(0xFF15261E),
      muted: Color(0xFF5E7A6C),
      accent: Color(0xFF059669),
      accent2: Color(0xFF0EA5E9),
      on: Color(0xFF0FA968),
      off: Color(0xFFE5394B),
    ),
  ];

  static BPalette current = palettes.first;

  static void setTheme(String id) => current = palettes.firstWhere(
    (p) => p.id == id,
    orElse: () => palettes.first,
  );

  static Color get bg => current.bg;
  static Color get bg2 => current.bg2;
  static Color get panel => current.panel;
  static Color get panel2 => current.panel2;
  static Color get line => current.line;
  static Color get txt => current.txt;
  static Color get muted => current.muted;
  static Color get accent => current.accent;
  static Color get accent2 => current.accent2;
  static Color get on => current.on;
  static Color get off => current.off;
  static Color get warn => const Color(0xFFFFB020);
  static bool get dark => current.dark;

  /// Text colour that reads well on top of [accent].
  static Color get onAccent =>
      accent.computeLuminance() > 0.45 ? const Color(0xFF111111) : Colors.white;

  static LinearGradient get accentGradient => LinearGradient(
    colors: [accent, accent2],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static LinearGradient get backgroundGradient => LinearGradient(
    colors: [bg2, bg, bg],
    stops: const [0, 0.45, 1],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData theme() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: accent,
          brightness: dark ? Brightness.dark : Brightness.light,
        ).copyWith(
          primary: accent,
          onPrimary: onAccent,
          secondary: accent2,
          surface: panel,
          onSurface: txt,
          error: off,
        );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      brightness: dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      dividerColor: line,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: txt,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: txt,
          fontSize: 20,
          fontWeight: FontWeight.w800,
        ),
      ),
      cardTheme: CardThemeData(
        color: panel,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: line),
        ),
      ),
      textTheme: Typography.material2021().black.apply(
        bodyColor: txt,
        displayColor: txt,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panel2,
        labelStyle: TextStyle(color: muted),
        hintStyle: TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: accent, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          foregroundColor: onAccent,
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: txt,
          side: BorderSide(color: line),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: accent),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? onAccent : muted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? accent : panel2,
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: accent,
        thumbColor: accent,
        inactiveTrackColor: line,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panel2,
        selectedColor: accent.withValues(alpha: 0.22),
        side: BorderSide(color: line),
        labelStyle: TextStyle(color: txt, fontWeight: FontWeight.w600),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panel2,
        contentTextStyle: TextStyle(color: txt, fontWeight: FontWeight.w600),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panel,
        modalBackgroundColor: panel,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: panel,
        indicatorColor: accent.withValues(alpha: 0.2),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (s) => TextStyle(
            fontSize: 11.5,
            fontWeight: s.contains(WidgetState.selected)
                ? FontWeight.w800
                : FontWeight.w500,
            color: s.contains(WidgetState.selected) ? txt : muted,
          ),
        ),
        iconTheme: WidgetStateProperty.resolveWith(
          (s) => IconThemeData(
            color: s.contains(WidgetState.selected) ? accent : muted,
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(iconColor: accent, textColor: txt),
    );
  }
}
