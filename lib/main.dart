import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/event_detail.dart';
import 'package:pjsk_viewer/pages/home.dart';
import 'package:pjsk_viewer/pages/music_detail.dart';
import 'package:pjsk_viewer/utils/cache_manager.dart';
import 'package:pjsk_viewer/utils/database/database.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:audio_service/audio_service.dart';
import 'package:pjsk_viewer/utils/audio_handler.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(Phoenix(child: const AppInitializer()));
}

class AppInitializer extends StatefulWidget {
  const AppInitializer({super.key});

  @override
  State<AppInitializer> createState() => _AppInitializerState();
}

class _AppInitializerState extends State<AppInitializer> {
  final List<String> _logs = [];
  late final Future<void> _initFuture;
  late Locale _initialLocale;

  @override
  void initState() {
    super.initState();
    _initFuture = _initAll();
  }

  Future<void> _initAll() async {
    await setLink();
    await _setLocale();
    await databaseInitialization((msg) {
      setState(() => _logs.add(msg));
    });
    await setBackgroundMusic();
    _setupNotificationNavigation();
  }

  Future<void> _setLocale() async {
    // load saved locale
    final prefs = await SharedPreferences.getInstance();
    String? code = prefs.getString('app_locale');

    if (code == null) {
      // use system locale if no saved locale
      final systemLocale = WidgetsBinding.instance.platformDispatcher.locale;
      code = systemLocale.languageCode;
      if (systemLocale.countryCode != null) {
        code += '_${systemLocale.countryCode}';
      }
    }
    // find the matching locale
    final match = supportedLocales.firstWhere(
      (supportedLocale) => supportedLocale.code == code,
      orElse: () => supportedLocales.first,
    );
    _initialLocale = match.locale;
    // save locale to shared preferences
    await prefs.setString('app_locale', match.code);
  }

  Future<void> setLink() async {
    final prefs = await SharedPreferences.getInstance();
    AppGlobals.reset();
    AppGlobals.region = prefs.getString('region') ?? 'jp';
    final String region = AppGlobals.region == 'tw' ? 'tc' : AppGlobals.region;
    AppGlobals.databaseUrl =
        prefs.getString('database_url') ?? AppGlobals.databaseUrl;
    AppGlobals.assetUrl = prefs.getString('asset_url') ?? AppGlobals.assetUrl;
    AppGlobals.localizationUrl =
        prefs.getString('localization_url') ?? AppGlobals.localizationUrl;
    AppGlobals.apiUrl = prefs.getString('api_url') ?? AppGlobals.apiUrl;
    if (AppGlobals.region == 'jp') {
      AppGlobals.databaseUrl = '${AppGlobals.databaseUrl}/sekai-master-db-diff';
    } else {
      AppGlobals.databaseUrl =
          '${AppGlobals.databaseUrl}/sekai-master-db-$region-diff';
    }
    AppGlobals.assetUrl = '${AppGlobals.assetUrl}/sekai-$region-assets';
    if (prefs.getString('news_url') != null) {
      AppGlobals.newsUrl = prefs.getString('news_url')!;
    } else {
      switch (AppGlobals.region) {
        case 'jp':
          AppGlobals.newsUrl =
              'https://production-web.sekai.colorfulpalette.org/';
          break;
        case 'en':
          AppGlobals.newsUrl = 'https://n-production-web.sekai-en.com/';
          break;
        default:
          AppGlobals.newsUrl = '';
      }
    }
  }

  Future<void> setBackgroundMusic() async {
    AppGlobals.audioHandler = await AudioService.init(
      builder: () => PJSKAudioHandler(),
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'com.pjskviewer.channel.audio',
      ),
      cacheManager: PJSKImageCacheManager.instance,
    );
  }

  // Listen for notification clicks
  void _setupNotificationNavigation() {
    AudioService.notificationClicked.listen((mediaItemId) {
      // Get the currently playing media item
      final mediaItem = AppGlobals.audioHandler.currentMediaItem;
      if (mediaItem == null) return;

      // Check the media type and navigate accordingly
      if (mediaItem.extras?['type'] == 'music') {
        final trackId = mediaItem.extras?['trackId'] as int;
        AppGlobals.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => MusicDetailPage(musicId: trackId),
          ),
        );
      } else if (mediaItem.extras?['type'] == 'event') {
        final eventId = mediaItem.extras?['eventId'] as int;
        AppGlobals.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (context) => EventDetailPage(eventId: eventId),
          ),
        );
      } else {
        // Navigate to home page
        AppGlobals.navigatorKey.currentState?.push(
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Expanded(
                      child: ListView(
                        children: _logs.map((log) => Text(log)).toList(),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return MyApp(initialLocale: _initialLocale);
      },
    );
  }
}

class MyApp extends StatelessWidget {
  final Locale initialLocale;

  const MyApp({super.key, required this.initialLocale});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "PJSK Viewer",
      navigatorKey: AppGlobals.navigatorKey,
      localizationsDelegates: const [
        AppLocalizationsDelegate(),
        ContentLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      localeResolutionCallback: (_, __) {
        return initialLocale;
      },
      home: const HomePage(),
    );
  }
}
