import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/work_entry.dart';
import '../models/customer_history.dart';
import '../models/report.dart';

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
      version: 2, // Increased version for migration
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Create reports table first
    await db.execute('''
      CREATE TABLE reports (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at TEXT NOT NULL,
        submitted_at TEXT,
        is_submitted INTEGER NOT NULL DEFAULT 0
      )
    ''');

    await db.execute('''
      CREATE TABLE work_entries (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        date TEXT NOT NULL,
        customer TEXT NOT NULL,
        hours REAL NOT NULL,
        report_id INTEGER,
        FOREIGN KEY (report_id) REFERENCES reports(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE customer_history (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL UNIQUE
      )
    ''');

    // Create initial active report
    await db.insert('reports', {
      'created_at': DateTime.now().toIso8601String(),
      'is_submitted': 0,
    });
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Migration from version 1 to 2
      // Create reports table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS reports (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          created_at TEXT NOT NULL,
          submitted_at TEXT,
          is_submitted INTEGER NOT NULL DEFAULT 0
        )
      ''');

      // Add report_id column to work_entries if it doesn't exist
      try {
        await db.execute('ALTER TABLE work_entries ADD COLUMN report_id INTEGER');
      } catch (e) {
        // Column might already exist
      }

      // Create initial active report
      final reportId = await db.insert('reports', {
        'created_at': DateTime.now().toIso8601String(),
        'is_submitted': 0,
      });

      // Assign all existing work entries to this report
      await db.update(
        'work_entries',
        {'report_id': reportId},
        where: 'report_id IS NULL',
      );
    }
  }

  // ==================== REPORT METHODS ====================

  /// Get the current active (non-submitted) report
  Future<Report?> getActiveReport() async {
    final db = await database;
    final result = await db.query(
      'reports',
      where: 'is_submitted = 0',
      limit: 1,
    );
    
    if (result.isEmpty) return null;
    return Report.fromMap(result.first);
  }

  /// Create a new active report
  Future<Report> createNewReport() async {
    final db = await database;
    final report = Report.createNew();
    final id = await db.insert('reports', report.toMap());
    return report.copyWith(id: id);
  }

  /// Ensure there's always an active report
  Future<Report> ensureActiveReport() async {
    final active = await getActiveReport();
    if (active != null) return active;
    return await createNewReport();
  }

  /// Submit a report (mark as sent)
  Future<void> submitReport(int reportId) async {
    final db = await database;
    await db.update(
      'reports',
      {
        'is_submitted': 1,
        'submitted_at': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  /// Unlock a submitted report (admin function)
  Future<void> unlockReport(int reportId) async {
    final db = await database;
    await db.update(
      'reports',
      {
        'is_submitted': 0,
        'submitted_at': null,
      },
      where: 'id = ?',
      whereArgs: [reportId],
    );
  }

  /// Get all submitted reports
  Future<List<Report>> getSubmittedReports() async {
    final db = await database;
    final result = await db.query(
      'reports',
      where: 'is_submitted = 1',
      orderBy: 'submitted_at DESC',
    );
    return result.map((map) => Report.fromMap(map)).toList();
  }

  /// Get all reports (both active and submitted)
  Future<List<Report>> getAllReports() async {
    final db = await database;
    final result = await db.query(
      'reports',
      orderBy: 'created_at DESC',
    );
    return result.map((map) => Report.fromMap(map)).toList();
  }

  /// Get a report by ID
  Future<Report?> getReportById(int id) async {
    final db = await database;
    final result = await db.query(
      'reports',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (result.isEmpty) return null;
    return Report.fromMap(result.first);
  }

  // ==================== WORK ENTRY METHODS ====================
  
  /// Insert a work entry into the active report
  Future<int> insertWorkEntry(WorkEntry entry) async {
    final db = await database;
    
    // Ensure there's an active report
    final activeReport = await ensureActiveReport();
    
    // Attach to active report
    final entryWithReport = entry.copyWith(reportId: activeReport.id);
    
    // Spara kund i historiken automatiskt
    await insertCustomerIfNotExists(entry.customer);
    
    return await db.insert('work_entries', entryWithReport.toMap());
  }

  /// Get all work entries for a specific report
  Future<List<WorkEntry>> getWorkEntriesForReport(int reportId) async {
    final db = await database;
    final result = await db.query(
      'work_entries',
      where: 'report_id = ?',
      whereArgs: [reportId],
      orderBy: 'date ASC',
    );
    return result.map((map) => WorkEntry.fromMap(map)).toList();
  }

  /// Get all work entries for the active report
  Future<List<WorkEntry>> getActiveReportEntries() async {
    final activeReport = await getActiveReport();
    if (activeReport == null || activeReport.id == null) return [];
    return await getWorkEntriesForReport(activeReport.id!);
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
