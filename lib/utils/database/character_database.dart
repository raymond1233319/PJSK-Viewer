import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CharacterDatabase {
  static Future<void> createTables(Database db) async {
    await db.execute('''
          CREATE TABLE IF NOT EXISTS characters(
          id INTEGER PRIMARY KEY,
          seq INTEGER,
          resourceId INTEGER,
          firstName TEXT,
          givenName TEXT,
          firstNameRuby TEXT,
          givenNameRuby TEXT,
          firstNameEnglish TEXT,
          givenNameEnglish TEXT,
          gender TEXT,
          height REAL,
          live2dHeightAdjustment REAL,
          figure TEXT,
          breastSize TEXT,
          modelName TEXT,
          unit TEXT,
          supportUnitType TEXT
        )
        ''');
  }

  static Future<String> processDecodedData(
    Database db,
    List<dynamic> charactersList,
    String newVersionHash,
  ) async {
    try {

      // Parse the response
      await db.transaction((txn) async {
        for (final character in charactersList) {
          await txn.insert('characters', {
            'id': character['id'] ?? 0,
            'seq': character['seq'] ?? 0,
            'resourceId': character['resourceId'] ?? 0,
            'firstName': character['firstName'] ?? '',
            'givenName': character['givenName'] ?? '',
            'firstNameRuby': character['firstNameRuby'] ?? '',
            'givenNameRuby': character['givenNameRuby'] ?? '',
            'firstNameEnglish': character['firstNameEnglish'] ?? '',
            'givenNameEnglish': character['givenNameEnglish'] ?? '',
            'gender': character['gender'] ?? '',
            'height': character['height'] ?? 0.0,
            'live2dHeightAdjustment':
                character['live2dHeightAdjustment'] ?? 0.0,
            'figure': character['figure'] ?? '',
            'breastSize': character['breastSize'] ?? '',
            'modelName': character['modelName'] ?? '',
            'unit': character['unit'] ?? 'none',
            'supportUnitType': character['supportUnitType'] ?? 'none',
          }, conflictAlgorithm: ConflictAlgorithm.replace);
        }
      });
      // Update the version hash
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('characters_version', newVersionHash);
      return ('Characters processed successfully (version $newVersionHash).');
    } catch (e) {
      return ('Error processing character data: $e');
    }
  }

  static Future<List<Map<String, dynamic>>> getCharacterById(int id) async {
    Database? db;
    try {
      String path = join(await getDatabasesPath(), 'pjsk_viewer.db');
      db = await openDatabase(path, readOnly: true);
      return await db.query('characters', where: 'id = ?', whereArgs: [id]);
    } catch (e) {
      return Future.error('Error fetching character: $e');
    } finally {
      if (db != null && db.isOpen) await db.close();
    }
  }
}
