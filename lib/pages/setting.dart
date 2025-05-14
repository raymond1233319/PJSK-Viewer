import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/cache_manager.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart' show Phoenix;
import 'package:pjsk_viewer/utils/database/database.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  // initial values loaded from prefs
  final Map<String, dynamic> _initial = {};
  // pending changes to apply
  final Map<String, dynamic> _pending = {};

  // Controllers for URL text fields
  final Map<String, TextEditingController> _urlControllers = {};

  String _imageCacheSize = "...";
  String _audioCacheSize = "...";
  String link = '';
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    // Get image cache size
    final imageCacheSize =
        await PJSKImageCacheManager.calculateImageCacheSize();
    // Get audio cache size
    final audioCacheSize = await MusicCacheManager.calculateAudioCacheSize();
    link = (await getApplicationCacheDirectory()).toString();
    if (!mounted) {
      return;
    }
    setState(() {
      _initial['app_locale'] = prefs.getString('app_locale') ?? 'en';
      _initial['db_update_interval_days'] =
          prefs.getInt('db_update_interval_days') ?? 7;
      _initial['region'] = prefs.getString('region') ?? AppGlobals.region;

      // Load URL settings
      _initial['database_url'] = prefs.getString('database_url');
      _initial['asset_url'] = prefs.getString('asset_url');
      _initial['localization_url'] = prefs.getString('localization_url');
      _initial['api_url'] = prefs.getString('api_url');
      _initial['news_url'] = prefs.getString('news_url');
      _imageCacheSize = formatSize(imageCacheSize);
      _audioCacheSize = formatSize(audioCacheSize);
    });
  }

  Future<void> _apply() async {
    if (_pending.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    bool needsRestart = false;
    bool needsReinit = false;
    AppLocalizations? l10n;
    if (mounted) {
      l10n = AppLocalizations.of(context);
    }

    for (var entry in _pending.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(key, value);
        if (key == 'app_locale' || key.contains('url')) needsRestart = true;
        if (key == 'region') needsReinit = true;
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      }
    }

    await _loadSettings();

    if (needsRestart && mounted) {
      showDialog(
        context: context,
        builder:
            (_) => AlertDialog(
              title: Text(l10n!.translate('restart_required_title')),
              content: Text(l10n.translate('restart_required_content')),
              actions: [
                TextButton(
                  child: Text(l10n.translate('later')),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                TextButton(
                  child: Text(l10n.translate('restart_required_button')),
                  onPressed: () {
                    // Ensure context is still valid before using Phoenix
                    if (mounted) {
                      Phoenix.rebirth(context);
                    }
                  },
                ),
              ],
            ),
      );
    }
    if (needsReinit && mounted) {
      // Reinitialize the database
      await clearDatabase();

      // Clear all URL-related preferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('database_url');
      await prefs.remove('asset_url');
      await prefs.remove('localization_url');
      await prefs.remove('api_url');
      await prefs.remove('news_url');
      if (mounted) {
        Phoenix.rebirth(context);
      }
    }
  }

  // Helper method to build URL text fields
  Widget _buildUrlTextField(String key, String defaultValue, String hint) {
    _urlControllers[key] ??= TextEditingController();
    _urlControllers[key]!.text = _pending[key] ?? _initial[key] ?? defaultValue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TextField(
        controller: _urlControllers[key],
        decoration: InputDecoration(
          labelText: key,
          hintText: hint,
          border: OutlineInputBorder(),
          suffixIcon: IconButton(
            icon: Icon(Icons.refresh),
            tooltip: 'Reset to default',
            onPressed: () {
              _urlControllers[key]!.text = defaultValue;
              setState(() => _pending[key] = defaultValue);
            },
          ),
        ),
        onChanged: (value) {
          setState(() => _pending[key] = value);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final i18n = ContentLocalizations.of(context);
    // Supported regions
    final List<String> supportedRegions = ['jp', 'en', 'kr', 'tw', 'cn'];
    final selectedLocaleCode =
        _pending['app_locale'] ??
        _initial['app_locale'] ??
        supportedLocales.first.code;
    final selectedIntervalDays =
        _pending['db_update_interval_days'] as int? ??
        _initial['db_update_interval_days'] as int? ??
        1;
    final selectedRegionCode =
        _pending['region'] as String? ??
        _initial['region'] as String? ??
        AppGlobals.region;

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        leadingWidth: 100,
        leading: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => Navigator.of(context).pop(),
            ),
            IconButton(
              icon: const Icon(Icons.home),
              onPressed:
                  () =>
                      Navigator.of(context).popUntil((route) => route.isFirst),
            ),
          ],
        ),
        title: Text(l10n.translate('settings_title')),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Region selection
          ExpansionTile(
            title: Text(
              AppGlobals.i18n.translate('common', 'serverRegionSelect').translated,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            initiallyExpanded: _pending.containsKey('region'),
            children:
                supportedRegions.map((region) {
                  return RadioListTile<String>(
                    title: Text(
                      i18n
                          !.translate('common', 'serverRegion', innerKey: region)
                          .translated,
                    ),
                    value: region,
                    groupValue: selectedRegionCode,
                    onChanged: (v) {
                      if (v != null) setState(() => _pending['region'] = v);
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
          ),

          // Locale selection
          ExpansionTile(
            title: Text(
              AppGlobals.i18n.translate('app', 'settings_language').translated,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children:
                supportedLocales.map((supportedLocale) {
                  return RadioListTile<String>(
                    title: Text(supportedLocale.name),
                    value: supportedLocale.code,
                    groupValue: selectedLocaleCode,
                    onChanged: (v) {
                      setState(() => _pending['app_locale'] = v!);
                    },
                    contentPadding: EdgeInsets.zero,
                  );
                }).toList(),
          ),

          // Data management section
          ExpansionTile(
            title: Text(
             AppGlobals.i18n.translate('app', 'settings_data_management').translated,
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              // Add to your settings page
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(
                  '${AppGlobals.i18n.translate('app', 'settings_clear_image_cache').translated} ($_imageCacheSize)',
                ),
                onTap: () async {
                  await clearImageCache();
                  imageCache.clear();
                  imageCache.clearLiveImages();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppGlobals.i18n
                              .translate(
                                'app',
                                'settings_cache_cleared_message',
                              )
                              .translated,
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(
                  '${AppGlobals.i18n.translate('app', 'settings_clear_audio_cache').translated} ($_audioCacheSize)',
                ),
                onTap: () async {
                  await clearAudioCache();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.translate(
                            'settings_audio_cache_cleared_message',
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),

              // Datebase reinitialization
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: Text(AppGlobals.i18n.translate('app', 'settings_reinit_db').translated),
                onTap: () async {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.translate('settings_reinit_db_started_message'),
                        ),
                      ),
                    );
                  }
                  await clearDatabase();
                  if (mounted) {
                    updateDatabase(context);
                  }
                },
              ),

              // Database update
              ListTile(
                leading: const Icon(Icons.update),
                title: Text(l10n.translate('settings_update_db')),
                onTap: () async {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.translate('settings_update_db_started_message'),
                        ),
                      ),
                    );
                    updateDatabase(context);
                  }
                },
              ),

              // Auto‑update interval selector
              ListTile(
                title: Text(l10n.translate('settings_auto_update_interval')),
                trailing: DropdownButton<int>(
                  value: selectedIntervalDays,
                  items:
                      [0, 1, 3, 7, 14].map((d) {
                        String text;
                        if (d == 0) {
                          text = l10n.translate('interval_days_0');
                        } else if (d == 1) {
                          text = l10n.translate('interval_days_1');
                        } else {
                          text = l10n
                              .translate('interval_days_plural')
                              .replaceFirst('%s', '$d');
                        }
                        return DropdownMenuItem(value: d, child: Text(text));
                      }).toList(),
                  onChanged: (v) {
                    setState(() => _pending['db_update_interval_days'] = v!);
                  },
                ),
              ),
            ],
          ), // URL Settings section
          ExpansionTile(
            title: Text(
              l10n.translate('settings_api_title'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              _buildUrlTextField(
                'database_url',
                'https://sekai-world.github.io',
                'URL for database resources',
              ),
              _buildUrlTextField(
                'asset_url',
                'https://storage.sekai.best',
                'URL for image and asset resources',
              ),
              _buildUrlTextField(
                'localization_url',
                'https://i18n-json.sekai.best',
                'URL for localization resources',
              ),
              _buildUrlTextField(
                'api_url',
                'https://api.sekai.best',
                'URL for API endpoints',
              ),
              _buildUrlTextField(
                'news_url',
                AppGlobals.newsUrl,
                'URL for news content',
              ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  l10n.translate('settings_api_note'),
                  style: TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Center(
            child: ElevatedButton(
              onPressed: _pending.isEmpty ? null : _apply,
              child: Text(l10n.translate('button_apply')),
            ),
          ),
        ],
      ),
    );
  }
}
