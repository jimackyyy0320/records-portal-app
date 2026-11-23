import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../models/portal_models.dart';
import 'local_database.dart';
import 'session_service.dart';

class ApiException implements Exception {
  final String message;

  /// `true` when the backend actively responded with a structured rejection
  /// (`{"success": false}` or `{"status": "ERROR"}`), as opposed to a network
  /// timeout or offline transport failure. Server rejections must NEVER be
  /// silently masked by stale offline `kv_cache` data.
  final bool isServerRejection;

  const ApiException(
    this.message, {
    this.isServerRejection = false,
  });

  @override
  String toString() => message;
}

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();
  final http.Client _client = http.Client();

  /// Validates a decoded server response map and throws an [ApiException]
  /// with `isServerRejection: true` when the server actively rejected the call.
  static void assertServerSuccess(
    Map<String, dynamic> res, {
    String fallbackMessage = 'Request failed.',
    bool checkStatusErrorOnly = false,
  }) {
    if (checkStatusErrorOnly) {
      if (res['status'] == 'ERROR') {
        throw ApiException(
          res['message']?.toString() ?? fallbackMessage,
          isServerRejection: true,
        );
      }
      return;
    }
    if (res['success'] != true) {
      throw ApiException(
        res['message']?.toString() ?? fallbackMessage,
        isServerRejection: true,
      );
    }
  }

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
        'Portal backend endpoint is unavailable. Please contact your instructor.',
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
      assertServerSuccess(
        res,
        fallbackMessage: 'System status error',
        checkStatusErrorOnly: true,
      );
      final status = SystemStatus.fromJson(res);
      await LocalDatabase.instance.putCache('system_status', status.toJson());
      return status;
    } on ApiException catch (e) {
      if (e.isServerRejection) rethrow;
      final cached = await LocalDatabase.instance.getCache('system_status');
      if (cached != null) {
        return SystemStatus.fromJson(cached);
      }
      rethrow;
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
      assertServerSuccess(res, fallbackMessage: 'Failed to load data');
      await LocalDatabase.instance.putCache(cacheKey, res);
      return SubjectDashboardData.fromJson(res);
    } on ApiException catch (e) {
      if (e.isServerRejection) rethrow;
      final cached = await LocalDatabase.instance.getCache(cacheKey);
      if (cached != null) {
        return SubjectDashboardData.fromJson(cached);
      }
      rethrow;
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
      assertServerSuccess(
        res,
        fallbackMessage: 'Failed to load subject roster',
      );
      await LocalDatabase.instance.putCache(cacheKey, res);
      return _parseSheetMatrix(res['sheetData']);
    } on ApiException catch (e) {
      if (e.isServerRejection) rethrow;
      final cached = await LocalDatabase.instance.getCache(cacheKey);
      if (cached != null) {
        return _parseSheetMatrix(cached['sheetData']);
      }
      rethrow;
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

  /// Dedicated JSON cloud storage for Virtual School manifests, RPG progress,
  /// and Chronicles of the Sovereign saves, completely isolated from student
  /// profile avatar images. Falls back transparently to legacy avatar JSON
  /// slots if an older Apps Script deployment has not been updated yet.
  Future<Map<String, dynamic>> saveLobbyCloudData({
    required String slotKey,
    required String dataJson,
  }) async {
    final res = await postAction('saveLobbyCloudData', {
      'slotKey': slotKey,
      'dataJson': dataJson,
    });
    if (res['success'] == true) return res;
    final msg = (res['message']?.toString() ?? '').toLowerCase();
    if (msg.contains('unknown action')) {
      final encoded = base64Encode(utf8.encode(dataJson));
      return uploadStudentAvatar(
        id: slotKey,
        dataUrl: 'data:application/json;base64,$encoded',
      );
    }
    return res;
  }

  /// Fetches dedicated JSON cloud storage for [slotKey], with automatic
  /// backward-compatible fallback to legacy JSON avatar slots.
  Future<String?> getLobbyCloudData(String slotKey) async {
    try {
      final res = await postAction('getLobbyCloudData', {'slotKey': slotKey});
      if (res['success'] == true) {
        final raw = res['dataJson']?.toString();
        if (raw != null && raw.trim().isNotEmpty) {
          return raw;
        }
      }
    } catch (_) {}

    // Backward-compatible fallback for older deployments or pre-migration saves
    try {
      final rawDataUrl = await getStudentAvatar(slotKey);
      if (rawDataUrl == null || !rawDataUrl.contains(',')) return null;
      final b64 = rawDataUrl.split(',').last.trim();
      if (b64.isEmpty) return null;
      return utf8.decode(base64Decode(b64));
    } catch (_) {
      return null;
    }
  }

  // ─────────────────────────────────────────────────────────────
  //  SCANNER BOOTSTRAP ("Reference" Col C) & BATCH SYNC (FACULTY ONLY)
  // ─────────────────────────────────────────────────────────────

  Future<({List<String> subjects, Map<String, String> students})>
      fetchScannerBootstrap({UserSession? sessionOverride}) async {
    if (sessionOverride != null && sessionOverride.isFaculty) {
      await SessionService.instance
          .persistScannerSyncCredentials(sessionOverride);
    }
    final creds = sessionOverride != null && sessionOverride.isFaculty
        ? (
            facultyId: sessionOverride.id.trim(),
            scannerAuthToken: (sessionOverride.scannerAuthToken ?? '').trim(),
          )
        : await SessionService.instance.getScannerSyncCredentials();
    if (creds == null || creds.facultyId.isEmpty) {
      return (subjects: <String>[], students: <String, String>{});
    }
    try {
      final res = await postAction('getScannerBootstrap', {
        'facultyId': creds.facultyId,
        'scannerAuthToken': creds.scannerAuthToken,
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

  Future<Map<String, dynamic>> syncScanBatch(
    List<ScanLogEntry> logs, {
    String? facultyId,
    String? scannerAuthToken,
  }) async {
    String? resolvedFacultyId = facultyId?.trim();
    String? resolvedToken = scannerAuthToken?.trim();
    if (resolvedFacultyId == null ||
        resolvedFacultyId.isEmpty ||
        resolvedToken == null ||
        resolvedToken.isEmpty) {
      final creds = await SessionService.instance.getScannerSyncCredentials();
      if (creds == null) {
        return {
          'success': false,
          'message': 'Unauthorized: Faculty access is required to sync scans.',
        };
      }
      resolvedFacultyId = creds.facultyId;
      resolvedToken = creds.scannerAuthToken;
    }
    return postAction(
      'syncScanBatch',
      {
        'facultyId': resolvedFacultyId,
        'scannerAuthToken': resolvedToken,
        'logs': logs.map((e) => e.toSyncJson()).toList(),
      },
      const Duration(seconds: 40),
    );
  }
}
