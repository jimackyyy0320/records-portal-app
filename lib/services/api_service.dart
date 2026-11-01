import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/portal_models.dart';
import 'local_database.dart';
import 'session_service.dart';

class ApiException implements Exception {
  final String message;
  const ApiException(this.message);

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();
  final http.Client _client = http.Client();

  /// Sends a JSON RPC action to Google Apps Script (`doPost`) and transparently
  /// follows Google's 302 redirect (`script.googleusercontent.com/macros/echo`).
  Future<Map<String, dynamic>> postAction(
    String action, [
    Map<String, dynamic>? payload,
    Duration timeout = const Duration(seconds: 28),
  ]) async {
    final scriptUrl = await AppConfig.getScriptUrl();
    if (!AppConfig.isConfiguredUrl(scriptUrl)) {
      throw const ApiException(
        'Backend URL not configured. Tap the ⚙️ icon on the Login screen to set your Apps Script /exec URL.',
      );
    }

    final body = <String, dynamic>{
      'action': action,
      if (payload != null) ...payload,
    };

    http.Response response;
    try {
      final request = http.Request('POST', Uri.parse(scriptUrl))
        ..followRedirects = false
        ..headers['Content-Type'] = 'text/plain;charset=utf-8'
        ..headers['Accept'] = 'application/json'
        ..body = jsonEncode(body);

      final streamed = await _client.send(request).timeout(timeout);
      response = await http.Response.fromStream(streamed);

      // Google Apps Script returns 302 Moved Temporarily on POST with Location
      // pointing to script.googleusercontent.com/macros/echo?... (which accepts GET)
      int redirects = 0;
      while ((response.statusCode == 301 ||
              response.statusCode == 302 ||
              response.statusCode == 303 ||
              response.statusCode == 307 ||
              response.statusCode == 308) &&
          redirects < 5) {
        final location = response.headers['location'];
        if (location == null || location.isEmpty) break;
        response = await _client
            .get(Uri.parse(location), headers: {'Accept': 'application/json'})
            .timeout(timeout);
        redirects++;
      }
    } on TimeoutException {
      throw const ApiException('Connection timed out. Check your internet.');
    } catch (e) {
      throw ApiException('Network error: $e');
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException('Server returned HTTP ${response.statusCode}.');
    }

    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
      throw const ApiException('Unexpected response format from server.');
    } catch (_) {
      throw const ApiException(
        'Invalid JSON from Apps Script. Ensure your Web App is deployed with "Who has access: Anyone".',
      );
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  SYSTEM & AUTHENTICATION ENDPOINTS
  // ─────────────────────────────────────────────────────────────

  Future<SystemStatus> getSystemStatus() async {
    try {
      final res = await postAction('getSystemStatus');
      if (res['status'] == 'ERROR') {
        throw ApiException(res['message']?.toString() ?? 'System status error');
      }
      final status = SystemStatus.fromJson(res);
      await LocalDatabase.instance.putCache('system_status', status.toJson());
      return status;
    } catch (e) {
      final cached = await LocalDatabase.instance.getCache('system_status');
      if (cached != null) {
        return SystemStatus.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> registerStudent({
    required String id,
    required String bdate,
    required String password,
  }) {
    return postAction('registerStudent', {
      'id': id,
      'bdate': bdate,
      'password': password,
    });
  }

  Future<Map<String, dynamic>> loginStudent({
    required String id,
    required String password,
  }) {
    return postAction('loginStudent', {'id': id, 'password': password});
  }

  Future<Map<String, dynamic>> loginFaculty({
    required String id,
    required String password,
  }) {
    return postAction('loginFaculty', {'id': id, 'password': password});
  }

  Future<Map<String, dynamic>> saveStudentProfile({
    required String id,
    required StudentProfile profile,
  }) {
    return postAction('saveStudentProfile', {
      'id': id,
      'profileData': profile.toJson(),
    });
  }

  Future<Map<String, dynamic>> generateAndSendOTP(String id) {
    return postAction('generateAndSendOTP', {'id': id});
  }

  Future<Map<String, dynamic>> verifyOTPAndResetPassword({
    required String id,
    required String otp,
    required String newPassword,
  }) {
    return postAction('verifyOTPAndResetPassword', {
      'id': id,
      'otp': otp,
      'newPassword': newPassword,
    });
  }

  // ─────────────────────────────────────────────────────────────
  //  STUDENT & FACULTY PORTAL DATA ENDPOINTS (WITH OFFLINE CACHE)
  // ─────────────────────────────────────────────────────────────

  Future<SubjectDashboardData> fetchSubjectData({
    required String id,
    required String subjectCode,
    required bool isFaculty,
  }) async {
    final cacheKey = 'subj_data_${id}_${subjectCode}_$isFaculty';
    try {
      final res = await postAction('fetchSubjectData', {
        'id': id,
        'subjectCode': subjectCode,
        'isFaculty': isFaculty,
      });
      if (res['success'] != true) {
        throw ApiException(res['message']?.toString() ?? 'Failed to load data');
      }
      await LocalDatabase.instance.putCache(cacheKey, res);
      return SubjectDashboardData.fromJson(res);
    } catch (e) {
      final cached = await LocalDatabase.instance.getCache(cacheKey);
      if (cached != null) {
        return SubjectDashboardData.fromJson(cached);
      }
      rethrow;
    }
  }

  Future<List<List<dynamic>>> fetchSubjectRoster(String subjectCode) async {
    final cacheKey = 'roster_$subjectCode';
    try {
      final res = await postAction('fetchSubjectRoster', {
        'subjectCode': subjectCode,
      });
      if (res['success'] != true) {
        throw ApiException(
          res['message']?.toString() ?? 'Failed to load subject roster',
        );
      }
      await LocalDatabase.instance.putCache(cacheKey, res);
      return _parseSheetMatrix(res['sheetData']);
    } catch (e) {
      final cached = await LocalDatabase.instance.getCache(cacheKey);
      if (cached != null) {
        return _parseSheetMatrix(cached['sheetData']);
      }
      rethrow;
    }
  }

  List<List<dynamic>> _parseSheetMatrix(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<List>()
        .map((row) => List<dynamic>.from(row))
        .toList();
  }

  Future<Map<String, dynamic>> updateCellData({
    required String subjectCode,
    required int rowIndex,
    required int colIndex,
    required String newValue,
    required String studentId,
  }) {
    return postAction('updateCellData', {
      'subjectCode': subjectCode,
      'rowIndex': rowIndex,
      'colIndex': colIndex,
      'newValue': newValue,
      'studentId': studentId,
    });
  }

  Future<List<ReviewerFile>> fetchReviewerFiles(String subjectCode) async {
    final cacheKey = 'reviewers_$subjectCode';
    try {
      final res = await postAction('fetchReviewerFiles', {
        'subjectCode': subjectCode,
      });
      if (res['success'] != true) {
        return const [];
      }
      await LocalDatabase.instance.putCache(cacheKey, res);
      return _parseReviewerList(res['files']);
    } catch (_) {
      final cached = await LocalDatabase.instance.getCache(cacheKey);
      if (cached != null) {
        return _parseReviewerList(cached['files']);
      }
      return const [];
    }
  }

  List<ReviewerFile> _parseReviewerList(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((f) => ReviewerFile.fromJson(Map<String, dynamic>.from(f)))
        .toList();
  }

  Future<String> fetchRawHtmlContent(String fileId) async {
    final res = await postAction('fetchRawHtmlContent', {'fileId': fileId});
    if (res['success'] != true) {
      throw ApiException(
        res['message']?.toString() ?? 'Failed to load HTML presentation.',
      );
    }
    return res['content']?.toString() ?? '';
  }

  Future<Map<String, dynamic>> fetchDailyAttendanceReport(String dateStr) async {
    final res = await postAction('fetchDailyAttendanceReport', {
      'dateStr': dateStr,
    });
    if (res['success'] != true || res['data'] is! Map) {
      throw ApiException(
        res['message']?.toString() ?? 'Failed to compile attendance report.',
      );
    }
    return Map<String, dynamic>.from(res['data'] as Map);
  }

  Future<String?> getStudentAvatar(String id) async {
    try {
      final res = await postAction('getStudentAvatar', {'id': id});
      return res['avatar']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, String>> getMultipleAvatars(List<String> ids) async {
    try {
      final res = await postAction('getMultipleAvatars', {'ids': ids});
      final map = <String, String>{};
      if (res['avatars'] is Map) {
        (res['avatars'] as Map).forEach((k, v) {
          if (k != null && v != null && v.toString().isNotEmpty) {
            map[k.toString()] = v.toString();
          }
        });
      }
      return map;
    } catch (_) {
      return const {};
    }
  }

  Future<Map<String, dynamic>> uploadStudentAvatar({
    required String id,
    required String dataUrl,
  }) {
    return postAction('uploadStudentAvatar', {'id': id, 'dataUrl': dataUrl});
  }

  Future<Map<String, dynamic>> removeStudentAvatar(String id) {
    return postAction('removeStudentAvatar', {'id': id});
  }

  Future<String> getStudentQRCode(String id) async {
    final res = await postAction('getStudentQRCode', {'id': id});
    if (res['success'] != true || res['data'] == null) {
      throw ApiException(
        res['message']?.toString() ?? 'Contact your Teacher immediately',
      );
    }
    return res['data'].toString();
  }

  // ─────────────────────────────────────────────────────────────
  //  SCANNER BOOTSTRAP ("Reference" Col C) & BATCH SYNC (FACULTY ONLY)
  // ─────────────────────────────────────────────────────────────

  Future<({List<String> subjects, Map<String, String> students})>
      fetchScannerBootstrap({UserSession? sessionOverride}) async {
    final session =
        sessionOverride ?? await SessionService.instance.restoreSession();
    if (session == null || !session.isFaculty) {
      return (subjects: <String>[], students: <String, String>{});
    }
    try {
      final res = await postAction('getScannerBootstrap', {
        'facultyId': session.id,
        'scannerAuthToken': session.scannerAuthToken ?? '',
      });
      if (res['success'] == true) {
        final subjects = (res['subjects'] as List?)
                ?.map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList() ??
            <String>[];
        final students = <String, String>{};
        if (res['students'] is Map) {
          (res['students'] as Map).forEach((k, v) {
            if (k != null && v != null) {
              students[k.toString().trim()] = v.toString().trim();
            }
          });
        }
        await LocalDatabase.instance.saveReferenceBootstrap(
          subjects: subjects,
          students: students,
        );
        return (subjects: subjects, students: students);
      }
    } catch (_) {}
    return LocalDatabase.instance.getCachedReferenceBootstrap();
  }

  Future<Map<String, dynamic>> syncScanBatch(List<ScanLogEntry> logs) async {
    final session = await SessionService.instance.restoreSession();
    if (session == null || !session.isFaculty) {
      return {
        'success': false,
        'message': 'Unauthorized: Faculty access is required to sync scans.',
      };
    }
    return postAction(
      'syncScanBatch',
      {
        'facultyId': session.id,
        'scannerAuthToken': session.scannerAuthToken ?? '',
        'logs': logs.map((e) => e.toSyncJson()).toList(),
      },
      const Duration(seconds: 40),
    );
  }
}
