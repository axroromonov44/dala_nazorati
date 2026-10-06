import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'map_object_store.dart';

/// Opens the map-object database. Separate from [MapObjectStore] so tests can
/// hand the store an in-memory database without going near the file system.
abstract final class MapObjectDatabase {
  static const fileName = 'map_objects.db';

  /// Bump on any schema change, and add the matching branch to [_upgrade].
  static const schemaVersion = 1;

  static Future<Database> open() async {
    final directory = await getDatabasesPath();
    return openDatabase(
      p.join(directory, fileName),
      version: schemaVersion,
      onCreate: (db, _) => MapObjectStore.createSchema(db),
      onUpgrade: _upgrade,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
    );
  }

  /// A failed migration would leave an inspector with an unusable map and no
  /// way to re-download it in the field, so each step has to be additive -
  /// never a drop and recreate.
  static Future<void> _upgrade(Database db, int from, int to) async {
    // Nothing to migrate yet; the first schema is the current one.
  }
}
