import 'dart:math';

/// Appliances and UPS maths shared by the Power tools and the UPS reminder.
class Appliance {
  final String id, name, emoji;
  final int watts;
  const Appliance(this.id, this.name, this.emoji, this.watts);
}

const kAppliances = [
  Appliance('fan', 'Ceiling fan', '🌀', 75),
  Appliance('led', 'LED bulb', '💡', 12),
  Appliance('tube', 'Tube light', '🔦', 20),
  Appliance('router', 'WiFi router', '📶', 12),
  Appliance('phone', 'Phone charger', '📱', 10),
  Appliance('laptop', 'Laptop', '💻', 65),
  Appliance('tv', 'LED TV', '📺', 80),
  Appliance('fridge', 'Fridge', '🧊', 150),
  Appliance('pc', 'Desktop PC', '🖥️', 200),
  Appliance('motor', 'Water pump', '🚰', 750),
  Appliance('iron', 'Iron', '👔', 1000),
  Appliance('ac', 'Inverter AC (1 ton)', '❄️', 1100),
];

const kDefaultUpsLoad = {'fan': 2, 'led': 3, 'router': 1, 'phone': 2};

int loadWatts(Map<String, int> counts) =>
    kAppliances.fold(0, (s, a) => s + a.watts * (counts[a.id] ?? 0));

/// Hours a UPS lasts: capacity × voltage × usable depth of discharge
/// (lead-acid 50 %, lithium 90 %) × battery health × 85 % inverter efficiency.
double upsBackupHours({
  required double ah,
  required int volts,
  required bool lithium,
  required double health,
  required int watts,
}) {
  if (watts <= 0) return 0;
  final wh = ah * volts * (lithium ? 0.9 : 0.5) * health * 0.85;
  return max(0, wh / watts);
}

/// Same, from the saved Power-tools settings (defaults if never opened).
double upsHoursFromPrefs(Map<String, dynamic> prefs) {
  final raw = prefs['upsLoad'];
  final counts = raw is Map
      ? raw.map((k, v) => MapEntry('$k', (v as num).toInt()))
      : kDefaultUpsLoad;
  return upsBackupHours(
    ah: (prefs['upsAh'] as num?)?.toDouble() ?? 150,
    volts: (prefs['upsV'] as num?)?.toInt() ?? 12,
    lithium: prefs['upsLi'] == true,
    health: (prefs['upsHealth'] as num?)?.toDouble() ?? 0.85,
    watts: loadWatts(counts),
  );
}
