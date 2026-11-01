import 'dart:convert';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import '../models/portal_models.dart';

class LocalDatabase {
  LocalDatabase._();

  static final LocalDatabase instance = LocalDatabase._();
  static Database? _db;

  Future<Database> get database async {
    if (_db != null && _db!.isOpen) return _db!;
    final dbDir = await getDatabasesPath();
    final dbPath = p.join(dbDir, 'records_portal_offline.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE scan_logs (
            log_id TEXT PRIMARY KEY,
            scan_type TEXT NOT NULL,
            timestamp TEXT NOT NULL,
            student_id TEXT NOT NULL,
            student_name TEXT,
            subject TEXT NOT NULL,
            points_awarded INTEGER,
            sync_status TEXT NOT NULL DEFAULT 'pending',
            retry_count INTEGER NOT NULL DEFAULT 0,
            error_message TEXT,
            created_at INTEGER NOT NULL
          )
        ''');
        await db.execute(
          'CREATE INDEX idx_scan_logs_sync_status ON scan_logs(sync_status, created_at)',
        );
        await db.execute('''
          CREATE TABLE kv_cache (
            cache_key TEXT PRIMARY KEY,
            json_value TEXT NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    return _db!;
  }

  // ─────────────────────────────────────────────────────────────
  //  OFFLINE SCAN QUEUE OPERATIONS
  // ─────────────────────────────────────────────────────────────

  Future<void> insertScan(ScanLogEntry entry) async {
    final db = await database;
    await db.insert(
      'scan_logs',
      entry.toDbMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<void> deleteScan(String logId) async {
    final db = await database;
    await db.delete('scan_logs', where: 'log_id = ?', whereArgs: [logId]);
  }

  /// Finds existing Attendance logs for the given [studentId], [subject], and
  /// class [datePrefix] (`YYYY-MM-DD`) so Faculty receives a duplicate warning
  /// with an explicit Override option.
  Future<List<ScanLogEntry>> findAttendanceScansForSubjectDate({
    required String subject,
    required String studentId,
    required String datePrefix,
  }) async {
    final db = await database;
    final rows = await db.query(
      'scan_logs',
      where:
          "scan_type = 'attendance' AND UPPER(subject) = UPPER(?) AND student_id = ? AND substr(timestamp, 1, 10) = ?",
      whereArgs: [subject.trim(), studentId.trim(), datePrefix.trim()],
      orderBy: 'created_at DESC',
    );
    return rows.map(ScanLogEntry.fromDbMap).toList();
  }

  /// Counts how many Recitation logs a student has earned for [subject] on
  /// [datePrefix] (`YYYY-MM-DD`) — multiple Recitation scans per subject are allowed.
  Future<int> countRecitationScansForSubjectDate({
    required String subject,
    required String studentId,
    required String datePrefix,
  }) async {
    final db = await database;
    final res = await db.rawQuery(
      '''
      SELECT COUNT(*) AS cnt
      FROM scan_logs
      WHERE scan_type = 'recitation'
        AND UPPER(subject) = UPPER(?)
        AND student_id = ?
        AND substr(timestamp, 1, 10) = ?
      ''',
      [subject.trim(), studentId.trim(), datePrefix.trim()],
    );
    if (res.isEmpty) return 0;
    return (res.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<List<ScanLogEntry>> getUnsyncedScans({int limit = 150}) async {
    final db = await database;
    final rows = await db.query(
      'scan_logs',
      where: "sync_status IN ('pending', 'failed', 'syncing')",
      orderBy: 'created_at ASC',
      limit: limit,
    );
    return rows.map(ScanLogEntry.fromDbMap).toList();
  }

  Future<List<ScanLogEntry>> getRecentScans({int limit = 50}) async {
    final db = await database;
    final rows = await db.query(
      'scan_logs',
      orderBy: 'created_at DESC',
      limit: limit,
    );
    return rows.map(ScanLogEntry.fromDbMap).toList();
  }

  Future<int> getUnsyncedCount() async {
    final db = await database;
    final res = await db.rawQuery(
      "SELECT COUNT(*) AS cnt FROM scan_logs WHERE sync_status != 'synced'",
    );
    if (res.isEmpty) return 0;
    return (res.first['cnt'] as num?)?.toInt() ?? 0;
  }

  Future<void> markSynced(List<String> logIds) async {
    if (logIds.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in logIds) {
      batch.update(
        'scan_logs',
        {'sync_status': 'synced', 'error_message': null},
        where: 'log_id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> markFailed(List<String> logIds, String error) async {
    if (logIds.isEmpty) return;
    final db = await database;
    final batch = db.batch();
    for (final id in logIds) {
      batch.rawUpdate(
        '''
        UPDATE scan_logs
        SET sync_status = 'failed',
            retry_count = retry_count + 1,
            error_message = ?
        WHERE log_id = ?
        ''',
        [error, id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> clearSyncedHistory() async {
    final db = await database;
    await db.delete('scan_logs', where: "sync_status = 'synced'");
  }

  // ─────────────────────────────────────────────────────────────
  //  KEY-VALUE CACHE FOR OFFLINE DASHBOARDS & REFERENCE SUBJECTS
  // ─────────────────────────────────────────────────────────────

  Future<void> putCache(String key, Map<String, dynamic> data) async {
    final db = await database;
    await db.insert(
      'kv_cache',
      {
        'cache_key': key,
        'json_value': jsonEncode(data),
        'updated_at': DateTime.now().millisecondsSinceEpoch,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCache(String key) async {
    final db = await database;
    final rows = await db.query(
      'kv_cache',
      where: 'cache_key = ?',
      whereArgs: [key],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    try {
      final decoded = jsonDecode(rows.first['json_value'] as String);
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return null;
  }

  Future<void> saveReferenceBootstrap({
    required List<String> subjects,
    required Map<String, String> students,
  }) async {
    await putCache('scanner_reference_bootstrap', {
      'subjects': subjects,
      'students': students,
    });
  }

  Future<({List<String> subjects, Map<String, String> students})>
      getCachedReferenceBootstrap() async {
    final cached = await getCache('scanner_reference_bootstrap');
    if (cached == null) {
      return (subjects: <String>[], students: <String, String>{});
    }
    final subjects = (cached['subjects'] as List?)
            ?.map((e) => e.toString().trim())
            .where((e) => e.isNotEmpty)
            .toList() ??
        <String>[];
    final rawStudents = cached['students'];
    final students = <String, String>{};
    if (rawStudents is Map) {
      rawStudents.forEach((k, v) {
        if (k != null && v != null) {
          students[k.toString().trim()] = v.toString().trim();
        }
      });
    }
    return (subjects: subjects, students: students);
  }
}
