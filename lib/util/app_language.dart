import 'package:flutter/widgets.dart';

import '../lock/lock_store.dart';
import 'strings_en.dart';
import 'strings_id.dart';

/// The two languages of the app. Indonesian is the default.
enum AppLang {
  id('Bahasa Indonesia'),
  en('English');

  const AppLang(this.label);
  final String label;
}

/// The chosen language, kept on the device. Text is written in Indonesian in
/// the code; [tr] gives the English version from [kEnglish] when English is
/// chosen (and falls back to the Indonesian text when there is none yet).
class AppLanguage {
  AppLanguage._();

  static final AppLanguage shared = AppLanguage._();

  static const _key = 'app_language';

  final ValueNotifier<AppLang> current = ValueNotifier(AppLang.id);

  /// Tests only: show the text exactly as written in the code, with no
  /// translation. The language tests turn this off.
  bool passthrough = false;

  /// Where the choice is kept. Tests use memory.
  LockStore store = const SecureLockStore();

  /// Reads the saved choice. A failure keeps Indonesian.
  Future<void> load([LockStore? store]) async {
    try {
      final v = await (store ?? this.store).read(_key);
      current.value = v == 'en' ? AppLang.en : AppLang.id;
    } catch (_) {}
  }

  /// Saves the choice and rebuilds every screen.
  Future<void> set(AppLang lang, [LockStore? store]) async {
    current.value = lang;
    rebuildAll();
    try {
      await (store ?? this.store).write(_key, lang.name);
    } catch (_) {}
  }
}

/// The text in the chosen language. [text] is the text as written in the
/// code, Indonesian or English. Indonesian chosen: English texts become
/// Indonesian ([kIndonesian]). English chosen: Indonesian texts become
/// English ([kEnglish]). A text with no entry stays as it is.
String tr(String text) {
  final app = AppLanguage.shared;
  if (app.passthrough) return text;
  return app.current.value == AppLang.en
      ? (kEnglish[text] ?? text)
      : (kIndonesian[text] ?? text);
}

/// Marks every widget to rebuild, so text written with [tr] changes at once
/// (the usual way to switch language without restarting).
void rebuildAll() {
  void visit(Element e) {
    e.markNeedsBuild();
    e.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
}
