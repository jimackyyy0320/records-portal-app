import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/app_config.dart';
import '../models/portal_models.dart';
import 'local_database.dart';

/// Manages Student & Faculty sessions with "Stay Signed In" persistence across
/// app closes, swipe-from-recents, offline launches, and device restarts.
class SessionService {
  SessionService._();

  static final SessionService instance = SessionService._();

  UserSession? _activeSession;
  bool _staySignedIn = true;

  /// Returns whether "Stay Signed In" is enabled (defaults to `true` so learners
  /// remain logged in across app restarts unless they explicitly opt out).
  Future<bool> getStaySignedInPreference() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getBool(AppConfig.prefStaySignedInKey);
    _staySignedIn = saved ?? true;
    return _staySignedIn;
  }

  Future<void> setStaySignedInPreference(bool staySignedIn) async {
    _staySignedIn = staySignedIn;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConfig.prefStaySignedInKey, staySignedIn);
    if (!staySignedIn) {
      await prefs.remove(AppConfig.prefSessionKey);
    } else if (_activeSession != null) {
      await prefs.setString(
        AppConfig.prefSessionKey,
        jsonEncode(_activeSession!.toJson()),
      );
    }
  }

  Future<String?> getLastStudentId() async {
    final prefs = await SharedPreferences.getInstance();
    final val = prefs.getString(AppConfig.prefLastStudentIdKey)?.trim();
    return (val != null && val.isNotEmpty) ? val : null;
  }

  Future<void> saveSession(
    UserSession session, {
    bool? staySignedIn,
  }) async {
    _activeSession = session;
    final prefs = await SharedPreferences.getInstance();

    final shouldPersist = staySignedIn ??
        (prefs.getBool(AppConfig.prefStaySignedInKey) ?? _staySignedIn);
    _staySignedIn = shouldPersist;
    await prefs.setBool(AppConfig.prefStaySignedInKey, shouldPersist);

    if (!session.isFaculty && session.id.trim().isNotEmpty) {
      await prefs.setString(
        AppConfig.prefLastStudentIdKey,
        session.id.trim(),
      );
    }

    if (session.isFaculty &&
        session.id.trim().isNotEmpty &&
        (session.scannerAuthToken ?? '').trim().isNotEmpty) {
      await persistScannerSyncCredentials(session);
    }

    if (shouldPersist) {
      await prefs.setString(
        AppConfig.prefSessionKey,
        jsonEncode(session.toJson()),
      );
    } else {
      await prefs.remove(AppConfig.prefSessionKey);
    }
  }

  /// Persists the teacher's scanner sync credentials in `SharedPreferences`
  /// whenever they authenticate or open the classroom scanner, so background
  /// `WorkManager` sync tasks can still authenticate even if "Stay Signed In"
  /// was unchecked at login.
  Future<void> persistScannerSyncCredentials(UserSession session) async {
    if (!session.isFaculty) return;
    final cleanId = session.id.trim();
    final cleanToken = (session.scannerAuthToken ?? '').trim();
    if (cleanId.isEmpty || cleanToken.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      AppConfig.prefScannerSyncCredsKey,
      jsonEncode(<String, dynamic>{
        'facultyId': cleanId,
        'scannerAuthToken': cleanToken,
      }),
    );
  }

  /// Returns active Faculty scanner credentials from either the live/restored
  /// session or the dedicated scanner sync credential slot for WorkManager.
  Future<({String facultyId, String scannerAuthToken})?>
      getScannerSyncCredentials() async {
    final session = await restoreSession();
    if (session != null && session.isFaculty) {
      final token = (session.scannerAuthToken ?? '').trim();
      if (session.id.trim().isNotEmpty && token.isNotEmpty) {
        return (facultyId: session.id.trim(), scannerAuthToken: token);
      }
    }

    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConfig.prefScannerSyncCredsKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map) {
        final fid = decoded['facultyId']?.toString().trim() ?? '';
        final token = decoded['scannerAuthToken']?.toString().trim() ?? '';
        if (fid.isNotEmpty && token.isNotEmpty) {
          return (facultyId: fid, scannerAuthToken: token);
        }
      }
    } catch (_) {}
    return null;
  }

  Future<UserSession?> restoreSession() async {
    if (_activeSession != null) {
      return _activeSession;
    }

    final prefs = await SharedPreferences.getInstance();
    final staySignedIn = prefs.getBool(AppConfig.prefStaySignedInKey) ?? true;
    _staySignedIn = staySignedIn;
    if (!staySignedIn) {
      return null;
    }

    final raw = prefs.getString(AppConfig.prefSessionKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map) {
        final restored = UserSession.fromJson(Map<String, dynamic>.from(map));
        _activeSession = restored;
        return restored;
      }
    } catch (_) {}
    return null;
  }

  Future<void> clearSession() async {
    _activeSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.prefSessionKey);
    await prefs.remove(AppConfig.prefScannerSyncCredsKey);
    try {
      await LocalDatabase.instance.clearCache();
    } catch (_) {
      // Safe no-op in headless VM tests without SQLite plugin
    }
  }

  /// Test helper to reset in-memory state between unit tests.
  void resetMemoryCacheForTesting() {
    _activeSession = null;
    _staySignedIn = true;
  }
}
