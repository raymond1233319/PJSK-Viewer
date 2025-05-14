import 'package:flutter/material.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/audio_handler.dart';

class AppGlobals {
  static String databaseUrl = 'https://sekai-world.github.io';
  static String assetUrl = 'https://storage.sekai.best';
  static String localizationUrl = 'https://i18n-json.sekai.best';
  static String apiUrl = 'https://api.sekai.best';
  static String region = 'jp';
  static String jpAssetUrl = 'https://storage.sekai.best/sekai-jp-assets';
  static String jpDatabaseUrl =
      'https://sekai-world.github.io/sekai-master-db-diff';
  static String newsUrl = 'https://production-web.sekai.colorfulpalette.org/';
  static late PJSKAudioHandler audioHandler;
  static late ContentLocalizations i18n;
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static void reset() {
    databaseUrl = 'https://sekai-world.github.io';
    assetUrl = 'https://storage.sekai.best';
    localizationUrl = 'https://i18n-json.sekai.best';
    apiUrl = 'https://api.sekai.best';
    region = 'jp';
  }
}
