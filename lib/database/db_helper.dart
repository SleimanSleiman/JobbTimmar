import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/work_entry.dart';
import '../models/customer_history.dart';

class DbHelper {
  static final DbHelper instance = DbHelper._init();
  static Database? _database;

  DbHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('jobb_timmar.db');
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

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
      CREATE TABLE work_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        customer TEXT NOT NULL,
        hours REAL NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');
  }

  // Work Entry methods
  Future<int> insertWorkEntry(WorkEntry entry) async {
    final db = await database;
    
    // Spara kund i historiken automatiskt
    await insertCustomerIfNotExists(entry.customer);
    
    return await db.insert('work_entries', entry.toMap());
  }

  Future<List<WorkEntry>> getAllWorkEntries() async {
    final db = await database;
    final result = await db.query('work_entries', orderBy: 'date DESC');
    return result.map((map) => WorkEntry.fromMap(map)).toList();
  }

  Future<List<WorkEntry>> getWorkEntriesForMonth(int year, int month) async {
    final db = await database;
    
    // Skapa start och slut för månaden
    final startDate = DateTime(year, month, 1);
    final endDate = DateTime(year, month + 1, 1);
    
    final result = await db.query(
      'work_entries',
      where: 'date >= ? AND date < ?',
      whereArgs: [startDate.toIso8601String(), endDate.toIso8601String()],
      orderBy: 'date ASC',
    );
    
    return result.map((map) => WorkEntry.fromMap(map)).toList();
  }

  Future<int> updateWorkEntry(WorkEntry entry) async {
    final db = await database;
    return await db.update(
      'work_entries',
      entry.toMap(),
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> deleteWorkEntry(int id) async {
    final db = await database;
    return await db.delete(
      'work_entries',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Customer History methods
  Future<void> insertCustomerIfNotExists(String customerName) async {
    if (customerName.trim().isEmpty) return;
    
    final db = await database;
    try {
      await db.insert(
        'customer_history',
        {'name': customerName.trim()},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    } catch (e) {
      // Ignorera om kunden redan finns
    }
  }

  Future<List<CustomerHistory>> getAllCustomers() async {
    final db = await database;
    final result = await db.query(
      'customer_history',
      orderBy: 'name ASC',
    );
    return result.map((map) => CustomerHistory.fromMap(map)).toList();
  }

  Future<List<String>> searchCustomers(String query) async {
    final db = await database;
    
    // Hämta kunder sorterade efter senaste användning
    // Kunder som använts i arbetspass kommer först, sorterade efter senaste datum
    final result = await db.rawQuery('''
      SELECT DISTINCT ch.name, 
        (SELECT MAX(we.date) FROM work_entries we WHERE we.customer = ch.name) as last_used
      FROM customer_history ch
      WHERE ch.name LIKE ?
      ORDER BY last_used DESC NULLS LAST, ch.name ASC
    ''', ['%$query%']);
    
    return result.map((map) => map['name'] as String).toList();
  }

  Future<List<String>> getRecentCustomers({int limit = 5}) async {
    final db = await database;
    
    // Hämta de senast använda kunderna baserat på arbetspass
    final result = await db.rawQuery('''
      SELECT DISTINCT customer, MAX(date) as last_used
      FROM work_entries
      GROUP BY customer
      ORDER BY last_used DESC
      LIMIT ?
    ''', [limit]);
    
    return result.map((map) => map['customer'] as String).toList();
  }

  Future<int> deleteCustomer(int id) async {
    final db = await database;
    return await db.delete(
      'customer_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateCustomer(int id, String newName) async {
    final db = await database;
    return await db.update(
      'customer_history',
      {'name': newName.trim()},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> close() async {
    final db = await database;
    db.close();
  }
}
