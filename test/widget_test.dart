import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_portal_app/config/app_config.dart';
import 'package:student_portal_app/models/portal_models.dart';
import 'package:student_portal_app/screens/auth_screen.dart';
import 'package:student_portal_app/screens/teacher_scanner_screen.dart';
import 'package:student_portal_app/services/session_service.dart';
import 'package:student_portal_app/utils/reviewer_outline_extractor.dart';
import 'package:student_portal_app/widgets/student_qr_generator.dart';
import 'package:student_portal_app/school_lobby/lobby_data_service.dart';
import 'package:student_portal_app/school_lobby/school_lobby_avatar.dart';
import 'package:student_portal_app/school_lobby/school_lobby_config.dart';
import 'package:student_portal_app/school_lobby/school_lobby_engine.dart';
import 'package:student_portal_app/theme/portal_theme.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SessionService.instance.resetMemoryCacheForTesting();
  });

  test(
    'Scanner anti-burst lag time is set to 1.5 seconds (1500ms) and app is MIS-SHS Learner App',
    () {
      expect(TeacherScannerScreen.scanLagDurationMs, 1500);
      expect(AppConfig.appName, 'MIS-SHS Learner App');
    },
  );

  test(
    'SessionService persists student login across app restarts when Stay Signed In is enabled',
    () async {
      const student = UserSession(
        id: '2024-00142',
        name: 'Juan Dela Cruz',
        isFaculty: false,
        subjects: [SubjectItem(code: 'PHILO', name: 'Philosophy')],
      );

      await SessionService.instance.saveSession(student, staySignedIn: true);

      // Simulate closing the app completely and cold-starting again
      SessionService.instance.resetMemoryCacheForTesting();
      final restored = await SessionService.instance.restoreSession();

      expect(restored, isNotNull);
      expect(restored!.id, '2024-00142');
      expect(restored.name, 'Juan Dela Cruz');
      expect(await SessionService.instance.getLastStudentId(), '2024-00142');

      // When Stay Signed In is unchecked, closing the app clears the persisted session
      await SessionService.instance.saveSession(student, staySignedIn: false);
      SessionService.instance.resetMemoryCacheForTesting();
      final afterClose = await SessionService.instance.restoreSession();
      expect(afterClose, isNull);
    },
  );

  test(
    'StudentQrGenerator builds clean local Student ID QR payloads and filenames without Drive',
    () {
      expect(
        StudentQrGenerator.normalizePayload('  2024-00142  '),
        '2024-00142',
      );
      expect(
        StudentQrGenerator.buildQrFileName('2024-00142'),
        'MIS_SHS_QR_2024-00142.png',
      );
    },
  );

  test(
    'ScanLogEntry enforces Points_Awarded = 1 for recitation and null for attendance',
    () {
      final att = ScanLogEntry.create(
        mode: ScanMode.attendance,
        timestamp: '2026-11-01 08:00:00',
        studentId: '2024-00142',
        subject: 'PHILO',
      );
      expect(att.logId.startsWith('ATT-'), isTrue);
      expect(att.pointsAwarded, isNull);
      expect(att.toSyncJson().containsKey('pointsAwarded'), isFalse);

      final rec = ScanLogEntry.create(
        mode: ScanMode.recitation,
        timestamp: '2026-11-01 08:05:00',
        studentId: '2024-00142',
        subject: 'PHILO',
      );
      expect(rec.logId.startsWith('REC-'), isTrue);
      expect(rec.pointsAwarded, 1);
      expect(rec.toSyncJson()['pointsAwarded'], 1);
    },
  );

  test(
    'UserSession preserves Faculty access and scannerAuthToken across JSON serialization',
    () {
      const session = UserSession(
        id: 'FAC-001',
        name: 'Prof. Reyes',
        isFaculty: true,
        subjects: [SubjectItem(code: 'PHILO', name: 'Philosophy')],
        scannerAuthToken: 'test-hmac-token',
      );

      final restored = UserSession.fromJson(session.toJson());
      expect(restored.isFaculty, isTrue);
      expect(restored.scannerAuthToken, 'test-hmac-token');
      expect(restored.subjects.first.code, 'PHILO');
    },
  );

  test(
    'ReviewerOutlineExtractor strips HTML/CSS/JS/nav chrome and preserves clean discussion outline',
    () {
      const sampleDeckHtml = '''
<!DOCTYPE html>
<html>
<head>
  <title>W1 - Introduction to Philosophy</title>
  <style>
    body { background: #111; color: #fff; }
    .slide { display: flex; }
  </style>
  <script>
    const totalSlides = 2;
    function nextSlide() { document.getElementById('s2').classList.add('active'); }
  </script>
</head>
<body>
  <div id="nav-panel"><button id="btnPrev">Previous</button><button id="btnNext">Next</button></div>
  <div class="slide active">
    <h1>Branches of Philosophy</h1>
    <p>Philosophy examines existence, knowledge &amp; ethics.</p>
    <ul>
      <li><strong>Metaphysics</strong> &mdash; study of ultimate reality</li>
      <li><strong>Epistemology</strong> &mdash; theory of knowledge</li>
    </ul>
    <div>1 / 2</div>
  </div>
  <div class="slide">
    <h2>Socratic Method</h2>
    <p>Disciplined questioning used to examine foundational beliefs.</p>
  </div>
</body>
</html>
''';

      final txt = ReviewerOutlineExtractor.extractOutline(
        rawHtml: sampleDeckHtml,
        reviewerTitle: 'W1_Philosophy_Deck.html',
        subjectName: 'Introduction to the Philosophy of the Human Person',
        generatedAt: DateTime(2026, 11, 1, 9, 30),
      );

      expect(txt.contains('MIS-SHS LEARNER APP'), isTrue);
      expect(txt.contains('BRANCHES OF PHILOSOPHY'), isTrue);
      expect(
        txt.contains('Philosophy examines existence, knowledge & ethics.'),
        isTrue,
      );
      expect(txt.contains('• Metaphysics — study of ultimate reality'), isTrue);
      expect(txt.contains('▸ Socratic Method'), isTrue);
      expect(txt.contains('[PART 1 OF 2]'), isTrue);
      expect(txt.contains('[PART 2 OF 2]'), isTrue);

      // Ensure zero HTML/CSS/JS/UI chrome leaked into the .txt outline
      expect(txt.contains('<div'), isFalse);
      expect(txt.contains('background: #111'), isFalse);
      expect(txt.contains('nextSlide'), isFalse);
      expect(txt.contains('1 / 2'), isFalse);
      expect(
        ReviewerOutlineExtractor.buildTxtFileName('W1 Philosophy.html'),
        'W1_Philosophy_Outline.txt',
      );
    },
  );

  testWidgets(
    'AuthScreen displays MIS-SHS Learner App, Stay Signed In checkbox, and hides endpoint button',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: AuthScreen(
            onAuthenticated: (_) {},
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.settings_ethernet_rounded), findsNothing);
      expect(find.text('Stay signed in on this device'), findsOneWidget);
      expect(find.text('SIGN IN TO PORTAL'), findsOneWidget);
    },
  );

  testWidgets(
    'StudentQrPassDialog renders local QR code directly from Student ID',
    (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: StudentQrPassDialog(
              studentId: '2024-00142',
              studentName: 'Maria Clara',
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(QrImageView), findsOneWidget);
      expect(find.text('STUDENT ID: 2024-00142'), findsOneWidget);
      expect(find.text('Maria Clara'), findsOneWidget);
    },
  );

  test(
    'School Lobby Phase 1 & 2: Avatar looks, A* NavGrid, Quest Counter badges, Subject Chests & Small Mystery Chests',
    () async {
      // 1. Avatar Look String serialization & frame index
      const customLook = LobbyAvatarLook(
        isPreset: false,
        body: '3',
        eyes: '2',
        outfit: '10-2',
        hair: '17-4',
        glasses: '15-1',
        hat: 'none',
        bag: '3-6',
      );
      final encoded = customLook.toLookString();
      expect(encoded, 'body.3/eyes.2/outfit.10-2/hair.17-4/glasses.15-1/bag.3-6');
      final parsed = LobbyAvatarLook.fromLookString(encoded);
      expect(parsed.isPreset, isFalse);
      expect(parsed.outfit, '10-2');
      expect(parsed.glasses, '15-1');
      expect(
        computeCharacterFrameIndex(
          facing: AvatarFacing.down,
          isWalking: true,
          stepFrame: 0,
        ),
        42,
      );

      // 2. LobbyDataService initialization & seed data
      final service = LobbyDataService.instance;
      await service.init('2024-00142');
      expect(service.isInitialized, isTrue);
      expect(service.subjectNames, containsAll(['UCSP', 'PPG', 'PHILO', 'KASAYSAYAN']));
      expect(service.allReviewerQuestions.length, greaterThanOrEqualTo(8));

      // 3. Teacher posts an activity -> Student launches & marks as done -> Badge & XP unlocked
      final posted = await service.postActivity(
        title: 'Unit 3 Constitutional Rights Analysis',
        subject: 'PPG',
        activityUrl: 'https://example.com/ppg-unit3',
        xpReward: 150,
        badgeName: 'Quiz Conqueror',
        badgeIcon: '👑',
        postedBy: 'Sir Jim Mark',
      );
      await service.markActivityLaunched(posted.id);
      expect(service.progress.launchedActivityIds.contains(posted.id), isTrue);

      final earnedBadge = await service.completeActivity(posted);
      expect(earnedBadge, isNotNull);
      expect(earnedBadge!.badgeName, 'Quiz Conqueror');
      expect(service.progress.xp, 150);
      expect(service.progress.equippedBadge?.badgeIcon, '👑');

      // 4. Small Mystery Chest Pop-Quiz: +20 XP, 2-minute cooldown, and 5-question Treasure Hunter badge
      final q = service.drawRandomMysteryQuestion();
      expect(q, isNotNull);
      for (var i = 1; i <= 5; i++) {
        final chestId = 'small_chest_${((i - 1) % 4) + 1}';
        final badge = await service.recordSmallChestSuccess(
          smallChestId: chestId,
          question: q!,
        );
        expect(service.isSmallChestOnCooldown(chestId), isTrue);
        if (i == 5) {
          expect(badge, isNotNull);
          expect(badge!.badgeName, 'Treasure Hunter');
          expect(badge.badgeIcon, '🏆');
        }
      }

      // 5. Expanded 48x34 Campus Map (1536x1088), 8 Small Mystery Chests & A* pathfinding
      expect(kLobbyCols, 48);
      expect(kLobbyRows, 34);
      expect(kLobbyWorldWidth, 1536.0);
      expect(kLobbyWorldHeight, 1088.0);

      final zones = buildActiveInteractiveZones(service.subjectChests);
      expect(zones.any((z) => z.id == 'quest_counter'), isTrue);
      expect(zones.any((z) => z.id == 'small_chest_1'), isTrue);
      expect(zones.any((z) => z.id == 'small_chest_8'), isTrue);

      final nav = LobbyNavGrid(
        cols: kLobbyCols,
        rows: kLobbyRows,
        solids: buildLobbySolids(service.subjectChests),
      );
      final path = nav.findPath(kPlayerSpawnPoint, const Offset(768, 196));
      expect(path, isNotEmpty);

      // 6. First-time Avatar & Nickname onboarding persistence + Dark Mode controller
      expect(await AvatarSpriteCache.instance.hasCompletedOnboarding('2024-00142'), isFalse);
      await AvatarSpriteCache.instance.saveNickname('2024-00142', 'AetherScholar');
      await AvatarSpriteCache.instance.markOnboardingCompleted('2024-00142');
      expect(await AvatarSpriteCache.instance.hasCompletedOnboarding('2024-00142'), isTrue);
      expect(
        await AvatarSpriteCache.instance.loadSavedNickname(
          '2024-00142',
          fallbackName: 'Juan Dela Cruz',
        ),
        'AetherScholar',
      );

      await ThemeController.instance.init();
      expect(ThemeController.instance.isDarkMode, isFalse);
      await ThemeController.instance.toggleDarkMode();
      expect(ThemeController.instance.isDarkMode, isTrue);
      await ThemeController.instance.setDarkMode(false);
    },
  );
}
