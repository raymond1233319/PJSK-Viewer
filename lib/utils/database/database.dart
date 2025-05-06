import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'card_database.dart';
import 'character_database.dart';
import 'event_database.dart';
import 'gacha_database.dart';
import 'music_database.dart';

// Helper class to hold fetched data and its hash
class FetchedData {
  final String body;
  final String versionHash;

  FetchedData(this.body, this.versionHash);
}

Future<String> get getDatabaseUrl async {
  final prefs = await SharedPreferences.getInstance();
  final storedBase =
      prefs.getString('db_base_url') ?? 'https://sekai-world.github.io/';
  final version = prefs.getString('database_version') ?? 'sekai-master-db-diff';

  return version.isNotEmpty ? "$storedBase/$version" : storedBase;
}

Future<Map<String, String>> buildFetchUrls() async {
  final baseUrl = await getDatabaseUrl;
  return {
    'cards': "$baseUrl/cards.json",
    'gachas': "$baseUrl/gachas.json",
    'events': "$baseUrl/events.json",
    'characters': "$baseUrl/gameCharacters.json",
    'music': "$baseUrl/musics.json",
    'eventDeckBonuses': "$baseUrl/eventDeckBonuses.json",
    'gachaCeilItems': "$baseUrl/gachaCeilItems.json",
    'eventCards': "$baseUrl/eventCards.json",
    'cardCostumes': "$baseUrl/cardCostume3ds.json",
    'costumeModels': "$baseUrl/costume3dModels.json",
    'musicTags': "$baseUrl/musicTags.json",
    'musicVocals': "$baseUrl/musicVocals.json",
    'musicDifficulties': "$baseUrl/musicDifficulties.json",
    'skills': "$baseUrl/skills.json",
    'outsideCharacters': "$baseUrl/outsideCharacters.json",
    'cardEpisodes': "$baseUrl/cardEpisodes.json",
    'eventStories': "$baseUrl/eventStories.json",
    'another3dmvCutIns': "$baseUrl/another3dmvCutIns.json",
    'cardSupplies': "$baseUrl/cardSupplies.json",
    'cheerfulCarnivalTeams': "$baseUrl/cheerfulCarnivalTeams.json",
    'cheerfulCarnivalSummaries': "$baseUrl/cheerfulCarnivalSummaries.json",
    'worldBlooms': "$baseUrl/worldBlooms.json",
  };
}

// Helper function to perform a single fetch operation
Future<FetchedData?> _fetchJsonData(String url) async {
  try {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final body = response.body;
      final versionHash = md5.convert(utf8.encode(body)).toString();
      return FetchedData(body, versionHash);
    } else {
      return null;
    }
  } catch (e) {
    return null;
  }
}

// Helper function to decode JSON in a separate isolate (compute)
dynamic _decodeJson(String jsonString) {
  // This function runs in a separate isolate
  try {
    return json.decode(jsonString);
  } catch (e) {
    // Return null or a specific error indicator if decoding fails
    return null;
  }
}

Future<void> databaseInitialization(void Function(String) onProgress) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  bool needsUpdate = true;
  final lastUpdateMs = prefs.getInt('db_update_time') ?? 0;
  final intervalDays = prefs.getInt('db_update_interval_days') ?? 1;
  if (lastUpdateMs > 0 && intervalDays > 0) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final cutoff = Duration(days: intervalDays).inMilliseconds;
    if (nowMs - lastUpdateMs < cutoff) {
      needsUpdate = false; // No update needed based on time interval
    }
  }

  if (!needsUpdate) {
    // Check if database file exists, if not, force update
    final dbPath = await getDatabasesPath();
    final dbFilePath = join(dbPath, 'pjsk_viewer.db');
    bool dbExists = await databaseExists(dbFilePath);
    if (!dbExists) {
      onProgress('Database file not found, forcing update.');
    } else {
      return; // Skip if update interval not met and DB exists
    }
  }

  onProgress('Starting database initialization...');

  // --- Parallel Data Fetching Phase ---
  final fetchUrls = await buildFetchUrls();
  final List<Future<FetchedData?>> dataFetchFutures =
      fetchUrls.values.map(_fetchJsonData).toList();
  final Map<String, FetchedData?> fetchedDataMap = Map.fromIterables(
    fetchUrls.keys,
    await Future.wait(dataFetchFutures),
  );

  // Save fetched data to SharedPreferences
  saveFetchUrlsToPrefs(
    fetchedDataMap: fetchedDataMap,
    keys: [
      'skills',
      'outsideCharacters',
      'cardSupplies',
      'cheerfulCarnivalTeams',
      'cheerfulCarnivalSummaries',
      'worldBlooms',
    ],
  );

  onProgress('Data fetching complete.');

  final Map<String, Future<dynamic>> decodedJson = {};
  final Set<String> keysToUpdate = {};
  final Map<String, String> newVersionHashes = {};

  for (final key in fetchUrls.keys) {
    final fetchedData = fetchedDataMap[key];
    if (fetchedData == null) {
      onProgress('Fetch failed for $key.');
      continue;
    }

    final String versionKey = '${key}_version'; // e.g., cards_version
    final String? storedHash = prefs.getString(versionKey);

    if (storedHash != fetchedData.versionHash) {
      keysToUpdate.add(key);
      newVersionHashes[key] = fetchedData.versionHash;
      decodedJson[key] = compute(_decodeJson, fetchedData.body);
    } else {
      onProgress('$key is up-to-date (version ${fetchedData.versionHash}).');
    }
  }

  if (decodedJson.isEmpty) {
    // Set update time
    await prefs.setInt('db_update_time', DateTime.now().millisecondsSinceEpoch);
    onProgress('Database initialization finished.');
    return;
  }

  // Wait for all necessary decodes to complete
  final Map<String, dynamic> decodedDataMap = {};
  final decodeResults = await Future.wait(decodedJson.values);

  int i = 0;
  for (final key in decodedJson.keys) {
    if (decodeResults[i] == null) {
      onProgress('Decoding failed for $key.');
      i++;
      continue;
    }
    decodedDataMap[key] = decodeResults[i];
    i++;
  }

  onProgress('Decoding complete.');

  // --- Database Processing Phase ---
  onProgress('Opening database...');
  final dbPath = await getDatabasesPath();
  final dbFilePath = join(dbPath, 'pjsk_viewer.db');
  final Database db = await openDatabase(
    dbFilePath,
    version: 1,
    onCreate: (db, version) async {
      await CardDatabase.createTables(db);
      await GachaDatabase.createTables(db);
      await EventDatabase.createTables(db);
      await CharacterDatabase.createTables(db);
      await MusicDatabase.createTables(db);
      onProgress('Database tables created.');
    },
  );
  final processors = <Future<String>>[];

  // Add processors conditionally based on keysToUpdate and successful decode
  if (keysToUpdate.contains('cards') && decodedDataMap['cards'] != null) {
    processors.add(
      CardDatabase.processDecodedData(
        db,
        decodedDataMap['cards'],
        decodedDataMap['eventCards'],
        decodedDataMap['cardCostumes'],
        decodedDataMap['costumeModels'],
        decodedDataMap['cardEpisodes'],
        newVersionHashes['cards']!,
      ),
    );
  }
  if (keysToUpdate.contains('gachas') && decodedDataMap['gachas'] != null) {
    processors.add(
      GachaDatabase.processDecodedData(
        db,
        decodedDataMap['gachas'],
        decodedDataMap['cards'],
        decodedDataMap['gachaCeilItems'],
        decodedDataMap['another3dmvCutIns'],
        newVersionHashes['gachas']!,
      ),
    );
  }
  if (keysToUpdate.contains('events') && decodedDataMap['events'] != null) {
    processors.add(
      EventDatabase.processDecodedData(
        db,
        decodedDataMap['events'],
        decodedDataMap['eventDeckBonuses'],
        decodedDataMap['eventStories'],
        newVersionHashes['events']!,
      ),
    );
  }
  if (keysToUpdate.contains('characters') &&
      decodedDataMap['characters'] != null) {
    processors.add(
      CharacterDatabase.processDecodedData(
        db,
        decodedDataMap['characters'],
        newVersionHashes['characters']!,
      ),
    );
  }
  if (keysToUpdate.contains('music') && decodedDataMap['music'] != null) {
    processors.add(
      MusicDatabase.processDecodedData(
        db,
        decodedDataMap['music'],
        decodedDataMap['musicTags'],
        decodedDataMap['musicVocals'],
        decodedDataMap['musicDifficulties'],
        newVersionHashes['music']!,
      ),
    );
  }

  // fetch each table, report the returned String
  if (processors.isNotEmpty) {
    final processingResults = await Future.wait(processors);
    processingResults.forEach(onProgress); // Log results from each processor
    onProgress('Data processing complete.');
  }

  await db.close();
  // update the last update time
  await prefs.setInt('db_update_time', DateTime.now().millisecondsSinceEpoch);
  // update the asset version
  try {
    final databaseLink = await getDatabaseUrl;
    final respone = await http.get(Uri.parse('$databaseLink/versions.json'));
    if (respone.statusCode == 200) {
      final jsonMap = json.decode(respone.body) as Map<String, dynamic>;
      final dataVersion = jsonMap['dataVersion']?.toString() ?? '';
      await prefs.setString('data_version', dataVersion);
    }
  } catch (_) {}

  onProgress('Database initialization finished.');
}

/// Saves entries from [fetchUrls] into SharedPreferences.
/// If [keys] is omitted, all entries are saved;
/// otherwise only the specified keys.
Future<void> saveFetchUrlsToPrefs({
  required Map<String, FetchedData?> fetchedDataMap,
  List<String>? keys,
}) async {
  final fetchUrls = await buildFetchUrls();
  final prefs = await SharedPreferences.getInstance();
  final toSave = (keys ?? fetchUrls.keys).where(
    (k) => fetchUrls.containsKey(k),
  );
  for (final key in toSave) {
    if (fetchedDataMap[key] != null) {
      await prefs.setString(key, fetchedDataMap[key]!.body);
    }
  }
}

Future<void> updateDatabase(context) async {
  final List<String> logs = [];
  void Function(void Function())? setDialogState;

  // Show a modal dialog that will display log messages
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setState) {
          setDialogState = setState;
          return AlertDialog(
            title: const Text('Updating Database'),
            content: SizedBox(
              width: double.maxFinite,
              height: 500,
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder:
                    (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(logs[i]),
                    ),
              ),
            ),
          );
        },
      );
    },
  );
  try {
    final prefs = await SharedPreferences.getInstance();
    final fetchUrls = await buildFetchUrls();
    final List<String> names = fetchUrls.keys.toList();
    for (var name in names) {
      await prefs.remove("${name}_version");
    }
    await prefs.setInt('db_update_time', 0);

    await databaseInitialization((message) {
      logs.add(message);
      if (setDialogState != null) {
        setDialogState!(() {});
      }
    });
  } catch (e) {
    logs.add("Error during database update: $e");
    if (setDialogState != null) {
      setDialogState!(() {});
    }
    await Future.delayed(Duration(seconds: 5));
  } finally {
    await Future.delayed(Duration(seconds: 1));
    // Close the dialog
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}
