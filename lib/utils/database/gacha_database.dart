import 'dart:convert';
import 'dart:developer' as developer;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class GachaDatabase {
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS gachas(
          id INTEGER PRIMARY KEY,
          gachaType TEXT,
          name TEXT,
          seq INTEGER,
          assetbundleName TEXT,
          gachaCeilItemId INTEGER,
          startAt INTEGER,
          endAt INTEGER,
          isShowPeriod INTEGER,
          spinLimit INTEGER,
          wishSelectCount INTEGER,
          wishFixedSelectCount INTEGER,
          wishLimitedSelectCount INTEGER,
          gachaCardRarityRates TEXT,
          gachaBehaviors TEXT,
          gachaDetails TEXT,
          gachaPickups TEXT,
          gachaPickupCostumes TEXT,
          gachaInformation TEXT,
          characters TEXT
      );
    ''');
    await db.execute('''
      CREATE TABLE IF NOT EXISTS card_gacha_map (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        gachaId INTEGER NOT NULL,
        cardId INTEGER NOT NULL,
        UNIQUE(gachaId, cardId)
      );
    ''');
    // Add index for faster lookups
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_card_gacha_map_cardId ON card_gacha_map (cardId);',
    );
    await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_card_gacha_map_gachaId ON card_gacha_map (gachaId);',
    );
  }

  static Future<String> processDecodedData(
    Database db,
    final List<dynamic> gachaList,
    final List<dynamic> cardsList,
    final List<dynamic> ceilList,
    final List<dynamic> another3dmvCutIns,
    final String newVersionHash,
  ) async {
    try {
      final List<Map<String, Object?>> maxIdResult = await db.rawQuery(
        'SELECT MAX(id) AS maxId FROM gachas',
      );

      final int latestGachaId =
          maxIdResult.isNotEmpty && maxIdResult.first['maxId'] != null
              ? maxIdResult.first['maxId'] as int
              : 0;

      // 1. Insert or Replace Base Gacha Data
      await db.transaction((txn) async {
        final Batch insertBatch = txn.batch();
        int processedCount = 0;
        for (final g in gachaList) {
          if (g is Map<String, dynamic>) {
            final int gachaId = g['id'] as int? ?? 0;
            if (gachaId <= latestGachaId) continue;

            insertBatch.insert('gachas', {
              'id': gachaId,
              'gachaType': g['gachaType'] ?? 'normal', // Default type
              'name': g['name'] ?? '',
              'seq': g['seq'] ?? 0,
              'assetbundleName': g['assetbundleName'] ?? '',
              'gachaCeilItemId': g['gachaCeilItemId'] ?? 0,
              'startAt': g['startAt'] ?? 0,
              'endAt': g['endAt'] ?? 0,
              'isShowPeriod': (g['isShowPeriod'] as bool?) == true ? 1 : 0,
              'spinLimit': g['spinLimit'] ?? 0,
              'wishSelectCount': g['wishSelectCount'] ?? 0,
              'wishFixedSelectCount': g['wishFixedSelectCount'] ?? 0,
              'wishLimitedSelectCount': g['wishLimitedSelectCount'] ?? 0,
              "gachaDetails": json.encode(g['gachaDetails'] ?? []),
              'gachaCardRarityRates': json.encode(
                g['gachaCardRarityRates'] ?? [],
              ),
              'gachaPickups': json.encode(g['gachaPickups'] ?? []),
              'gachaPickupCostumes': json.encode(
                g['gachaPickupCostumes'] ?? [],
              ),
              'gachaInformation': json.encode(g['gachaInformation'] ?? {}),
              'characters': json.encode([]), // Default, updated later
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            processedCount++;
            if (processedCount % 500 == 0) {
              await insertBatch.commit(noResult: true);
              // insertBatch = txn.batch(); // Re-initialize if needed
            }
          }
        }
        await insertBatch.commit(noResult: true);
      });
      // 2. Build Character Map from Cards Data
      // cardId → characterId map (only needed if cardsList is not empty)
      final Map<int, int> cardToChar =
          cardsList.isNotEmpty
              ? {
                for (var c in cardsList)
                  c['id'] as int: c['characterId'] as int,
              }
              : {};
      // 3. Update 'characters' field in gachas table
      await db.transaction((txn) async {
        // Load only the newly inserted gachas for character update
        final rows = await txn.query(
          'gachas',
          columns: [
            'id',
            'gachaPickups',
          ], // Only need pickups to find characters
          where: 'id > ?', // Process only new gachas
          whereArgs: [latestGachaId],
        );
        final Batch charUpdateBatch = txn.batch();
        int charUpdateCount = 0;
        for (final row in rows) {
          final int gachaId = row['id'] as int;
          final String rawPickups = row['gachaPickups'] as String? ?? '[]';
          final List<dynamic> pickups =
              json.decode(rawPickups) as List<dynamic>;

          final List<int> charIds =
              pickups
                  .map(
                    (p) =>
                        p is Map<String, dynamic> ? p['cardId'] as int? : null,
                  )
                  .where(
                    (cardId) =>
                        cardId != null && cardToChar.containsKey(cardId),
                  ) // Check if cardId exists in map
                  .map((cardId) => cardToChar[cardId]!) // Map to characterId
                  .toSet() // Get unique character IDs
                  .toList(); // Convert back to list

          if (charIds.isNotEmpty) {
            final encodedCharIds = json.encode(charIds);
            charUpdateBatch.update(
              'gachas',
              {'characters': encodedCharIds},
              where: 'id = ?',
              whereArgs: [gachaId],
            );
            charUpdateCount++;
            if (charUpdateCount % 500 == 0) {
              await charUpdateBatch.commit(noResult: true);
            }
          }
        }
        if (charUpdateCount > 0) {
          await charUpdateBatch.commit(noResult: true);
        }
      });

      await _updateGachaType(db, latestGachaId, ceilList, gachaList);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('gachas_version', newVersionHash);
      return ('Gachas processed successfully (version $newVersionHash)!');
    } catch (e) {
      return ('Error processing gacha data: $e');
    }
  }

  static _updateGachaType(
    Database db,
    int latestGachaId,
    List<dynamic> ceilList,
    List<dynamic> gachaList,
  ) async {
    // build map: ceilItemId → newType
    final Map<int, String> ceilTypeById = {};
    for (final item in ceilList) {
      final int ceilItemId = item['id'] as int;
      final String ab = item['assetbundleName'] as String? ?? '';
      String? newType;
      if (ab == 'ceil_item_birthday') {
        newType = 'birthday';
      } else if (ab == 'ceil_item') {
        newType = 'ordinary';
      } else if (ab == 'ceil_item_limited') {
        newType = 'limited';
      }
      if (newType != null) {
        ceilTypeById[ceilItemId] = newType;
      }
    }
    // Update gacha types in the database based on ceil item overrides
    await db.transaction((txn) async {
      final Batch typeUpdateBatch = txn.batch();
      int typeUpdateCount = 0;
      for (final entry in ceilTypeById.entries) {
        typeUpdateBatch.update(
          'gachas',
          {'gachaType': entry.value},
          where: 'gachaCeilItemId = ? AND id > ?',
          whereArgs: [entry.key, latestGachaId],
        );
        typeUpdateCount++;
        if (typeUpdateCount % 500 == 0) {
          await typeUpdateBatch.commit(noResult: true);
        }
      }
      if (typeUpdateCount > 0) {
        await typeUpdateBatch.commit();
      }
    });
    // Populate card_gacha_map for pick-up members
    await db.transaction((txn) async {
      final rows = await txn.query(
        'gachas',
        columns: ['id', 'gachaPickups', 'gachaType'],
        where: 'id > ?',
        whereArgs: [latestGachaId],
      );

      final Batch mapInsertBatch = txn.batch();
      int mapInsertCount = 0;
      for (final row in rows) {
        final int gid = row['id'] as int;
        final String rawPickups = row['gachaPickups'] as String? ?? '[]';
        final List<dynamic> pickups = json.decode(rawPickups) as List<dynamic>;
        final String baseType = row['gachaType'] as String? ?? 'normal';

        if (baseType != 'ordinary' &&
            baseType != 'limited' &&
            baseType != 'birthday') {
          continue;
        }

        for (final p in pickups) {
          if (p is Map<String, dynamic> && p['cardId'] != null) {
            final int cardId = p['cardId'] as int;
            // Insert mapping, replacing if somehow duplicate exists for same gacha/card
            mapInsertBatch.insert('card_gacha_map', {
              'gachaId': gid,
              'cardId': cardId,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            mapInsertCount++;
            if (mapInsertCount % 500 == 0) {
              await mapInsertBatch.commit(noResult: true);
            }
          }
        }
      }
      if (mapInsertCount > 0) {
        await mapInsertBatch.commit(noResult: true);
      }
    });

    // --- Update Gacha Type to 'festival' based on Rarity Rates ---
    await db.transaction((txn) async {
      // Fetch limited gachas
      final limitedGachas = await txn.query(
        'gachas',
        columns: ['id', 'gachaCardRarityRates'],
        where: 'gachaType = ? AND id > ?',
        whereArgs: ['limited', latestGachaId],
      );

      final Batch festivalUpdateBatch = txn.batch();
      int festivalUpdateCount = 0;

      for (final gacha in limitedGachas) {
        final int gachaId = gacha['id'] as int;
        final String ratesJson =
            gacha['gachaCardRarityRates'] as String? ?? '[]';
        double rarity4RateSum = 0.0;

        try {
          final List<dynamic> ratesList = json.decode(ratesJson);
          for (final rateEntry in ratesList) {
            if (rateEntry is Map<String, dynamic> &&
                rateEntry['cardRarityType'] == 'rarity_4' &&
                rateEntry['rate'] != null) {
              rarity4RateSum += rateEntry['rate'].toDouble();
            }
          }
        } catch (e) {
          continue;
        }

        // Check if the sum within the threshold
        if (rarity4RateSum > 5.1 && rarity4RateSum < 6.1) {
          festivalUpdateBatch.update(
            'gachas',
            {'gachaType': 'festival'},
            where: 'id = ?',
            whereArgs: [gachaId],
          );
          festivalUpdateCount++;
          if (festivalUpdateCount % 500 == 0) {
            await festivalUpdateBatch.commit(noResult: true);
          }
        }
      }
      // Commit remaining festival updates
      if (festivalUpdateCount > 0) {
        await festivalUpdateBatch.commit();
      }
    });
  }

  /// Returns a list of gachas
  static Future<List<Map<String, dynamic>>> getGachaIndex() async {
    Database? db;
    try {
      final path = join(await getDatabasesPath(), 'pjsk_viewer.db');
      db = await openDatabase(path);
      List<Map<String, dynamic>> rows = [];
      await db.transaction((txn) async {
        // load all gachas
        rows = await txn.query(
          'gachas',
          columns: [
            'id',
            'name',
            'startAt',
            'endAt',
            'assetbundleName',
            'gachaPickups',
            'characters',
            'gachaType',
          ],
          orderBy: 'startAt DESC',
        );
      });
      return rows;
    } catch (e) {
      return Future.error('Error fetching gacha index: $e');
    } finally {
      if (db != null && db.isOpen) await db.close();
    }
  }

  /// Returns a single gacha by its ID, or null if not found.
  static Future<Map<String, dynamic>?> getGachaById(int gachaId) async {
    final String dbDirectory = await getDatabasesPath();
    final String dbFilePath = join(dbDirectory, 'pjsk_viewer.db');
    final Database db = await openDatabase(dbFilePath, readOnly: true);
    try {
      final List<Map<String, dynamic>> result = await db.query(
        'gachas',
        where: 'id = ?',
        whereArgs: [gachaId],
        limit: 1,
      );
      if (result.isEmpty) return null;

      final Map<String, dynamic> gacha = Map.from(result.first);

      // parse the pickup definitions
      final String rawPickups = gacha['gachaPickups'] as String? ?? '[]';
      final List<dynamic> pickups = json.decode(rawPickups) as List<dynamic>;
      final List<int> pickupIds =
          pickups.map((p) => p['cardId'] as int).toList();

      // fetch full card details for pickups
      List<Map<String, dynamic>> pickupCards = <Map<String, dynamic>>[];
      if (pickupIds.isNotEmpty) {
        final String placeholders = List.filled(
          pickupIds.length,
          '?',
        ).join(',');
        pickupCards = await db.query(
          'cards',
          where: 'id IN ($placeholders)',
          whereArgs: pickupIds,
          orderBy: 'id ASC',
        );
      }
      // attach to returned map
      gacha['pickupCards'] = pickupCards;
      return gacha;
    } finally {
      await db.close();
    }
  }
}
