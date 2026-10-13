import 'package:get/get.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/documented_photo.dart';
import '../models/trip.dart';
import '../models/visit_location.dart';

/// Local database for KAMLOKA Pro trip documentation.
/// Photo bytes are stored as managed files; SQLite stores metadata and paths.
class ProDatabaseService extends GetxService {
  static const _databaseName = 'kamloka_pro.db';
  static const _databaseVersion = 1;

  Database? _database;

  Future<ProDatabaseService> init() async {
    await database;
    return this;
  }

  Future<Database> get database async {
    final current = _database;
    if (current != null && current.isOpen) return current;

    final documents = await getApplicationDocumentsDirectory();
    final dbPath = p.join(documents.path, _databaseName);

    _database = await openDatabase(
      dbPath,
      version: _databaseVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE trips (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            purpose TEXT NOT NULL,
            start_date TEXT NOT NULL,
            end_date TEXT NOT NULL,
            assignment_number TEXT,
            officer_name TEXT,
            notes TEXT,
            status TEXT NOT NULL DEFAULT 'draft',
            created_at TEXT NOT NULL,
            updated_at TEXT NOT NULL
          )
        ''');

        await db.execute('''
          CREATE TABLE visit_locations (
            id TEXT PRIMARY KEY,
            trip_id TEXT NOT NULL,
            name TEXT NOT NULL,
            address TEXT,
            latitude REAL,
            longitude REAL,
            visited_at TEXT,
            notes TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at TEXT NOT NULL,
            FOREIGN KEY (trip_id) REFERENCES trips(id) ON DELETE CASCADE
          )
        ''');

        await db.execute('''
          CREATE TABLE documented_photos (
            id TEXT PRIMARY KEY,
            location_id TEXT NOT NULL,
            file_path TEXT NOT NULL,
            caption TEXT,
            captured_at TEXT,
            latitude REAL,
            longitude REAL,
            address TEXT,
            sort_order INTEGER NOT NULL DEFAULT 0,
            include_in_report INTEGER NOT NULL DEFAULT 1,
            created_at TEXT NOT NULL,
            FOREIGN KEY (location_id) REFERENCES visit_locations(id)
              ON DELETE CASCADE
          )
        ''');

        await db.execute(
          'CREATE INDEX idx_visit_locations_trip_order '
          'ON visit_locations(trip_id, sort_order)',
        );
        await db.execute(
          'CREATE INDEX idx_documented_photos_location_order '
          'ON documented_photos(location_id, sort_order)',
        );
      },
    );

    return _database!;
  }

  Future<void> saveTrip(Trip trip) async {
    final db = await database;
    await db.insert(
      'trips',
      trip.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Trip?> getTrip(String id) async {
    final db = await database;
    final rows = await db.query('trips', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : Trip.fromMap(rows.first);
  }

  Future<List<Trip>> listTrips() async {
    final db = await database;
    final rows = await db.query('trips', orderBy: 'start_date DESC, created_at DESC');
    return rows.map(Trip.fromMap).toList(growable: false);
  }

  Future<void> deleteTrip(String id) async {
    final db = await database;
    await db.delete('trips', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> saveLocation(VisitLocation location) async {
    final db = await database;
    await db.insert(
      'visit_locations',
      location.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<VisitLocation>> listLocations(String tripId) async {
    final db = await database;
    final rows = await db.query(
      'visit_locations',
      where: 'trip_id = ?',
      whereArgs: [tripId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(VisitLocation.fromMap).toList(growable: false);
  }

  Future<void> deleteLocation(String id) async {
    final db = await database;
    await db.delete('visit_locations', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> savePhoto(DocumentedPhoto photo) async {
    final db = await database;
    await db.insert(
      'documented_photos',
      photo.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<DocumentedPhoto>> listPhotos(String locationId) async {
    final db = await database;
    final rows = await db.query(
      'documented_photos',
      where: 'location_id = ?',
      whereArgs: [locationId],
      orderBy: 'sort_order ASC, created_at ASC',
    );
    return rows.map(DocumentedPhoto.fromMap).toList(growable: false);
  }

  Future<void> deletePhoto(String id) async {
    final db = await database;
    await db.delete('documented_photos', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updatePhotoCaption(String id, String? caption) async {
    final db = await database;
    await db.update(
      'documented_photos',
      {'caption': caption?.trim().isEmpty == true ? null : caption?.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> setPhotoIncludedInReport(String id, bool included) async {
    final db = await database;
    await db.update(
      'documented_photos',
      {'include_in_report': included ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> reorderLocations(String tripId, List<String> orderedIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var index = 0; index < orderedIds.length; index++) {
        await txn.update(
          'visit_locations',
          {'sort_order': index},
          where: 'id = ? AND trip_id = ?',
          whereArgs: [orderedIds[index], tripId],
        );
      }
    });
  }

  Future<void> reorderPhotos(String locationId, List<String> orderedIds) async {
    final db = await database;
    await db.transaction((txn) async {
      for (var index = 0; index < orderedIds.length; index++) {
        await txn.update(
          'documented_photos',
          {'sort_order': index},
          where: 'id = ? AND location_id = ?',
          whereArgs: [orderedIds[index], locationId],
        );
      }
    });
  }

  @override
  void onClose() {
    _database?.close();
    _database = null;
    super.onClose();
  }
}
