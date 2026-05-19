import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:latlong2/latlong.dart';
import '../../domain/models/geofence_zone.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('geofence.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE zones (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        is_active INTEGER NOT NULL,
        start_time TEXT,
        end_time TEXT,
        type INTEGER NOT NULL DEFAULT 0,
        radius REAL
      )
    ''');

    await db.execute('''
      CREATE TABLE points (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        zone_id TEXT NOT NULL,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        point_order INTEGER NOT NULL,
        FOREIGN KEY (zone_id) REFERENCES zones (id) ON DELETE CASCADE
      )
    ''');
  }

  Future<void> insertZone(GeofenceZone zone) async {
    final db = await instance.database;
    
    await db.transaction((txn) async {
      await txn.insert('zones', zone.toMap());
      for (int i = 0; i < zone.points.length; i++) {
        await txn.insert('points', {
          'zone_id': zone.id,
          'latitude': zone.points[i].latitude,
          'longitude': zone.points[i].longitude,
          'point_order': i,
        });
      }
    });
  }

  Future<List<GeofenceZone>> getAllZones() async {
    final db = await instance.database;
    
    final zonesData = await db.query('zones');
    
    List<GeofenceZone> zones = [];
    for (var zoneMap in zonesData) {
      final pointsData = await db.query(
        'points',
        where: 'zone_id = ?',
        whereArgs: [zoneMap['id']],
        orderBy: 'point_order ASC',
      );
      
      final points = pointsData.map((p) => LatLng(
        p['latitude'] as double,
        p['longitude'] as double,
      )).toList();
      
      zones.add(GeofenceZone.fromMap(zoneMap, points));
    }
    return zones;
  }

  Future<void> deleteZone(String id) async {
    final db = await instance.database;
    
    await db.delete('zones', where: 'id = ?', whereArgs: [id]);
    await db.delete('points', where: 'zone_id = ?', whereArgs: [id]);
  }
}
