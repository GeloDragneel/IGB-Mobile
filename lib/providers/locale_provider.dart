import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleProvider with ChangeNotifier {
  Locale _locale = const Locale('en', 'US');
  static const String _localeKey = 'locale';

  Locale get locale => _locale;

  LocaleProvider() {
    _loadLocale();
  }

  Future<void> _loadLocale() async {
    final prefs = await SharedPreferences.getInstance();
    final localeCode = prefs.getString(_localeKey) ?? 'en';
    _locale = Locale(localeCode, localeCode == 'en' ? 'US' : 'CN');
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (_locale == locale) return;

    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_localeKey, locale.languageCode);
    notifyListeners();
  }

  Future<void> setLanguageCode(String languageCode) async {
    final locale = Locale(languageCode, languageCode == 'en' ? 'US' : 'CN');
    await setLocale(locale);
  }

  bool get isEnglish => _locale.languageCode == 'en';
  bool get isChinese => _locale.languageCode == 'zh';

  String get languageName => isEnglish ? 'English' : '中文';
  String get languageCode => _locale.languageCode.toUpperCase();
}
