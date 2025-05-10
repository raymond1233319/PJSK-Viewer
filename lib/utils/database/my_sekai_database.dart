import 'dart:convert';
import 'dart:developer' as developer;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class MySekaiDatabase {
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mysekai_fixtures(
        id INTEGER PRIMARY KEY,
        mysekaiFixtureType TEXT,
        name TEXT,
        pronunciation TEXT,
        flavorText TEXT,
        seq INTEGER,
        gridSize TEXT,
        mysekaiFixtureMainGenreId INTEGER,
        mysekaiFixtureSubGenreId INTEGER,
        mysekaiFixtureHandleType TEXT,
        mysekaiSettableSiteType TEXT,
        mysekaiSettableLayoutType TEXT,
        mysekaiFixturePutType TEXT,
        mysekaiFixtureAnotherColors TEXT,
        mysekaiFixturePutSoundId INTEGER,
        mysekaiFixtureTagGroup TEXT,
        isAssembled INTEGER,
        isDisassembled INTEGER,
        mysekaiFixturePlayerActionType TEXT,
        isGameCharacterAction INTEGER,
        assetbundleName TEXT,
        bluprintId INTEGER,
        mysekaiCraftType TEXT,
        isEnableSketch INTEGER,
        isObtainedByConvert INTEGER,
        materialCost TEXT,
        tags TEXT,
        talks TEXT,
        characters TEXT
      )
    ''');
    await db.execute('''
    CREATE TABLE IF NOT EXISTS mysekai_materials(
      id INTEGER PRIMARY KEY,
      seq INTEGER,
      mysekaiMaterialType TEXT,
      name TEXT,
      pronunciation TEXT,
      description TEXT,
      mysekaiMaterialRarityType TEXT,
      iconAssetbundleName TEXT,
      mysekaiSiteIds TEXT
    )
  ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS mysekai_fixture_tags(
        id INTEGER PRIMARY KEY,
        name  TEXT,
        pronunciation TEXT,
        mysekaiFixtureTagType TEXT,
        externalId INTEGER
      )
    ''');
  }

  /// Insert or update a batch of fixtures.
  /// Returns a status message.
  static Future<String> processFixturesData(
    Database db,
    List<dynamic> fixtureList,
    List<dynamic> blueprintList,
    List<dynamic> materialCostList,
    List<dynamic> talkConditionList,
    List<dynamic> talkConditionGroupList,
    List<dynamic> talkList,
    List<dynamic> characterGroupList,
    String newVersionHash,
  ) async {
    try {
      await db.transaction((txn) async {
        var batch = txn.batch();
        int count = 0;
        for (var raw in fixtureList) {
          if (raw is Map<String, dynamic>) {
            batch.insert('mysekai_fixtures', {
              'id': raw['id'] as int? ?? 0,
              'mysekaiFixtureType': raw['mysekaiFixtureType'] ?? '',
              'name': raw['name'] ?? '',
              'pronunciation': raw['pronunciation'] ?? '',
              'flavorText': raw['flavorText'] ?? '',
              'seq': raw['seq'] as int? ?? 0,
              'gridSize': json.encode(raw['gridSize'] ?? {}),
              'mysekaiFixtureMainGenreId':
                  raw['mysekaiFixtureMainGenreId'] as int? ?? 0,
              'mysekaiFixtureSubGenreId':
                  raw['mysekaiFixtureSubGenreId'] as int? ?? 0,
              'mysekaiFixtureHandleType': raw['mysekaiFixtureHandleType'] ?? '',
              'mysekaiSettableSiteType': raw['mysekaiSettableSiteType'] ?? '',
              'mysekaiSettableLayoutType':
                  raw['mysekaiSettableLayoutType'] ?? '',
              'mysekaiFixturePutType': raw['mysekaiFixturePutType'] ?? '',
              'mysekaiFixtureAnotherColors': json.encode(
                raw['mysekaiFixtureAnotherColors'] ?? [],
              ),
              'mysekaiFixturePutSoundId':
                  raw['mysekaiFixturePutSoundId'] as int? ?? 0,
              'mysekaiFixtureTagGroup': json.encode(
                raw['mysekaiFixtureTagGroup'] ?? {},
              ),
              'isAssembled': (raw['isAssembled'] == true) ? 1 : 0,
              'isDisassembled': (raw['isDisassembled'] == true) ? 1 : 0,
              'mysekaiFixturePlayerActionType':
                  raw['mysekaiFixturePlayerActionType'] ?? '',
              'isGameCharacterAction':
                  (raw['isGameCharacterAction'] == true) ? 1 : 0,
              'assetbundleName': raw['assetbundleName'] ?? '',
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            if (++count % 500 == 0) {
              await batch.commit(noResult: true);
            }
          }
        }
      });

      await Future.wait([
        processBluePrint(db, blueprintList, materialCostList),
        processCharacterTalk(
          db,
          talkConditionList,
          talkConditionGroupList,
          talkList,
          characterGroupList,
        ),
      ]);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_sekai_fixtures_version', newVersionHash);
      return 'MySekai fixtures processed.)';
    } catch (e) {
      return 'Error processing MySekai fixtures: $e';
    }
  }

  static Future<void> batchUpdate({
    required Database db,
    required List<dynamic> items,
    required String column,
    required String tableToUpdate,
    String key = 'id',
    String value = 'id',
  }) async {
    // Group items by key
    final Map<int, List<Map<String, dynamic>>> groupedItems = {};
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        final int id = item[key] as int? ?? 0;
        groupedItems.putIfAbsent(id, () => []).add(item);
      }
    }

    if (groupedItems.isEmpty) {
      return;
    }

    await db.transaction((txn) async {
      Batch batch = txn.batch();

      for (final entry in groupedItems.entries) {
        final int id = entry.key;
        final List<Map<String, dynamic>> items = entry.value;

        if (items.isEmpty) continue;

        batch.update(
          tableToUpdate,
          {column: json.encode(items)},
          where: '$value = ?',
          whereArgs: [id],
        );
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<void> processCharacterTalk(
    Database db,
    List<dynamic> talkConditionList,
    List<dynamic> talkConditionGroupList,
    List<dynamic> talkList,
    List<dynamic> characterGroupList,
  ) async {
    final Map<int, List<int>> conditionToGroupIdsMap = {};

    // Map mysekaiCharacterTalkConditionId to a list of groupIds
    for (var groupEntry in talkConditionGroupList) {
      final int conditionId = groupEntry['mysekaiCharacterTalkConditionId'];
      final int groupId = groupEntry['groupId'];
      conditionToGroupIdsMap.putIfAbsent(conditionId, () => []).add(groupId);
    }

    // Map groupId to a list of talk objects
    final Map<int, List<Map<String, dynamic>>> talksByGroupIdMap = {};
    for (var talk in talkList) {
      final int talkGroupId = talk['mysekaiCharacterTalkConditionGroupId'];
      talksByGroupIdMap.putIfAbsent(talkGroupId, () => []).add(talk);
    }

    // Map characterGroup.id to a list of character IDs
    final Map<int, List<int>> characterGroupIdToCharacterIdsMap = {};
    for (var charGroup in characterGroupList) {
      final int charGroupId = charGroup['id'];
      final List<int> charIdsInGroup = [];
      // Iterate over entries, skip 'id' key, and collect other integer values
      for (final entry in charGroup.entries) {
        if (entry.key == 'id') {
          continue;
        }
        charIdsInGroup.add(entry.value as int);
      }
      if (charIdsInGroup.isNotEmpty) {
        characterGroupIdToCharacterIdsMap[charGroupId] = charIdsInGroup;
      }
    }

    // Map fixtureId to jsonEncodedTalks
    final Map<int, String> fixtureToTalksJsonMap = {};
    final Map<int, String> fixtureToCharacterIdsJsonMap = {};

    for (var talkCondition in talkConditionList) {
      if (talkCondition["mysekaiCharacterTalkConditionType"] !=
          "mysekai_fixture_id") {
        continue;
      }
      final int fixtureId =
          talkCondition['mysekaiCharacterTalkConditionTypeValue'];
      final int talkConditionId = talkCondition['id'];

      final List<int>? associatedGroupIds =
          conditionToGroupIdsMap[talkConditionId];
      if (associatedGroupIds != null && associatedGroupIds.isNotEmpty) {
        final List<Map<String, dynamic>> talks = [];
        for (int groupId in associatedGroupIds) {
          if (talksByGroupIdMap.containsKey(groupId)) {
            talks.addAll(talksByGroupIdMap[groupId]!);
          }
        }
        if (talks.isNotEmpty) {
          fixtureToTalksJsonMap[fixtureId] = json.encode(talks);
          List<int> characterIds = [];
          for (var talk in talks) {
            final int gameCharUnitGroupId =
                talk['mysekaiGameCharacterUnitGroupId'];
            if (characterGroupIdToCharacterIdsMap.containsKey(
              gameCharUnitGroupId,
            )) {
              characterIds.addAll(
                characterGroupIdToCharacterIdsMap[gameCharUnitGroupId]!,
              );
            }
          }
          if (characterIds.isNotEmpty) {
            fixtureToCharacterIdsJsonMap[fixtureId] = json.encode(
              characterIds.toSet().toList(),
            );
          }
        }
      }
    }

    // update the mysekai_fixtures table
    if (fixtureToTalksJsonMap.isNotEmpty ||
        fixtureToCharacterIdsJsonMap.isNotEmpty) {
      await db.transaction((txn) async {
        var batch = txn.batch();
        int count = 0;
        fixtureToTalksJsonMap.forEach((fixtureId, talksJson) {
          batch.update(
            'mysekai_fixtures',
            {'talks': talksJson},
            where: 'id = ?',
            whereArgs: [fixtureId],
          );
          if (++count % 500 == 0) {
            batch.commit(noResult: true);
          }
        });
        fixtureToCharacterIdsJsonMap.forEach((fixtureId, characterIdsJson) {
          batch.update(
            'mysekai_fixtures',
            {'characters': characterIdsJson},
            where: 'id = ?',
            whereArgs: [fixtureId],
          );
          if (++count % 500 == 0) {
            batch.commit(noResult: true);
          }
        });
        if (count % 500 != 0) {
          await batch.commit(noResult: true);
        }
      });
    }
  }

  static Future<void> processBluePrint(
    Database db,
    List<dynamic> blueprintList,
    List<dynamic> materialCostList,
  ) async {
    await db.transaction((txn) async {
      var batch = txn.batch();
      int count = 0;
      for (var blueprint in blueprintList) {
        if (blueprint["mysekaiCraftType"] != "mysekai_fixture") continue;
        batch.update(
          'mysekai_fixtures',
          {
            'bluprintId': blueprint['id'] as int? ?? 0,
            'mysekaiCraftType': blueprint['mysekaiCraftType'] ?? '',
            'isEnableSketch': blueprint['isEnableSketch'] ? 1 : 0,
            'isObtainedByConvert': blueprint['isObtainedByConvert'] ? 1 : 0,
          },
          where: 'id = ?',
          whereArgs: [blueprint['craftTargetId']],
        );
        if (++count % 500 == 0) {
          await batch.commit(noResult: true);
        }
      }
      if (count % 500 != 0) {
        await batch.commit(noResult: true);
      }
    });
    await batchUpdate(
      db: db,
      items: materialCostList,
      column: 'materialCost',
      tableToUpdate: 'mysekai_fixtures',
      key: 'mysekaiBlueprintId',
      value: 'bluprintId',
    );
  }

  static Future<String> processMaterialsData(
    Database db,
    List<dynamic> materialList,
    String newVersionHash,
  ) async {
    try {
      await db.transaction((txn) async {
        var batch = txn.batch();
        for (var material in materialList) {
          batch.insert('mysekai_materials', {
            'id': material['id'] as int? ?? 0,
            'seq': material['seq'] as int? ?? 0,
            'mysekaiMaterialType': material['mysekaiMaterialType'] ?? '',
            'name': material['name'] ?? '',
            'pronunciation': material['pronunciation'] ?? '',
            'description': material['description'] ?? '',
            'mysekaiMaterialRarityType':
                material['mysekaiMaterialRarityType'] ?? '',
            'iconAssetbundleName': material['iconAssetbundleName'] ?? '',
            'mysekaiSiteIds': json.encode(material['mysekaiSiteIds'] ?? []),
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
        await batch.commit(noResult: true);
      });
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('my_sekai_materials_version', newVersionHash);
      return 'Materials processed)';
    } catch (e) {
      return 'Error processing materials: $e';
    }
  }

  /// Query a single fixture by ID
  static Future<Map<String, dynamic>?> getFixtureById(int id) async {
    final dbPath = join(await getDatabasesPath(), 'pjsk_viewer.db');
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final rows = await db.query(
        'mysekai_fixtures',
        where: 'id = ?',
        whereArgs: [id],
      );
      return rows.isNotEmpty ? rows.first : null;
    } finally {
      await db.close();
    }
  }

  static Future<List<Map<String, dynamic>>> getFixtureIndex() async {
    final dbPath = join(await getDatabasesPath(), 'pjsk_viewer.db');
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      return await db.query('mysekai_fixtures');
    } finally {
      await db.close();
    }
  }

  /// Get a single material by ID
  static Future<Map<String, dynamic>?> getMaterialById(int id) async {
    final dbPath = join(await getDatabasesPath(), 'pjsk_viewer.db');
    Database? db;
    try {
      db = await openDatabase(dbPath, readOnly: true);
      final rows = await db.query(
        'mysekai_materials',
        where: 'id = ?',
        whereArgs: [id],
      );
      return rows.isNotEmpty ? rows.first : null;
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }

  /// Get all materials
  static Future<List<Map<String, dynamic>>> getAllMaterials() async {
    final dbPath = join(await getDatabasesPath(), 'pjsk_viewer.db');
    Database? db;
    try {
      db = await openDatabase(dbPath, readOnly: true);
      return await db.query('mysekai_materials');
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }
}
