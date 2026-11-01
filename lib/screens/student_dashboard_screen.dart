import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/app_config.dart';
import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../services/device_bridge_service.dart';
import '../services/session_service.dart';
import '../theme/portal_theme.dart';
import '../utils/reviewer_outline_extractor.dart';
import '../widgets/common_widgets.dart';
import '../widgets/student_qr_generator.dart';
import 'profile_modal.dart';

/// Full Student Dashboard + Faculty Read-Only Student Drill-Down View
/// replicating `#subject-screen`, `#dashboard-screen`, and `#html-streamer`
/// from `index.html`, enhanced with:
/// - Smooth page sequencing & Android Back navigation (`PopScope`)
/// - Full-screen branded loading transitions (`PortalLoadingOverlay`)
/// - App-only `.txt` Study Outline Extractor for HTML Reviewers
class StudentDashboardScreen extends StatefulWidget {
  final UserSession session;
  final List<AnnouncementItem> announcements;
  final ValueChanged<UserSession> onSessionUpdated;
  final VoidCallback onLogout;

  /// Populated when a Faculty member drills into a specific student from Roster.
  final String? facultyViewedStudentId;
  final String? facultyFixedSubjectCode;
  final VoidCallback? onFacultyBackToRoster;

  const StudentDashboardScreen({
    super.key,
    required this.session,
    required this.announcements,
    required this.onSessionUpdated,
    required this.onLogout,
    this.facultyViewedStudentId,
    this.facultyFixedSubjectCode,
    this.onFacultyBackToRoster,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  String? _activeSubjectCode;
  SubjectDashboardData? _dashData;
  List<ReviewerFile> _reviewers = const [];
  bool _loadingSubject = false;
  String _loadingMessage = 'Opening Subject Workspace...';
  String? _loadingSubtitle;
  bool _loadingReviewers = false;
  String? _facultyViewedAvatar;

  int _selectedTabIndex = 0; // 0: Att, 1: Daily, 2: Majors, 3: Reviewers, 4: Eval
  String _selectedMonth = 'all';
  String _selectedWeek = 'all';

  Timer? _autoRefreshTimer;

  bool get _isFacultyViewing => widget.facultyViewedStudentId != null;

  String get _targetStudentId =>
      widget.facultyViewedStudentId ?? widget.session.id;

  bool get _canNavigateBackInsideScreen =>
      (_isFacultyViewing && widget.onFacultyBackToRoster != null) ||
      (!_isFacultyViewing &&
          _activeSubjectCode != null &&
          widget.session.subjects.length > 1);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeEntryFlow();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeEntryFlow() async {
    if (_isFacultyViewing && widget.facultyFixedSubjectCode != null) {
      ApiService.instance
          .getStudentAvatar(widget.facultyViewedStudentId!)
          .then((pic) {
        if (mounted) setState(() => _facultyViewedAvatar = pic);
      });
      await _loadSubjectDashboard(
        widget.facultyFixedSubjectCode!,
        customLoaderTitle: 'Loading Student Record...',
        customLoaderSub: 'Fetching attendance, grades & relative standing',
      );
      return;
    }

    // Enforce mandatory Student Profile completion gate from index.html
    if (!widget.session.profile.isComplete) {
      final completed = await showDialog<StudentProfile>(
        context: context,
        barrierDismissible: false,
        builder: (_) => StudentProfileSheet(
          studentId: widget.session.id,
          initialProfile: widget.session.profile,
          mandatoryCompletion: true,
          onProfileSaved: (updatedProfile) async {
            final updatedSession =
                widget.session.copyWith(profile: updatedProfile);
            await SessionService.instance.saveSession(updatedSession);
            widget.onSessionUpdated(updatedSession);
          },
        ),
      );
      if (completed == null && !mounted) return;
    }

    // Auto-enter dashboard directly if enrolled in only 1 subject
    if (widget.session.subjects.length == 1) {
      await _loadSubjectDashboard(widget.session.subjects.first.code);
    }
  }

  void _startSilentAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 60), (_) async {
      final code = _activeSubjectCode;
      if (code == null || !mounted) return;
      try {
        final refreshed = await ApiService.instance.fetchSubjectData(
          id: _targetStudentId,
          subjectCode: code,
          isFaculty: _isFacultyViewing,
        );
        if (mounted) {
          setState(() => _dashData = refreshed);
        }
      } catch (_) {}
    });
  }

  Future<void> _loadSubjectDashboard(
    String code, {
    String customLoaderTitle = 'Opening Subject Workspace...',
    String? customLoaderSub,
    bool preserveTab = false,
  }) async {
    setState(() {
      _loadingSubject = true;
      _loadingMessage = customLoaderTitle;
      _loadingSubtitle =
          customLoaderSub ?? 'Loading $code attendance, scores & reviewers';
      _activeSubjectCode = code;
      if (!preserveTab) {
        _selectedTabIndex = 0;
        _selectedMonth = 'all';
        _selectedWeek = 'all';
      }
    });

    try {
      final data = await ApiService.instance.fetchSubjectData(
        id: _targetStudentId,
        subjectCode: code,
        isFaculty: _isFacultyViewing,
      );
      if (!mounted) return;
      setState(() {
        _dashData = data;
        _loadingSubject = false;
        _loadingReviewers = true;
      });
      _startSilentAutoRefresh();

      final revs = await ApiService.instance.fetchReviewerFiles(code);
      if (mounted) {
        setState(() {
          _reviewers = revs;
          _loadingReviewers = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingSubject = false;
        if (!preserveTab) {
          _activeSubjectCode = null;
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading records: $e')),
      );
    }
  }

  Future<void> _returnToSubjectHub() async {
    _autoRefreshTimer?.cancel();
    setState(() {
      _loadingSubject = true;
      _loadingMessage = 'Returning to Subject Hub...';
      _loadingSubtitle = null;
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (!mounted) return;
    setState(() {
      _activeSubjectCode = null;
      _dashData = null;
      _reviewers = const [];
      _loadingSubject = false;
    });
  }

  void _openStudentProfileModal() {
    showDialog<void>(
      context: context,
      builder: (_) => StudentProfileSheet(
        studentId: widget.session.id,
        initialProfile: widget.session.profile,
        mandatoryCompletion: false,
        onProfileSaved: (updatedProfile) async {
          final next = widget.session.copyWith(profile: updatedProfile);
          await SessionService.instance.saveSession(next);
          widget.onSessionUpdated(next);
        },
      ),
    );
  }

  Future<void> _openAvatarMenu() async {
    if (_isFacultyViewing) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Profile Picture', style: PortalTheme.serif(size: 24)),
              const SizedBox(height: 6),
              Text(
                'Upload a square photo (Max 3MB).',
                style: PortalTheme.sans(size: 13, color: PortalColors.ink3),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: PortalColors.burg,
                        side: const BorderSide(color: PortalColors.burgBorder),
                      ),
                      onPressed: () => Navigator.of(ctx).pop('remove'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Remove'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.gold,
                        foregroundColor: PortalColors.forest,
                      ),
                      onPressed: () => Navigator.of(ctx).pop('upload'),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Upload'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (action == 'upload') {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (bytes.lengthInBytes > 3000000) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Image too large (Max 3MB).')),
          );
        }
        return;
      }
      if (!mounted) return;
      final croppedDataUrl = await showDialog<String>(
        context: context,
        builder: (_) => AvatarCropDialog(imageBytes: bytes),
      );
      if (croppedDataUrl == null || !mounted) return;

      try {
        final res = await PortalLoadingOverlay.run(
          context,
          message: 'Uploading Profile Photo...',
          subtitle: 'Saving cropped avatar to your portal profile',
          task: () => ApiService.instance.uploadStudentAvatar(
            id: widget.session.id,
            dataUrl: croppedDataUrl,
          ),
        );
        if (res['success'] == true) {
          final updated =
              widget.session.copyWith(avatarDataUrl: croppedDataUrl);
          await SessionService.instance.saveSession(updated);
          widget.onSessionUpdated(updated);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Upload failed: $e')),
          );
        }
      }
    } else if (action == 'remove') {
      if (!mounted) return;
      try {
        final res = await PortalLoadingOverlay.run(
          context,
          message: 'Removing Photo...',
          task: () =>
              ApiService.instance.removeStudentAvatar(widget.session.id),
        );
        if (res['success'] == true) {
          final updated = widget.session.copyWith(clearAvatar: true);
          await SessionService.instance.saveSession(updated);
          widget.onSessionUpdated(updated);
        }
      } catch (_) {}
    }
  }

  Future<void> _openStudentQrGenerator() async {
    final targetId = _targetStudentId.trim();
    if (targetId.isEmpty) return;
    final targetName = _isFacultyViewing
        ? _dashData?.studentName
        : widget.session.name;
    await StudentQrPassDialog.show(
      context,
      studentId: targetId,
      studentName: targetName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isInSubjectWorkspace =
        _activeSubjectCode != null && _dashData != null;

    Widget content;
    if (isInSubjectWorkspace) {
      content = KeyedSubtree(
        key: ValueKey('subj_workspace_${_activeSubjectCode!}'),
        child: _buildSubjectDashboardView(_dashData!),
      );
    } else if (_loadingSubject) {
      content = const SizedBox.expand(key: ValueKey('subj_loading_placeholder'));
    } else {
      content = KeyedSubtree(
        key: const ValueKey('subj_hub'),
        child: _buildSubjectSelectionView(),
      );
    }

    final animatedBody = AnimatedSwitcher(
      duration: const Duration(milliseconds: 260),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeInCubic,
      child: content,
    );

    final bodyWithSchedule = _isFacultyViewing
        ? animatedBody
        : StudentScheduleOverlay(
            schedule: widget.session.schedule,
            child: animatedBody,
          );

    return PopScope(
      canPop: !_canNavigateBackInsideScreen,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_isFacultyViewing && widget.onFacultyBackToRoster != null) {
          widget.onFacultyBackToRoster!();
        } else if (_activeSubjectCode != null &&
            widget.session.subjects.length > 1) {
          _returnToSubjectHub();
        }
      },
      child: ParchmentScaffold(
        isLoading: _loadingSubject,
        loadingMessage: _loadingMessage,
        loadingSubtitle: _loadingSubtitle,
        topBanner: widget.announcements.isNotEmpty
            ? AnnouncementMarqueeBanner(announcements: widget.announcements)
            : null,
        topNavigationBar: _buildTopNavigationBar(isInSubjectWorkspace),
        child: bodyWithSchedule,
      ),
    );
  }

  Widget _buildTopNavigationBar(bool inSubjectWorkspace) {
    if (_isFacultyViewing) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: const BoxDecoration(
          color: PortalColors.forest,
          boxShadow: [
            BoxShadow(
              color: Color(0x220D1F16),
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: PortalColors.gold,
                visualDensity: VisualDensity.compact,
              ),
              onPressed: widget.onFacultyBackToRoster,
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Back to Roster'),
            ),
            const Spacer(),
            IconButton(
              tooltip: 'Generate Student QR Pass',
              visualDensity: VisualDensity.compact,
              onPressed: _openStudentQrGenerator,
              icon: const Icon(
                Icons.qr_code_2_rounded,
                size: 20,
                color: PortalColors.gold,
              ),
            ),
            const SizedBox(width: 4),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withAlpha(28),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'STUDENT RECORD VIEW',
                style: PortalTheme.sans(
                  size: 10.5,
                  weight: FontWeight.w800,
                  letterSpacing: 0.9,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: PortalColors.rule)),
      ),
      child: Row(
        children: [
          if (inSubjectWorkspace && widget.session.subjects.length > 1)
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: _returnToSubjectHub,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: PortalColors.parchment,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: PortalColors.ruleMed),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.arrow_back_rounded,
                      size: 16,
                      color: PortalColors.forest,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Subjects',
                      style: PortalTheme.sans(
                        size: 12,
                        weight: FontWeight.w800,
                        color: PortalColors.forest,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else
            Flexible(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SchoolLogoBadge(
                    size: 30,
                    borderWidth: 1.5,
                    showShadow: false,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      AppConfig.appName,
                      overflow: TextOverflow.ellipsis,
                      style:
                          PortalTheme.serif(size: 18, weight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          if (inSubjectWorkspace && _activeSubjectCode != null) ...[
            IconButton(
              tooltip: 'Refresh Subject Records',
              visualDensity: VisualDensity.compact,
              onPressed: () => _loadSubjectDashboard(
                _activeSubjectCode!,
                customLoaderTitle: 'Refreshing Records...',
                preserveTab: true,
              ),
              icon: const Icon(
                Icons.refresh_rounded,
                size: 20,
                color: PortalColors.forest,
              ),
            ),
          ],
          IconButton(
            tooltip: 'My QR Pass',
            visualDensity: VisualDensity.compact,
            onPressed: _openStudentQrGenerator,
            icon: const Icon(
              Icons.qr_code_2_rounded,
              size: 21,
              color: PortalColors.forest,
            ),
          ),
          IconButton(
            tooltip: 'Sign Out',
            visualDensity: VisualDensity.compact,
            onPressed: () => confirmAndLogout(context, widget.onLogout),
            icon: const Icon(
              Icons.logout_rounded,
              size: 20,
              color: PortalColors.burg,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubjectSelectionView() {
    final avatarBytes = decodeDataUrlBytes(widget.session.avatarDataUrl);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 48),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Student Welcome Hero Card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [PortalColors.forest, PortalColors.forestDark],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x261A3A2A),
                      blurRadius: 22,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        GestureDetector(
                          onTap: _openAvatarMenu,
                          child: Container(
                            padding: const EdgeInsets.all(3),
                            decoration: const BoxDecoration(
                              color: PortalColors.gold,
                              shape: BoxShape.circle,
                            ),
                            child: CircleAvatar(
                              radius: 30,
                              backgroundColor: PortalColors.parchment,
                              backgroundImage: avatarBytes != null
                                  ? MemoryImage(avatarBytes)
                                  : null,
                              child: avatarBytes == null
                                  ? const Text(
                                      '🎓',
                                      style: TextStyle(fontSize: 26),
                                    )
                                  : null,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'WELCOME BACK',
                                style: PortalTheme.sans(
                                  size: 10,
                                  weight: FontWeight.w800,
                                  letterSpacing: 1.4,
                                  color: PortalColors.gold,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.session.name,
                                style: PortalTheme.serif(
                                  size: 24,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                'Student ID: ${widget.session.id}',
                                style: PortalTheme.sans(
                                  size: 12,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Colors.white38),
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            onPressed: _openStudentProfileModal,
                            icon: const Icon(
                              Icons.badge_outlined,
                              size: 17,
                              color: PortalColors.gold,
                            ),
                            label: const Text('My Profile'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PortalColors.gold,
                              foregroundColor: PortalColors.forest,
                              padding: const EdgeInsets.symmetric(vertical: 11),
                            ),
                            onPressed: _openStudentQrGenerator,
                            icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                            label: const Text('QR Pass'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 22),

              // Section Title: Enrolled Subjects
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Row(
                  children: [
                    Text(
                      'My Enrolled Subjects',
                      style: PortalTheme.serif(size: 25, italic: true),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: PortalColors.forestFaint,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${widget.session.subjects.length} SUBJECT${widget.session.subjects.length == 1 ? "" : "S"}',
                        style: PortalTheme.sans(
                          size: 10.5,
                          weight: FontWeight.w800,
                          color: PortalColors.forest,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              if (widget.session.subjects.isEmpty)
                Container(
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: PortalColors.rule),
                  ),
                  child: Text(
                    'No released subjects are currently assigned to your Student ID.',
                    textAlign: TextAlign.center,
                    style: PortalTheme.sans(color: PortalColors.ink3),
                  ),
                )
              else
                ...widget.session.subjects.map((subj) {
                  final matchingSched = widget.session.schedule
                      .where(
                        (s) =>
                            s.subjectCode.toUpperCase() ==
                            subj.code.toUpperCase(),
                      )
                      .toList();
                  final schedText = matchingSched.isEmpty
                      ? 'Tap to view attendance, progress & reviewers'
                      : matchingSched
                          .map((s) => '${s.day} (${s.timeIn} – ${s.timeOut})')
                          .join(' • ');

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
                        onTap: () => _loadSubjectDashboard(subj.code),
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Row(
                            children: [
                              Container(
                                width: 54,
                                height: 54,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: PortalColors.parchment,
                                  borderRadius: BorderRadius.circular(15),
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
                                    const SizedBox(height: 3),
                                    Text(
                                      schedText,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: PortalTheme.sans(
                                        size: 11.5,
                                        color: PortalColors.ink3,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 34,
                                height: 34,
                                decoration: const BoxDecoration(
                                  color: PortalColors.forest,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 17,
                                  color: PortalColors.gold,
                                ),
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

  Widget _buildSubjectDashboardView(SubjectDashboardData data) {
    final avatarBytes = decodeDataUrlBytes(
      _isFacultyViewing ? _facultyViewedAvatar : widget.session.avatarDataUrl,
    );

    final greeting = _isFacultyViewing
        ? data.studentName.toUpperCase()
        : 'Welcome, ${widget.session.firstNameGreeting}';

    final tabs = <(String, int)>[
      ('📅 Attendance', 0),
      ('📊 Daily Progress', 1),
      ('📝 Majors', 2),
      ('📚 Reviewers', 3),
      if (_isFacultyViewing) ('📈 Evaluation', 4),
    ];

    return RefreshIndicator(
      color: PortalColors.forest,
      onRefresh: () async {
        if (_activeSubjectCode != null) {
          await _loadSubjectDashboard(
            _activeSubjectCode!,
            customLoaderTitle: 'Refreshing Records...',
            preserveTab: true,
          );
        }
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 48),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: Column(
              children: [
                // Student Profile Card (.dash-profile-card)
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(26),
                    border: Border.all(color: PortalColors.rule),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F1A3A2A),
                        blurRadius: 22,
                        offset: Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Container(
                            height: _isFacultyViewing ? 64 : 96,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  PortalColors.forest,
                                  PortalColors.forestDark,
                                ],
                              ),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(25),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: _isFacultyViewing ? -28 : -42,
                            child: GestureDetector(
                              onTap: _isFacultyViewing ? null : _openAvatarMenu,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Color(0x221A3A2A),
                                      blurRadius: 10,
                                    ),
                                  ],
                                ),
                                child: CircleAvatar(
                                  radius: _isFacultyViewing ? 28 : 42,
                                  backgroundColor: PortalColors.parchmentDk,
                                  backgroundImage: avatarBytes != null
                                      ? MemoryImage(avatarBytes)
                                      : null,
                                  child: avatarBytes == null
                                      ? Text(
                                          '👤',
                                          style: TextStyle(
                                            fontSize:
                                                _isFacultyViewing ? 22 : 30,
                                          ),
                                        )
                                      : null,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: _isFacultyViewing ? 36 : 48),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          greeting,
                          textAlign: TextAlign.center,
                          style: PortalTheme.serif(
                            size: _isFacultyViewing ? 22 : 27,
                            italic: true,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        margin: const EdgeInsets.symmetric(horizontal: 16),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: PortalColors.parchment,
                          borderRadius: BorderRadius.circular(50),
                          border: Border.all(color: PortalColors.ruleMed),
                        ),
                        child: Text(
                          data.subjectName.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PortalTheme.sans(
                            size: 10.5,
                            weight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: PortalColors.forest,
                          ),
                        ),
                      ),
                      if (!_isFacultyViewing) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PortalColors.forest,
                                foregroundColor: Colors.white,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _openStudentProfileModal,
                              icon: const Icon(
                                Icons.person_outline_rounded,
                                size: 15,
                                color: PortalColors.gold,
                              ),
                              label: Text(
                                'VIEW PROFILE',
                                style: PortalTheme.sans(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                            ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: PortalColors.gold,
                                foregroundColor: PortalColors.forest,
                                visualDensity: VisualDensity.compact,
                              ),
                              onPressed: _downloadStudentQr,
                              icon: const Icon(
                                Icons.qr_code_2_rounded,
                                size: 16,
                              ),
                              label: Text(
                                'DOWNLOAD QR',
                                style: PortalTheme.sans(
                                  size: 11,
                                  weight: FontWeight.w800,
                                  color: PortalColors.forest,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 18),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Horizontal Scrollable Module Tab Bar (.tab-nav)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: PortalColors.forestFaint,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: tabs.map((t) {
                        final active = _selectedTabIndex == t.$2;
                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 3),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(13),
                            onTap: () =>
                                setState(() => _selectedTabIndex = t.$2),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: active
                                    ? PortalColors.forest
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(13),
                              ),
                              child: Text(
                                t.$1.toUpperCase(),
                                style: PortalTheme.sans(
                                  size: 11,
                                  weight: FontWeight.w700,
                                  color: active
                                      ? PortalColors.gold
                                      : PortalColors.ink3,
                                ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Active Module Card (.module-container) with smooth transition
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: PortalColors.rule),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F1A3A2A),
                        blurRadius: 20,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    child: KeyedSubtree(
                      key: ValueKey('module_tab_$_selectedTabIndex'),
                      child: _buildActiveModuleContent(data),
                    ),
                  ),
                ),

                const SizedBox(height: 18),
                if (_isFacultyViewing && widget.onFacultyBackToRoster != null)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: widget.onFacultyBackToRoster,
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: const Text('Back to Class Roster'),
                    ),
                  )
                else if (widget.session.subjects.length > 1)
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _returnToSubjectHub,
                      icon: const Icon(Icons.grid_view_rounded, size: 18),
                      label: const Text('All Enrolled Subjects'),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _moduleHeader(String title) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [PortalColors.forest, PortalColors.forestDark],
        ),
      ),
      child: Text(
        title,
        style: PortalTheme.serif(size: 24, color: Colors.white, italic: true),
      ),
    );
  }

  Widget _buildActiveModuleContent(SubjectDashboardData data) {
    switch (_selectedTabIndex) {
      case 0:
        return _buildAttendanceTab(data);
      case 1:
        return _buildDailyProgressTab(data);
      case 2:
        return _buildMajorsTab(data);
      case 3:
        return _buildReviewersTab();
      case 4:
        return _buildEvaluationTab(data);
      default:
        return _buildAttendanceTab(data);
    }
  }

  Widget _buildAttendanceTab(SubjectDashboardData data) {
    final months = <String>{
      for (final r in data.attendanceRecords)
        if (r.monthPrefix.isNotEmpty) r.monthPrefix,
    }.toList();

    final filtered = _selectedMonth == 'all'
        ? data.attendanceRecords
        : data.attendanceRecords
            .where((r) => r.date.startsWith(_selectedMonth))
            .toList();

    final presCount = _selectedMonth == 'all'
        ? data.totalPresent
        : filtered.where((r) => r.isPresent).length;
    final absCount = _selectedMonth == 'all'
        ? data.totalAbsent
        : filtered.where((r) => !r.isPresent).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader('Attendance Record'),
        Container(
          color: const Color(0xFFFAF7F2),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: PortalColors.emeraldBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PortalColors.emeraldBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'PRESENT: $presCount',
                    style: PortalTheme.sans(
                      size: 12,
                      weight: FontWeight.w800,
                      color: PortalColors.emerald,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: PortalColors.burgBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: PortalColors.burgBorder),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    'ABSENT: $absCount',
                    style: PortalTheme.sans(
                      size: 12,
                      weight: FontWeight.w800,
                      color: PortalColors.burg,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (months.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PortalColors.ruleMed),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value:
                      months.contains(_selectedMonth) ? _selectedMonth : 'all',
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Months'),
                    ),
                    ...months.map(
                      (m) => DropdownMenuItem(value: m, child: Text(m)),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedMonth = val ?? 'all'),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: AttendanceDoughnutChart(present: presCount, absent: absCount),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No attendance records.',
                    textAlign: TextAlign.center,
                    style: PortalTheme.sans(color: PortalColors.ink3),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 4,
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    childAspectRatio: 1.15,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final r = filtered[idx];
                    return Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: PortalColors.ruleMed),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            r.date,
                            style: PortalTheme.sans(
                              size: 11,
                              weight: FontWeight.w700,
                              color: PortalColors.ink2,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: r.isPresent
                                  ? PortalColors.emerald
                                  : PortalColors.burg,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildDailyProgressTab(SubjectDashboardData data) {
    final weeks = <String>{
      for (final d in data.dailyProgress) d.week,
    }.toList()
      ..sort((a, b) {
        if (a == 'Other') return 1;
        if (b == 'Other') return -1;
        final na = int.tryParse(a.replaceAll('Week ', '')) ?? 999;
        final nb = int.tryParse(b.replaceAll('Week ', '')) ?? 999;
        return na.compareTo(nb);
      });

    final filtered = _selectedWeek == 'all'
        ? data.dailyProgress
        : data.dailyProgress.where((d) => d.week == _selectedWeek).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader('Daily Progress'),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 26),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [PortalColors.parchment, Colors.white],
            ),
            border: Border(bottom: BorderSide(color: PortalColors.rule)),
          ),
          child: Column(
            children: [
              Text(
                'TOTAL RECITATIONS',
                style: PortalTheme.sans(
                  size: 11,
                  weight: FontWeight.w800,
                  letterSpacing: 2.8,
                  color: PortalColors.goldDark,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data.recitations,
                style: PortalTheme.serif(size: 62, height: 1.0),
              ),
            ],
          ),
        ),
        if (weeks.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: PortalColors.ruleMed),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: weeks.contains(_selectedWeek) ? _selectedWeek : 'all',
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All Weeks'),
                    ),
                    ...weeks.map(
                      (w) => DropdownMenuItem(value: w, child: Text(w)),
                    ),
                  ],
                  onChanged: (val) =>
                      setState(() => _selectedWeek = val ?? 'all'),
                ),
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: filtered.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    'No daily progress records.',
                    textAlign: TextAlign.center,
                    style: PortalTheme.sans(color: PortalColors.ink3),
                  ),
                )
              : GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.45,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, idx) {
                    final item = filtered[idx];
                    return InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: item.isMissing
                          ? () async {
                              final altUrl =
                                  data.alternatives[item.week.toUpperCase()];
                              if (altUrl != null && altUrl.isNotEmpty) {
                                final uri = Uri.tryParse(altUrl);
                                if (uri != null) {
                                  await launchUrl(
                                    uri,
                                    mode: LaunchMode.externalApplication,
                                  );
                                  return;
                                }
                              }
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Activity is not yet available',
                                    ),
                                  ),
                                );
                              }
                            }
                          : null,
                      child: _scoreTile(
                        title: item.name,
                        score: item.score,
                        maxScore: item.maxScore,
                        isMissing: item.isMissing,
                      ),
                    );
                  },
                ),
        ),
        if (filtered.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
            child: DailyProgressBarChart(items: filtered),
          ),
      ],
    );
  }

  Widget _buildMajorsTab(SubjectDashboardData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader('Major Assessments'),
        if (!data.hasMajors || data.majors.isEmpty)
          Padding(
            padding: const EdgeInsets.all(36),
            child: Text(
              'No major assessments recorded.',
              textAlign: TextAlign.center,
              style: PortalTheme.sans(color: PortalColors.ink3),
            ),
          )
        else
          Padding(
            padding: const EdgeInsets.all(16),
            child: GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.95,
              ),
              itemCount: data.majors.length,
              itemBuilder: (context, idx) {
                final m = data.majors[idx];
                return _scoreTile(
                  title: m.label,
                  score: m.score,
                  maxScore: m.maxScore,
                  isMissing: m.isMissing,
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _scoreTile({
    required String title,
    required String? score,
    required String? maxScore,
    required bool isMissing,
  }) {
    final hasMax = maxScore != null && maxScore.trim().isNotEmpty;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: PortalColors.parchment,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: PortalColors.rule),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            title.toUpperCase(),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: PortalTheme.sans(
              size: 10,
              weight: FontWeight.w700,
              letterSpacing: 0.8,
              color: PortalColors.ink3,
            ),
          ),
          const SizedBox(height: 6),
          if (isMissing)
            Text(
              'NO RECORD',
              style: PortalTheme.sans(
                size: 12,
                weight: FontWeight.w800,
                color: PortalColors.burg,
              ),
            )
          else
            RichText(
              text: TextSpan(
                style: PortalTheme.serif(size: 30),
                children: [
                  TextSpan(text: score),
                  if (hasMax)
                    TextSpan(
                      text: ' / $maxScore',
                      style: PortalTheme.sans(
                        size: 13,
                        weight: FontWeight.w600,
                        color: PortalColors.ink3,
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildReviewersTab() {
    if (_loadingReviewers) {
      return Column(
        children: [
          _moduleHeader('Reviewers'),
          Padding(
            padding: const EdgeInsets.all(36),
            child: Column(
              children: [
                const CircularProgressIndicator(color: PortalColors.forest),
                const SizedBox(height: 12),
                Text(
                  'LOADING REVIEWER MATERIALS...',
                  style: PortalTheme.sans(
                    size: 11.5,
                    weight: FontWeight.w700,
                    letterSpacing: 1.2,
                    color: PortalColors.ink3,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    if (_reviewers.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _moduleHeader('Reviewers'),
          Padding(
            padding: const EdgeInsets.all(36),
            child: Text(
              'No reviewers available for this subject.',
              textAlign: TextAlign.center,
              style: PortalTheme.sans(color: PortalColors.ink3),
            ),
          ),
        ],
      );
    }

    final grouped = <String, List<ReviewerFile>>{};
    for (final f in _reviewers) {
      grouped.putIfAbsent(f.weekGroup, () => []).add(f);
    }
    final sortedWeeks = grouped.keys.toList()
      ..sort((a, b) {
        if (a == 'Other') return 1;
        if (b == 'Other') return -1;
        final na = int.tryParse(a.replaceAll('Week ', '')) ?? 999;
        final nb = int.tryParse(b.replaceAll('Week ', '')) ?? 999;
        return na.compareTo(nb);
      });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader('Reviewers & Study Outlines'),
        Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: sortedWeeks.map((week) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 10),
                    child: Text(
                      week.toUpperCase(),
                      style: PortalTheme.sans(
                        size: 13,
                        weight: FontWeight.w800,
                        color: PortalColors.forest,
                      ),
                    ),
                  ),
                  ...grouped[week]!.map((file) {
                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: const BorderSide(color: PortalColors.ruleMed),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: PortalColors.parchment,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            file.isHtml ? '📺' : '📄',
                            style: const TextStyle(fontSize: 22),
                          ),
                        ),
                        title: Text(
                          file.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: PortalTheme.sans(
                            size: 14,
                            weight: FontWeight.w700,
                            color: PortalColors.forest,
                          ),
                        ),
                        subtitle: Text(
                          file.isHtml
                              ? 'STREAM DECK  •  .TXT STUDY OUTLINE'
                              : '${file.shortTypeLabel} FILE',
                          style: PortalTheme.sans(
                            size: 10.5,
                            weight: FontWeight.w700,
                            color: file.isHtml
                                ? PortalColors.goldDark
                                : PortalColors.ink3,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.chevron_right_rounded,
                          color: PortalColors.goldDark,
                        ),
                        onTap: () => _handleReviewerTap(file),
                      ),
                    );
                  }),
                ],
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Future<void> _handleReviewerTap(ReviewerFile file) async {
    if (!file.isHtml) {
      final uri = Uri.tryParse(file.url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: PortalColors.parchment,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text('📚', style: TextStyle(fontSize: 22)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'STUDY REVIEWER OPTIONS',
                          style: PortalTheme.sans(
                            size: 10,
                            weight: FontWeight.w800,
                            letterSpacing: 1.2,
                            color: PortalColors.goldDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          file.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: PortalTheme.sans(
                            size: 14.5,
                            weight: FontWeight.w800,
                            color: PortalColors.forest,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Option 1: Stream Interactive Presentation Deck
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: PortalColors.forest,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop('stream'),
                child: Row(
                  children: [
                    const Icon(
                      Icons.slideshow_rounded,
                      color: PortalColors.gold,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Stream Interactive Deck',
                            style: PortalTheme.sans(
                              size: 14,
                              weight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'Open the full interactive presentation viewer',
                            style: PortalTheme.sans(
                              size: 11.5,
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 14,
                      color: PortalColors.gold,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),

              // Option 2: Extract & Download Clean .txt Discussion Outline (App-Only!)
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: PortalColors.forest,
                  side: const BorderSide(color: PortalColors.forest, width: 1.6),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: () => Navigator.of(ctx).pop('extract_txt'),
                child: Row(
                  children: [
                    const Icon(
                      Icons.article_outlined,
                      color: PortalColors.forest,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Download .TXT Study Outline',
                            style: PortalTheme.sans(
                              size: 14,
                              weight: FontWeight.w800,
                              color: PortalColors.forest,
                            ),
                          ),
                          Text(
                            'Extracts pure discussion outline only (removes all HTML/code)',
                            style: PortalTheme.sans(
                              size: 11.5,
                              color: PortalColors.ink3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(
                      Icons.download_rounded,
                      size: 18,
                      color: PortalColors.goldDark,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || choice == null) return;

    if (choice == 'stream') {
      Navigator.of(context).push(
        PortalPageRoute(
          builder: (_) => _HtmlDeckStreamerScreen(file: file),
        ),
      );
      return;
    }

    if (choice == 'extract_txt') {
      await _extractAndDownloadReviewerTxt(file);
    }
  }

  Future<void> _extractAndDownloadReviewerTxt(ReviewerFile file) async {
    try {
      final result = await PortalLoadingOverlay.run<
          ({String outlineText, SavedTextFileResult saved})>(
        context,
        message: 'Extracting Study Outline...',
        subtitle: 'Stripping HTML code & formatting discussion notes',
        task: () async {
          final rawHtml = await ApiService.instance.fetchRawHtmlContent(file.id);
          final outlineText = ReviewerOutlineExtractor.extractOutline(
            rawHtml: rawHtml,
            reviewerTitle: file.name,
            subjectName: _dashData?.subjectName ?? _activeSubjectCode,
          );
          final txtFileName = ReviewerOutlineExtractor.buildTxtFileName(file.name);
          final saved = await DeviceBridgeService.instance.saveTextToDownloads(
            fileName: txtFileName,
            content: outlineText,
          );
          return (outlineText: outlineText, saved: saved);
        },
      );

      if (!mounted) return;
      Navigator.of(context).push(
        PortalPageRoute(
          builder: (_) => _ReviewerOutlineReaderScreen(
            reviewerTitle: file.name,
            outlineText: result.outlineText,
            savedResult: result.saved,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to extract study outline: $e')),
      );
    }
  }

  Widget _buildEvaluationTab(SubjectDashboardData data) {
    final eval = data.evaluation;
    Color statusColor = PortalColors.forest;
    if (eval != null) {
      if (eval.status.contains('Exceeds')) {
        statusColor = PortalColors.emerald;
      } else if (eval.status.contains('Developing')) {
        statusColor = PortalColors.goldDark;
      } else if (eval.status.contains('Below Basic')) {
        statusColor = PortalColors.burg;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _moduleHeader('Academic Progression'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              Text(
                'RELATIVE PERFORMANCE STATUS',
                style: PortalTheme.sans(
                  size: 11.5,
                  weight: FontWeight.w800,
                  letterSpacing: 2.0,
                  color: PortalColors.ink3,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                eval?.status ?? 'Not Evaluated',
                textAlign: TextAlign.center,
                style: PortalTheme.serif(size: 34, color: statusColor),
              ),
              const SizedBox(height: 8),
              Text(
                eval?.details ?? 'Insufficient data',
                textAlign: TextAlign.center,
                style: PortalTheme.sans(size: 15, color: PortalColors.ink2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Distraction-free `.txt` Study Outline Reader & Downloader Screen.
class _ReviewerOutlineReaderScreen extends StatefulWidget {
  final String reviewerTitle;
  final String outlineText;
  final SavedTextFileResult savedResult;

  const _ReviewerOutlineReaderScreen({
    required this.reviewerTitle,
    required this.outlineText,
    required this.savedResult,
  });

  @override
  State<_ReviewerOutlineReaderScreen> createState() =>
      _ReviewerOutlineReaderScreenState();
}

class _ReviewerOutlineReaderScreenState
    extends State<_ReviewerOutlineReaderScreen> {
  late SavedTextFileResult _saved = widget.savedResult;
  bool _savingAgain = false;

  Future<void> _saveAgain() async {
    setState(() => _savingAgain = true);
    try {
      final next = await DeviceBridgeService.instance.saveTextToDownloads(
        fileName: _saved.fileName,
        content: widget.outlineText,
      );
      if (!mounted) return;
      setState(() => _saved = next);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('✅ Saved to ${next.displayPath}')),
      );
    } finally {
      if (mounted) setState(() => _savingAgain = false);
    }
  }

  Future<void> _shareTxtFile() async {
    await Share.shareXFiles(
      [XFile(_saved.tempShareFile.path, mimeType: 'text/plain')],
      subject: _saved.fileName,
    );
  }

  Future<void> _copyOutline() async {
    await Clipboard.setData(ClipboardData(text: widget.outlineText));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('📋 Study outline copied to clipboard!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalColors.parchment,
      appBar: AppBar(
        backgroundColor: PortalColors.forest,
        foregroundColor: Colors.white,
        title: Text(
          'Study Outline (.TXT)',
          style: PortalTheme.serif(size: 22, color: Colors.white),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy Outline Text',
            onPressed: _copyOutline,
            icon: const Icon(Icons.copy_rounded, size: 20),
          ),
          IconButton(
            tooltip: 'Share / Open .TXT File',
            onPressed: _shareTxtFile,
            icon: const Icon(Icons.ios_share_rounded, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Saved confirmation banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              color: PortalColors.emeraldBg,
              child: Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    size: 18,
                    color: PortalColors.emerald,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Saved clean discussion outline to ${_saved.displayPath}',
                      style: PortalTheme.sans(
                        size: 12,
                        weight: FontWeight.w700,
                        color: PortalColors.emerald,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Scrollable Plain-Text Discussion Outline
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 720),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: PortalColors.ruleMed),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x141A3A2A),
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: SelectableText(
                        widget.outlineText,
                        style: PortalTheme.sans(
                          size: 13.5,
                          height: 1.55,
                          color: PortalColors.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Bottom Action Bar
            Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: PortalColors.ruleMed)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _savingAgain ? null : _saveAgain,
                      icon: const Icon(Icons.download_done_rounded, size: 18),
                      label: Text(_savingAgain ? 'Saving...' : 'Save .TXT Again'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.forest,
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _shareTxtFile,
                      icon: const Icon(
                        Icons.open_in_new_rounded,
                        size: 17,
                        color: PortalColors.gold,
                      ),
                      label: const Text('Share / Open .TXT'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HtmlDeckStreamerScreen extends StatefulWidget {
  final ReviewerFile file;

  const _HtmlDeckStreamerScreen({required this.file});

  @override
  State<_HtmlDeckStreamerScreen> createState() =>
      _HtmlDeckStreamerScreenState();
}

class _HtmlDeckStreamerScreenState extends State<_HtmlDeckStreamerScreen> {
  WebViewController? _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadHtml();
  }

  Future<void> _loadHtml() async {
    try {
      final rawHtml =
          await ApiService.instance.fetchRawHtmlContent(widget.file.id);
      final ctrl = WebViewController()
        ..setJavaScriptMode(JavaScriptMode.unrestricted)
        ..loadHtmlString(rawHtml);
      if (mounted) {
        setState(() {
          _controller = ctrl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PortalColors.forestDark,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(
          widget.file.name,
          style: PortalTheme.sans(
            size: 14,
            weight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      ),
      body: _loading
          ? const PortalLoadingView(
              message: 'Loading Presentation Deck...',
              subtitle: 'Preparing interactive slides for streaming',
            )
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: PortalTheme.sans(color: Colors.white),
                    ),
                  ),
                )
              : WebViewWidget(controller: _controller!),
    );
  }
}
