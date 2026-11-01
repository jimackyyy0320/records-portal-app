import 'package:flutter/material.dart';

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

  runApp(const RecordsPortalApp());
}

class RecordsPortalApp extends StatelessWidget {
  const RecordsPortalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Records Portal',
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

    // 1. Restore saved Student or Faculty session immediately (works 100% offline)
    final savedSession = await SessionService.instance.restoreSession();

    // 2. Fetch portal status & announcements (falls back to SQLite cache when offline)
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
      _session = savedSession;
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
    if (_booting) {
      return Scaffold(
        backgroundColor: PortalColors.forest,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(color: PortalColors.gold),
              const SizedBox(height: 18),
              Text(
                'CONNECTING TO RECORDS PORTAL...',
                style: PortalTheme.sans(
                  size: 12,
                  weight: FontWeight.w700,
                  letterSpacing: 2.5,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final announcements = _systemStatus?.announcements ?? const [];
    final isMaintenance = _systemStatus?.isOfflineOrMaintenance == true;

    // Show Retro TV Maintenance screen unless a Faculty member is logged in or signing in
    if (isMaintenance &&
        (_session == null || !_session!.isFaculty) &&
        !_facultyLoginDuringMaintenance) {
      return ParchmentScaffold(
        topBanner: announcements.isNotEmpty
            ? AnnouncementMarqueeBanner(announcements: announcements)
            : null,
        child: MaintenanceTvView(
          onRetry: _bootstrapPortal,
          onFacultyBypass: () =>
              setState(() => _facultyLoginDuringMaintenance = true),
        ),
      );
    }

    if (_session == null) {
      return ParchmentScaffold(
        topBanner: announcements.isNotEmpty
            ? AnnouncementMarqueeBanner(announcements: announcements)
            : null,
        child: AuthScreen(
          onAuthenticated: _handleAuthenticated,
          initialFacultyMode: _facultyLoginDuringMaintenance,
        ),
      );
    }

    if (_session!.isFaculty) {
      return FacultyDashboardScreen(
        session: _session!,
        announcements: announcements,
        onLogout: _handleLogout,
      );
    }

    return StudentDashboardScreen(
      session: _session!,
      announcements: announcements,
      onSessionUpdated: (updated) => setState(() => _session = updated),
      onLogout: _handleLogout,
    );
  }
}
