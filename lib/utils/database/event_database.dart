import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventDatabase {
  static Future<void> createTables(Database db) async {
    await db.execute('''
        CREATE TABLE IF NOT EXISTS events(
          id INTEGER PRIMARY KEY,
          eventType TEXT,
          name TEXT,
          assetbundleName TEXT,
          bgmAssetbundleName TEXT,
          eventOnlyComponentDisplayStartAt INTEGER,
          startAt INTEGER,
          aggregateAt INTEGER,
          rankingAnnounceAt INTEGER,
          distributionStartAt INTEGER,
          eventOnlyComponentDisplayEndAt INTEGER,
          closedAt INTEGER,
          distributionEndAt INTEGER,
          virtualLiveId INTEGER,
          unit TEXT,
          eventRankingRewardRanges TEXT,
          bonusCharacter TEXT,
          bonusAttr TEXT,
          cards TEXT,
          eventStory TEXT,
          eventExchangeSummaries TEXT,
          eventItems TEXT
        )
      ''');
  }

  static Future<String> processDecodedData(
    Database db,
    final List<dynamic> eventsList,
    final List<dynamic> bonusList,
    final List<dynamic> eventStoryList,
    final List<dynamic> eventExchangeSummaries,
    final List<dynamic> eventItemsList,
    String newVersionHash,
  ) async {
    int localEventId = 164;
    try {
      // ───────────────────────────────────────────────────────────────────────
      final List<Map<String, Object?>> maxIdResult = await db.rawQuery(
        'SELECT MAX(id) AS maxId FROM events',
      );
      final int latestEventId =
          maxIdResult.isNotEmpty && maxIdResult.first['maxId'] != null
              ? maxIdResult.first['maxId'] as int
              : 0;

      // 1. Insert base event data within a transaction
      await db.transaction((txn) async {
        final Batch insertBatch = txn.batch();
        int processedCount = 0;
        for (final e in eventsList) {
          if (e is Map<String, dynamic>) {
            final int eventId = e['id'] as int? ?? 0;
            if (eventId <= latestEventId) continue;

            insertBatch.insert('events', {
              'id': eventId,
              'eventType': e['eventType'] ?? '',
              'name': e['name'] ?? '',
              'assetbundleName': e['assetbundleName'] ?? '',
              'bgmAssetbundleName': e['bgmAssetbundleName'] ?? '',
              'eventOnlyComponentDisplayStartAt':
                  e['eventOnlyComponentDisplayStartAt'] ?? 0,
              'startAt': e['startAt'] ?? 0,
              'aggregateAt': e['aggregateAt'] ?? 0,
              'rankingAnnounceAt': e['rankingAnnounceAt'] ?? 0,
              'distributionStartAt': e['distributionStartAt'] ?? 0,
              'eventOnlyComponentDisplayEndAt':
                  e['eventOnlyComponentDisplayEndAt'] ?? 0,
              'closedAt': e['closedAt'] ?? 0,
              'distributionEndAt': e['distributionEndAt'] ?? 0,
              'virtualLiveId': e['virtualLiveId'] ?? 0,
              'unit': e['unit'] ?? '', // May be overridden by local JSON
              'eventRankingRewardRanges': json.encode(
                e['eventRankingRewardRanges'] ?? [],
              ),
              'bonusAttr': 'none',
              'bonusCharacter': json.encode([]),
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            processedCount++;
            if (processedCount % 500 == 0) {
              await insertBatch.commit(noResult: true);
            }
          }
        }
        if (processedCount > 0) {
          await insertBatch.commit(noResult: true);
        }
      });

      await Future.wait([
        batchUpdateEvents(
          db: db,
          items: eventStoryList,
          column: 'eventStory',
          latestEventId: latestEventId,
        ),
        batchUpdateEvents(
          db: db,
          items: eventExchangeSummaries,
          column: 'eventExchangeSummaries',
          latestEventId: latestEventId,
        ),
        buildEventItemAssetbundleMap(eventItemsList),
        processEventBonuses(
          db: db,
          bonusList: bonusList,
          localEventId: localEventId,
          latestEventId: latestEventId,
        ),
      ]);

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('events_version', newVersionHash);
      return ('Events processed successfully (version $newVersionHash)!');
    } catch (e) {
      return ('Error processing event data: $e');
    }
  }

  static Future<int> batchUpdateEvents<T>({
    required Database db,
    required List<dynamic> items,
    required String column,
    required int latestEventId,
  }) async {
    int processedEventIdsCount = 0;

    // Group items by eventId
    final Map<int, List<Map<String, dynamic>>> groupedItems = {};
    for (final item in items) {
      if (item is Map<String, dynamic>) {
        final int eventId = item['eventId'] as int? ?? 0;
        // Skip events that are not new
        if (eventId <= latestEventId) continue;

        groupedItems.putIfAbsent(eventId, () => []).add(item);
      }
    }

    if (groupedItems.isEmpty) {
      return 0;
    }

    await db.transaction((txn) async {
      Batch batch = txn.batch();

      for (final entry in groupedItems.entries) {
        final int eventId = entry.key;
        final List<Map<String, dynamic>> eventSpecificItems = entry.value;

        if (eventSpecificItems.isEmpty) continue;

        Object? valueToEncode;
        if (eventSpecificItems.length == 1) {
          // If only one item for this eventId, encode it directly
          valueToEncode = eventSpecificItems.first;
        } else {
          // If multiple items, encode the list of items
          valueToEncode = eventSpecificItems;
        }

        batch.update(
          'events',
          {
            column: json.encode(valueToEncode),
          }, // Encode the single item or the list
          where: 'id = ?',
          whereArgs: [eventId],
        );
        processedEventIdsCount++;
      }
      await batch.commit(noResult: true);
    });

    return processedEventIdsCount; // Returns the number of unique eventIds processed
  }

  /// Process event bonus data (attributes and characters) and apply local overrides
  static Future<void> processEventBonuses({
    required Database db,
    required List<dynamic> bonusList,
    required int localEventId,
    required int latestEventId,
  }) async {
    await db.transaction((txn) async {
      final Map<int, List<int>> bonusCharacterMap = {};
      final Map<int, String> bonusAttrMap = {}; // Store attributes separately

      // Group bonuses by eventId from the decoded bonusList
      for (final bonus in bonusList) {
        if (bonus is Map<String, dynamic>) {
          final int eventId = bonus["eventId"] as int? ?? 0;
          // Process only bonuses for *newly added* events
          if (eventId <= localEventId || eventId <= latestEventId) continue;

          final bool hasCharacter = bonus["gameCharacterUnitId"] != null;
          final bool hasAttr = bonus["cardAttr"] != null;

          if (hasAttr && !hasCharacter) {
            bonusAttrMap[eventId] = bonus["cardAttr"] as String;
          } else if (hasCharacter && !hasAttr) {
            bonusCharacterMap
                .putIfAbsent(eventId, () => <int>[])
                .add(bonus["gameCharacterUnitId"] as int);
          }
        }
      }

      final Batch updateBatch = txn.batch();

      // Update events with bonus attributes and characters
      for (final entry in bonusAttrMap.entries) {
        updateBatch.update(
          'events',
          {'bonusAttr': entry.value},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }
      for (final entry in bonusCharacterMap.entries) {
        updateBatch.update(
          'events',
          {'bonusCharacter': json.encode(entry.value)},
          where: 'id = ?',
          whereArgs: [entry.key],
        );
      }

      final String jsonStr = await rootBundle.loadString(
        'lib/utils/database/events.json',
      );
      final List<dynamic> localEvents = json.decode(jsonStr) as List<dynamic>;

      for (final e in localEvents) {
        if (e['id'] <= latestEventId) continue;
        updateBatch.update(
          'events',
          {
            'bonusAttr': e['bonusAttr'] as String? ?? '',
            'bonusCharacter': e['bonusCharacter'],
            'unit': e['unit'] as String? ?? '',
          },
          where: 'id = ?',
          whereArgs: [e['id'] as int],
        );
      }

      await updateBatch.commit();
    });
  }

  /// Build a map from event‐item ID → assetbundleName and store in SharedPreferences.
  static Future<void> buildEventItemAssetbundleMap(
    List<dynamic> eventItemsList,
  ) async {
    final Map<String, String> idToAsset = {};
    for (final eventItem in eventItemsList) {
      final int id = eventItem['id'] as int? ?? 0;
      final String assetName = eventItem['assetbundleName'] as String? ?? '';
      if (id > 0 && assetName.isNotEmpty) {
        idToAsset[id.toString()] = assetName;
      }
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('eventItemAssetbundleMap', json.encode(idToAsset));
  }

  /// Retrieve cached map of event-item ID → assetbundleName.
  static Future<Map<int, String>> getEventItemAssetbundleMap() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('eventItemAssetbundleMap') ?? '{}';
    final Map<String, dynamic> decoded =
        json.decode(jsonStr) as Map<String, dynamic>;
    final Map<int, String> result = {};
    decoded.forEach((key, value) {
      final id = int.tryParse(key);
      if (id != null && value is String) {
        result[id] = value;
      }
    });
    return result;
  }

  /// Returns one event with its full card details.
  static Future<Map<String, dynamic>?> getEventByEventId(int eventId) async {
    Database? db;
    try {
      final String path = join(await getDatabasesPath(), 'pjsk_viewer.db');
      db = await openDatabase(path, readOnly: true);

      // Load the event record
      final List<Map<String, dynamic>> results = await db.query(
        'events',
        where: 'id = ?',
        whereArgs: [eventId],
        limit: 1,
      );
      if (results.isEmpty) return null;
      final Map<String, dynamic> event = Map.from(results.first);

      final cards = await db.query(
        'cards',
        where: 'eventId = ?',
        whereArgs: [eventId],
        orderBy: 'id ASC',
      );
      // Attach the card details to the event map
      event['cards'] = cards;

      // Fetch all gachas whose period overlaps the event
      final int startAt = event['startAt'] as int? ?? 0;
      final int aggregateAt = event['aggregateAt'] as int? ?? 0;
      final List<Map<String, dynamic>> overlappingGachas = await db.query(
        'gachas',
        where: 'startAt <= ? AND endAt >= ? AND gachaType IN (?, ?)',
        whereArgs: [aggregateAt, startAt, 'ordinary', 'limited'],
        orderBy: 'startAt DESC',
      );
      event['gachas'] = overlappingGachas;

      return event;
    } catch (e) {
      return Future.error('Error fetching event by ID: $e');
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }

  // Get event index
  static Future<List<Map<String, dynamic>>> getEventIndex() async {
    Database? db;
    try {
      String path = join(await getDatabasesPath(), 'pjsk_viewer.db');
      db = await openDatabase(path, readOnly: true);
      final events = await db.query(
        'events',
        columns: [
          'id',
          'eventType',
          'name',
          'assetbundleName',
          'startAt',
          'aggregateAt',
          'unit',
          'bonusAttr',
          'bonusCharacter',
        ],
        orderBy: 'id DESC',
      );
      return events;
    } catch (e) {
      return Future.error('Error fetching event index: $e');
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }

  /// Get current active event, or null if no event is active
  static Future<Map<String, dynamic>?> getCurrentEvent() async {
    Database? db;
    try {
      final String path = join(await getDatabasesPath(), 'pjsk_viewer.db');
      db = await openDatabase(path, readOnly: true);

      // Find events where current time is between startAt and aggregateAt
      final now = DateTime.now().millisecondsSinceEpoch;
      final List<Map<String, dynamic>> results = await db.query(
        'events',
        where: 'startAt <= ? AND aggregateAt >= ?',
        whereArgs: [now, now],
        limit: 1,
      );

      if (results.isEmpty) {
        return null; // No current event
      }
      return Map.from(results.first);
    } catch (e) {
      return null; // Return null on error
    } finally {
      if (db != null && db.isOpen) {
        await db.close();
      }
    }
  }
}
