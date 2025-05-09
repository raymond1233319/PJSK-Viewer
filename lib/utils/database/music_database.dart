import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class MusicDatabase {
  /// Creates the `musics` table.
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS musics(
        id INTEGER PRIMARY KEY,
        seq INTEGER,
        releaseConditionId INTEGER,
        categories TEXT,
        title TEXT,
        pronunciation TEXT,
        creatorArtistId INTEGER,
        lyricist TEXT,
        composer TEXT,
        arranger TEXT,
        dancerCount INTEGER,
        selfDancerPosition INTEGER,
        assetbundleName TEXT,
        liveTalkBackgroundAssetbundleName TEXT,
        publishedAt INTEGER,
        releasedAt INTEGER,
        liveStageId INTEGER,
        fillerSec REAL,
        musicCollaborationId INTEGER,
        isNewlyWrittenMusic INTEGER,
        isFullLength INTEGER,
        tags TEXT,
        vocals TEXT,
        difficulties TEXT
      )
    ''');
  }

  /// Fetches remote musics.json, caches into SQLite, and returns status.
  static Future<String> processDecodedData(
    Database db,
    final List<dynamic> musicsList,
    final List<dynamic> tagListRaw,
    final List<dynamic> vocalListRaw,
    final List<dynamic> difficultyListRaw,
    String newVersionHash,
  ) async {
    try {
      final List<Map<String, dynamic>> tagList =
          tagListRaw.whereType<Map<String, dynamic>>().toList();
      final List<Map<String, dynamic>> vocalList =
          vocalListRaw.whereType<Map<String, dynamic>>().toList();
      final List<Map<String, dynamic>> difficultyList =
          difficultyListRaw.whereType<Map<String, dynamic>>().toList();

      List<Map<String, Object?>> maxIdResult = await db.rawQuery(
        'SELECT MAX(id) AS maxId FROM musics',
      );
      final int latestMusicId =
          maxIdResult.isNotEmpty && maxIdResult.first['maxId'] != null
              ? maxIdResult.first['maxId'] as int
              : 0;
      // 1. Insert/Replace base music data
      await db.transaction((txn) async {
        final Batch insertBatch = txn.batch();
        int processedCount = 0;
        for (final m in musicsList) {
          if (m is Map<String, dynamic>) {
            final int musicId = m['id'] as int? ?? 0;
            // Optional: Skip processing if music ID is not newer
            if (musicId <= latestMusicId) continue;

            insertBatch.insert('musics', {
              'id': m['id'] ?? 0,
              'seq': m['seq'] ?? 0,
              'releaseConditionId': m['releaseConditionId'] ?? 0,
              'categories': json.encode(m['categories'] ?? []),
              'title': m['title'] ?? '',
              'pronunciation': m['pronunciation'] ?? '',
              'creatorArtistId': m['creatorArtistId'] ?? 0,
              'lyricist': m['lyricist'] ?? '',
              'composer': m['composer'] ?? '',
              'arranger': m['arranger'] ?? '',
              'dancerCount': m['dancerCount'] ?? 0,
              'selfDancerPosition': m['selfDancerPosition'] ?? 0,
              'assetbundleName': m['assetbundleName'] ?? '',
              'liveTalkBackgroundAssetbundleName':
                  m['liveTalkBackgroundAssetbundleName'] ?? '',
              'publishedAt': m['publishedAt'] ?? 0,
              'releasedAt': m['releasedAt'] ?? 0,
              'liveStageId': m['liveStageId'] ?? 0,
              'fillerSec': (m['fillerSec'] as num?)?.toDouble() ?? 0.0,
              'musicCollaborationId': m['musicCollaborationId'] ?? 0,
              'isNewlyWrittenMusic': (m['isNewlyWrittenMusic'] == true) ? 1 : 0,
              'isFullLength': (m['isFullLength'] == true) ? 1 : 0,
            }, conflictAlgorithm: ConflictAlgorithm.replace);
            processedCount++;
          }
        }
        if (processedCount > 0) {
          await insertBatch.commit(noResult: true);
        }
      });

      // run groupings
      final grouped = await Future.wait([
        compute(groupByMusicId, tagList),
        compute(groupByMusicId, vocalList),
        compute(groupByMusicId, difficultyList),
      ]);
      final tagMap = grouped[0];
      final vocalMap = grouped[1];
      final diffMap = grouped[2];

      // Update musics table with grouped auxiliary data
      await db.transaction((txn) async {
        final Batch updateBatch = txn.batch();
        int updateCount = 0;
        // Combine all music IDs that have any auxiliary data
        final allMusicIds = <int>{
          ...tagMap.keys,
          ...vocalMap.keys,
          ...diffMap.keys,
        };

        for (final musicId in allMusicIds) {
          if (musicId <= latestMusicId) continue;

          final Map<String, Object?> updates = {};
          // Use the grouped data, defaulting to empty list if a music ID is missing from a map
          updates['tags'] = json.encode(tagMap[musicId] ?? []);
          updates['vocals'] = json.encode(vocalMap[musicId] ?? []);
          updates['difficulties'] = json.encode(diffMap[musicId] ?? []);

          updateBatch.update(
            'musics',
            updates,
            where: 'id = ?',
            whereArgs: [musicId],
          );
          updateCount++;
        }
        if (updateCount > 0) {
          await updateBatch.commit();
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('music_version', newVersionHash);
      return 'Musics fetched and cached successfully!'; // Internal status - ignored
    } catch (e) {
      return 'Error fetching musics: $e'; // Error message - ignored
    }
  }

  static Map<int, List<Map<String, dynamic>>> groupByMusicId(
    List<Map<String, dynamic>> list,
  ) {
    final map = <int, List<Map<String, dynamic>>>{};
    for (final item in list) {
      final id = item['musicId'] as int;
      map.putIfAbsent(id, () => []).add(item);
    }
    return map;
  }

  /// Returns a list of musics
  static Future<List<Map<String, dynamic>>> getMusicIndex() async {
    final dbPath = join(await getDatabasesPath(), 'pjsk_viewer.db');
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      return await db.query('musics', orderBy: 'releasedAt DESC');
    } finally {
      await db.close();
    }
  }

  /// Returns a single music by its ID
  static Future<Map<String, dynamic>?> getMusicById(int musicId) async {
    final dbPath = join(await getDatabasesPath(), 'pjsk_viewer.db');
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      final rows = await db.query(
        'musics',
        where: 'id = ?',
        whereArgs: [musicId],
        limit: 1,
      );
      return rows.isNotEmpty ? rows.first : null;
    } finally {
      await db.close();
    }
  }

  /// Fetches outside‑characters.json, returns a list where index+1 == characterId
  static Future<List<String>> getOutsideCharacterNames() async {
    const cacheKey = 'outside_characters_json';
    final prefs = await SharedPreferences.getInstance();

    try {
      final response = await http.get(
        Uri.parse(
          'https://sekai-world.github.io/sekai-master-db-diff/outsideCharacters.json',
        ),
      );
      if (response.statusCode == 200) {
        await prefs.setString(cacheKey, response.body);
        final List<dynamic> list = json.decode(response.body);
        return _buildNameList(list);
      } else {
        throw Exception(
          'HTTP ${response.statusCode}',
        ); // Error message - ignored
      }
    } catch (_) {
      final cached = prefs.getString(cacheKey);
      if (cached != null) {
        final List<dynamic> list = json.decode(cached);
        return _buildNameList(list);
      }
      rethrow;
    }
  }

  static List<String> _buildNameList(List<dynamic> list) {
    final maxId = list
        .map((e) => e['id'] as int)
        .reduce((a, b) => a > b ? a : b);
    final names = List<String>.filled(maxId, '');
    for (final e in list) {
      final id = e['id'] as int;
      names[id - 1] = e['name'] as String;
    }
    return names;
  }

  /// Build “First Last, First2 Last2, …” from a single vocal entry
  static String buildVocalName(
    context,
    Map<String, dynamic> vocal,
    List<String> outsideCharacterNames,
  ) {
    final localizations = ContentLocalizations.of(context)!;
    final chars =
        (vocal['characters'] as List<dynamic>).map((c) {
          final type = c['characterType'] as String;
          final id = c['characterId'] as int;
          if (type == 'outside_character') {
            return outsideCharacterNames[id - 1];
          } else {
            final idStr = id.toString();
            final first =
                localizations
                    .translate('character_name', idStr, innerKey: 'firstName')
                    .translated;
            final last =
                localizations
                    .translate('character_name', idStr, innerKey: 'givenName')
                    .translated;
            return '$first $last'.trim();
          }
        }).toList();
    return chars.join(', ');
  }
}
