/// App languages.
///
/// Text is written in English in the code and passed through [tr], which
/// returns the translation for the current language (or the English text if
/// there is none). Translations live in translations.dart.
library;

import 'translations.dart';

class Lang {
  final String code;
  final String name; // in its own language
  final String hint; // in English
  final bool rtl;
  const Lang(this.code, this.name, this.hint, {this.rtl = false});
}

const kLanguages = [
  Lang('rur', 'Roman Urdu', 'Urdu in English letters'),
  Lang('en', 'English', 'English'),
  Lang('ur', 'اردو', 'Urdu', rtl: true),
  Lang('hi', 'हिन्दी', 'Hindi'),
];

String _current = 'rur';
String get currentLang => _current;
bool get isRtl => kLanguages.any((l) => l.code == _current && l.rtl);
void setCurrentLang(String code) =>
    _current = kLanguages.any((l) => l.code == code) ? code : 'rur';

/// Translate [s] into the current language.
String tr(String s) =>
    _current == 'en' ? s : (kTranslations[_current]?[s] ?? s);

/// Translate and fill `{0}`, `{1}` … placeholders.
String trf(String s, List<Object> args) {
  var out = tr(s);
  for (var i = 0; i < args.length; i++) {
    out = out.replaceAll('{$i}', '${args[i]}');
  }
  return out;
}
