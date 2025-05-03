import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalizedText {
  final String japaneseText;
  final String translatedText;

  const LocalizedText({
    required this.japaneseText,
    required this.translatedText,
  });

  // toString returns the translated version if available
  @override
  String toString() =>
      translatedText.isNotEmpty ? translatedText : japaneseText;

  // Format as "japanese | translated" or just one if the other is empty
  String get combined =>
      japaneseText.isNotEmpty &&
              translatedText.isNotEmpty &&
              japaneseText.toString() != translatedText.toString()
          ? "$translatedText | $japaneseText"
          : toString();

  String get japanese =>
      japaneseText.isNotEmpty ? japaneseText : translatedText;
  String get translated =>
      translatedText.isNotEmpty ? translatedText : japaneseText;
}

/// Represents a JSON resource to be loaded
class JsonResource {
  final String url;
  final String cacheKey;
  final bool
  isStringMap; // Indicates if the result should be Map<String, String>

  JsonResource({
    required this.url,
    required this.cacheKey,
    this.isStringMap = false,
  });
}

class ContentLocalizations {
  final Locale locale;

  // Data storage for different resource types
  final Map<String, Map<String, String>> _stringMaps = {};
  final Map<String, Map<String, dynamic>> _dynamicMaps = {};

  ContentLocalizations(this.locale);

  // Static accessor
  static ContentLocalizations? of(BuildContext context) {
    return Localizations.of<ContentLocalizations>(
      context,
      ContentLocalizations,
    );
  }

  // Load the localization data
  Future<bool> load() async {
    final String languageCode =
        (locale.countryCode != '')
            ? '${locale.languageCode}-${locale.countryCode}'
            : locale.languageCode;
    final String baseUrl = 'https://i18n-json.sekai.best';

    final resourcesMeta = <Map<String, Object>>[
      {'key': 'event_name', 'string': true}, // Event names
      {'key': 'event', 'string': false}, // Event details
      {'key': 'common', 'string': false}, // Common name
      {'key': 'card_prefix', 'string': true}, // Card Prefix
      {'key': 'character_name', 'string': false}, // Character names
      {'key': 'stamp_name', 'string': true}, // Stamp names
      {
        'key': 'cheerful_carnival_teams',
        'string': true,
      }, // Cheerful Carnival teams
      {'key': 'gacha_name', 'string': true}, // Gacha names
      {'key': 'card_skill_name', 'string': true}, // Card skill names
      {'key': 'music_titles', 'string': true}, // Music titles
      {
        'key': 'unit_story_chapter_title',
        'string': true,
      }, // Unit story chapter titles
      {'key': 'music_vocal', 'string': true}, // Music vocals
      {'key': 'card_episode_title', 'string': true}, // Card episode titles
      {'key': 'release_cond', 'string': true}, // Release conditions
      {'key': 'comic_title', 'string': true}, // Comic titles
      {'key': 'unit_profile', 'string': false}, // Unit profiles
      {'key': 'character_profile', 'string': false}, // Character profiles
      {'key': 'skill_desc', 'string': true}, // Skill descriptions
      {
        'key': 'event_story_episode_title',
        'string': true,
      }, // Event story episode titles
      {
        'key': 'unit_story_episode_title',
        'string': true,
      }, // Unit story episode titles
      {'key': 'virtualLive_name', 'string': true}, // Virtual Live names
      {'key': 'honorGroup_name', 'string': true}, // Honor Group names
      {'key': 'honor_name', 'string': true}, // Honor names
      {'key': 'beginner_mission', 'string': true}, // Beginner missions
      {'key': 'normal_mission', 'string': true}, // Normal missions
      {'key': 'honor_mission', 'string': true}, // Honor missions
      {'key': 'area_subname', 'string': true}, // Area subnames
      {'key': 'area_name', 'string': true}, // Area names
      {
        'key': 'cheerful_carnival_themes',
        'string': true,
      }, // Cheerful Carnival themes
      {'key': 'card_gacha_phrase', 'string': true}, // Card gacha phrases
      {'key': 'character_mission', 'string': true}, // Character missions
      {'key': 'card', 'string': false}, // Card Detail
      {'key': 'gacha', 'string': false}, // Gacha Detail
      {'key': 'home', 'string': false}, //home
      {'key': 'music', 'string': false}, //music
      {'key': 'filter', 'string': false}, //home
    ];
    // Always load Japanese first, then the current locale if different
    final codes = <String>['ja'];
    if (languageCode != 'ja') codes.add(languageCode);
    // Build JsonResource list
    final resources = <JsonResource>[];
    for (final code in codes) {
      for (final meta in resourcesMeta) {
        final key = meta['key'] as String;
        final isStringMap = meta['string'] as bool;
        resources.add(
          JsonResource(
            url: '$baseUrl/$code/$key.json',
            cacheKey: '${key}_$code',
            isStringMap: isStringMap,
          ),
        );
      }
    }

    // Load all resources
    final results = await _loadAllResources(resources);

    // Process results
    for (int i = 0; i < resources.length; i++) {
      final resource = resources[i];
      final data = results[i];

      if (data != null) {
        if (resource.isStringMap) {
          // Convert to Map<String, String> and store
          _stringMaps[resource.cacheKey] = _convertToStringMap(data);
        } else {
          _dynamicMaps[resource.cacheKey] = data;
        }
      }
    }

    return true;
  }

  // Load all resources concurrently
  Future<List<dynamic>> _loadAllResources(List<JsonResource> resources) async {
    return await Future.wait(
      resources.map(
        (resource) => _fetchJsonData(resource.url, resource.cacheKey),
      ),
    );
  }

  // Helper to convert dynamic map to string map
  Map<String, String> _convertToStringMap(dynamic data) {
    if (data is Map<String, dynamic>) {
      return data.map((key, value) => MapEntry(key, value.toString()));
    }
    return {};
  }

  // Generic helper method to fetch and decode JSON from a URL, with caching
  Future<dynamic> _fetchJsonData(String url, String cacheKey) async {
    // Use a cache key based on locale and the provided key
    final fullCacheKey = 'json_cache_${locale.languageCode}_$cacheKey';
    SharedPreferences? prefs;

    try {
      prefs = await SharedPreferences.getInstance();

      // fetch from network
      final response = await http
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        // Cache the successful response string
        await prefs.setString(fullCacheKey, response.body);
        return json.decode(response.body);
      } else {
        developer.log(
          'Failed to load $cacheKey from $url: Status ${response.statusCode}',
        );
        return _loadFromCache(prefs, fullCacheKey, cacheKey, url);
      }
    } catch (e) {
      developer.log('Error fetching $cacheKey from $url: $e');
      // Try loading from cache on exception
      prefs ??= await SharedPreferences.getInstance();
      return _loadFromCache(prefs, fullCacheKey, cacheKey, url);
    }
  }

  // Helper to load data from cache
  dynamic _loadFromCache(
    SharedPreferences prefs,
    String fullCacheKey,
    String cacheKey,
    String url,
  ) {
    final cachedData = prefs.getString(fullCacheKey);
    if (cachedData != null) {
      return json.decode(cachedData);
    } else {
      return null;
    }
  }

  /// Returns a [LocalizedText] for a given [resourceKey] and [valueKey].
  /// If [innerKey] is provided, looks up nested entries in dynamic maps.
  LocalizedText translate(
    String resourceKey,
    String valueKey, {
    String? innerKey,
  }) {
    dynamic flatten(dynamic d) {
      while (d is Map<String, dynamic> && d.length == 1) {
        final only = d.values.first;
        if (only is Map<String, dynamic>) {
          d = only;
          continue;
        }
        break;
      }
      return d;
    }

    // build keys for Japanese and current locale
    final langCode =
        locale.countryCode?.isNotEmpty == true
            ? '${locale.languageCode}-${locale.countryCode}'
            : locale.languageCode;
    final japaneseMapKey = '${resourceKey}_ja';
    final tranlatedMapKey = '${resourceKey}_$langCode';
    // fetch flat string maps
    String japanese = '', translated = '';

    // if nested lookup requested
    if (innerKey != null) {
      // fully flatten nested single‐entry maps
      dynamic japaneseMap = flatten(_dynamicMaps[japaneseMapKey]?[valueKey]);
      if (japaneseMap is Map<String, dynamic> &&
          japaneseMap.containsKey(innerKey)) {
        japanese = japaneseMap[innerKey].toString();
      }
      // fully flatten nested single‐entry maps
      dynamic tranlatedMap = flatten(_dynamicMaps[tranlatedMapKey]?[valueKey]);
      if (tranlatedMap is Map<String, dynamic> &&
          tranlatedMap.containsKey(innerKey)) {
        translated = tranlatedMap[innerKey].toString();
      }
    } else {
      // Check if the resourceKey exists in the string maps
      if (_stringMaps.containsKey(japaneseMapKey)) {
        if (_stringMaps[japaneseMapKey]?[valueKey] != null) {
          japanese = _stringMaps[japaneseMapKey]?[valueKey] ?? '';
          translated = _stringMaps[tranlatedMapKey]?[valueKey] ?? '';
        }
      } else {
        if (_dynamicMaps[japaneseMapKey]?[valueKey] != null) {
          japanese = _dynamicMaps[japaneseMapKey]?[valueKey].toString() ?? '';
          translated =
              _dynamicMaps[tranlatedMapKey]?[valueKey].toString() ?? '';
        }
      }
    }
    return LocalizedText(japaneseText: japanese, translatedText: translated);
  }
}

class ContentLocalizationsDelegate
    extends LocalizationsDelegate<ContentLocalizations> {
  const ContentLocalizationsDelegate();

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
  Future<ContentLocalizations> load(Locale locale) async {
    ContentLocalizations localizations = ContentLocalizations(locale);
    await localizations.load();
    return localizations;
  }

  @override
  bool shouldReload(ContentLocalizationsDelegate old) => false;
}
