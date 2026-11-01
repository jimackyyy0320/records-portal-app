import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../models/portal_models.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../theme/portal_theme.dart';
import '../widgets/common_widgets.dart';
import 'profile_modal.dart';

/// Full Student Dashboard + Faculty Read-Only Student Drill-Down View
/// replicating `#subject-screen`, `#dashboard-screen`, and `#html-streamer`
/// from `index.html`.
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
  bool _loadingReviewers = false;
  String? _facultyViewedAvatar;

  int _selectedTabIndex = 0; // 0: Att, 1: Daily, 2: Majors, 3: Reviewers, 4: Eval
  String _selectedMonth = 'all';
  String _selectedWeek = 'all';

  Timer? _autoRefreshTimer;

  bool get _isFacultyViewing => widget.facultyViewedStudentId != null;

  String get _targetStudentId =>
      widget.facultyViewedStudentId ?? widget.session.id;

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
      await _loadSubjectDashboard(widget.facultyFixedSubjectCode!);
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

  Future<void> _loadSubjectDashboard(String code) async {
    setState(() {
      _loadingSubject = true;
      _activeSubjectCode = code;
      _selectedTabIndex = 0;
      _selectedMonth = 'all';
      _selectedWeek = 'all';
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
        _activeSubjectCode = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading records: $e')),
      );
    }
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Image too large (Max 3MB).')),
        );
        return;
      }
      if (!mounted) return;
      final croppedDataUrl = await showDialog<String>(
        context: context,
        builder: (_) => AvatarCropDialog(imageBytes: bytes),
      );
      if (croppedDataUrl == null) return;

      try {
        final res = await ApiService.instance.uploadStudentAvatar(
          id: widget.session.id,
          dataUrl: croppedDataUrl,
        );
        if (res['success'] == true) {
          final updated =
              widget.session.copyWith(avatarDataUrl: croppedDataUrl);
          await SessionService.instance.saveSession(updated);
          widget.onSessionUpdated(updated);
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
      }
    } else if (action == 'remove') {
      try {
        final res =
            await ApiService.instance.removeStudentAvatar(widget.session.id);
        if (res['success'] == true) {
          final updated = widget.session.copyWith(clearAvatar: true);
          await SessionService.instance.saveSession(updated);
          widget.onSessionUpdated(updated);
        }
      } catch (_) {}
    }
  }

  Future<void> _downloadStudentQr() async {
    try {
      final dataUrl =
          await ApiService.instance.getStudentQRCode(widget.session.id);
      final bytes = decodeDataUrlBytes(dataUrl);
      if (bytes == null) {
        throw const ApiException('Contact your Teacher immediately');
      }
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Student QR Pass', style: PortalTheme.serif(size: 24)),
                const SizedBox(height: 6),
                Text(
                  'ID: ${widget.session.id}',
                  style: PortalTheme.sans(
                    size: 12.5,
                    weight: FontWeight.w700,
                    color: PortalColors.ink3,
                  ),
                ),
                const SizedBox(height: 16),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(bytes, width: 220, height: 220),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Close'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: PortalColors.gold,
                          foregroundColor: PortalColors.forest,
                        ),
                        onPressed: () async {
                          final dir = await getTemporaryDirectory();
                          final file =
                              File('${dir.path}/QR_${widget.session.id}.png');
                          await file.writeAsBytes(bytes);
                          await Share.shareXFiles(
                            [XFile(file.path)],
                            text: 'QR Code - ${widget.session.id}',
                          );
                        },
                        icon: const Icon(Icons.download_rounded, size: 18),
                        label: const Text('Save / Share'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contact your Teacher immediately')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    Widget content;
    if (_loadingSubject) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: PortalColors.forest),
            const SizedBox(height: 14),
            Text(
              'LOADING ACADEMIC RECORDS...',
              style: PortalTheme.sans(
                size: 12,
                weight: FontWeight.w700,
                letterSpacing: 1.6,
                color: PortalColors.forest,
              ),
            ),
          ],
        ),
      );
    } else if (_activeSubjectCode == null || _dashData == null) {
      content = _buildSubjectSelectionView();
    } else {
      content = _buildSubjectDashboardView(_dashData!);
    }

    final bodyWithSchedule = _isFacultyViewing
        ? content
        : StudentScheduleOverlay(
            schedule: widget.session.schedule,
            child: content,
          );

    return ParchmentScaffold(
      topBanner: widget.announcements.isNotEmpty
          ? AnnouncementMarqueeBanner(announcements: widget.announcements)
          : null,
      floatingActionButton: _isFacultyViewing
          ? null
          : FloatingActionButton(
              tooltip: 'Logout',
              backgroundColor: PortalColors.burg,
              foregroundColor: Colors.white,
              onPressed: widget.onLogout,
              child: const Icon(Icons.logout_rounded),
            ),
      child: bodyWithSchedule,
    );
  }

  Widget _buildSubjectSelectionView() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 90),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            children: [
              const PortalHeader(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 34,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: PortalColors.rule),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x1F1A3A2A),
                      blurRadius: 24,
                      offset: Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      'Select Subject',
                      style: PortalTheme.serif(size: 26, italic: true),
                    ),
                    const SizedBox(height: 8),
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: PortalTheme.sans(
                          size: 13.5,
                          weight: FontWeight.w600,
                          color: PortalColors.ink3,
                        ),
                        children: [
                          const TextSpan(text: 'Welcome back, '),
                          TextSpan(
                            text: widget.session.name,
                            style: PortalTheme.sans(
                              size: 13.5,
                              weight: FontWeight.w800,
                              color: PortalColors.forest,
                            ),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      alignment: WrapAlignment.center,
                      children: widget.session.subjects.map((subj) {
                        return ActionChip(
                          backgroundColor: PortalColors.parchment,
                          side: const BorderSide(
                            color: PortalColors.ruleMed,
                            width: 1.8,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(50),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          label: Text(
                            subj.code.toUpperCase(),
                            style: PortalTheme.sans(
                              size: 13,
                              weight: FontWeight.w800,
                              letterSpacing: 1.5,
                              color: PortalColors.forest,
                            ),
                          ),
                          onPressed: () => _loadSubjectDashboard(subj.code),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
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

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 95),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 660),
          child: Column(
            children: [
              PortalHeader(compact: _isFacultyViewing),
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
                          height: _isFacultyViewing ? 68 : 112,
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
                          bottom: _isFacultyViewing ? -30 : -46,
                          child: GestureDetector(
                            onTap: _isFacultyViewing ? null : _openAvatarMenu,
                            child: Container(
                              padding: const EdgeInsets.all(5),
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
                                radius: _isFacultyViewing ? 30 : 46,
                                backgroundColor: PortalColors.parchmentDk,
                                backgroundImage: avatarBytes != null
                                    ? MemoryImage(avatarBytes)
                                    : null,
                                child: avatarBytes == null
                                    ? Text(
                                        '👤',
                                        style: TextStyle(
                                          fontSize:
                                              _isFacultyViewing ? 22 : 34,
                                        ),
                                      )
                                    : null,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: _isFacultyViewing ? 38 : 54),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text(
                        greeting,
                        textAlign: TextAlign.center,
                        style: PortalTheme.serif(
                          size: _isFacultyViewing ? 22 : 28,
                          italic: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Container(
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
                          weight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: PortalColors.ink2,
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
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PortalColors.forest,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () {
                              showDialog<void>(
                                context: context,
                                builder: (_) => StudentProfileSheet(
                                  studentId: widget.session.id,
                                  initialProfile: widget.session.profile,
                                  mandatoryCompletion: false,
                                  onProfileSaved: (updatedProfile) async {
                                    final next = widget.session
                                        .copyWith(profile: updatedProfile);
                                    await SessionService.instance
                                        .saveSession(next);
                                    widget.onSessionUpdated(next);
                                  },
                                ),
                              );
                            },
                            child: Text(
                              'VIEW PROFILE',
                              style: PortalTheme.sans(
                                size: 11,
                                weight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: PortalColors.gold,
                              foregroundColor: PortalColors.forest,
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: _downloadStudentQr,
                            child: Text(
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
              const SizedBox(height: 18),

              // Module Tab Navigation (.tab-nav)
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: PortalColors.forestFaint,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: tabs.map((t) {
                    final active = _selectedTabIndex == t.$2;
                    return InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => setState(() => _selectedTabIndex = t.$2),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 13,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: active
                              ? PortalColors.forest
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
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
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 18),

              // Active Module Card (.module-container)
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
                child: _buildActiveModuleContent(data),
              ),

              const SizedBox(height: 18),
              if (_isFacultyViewing && widget.onFacultyBackToRoster != null)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: widget.onFacultyBackToRoster,
                    child: const Text('← Back to Roster'),
                  ),
                )
              else if (widget.session.subjects.length > 1)
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () {
                      _autoRefreshTimer?.cancel();
                      setState(() {
                        _activeSubjectCode = null;
                        _dashData = null;
                      });
                    },
                    child: const Text('← Back to Subjects'),
                  ),
                ),
            ],
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
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Activity is not yet available',
                                  ),
                                ),
                              );
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
          const Padding(
            padding: EdgeInsets.all(36),
            child: CircularProgressIndicator(color: PortalColors.forest),
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
        _moduleHeader('Reviewers'),
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
                          '${file.shortTypeLabel} FILE',
                          style: PortalTheme.sans(
                            size: 11,
                            weight: FontWeight.w600,
                            color: PortalColors.ink3,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                file.name,
                textAlign: TextAlign.center,
                style: PortalTheme.sans(
                  size: 15,
                  weight: FontWeight.w800,
                  color: PortalColors.forest,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: PortalColors.forest,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.of(ctx).pop('view'),
                      icon: const Icon(Icons.slideshow_rounded),
                      label: const Text('Stream Deck'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.of(ctx).pop('download'),
                      icon: const Icon(Icons.download_rounded),
                      label: const Text('Download HTML'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    if (choice == 'download') {
      final uri = Uri.tryParse(file.url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } else if (choice == 'view') {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => _HtmlDeckStreamerScreen(file: file),
        ),
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
      backgroundColor: Colors.black,
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
          ? const Center(
              child: CircularProgressIndicator(color: PortalColors.gold),
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
