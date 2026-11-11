import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/portal_models.dart';
import '../services/api_service.dart';
import 'lobby_exam_bank.dart';
import 'lobby_shop_service.dart';

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
  final String fileType; // 'LINK' | 'HTML' | 'PDF' | 'PPTX' | 'NOTES'
  final String urlOrContent;
  final String summary;
  final String uploadedBy;
  final int createdAtMs;
  final int xpReward;
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
    this.xpReward = 50,
    this.driveFileId,
    this.mimeType,
    this.weekGroup,
  });

  bool get isFromDrive => driveFileId != null && driveFileId!.trim().isNotEmpty;

  bool get isLink {
    final trimmed = urlOrContent.trim().toLowerCase();
    return fileType.toUpperCase() == 'LINK' ||
        trimmed.startsWith('http://') ||
        trimmed.startsWith('https://');
  }

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
      fileType: json['fileType']?.toString() ?? 'LINK',
      urlOrContent: json['urlOrContent']?.toString() ?? '',
      summary: json['summary']?.toString() ?? '',
      uploadedBy: json['uploadedBy']?.toString() ?? 'Teacher',
      createdAtMs: (json['createdAtMs'] as num?)?.toInt() ?? 0,
      xpReward: ((json['xpReward'] as num?)?.toInt() ?? 50).clamp(10, 1000),
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
        'xpReward': xpReward,
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

/// Per-student RPG state (XP, Spent Shop XP, Level, Rank Title, Launched/Completed Activities & Reviewers,
/// Earned Badges, Equipped Badge, 24h Chest Cooldowns, Unlocked Shop Cosmetics, and Non-Repeating Question History).
class StudentLobbyProgress {
  final int xp;
  final int spentXp;
  final Set<String> launchedActivityIds;
  final Set<String> completedActivityIds;
  final Set<String> launchedReviewerIds;
  final Set<String> completedReviewerIds;
  final List<EarnedStudentBadge> earnedBadges;
  final String? equippedBadgeId;
  final Map<String, int> smallChestCooldownUntilMs;
  final int smallChestsSolvedCount;
  final Set<String> unlockedCosmetics;
  final List<String> answeredQuestionIds;
  final LobbyTableDecorConfig tableDecor;

  const StudentLobbyProgress({
    this.xp = 0,
    this.spentXp = 0,
    this.launchedActivityIds = const {},
    this.completedActivityIds = const {},
    this.launchedReviewerIds = const {},
    this.completedReviewerIds = const {},
    this.earnedBadges = const [],
    this.equippedBadgeId,
    this.smallChestCooldownUntilMs = const {},
    this.smallChestsSolvedCount = 0,
    this.unlockedCosmetics = LobbyShopService.kStarterUnlockedCosmetics,
    this.answeredQuestionIds = const [],
    this.tableDecor = const LobbyTableDecorConfig(),
  });

  /// Spendable XP wallet in the Campus Cosmetics Shop (`xp - spentXp`).
  /// Spending XP in the shop never reduces lifetime `level` or `rankTitle`!
  int get availableXp => math.max(0, xp - spentXp);

  int get level => (xp ~/ 100) + 1;
  int get currentLevelXp => xp % 100;

  String get rankTitle {
    final lv = level;
    if (lv >= 10) return 'Grand Academician';
    if (lv >= 7) return 'Campus Luminary';
    if (lv >= 5) return "Dean's Lister";
    if (lv >= 4) return 'Quiz Vanguard';
    if (lv >= 3) return 'Honor Scholar';
    if (lv >= 2) return 'Campus Explorer';
    return 'Campus Freshman';
  }

  String get rankEmoji {
    final lv = level;
    if (lv >= 10) return '👑';
    if (lv >= 7) return '🌟';
    if (lv >= 5) return '🎓';
    if (lv >= 4) return '🛡️';
    if (lv >= 3) return '⚡';
    if (lv >= 2) return '🧭';
    return '🌱';
  }

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
    int? spentXp,
    Set<String>? launchedActivityIds,
    Set<String>? completedActivityIds,
    Set<String>? launchedReviewerIds,
    Set<String>? completedReviewerIds,
    List<EarnedStudentBadge>? earnedBadges,
    String? equippedBadgeId,
    Map<String, int>? smallChestCooldownUntilMs,
    int? smallChestsSolvedCount,
    Set<String>? unlockedCosmetics,
    List<String>? answeredQuestionIds,
    LobbyTableDecorConfig? tableDecor,
  }) {
    return StudentLobbyProgress(
      xp: xp ?? this.xp,
      spentXp: spentXp ?? this.spentXp,
      launchedActivityIds: launchedActivityIds ?? this.launchedActivityIds,
      completedActivityIds: completedActivityIds ?? this.completedActivityIds,
      launchedReviewerIds: launchedReviewerIds ?? this.launchedReviewerIds,
      completedReviewerIds: completedReviewerIds ?? this.completedReviewerIds,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      equippedBadgeId: equippedBadgeId ?? this.equippedBadgeId,
      smallChestCooldownUntilMs:
          smallChestCooldownUntilMs ?? this.smallChestCooldownUntilMs,
      smallChestsSolvedCount:
          smallChestsSolvedCount ?? this.smallChestsSolvedCount,
      unlockedCosmetics: unlockedCosmetics ?? this.unlockedCosmetics,
      answeredQuestionIds: answeredQuestionIds ?? this.answeredQuestionIds,
      tableDecor: tableDecor ?? this.tableDecor,
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
    final launchedRevs = (json['launchedReviewerIds'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        <String>{};
    final completedRevs = (json['completedReviewerIds'] as List?)
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
    final unlocked = <String>{
      ...LobbyShopService.kStarterUnlockedCosmetics,
      ...((json['unlockedCosmetics'] as List?)?.map((e) => e.toString()) ??
          const <String>[]),
    };
    final answered = (json['answeredQuestionIds'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        <String>[];
    final rawDecor = json['tableDecor'];
    final decor = rawDecor is Map
        ? LobbyTableDecorConfig.fromJson(Map<String, dynamic>.from(rawDecor))
        : const LobbyTableDecorConfig();
    return StudentLobbyProgress(
      xp: (json['xp'] as num?)?.toInt() ?? 0,
      spentXp: (json['spentXp'] as num?)?.toInt() ?? 0,
      launchedActivityIds: launched,
      completedActivityIds: completed,
      launchedReviewerIds: launchedRevs,
      completedReviewerIds: completedRevs,
      earnedBadges: badges,
      equippedBadgeId: json['equippedBadgeId']?.toString(),
      smallChestCooldownUntilMs: cooldowns,
      smallChestsSolvedCount:
          (json['smallChestsSolvedCount'] as num?)?.toInt() ?? 0,
      unlockedCosmetics: unlocked,
      answeredQuestionIds: answered,
      tableDecor: decor,
    );
  }

  Map<String, dynamic> toJson() => {
        'xp': xp,
        'spentXp': spentXp,
        'launchedActivityIds': launchedActivityIds.toList(),
        'completedActivityIds': completedActivityIds.toList(),
        'launchedReviewerIds': launchedReviewerIds.toList(),
        'completedReviewerIds': completedReviewerIds.toList(),
        'earnedBadges': earnedBadges.map((b) => b.toJson()).toList(),
        'equippedBadgeId': equippedBadgeId,
        'smallChestCooldownUntilMs': smallChestCooldownUntilMs,
        'smallChestsSolvedCount': smallChestsSolvedCount,
        'unlockedCosmetics': unlockedCosmetics.toList(),
        'answeredQuestionIds': answeredQuestionIds,
        'tableDecor': tableDecor.toJson(),
      };
}

/// Central reactive service managing:
/// - MIS Control Sheet (`Subject Enrollment`) active vs. finished subject filtering
/// - Strict Student Enrollment filtering for Subject Chests, Quest Activities, Reviewers & Quizzes
/// - Teacher Content & Link Manager with Live Google Drive Cloud Manifest Sync (`999999001`)
/// - Thought Bubble Chat history & peer replies
class LobbyDataService extends ChangeNotifier {
  LobbyDataService._();
  static final LobbyDataService instance = LobbyDataService._();

  static const String _kActivitiesKey = 'mis_school_lobby_activities_v4';
  static const String _kSubjectChestsKey = 'mis_school_lobby_subject_chests_v4';
  static const String _kQuizQuestionsKey = 'mis_school_lobby_quiz_questions_v3';
  static const String _kProgressPrefix = 'mis_school_lobby_progress_v1_';
  static const String _kCloudManifestId = '999999001';
  static const String _kCloudProgressPrefix = '999999003_';

  /// 24-hour refresh interval per student for each Small Mystery Chest (86,400,000 ms).
  static const int kSmallChestCooldownMs = 24 * 60 * 60 * 1000;

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

  bool get isInitialized => _initialized;
  bool get isSyncingDriveReviewers => _isSyncingDriveReviewers;
  List<SubjectEnrollmentStatus> get controlSheetSubjects =>
      List.unmodifiable(_controlSheetSubjects);
  Set<String> get studentEnrolledCodes =>
      Set.unmodifiable(_studentEnrolledCodes);
  StudentLobbyProgress get progress => _progress;
  List<LobbyThoughtMessage> get thoughtMessages =>
      List.unmodifiable(_thoughtMessages);

  /// Visible subject names (plus legacy `'KASAYSAYAN'` alias when `'PKLP TERM 2'` is visible).
  List<String> get subjectNames {
    final names = subjectChests.map((c) => c.subjectName).toList();
    if (names.contains('PKLP TERM 2') && !names.contains('KASAYSAYAN')) {
      names.add('KASAYSAYAN');
    }
    return names;
  }

  /// Alias for `quizQuestions` used by tests.
  List<MiniQuizQuestion> get allReviewerQuestions => quizQuestions;

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

    // 3. Load or seed Mini Quiz Questions (merging all authentic `.docx` exam questions)
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
    }
    // Ensure all authentic `.docx` exam questions from `exams/` are present
    final existingIds = _quizQuestions.map((q) => q.id).toSet();
    var addedExamQuestions = false;
    for (final examQ in _defaultQuizQuestions()) {
      if (!existingIds.contains(examQ.id)) {
        _quizQuestions.add(examQ);
        addedExamQuestions = true;
      }
    }
    if (rawQuestions == null || addedExamQuestions) {
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

  /// Synchronizes the MIS Control Sheet status (`getSystemStatus`) and pulls the
  /// Teacher's live Reviewer Links & Activity Links manifest from Google Drive (`999999001`).
  /// Does NOT auto-inject random Drive files so chests remain clean and strictly
  /// contain links curated by the Teacher!
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

      // 2. Pull Teacher's live Cloud Manifest (Activities & Reviewer Links)
      await _pullCloudManifest();

      // 2b. Pull & merge Student's Cloud RPG & Shop Progress (`999999003_<studentId>`)
      await _pullAndMergeCloudProgress();

      // 3. Ensure every enrolled active subject has a SubjectChest ready
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

      if (chestsChanged) {
        final prefs = await SharedPreferences.getInstance();
        await _saveSubjectChests(prefs);
      }
    } finally {
      _isSyncingDriveReviewers = false;
      notifyListeners();
    }
  }

  /// Pushes the Teacher's current Activities and Subject Chest Reviewer Links
  /// to Google Drive (`_kCloudManifestId = '999999001'`) so all Student APKs
  /// automatically receive the Teacher's links across devices.
  Future<bool> pushCloudManifest() async {
    try {
      final manifest = <String, dynamic>{
        'version': 4,
        'updatedAtMs': DateTime.now().millisecondsSinceEpoch,
        'activities': _activities.map((a) => a.toJson()).toList(),
        'subjectChests': _subjectChests.map((c) => c.toJson()).toList(),
      };
      final rawJson = jsonEncode(manifest);
      final encoded = base64Encode(utf8.encode(rawJson));
      final dataUrl = 'data:application/json;base64,$encoded';
      final res = await ApiService.instance.uploadStudentAvatar(
        id: _kCloudManifestId,
        dataUrl: dataUrl,
      );
      return res['success'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Pulls the Teacher's latest Activities and Subject Chest Reviewer Links
  /// from Google Drive (`_kCloudManifestId = '999999001'`).
  Future<bool> _pullCloudManifest() async {
    try {
      final rawDataUrl =
          await ApiService.instance.getStudentAvatar(_kCloudManifestId);
      if (rawDataUrl == null || !rawDataUrl.contains(',')) return false;
      final b64 = rawDataUrl.split(',').last.trim();
      if (b64.isEmpty) return false;
      final decodedStr = utf8.decode(base64Decode(b64));
      final map = jsonDecode(decodedStr);
      if (map is! Map) return false;

      var updated = false;
      if (map['activities'] is List) {
        _activities = (map['activities'] as List)
            .whereType<Map>()
            .map(
              (e) => LobbyQuestActivity.fromJson(Map<String, dynamic>.from(e)),
            )
            .toList();
        updated = true;
      }
      if (map['subjectChests'] is List) {
        final cloudChests = (map['subjectChests'] as List)
            .whereType<Map>()
            .map((e) => SubjectChest.fromJson(Map<String, dynamic>.from(e)))
            .toList();
        if (cloudChests.isNotEmpty) {
          _subjectChests = cloudChests;
          updated = true;
        }
      }
      if (updated) {
        final prefs = await SharedPreferences.getInstance();
        await _saveActivities(prefs);
        await _saveSubjectChests(prefs);
        notifyListeners();
      }
      return updated;
    } catch (_) {
      return false;
    }
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

  /// Feature 1: Teacher posts a new Quest Counter Activity Link.
  Future<LobbyQuestActivity> postActivity({
    required String title,
    required String subject,
    required String activityUrl,
    required int xpReward,
    required String badgeName,
    required String badgeIcon,
    int badgeColor = 0xFFFACC15,
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
    unawaited(pushCloudManifest());
    return activity;
  }

  /// Teacher deletes a posted Activity Link from the Quest Counter.
  Future<void> deleteActivity(String activityId) async {
    _activities = _activities.where((a) => a.id != activityId).toList();
    final prefs = await SharedPreferences.getInstance();
    await _saveActivities(prefs);
    notifyListeners();
    unawaited(pushCloudManifest());
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

  /// Feature 1: Student clicks "Mark as Done" on an Activity -> awards XP + Badge and equips if first badge.
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

  /// Feature 2: Student clicks "Launch Reviewer Link" -> unlocks "Mark as Done (+XP)".
  Future<void> markReviewerLaunched(String reviewerId) async {
    if (_progress.launchedReviewerIds.contains(reviewerId)) return;
    final nextLaunched = Set<String>.from(_progress.launchedReviewerIds)
      ..add(reviewerId);
    _progress = _progress.copyWith(launchedReviewerIds: nextLaunched);
    await _saveProgress();
    notifyListeners();
  }

  /// Feature 2: Student clicks "Mark as Done (+XP)" on a Reviewer Link -> awards XP
  /// and unlocks a Reviewer Scholar badge on their 1st and 3rd completed reviewers!
  Future<EarnedStudentBadge?> completeReviewer(
      LobbyReviewerItem reviewer) async {
    if (_progress.completedReviewerIds.contains(reviewer.id)) return null;

    final now = DateTime.now().millisecondsSinceEpoch;
    final nextCompleted = Set<String>.from(_progress.completedReviewerIds)
      ..add(reviewer.id);
    final nextLaunched = Set<String>.from(_progress.launchedReviewerIds)
      ..add(reviewer.id);

    EarnedStudentBadge? unlockedBadge;
    var nextBadges = List<EarnedStudentBadge>.from(_progress.earnedBadges);

    if (nextCompleted.length == 1 &&
        !nextBadges.any((b) => b.id == 'badge_reviewer_scholar')) {
      unlockedBadge = EarnedStudentBadge(
        id: 'badge_reviewer_scholar',
        badgeName: 'Reviewer Scholar',
        badgeIcon: '📚',
        badgeColor: 0xFF38BDF8,
        subject: reviewer.subject,
        sourceTitle: reviewer.title,
        earnedAtMs: now,
      );
      nextBadges = [unlockedBadge, ...nextBadges];
    } else if (nextCompleted.length >= 3 &&
        !nextBadges.any((b) => b.id == 'badge_vault_master')) {
      unlockedBadge = EarnedStudentBadge(
        id: 'badge_vault_master',
        badgeName: 'Vault Master',
        badgeIcon: '💎',
        badgeColor: 0xFFA855F7,
        subject: reviewer.subject,
        sourceTitle: 'Completed 3 Reviewer Links',
        earnedAtMs: now,
      );
      nextBadges = [unlockedBadge, ...nextBadges];
    }

    _progress = _progress.copyWith(
      xp: _progress.xp + reviewer.xpReward,
      launchedReviewerIds: nextLaunched,
      completedReviewerIds: nextCompleted,
      earnedBadges: nextBadges,
      equippedBadgeId: _progress.equippedBadgeId ?? unlockedBadge?.id,
    );
    await _saveProgress();
    notifyListeners();
    return unlockedBadge;
  }

  /// Feature 1: Equip a badge next to the student's floating avatar nameplate.
  Future<void> equipBadge(String badgeId) async {
    _progress = _progress.copyWith(equippedBadgeId: badgeId);
    await _saveProgress();
    notifyListeners();
  }

  /// Feature 2: Teacher adds a Reviewer Link or study item to a Subject Chest.
  Future<LobbyReviewerItem> addReviewerToChest({
    required String chestId,
    required String title,
    required String fileType,
    required String urlOrContent,
    required String summary,
    required String uploadedBy,
    int xpReward = 50,
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
      xpReward: xpReward.clamp(10, 1000),
    );

    final updatedChest = chest.copyWith(
      reviewers: [item, ...chest.reviewers],
    );
    _subjectChests = List<SubjectChest>.from(_subjectChests)
      ..[idx] = updatedChest;

    final prefs = await SharedPreferences.getInstance();
    await _saveSubjectChests(prefs);
    notifyListeners();
    unawaited(pushCloudManifest());
    return item;
  }

  /// Teacher deletes a Reviewer Link from a Subject Chest.
  Future<void> deleteReviewerFromChest({
    required String chestId,
    required String reviewerId,
  }) async {
    final idx = _subjectChests.indexWhere((c) => c.id == chestId);
    if (idx < 0) return;
    final chest = _subjectChests[idx];
    final updated = chest.copyWith(
      reviewers: chest.reviewers.where((r) => r.id != reviewerId).toList(),
    );
    _subjectChests = List<SubjectChest>.from(_subjectChests)..[idx] = updated;
    final prefs = await SharedPreferences.getInstance();
    await _saveSubjectChests(prefs);
    notifyListeners();
    unawaited(pushCloudManifest());
  }

  /// Feature 2: Teacher renames an existing Subject Chest or adds a new Subject Chest (starts empty).
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
        unawaited(pushCloudManifest());
        return updated;
      }
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final newChest = SubjectChest(
      id: 'chest_$now',
      subjectName: cleanName,
      fullTitle: fullTitle ?? cleanName,
      colorValue: colorValue,
      reviewers: const [],
    );
    _subjectChests = [..._subjectChests, newChest];
    final prefs = await SharedPreferences.getInstance();
    await _saveSubjectChests(prefs);
    notifyListeners();
    unawaited(pushCloudManifest());
    return newChest;
  }

  /// Feature 3: Returns remaining cooldown in seconds for a Small Mystery Chest (`0` if ready).
  int smallChestRemainingSeconds(String smallChestId, [int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final until = _progress.smallChestCooldownUntilMs[smallChestId] ?? 0;
    if (until <= now) return 0;
    return ((until - now) / 1000).ceil();
  }

  /// Human-readable remaining cooldown string for the 24-hour Small Mystery Chest timer (`XXh YYm` or `MMm SSs`).
  String smallChestFormattedCooldown(String smallChestId, [int? nowMs]) {
    final remSec = smallChestRemainingSeconds(smallChestId, nowMs);
    if (remSec <= 0) return 'Ready';
    final hours = remSec ~/ 3600;
    final mins = (remSec % 3600) ~/ 60;
    final secs = remSec % 60;
    if (hours > 0) {
      return '${hours}h ${mins.toString().padLeft(2, '0')}m';
    }
    return '${mins}m ${secs.toString().padLeft(2, '0')}s';
  }

  bool isSmallChestOnCooldown(String smallChestId, [int? nowMs]) {
    return smallChestRemainingSeconds(smallChestId, nowMs) > 0;
  }

  /// Feature 3 & Item #4: Picks an authentic `.docx` exam question strictly from the student's
  /// active enrolled subjects (and matching the AI Mentor's Portal subject `PKLP`, `PPG`, or `UCSP` if specified)
  /// and rotates through `answeredQuestionIds` so questions NEVER repeat
  /// until the student has completed the entire deck!
  MiniQuizQuestion pickRandomQuestionForSmallChest(
    String smallChestId, {
    String? preferredSubjectCode,
  }) {
    var pool = quizQuestions;
    if (pool.isEmpty) {
      pool = _defaultQuizQuestions();
    }

    // Infer subject from preferredSubjectCode or AI Mentor ID ('pklp', 'ppg', 'ucsp')
    final lowerId = (preferredSubjectCode ?? smallChestId).toLowerCase();
    String? targetSubjectPrefix;
    if (lowerId.contains('pklp')) {
      targetSubjectPrefix = 'PKLP';
    } else if (lowerId.contains('ppg')) {
      targetSubjectPrefix = 'PPG';
    } else if (lowerId.contains('ucsp')) {
      targetSubjectPrefix = 'UCSP';
    }

    if (targetSubjectPrefix != null) {
      final matchingPool = pool
          .where(
              (q) => q.subject.toUpperCase().startsWith(targetSubjectPrefix!))
          .toList();
      if (matchingPool.isNotEmpty) {
        pool = matchingPool;
      } else {
        final bankMatching = kAuthenticExamQuestionBank
            .where((q) =>
                q.subject.toUpperCase().startsWith(targetSubjectPrefix!))
            .toList();
        if (bankMatching.isNotEmpty) {
          pool = bankMatching;
        }
      }
    }

    final answeredSet = _progress.answeredQuestionIds.toSet();
    final unanswered =
        pool.where((q) => !answeredSet.contains(q.id)).toList();

    if (unanswered.isNotEmpty) {
      final chestHash = smallChestId.codeUnits.fold<int>(0, (a, b) => a + b);
      final idx =
          (_progress.answeredQuestionIds.length + chestHash) % unanswered.length;
      return unanswered[idx];
    }

    // All questions in this pool have been answered! Reset rotation for this pool.
    final poolIds = pool.map((q) => q.id).toSet();
    final retainedOtherSubjects = _progress.answeredQuestionIds
        .where((id) => !poolIds.contains(id))
        .toList();
    _progress = _progress.copyWith(answeredQuestionIds: retainedOtherSubjects);
    unawaited(_saveProgress());
    final rng = math.Random();
    return pool[rng.nextInt(pool.length)];
  }

  MiniQuizQuestion? drawRandomMysteryQuestion() {
    final pool = quizQuestions;
    if (pool.isEmpty) return null;
    return pickRandomQuestionForSmallChest('chest_draw_${_progress.answeredQuestionIds.length}');
  }

  /// Records a Small Mystery Chest Pop-Quiz attempt (whether right or wrong on the first click),
  /// locks the chest for **24 hours (`kSmallChestCooldownMs = 86,400,000 ms`)**, rotates `question.id`
  /// into `answeredQuestionIds`, and awards XP + `🏆 Treasure Hunter` badge if solved!
  Future<EarnedStudentBadge?> recordSmallChestSuccess({
    required String smallChestId,
    required MiniQuizQuestion question,
    int? nowMs,
  }) async {
    return _recordSmallChestAttemptInternal(
      smallChestId: smallChestId,
      question: question,
      isCorrect: true,
      nowMs: nowMs,
    );
  }

  Future<EarnedStudentBadge?> _recordSmallChestAttemptInternal({
    required String smallChestId,
    required MiniQuizQuestion question,
    required bool isCorrect,
    int? nowMs,
  }) async {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final nextCooldowns =
        Map<String, int>.from(_progress.smallChestCooldownUntilMs);
    nextCooldowns[smallChestId] = now + kSmallChestCooldownMs;

    final nextAnswered = List<String>.from(_progress.answeredQuestionIds);
    if (!nextAnswered.contains(question.id)) {
      nextAnswered.add(question.id);
    }

    final nextSolved = isCorrect
        ? _progress.smallChestsSolvedCount + 1
        : _progress.smallChestsSolvedCount;

    EarnedStudentBadge? unlockedBadge;
    var nextBadges = List<EarnedStudentBadge>.from(_progress.earnedBadges);
    final alreadyHasHunter =
        nextBadges.any((b) => b.id == 'badge_treasure_hunter');
    if (isCorrect && nextSolved >= 5 && !alreadyHasHunter) {
      unlockedBadge = EarnedStudentBadge(
        id: 'badge_treasure_hunter',
        badgeName: 'Treasure Hunter',
        badgeIcon: '🏆',
        badgeColor: 0xFFFACC15,
        subject: question.subject,
        sourceTitle: 'Solved 5 Small Mystery Chests',
        earnedAtMs: now,
      );
      nextBadges = [unlockedBadge, ...nextBadges];
    }

    _progress = _progress.copyWith(
      xp: isCorrect ? _progress.xp + question.xpReward : _progress.xp,
      smallChestCooldownUntilMs: nextCooldowns,
      smallChestsSolvedCount: nextSolved,
      answeredQuestionIds: nextAnswered,
      earnedBadges: nextBadges,
      equippedBadgeId: _progress.equippedBadgeId ?? unlockedBadge?.id,
    );
    await _saveProgress();
    notifyListeners();
    return unlockedBadge;
  }

  /// Feature 3 & Items #5 & #6: Submits the student's locked first-click answer to a Small Mystery Chest Pop-Quiz.
  /// Immediately starts the **24-hour (`86,400s`) cooldown** on `smallChestId` and rotates the question
  /// whether the answer is right or wrong so students cannot retry or change their answer!
  Future<bool> submitSmallChestQuizAnswer({
    required String smallChestId,
    required MiniQuizQuestion question,
    required int selectedIndex,
    int? nowMs,
  }) async {
    final isCorrect = selectedIndex == question.correctIndex;
    await _recordSmallChestAttemptInternal(
      smallChestId: smallChestId,
      question: question,
      isCorrect: isCorrect,
      nowMs: nowMs,
    );
    return isCorrect;
  }

  /// Item #8: Exchanges earned `availableXp` (`xp - spentXp`) for a cosmetic item in the Campus Shop.
  /// Lifetime `xp`, `level`, and `rankTitle` are never reduced!
  Future<bool> purchaseShopCosmetic({
    required String itemKey,
    required int costXp,
  }) async {
    final cleanKey = itemKey.trim();
    if (cleanKey.isEmpty) return false;
    if (_progress.unlockedCosmetics.contains(cleanKey)) {
      return true;
    }
    final clampedCost = math.max(0, costXp);
    if (_progress.availableXp < clampedCost) {
      return false;
    }
    final nextUnlocked = Set<String>.from(_progress.unlockedCosmetics)
      ..add(cleanKey);
    _progress = _progress.copyWith(
      spentXp: _progress.spentXp + clampedCost,
      unlockedCosmetics: nextUnlocked,
    );
    await _saveProgress();
    notifyListeners();
    return true;
  }

  /// Item #10: Updates and persists the student's equipped Classroom Table Space decorations.
  Future<void> updateTableDecor(LobbyTableDecorConfig decor) async {
    final safeDecor = LobbyShopService.instance.sanitizeTableDecorForUnlocked(
      decor,
      isFaculty: _isFaculty,
    );
    _progress = _progress.copyWith(tableDecor: safeDecor);
    await _saveProgress();
    notifyListeners();
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
    unawaited(_pushCloudProgress());
  }

  /// Section 4.2 Critique Fix: Cloud-backed RPG & Shop state persistence (`999999003_<studentId>`)
  /// so a student reinstalling the APK or switching phones never loses their XP, Badges, or Shop Cosmetics.
  Future<void> _pushCloudProgress() async {
    if (_activeUserId.isEmpty || _activeUserId == 'guest') return;
    try {
      final rawJson = jsonEncode(_progress.toJson());
      final encoded = base64Encode(utf8.encode(rawJson));
      final dataUrl = 'data:application/json;base64,$encoded';
      await ApiService.instance.uploadStudentAvatar(
        id: '$_kCloudProgressPrefix$_activeUserId',
        dataUrl: dataUrl,
      );
    } catch (_) {}
  }

  Future<void> _pullAndMergeCloudProgress() async {
    if (_activeUserId.isEmpty || _activeUserId == 'guest') return;
    try {
      final rawDataUrl = await ApiService.instance
          .getStudentAvatar('$_kCloudProgressPrefix$_activeUserId');
      if (rawDataUrl == null || !rawDataUrl.contains(',')) return;
      final b64 = rawDataUrl.split(',').last.trim();
      if (b64.isEmpty) return;
      final decodedStr = utf8.decode(base64Decode(b64));
      final map = jsonDecode(decodedStr);
      if (map is! Map) return;

      final cloud =
          StudentLobbyProgress.fromJson(Map<String, dynamic>.from(map));
      final mergedBadges = <String, EarnedStudentBadge>{};
      for (final b in [..._progress.earnedBadges, ...cloud.earnedBadges]) {
        mergedBadges[b.id] = b;
      }
      final mergedCooldowns =
          Map<String, int>.from(_progress.smallChestCooldownUntilMs);
      cloud.smallChestCooldownUntilMs.forEach((k, v) {
        final cur = mergedCooldowns[k] ?? 0;
        if (v > cur) mergedCooldowns[k] = v;
      });
      final mergedAnswered = <String>[..._progress.answeredQuestionIds];
      for (final qid in cloud.answeredQuestionIds) {
        if (!mergedAnswered.contains(qid)) mergedAnswered.add(qid);
      }

      _progress = _progress.copyWith(
        xp: math.max(_progress.xp, cloud.xp),
        spentXp: math.max(_progress.spentXp, cloud.spentXp),
        launchedActivityIds: {
          ..._progress.launchedActivityIds,
          ...cloud.launchedActivityIds,
        },
        completedActivityIds: {
          ..._progress.completedActivityIds,
          ...cloud.completedActivityIds,
        },
        launchedReviewerIds: {
          ..._progress.launchedReviewerIds,
          ...cloud.launchedReviewerIds,
        },
        completedReviewerIds: {
          ..._progress.completedReviewerIds,
          ...cloud.completedReviewerIds,
        },
        earnedBadges: mergedBadges.values.toList(),
        equippedBadgeId: _progress.equippedBadgeId ?? cloud.equippedBadgeId,
        smallChestCooldownUntilMs: mergedCooldowns,
        smallChestsSolvedCount: math.max(
          _progress.smallChestsSolvedCount,
          cloud.smallChestsSolvedCount,
        ),
        unlockedCosmetics: {
          ..._progress.unlockedCosmetics,
          ...cloud.unlockedCosmetics,
        },
        answeredQuestionIds: mergedAnswered,
      );
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kProgressPrefix$_activeUserId',
        jsonEncode(_progress.toJson()),
      );
      notifyListeners();
    } catch (_) {}
  }

  /// Phase 4: All Subject Chests start completely empty (`reviewers: const []`)
  /// so the Teacher has 100% control over adding Reviewer Links for each subject!
  static List<SubjectChest> _defaultSubjectChests() {
    return const [
      SubjectChest(
        id: 'chest_pgp',
        subjectName: 'PGP',
        fullTitle: 'Philippine Governance and Politics',
        colorValue: 0xFF38BDF8,
        reviewers: [],
      ),
      SubjectChest(
        id: 'chest_ucsp',
        subjectName: 'UCSP',
        fullTitle: 'Understanding Culture, Society and Politics',
        colorValue: 0xFF10B981,
        reviewers: [],
      ),
      SubjectChest(
        id: 'chest_ppg',
        subjectName: 'PPG',
        fullTitle: 'Philippine Politics and Governance',
        colorValue: 0xFFF59E0B,
        reviewers: [],
      ),
      SubjectChest(
        id: 'chest_pklp_term_2',
        subjectName: 'PKLP TERM 2',
        fullTitle: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino (Term 2)',
        colorValue: 0xFFF97316,
        reviewers: [],
      ),
      SubjectChest(
        id: 'chest_philo',
        subjectName: 'PHILO',
        fullTitle: 'Introduction to Philosophy of Human Person',
        colorValue: 0xFFA855F7,
        reviewers: [],
      ),
    ];
  }

  /// Phase 4: Quest Counter Activities start completely empty (`const []`)
  /// so the Teacher can add Activity Links directly from their Teacher account!
  static List<LobbyQuestActivity> _defaultActivities() {
    return const [];
  }

  /// Phase 5: Seeds all 40+ authentic multiple-choice questions extracted directly
  /// from the 11 `.docx` examination files in the project's `exams/` folder!
  static List<MiniQuizQuestion> _defaultQuizQuestions() {
    return List<MiniQuizQuestion>.from(kAuthenticExamQuestionBank);
  }
}
