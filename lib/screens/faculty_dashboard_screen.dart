import 'dart:async';

import 'package:flutter/material.dart';

import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../services/sync_manager.dart';
import '../theme/portal_theme.dart';
import '../widgets/common_widgets.dart';
import '../school_lobby/school_lobby_screen.dart';
import 'student_dashboard_screen.dart';
import 'teacher_scanner_screen.dart';

/// Full Faculty LMS Dashboard replicating `#subject-screen`, `#faculty-dashboard`,
/// `#edit-modal`, and individual student drill-down from `index.html`, enhanced with:
/// - Smooth 3-level page sequencing & Android Back navigation (`PopScope`)
/// - Full-screen branded loading overlays (`PortalLoadingOverlay`)
/// - Live student roster search & Faculty-only Apps Script endpoint settings
class FacultyDashboardScreen extends StatefulWidget {
  final UserSession session;
  final List<AnnouncementItem> announcements;
  final VoidCallback onLogout;

  const FacultyDashboardScreen({
    super.key,
    required this.session,
    required this.announcements,
    required this.onLogout,
  });

  @override
  State<FacultyDashboardScreen> createState() => _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  SubjectItem? _activeSubject;
  List<List<dynamic>> _rosterData = const [];
  Map<String, String> _studentAvatars = const {};
  bool _loadingOverlay = false;
  String _loadingMessage = 'Loading Class Roster...';
  String? _loadingSubtitle;

  int _rosterViewTab = 0; // 0: Overview Table, 1: Student Cards
  String? _viewedStudentId;
  final TextEditingController _rosterSearchCtrl = TextEditingController();
  String _rosterSearchQuery = '';

  Timer? _autoRefreshTimer;

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _rosterSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _openClassroomScanner({String? initialSubject}) async {
    if (!widget.session.isFaculty) return;
    await Navigator.of(context).push(
      PortalPageRoute(
        builder: (_) => TeacherScannerScreen(
          session: widget.session,
          facultySubjects: widget.session.subjects,
          initialSubjectCode: initialSubject ?? _activeSubject?.code,
        ),
      ),
    );
  }

  void _openAdminEndpointDialog() {
    if (!widget.session.isFaculty) return;
    showDialog<bool>(
      context: context,
      builder: (_) => const BackendConfigDialog(),
    );
  }

  void _openSchoolLobby() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SchoolLobbyScreen(session: widget.session),
      ),
    );
  }

  Future<void> _loadSubjectRoster(
    SubjectItem subj, {
    String loaderTitle = 'Loading Subject Roster...',
    bool preserveSearch = false,
  }) async {
    setState(() {
      _activeSubject = subj;
      _viewedStudentId = null;
      _loadingOverlay = true;
      _loadingMessage = loaderTitle;
      _loadingSubtitle = '${subj.name} (${subj.code})';
      if (!preserveSearch) {
        _rosterSearchCtrl.clear();
        _rosterSearchQuery = '';
      }
    });

    try {
      final matrix = await ApiService.instance.fetchSubjectRoster(subj.code);
      if (!mounted) return;
      setState(() {
        _rosterData = matrix;
        _loadingOverlay = false;
      });
      _startSilentRosterRefresh();

      // Batch fetch student avatars for the Student Cards view
      final ids = <String>[];
      for (int r = 1; r < matrix.length; r++) {
        if (matrix[r].length > 1) {
          final sId = matrix[r][1].toString().trim();
          if (sId.isNotEmpty && sId != '-') ids.add(sId);
        }
      }
      if (ids.isNotEmpty) {
        final avatars = await ApiService.instance.getMultipleAvatars(ids);
        if (mounted) {
          setState(() => _studentAvatars = avatars);
        }
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingOverlay = false;
        if (!preserveSearch) {
          _activeSubject = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error fetching roster: $e')),
      );
    }
  }

  Future<void> _returnToFacultyHub() async {
    _autoRefreshTimer?.cancel();
    setState(() {
      _loadingOverlay = true;
      _loadingMessage = 'Returning to Faculty Hub...';
      _loadingSubtitle = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() {
      _activeSubject = null;
      _rosterData = const [];
      _rosterSearchCtrl.clear();
      _rosterSearchQuery = '';
      _loadingOverlay = false;
    });
  }

  void _startSilentRosterRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final subj = _activeSubject;
      if (subj == null || _viewedStudentId != null || !mounted) return;
      try {
        final matrix = await ApiService.instance.fetchSubjectRoster(subj.code);
        if (mounted) setState(() => _rosterData = matrix);
      } catch (_) {}
    });
  }

  Future<void> _openEditScoreDialog({
    required int rowIndex,
    required int colIndex,
    required String headerName,
    required String currentVal,
    required String studentId,
  }) async {
    final ctrl = TextEditingController(
      text: currentVal == '-' ? '' : currentVal,
    );
    final savedVal = await showDialog<String>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Edit Score', style: PortalTheme.serif(size: 24)),
              const SizedBox(height: 6),
              Text(
                'EDITING: ${headerName.toUpperCase()}',
                style: PortalTheme.sans(
                  size: 11.5,
                  weight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: PortalColors.ink3,
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: ctrl,
                autofocus: true,
                textAlign: TextAlign.center,
                style: PortalTheme.sans(size: 18, weight: FontWeight.w600),
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onSubmitted: (v) => Navigator.of(ctx).pop(v),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.gold,
                        foregroundColor: PortalColors.forest,
                      ),
                      onPressed: () => Navigator.of(ctx).pop(ctrl.text),
                      child: const Text('💾 Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (savedVal == null || _activeSubject == null || !mounted) return;

    try {
      await PortalLoadingOverlay.run(
        context,
        message: 'Saving Score Update...',
        subtitle: '${headerName.toUpperCase()} • Student $studentId',
        task: () async {
          final res = await ApiService.instance.updateCellData(
            subjectCode: _activeSubject!.code,
            rowIndex: rowIndex,
            colIndex: colIndex,
            newValue: savedVal,
            studentId: studentId,
          );
          if (res['success'] == true) {
            final refreshed = await ApiService.instance
                .fetchSubjectRoster(_activeSubject!.code);
            if (mounted) setState(() => _rosterData = refreshed);
          } else {
            throw ApiException(
              res['message']?.toString() ?? 'Unknown update error',
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Save failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Level 3: Drill-down view for an individual student (with Evaluation Z-Score tab!)
    if (_viewedStudentId != null && _activeSubject != null) {
      return StudentDashboardScreen(
        key: ValueKey('fac_drill_${_viewedStudentId!}'),
        session: widget.session,
        announcements: widget.announcements,
        onSessionUpdated: (_) {},
        onLogout: widget.onLogout,
        facultyViewedStudentId: _viewedStudentId,
        facultyFixedSubjectCode: _activeSubject!.code,
        onFacultyBackToRoster: () => setState(() => _viewedStudentId = null),
      );
    }

    final inRosterView = _activeSubject != null;

    return PopScope(
      canPop: !inRosterView,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (inRosterView) {
          _returnToFacultyHub();
        }
      },
      child: ParchmentScaffold(
        isLoading: _loadingOverlay,
        loadingMessage: _loadingMessage,
        loadingSubtitle: _loadingSubtitle,
        topBanner: widget.announcements.isNotEmpty
            ? AnnouncementMarqueeBanner(announcements: widget.announcements)
            : null,
        topNavigationBar: _buildFacultyTopBar(inRosterView),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: inRosterView
              ? KeyedSubtree(
                  key: ValueKey('fac_roster_${_activeSubject!.code}'),
                  child: _buildFacultyRosterLms(),
                )
              : KeyedSubtree(
                  key: const ValueKey('fac_hub'),
                  child: _buildSubjectSelectionHome(),
                ),
        ),
      ),
    );
  }

  Widget _buildFacultyTopBar(bool inRosterView) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: const BoxDecoration(
        color: PortalColors.forest,
        boxShadow: [
          BoxShadow(
            color: Color(0x240D1F16),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          if (inRosterView)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _returnToFacultyHub,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(26),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: PortalColors.gold,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Subjects',
                      style: PortalTheme.sans(
                        size: 12,
                        weight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SchoolLogoBadge(
                  size: 32,
                  borderWidth: 1.5,
                  showShadow: false,
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'MIS-SHS Faculty',
                      style: PortalTheme.serif(size: 18, color: Colors.white),
                    ),
                    Text(
                      'Prof. ${widget.session.name}',
                      style: PortalTheme.sans(
                        size: 10.5,
                        color: PortalColors.gold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          const Spacer(),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: PortalColors.gold,
              foregroundColor: PortalColors.forest,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () =>
                _openClassroomScanner(initialSubject: _activeSubject?.code),
            icon: const Icon(Icons.qr_code_scanner_rounded, size: 16),
            label: Text(
              'Scanner',
              style: PortalTheme.sans(
                size: 11.5,
                weight: FontWeight.w800,
                color: PortalColors.forest,
              ),
            ),
          ),
          const SizedBox(width: 4),
          IconButton(
            tooltip: 'Enter School Lobby (Teacher Mode)',
            visualDensity: VisualDensity.compact,
            onPressed: _openSchoolLobby,
            icon: const Icon(
              Icons.sports_esports_rounded,
              size: 20,
              color: PortalColors.gold,
            ),
          ),
          // Faculty-Only Apps Script Endpoint configuration button
          IconButton(
            tooltip: 'Apps Script Endpoint (Faculty Admin)',
            visualDensity: VisualDensity.compact,
            onPressed: _openAdminEndpointDialog,
            icon: const Icon(
              Icons.settings_ethernet_rounded,
              size: 19,
              color: Colors.white70,
            ),
          ),
          IconButton(
            tooltip: 'Sign Out',
            visualDensity: VisualDensity.compact,
            onPressed: () => confirmAndLogout(context, widget.onLogout),
            icon: const Icon(
              Icons.logout_rounded,
              size: 19,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScannerQuickCard({String? subjectCode}) {
    return ListenableBuilder(
      listenable: SyncManager.instance,
      builder: (context, _) {
        final sm = SyncManager.instance;
        return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [PortalColors.forest, PortalColors.forestMid],
            ),
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x281A3A2A),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: PortalColors.gold.withAlpha(46),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.qr_code_scanner_rounded,
                      color: PortalColors.gold,
                      size: 30,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'QR & NFC Classroom Scanner',
                          style: PortalTheme.serif(
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sm.pendingCount > 0
                              ? '${sm.pendingCount} offline scan(s) queued for automatic sync'
                              : 'Attendance & Recitation (+1 Pt) • 1.5s anti-burst protection',
                          style: PortalTheme.sans(
                            size: 12,
                            color: Colors.white.withAlpha(215),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: PortalColors.gold,
                    foregroundColor: PortalColors.forest,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: () =>
                      _openClassroomScanner(initialSubject: subjectCode),
                  icon: const Icon(Icons.nfc_rounded, size: 19),
                  label: Text(
                    'LAUNCH CLASSROOM SCANNER',
                    style: PortalTheme.sans(
                      size: 12.5,
                      weight: FontWeight.w800,
                      letterSpacing: 0.6,
                      color: PortalColors.forest,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: PortalColors.gold, width: 1.4),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: _openSchoolLobby,
                  icon: const Icon(
                    Icons.sports_esports_rounded,
                    size: 19,
                    color: PortalColors.gold,
                  ),
                  label: Text(
                    '🎮 ENTER SCHOOL LOBBY (POST QUESTS & REVIEWER CHESTS)',
                    style: PortalTheme.sans(
                      size: 11.5,
                      weight: FontWeight.w800,
                      letterSpacing: 0.5,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSubjectSelectionHome() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildScannerQuickCard(),

              // Assigned Class Rosters
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Assigned Class Rosters',
                  style: PortalTheme.serif(size: 25, italic: true),
                ),
              ),
              const SizedBox(height: 10),

              if (widget.session.subjects.isEmpty)
                Container(
                  padding: const EdgeInsets.all(26),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PortalColors.rule),
                  ),
                  child: Text(
                    'No subjects assigned to this Faculty account.',
                    textAlign: TextAlign.center,
                    style: PortalTheme.sans(color: PortalColors.ink3),
                  ),
                )
              else
                ...widget.session.subjects.map((subj) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: PortalColors.ruleMed),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x141A3A2A),
                          blurRadius: 14,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: () => _loadSubjectRoster(subj),
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: PortalColors.parchment,
                                  borderRadius: BorderRadius.circular(14),
                                  border:
                                      Border.all(color: PortalColors.ruleMed),
                                ),
                                child: Text(
                                  subj.code.length > 5
                                      ? subj.code.substring(0, 5).toUpperCase()
                                      : subj.code.toUpperCase(),
                                  style: PortalTheme.sans(
                                    size: 12,
                                    weight: FontWeight.w800,
                                    color: PortalColors.forest,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      subj.name.isNotEmpty
                                          ? subj.name
                                          : subj.code,
                                      style: PortalTheme.serif(size: 21),
                                    ),
                                    Text(
                                      'Open gradebook, student cards & evaluations',
                                      style: PortalTheme.sans(
                                        size: 11.5,
                                        color: PortalColors.ink3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'Scan ${subj.code}',
                                onPressed: () => _openClassroomScanner(
                                  initialSubject: subj.code,
                                ),
                                icon: const Icon(
                                  Icons.qr_code_scanner_rounded,
                                  color: PortalColors.forest,
                                ),
                              ),
                                const Icon(
                                  Icons.chevron_right_rounded,
                                  color: PortalColors.goldDark,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFacultyRosterLms() {
    final subj = _activeSubject!;
    return RefreshIndicator(
      color: PortalColors.forest,
      onRefresh: () => _loadSubjectRoster(
        subj,
        loaderTitle: 'Refreshing Class Roster...',
        preserveSearch: true,
      ),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 960),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Roster Title + Quick Subject Actions
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PortalColors.rule),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  subj.code.toUpperCase(),
                                  style: PortalTheme.sans(
                                    size: 11,
                                    weight: FontWeight.w800,
                                    letterSpacing: 1.4,
                                    color: PortalColors.goldDark,
                                  ),
                                ),
                                Text(
                                  subj.name,
                                  style: PortalTheme.serif(size: 25),
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: 'Refresh Roster',
                            onPressed: () => _loadSubjectRoster(
                              subj,
                              loaderTitle: 'Refreshing Class Roster...',
                              preserveSearch: true,
                            ),
                            icon: const Icon(
                              Icons.refresh_rounded,
                              color: PortalColors.forest,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      // Quick Search Filter
                      TextField(
                        controller: _rosterSearchCtrl,
                        onChanged: (v) =>
                            setState(() => _rosterSearchQuery = v.trim()),
                        decoration: InputDecoration(
                          hintText: 'Search student name or ID...',
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: PortalColors.ink3,
                          ),
                          suffixIcon: _rosterSearchQuery.isNotEmpty
                              ? IconButton(
                                  onPressed: () {
                                    _rosterSearchCtrl.clear();
                                    setState(() => _rosterSearchQuery = '');
                                  },
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                )
                              : null,
                          filled: true,
                          fillColor: PortalColors.parchment,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 11,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Overview Table vs Student Cards toggle
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: PortalColors.forestFaint,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _rosterTabBtn('🗂️ Overview Table', 0),
                        _rosterTabBtn('👤 Student Cards', 1),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 14),

                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: _rosterViewTab == 0
                      ? KeyedSubtree(
                          key: const ValueKey('roster_table'),
                          child: _buildOverviewTable(),
                        )
                      : KeyedSubtree(
                          key: const ValueKey('roster_cards'),
                          child: _buildStudentCardsList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool _matchesRosterFilter(List<dynamic> row) {
    if (_rosterSearchQuery.isEmpty) return true;
    final q = _rosterSearchQuery.toLowerCase();
    final sId = row.length > 1 ? row[1].toString().toLowerCase() : '';
    final sName = row.length > 2 ? row[2].toString().toLowerCase() : '';
    return sId.contains(q) || sName.contains(q);
  }

  Widget _rosterTabBtn(String label, int idx) {
    final active = _rosterViewTab == idx;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => setState(() => _rosterViewTab = idx),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: active ? PortalColors.forest : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label.toUpperCase(),
          style: PortalTheme.sans(
            size: 11.5,
            weight: FontWeight.w700,
            color: active ? PortalColors.gold : PortalColors.ink3,
          ),
        ),
      ),
    );
  }

  Widget _buildOverviewTable() {
    if (_rosterData.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No roster records found.',
            style: PortalTheme.sans(color: PortalColors.ink3),
          ),
        ),
      );
    }

    final headers = _rosterData.first;
    final indexedRows = <(int, List<dynamic>)>[];
    for (int i = 1; i < _rosterData.length; i++) {
      if (_matchesRosterFilter(_rosterData[i])) {
        indexedRows.add((i, _rosterData[i]));
      }
    }

    if (indexedRows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PortalColors.rule),
        ),
        child: Text(
          'No students match "$_rosterSearchQuery".',
          textAlign: TextAlign.center,
          style: PortalTheme.sans(color: PortalColors.ink3),
        ),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: PortalColors.rule),
      ),
      clipBehavior: Clip.antiAlias,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(PortalColors.forest),
          headingTextStyle: PortalTheme.sans(
            size: 11,
            weight: FontWeight.w700,
            letterSpacing: 0.8,
            color: Colors.white,
          ),
          columns: headers
              .map(
                (h) => DataColumn(
                  label: Text(h.toString().toUpperCase()),
                ),
              )
              .toList(),
          rows: indexedRows.map((entry) {
            final rIndex = entry.$1; // Preserves exact 1-based sheet row index!
            final row = entry.$2;
            final studentId = row.length > 1 ? row[1].toString().trim() : '';

            return DataRow(
              cells: List<DataCell>.generate(headers.length, (c) {
                final rawVal = c < row.length ? row[c].toString() : '';
                final display = rawVal.isEmpty ? '-' : rawVal;

                if (c == 2 && studentId.isNotEmpty && studentId != '-') {
                  return DataCell(
                    Text(
                      '📋 $display',
                      style: PortalTheme.sans(
                        size: 13,
                        weight: FontWeight.w700,
                        color: PortalColors.goldDark,
                      ),
                    ),
                    onTap: () => setState(() => _viewedStudentId = studentId),
                  );
                }

                if (c > 3 && studentId.isNotEmpty && studentId != '-') {
                  return DataCell(
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(display),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.edit_outlined,
                          size: 13,
                          color: PortalColors.ink3,
                        ),
                      ],
                    ),
                    onTap: () => _openEditScoreDialog(
                      rowIndex: rIndex,
                      colIndex: c,
                      headerName: headers[c].toString(),
                      currentVal: display,
                      studentId: studentId,
                    ),
                  );
                }

                return DataCell(Text(display));
              }),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildStudentCardsList() {
    final rows = _rosterData.length > 1
        ? _rosterData.sublist(1).where(_matchesRosterFilter).toList()
        : const <List<dynamic>>[];

    if (rows.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: PortalColors.rule),
        ),
        child: Text(
          'No students match your search.',
          textAlign: TextAlign.center,
          style: PortalTheme.sans(color: PortalColors.ink3),
        ),
      );
    }

    return Column(
      children: rows.map((row) {
        final sId = row.length > 1 ? row[1].toString().trim() : '';
        final sName = row.length > 2 ? row[2].toString().trim() : '';
        if (sId.isEmpty || sId == '-') return const SizedBox.shrink();

        final avatarBytes = decodeDataUrlBytes(_studentAvatars[sId]);
        return Card(
          elevation: 0,
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: PortalColors.ruleMed),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 6,
            ),
            leading: CircleAvatar(
              radius: 22,
              backgroundColor: PortalColors.parchment,
              backgroundImage:
                  avatarBytes != null ? MemoryImage(avatarBytes) : null,
              child: avatarBytes == null
                  ? const Text('🎓', style: TextStyle(fontSize: 20))
                  : null,
            ),
            title: Text(
              sName,
              style: PortalTheme.sans(
                size: 14.5,
                weight: FontWeight.w700,
                color: PortalColors.forest,
              ),
            ),
            subtitle: Text(
              sId,
              style: PortalTheme.sans(
                size: 11.5,
                weight: FontWeight.w600,
                color: PortalColors.ink3,
              ),
            ),
            trailing: const Icon(
              Icons.arrow_forward_rounded,
              color: PortalColors.goldDark,
            ),
            onTap: () => setState(() => _viewedStudentId = sId),
          ),
        );
      }).toList(),
    );
  }
}
