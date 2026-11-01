import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  AppConfig._();

  /// Deployed Google Apps Script Web App (/exec) URL.
  /// Endpoint editing is hidden from students and restricted to Faculty LMS settings.
  static const String defaultScriptUrl =
      'https://script.google.com/macros/s/AKfycbzDkxouKdcWBjHwCw5ljcBzAa_l_hI1aK4P7sQ5Ujt8sjsSgRsBfPJ6Hx6LpdIwXF8EYA/exec';

  /// Target Google Sheet for Attendance Log, Recitation_Log, and Reference (Col C).
  static const String scanLogSheetId =
      '12DvradQOqCeswwKMtdx7jaIKDRjMUuxWRRD_p1WBCQQ';

  static const String appName = 'MIS-SHS Learner App';
  static const String schoolLogoAsset = 'assets/images/mis_logo.png';

  static const String prefScriptUrlKey = 'portal_gas_exec_url';
  static const String prefSessionKey = 'portal_user_session_v1';
  static const String prefStaySignedInKey = 'portal_stay_signed_in_v1';
  static const String prefLastStudentIdKey = 'portal_last_student_id_v1';

  /// Workmanager task identifiers
  static const String wmOneOffSyncUniqueName = 'portal_oneoff_batch_sync';
  static const String wmPeriodicSyncUniqueName = 'portal_periodic_batch_sync';
  static const String wmTaskSyncScans = 'portalBatchSyncTask';

  /// Default fallback subjects if first launch happens completely offline
  static const List<String> fallbackSubjects = ['PHILO', 'PKLP', 'PGP'];

  static Future<String> getScriptUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(prefScriptUrlKey)?.trim();
    if (saved != null && saved.isNotEmpty && isConfiguredUrl(saved)) {
      return saved;
    }
    return defaultScriptUrl;
  }

  static Future<void> setScriptUrl(String url) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(prefScriptUrlKey, url.trim());
  }

  static Future<void> resetScriptUrlToDefault() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(prefScriptUrlKey);
  }

  static bool isConfiguredUrl(String url) {
    final trimmed = url.trim();
    return trimmed.startsWith('https://script.google.com/macros/s/') &&
        !trimmed.contains('REPLACE_WITH_YOUR_DEPLOYMENT_ID');
  }
}
