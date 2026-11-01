import 'package:flutter/material.dart';

import 'config/app_config.dart';
import 'models/portal_models.dart';
import 'screens/auth_screen.dart';
import 'screens/faculty_dashboard_screen.dart';
import 'screens/student_dashboard_screen.dart';
import 'services/api_service.dart';
import 'services/local_database.dart';
import 'services/session_service.dart';
import 'services/sync_manager.dart';
import 'theme/portal_theme.dart';
import 'widgets/common_widgets.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Warm up local SQLite database & offline-to-online Background Sync Manager
  await LocalDatabase.instance.database;
  await SyncManager.instance.initialize();

  runApp(const MisShsLearnerApp());
}

class MisShsLearnerApp extends StatelessWidget {
  const MisShsLearnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: PortalTheme.buildTheme(),
      home: const PortalRootShell(),
    );
  }
}

class PortalRootShell extends StatefulWidget {
  const PortalRootShell({super.key});

  @override
  State<PortalRootShell> createState() => _PortalRootShellState();
}

class _PortalRootShellState extends State<PortalRootShell> {
  bool _booting = true;
  bool _facultyLoginDuringMaintenance = false;
  SystemStatus? _systemStatus;
  UserSession? _session;

  @override
  void initState() {
    super.initState();
    _bootstrapPortal();
  }

  Future<void> _bootstrapPortal() async {
    setState(() => _booting = true);

    // 1. Restore saved Student or Faculty session immediately when "Stay Signed In" is active
    final savedSession = await SessionService.instance.restoreSession();

    if (savedSession != null) {
      // Load cached announcements instantly so returning learners enter their dashboard
      // without waiting on slow mobile data, then refresh system status in the background.
      final cachedRaw = await LocalDatabase.instance.getCache('system_status');
      final initialStatus = cachedRaw != null
          ? SystemStatus.fromJson(cachedRaw)
          : const SystemStatus(
              status: 'OPEN',
              releasedSubjects: [],
              announcements: [],
            );

      if (!mounted) return;
      setState(() {
        _session = savedSession;
        _systemStatus = initialStatus;
        _booting = false;
      });

      // Background refresh of portal status & announcements
      ApiService.instance.getSystemStatus().then((freshStatus) {
        if (mounted) {
          setState(() => _systemStatus = freshStatus);
        }
      }).catchError((_) {});
      return;
    }

    // 2. Unauthenticated launch: fetch portal status & announcements (falls back to SQLite cache)
    SystemStatus? sysStatus;
    try {
      sysStatus = await ApiService.instance.getSystemStatus();
    } catch (_) {
      sysStatus = const SystemStatus(
        status: 'OPEN',
        releasedSubjects: [],
        announcements: [],
      );
    }

    if (!mounted) return;
    setState(() {
      _session = null;
      _systemStatus = sysStatus;
      _booting = false;
    });
  }

  Future<void> _handleAuthenticated(UserSession session) async {
    await SessionService.instance.saveSession(session);
    if (mounted) {
      setState(() {
        _session = session;
        _facultyLoginDuringMaintenance = false;
      });
    }
  }

  Future<void> _handleLogout() async {
    await SessionService.instance.clearSession();
    if (mounted) {
      setState(() {
        _session = null;
        _facultyLoginDuringMaintenance = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget activeScreen;

    if (_booting) {
      activeScreen = const Scaffold(
        key: ValueKey('portal_boot'),
        backgroundColor: PortalColors.forestDark,
        body: PortalLoadingView(
          message: 'Opening MIS-SHS Learner App...',
          subtitle: 'Syncing academic workspace & announcements',
        ),
      );
    } else {
      final announcements = _systemStatus?.announcements ?? const [];
      final isMaintenance = _systemStatus?.isOfflineOrMaintenance == true;

      // Show Retro TV Maintenance screen unless a Faculty member is logged in or signing in
      if (isMaintenance &&
          (_session == null || !_session!.isFaculty) &&
          !_facultyLoginDuringMaintenance) {
        activeScreen = ParchmentScaffold(
          key: const ValueKey('portal_maintenance'),
          topBanner: announcements.isNotEmpty
              ? AnnouncementMarqueeBanner(announcements: announcements)
              : null,
          child: MaintenanceTvView(
            onRetry: _bootstrapPortal,
            onFacultyBypass: () =>
                setState(() => _facultyLoginDuringMaintenance = true),
          ),
        );
      } else if (_session == null) {
        activeScreen = AuthScreen(
          key: const ValueKey('portal_auth'),
          announcements: announcements,
          onAuthenticated: _handleAuthenticated,
          initialFacultyMode: _facultyLoginDuringMaintenance,
        );
      } else if (_session!.isFaculty) {
        activeScreen = FacultyDashboardScreen(
          key: ValueKey('portal_fac_${_session!.id}'),
          session: _session!,
          announcements: announcements,
          onLogout: _handleLogout,
        );
      } else {
        activeScreen = StudentDashboardScreen(
          key: ValueKey('portal_stu_${_session!.id}'),
          session: _session!,
          announcements: announcements,
          onSessionUpdated: (updated) => setState(() => _session = updated),
          onLogout: _handleLogout,
        );
      }
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: activeScreen,
    );
  }
}
