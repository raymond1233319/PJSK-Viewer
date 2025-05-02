import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_phoenix/flutter_phoenix.dart' show Phoenix;
import 'package:sqflite/sqflite.dart';
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

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _initial['app_locale'] = prefs.getString('app_locale') ?? 'en';
      _initial['db_update_interval_days'] =
          prefs.getInt('db_update_interval_days') ?? 7;
    });
  }

  Future<void> _apply() async {
    if (_pending.isEmpty) {
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    bool needsRestart = false;
    AppLocalizations? l10n;
    if (mounted) {
      l10n = AppLocalizations.of(context);
    }

    for (var entry in _pending.entries) {
      final key = entry.key;
      final value = entry.value;
      if (value is String) {
        await prefs.setString(key, value);
        if (key == 'app_locale') needsRestart = true;
      } else if (value is bool) {
        await prefs.setBool(key, value);
      } else if (value is int) {
        await prefs.setInt(key, value);
      }
    }

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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final selectedCode =
        _pending['app_locale'] ??
        _initial['app_locale'] ??
        supportedLocales.first.code;
    final selectedIntervalDays =
        _pending['db_update_interval_days'] as int? ??
        _initial['db_update_interval_days'] as int? ??
        1;
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
          // Locale selection
          ExpansionTile(
            title: Text(
              l10n.translate('settings_language'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children:
                supportedLocales.map((supportedLocale) {
                  return RadioListTile<String>(
                    title: Text(
                      supportedLocale.name,
                    ), // Assuming Locale name is already localized or standard
                    value: supportedLocale.code,
                    groupValue: selectedCode,
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
              l10n.translate('settings_data_management'),
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            children: [
              ListTile(
                leading: const Icon(Icons.delete),
                title: Text(l10n.translate('settings_clear_image_cache')),
                onTap: () async {
                  // clear cached_network_image files
                  await DefaultCacheManager().emptyCache();
                  // evict any in‐memory instances
                  imageCache.clear();
                  imageCache.clearLiveImages();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.translate('settings_cache_cleared_message'),
                        ),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.restart_alt),
                title: Text(l10n.translate('settings_reinit_db')),
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
                  final path = p.join(
                    await getDatabasesPath(),
                    'pjsk_viewer.db',
                  );
                  await deleteDatabase(path);
                  if (mounted) {
                    updateDatabase(context);
                  }
                },
              ),
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
