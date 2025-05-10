import 'dart:convert';
import 'dart:developer' as developer;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class CardDatabase {
  static Future<void> createTables(Database db) async {
    await db.execute('''
            CREATE TABLE IF NOT EXISTS cards(
              id INTEGER PRIMARY KEY,
              seq INTEGER,
              characterId INTEGER,
              cardRarityType TEXT,
              specialTrainingPower1BonusFixed INTEGER DEFAULT 0,
              specialTrainingPower2BonusFixed INTEGER DEFAULT 0,
              specialTrainingPower3BonusFixed INTEGER DEFAULT 0,
              attr TEXT,
              supportUnit TEXT,
              skillId INTEGER,
              cardSkillName TEXT,
              prefix TEXT,
              assetbundleName TEXT,
              gachaPhrase TEXT,
              flavorText TEXT,
              releaseAt INTEGER,
              archivePublishedAt INTEGER,
              cardSupplyId INTEGER,
              cardParameters TEXT,
              specialTrainingCosts TEXT,
              masterLessonAchieveResources TEXT,
              unit TEXT,
              eventId INTEGER,
              specialTrainingSkillId INTEGER,
              specialTrainingSkillName TEXT,
              initialSpecialTrainingStatus TEXT,
              costumes TEXT,
              cardEpisodes TEXT
            )
          ''');
    await db.execute('''
          CREATE TABLE IF NOT EXISTS event_card_relations(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            eventCardId INTEGER,
            cardId INTEGER,
            eventId INTEGER,
            bonusRate REAL,
            isDisplayCardStory INTEGER
          )
        ''');
  }

  static Future<String> processDecodedData(
    Database db,
    cardsList,
    eventCardsList,
    cardCostumesList,
    costumeModelsList,
    cardEpisodesList,
    String newVersionHash,
  ) async {
    try {
      final List<Map<String, Object?>> maxIdResult = await db.rawQuery(
        'SELECT MAX(id) AS maxId FROM cards',
      );
      final int latestCardId =
          maxIdResult.isNotEmpty && maxIdResult.first['maxId'] != null
              ? maxIdResult.first['maxId'] as int
              : 0;

      await db.transaction((txn) async {
        // Insert or Replace Base Card Data
        final Batch batch = txn.batch();
        int processedCount = 0;
        for (final card in cardsList) {
          final int cardId = card['id'] as int? ?? 0;
          if (cardId <= latestCardId) continue;
          batch.insert('cards', {
            'id': cardId,
            'seq': card['seq'],
            'characterId': card['characterId'],
            'cardRarityType': card['cardRarityType'],
            'specialTrainingPower1BonusFixed':
                card['specialTrainingPower1BonusFixed'] ?? 0,
            'specialTrainingPower2BonusFixed':
                card['specialTrainingPower2BonusFixed'] ?? 0,
            'specialTrainingPower3BonusFixed':
                card['specialTrainingPower3BonusFixed'] ?? 0,
            'attr': card['attr'],
            'supportUnit': card['supportUnit'],
            'skillId': card['skillId'],
            'cardSkillName': card['cardSkillName'],
            'prefix': card['prefix'],
            'assetbundleName': card['assetbundleName'],
            'gachaPhrase': card['gachaPhrase'],
            'flavorText': card['flavorText'],
            'releaseAt': card['releaseAt'],
            'archivePublishedAt': card['archivePublishedAt'],
            'cardSupplyId': card['cardSupplyId'],
            'specialTrainingCosts': json.encode(
              card['specialTrainingCosts'] ?? [],
            ),
            'masterLessonAchieveResources': json.encode(
              card['masterLessonAchieveResources'] ?? [],
            ),
            'eventId': -1, // Default value, will be updated later
            'specialTrainingSkillId': card['specialTrainingSkillId'],
            'specialTrainingSkillName': card['specialTrainingSkillName'],
            'initialSpecialTrainingStatus':
                card['initialSpecialTrainingStatus'],
            'costumes': json.encode([]), // Default, updated later
            'unit': 'none', // Default, updated later
          }, conflictAlgorithm: ConflictAlgorithm.replace);
          processedCount++;
          // Commit periodically
          if (processedCount % 500 == 0) {
            await batch.commit(noResult: true);
          }
        }
        await batch.commit(noResult: true);

        // Process Auxiliary Data (Unit, Event, Costumes)
        final unitMap = _processUnitMap(cardsList, latestCardId);
        final eventMap = _processEventMap(eventCardsList, latestCardId);
        final costumesMap = _processCostumesMap(
          cardCostumesList,
          costumeModelsList,
          latestCardId,
        );
        final episodesMap = _processEpisodesMap(cardEpisodesList, latestCardId);

        // batch‐update unit, eventId, and costumes
        final allIdsToUpdate = <int>{
          ...unitMap.keys,
          ...eventMap.keys,
          ...costumesMap.keys,
          ...episodesMap.keys,
        };

        final Batch updateBatch = txn.batch();
        int updateCount = 0;
        for (final id in allIdsToUpdate) {
          if (id <= latestCardId) continue;

          final Map<String, Object?> updates = {};
          if (unitMap.containsKey(id)) updates['unit'] = unitMap[id];
          if (eventMap.containsKey(id)) updates['eventId'] = eventMap[id];
          if (episodesMap.containsKey(id)) {
            updates['cardEpisodes'] = json.encode(episodesMap[id]);
          }
          if (costumesMap.containsKey(id)) {
            updates['costumes'] = json.encode(costumesMap[id]);
          }
          if (updates.isNotEmpty) {
            updateBatch.update(
              'cards',
              updates,
              where: 'id = ?',
              whereArgs: [id],
            );
            updateCount++;
            if (updateCount % 500 == 0) {
              await updateBatch.commit(noResult: true);
            }
          }
        }
        updateBatch.commit(noResult: true);
      });

      // 4. Update the version hash in SharedPreferences upon successful processing
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('cards_version', newVersionHash);
      return ('Cards initialized (version $newVersionHash).');
    } catch (e) {
      return ('Error processing card data: $e');
    }
  }

  /// Processes unit mapping for cards > latestCardId by characterId.
  static Map<int, String> _processUnitMap(
    List<dynamic> cardsList,
    int latestCardId,
  ) {
    // characterId → unit mapping
    const Map<int, String> baseUnitMap = {
      1: 'light_sound',
      2: 'light_sound',
      3: 'light_sound',
      4: 'light_sound',
      5: 'idol',
      6: 'idol',
      7: 'idol',
      8: 'idol',
      9: 'street',
      10: 'street',
      11: 'street',
      12: 'street',
      13: 'theme_park',
      14: 'theme_park',
      15: 'theme_park',
      16: 'theme_park',
      17: 'school_refusal',
      18: 'school_refusal',
      19: 'school_refusal',
      20: 'school_refusal',
      21: 'piapro',
      22: 'piapro',
      23: 'piapro',
      24: 'piapro',
      25: 'piapro',
      26: 'piapro',
    };

    final Map<int, String> unitMap = {};
    for (final card in cardsList) {
      final int id = card['id'] as int? ?? 0;
      final int cid = card['characterId'] as int? ?? 0;

      if (id <= latestCardId) continue;

      if (baseUnitMap.containsKey(cid)) {
        unitMap[id] = baseUnitMap[cid]!;
      }
    }
    return unitMap;
  }

  /// Processes eventId map for cards > latestCardId from the eventCards list.
  static Map<int, int> _processEventMap(
    List<dynamic> eventCardsList,
    int latestCardId,
  ) {
    final Map<int, int> map = {};
    for (final relation in eventCardsList) {
      final int cid = relation['cardId'] as int? ?? 0;

      if (cid <= latestCardId) continue;

      map[cid] =
          relation['eventId'] as int? ??
          -1; // Default to -1 if eventId is missing
    }
    return map;
  }

  /// Processes eventId map for cards > latestCardId from the eventCards list.
  static Map<int, List<Map<String, dynamic>>> _processEpisodesMap(
    List<dynamic> cardEpisodesList,
    int latestCardId,
  ) {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final cardEpisode in cardEpisodesList) {
      final int cid = cardEpisode['cardId'] as int? ?? 0;
      if (cid <= latestCardId) continue;
      map.putIfAbsent(cid, () => []).add(cardEpisode);
    }
    return map;
  }

  /// Processes costumes map for cards > latestCardId using cardCostumes and costumeModels lists.
  static Map<int, List<String>> _processCostumesMap(
    List<dynamic> cardCostumesList,
    List<dynamic> costumeModelsList,
    int latestCardId,
  ) {
    // Build a map from costume3dId to thumbnail assetbundle name
    final Map<int, String> thumbnailMap = {
      for (final model in costumeModelsList)
        if (model['costume3dId'] != null &&
            model['thumbnailAssetbundleName'] != null)
          model['costume3dId'] as int:
              model['thumbnailAssetbundleName'] as String,
    };

    final Map<int, List<String>> costumesMap = {};
    for (final entry in cardCostumesList) {
      final int cid = entry['cardId'] as int? ?? 0;
      if (cid <= latestCardId) continue;

      final int costumeId = entry['costume3dId'] as int? ?? 0;
      final String? thumbnailName = thumbnailMap[costumeId];

      if (thumbnailName != null) {
        costumesMap.putIfAbsent(cid, () => []).add(thumbnailName);
      }
    }
    return costumesMap;
  }

  static Future<Map<String, dynamic>?> getCardById(int id) async {
    Database? db;
    try {
      final String path = join(await getDatabasesPath(), 'pjsk_viewer.db');
      db = await openDatabase(path, readOnly: true);

      // Fetch the card record
      final List<Map<String, dynamic>> results = await db.query(
        'cards',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      if (results.isEmpty) return null;
      final Map<String, dynamic> card = Map.from(results.first);

      // Fetch mappings to get gacha IDs
      final List<Map<String, dynamic>> mappings = await db.query(
        'card_gacha_map',
        columns: ['gachaId'],
        where: 'cardId = ?',
        whereArgs: [id],
      );

      final List<int> gachaIds =
          mappings
              .where((m) => m['gachaId'] != -1)
              .map((m) => m['gachaId'] as int)
              .toList();

      List<Map<String, dynamic>> gachaList = [];
      if (gachaIds.isNotEmpty) {
        final String placeholders = List.filled(gachaIds.length, '?').join(',');
        gachaList = await db.query(
          'gachas',
          columns: ['id', 'name', 'assetbundleName'],
          where: 'id IN ($placeholders)',
          whereArgs: gachaIds,
          orderBy: 'id DESC',
        );
      }
      card['gachas'] = gachaList;

      // Fetch the event ID for this card
      final int eventId = card['eventId'] as int? ?? -1;
      if (eventId != -1) {
        final List<Map<String, dynamic>> eventRows = await db.query(
          'events',
          columns: ['id', 'name', 'assetbundleName'],
          where: 'id = ?',
          whereArgs: [eventId],
          limit: 1,
        );
        card['event'] =
            eventRows.isNotEmpty
                ? Map<String, dynamic>.from(eventRows.first)
                : null;
      } else {
        card['event'] = null;
      }

      // Get gachaType
      final pref = await SharedPreferences.getInstance();
      final String? cardSuppliesJson = pref.getString('cardSupplies');
      if (cardSuppliesJson == null || cardSuppliesJson.isEmpty) {
        return card;
      }
      final List<Map<String, dynamic>> gachaTypes =
          json
              .decode(cardSuppliesJson)
              .cast<Map<String, dynamic>>()
              .toList();

      final Map<int, String> cardSupplyTypeMap = {
        for (var supply in gachaTypes)
          if (supply['id'] != null && supply['cardSupplyType'] != null)
            supply['id'] as int: supply['cardSupplyType'] as String,
      };

      card['gachaType'] = cardSupplyTypeMap[card['cardSupplyId']] ?? '';

      return card;
    } catch (e) {
      developer.log(
        'Error fetching card by ID: $e',
        name: 'CardDatabase.getCardById',
        error: e,
      );
      return null;
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }

  /// Returns the list of all cards
  static Future<List<Map<String, dynamic>>> getCardIndex() async {
    Database? db;
    try {
      final String databaseDirectory = await getDatabasesPath();
      final String databaseFilePath = join(databaseDirectory, 'pjsk_viewer.db');
      db = await openDatabase(databaseFilePath, readOnly: true);

      // Fetch all cards
      final List<Map<String, dynamic>> cards = await db.query(
        'cards',
        orderBy: 'id DESC',
      );

      // Get gachaType mapping
      final pref = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> gachaTypesRaw =
          json
              .decode(pref.getString('cardSupplies') ?? '[]')
              .cast<Map<String, dynamic>>()
              .toList();

      // Build a map from cardSupplyId to cardSupplyType
      final Map<int, String> cardSupplyTypeMap = {
        for (var supply in gachaTypesRaw)
          if (supply['id'] != null && supply['cardSupplyType'] != null)
            supply['id'] as int: supply['cardSupplyType'] as String,
      };

      // build final list, applying gachaType from the map
      final List<Map<String, dynamic>> cardIndex =
          cards.map((cardRow) {
            final int cardSupplyId = cardRow['cardSupplyId'] as int? ?? -1;
            final String type = cardSupplyTypeMap[cardSupplyId] ?? '';
            return {...cardRow, 'gachaType': type};
          }).toList();

      return cardIndex;
    } catch (error) {
      return <Map<String, dynamic>>[];
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }

  /// Returns a map of every card ID to its thumbnail info:
  /// `{ assetbundleName, rarity, attribute }`.
  static Future<Map<int, Map<String, String>>> getRankingInfo() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'pjsk_viewer.db');
    Database? db;
    try {
      db = await openDatabase(path, readOnly: true);
      // fetch id, assetbundleName, rarity and attr
      final rows = await db.query(
        'cards',
        columns: ['id', 'assetbundleName', 'cardRarityType', 'attr'],
      );
      final Map<int, Map<String, String>> info = {};
      for (final row in rows) {
        final id = row['id'] as int;
        info[id] = {
          'assetbundleName': row['assetbundleName'] as String? ?? '',
          'rarity': row['cardRarityType'] as String? ?? '',
          'attribute': row['attr'] as String? ?? '',
        };
      }
      return info;
    } finally {
      if (db != null && db.isOpen) await db.close();
    }
  }
}
