import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import 'card_database.dart';
import 'character_database.dart';
import 'event_database.dart';
import 'gacha_database.dart';
import 'music_database.dart';
import 'my_sekai_database.dart';
import 'resource_boxes_database.dart';

// Helper class to hold fetched data and its hash
class FetchedData {
  final String body;
  final String versionHash;

  FetchedData(this.body, this.versionHash);
}

Future<Map<String, String>> buildFetchUrls() async {
  // This function builds the URLs for fetching data
  final baseUrl = AppGlobals.databaseUrl;

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
    'cardSupplies': "${AppGlobals.jpDatabaseUrl}/cardSupplies.json",
    'cheerfulCarnivalTeams': "$baseUrl/cheerfulCarnivalTeams.json",
    'cheerfulCarnivalSummaries': "$baseUrl/cheerfulCarnivalSummaries.json",
    'worldBlooms': "$baseUrl/worldBlooms.json",
    'eventExchangeSummaries': "$baseUrl/eventExchangeSummaries.json",
    'eventItems': "$baseUrl/eventItems.json",
    'resourceBoxes': "$baseUrl/resourceBoxes.json",
    'mySekaiMaterials': "${AppGlobals.jpDatabaseUrl}/mysekaiMaterials.json",
    'mySekaiFixtures': "${AppGlobals.jpDatabaseUrl}/mysekaiFixtures.json",
    'mysekaiFixtureMainGenres':
        "${AppGlobals.jpDatabaseUrl}/mysekaiFixtureMainGenres.json",
    'mysekaiBlueprints': "${AppGlobals.jpDatabaseUrl}/mysekaiBlueprints.json",
    'mysekaiBlueprintMysekaiMaterialCosts':
        "${AppGlobals.jpDatabaseUrl}/mysekaiBlueprintMysekaiMaterialCosts.json",
    'mysekaiFixtureSubGenres':
        "${AppGlobals.jpDatabaseUrl}/mysekaiFixtureSubGenres.json",
    'mysekaiFixtureTags': "${AppGlobals.jpDatabaseUrl}/mysekaiFixtureTags.json",
    'mysekaiGameCharacterUnitGroups':
        "${AppGlobals.jpDatabaseUrl}/mysekaiGameCharacterUnitGroups.json",
    'mysekaiCharacterTalkConditions':
        "${AppGlobals.jpDatabaseUrl}/mysekaiCharacterTalkConditions.json",
    'mysekaiCharacterTalkConditionGroups':
        "${AppGlobals.jpDatabaseUrl}/mysekaiCharacterTalkConditionGroups.json",
    'mysekaiCharacterTalks':
        "${AppGlobals.jpDatabaseUrl}/mysekaiCharacterTalks.json",
    'musicOriginals': "$baseUrl/musicOriginals.json",
    'eventMusics': "$baseUrl/eventMusics.json",
    'musicAssetVariants': "$baseUrl/musicAssetVariants.json",
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

  // Check if the database needs to be updated
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
      'mysekaiFixtureMainGenres',
      'mysekaiFixtureSubGenres',
      'mysekaiFixtureTags',
      'musicOriginals',
      'eventMusics',
      'musicAssetVariants'
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

    // Check if the fetched data is different from the stored data
    if (storedHash != fetchedData.versionHash) {
      keysToUpdate.add(key);
      newVersionHashes[key] = fetchedData.versionHash;
      decodedJson[key] = compute(_decodeJson, fetchedData.body);
    } else {
      onProgress('$key is up-to-date (version ${fetchedData.versionHash}).');
    }
  }

  // Finish if no updates are needed
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
  final dbPath = await getDatabasesPath();
  final dbFilePath = join(dbPath, 'pjsk_viewer.db');
  // Open the database
  final Database db = await openDatabase(
    dbFilePath,
    version: 1,
    onCreate: (db, version) async {
      await CardDatabase.createTables(db);
      await GachaDatabase.createTables(db);
      await EventDatabase.createTables(db);
      await CharacterDatabase.createTables(db);
      await MusicDatabase.createTables(db);
      await ResourceBoxesDatabase.createTables(db);
      await MySekaiDatabase.createTables(db);
    },
  );
  onProgress('Database opened.');

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
        decodedDataMap['eventExchangeSummaries'],
        decodedDataMap['eventItems'],
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
  if (keysToUpdate.contains('resourceBoxes') &&
      decodedDataMap['resourceBoxes'] != null) {
    processors.add(
      ResourceBoxesDatabase.processDecodedData(
        db,
        decodedDataMap['resourceBoxes'],
        newVersionHashes['resourceBoxes']!,
      ),
    );
  }
  if (keysToUpdate.contains('mySekaiMaterials') &&
      decodedDataMap['mySekaiMaterials'] != null) {
    processors.add(
      MySekaiDatabase.processMaterialsData(
        db,
        decodedDataMap['mySekaiMaterials'],
        newVersionHashes['mySekaiMaterials']!,
      ),
    );
  }
  if (keysToUpdate.contains('mySekaiFixtures') &&
      decodedDataMap['mySekaiFixtures'] != null) {
    processors.add(
      MySekaiDatabase.processFixturesData(
        db,
        decodedDataMap['mySekaiFixtures'],
        decodedDataMap['mysekaiBlueprints'],
        decodedDataMap['mysekaiBlueprintMysekaiMaterialCosts'],
        decodedDataMap['mysekaiCharacterTalkConditions'],
        decodedDataMap['mysekaiCharacterTalkConditionGroups'],
        decodedDataMap['mysekaiCharacterTalks'],
        decodedDataMap['mysekaiGameCharacterUnitGroups'],
        newVersionHashes['mySekaiFixtures']!,
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
  // update the data version
  try {
    final databaseLink = AppGlobals.databaseUrl;
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
    await prefs.setString(key, fetchedDataMap[key]?.body ?? '');
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
  } finally {
    await Future.delayed(Duration(seconds: 1));
    // Close the dialog
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
  }
}

/// Clears the database by removing the DB file and resetting all version tracking
Future<void> clearDatabase() async {
  try {
    // Delete the database file
    final dbPath = await getDatabasesPath();
    final dbFilePath = join(dbPath, 'pjsk_viewer.db');
    bool dbExists = await databaseExists(dbFilePath);
    if (dbExists) {
      await deleteDatabase(dbFilePath);
    }

    // Clear all version hashes and data from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final fetchUrls = await buildFetchUrls();
    final List<String> keys = fetchUrls.keys.toList();

    for (final key in keys) {
      await prefs.remove('${key}_version');
      await prefs.remove(key);
    }

    // Clear data version
    await prefs.remove('data_version');
  } catch (_) {}
}
