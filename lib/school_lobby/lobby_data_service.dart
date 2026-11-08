import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Selectable RPG / Pixel badge icons for Teacher Activity Creation & Achievements.
const List<Map<String, String>> kSelectableBadgeIcons = [
  {'icon': '🛡️', 'label': 'Aegis Shield'},
  {'icon': '⚔️', 'label': 'Valor Blade'},
  {'icon': '📜', 'label': 'Scholar Scroll'},
  {'icon': '👑', 'label': 'Sovereign Crown'},
  {'icon': '🏛️', 'label': 'Civic Pillar'},
  {'icon': '🧠', 'label': 'Sage Mind'},
  {'icon': '🔥', 'label': 'Ignis Flame'},
  {'icon': '💎', 'label': 'Crystal Gem'},
  {'icon': '⚖️', 'label': 'Justice Scale'},
  {'icon': '🌟', 'label': 'Nova Star'},
  {'icon': '🦉', 'label': 'Athena Owl'},
  {'icon': '🏆', 'label': 'Grand Trophy'},
];

/// Represents an Activity / Quest posted at the Reception Quest Counter.
class LobbyActivity {
  final String id;
  final String title;
  final String subject;
  final String activityUrl;
  final int xpReward;
  final String badgeName;
  final String badgeIcon;
  final String postedBy;
  final String createdAt;

  const LobbyActivity({
    required this.id,
    required this.title,
    required this.subject,
    required this.activityUrl,
    required this.xpReward,
    required this.badgeName,
    required this.badgeIcon,
    required this.postedBy,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'subject': subject,
        'activityUrl': activityUrl,
        'xpReward': xpReward,
        'badgeName': badgeName,
        'badgeIcon': badgeIcon,
        'postedBy': postedBy,
        'createdAt': createdAt,
      };

  factory LobbyActivity.fromJson(Map<String, dynamic> json) => LobbyActivity(
        id: json['id']?.toString() ?? '',
        title: json['title']?.toString() ?? '',
        subject: json['subject']?.toString() ?? 'GENERAL',
        activityUrl: json['activityUrl']?.toString() ?? '',
        xpReward: (json['xpReward'] is int)
            ? json['xpReward'] as int
            : int.tryParse(json['xpReward']?.toString() ?? '100') ?? 100,
        badgeName: json['badgeName']?.toString() ?? 'Quest Finisher',
        badgeIcon: json['badgeIcon']?.toString() ?? '🛡️',
        postedBy: json['postedBy']?.toString() ?? 'Faculty',
        createdAt: json['createdAt']?.toString() ?? '',
      );
}

/// Represents a Badge earned by a student from completing quests or chest milestones.
class LobbyBadge {
  final String id;
  final String badgeName;
  final String badgeIcon;
  final String subject;
  final String description;
  final String earnedAt;

  const LobbyBadge({
    required this.id,
    required this.badgeName,
    required this.badgeIcon,
    required this.subject,
    required this.description,
    required this.earnedAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'badgeName': badgeName,
        'badgeIcon': badgeIcon,
        'subject': subject,
        'description': description,
        'earnedAt': earnedAt,
      };

  factory LobbyBadge.fromJson(Map<String, dynamic> json) => LobbyBadge(
        id: json['id']?.toString() ?? '',
        badgeName: json['badgeName']?.toString() ?? '',
        badgeIcon: json['badgeIcon']?.toString() ?? '🏅',
        subject: json['subject']?.toString() ?? 'GENERAL',
        description: json['description']?.toString() ?? '',
        earnedAt: json['earnedAt']?.toString() ?? '',
      );
}

/// Represents a single review question inside a Reviewer (feeds the Small Mystery Chests).
class ReviewerQuestion {
  final String id;
  final String questionText;
  final List<String> options;
  final int correctIndex;
  final String subject;
  final String reviewerTitle;

  const ReviewerQuestion({
    required this.id,
    required this.questionText,
    required this.options,
    required this.correctIndex,
    required this.subject,
    required this.reviewerTitle,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'questionText': questionText,
        'options': options,
        'correctIndex': correctIndex,
        'subject': subject,
        'reviewerTitle': reviewerTitle,
      };

  factory ReviewerQuestion.fromJson(Map<String, dynamic> json) {
    final rawOptions = (json['options'] as List<dynamic>?) ?? const [];
    return ReviewerQuestion(
      id: json['id']?.toString() ?? '',
      questionText: json['questionText']?.toString() ?? '',
      options: rawOptions.map((e) => e.toString()).toList(),
      correctIndex: (json['correctIndex'] is int)
          ? json['correctIndex'] as int
          : int.tryParse(json['correctIndex']?.toString() ?? '0') ?? 0,
      subject: json['subject']?.toString() ?? '',
      reviewerTitle: json['reviewerTitle']?.toString() ?? '',
    );
  }
}

/// Represents a study reviewer inside a Subject-Labeled Large Treasure Chest.
class LobbyReviewerItem {
  final String id;
  final String title;
  final String studyNotes;
  final String resourceUrl;
  final List<ReviewerQuestion> questions;
  final String createdAt;

  const LobbyReviewerItem({
    required this.id,
    required this.title,
    required this.studyNotes,
    required this.resourceUrl,
    required this.questions,
    required this.createdAt,
  });

  LobbyReviewerItem copyWith({
    String? title,
    String? studyNotes,
    String? resourceUrl,
    List<ReviewerQuestion>? questions,
  }) {
    return LobbyReviewerItem(
      id: id,
      title: title ?? this.title,
      studyNotes: studyNotes ?? this.studyNotes,
      resourceUrl: resourceUrl ?? this.resourceUrl,
      questions: questions ?? this.questions,
      createdAt: createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'studyNotes': studyNotes,
        'resourceUrl': resourceUrl,
        'questions': questions.map((q) => q.toJson()).toList(),
        'createdAt': createdAt,
      };

  factory LobbyReviewerItem.fromJson(Map<String, dynamic> json) {
    final rawQuestions = (json['questions'] as List<dynamic>?) ?? const [];
    return LobbyReviewerItem(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      studyNotes: json['studyNotes']?.toString() ?? '',
      resourceUrl: json['resourceUrl']?.toString() ?? '',
      questions: rawQuestions
          .map((q) => ReviewerQuestion.fromJson(Map<String, dynamic>.from(q as Map)))
          .toList(),
      createdAt: json['createdAt']?.toString() ?? '',
    );
  }
}

/// Represents a Subject-Labeled Large Treasure Chest in the Reviewer Treasure Corner.
class SubjectChest {
  final String id;
  final String subjectName;
  final int colorValue;
  final List<LobbyReviewerItem> reviewers;

  const SubjectChest({
    required this.id,
    required this.subjectName,
    required this.colorValue,
    required this.reviewers,
  });

  SubjectChest copyWith({
    String? subjectName,
    int? colorValue,
    List<LobbyReviewerItem>? reviewers,
  }) {
    return SubjectChest(
      id: id,
      subjectName: subjectName ?? this.subjectName,
      colorValue: colorValue ?? this.colorValue,
      reviewers: reviewers ?? this.reviewers,
    );
  }

  int get totalQuestions =>
      reviewers.fold(0, (sum, r) => sum + r.questions.length);

  Map<String, dynamic> toJson() => {
        'id': id,
        'subjectName': subjectName,
        'colorValue': colorValue,
        'reviewers': reviewers.map((r) => r.toJson()).toList(),
      };

  factory SubjectChest.fromJson(Map<String, dynamic> json) {
    final rawReviewers = (json['reviewers'] as List<dynamic>?) ?? const [];
    return SubjectChest(
      id: json['id']?.toString() ?? '',
      subjectName: json['subjectName']?.toString() ?? 'SUBJECT',
      colorValue: (json['colorValue'] is int)
          ? json['colorValue'] as int
          : int.tryParse(json['colorValue']?.toString() ?? '0xFF10B981') ??
              0xFF10B981,
      reviewers: rawReviewers
          .map((r) => LobbyReviewerItem.fromJson(Map<String, dynamic>.from(r as Map)))
          .toList(),
    );
  }
}

/// Persistent student progress inside the School Lobby (XP, Badges, Completed Quests, Chest Cooldowns).
class StudentLobbyProgress {
  final String studentId;
  final int xp;
  final Set<String> launchedActivityIds;
  final Set<String> completedActivityIds;
  final List<LobbyBadge> earnedBadges;
  final String? equippedBadgeId;
  final Set<String> answeredQuestionIds;
  final int smallChestCorrectCount;
  final Map<String, int> smallChestCooldownUntilMs;

  const StudentLobbyProgress({
    required this.studentId,
    this.xp = 0,
    this.launchedActivityIds = const {},
    this.completedActivityIds = const {},
    this.earnedBadges = const [],
    this.equippedBadgeId,
    this.answeredQuestionIds = const {},
    this.smallChestCorrectCount = 0,
    this.smallChestCooldownUntilMs = const {},
  });

  int get level => (xp ~/ 100) + 1;
  int get xpIntoCurrentLevel => xp % 100;

  LobbyBadge? get equippedBadge {
    if (equippedBadgeId == null || equippedBadgeId!.isEmpty) return null;
    for (final b in earnedBadges) {
      if (b.id == equippedBadgeId) return b;
    }
    return earnedBadges.isNotEmpty ? earnedBadges.first : null;
  }

  StudentLobbyProgress copyWith({
    int? xp,
    Set<String>? launchedActivityIds,
    Set<String>? completedActivityIds,
    List<LobbyBadge>? earnedBadges,
    String? equippedBadgeId,
    bool clearEquippedBadge = false,
    Set<String>? answeredQuestionIds,
    int? smallChestCorrectCount,
    Map<String, int>? smallChestCooldownUntilMs,
  }) {
    return StudentLobbyProgress(
      studentId: studentId,
      xp: xp ?? this.xp,
      launchedActivityIds: launchedActivityIds ?? this.launchedActivityIds,
      completedActivityIds: completedActivityIds ?? this.completedActivityIds,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      equippedBadgeId:
          clearEquippedBadge ? null : (equippedBadgeId ?? this.equippedBadgeId),
      answeredQuestionIds: answeredQuestionIds ?? this.answeredQuestionIds,
      smallChestCorrectCount:
          smallChestCorrectCount ?? this.smallChestCorrectCount,
      smallChestCooldownUntilMs:
          smallChestCooldownUntilMs ?? this.smallChestCooldownUntilMs,
    );
  }

  Map<String, dynamic> toJson() => {
        'studentId': studentId,
        'xp': xp,
        'launchedActivityIds': launchedActivityIds.toList(),
        'completedActivityIds': completedActivityIds.toList(),
        'earnedBadges': earnedBadges.map((b) => b.toJson()).toList(),
        'equippedBadgeId': equippedBadgeId,
        'answeredQuestionIds': answeredQuestionIds.toList(),
        'smallChestCorrectCount': smallChestCorrectCount,
        'smallChestCooldownUntilMs': smallChestCooldownUntilMs,
      };

  factory StudentLobbyProgress.fromJson(Map<String, dynamic> json) {
    final rawLaunched = (json['launchedActivityIds'] as List<dynamic>?) ?? const [];
    final rawCompleted =
        (json['completedActivityIds'] as List<dynamic>?) ?? const [];
    final rawBadges = (json['earnedBadges'] as List<dynamic>?) ?? const [];
    final rawAnswered = (json['answeredQuestionIds'] as List<dynamic>?) ?? const [];
    final rawCooldowns =
        (json['smallChestCooldownUntilMs'] as Map<String, dynamic>?) ?? const {};

    return StudentLobbyProgress(
      studentId: json['studentId']?.toString() ?? 'guest',
      xp: (json['xp'] is int) ? json['xp'] as int : 0,
      launchedActivityIds: rawLaunched.map((e) => e.toString()).toSet(),
      completedActivityIds: rawCompleted.map((e) => e.toString()).toSet(),
      earnedBadges: rawBadges
          .map((b) => LobbyBadge.fromJson(Map<String, dynamic>.from(b as Map)))
          .toList(),
      equippedBadgeId: json['equippedBadgeId']?.toString(),
      answeredQuestionIds: rawAnswered.map((e) => e.toString()).toSet(),
      smallChestCorrectCount: (json['smallChestCorrectCount'] is int)
          ? json['smallChestCorrectCount'] as int
          : 0,
      smallChestCooldownUntilMs: rawCooldowns.map(
        (k, v) => MapEntry(k, (v is int) ? v : int.tryParse(v.toString()) ?? 0),
      ),
    );
  }
}

/// Centralized Data Service (`lobbyDataService`) for the School Lobby RPG mechanics.
/// Stores Activities, Subject Chests, Reviewer Question Pool, and Student Progress
/// in SharedPreferences with rich initial seed data ready for Firebase/Google Sheets sync.
class LobbyDataService extends ChangeNotifier {
  static final LobbyDataService instance = LobbyDataService._();
  LobbyDataService._();

  static const String _kActivitiesKey = 'mis_lobby_activities_v1';
  static const String _kSubjectChestsKey = 'mis_lobby_subject_chests_v1';
  static const String _kStudentProgressPrefix = 'mis_lobby_progress_v1_';

  static const int kSmallChestCooldownMs = 2 * 60 * 1000; // 2 minutes
  static const int kSmallChestXpReward = 20;
  static const int kTreasureHunterTarget = 5;

  bool _initialized = false;
  List<LobbyActivity> _activities = [];
  List<SubjectChest> _subjectChests = [];
  StudentLobbyProgress _progress = const StudentLobbyProgress(studentId: 'guest');

  bool get isInitialized => _initialized;
  List<LobbyActivity> get activities => List.unmodifiable(_activities);
  List<SubjectChest> get subjectChests => List.unmodifiable(_subjectChests);
  StudentLobbyProgress get progress => _progress;

  /// All available subject names from the Large Subject Chests.
  List<String> get subjectNames =>
      _subjectChests.map((c) => c.subjectName).toList();

  /// Combined Reviewer Question Pool across all Subject Chests.
  List<ReviewerQuestion> get allReviewerQuestions {
    final pool = <ReviewerQuestion>[];
    for (final chest in _subjectChests) {
      for (final reviewer in chest.reviewers) {
        for (final q in reviewer.questions) {
          pool.add(ReviewerQuestion(
            id: q.id,
            questionText: q.questionText,
            options: q.options,
            correctIndex: q.correctIndex,
            subject: chest.subjectName,
            reviewerTitle: reviewer.title,
          ));
        }
      }
    }
    return pool;
  }

  /// Initializes the service and loads persisted data (or populates rich seed data).
  Future<void> init(String userId) async {
    final prefs = await SharedPreferences.getInstance();

    // 1. Load or seed Activities
    final rawActivities = prefs.getString(_kActivitiesKey);
    if (rawActivities != null && rawActivities.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawActivities) as List<dynamic>;
        _activities = decoded
            .map((e) => LobbyActivity.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        _activities = _seedActivities();
      }
    } else {
      _activities = _seedActivities();
      await _saveActivities(prefs);
    }

    // 2. Load or seed Subject Chests
    final rawChests = prefs.getString(_kSubjectChestsKey);
    if (rawChests != null && rawChests.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawChests) as List<dynamic>;
        _subjectChests = decoded
            .map((e) => SubjectChest.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
      } catch (_) {
        _subjectChests = _seedSubjectChests();
      }
    } else {
      _subjectChests = _seedSubjectChests();
      await _saveSubjectChests(prefs);
    }

    // 3. Load Student Progress for this user
    final cleanId = userId.trim().isEmpty ? 'guest' : userId.trim();
    final rawProgress = prefs.getString('$_kStudentProgressPrefix$cleanId');
    if (rawProgress != null && rawProgress.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawProgress) as Map<String, dynamic>;
        _progress = StudentLobbyProgress.fromJson(decoded);
      } catch (_) {
        _progress = StudentLobbyProgress(studentId: cleanId);
      }
    } else {
      _progress = StudentLobbyProgress(studentId: cleanId);
    }

    _initialized = true;
    notifyListeners();
  }

  Future<void> _saveActivities([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _kActivitiesKey,
      jsonEncode(_activities.map((a) => a.toJson()).toList()),
    );
  }

  Future<void> _saveSubjectChests([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      _kSubjectChestsKey,
      jsonEncode(_subjectChests.map((c) => c.toJson()).toList()),
    );
  }

  Future<void> _saveProgress([SharedPreferences? prefs]) async {
    final p = prefs ?? await SharedPreferences.getInstance();
    await p.setString(
      '$_kStudentProgressPrefix${_progress.studentId}',
      jsonEncode(_progress.toJson()),
    );
  }

  // ---------------------------------------------------------------------------
  // FEATURE 1: QUEST COUNTER (TEACHER POST ACTIVITY & STUDENT BADGE SYSTEM)
  // ---------------------------------------------------------------------------

  /// Teacher posts a new Quest / Activity at the Quest Counter.
  Future<LobbyActivity> postActivity({
    required String title,
    required String subject,
    required String activityUrl,
    required int xpReward,
    required String badgeName,
    required String badgeIcon,
    required String postedBy,
  }) async {
    final activity = LobbyActivity(
      id: 'act_${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      subject: subject.trim().toUpperCase(),
      activityUrl: activityUrl.trim(),
      xpReward: xpReward,
      badgeName: badgeName.trim(),
      badgeIcon: badgeIcon,
      postedBy: postedBy,
      createdAt: DateTime.now().toIso8601String(),
    );
    _activities = [activity, ..._activities];
    await _saveActivities();
    notifyListeners();
    return activity;
  }

  /// Teacher deletes an activity if needed.
  Future<void> deleteActivity(String activityId) async {
    _activities = _activities.where((a) => a.id != activityId).toList();
    await _saveActivities();
    notifyListeners();
  }

  /// Student clicks "Launch Activity" — unlocks the "Mark as Done" button.
  Future<void> markActivityLaunched(String activityId) async {
    final updated = Set<String>.from(_progress.launchedActivityIds)..add(activityId);
    _progress = _progress.copyWith(launchedActivityIds: updated);
    await _saveProgress();
    notifyListeners();
  }

  /// Student clicks "Mark as Done" — awards XP and unlocks the Activity's Badge.
  /// Returns the newly earned [LobbyBadge] (or null if already completed).
  Future<LobbyBadge?> completeActivity(LobbyActivity activity) async {
    if (_progress.completedActivityIds.contains(activity.id)) {
      return null;
    }

    final updatedCompleted = Set<String>.from(_progress.completedActivityIds)
      ..add(activity.id);
    final newBadge = LobbyBadge(
      id: 'badge_${activity.id}',
      badgeName: activity.badgeName,
      badgeIcon: activity.badgeIcon,
      subject: activity.subject,
      description: 'Completed "${activity.title}" in ${activity.subject}',
      earnedAt: DateTime.now().toIso8601String(),
    );

    final updatedBadges = List<LobbyBadge>.from(_progress.earnedBadges);
    if (!updatedBadges.any((b) => b.id == newBadge.id)) {
      updatedBadges.insert(0, newBadge);
    }

    final shouldAutoEquip = _progress.equippedBadgeId == null ||
        _progress.equippedBadgeId!.isEmpty;

    _progress = _progress.copyWith(
      xp: _progress.xp + activity.xpReward,
      completedActivityIds: updatedCompleted,
      earnedBadges: updatedBadges,
      equippedBadgeId: shouldAutoEquip ? newBadge.id : _progress.equippedBadgeId,
    );
    await _saveProgress();
    notifyListeners();
    return newBadge;
  }

  /// Student equips (or unequips) a primary badge icon next to their floating avatar nameplate.
  Future<void> equipBadge(String? badgeId) async {
    if (badgeId == null || badgeId.isEmpty) {
      _progress = _progress.copyWith(clearEquippedBadge: true);
    } else {
      _progress = _progress.copyWith(equippedBadgeId: badgeId);
    }
    await _saveProgress();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // FEATURE 2: SUBJECT-LABELED LARGE TREASURE CHESTS (REVIEWER VAULTS)
  // ---------------------------------------------------------------------------

  SubjectChest? getChestById(String chestId) {
    for (final c in _subjectChests) {
      if (c.id == chestId) return c;
    }
    return null;
  }

  /// Teacher renames an existing Subject Chest or updates its banner color.
  Future<void> updateSubjectChest({
    required String chestId,
    required String newSubjectName,
    int? colorValue,
  }) async {
    _subjectChests = _subjectChests.map((c) {
      if (c.id != chestId) return c;
      return c.copyWith(
        subjectName: newSubjectName.trim().toUpperCase(),
        colorValue: colorValue ?? c.colorValue,
      );
    }).toList();
    await _saveSubjectChests();
    notifyListeners();
  }

  /// Teacher adds a brand-new Subject Chest to the Reviewer Treasure Corner.
  Future<SubjectChest> addSubjectChest({
    required String subjectName,
    required int colorValue,
  }) async {
    final chest = SubjectChest(
      id: 'chest_${DateTime.now().millisecondsSinceEpoch}',
      subjectName: subjectName.trim().toUpperCase(),
      colorValue: colorValue,
      reviewers: const [],
    );
    _subjectChests = [..._subjectChests, chest];
    await _saveSubjectChests();
    notifyListeners();
    return chest;
  }

  /// Teacher adds a new Reviewer item (with optional initial questions) inside a Subject Chest.
  Future<LobbyReviewerItem> addReviewerToChest({
    required String chestId,
    required String title,
    required String studyNotes,
    required String resourceUrl,
    List<ReviewerQuestion> questions = const [],
  }) async {
    final chest = getChestById(chestId);
    final subjectName = chest?.subjectName ?? 'GENERAL';
    final reviewerId = 'rev_${DateTime.now().millisecondsSinceEpoch}';

    final normalizedQuestions = questions
        .asMap()
        .entries
        .map((entry) => ReviewerQuestion(
              id: entry.value.id.isNotEmpty
                  ? entry.value.id
                  : '${reviewerId}_q${entry.key}',
              questionText: entry.value.questionText,
              options: entry.value.options,
              correctIndex: entry.value.correctIndex,
              subject: subjectName,
              reviewerTitle: title.trim(),
            ))
        .toList();

    final newItem = LobbyReviewerItem(
      id: reviewerId,
      title: title.trim(),
      studyNotes: studyNotes.trim(),
      resourceUrl: resourceUrl.trim(),
      questions: normalizedQuestions,
      createdAt: DateTime.now().toIso8601String(),
    );

    _subjectChests = _subjectChests.map((c) {
      if (c.id != chestId) return c;
      return c.copyWith(reviewers: [newItem, ...c.reviewers]);
    }).toList();

    await _saveSubjectChests();
    notifyListeners();
    return newItem;
  }

  /// Teacher adds one or more review questions to an existing Reviewer inside a Subject Chest.
  Future<void> addQuestionsToReviewer({
    required String chestId,
    required String reviewerId,
    required List<ReviewerQuestion> newQuestions,
  }) async {
    _subjectChests = _subjectChests.map((c) {
      if (c.id != chestId) return c;
      final updatedReviewers = c.reviewers.map((r) {
        if (r.id != reviewerId) return r;
        final stamped = newQuestions
            .asMap()
            .entries
            .map((e) => ReviewerQuestion(
                  id: 'q_${DateTime.now().millisecondsSinceEpoch}_${e.key}',
                  questionText: e.value.questionText,
                  options: e.value.options,
                  correctIndex: e.value.correctIndex,
                  subject: c.subjectName,
                  reviewerTitle: r.title,
                ))
            .toList();
        return r.copyWith(questions: [...r.questions, ...stamped]);
      }).toList();
      return c.copyWith(reviewers: updatedReviewers);
    }).toList();

    await _saveSubjectChests();
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // FEATURE 3: SMALL MYSTERY CHESTS (RANDOM POP-QUIZ & 2-MINUTE COOLDOWN)
  // ---------------------------------------------------------------------------

  /// Checks whether a Small Mystery Chest (`small_chest_1..4`) is currently on cooldown.
  bool isSmallChestOnCooldown(String smallChestId, [int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final until = _progress.smallChestCooldownUntilMs[smallChestId] ?? 0;
    return until > now;
  }

  /// Remaining cooldown seconds for a Small Mystery Chest (0 if ready).
  int smallChestRemainingSeconds(String smallChestId, [int? nowMs]) {
    final now = nowMs ?? DateTime.now().millisecondsSinceEpoch;
    final until = _progress.smallChestCooldownUntilMs[smallChestId] ?? 0;
    if (until <= now) return 0;
    return ((until - now) / 1000).ceil();
  }

  /// Pulls 1 random unanswered question from the combined Reviewer Question Pool
  /// (or any random question if the student has answered all available questions).
  ReviewerQuestion? drawRandomMysteryQuestion() {
    final pool = allReviewerQuestions;
    if (pool.isEmpty) return null;

    final unanswered = pool
        .where((q) => !_progress.answeredQuestionIds.contains(q.id))
        .toList();
    final source = unanswered.isNotEmpty ? unanswered : pool;
    final rng = math.Random();
    return source[rng.nextInt(source.length)];
  }

  /// Records a correct answer on a Small Mystery Chest:
  /// - Awards +20 bonus XP
  /// - Puts `smallChestId` on a 2-minute cooldown
  /// - Tracks progress toward the "Treasure Hunter" (`🏆`) badge (unlocked at 5 correct answers)
  /// Returns the newly unlocked "Treasure Hunter" badge if this answer hit the milestone!
  Future<LobbyBadge?> recordSmallChestSuccess({
    required String smallChestId,
    required ReviewerQuestion question,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedCooldowns =
        Map<String, int>.from(_progress.smallChestCooldownUntilMs)
          ..[smallChestId] = now + kSmallChestCooldownMs;

    final updatedAnswered = Set<String>.from(_progress.answeredQuestionIds)
      ..add(question.id);
    final newCount = _progress.smallChestCorrectCount + 1;

    LobbyBadge? unlockedBadge;
    final updatedBadges = List<LobbyBadge>.from(_progress.earnedBadges);
    const treasureHunterId = 'badge_treasure_hunter';
    final alreadyHasTreasureHunter =
        updatedBadges.any((b) => b.id == treasureHunterId);

    if (newCount >= kTreasureHunterTarget && !alreadyHasTreasureHunter) {
      unlockedBadge = LobbyBadge(
        id: treasureHunterId,
        badgeName: 'Treasure Hunter',
        badgeIcon: '🏆',
        subject: 'ALL SUBJECTS',
        description:
            'Solved $kTreasureHunterTarget Small Mystery Chest pop-quizzes in the School Lobby!',
        earnedAt: DateTime.now().toIso8601String(),
      );
      updatedBadges.insert(0, unlockedBadge);
    }

    _progress = _progress.copyWith(
      xp: _progress.xp + kSmallChestXpReward,
      answeredQuestionIds: updatedAnswered,
      smallChestCorrectCount: newCount,
      smallChestCooldownUntilMs: updatedCooldowns,
      earnedBadges: updatedBadges,
      equippedBadgeId: (_progress.equippedBadgeId == null && unlockedBadge != null)
          ? unlockedBadge.id
          : _progress.equippedBadgeId,
    );

    await _saveProgress();
    notifyListeners();
    return unlockedBadge;
  }

  // ---------------------------------------------------------------------------
  // SAMPLE SEED DATA (FOR IMMEDIATE TESTING OF TEACHER & STUDENT FLOWS)
  // ---------------------------------------------------------------------------

  List<LobbyActivity> _seedActivities() => [
        const LobbyActivity(
          id: 'seed_act_ppg_1',
          title: 'Unit 2 Policy & Governance Case Analysis',
          subject: 'PPG',
          activityUrl:
              'https://www.officialgazette.gov.ph/constitutions/1987-constitution/',
          xpReward: 100,
          badgeName: 'Policy Vanguard',
          badgeIcon: '🏛️',
          postedBy: 'Sir Jim Mark',
          createdAt: '2026-11-01T08:00:00Z',
        ),
        const LobbyActivity(
          id: 'seed_act_ucsp_1',
          title: 'Cultural Relativism & Ethnocentrism Field Reflection',
          subject: 'UCSP',
          activityUrl: 'https://en.wikipedia.org/wiki/Cultural_relativism',
          xpReward: 120,
          badgeName: 'Social Scientist',
          badgeIcon: '🛡️',
          postedBy: 'Sir Jim Mark',
          createdAt: '2026-11-01T09:00:00Z',
        ),
        const LobbyActivity(
          id: 'seed_act_philo_1',
          title: 'Socratic Dialogue: Methods of Philosophizing',
          subject: 'PHILO',
          activityUrl: 'https://plato.stanford.edu/entries/socrates/',
          xpReward: 100,
          badgeName: 'Sage Philosopher',
          badgeIcon: '🦉',
          postedBy: 'Sir Jim Mark',
          createdAt: '2026-11-01T10:00:00Z',
        ),
        const LobbyActivity(
          id: 'seed_act_kas_1',
          title: 'Primary Sources of the 1896 Philippine Revolution',
          subject: 'KASAYSAYAN',
          activityUrl: 'https://nhcp.gov.ph/',
          xpReward: 150,
          badgeName: 'Katipunan Chronicler',
          badgeIcon: '📜',
          postedBy: 'Sir Jim Mark',
          createdAt: '2026-11-01T11:00:00Z',
        ),
      ];

  List<SubjectChest> _seedSubjectChests() => [
        const SubjectChest(
          id: 'chest_ucsp',
          subjectName: 'UCSP',
          colorValue: 0xFF10B981, // Emerald
          reviewers: [
            LobbyReviewerItem(
              id: 'rev_ucsp_1',
              title: 'Culture, Society & Cultural Relativism',
              studyNotes:
                  '• Culture refers to that complex whole which encompasses beliefs, practices, values, attitudes, laws, norms, artifacts, symbols, and knowledge.\n'
                  '• Ethnocentrism is judging another culture solely by the values and standards of one\'s own culture.\n'
                  '• Cultural Relativism is the principle that an individual\'s beliefs and activities should be understood by others in terms of that individual\'s own culture.\n'
                  '• Socialization is the lifelong process through which people learn the values and norms of a given society.',
              resourceUrl: 'https://en.wikipedia.org/wiki/Culture',
              createdAt: '2026-11-01T08:00:00Z',
              questions: [
                ReviewerQuestion(
                  id: 'q_ucsp_1',
                  questionText:
                      'Which concept refers to understanding a group\'s beliefs and practices within the context of their own culture rather than judging them by external standards?',
                  options: [
                    'Ethnocentrism',
                    'Cultural Relativism',
                    'Xenocentrism',
                    'Cultural Lag',
                  ],
                  correctIndex: 1,
                  subject: 'UCSP',
                  reviewerTitle: 'Culture, Society & Cultural Relativism',
                ),
                ReviewerQuestion(
                  id: 'q_ucsp_2',
                  questionText:
                      'What do we call the lifelong process of learning the norms, customs, and ideologies of one\'s society?',
                  options: [
                    'Stratification',
                    'Socialization',
                    'Industrialization',
                    'Bureaucratization',
                  ],
                  correctIndex: 1,
                  subject: 'UCSP',
                  reviewerTitle: 'Culture, Society & Cultural Relativism',
                ),
              ],
            ),
          ],
        ),
        const SubjectChest(
          id: 'chest_ppg',
          subjectName: 'PPG',
          colorValue: 0xFF3B82F6, // Royal Blue
          reviewers: [
            LobbyReviewerItem(
              id: 'rev_ppg_1',
              title: 'State Elements, Power & Three Branches of Government',
              studyNotes:
                  '• Four Essential Elements of a State: People, Territory, Government, and Sovereignty.\n'
                  '• Three Inherent Powers of the State: Police Power, Power of Eminent Domain, and Power of Taxation.\n'
                  '• Executive Branch: Enforces and administers laws (headed by the President).\n'
                  '• Legislative Branch: Makes, alters, and repeals laws (Congress: Senate & House of Representatives).\n'
                  '• Judicial Branch: Interprets laws and settles legal controversies (Supreme Court & lower courts).',
              resourceUrl:
                  'https://www.officialgazette.gov.ph/about/gov/',
              createdAt: '2026-11-01T08:30:00Z',
              questions: [
                ReviewerQuestion(
                  id: 'q_ppg_1',
                  questionText:
                      'Which of the following is NOT one of the four essential elements of a State?',
                  options: [
                    'People',
                    'Sovereignty',
                    'Political Party',
                    'Territory',
                  ],
                  correctIndex: 2,
                  subject: 'PPG',
                  reviewerTitle:
                      'State Elements, Power & Three Branches of Government',
                ),
                ReviewerQuestion(
                  id: 'q_ppg_2',
                  questionText:
                      'Which inherent power of the State allows the government to take private property for public use upon payment of just compensation?',
                  options: [
                    'Police Power',
                    'Power of Taxation',
                    'Eminent Domain',
                    'Executive Privilege',
                  ],
                  correctIndex: 2,
                  subject: 'PPG',
                  reviewerTitle:
                      'State Elements, Power & Three Branches of Government',
                ),
              ],
            ),
          ],
        ),
        const SubjectChest(
          id: 'chest_philo',
          subjectName: 'PHILO',
          colorValue: 0xFFA855F7, // Purple
          reviewers: [
            LobbyReviewerItem(
              id: 'rev_philo_1',
              title: 'Holistic Perspective, Truth vs. Opinion & Fallacies',
              studyNotes:
                  '• Holistic Thinking looks at the "big picture" and considers all aspects of a situation, whereas Partial Thinking focuses on specific parts.\n'
                  '• Socrates: "The unexamined life is not worth living." Uses the Socratic Method (elenchus).\n'
                  '• Ad Hominem: Attacking the person instead of addressing their argument.\n'
                  '• Appeal to Force (Ad Baculum): Using threat or force to advance an argument.',
              resourceUrl: 'https://plato.stanford.edu/',
              createdAt: '2026-11-01T09:00:00Z',
              questions: [
                ReviewerQuestion(
                  id: 'q_philo_1',
                  questionText:
                      'Which philosopher famously declared that "The unexamined life is not worth living"?',
                  options: [
                    'Aristotle',
                    'Socrates',
                    'René Descartes',
                    'Immanuel Kant',
                  ],
                  correctIndex: 1,
                  subject: 'PHILO',
                  reviewerTitle:
                      'Holistic Perspective, Truth vs. Opinion & Fallacies',
                ),
                ReviewerQuestion(
                  id: 'q_philo_2',
                  questionText:
                      'What logical fallacy occurs when someone attacks the character or motive of a person instead of refuting their actual argument?',
                  options: [
                    'Appeal to Pity (Ad Misericordiam)',
                    'Argumentum Ad Hominem',
                    'False Dilemma',
                    'Slippery Slope',
                  ],
                  correctIndex: 1,
                  subject: 'PHILO',
                  reviewerTitle:
                      'Holistic Perspective, Truth vs. Opinion & Fallacies',
                ),
              ],
            ),
          ],
        ),
        const SubjectChest(
          id: 'chest_kasaysayan',
          subjectName: 'KASAYSAYAN',
          colorValue: 0xFFF59E0B, // Amber Gold
          reviewers: [
            LobbyReviewerItem(
              id: 'rev_kas_1',
              title: 'Kartilya ng Katipunan & Cry of Pugad Lawin',
              studyNotes:
                  '• Kataastaasan, Kagalanggalangang Katipunan ng mga Anak ng Bayan (KKK) was founded on July 7, 1892 by Andres Bonifacio, Valentin Diaz, Teodoro Plata, Ladislao Diwa, and Deodato Arellano.\n'
                  '• Emilio Jacinto ("Utak ng Katipunan") authored the Kartilya ng Katipunan, a 14-point guidebook for Katipuneros.\n'
                  '• The tearing of cedulas during the Cry of Pugad Lawin / Balintawak in August 1896 symbolized the Filipinos\' definitive break from Spanish colonial rule.',
              resourceUrl: 'https://nhcp.gov.ph/',
              createdAt: '2026-11-01T09:30:00Z',
              questions: [
                ReviewerQuestion(
                  id: 'q_kas_1',
                  questionText:
                      'Who authored the "Kartilya ng Katipunan" and became known as the "Utak ng Katipunan"?',
                  options: [
                    'Apolinario Mabini',
                    'Emilio Jacinto',
                    'Marcelo H. del Pilar',
                    'Gregorio del Pilar',
                  ],
                  correctIndex: 1,
                  subject: 'KASAYSAYAN',
                  reviewerTitle: 'Kartilya ng Katipunan & Cry of Pugad Lawin',
                ),
                ReviewerQuestion(
                  id: 'q_kas_2',
                  questionText:
                      'What document did the Katipuneros tear during the August 1896 uprising as a symbol of defying Spanish colonial authority?',
                  options: [
                    'Cedula Personal',
                    'Treaty of Paris',
                    'Acta de Tejeros',
                    'La Solidaridad',
                  ],
                  correctIndex: 0,
                  subject: 'KASAYSAYAN',
                  reviewerTitle: 'Kartilya ng Katipunan & Cry of Pugad Lawin',
                ),
              ],
            ),
          ],
        ),
      ];
}
