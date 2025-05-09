import 'dart:convert';

import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

class ResourceBoxesDatabase {
  static Future<void> createTables(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS event_exchange_resource_boxes(
        id INTEGER PRIMARY KEY,
        resourceBoxType TEXT,
        details TEXT
      )
    ''');
  }

  /// Process resource box data into the database
  static Future<String> processDecodedData(
    Database db,
    final List<dynamic> resourceBoxesList,
    String newVersionHash,
  ) async {
    try {
      await db.transaction((txn) async {
        final Batch boxBatch = txn.batch();
        int processedCount = 0;

        for (final box in resourceBoxesList) {
          if (box is Map<String, dynamic>) {
            final int boxId = box['id'] as int? ?? 0;
            final String resourceBoxPurpose = box['resourceBoxPurpose'] as String? ?? '';
            if (resourceBoxPurpose != 'event_exchange') {
              continue;
            }
            boxBatch.insert(
              'event_exchange_resource_boxes',
              {
                'id': boxId,
                'resourceBoxType': box['resourceBoxType'] ?? '',
                'details': json.encode(box['details']),
              },
              conflictAlgorithm: ConflictAlgorithm.replace,
            );

            processedCount++;
            if (processedCount % 500 == 0) {
              await boxBatch.commit(noResult: true);
            }
          }
        }

        if (processedCount % 500 != 0) {
          await boxBatch.commit(noResult: true);
        }
      });

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('resource_boxes_version', newVersionHash);
      return 'Resource boxes processed successfully!';
    } catch (e) {
      return 'Error processing resource boxes: $e';
    }
  }

  /// Get resource boxes by purpose
  static Future<List<Map<String, dynamic>>> getResourceBoxesByPurpose(
    String purpose,
    List<int> resourceBoxIds,
  ) async {
    final dbPath = join(await getDatabasesPath(), 'pjsk_viewer.db');
    final db = await openDatabase(dbPath, readOnly: true);
    try {
      if (resourceBoxIds.isEmpty) {
        return [];
      }
      return await db.query(
        'event_exchange_resource_boxes',
        where: 'id IN (${resourceBoxIds.join(',')})',
      );
    } finally {
      await db.close();
    }
  }
}
