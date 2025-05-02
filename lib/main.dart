import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/home.dart';
import 'package:pjsk_viewer/utils/database/database.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
    await _setLocale();
    await databaseInitialization((msg) {
      setState(() => _logs.add(msg));
    });
  }

  Future<void> _setLocale() async {
    // load saved locale    rm -r android/app/src/main/res/mipmap-*/
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
