import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

class AppLocalizations {
  final Locale locale;
  Map<String, String> _localizedStrings = {};

  AppLocalizations(this.locale);

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        AppLocalizations(const Locale('en', ''));
  }


  Future<void> load() async {
    // Try to load the language file
    String jsonString;

    final String languageCode =
        (locale.countryCode != '')
            ? '${locale.languageCode}-${locale.countryCode}'
            : locale.languageCode;
    try {
      jsonString = await rootBundle.loadString(
        'assets/localization/$languageCode.json',
      );
    } catch (e) {
      // Fallback to English if the requested language is not available
      jsonString = await rootBundle.loadString(
        'assets/localization/en.json',
      );
    }

    Map<String, dynamic> jsonMap = json.decode(jsonString);
    _localizedStrings = jsonMap.map((key, value) {
      return MapEntry(key, value.toString());
    });
  }

  // Generic method to translate any key
  String translate(String key, [String? defaultValue]) {
    return _localizedStrings[key] ?? defaultValue ?? key;
  }
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();
  @override
  bool isSupported(Locale locale) {
    return supportedLocales.any(
      (supportedLocale) =>
          supportedLocale.locale.languageCode == locale.languageCode &&
          (supportedLocale.locale.countryCode == locale.countryCode ||
              supportedLocale.locale.countryCode == ''),
    );
  }

  @override
  Future<AppLocalizations> load(Locale locale) async {
    AppLocalizations localizations = AppLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(AppLocalizationsDelegate old) => false;
}

class SupportedLocale {
  final String code;
  final Locale locale;
  final String name;
  const SupportedLocale({
    required this.code,
    required this.locale,
    required this.name,
  });
}

const List<SupportedLocale> supportedLocales = [
  SupportedLocale(code: 'en', locale: Locale('en', ''), name: 'English'),
  SupportedLocale(code: 'zh_CN', locale: Locale('zh', 'CN'), name: '简体中文'),
  SupportedLocale(code: 'zh_TW', locale: Locale('zh', 'TW'), name: '繁體中文'),
  SupportedLocale(code: 'ja', locale: Locale('ja', ''), name: '日本語'),
  SupportedLocale(code: 'ko', locale: Locale('ko', ''), name: '한국어'),
  SupportedLocale(code: 'fr', locale: Locale('fr', ''), name: 'Français'),
  SupportedLocale(code: 'es', locale: Locale('es', ''), name: 'Español'),
  SupportedLocale(code: 'it', locale: Locale('it', ''), name: 'Italiano'),
  SupportedLocale(code: 'pl', locale: Locale('pl', ''), name: 'Polski'),
  SupportedLocale(
    code: 'pt_BR',
    locale: Locale('pt', 'BR'),
    name: 'Português do Brasil',
  ),
  SupportedLocale(
    code: 'id',
    locale: Locale('id', ''),
    name: 'bahasa Indonesia',
  ),
  SupportedLocale(code: 'th', locale: Locale('th', ''), name: 'ภาษาไทย'),
  SupportedLocale(code: 'ru', locale: Locale('ru', ''), name: 'русский язык'),
  SupportedLocale(code: 'de', locale: Locale('de', ''), name: 'Deutsch'),
  SupportedLocale(code: 'ms', locale: Locale('ms', ''), name: 'bahasa Melayu'),
  SupportedLocale(code: 'ca_ES', locale: Locale('ca_ES', ''), name: 'Català'),
  SupportedLocale(code: 'pt', locale: Locale('pt', ''), name: 'Português'),
  SupportedLocale(
    code: 'ar',
    locale: Locale('ar', ''),
    name: 'اَلْعَرَبِيَّةُ',
  ),
  SupportedLocale(code: 'cs', locale: Locale('cs', ''), name: 'Čeština'),
  SupportedLocale(code: 'bg', locale: Locale('bg', ''), name: 'български език'),
  SupportedLocale(
    code: 'vi_VN',
    locale: Locale('vi_VN', ''),
    name: 'Tiếng Việt',
  ),
];
