import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/portal_models.dart';
import '../services/api_service.dart';

/// Selectable pixel-style badge presets for Teacher "+ Post an Activity" & Student Achievements.
class LobbyBadgePreset {
  final String icon;
  final String defaultTitle;
  final int accentColor;

  const LobbyBadgePreset({
    required this.icon,
    required this.defaultTitle,
    required this.accentColor,
  });
}

const List<LobbyBadgePreset> kLobbyBadgePresets = [
  LobbyBadgePreset(
    icon: '🛡️',
    defaultTitle: 'Policy Vanguard',
    accentColor: 0xFF38BDF8,
  ),
  LobbyBadgePreset(
    icon: '👑',
    defaultTitle: 'Quiz Conqueror',
    accentColor: 0xFFFACC15,
  ),
  LobbyBadgePreset(
    icon: '🦉',
    defaultTitle: 'Philo Sage',
    accentColor: 0xFFA855F7,
  ),
  LobbyBadgePreset(
    icon: '🏛️',
    defaultTitle: 'Social Scientist',
    accentColor: 0xFF10B981,
  ),
  LobbyBadgePreset(
    icon: '📜',
    defaultTitle: 'Kasaysayan Keeper',
    accentColor: 0xFFF97316,
  ),
  LobbyBadgePreset(
    icon: '⚡',
    defaultTitle: 'Honor Scholar',
    accentColor: 0xFFEC4899,
  ),
  LobbyBadgePreset(
    icon: '🔥',
    defaultTitle: 'Streak Master',
    accentColor: 0xFFEF4444,
  ),
  LobbyBadgePreset(
    icon: '💎',
    defaultTitle: 'Vault Explorer',
    accentColor: 0xFF06B6D4,
  ),
];

/// MIS Control Sheet (`1pH1eYliOI5R4gU--AwOmE3fYDbRkRewzIEE5noMOM9A`)
/// Tab: `Subject Enrollment`
/// - Column A: Subject Name
/// - Column B: Subject Code
/// - Column C: Sheet ID
/// - Column D: Status (`Finished` = Do NOT include reviewers in the game; `Active` = Included)
const List<SubjectEnrollmentStatus> kDefaultSubjectEnrollmentCatalog = [
  SubjectEnrollmentStatus(
    name: 'Philippine Governance and Politics',
    code: 'PGP',
    sheetId: '1hTTlEMCbZo_Ff2C3w-ZyCxdLG-KOZpgTCNdnm03rOZ0',
    status: 'Active',
  ),
  SubjectEnrollmentStatus(
    name: 'Understanding Culture, Society and Politics',
    code: 'UCSP',
    sheetId: '1EFX9aylAeSRmDWU7OeFIPa0llAMD8wC5_UCSP',
    status: 'Active',
  ),
  SubjectEnrollmentStatus(
    name: 'Philippine Politics and Governance',
    code: 'PPG',
    sheetId: '1hTTlEMCbZo_Ff2C3w-ZyCxdLG-KOZpgTCNdnm03rOZ0',
    status: 'Active',
  ),
  SubjectEnrollmentStatus(
    name: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino (Term 2)',
    code: 'PKLP TERM 2',
    sheetId: '159RZLsZOB2miwF3uLd-N7p9HD6pYqA3VvoHrFuqi4TI_T2',
    status: 'Active',
  ),
  SubjectEnrollmentStatus(
    name: 'Introduction to Philosophy of Human Person',
    code: 'PHILO',
    sheetId: '1PPfA1h9PHxQgiBoozKBUdQLD8AuyobBQy-jGXUExfYs',
    status: 'Active',
  ),
  SubjectEnrollmentStatus(
    name: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino (Term 1)',
    code: 'PKLP',
    sheetId: '159RZLsZOB2miwF3uLd-N7p9HD6pYqA3VvoHrFuqi4TI',
    status: 'Finished',
  ),
];

/// Thought Bubble message item for in-lobby classmate communication (`💭`).
class LobbyThoughtMessage {
  final String id;
  final String senderName;
  final String senderRole;
  final String roomName;
  final String text;
  final int timestampMs;
  final bool isFromPeer;

  const LobbyThoughtMessage({
    required this.id,
    required this.senderName,
    required this.senderRole,
    required this.roomName,
    required this.text,
    required this.timestampMs,
    this.isFromPeer = false,
  });
}

/// Feature 1: Quest Counter Activity posted by a Teacher & completable by Students.
class LobbyQuestActivity {
  final String id;
  final String title;
  final String subject;
  final String activityUrl;
  final int xpReward;
  final String badgeName;
  final String badgeIcon;
  final int badgeColor;
  final String postedBy;
  final int createdAtMs;

  const LobbyQuestActivity({
    required this.id,
    required this.title,
    required this.subject,
    required this.activityUrl,
    required this.xpReward,
    required this.badgeName,
    required this.badgeIcon,
    required this.badgeColor,
    required this.postedBy,
    required this.createdAtMs,
  });

  factory LobbyQuestActivity.fromJson(Map<String, dynamic> json) {
    return LobbyQuestActivity(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'UCSP',
      activityUrl: json['activityUrl']?.toString() ?? '',
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 100,
      badgeName: json['badgeName']?.toString() ?? 'Quest Explorer',
      badgeIcon: json['badgeIcon']?.toString() ?? '🛡️',
      badgeColor: (json['badgeColor'] as num?)?.toInt() ?? 0xFF38BDF8,
      postedBy: json['postedBy']?.toString() ?? 'Faculty',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'activityUrl': activityUrl,
        'xpReward': xpReward,
        'badgeName': badgeName,
        'badgeIcon': badgeIcon,
        'badgeColor': badgeColor,
        'postedBy': postedBy,
        'createdAtMs': createdAtMs,
      };
}

/// Earned badge stored in a student's RPG profile.
class EarnedStudentBadge {
  final String id;
  final String badgeName;
  final String badgeIcon;
  final int badgeColor;
  final String subject;
  final String sourceTitle;
  final int earnedAtMs;

  const EarnedStudentBadge({
    required this.id,
    required this.badgeName,
    required this.badgeIcon,
    required this.badgeColor,
    required this.subject,
    required this.sourceTitle,
    required this.earnedAtMs,
  });

  factory EarnedStudentBadge.fromJson(Map<String, dynamic> json) {
    return EarnedStudentBadge(
      id: json['id']?.toString() ?? '',
      badgeName: json['badgeName']?.toString() ?? '',
      badgeIcon: json['badgeIcon']?.toString() ?? '🛡️',
      badgeColor: (json['badgeColor'] as num?)?.toInt() ?? 0xFF38BDF8,
      subject: json['subject']?.toString() ?? '',
      sourceTitle: json['sourceTitle']?.toString() ?? '',
      earnedAtMs: (json['earnedAtMs'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'badgeName': badgeName,
        'badgeIcon': badgeIcon,
        'badgeColor': badgeColor,
        'subject': subject,
        'sourceTitle': sourceTitle,
        'earnedAtMs': earnedAtMs,
      };
}

/// Feature 2: Reviewer Item inside a Subject-Labeled Large Treasure Chest.
/// Supports both Google Drive Reviewer files (`REVIEWER_FOLDER_ID = 1EFX9aylAeSRmDWU7OeFIPa0llAMD8wC5`)
/// and Teacher-uploaded / built-in study notes.
class LobbyReviewerItem {
  final String id;
  final String title;
  final String subject;
  final String fileType; // 'HTML' | 'PDF' | 'PPTX' | 'LINK' | 'NOTES'
  final String urlOrContent;
  final String summary;
  final String uploadedBy;
  final int createdAtMs;
  final String? driveFileId;
  final String? mimeType;
  final String? weekGroup;

  const LobbyReviewerItem({
    required this.id,
    required this.title,
    required this.subject,
    required this.fileType,
    required this.urlOrContent,
    required this.summary,
    required this.uploadedBy,
    required this.createdAtMs,
    this.driveFileId,
    this.mimeType,
    this.weekGroup,
  });

  bool get isFromDrive => driveFileId != null && driveFileId!.trim().isNotEmpty;

  bool get isHtmlReviewer {
    final lowerTitle = title.toLowerCase();
    final lowerMime = (mimeType ?? '').toLowerCase();
    final upperType = fileType.toUpperCase();
    return upperType == 'HTML' ||
        upperType == 'HTM' ||
        lowerTitle.endsWith('.html') ||
        lowerTitle.endsWith('.htm') ||
        lowerMime.contains('html');
  }

  factory LobbyReviewerItem.fromJson(Map<String, dynamic> json) {
    return LobbyReviewerItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      fileType: json['fileType']?.toString() ?? 'NOTES',
      urlOrContent: json['urlOrContent']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      uploadedBy: json['uploadedBy']?.toString() ?? 'Teacher',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      driveFileId: json['driveFileId']?.toString(),
      mimeType: json['mimeType']?.toString(),
      weekGroup: json['weekGroup']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'fileType': fileType,
        'urlOrContent': urlOrContent,
        'summary': summary,
        'uploadedBy': uploadedBy,
        'createdAtMs': createdAtMs,
        if (driveFileId != null) 'driveFileId': driveFileId,
        if (mimeType != null) 'mimeType': mimeType,
        if (weekGroup != null) 'weekGroup': weekGroup,
      };
}

/// Feature 2: Subject-Labeled Large Treasure Chest (Reviewer Vault).
class SubjectChest {
  final String id;
  final String subjectName; // Subject Code e.g. 'PGP', 'UCSP', 'PPG', 'PKLP TERM 2', 'PHILO'
  final String fullTitle; // Full Subject Name from MIS Control Sheet Column A
  final int colorValue;
  final List<LobbyReviewerItem> reviewers;

  const SubjectChest({
    required this.id,
    required this.subjectName,
    this.fullTitle = '',
    required this.colorValue,
    required this.reviewers,
  });

  SubjectChest copyWith({
    String? subjectName,
    String? fullTitle,
    int? colorValue,
    List<LobbyReviewerItem>? reviewers,
  }) {
    return SubjectChest(
      id: id,
      subjectName: subjectName ?? this.subjectName,
      fullTitle: fullTitle ?? this.fullTitle,
      colorValue: colorValue ?? this.colorValue,
      reviewers: reviewers ?? this.reviewers,
    );
  }

  factory SubjectChest.fromJson(Map<String, dynamic> json) {
    final revs = (json['reviewers'] as List?)
            ?.whereType<Map>()
            .map(
              (e) => LobbyReviewerItem.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList() ??
        const <LobbyReviewerItem>[];
    return SubjectChest(
      id: json['id']?.toString() ?? '',
      subjectName: json['subjectName']?.toString() ?? 'SUBJECT',
      fullTitle: json['fullTitle']?.toString() ?? '',
      colorValue: (json['colorValue'] as num?)?.toInt() ?? 0xFF38BDF8,
      reviewers: revs,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectName': subjectName,
        'fullTitle': fullTitle,
        'colorValue': colorValue,
        'reviewers': reviewers.map((r) => r.toJson()).toList(),
      };
}

/// Feature 3: Multiple-Choice Pop-Quiz Question inside Small Mystery Chests.
class MiniQuizQuestion {
  final String id;
  final String subject;
  final String question;
  final List<String> options; // 4 options (A, B, C, D)
  final int correctIndex; // 0..3
  final int xpReward;

  const MiniQuizQuestion({
    required this.id,
    required this.subject,
    required this.question,
    required this.options,
    required this.correctIndex,
    this.xpReward = 25,
  });

  factory MiniQuizQuestion.fromJson(Map<String, dynamic> json) {
    final opts = (json['options'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const ['A', 'B', 'C', 'D'];
    return MiniQuizQuestion(
      id: json['id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? 'GENERAL',
      question: json['question']?.toString() ?? '',
      options: opts.length >= 4 ? opts.sublist(0, 4) : ['A', 'B', 'C', 'D'],
      correctIndex:
          ((json['correctIndex'] as num?)?.toInt() ?? 0).clamp(0, 3),
      xpReward: (json['xpReward'] as num?)?.toInt() ?? 25,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'subject': subject,
        'question': question,
        'options': options,
        'correctIndex': correctIndex,
        'xpReward': xpReward,
      };
}

/// Per-student RPG state (XP, Level, Launched/Completed Activities, Earned Badges, Equipped Badge, Cooldowns).
class StudentLobbyProgress {
  final int xp;
  final Set<String> launchedActivityIds;
  final Set<String> completedActivityIds;
  final List<EarnedStudentBadge> earnedBadges;
  final String? equippedBadgeId;
  final Map<String, int> smallChestCooldownUntilMs;

  const StudentLobbyProgress({
    this.xp = 0,
    this.launchedActivityIds = const {},
    this.completedActivityIds = const {},
    this.earnedBadges = const [],
    this.equippedBadgeId,
    this.smallChestCooldownUntilMs = const {},
  });

  int get level => (xp ~/ 100) + 1;
  int get currentLevelXp => xp % 100;

  EarnedStudentBadge? get equippedBadge {
    if (earnedBadges.isEmpty) return null;
    if (equippedBadgeId != null) {
      for (final b in earnedBadges) {
        if (b.id == equippedBadgeId) return b;
      }
    }
    return earnedBadges.first;
  }

  StudentLobbyProgress copyWith({
    int? xp,
    Set<String>? launchedActivityIds,
    Set<String>? completedActivityIds,
    List<EarnedStudentBadge>? earnedBadges,
    String? equippedBadgeId,
    Map<String, int>? smallChestCooldownUntilMs,
  }) {
    return StudentLobbyProgress(
      xp: xp ?? this.xp,
      launchedActivityIds: launchedActivityIds ?? this.launchedActivityIds,
      completedActivityIds: completedActivityIds ?? this.completedActivityIds,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      equippedBadgeId: equippedBadgeId ?? this.equippedBadgeId,
      smallChestCooldownUntilMs:
          smallChestCooldownUntilMs ?? this.smallChestCooldownUntilMs,
    );
  }

  factory StudentLobbyProgress.fromJson(Map<String, dynamic> json) {
    final launched = (json['launchedActivityIds'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};
    final completed = (json['completedActivityIds'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};
    final badges = (json['earnedBadges'] as List?)
            ?.whereType<Map>()
            .map(
              (e) => EarnedStudentBadge.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList() ??
        <EarnedStudentBadge>[];
    final rawCooldowns = json['smallChestCooldownUntilMs'];
    final cooldowns = <String, int>{};
    if (rawCooldowns is Map) {
      rawCooldowns.forEach((k, v) {
        if (v is num) cooldowns[k.toString()] = v.toInt();
      });
    }
    return StudentLobbyProgress(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      launchedActivityIds: launched,
      completedActivityIds: completed,
      earnedBadges: badges,
      equippedBadgeId: json['equippedBadgeId']?.toString(),
      smallChestCooldownUntilMs: cooldowns,
    );
  }

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'launchedActivityIds': launchedActivityIds.toList(),
        'completedActivityIds': completedActivityIds.toList(),
        'earnedBadges': earnedBadges.map((b) => b.toJson()).toList(),
        'equippedBadgeId': equippedBadgeId,
        'smallChestCooldownUntilMs': smallChestCooldownUntilMs,
      };
}

/// Central reactive service managing:
/// - MIS Control Sheet (`Subject Enrollment`) active vs. finished subject filtering
/// - Strict Student Enrollment filtering for Subject Chests, Quest Activities, Reviewers & Quizzes
/// - Real Google Drive Reviewer Folder (`1EFX9aylAeSRmDWU7OeFIPa0llAMD8wC5`) synchronization
/// - Thought Bubble Chat history & peer replies
class LobbyDataService extends ChangeNotifier {
  LobbyDataService._();
  static final LobbyDataService instance = LobbyDataService._();

  static const String _kActivitiesKey = 'mis_school_lobby_activities_v2';
  static const String _kSubjectChestsKey = 'mis_school_lobby_subject_chests_v3';
  static const String _kQuizQuestionsKey = 'mis_school_lobby_quiz_questions_v2';
  static const String _kProgressPrefix = 'mis_school_lobby_progress_v1_';

  static const int kSmallChestCooldownMs = 120 * 1000; // 2 minutes

  String _activeUserId = 'guest';
  bool _initialized = false;
  bool _isFaculty = false;
  bool _filterByStudentEnrollment = false;
  bool _isSyncingDriveReviewers = false;

  List<SubjectEnrollmentStatus> _controlSheetSubjects =
      List<SubjectEnrollmentStatus>.from(kDefaultSubjectEnrollmentCatalog);
  Set<String> _studentEnrolledCodes = <String>{};

  List<LobbyQuestActivity> _activities = [];
  List<SubjectChest> _subjectChests = [];
  List<MiniQuizQuestion> _quizQuestions = [];
  StudentLobbyProgress _progress = const StudentLobbyProgress();
  final List<LobbyThoughtMessage> _thoughtMessages = [];

  bool get isSyncingDriveReviewers => _isSyncingDriveReviewers;
  List<SubjectEnrollmentStatus> get controlSheetSubjects =>
      List.unmodifiable(_controlSheetSubjects);
  Set<String> get studentEnrolledCodes =>
      Set.unmodifiable(_studentEnrolledCodes);
  StudentLobbyProgress get progress => _progress;
  List<LobbyThoughtMessage> get thoughtMessages =>
      List.unmodifiable(_thoughtMessages);

  /// Normalizes a subject code or alias to match the MIS Control Sheet `Subject Enrollment` codes.
  static String normalizeSubjectCode(String rawCode, [String rawName = '']) {
    final upper = rawCode.trim().toUpperCase();
    if (upper == 'KASAYSAYAN') return 'PKLP TERM 2';
    if (upper.isNotEmpty) return upper;
    final upperName = rawName.trim().toUpperCase();
    if (upperName.contains('GOVERNANCE') && upperName.contains('POLITICS')) {
      return 'PGP';
    }
    if (upperName.contains('CULTURE') || upperName.contains('UCSP')) {
      return 'UCSP';
    }
    if (upperName.contains('PHILOSOPHY') || upperName.contains('PHILO')) {
      return 'PHILO';
    }
    if (upperName.contains('TERM 2')) return 'PKLP TERM 2';
    if (upperName.contains('KASAYSAYAN') || upperName.contains('LIPUNANG')) {
      return 'PKLP';
    }
    return upper;
  }

  /// Checks whether a subject code is `Active` (and NOT `Finished` or `Inactive`)
  /// in the MIS Control Sheet (`Subject Enrollment` Column D).
  bool isSubjectActiveInControlSheet(String rawCode) {
    final code = normalizeSubjectCode(rawCode);
    if (code.isEmpty) return false;
    // PKLP (Term 1) is Finished in the MIS Control Sheet; PKLP TERM 2 is Active.
    if (code == 'PKLP') {
      for (final item in _controlSheetSubjects) {
        if (item.code.trim().toUpperCase() == 'PKLP') {
          return item.isActive;
        }
      }
      return false;
    }
    for (final item in _controlSheetSubjects) {
      if (normalizeSubjectCode(item.code, item.name) == code) {
        return item.isActive;
      }
    }
    // Custom teacher-added subject chests default to active unless explicitly marked Finished
    return true;
  }

  /// Checks whether a subject is visible to the currently logged-in user:
  /// 1. Must be `Active` in the MIS Control Sheet (`Status != Finished`).
  /// 2. If the user is a Student (`!_isFaculty`) and enrollment filtering is active,
  ///    the student must be enrolled in that subject (`_studentEnrolledCodes`).
  bool isSubjectVisibleForCurrentUser(String rawCode) {
    final code = normalizeSubjectCode(rawCode);
    if (!isSubjectActiveInControlSheet(code)) {
      return false;
    }
    if (!_filterByStudentEnrollment || _isFaculty) {
      return true;
    }
    return _studentEnrolledCodes.contains(code);
  }

  /// Filtered list of Quest Counter Activities:
  /// Students only see tasks for the active subjects they are enrolled in!
  List<LobbyQuestActivity> get activities => List.unmodifiable(
        _activities.where((a) => isSubjectVisibleForCurrentUser(a.subject)),
      );

  /// Unfiltered activities list (for internal persistence).
  List<LobbyQuestActivity> get allActivitiesUnfiltered =>
      List.unmodifiable(_activities);

  /// Filtered list of Subject-Labeled Large Treasure Chests:
  /// Excludes `Finished` subjects from the MIS Control Sheet and restricts students
  /// strictly to the subjects they are enrolled in!
  List<SubjectChest> get subjectChests => List.unmodifiable(
        _subjectChests
            .where((c) => isSubjectVisibleForCurrentUser(c.subjectName)),
      );

  /// Filtered list of Pop-Quiz Questions for enrolled active subjects.
  List<MiniQuizQuestion> get quizQuestions => List.unmodifiable(
        _quizQuestions.where((q) => isSubjectVisibleForCurrentUser(q.subject)),
      );

  Future<void> init(String userId, {UserSession? session}) async {
    final cleanId = userId.trim().isEmpty ? 'guest' : userId.trim();
    if (_initialized && _activeUserId == cleanId && session == null) return;
    _activeUserId = cleanId;

    final prefs = await SharedPreferences.getInstance();

    // 1. Load or seed Subject Chests aligned with MIS Control Sheet `Subject Enrollment`
    final rawChests = prefs.getString(_kSubjectChestsKey);
    if (rawChests != null && rawChests.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawChests) as List;
        _subjectChests = decoded
            .whereType<Map>()
            .map((e) => SubjectChest.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        _subjectChests = _defaultSubjectChests();
      }
    } else {
      _subjectChests = _defaultSubjectChests();
      await _saveSubjectChests(prefs);
    }

    // Ensure all active default subjects exist in `_subjectChests`
    for (final defChest in _defaultSubjectChests()) {
      final exists = _subjectChests.any(
        (c) =>
            normalizeSubjectCode(c.subjectName) ==
            normalizeSubjectCode(defChest.subjectName),
      );
      if (!exists) {
        _subjectChests.add(defChest);
      }
    }

    // 2. Load or seed Quest Counter Activities
    final rawActivities = prefs.getString(_kActivitiesKey);
    if (rawActivities != null && rawActivities.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawActivities) as List;
        _activities = decoded
            .whereType<Map>()
            .map(
              (e) => LobbyQuestActivity.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
      } catch (_) {
        _activities = _defaultActivities();
      }
    } else {
      _activities = _defaultActivities();
      await _saveActivities(prefs);
    }

    // 3. Load or seed Mini Quiz Questions
    final rawQuestions = prefs.getString(_kQuizQuestionsKey);
    if (rawQuestions != null && rawQuestions.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawQuestions) as List;
        _quizQuestions = decoded
            .whereType<Map>()
            .map((e) => MiniQuizQuestion.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        _quizQuestions = _defaultQuizQuestions();
      }
    } else {
      _quizQuestions = _defaultQuizQuestions();
      await _saveQuizQuestions(prefs);
    }

    // 4. Load per-student progress
    final rawProgress = prefs.getString('$_kProgressPrefix$_activeUserId');
    if (rawProgress != null && rawProgress.isNotEmpty) {
      try {
        _progress = StudentLobbyProgress.fromJson(
          Map<String, dynamic>.from(jsonDecode(rawProgress) as Map),
        );
      } catch (_) {
        _progress = const StudentLobbyProgress();
      }
    } else {
      _progress = const StudentLobbyProgress();
    }

    // 5. Apply session enrollment filter if provided
    if (session != null) {
      applyUserEnrollmentFilter(
        isFaculty: session.isFaculty,
        enrolledSubjects: session.subjects,
      );
    } else {
      _isFaculty = false;
      _filterByStudentEnrollment = false;
    }

    _initialized = true;
    notifyListeners();
  }

  /// Applies the MIS Control Sheet (`Subject Enrollment`) active status rules
  /// and restricts students strictly to the subjects they are enrolled in (`enrolledSubjects`).
  void applyUserEnrollmentFilter({
    required bool isFaculty,
    required List<SubjectItem> enrolledSubjects,
    List<SubjectEnrollmentStatus>? controlSheetOverrides,
  }) {
    _isFaculty = isFaculty;
    if (controlSheetOverrides != null && controlSheetOverrides.isNotEmpty) {
      _controlSheetSubjects =
          List<SubjectEnrollmentStatus>.from(controlSheetOverrides);
      // Ensure PKLP Term 1 remains marked Finished if not explicitly overridden
      final hasPklp = _controlSheetSubjects
          .any((s) => s.code.trim().toUpperCase() == 'PKLP');
      if (!hasPklp) {
        _controlSheetSubjects.add(
          const SubjectEnrollmentStatus(
            name: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino (Term 1)',
            code: 'PKLP',
            sheetId: '159RZLsZOB2miwF3uLd-N7p9HD6pYqA3VvoHrFuqi4TI',
            status: 'Finished',
          ),
        );
      }
    }

    if (isFaculty) {
      _filterByStudentEnrollment = false;
      _studentEnrolledCodes = _controlSheetSubjects
          .where((s) => s.isActive)
          .map((s) => normalizeSubjectCode(s.code, s.name))
          .toSet();
    } else {
      _filterByStudentEnrollment = true;
      final codes = <String>{};
      for (final subj in enrolledSubjects) {
        final norm = normalizeSubjectCode(subj.code, subj.name);
        if (norm.isNotEmpty && isSubjectActiveInControlSheet(norm)) {
          codes.add(norm);
        }
      }
      _studentEnrolledCodes = codes;
    }
    notifyListeners();
  }

  /// Synchronizes the MIS Control Sheet status (`getSystemStatus`) and fetches live
  /// Google Drive Reviewer files (`REVIEWER_FOLDER_ID = 1EFX9aylAeSRmDWU7OeFIPa0llAMD8wC5`)
  /// for each active subject the student is enrolled in!
  Future<void> syncDriveReviewersForSession(UserSession session) async {
    applyUserEnrollmentFilter(
      isFaculty: session.isFaculty,
      enrolledSubjects: session.subjects,
    );

    if (_isSyncingDriveReviewers) return;
    _isSyncingDriveReviewers = true;
    notifyListeners();

    try {
      // 1. Check live MIS Control Sheet system status if online
      try {
        final sysStatus = await ApiService.instance.getSystemStatus();
        if (sysStatus.subjectEnrollments.isNotEmpty) {
          applyUserEnrollmentFilter(
            isFaculty: session.isFaculty,
            enrolledSubjects: session.subjects,
            controlSheetOverrides: sysStatus.subjectEnrollments,
          );
        }
      } catch (_) {
        // Offline or unreachable; keep default MIS Control Sheet catalog
      }

      // 2. Ensure every enrolled active subject has a SubjectChest ready
      var chestsChanged = false;
      final targetCodes = session.isFaculty
          ? _controlSheetSubjects
              .where((s) => s.isActive)
              .map((s) => normalizeSubjectCode(s.code, s.name))
              .toSet()
          : _studentEnrolledCodes;

      for (final code in targetCodes) {
        if (!isSubjectActiveInControlSheet(code)) continue;
        final existingIdx = _subjectChests.indexWhere(
          (c) => normalizeSubjectCode(c.subjectName) == code,
        );
        if (existingIdx < 0) {
          final meta = _controlSheetSubjects.firstWhere(
            (s) => normalizeSubjectCode(s.code, s.name) == code,
            orElse: () => SubjectEnrollmentStatus(
              name: code,
              code: code,
              sheetId: '',
              status: 'Active',
            ),
          );
          _subjectChests.add(
            SubjectChest(
              id: 'chest_${code.toLowerCase().replaceAll(' ', '_')}',
              subjectName: code,
              fullTitle: meta.name,
              colorValue: _colorForSubjectCode(code),
              reviewers: const [],
            ),
          );
          chestsChanged = true;
        }
      }

      // 3. Fetch live Google Drive reviewer files (`fetchReviewerFiles`) per active visible chest
      final visibleChests = List<SubjectChest>.from(subjectChests);
      for (final chest in visibleChests) {
        final code = normalizeSubjectCode(chest.subjectName);
        if (!isSubjectActiveInControlSheet(code)) continue;
        try {
          final driveFiles = await ApiService.instance.fetchReviewerFiles(code);
          if (driveFiles.isNotEmpty) {
            MergeResult merged = _mergeDriveFilesIntoChest(chest, driveFiles);
            if (merged.changed) {
              final idx = _subjectChests.indexWhere((c) => c.id == chest.id);
              if (idx >= 0) {
                _subjectChests[idx] = merged.chest;
                chestsChanged = true;
                notifyListeners();
              }
            }
          }
        } catch (_) {
          // Keep cached/built-in reviewers if offline
        }
      }

      if (chestsChanged) {
        final prefs = await SharedPreferences.getInstance();
        await _saveSubjectChests(prefs);
      }
    } finally {
      _isSyncingDriveReviewers = false;
      notifyListeners();
    }
  }

  MergeResult _mergeDriveFilesIntoChest(
    SubjectChest chest,
    List<ReviewerFile> driveFiles,
  ) {
    final driveItems = driveFiles.map((f) {
      final isHtml = f.isHtml;
      final lowerName = f.name.toLowerCase();
      final fType = isHtml
          ? 'HTML'
          : (lowerName.endsWith('.pptx') || lowerName.endsWith('.ppt')
              ? 'PPTX'
              : (lowerName.endsWith('.pdf') ? 'PDF' : f.shortTypeLabel));
      return LobbyReviewerItem(
        id: 'drive_${f.id}',
        title: f.name,
        subject: chest.subjectName,
        fileType: fType,
        urlOrContent: f.url,
        summary: isHtml
            ? 'Official MIS-SHS Interactive HTML Reviewer (${f.weekGroup}) from Google Drive. Tap to stream slides or extract a .TXT study outline.'
            : 'Official MIS-SHS ${fType.toUpperCase()} Reviewer (${f.weekGroup}) from Google Drive.',
        uploadedBy: 'MIS-SHS Reviewer Vault',
        createdAtMs: 1710000000000,
        driveFileId: f.id,
        mimeType: f.mimeType,
        weekGroup: f.weekGroup,
      );
    }).toList();

    // Keep any non-drive (custom teacher or offline summary) reviewers
    final nonDriveItems =
        chest.reviewers.where((r) => !r.id.startsWith('drive_')).toList();
    final combined = <LobbyReviewerItem>[...driveItems, ...nonDriveItems];

    return MergeResult(
      chest: chest.copyWith(reviewers: combined),
      changed: true,
    );
  }

  static int _colorForSubjectCode(String code) {
    switch (normalizeSubjectCode(code)) {
      case 'PGP':
        return 0xFF38BDF8;
      case 'UCSP':
        return 0xFF10B981;
      case 'PPG':
        return 0xFFF59E0B;
      case 'PKLP TERM 2':
        return 0xFFF97316;
      case 'PHILO':
        return 0xFFA855F7;
      default:
        return 0xFFEC4899;
    }
  }

  /// Adds a Thought Bubble message (`💭`) to the room log and notifies listeners.
  void recordThoughtBubble({
    required String senderName,
    required String senderRole,
    required String roomName,
    required String text,
    bool isFromPeer = false,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    _thoughtMessages.insert(
      0,
      LobbyThoughtMessage(
        id: 'thought_${DateTime.now().microsecondsSinceEpoch}',
        senderName: senderName,
        senderRole: senderRole,
        roomName: roomName,
        text: clean,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
        isFromPeer: isFromPeer,
      ),
    );
    if (_thoughtMessages.length > 30) {
      _thoughtMessages.removeRange(30, _thoughtMessages.length);
    }
    notifyListeners();
  }

  /// Feature 1: Teacher posts a new Quest Counter Activity.
  Future<LobbyQuestActivity> postActivity({
    required String title,
    required String subject,
    required String activityUrl,
    required int xpReward,
    required String badgeName,
    required String badgeIcon,
    required int badgeColor,
    required String postedBy,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final activity = LobbyQuestActivity(
      id: 'act_$now',
      title: title.trim(),
      subject: normalizeSubjectCode(subject),
      activityUrl: activityUrl.trim(),
      xpReward: xpReward.clamp(10, 1000),
      badgeName: badgeName.trim().isEmpty ? 'Quest Finisher' : badgeName.trim(),
      badgeIcon: badgeIcon.trim().isEmpty ? '🛡️' : badgeIcon.trim(),
      badgeColor: badgeColor,
      postedBy: postedBy.trim().isEmpty ? 'Teacher' : postedBy.trim(),
      createdAtMs: now,
    );
    _activities = [activity, ..._activities];
    final prefs = await SharedPreferences.getInstance();
    await _saveActivities(prefs);
    notifyListeners();
    return activity;
  }

  /// Feature 1: Student clicks "Launch Activity" -> unlocks "Mark as Done".
  Future<void> markActivityLaunched(String activityId) async {
    if (_progress.launchedActivityIds.contains(activityId)) return;
    final nextLaunched = Set<String>.from(_progress.launchedActivityIds)
      ..add(activityId);
    _progress = _progress.copyWith(launchedActivityIds: nextLaunched);
    await _saveProgress();
    notifyListeners();
  }

  /// Feature 1: Student clicks "Mark as Done" -> awards XP + Badge and equips if first badge.
  Future<EarnedStudentBadge?> completeActivity(
      LobbyQuestActivity activity) async {
    if (_progress.completedActivityIds.contains(activity.id)) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final badge = EarnedStudentBadge(
      id: 'badge_${activity.id}',
      badgeName: activity.badgeName,
      badgeIcon: activity.badgeIcon,
      badgeColor: activity.badgeColor,
      subject: activity.subject,
      sourceTitle: activity.title,
      earnedAtMs: now,
    );

    final nextCompleted = Set<String>.from(_progress.completedActivityIds)
      ..add(activity.id);
    final nextBadges = [badge, ..._progress.earnedBadges];
    final nextEquipped = _progress.equippedBadgeId ?? badge.id;

    _progress = _progress.copyWith(
      xp: _progress.xp + activity.xpReward,
      completedActivityIds: nextCompleted,
      earnedBadges: nextBadges,
      equippedBadgeId: nextEquipped,
    );
    await _saveProgress();
    notifyListeners();
    return badge;
  }

  /// Feature 1: Equip a badge next to the student's floating avatar nameplate.
  Future<void> equipBadge(String badgeId) async {
    _progress = _progress.copyWith(equippedBadgeId: badgeId);
    await _saveProgress();
    notifyListeners();
  }

  /// Feature 2: Teacher adds a Reviewer item to a Subject Chest.
  Future<LobbyReviewerItem> addReviewerToChest({
    required String chestId,
    required String title,
    required String fileType,
    required String urlOrContent,
    required String summary,
    required String uploadedBy,
  }) async {
    final idx = _subjectChests.indexWhere((c) => c.id == chestId);
    if (idx < 0) {
      throw StateError('Subject chest not found: $chestId');
    }
    final chest = _subjectChests[idx];
    final now = DateTime.now().millisecondsSinceEpoch;
    final item = LobbyReviewerItem(
      id: 'rev_$now',
      title: title.trim(),
      subject: chest.subjectName,
      fileType: fileType.trim().toUpperCase(),
      urlOrContent: urlOrContent.trim(),
      summary: summary.trim(),
      uploadedBy: uploadedBy.trim().isEmpty ? 'Teacher' : uploadedBy.trim(),
      createdAtMs: now,
    );

    final updatedChest = chest.copyWith(
      reviewers: [item, ...chest.reviewers],
    );
    _subjectChests = List<SubjectChest>.from(_subjectChests)
      ..[idx] = updatedChest;

    final prefs = await SharedPreferences.getInstance();
    await _saveSubjectChests(prefs);
    notifyListeners();
    return item;
  }

  /// Feature 2: Teacher renames an existing Subject Chest or adds a new Subject Chest.
  Future<SubjectChest> addOrRenameSubjectChest({
    String? existingChestId,
    required String subjectName,
    String? fullTitle,
    required int colorValue,
  }) async {
    final cleanName = normalizeSubjectCode(subjectName);
    if (existingChestId != null) {
      final idx = _subjectChests.indexWhere((c) => c.id == existingChestId);
      if (idx >= 0) {
        final updated = _subjectChests[idx].copyWith(
          subjectName: cleanName,
          fullTitle: fullTitle ?? _subjectChests[idx].fullTitle,
          colorValue: colorValue,
        );
        _subjectChests = List<SubjectChest>.from(_subjectChests)..[idx] = updated;
        final prefs = await SharedPreferences.getInstance();
        await _saveSubjectChests(prefs);
        notifyListeners();
        return updated;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final newChest = SubjectChest(
      id: 'chest_$now',
      subjectName: cleanName,
      fullTitle: fullTitle ?? cleanName,
      colorValue: colorValue,
      reviewers: [
        LobbyReviewerItem(
          id: 'rev_seed_$now',
          title: '$cleanName Core Study Guide & Key Concepts',
          subject: cleanName,
          fileType: 'NOTES',
          urlOrContent:
              'Key definitions, core competencies, and exam pointers for $cleanName.',
          summary: 'Starter reviewer notes for $cleanName.',
          uploadedBy: 'Faculty',
          createdAtMs: now,
        ),
      ],
    );
    _subjectChests = [..._subjectChests, newChest];
    final prefs = await SharedPreferences.getInstance();
    await _saveSubjectChests(prefs);
    notifyListeners();
    return newChest;
  }

  /// Feature 3: Returns remaining cooldown in seconds for a Small Mystery Chest (`0` if ready).
  int smallChestRemainingSeconds(String smallChestId, [int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final until = _progress.smallChestCooldownUntilMs[smallChestId] ?? 0;
    if (until <= now) return 0;
    return ((until - now) / 1000).ceil();
  }

  bool isSmallChestOnCooldown(String smallChestId, [int? nowMs]) {
    return smallChestRemainingSeconds(smallChestId, nowMs) > 0;
  }

  /// Feature 3: Picks a random Pop-Quiz Question strictly from the student's active enrolled subjects.
  MiniQuizQuestion pickRandomQuestionForSmallChest(String smallChestId) {
    final pool = quizQuestions;
    if (pool.isEmpty) {
      final fallback = _defaultQuizQuestions();
      return fallback.first;
    }
    final rng = math.Random();
    return pool[rng.nextInt(pool.length)];
  }

  /// Feature 3: Submits an answer to a Small Mystery Chest Pop-Quiz.
  /// Correct -> awards `question.xpReward` (+25 XP) and starts the 2-minute cooldown on `smallChestId`.
  Future<bool> submitSmallChestQuizAnswer({
    required String smallChestId,
    required MiniQuizQuestion question,
    required int selectedIndex,
  }) async {
    if (selectedIndex != question.correctIndex) {
      return false;
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final nextCooldowns =
        Map<String, int>.from(_progress.smallChestCooldownUntilMs);
    nextCooldowns[smallChestId] = now + kSmallChestCooldownMs;

    _progress = _progress.copyWith(
      xp: _progress.xp + question.xpReward,
      smallChestCooldownUntilMs: nextCooldowns,
    );
    await _saveProgress();
    notifyListeners();
    return true;
  }

  /// Teacher can also add custom Pop-Quiz Questions to the Mystery Chest pool.
  Future<MiniQuizQuestion> addQuizQuestion({
    required String subject,
    required String question,
    required List<String> options,
    required int correctIndex,
    int xpReward = 25,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final q = MiniQuizQuestion(
      id: 'quiz_$now',
      subject: normalizeSubjectCode(subject),
      question: question.trim(),
      options: options,
      correctIndex: correctIndex.clamp(0, 3),
      xpReward: xpReward,
    );
    _quizQuestions = [q, ..._quizQuestions];
    final prefs = await SharedPreferences.getInstance();
    await _saveQuizQuestions(prefs);
    notifyListeners();
    return q;
  }

  Future<void> _saveActivities(SharedPreferences prefs) async {
    await prefs.setString(
      _kActivitiesKey,
      jsonEncode(_activities.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> _saveSubjectChests(SharedPreferences prefs) async {
    await prefs.setString(
      _kSubjectChestsKey,
      jsonEncode(_subjectChests.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _saveQuizQuestions(SharedPreferences prefs) async {
    await prefs.setString(
      _kQuizQuestionsKey,
      jsonEncode(_quizQuestions.map((q) => q.toJson()).toList()),
    );
  }

  Future<void> _saveProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_kProgressPrefix$_activeUserId',
      jsonEncode(_progress.toJson()),
    );
  }

  static List<SubjectChest> _defaultSubjectChests() {
    const seedTime = 1710000000000;
    return const [
      SubjectChest(
        id: 'chest_pgp',
        subjectName: 'PGP',
        fullTitle: 'Philippine Governance and Politics',
        colorValue: 0xFF38BDF8,
        reviewers: [
          LobbyReviewerItem(
            id: 'rev_pgp_1',
            title: 'PGP Weeks 1–10 Master Reviewer & Branches of Government',
            subject: 'PGP',
            fileType: 'NOTES',
            urlOrContent:
                '• Politics vs. Governance: Power, Authority, and Legitimacy\n'
                '• 1987 Philippine Constitution: Executive (Art. VII), Legislative (Art. VI), Judicial (Art. VIII)\n'
                '• Decentralization & Local Governance (RA 7160 Local Government Code)\n'
                '• Suffrage, Elections, Political Parties & Civil Society Organizations.',
            summary:
                'Comprehensive PGP study summary synced with the MIS-SHS Google Drive Reviewer Folder (39 files).',
            uploadedBy: 'MIS-SHS Social Science Dept.',
            createdAtMs: seedTime,
          ),
        ],
      ),
      SubjectChest(
        id: 'chest_ucsp',
        subjectName: 'UCSP',
        fullTitle: 'Understanding Culture, Society and Politics',
        colorValue: 0xFF10B981,
        reviewers: [
          LobbyReviewerItem(
            id: 'rev_ucsp_1',
            title: 'UCSP Weeks 1–6 Master Reviewer: Culture, Society & Kinship',
            subject: 'UCSP',
            fileType: 'NOTES',
            urlOrContent:
                '• Anthropology, Sociology, and Political Science Perspectives\n'
                '• Ethnocentrism vs. Cultural Relativism\n'
                '• Socialization, Conformity, Deviance & Human Dignity\n'
                '• Kinship, Marriage, Social Stratification & Cultural Change.',
            summary:
                'Core UCSP reviewer notes paired with the 24 interactive HTML decks in the Google Drive Reviewer Folder.',
            uploadedBy: 'MIS-SHS Social Science Dept.',
            createdAtMs: seedTime,
          ),
        ],
      ),
      SubjectChest(
        id: 'chest_ppg',
        subjectName: 'PPG',
        fullTitle: 'Philippine Politics and Governance',
        colorValue: 0xFFF59E0B,
        reviewers: [
          LobbyReviewerItem(
            id: 'rev_ppg_1',
            title: 'PPG Weeks 1–2 Ideologies, Power & State Elements',
            subject: 'PPG',
            fileType: 'NOTES',
            urlOrContent:
                '• Four Elements of a State: People, Territory, Government, Sovereignty\n'
                '• Faces of Power & Political Ideologies (Liberalism, Conservatism, Socialism)\n'
                '• Evolution of Philippine Politics from Pre-Colonial Barangay to Republic.',
            summary:
                'Essential PPG reviewer notes paired with the Google Drive Reviewer Folder.',
            uploadedBy: 'MIS-SHS Social Science Dept.',
            createdAtMs: seedTime,
          ),
        ],
      ),
      SubjectChest(
        id: 'chest_pklp_term_2',
        subjectName: 'PKLP TERM 2',
        fullTitle: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino (Term 2)',
        colorValue: 0xFFF97316,
        reviewers: [
          LobbyReviewerItem(
            id: 'rev_pklp_t2_1',
            title: 'PKLP Term 2 Weeks 11–12: Kasaysayan at Kontemporaryong Lipunan',
            subject: 'PKLP TERM 2',
            fileType: 'NOTES',
            urlOrContent:
                '• Batis Pangkasaysayan: Primarya at Sekundaryang Sanggunian\n'
                '• Pantayong Pananaw (Zeus Salazar) at Sikolohiyang Pilipino\n'
                '• Hamon ng Makabagong Lipunang Pilipino, Karapatang Pantao at Pakikilahok.',
            summary:
                'Active Term 2 PKLP reviewer guide paired with Weeks 11–12 HTML decks from Google Drive.',
            uploadedBy: 'MIS-SHS Araling Panlipunan Dept.',
            createdAtMs: seedTime,
          ),
        ],
      ),
      SubjectChest(
        id: 'chest_philo',
        subjectName: 'PHILO',
        fullTitle: 'Introduction to Philosophy of Human Person',
        colorValue: 0xFFA855F7,
        reviewers: [
          LobbyReviewerItem(
            id: 'rev_philo_1',
            title: 'Holistic Perspective, Methods of Philosophizing & Embodiment',
            subject: 'PHILO',
            fileType: 'NOTES',
            urlOrContent:
                '• Holistic Thinking vs. Partial Point of View\n'
                '• Socratic Dialectic, Phenomenology & Existentialism\n'
                '• Truth vs. Opinion & Logical Fallacies\n'
                '• The Human Person as an Embodied Spirit & Environmental Ethics.',
            summary:
                'Complete Philosophy of the Human Person reviewer guide.',
            uploadedBy: 'MIS-SHS Humanities Dept.',
            createdAtMs: seedTime,
          ),
        ],
      ),
    ];
  }

  static List<LobbyQuestActivity> _defaultActivities() {
    const seedTime = 1710000000000;
    return const [
      LobbyQuestActivity(
        id: 'act_seed_pgp',
        title: 'Unit 2 Policy & Constitutional Analysis Quest',
        subject: 'PGP',
        activityUrl: 'https://www.officialgazette.gov.ph/constitutions/1987-constitution/',
        xpReward: 100,
        badgeName: 'Policy Vanguard',
        badgeIcon: '🛡️',
        badgeColor: 0xFF38BDF8,
        postedBy: 'Sir Jim Mark',
        createdAtMs: seedTime,
      ),
      LobbyQuestActivity(
        id: 'act_seed_ucsp',
        title: 'Cultural Relativism Case Reflection',
        subject: 'UCSP',
        activityUrl: 'https://en.wikipedia.org/wiki/Cultural_relativism',
        xpReward: 100,
        badgeName: 'Social Scientist',
        badgeIcon: '🏛️',
        badgeColor: 0xFF10B981,
        postedBy: 'Sir Jim Mark',
        createdAtMs: seedTime - 1000,
      ),
      LobbyQuestActivity(
        id: 'act_seed_ppg',
        title: 'Branches of Government & Checks and Balances',
        subject: 'PPG',
        activityUrl: 'https://www.officialgazette.gov.ph/constitutions/1987-constitution/',
        xpReward: 100,
        badgeName: 'Quiz Conqueror',
        badgeIcon: '👑',
        badgeColor: 0xFFFACC15,
        postedBy: 'Sir Jim Mark',
        createdAtMs: seedTime - 1500,
      ),
      LobbyQuestActivity(
        id: 'act_seed_pklp_t2',
        title: 'Pagsusuri ng Batis sa Lipunang Pilipino (Term 2)',
        subject: 'PKLP TERM 2',
        activityUrl: 'https://nhcp.gov.ph/',
        xpReward: 110,
        badgeName: 'Kasaysayan Keeper',
        badgeIcon: '📜',
        badgeColor: 0xFFF97316,
        postedBy: 'Sir Jim Mark',
        createdAtMs: seedTime - 1800,
      ),
      LobbyQuestActivity(
        id: 'act_seed_philo',
        title: 'Socratic Dialogue & Truth vs. Opinion Challenge',
        subject: 'PHILO',
        activityUrl: 'https://plato.stanford.edu/entries/socrates/',
        xpReward: 120,
        badgeName: 'Philo Sage',
        badgeIcon: '🦉',
        badgeColor: 0xFFA855F7,
        postedBy: 'Sir Jim Mark',
        createdAtMs: seedTime - 2000,
      ),
    ];
  }

  static List<MiniQuizQuestion> _defaultQuizQuestions() {
    return const [
      MiniQuizQuestion(
        id: 'q_pgp_1',
        subject: 'PGP',
        question:
            'Which branch of the Philippine government is vested with the power to enact, amend, and repeal laws?',
        options: [
          'Executive Branch',
          'Legislative Branch',
          'Judicial Branch',
          'Commission on Audit',
        ],
        correctIndex: 1,
        xpReward: 25,
      ),
      MiniQuizQuestion(
        id: 'q_pgp_2',
        subject: 'PGP',
        question:
            'What element of the State refers to its supreme and absolute power to command and enforce obedience within its territory?',
        options: [
          'People',
          'Government',
          'Sovereignty',
          'Diplomacy',
        ],
        correctIndex: 2,
        xpReward: 25,
      ),
      MiniQuizQuestion(
        id: 'q_ucsp_1',
        subject: 'UCSP',
        question:
            'Viewing another culture using the standards and beliefs of one\'s own culture as superior is known as:',
        options: [
          'Cultural Relativism',
          'Ethnocentrism',
          'Enculturation',
          'Xenocentrism',
        ],
        correctIndex: 1,
        xpReward: 25,
      ),
      MiniQuizQuestion(
        id: 'q_ucsp_2',
        subject: 'UCSP',
        question:
            'Which social science discipline primarily studies human biological and cultural evolution across time?',
        options: [
          'Anthropology',
          'Political Science',
          'Macroeconomics',
          'Demography',
        ],
        correctIndex: 0,
        xpReward: 25,
      ),
      MiniQuizQuestion(
        id: 'q_ppg_1',
        subject: 'PPG',
        question:
            'Under the 1987 Philippine Constitution, who serves as the Commander-in-Chief of the Armed Forces of the Philippines?',
        options: [
          'Senate President',
          'Chief Justice',
          'President of the Philippines',
          'Secretary of National Defense',
        ],
        correctIndex: 2,
        xpReward: 25,
      ),
      MiniQuizQuestion(
        id: 'q_pklp_t2_1',
        subject: 'PKLP TERM 2',
        question:
            'Alin sa mga sumusunod ang halimbawa ng Primaryang Batis (Primary Source) sa pag-aaral ng kasaysayan?',
        options: [
          'Orihinal na talaarawan at liham ng saksi sa pangyayari',
          'Aklat-aralin sa paaralan na isinulat ngayong taon',
          'Artikulo sa encyclopedia',
          'Rebyu ng pelikula tungkol sa bayani',
        ],
        correctIndex: 0,
        xpReward: 25,
      ),
      MiniQuizQuestion(
        id: 'q_pklp_t2_2',
        subject: 'PKLP TERM 2',
        question:
            'Sino ang historyador na nagtaguyod ng "Pantayong Pananaw" sa pag-unawa ng kasaysayan at kalinangang Pilipino?',
        options: [
          'Zeus Salazar',
          'Jose Rizal',
          'Graciano Lopez Jaena',
          'Pedro Paterno',
        ],
        correctIndex: 0,
        xpReward: 25,
      ),
      MiniQuizQuestion(
        id: 'q_philo_1',
        subject: 'PHILO',
        question:
            'Who among the ancient Greek philosophers is famous for the dictum "The unexamined life is not worth living"?',
        options: [
          'Socrates',
          'Pythagoras',
          'Thales of Miletus',
          'Epicurus',
        ],
        correctIndex: 0,
        xpReward: 25,
      ),
      MiniQuizQuestion(
        id: 'q_philo_2',
        subject: 'PHILO',
        question:
            'Attacking the character or motive of the person making an argument rather than addressing the argument itself is which fallacy?',
        options: [
          'Ad Hominem',
          'Appeal to Force (Ad Baculum)',
          'False Cause (Post Hoc)',
          'Begging the Question',
        ],
        correctIndex: 0,
        xpReward: 25,
      ),
    ];
  }
}

class MergeResult {
  final SubjectChest chest;
  final bool changed;

  const MergeResult({
    required this.chest,
    required this.changed,
  });
}
