import 'dart:convert';
import 'dart:io';
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
import 'package:student_portal_app/school_lobby/lobby_audio_service.dart';
import 'package:student_portal_app/school_lobby/lobby_data_service.dart';
import 'package:student_portal_app/school_lobby/lobby_exam_bank.dart';
import 'package:student_portal_app/school_lobby/lobby_moderation_service.dart';
import 'package:student_portal_app/school_lobby/lobby_presence_service.dart';
import 'package:student_portal_app/school_lobby/lobby_radio_service.dart';
import 'package:student_portal_app/school_lobby/lobby_shop_service.dart';
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
    LobbyPresenceService.instance.enableNetworkTransport = false;
    LobbyPresenceService.instance.stopPresence();
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

      // 2. LobbyDataService initialization & empty default Reviewer/Activity containers
      final service = LobbyDataService.instance;
      await service.init('2024-00142');
      expect(service.isInitialized, isTrue);
      expect(service.subjectNames,
          containsAll(['PGP', 'UCSP', 'PPG', 'PKLP TERM 2', 'PHILO']));
      expect(service.allReviewerQuestions.length, greaterThanOrEqualTo(8));

      // Verify all Subject Chests and Quest Counter start empty by default (Phase 4 requirement)
      expect(service.activities, isEmpty);
      for (final chest in service.subjectChests) {
        expect(chest.reviewers, isEmpty);
      }

      // 3. Teacher posts an Activity Link -> Student launches & marks as done -> Badge & XP unlocked
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

      // 3b. Teacher adds a Reviewer Link -> Student launches & marks as done -> +75 XP added!
      final pgpChest =
          service.subjectChests.firstWhere((c) => c.subjectName == 'PGP');
      final addedRev = await service.addReviewerToChest(
        chestId: pgpChest.id,
        title: 'Week 4 Executive Branch Slide Deck Link',
        fileType: 'LINK',
        urlOrContent: 'https://drive.google.com/example-pgp-w4',
        summary: 'Read before the Week 4 quiz',
        uploadedBy: 'Sir Jim Mark',
        xpReward: 75,
      );
      expect(addedRev.isLink, isTrue);
      expect(addedRev.xpReward, 75);

      await service.markReviewerLaunched(addedRev.id);
      expect(
          service.progress.launchedReviewerIds.contains(addedRev.id), isTrue);
      final completedRev = await service.completeReviewer(addedRev);
      expect(completedRev, isNotNull);
      expect(
          service.progress.completedReviewerIds.contains(addedRev.id), isTrue);
      expect(service.progress.xp, 225); // 150 + 75 XP
      expect(service.progress.level, 3);
      expect(service.progress.rankTitle, isNotEmpty);

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

      await ThemeController.instance.initialize();
      expect(ThemeController.instance.isDarkMode, isFalse);
      await ThemeController.instance.toggleDarkMode();
      expect(ThemeController.instance.isDarkMode, isTrue);
      await ThemeController.instance.setDarkMode(false);

      // 7. Phase 3: Campus Doors (Park, Class Room, Canteen, Faculty Room), Sit/Nap/Sleep,
      //    Thought Bubbles, MIS Control Sheet Active/Finished & Student Enrollment Filtering
      expect(LobbyRoomId.values.length, 5);
      expect(zones.any((z) => z.id == 'door_to_park'), isTrue);
      expect(zones.any((z) => z.id == 'door_to_classroom'), isTrue);
      expect(zones.any((z) => z.id == 'door_to_canteen'), isTrue);
      expect(zones.any((z) => z.id == 'door_to_faculty_room'), isTrue);

      for (final room in LobbyRoomId.values) {
        final roomZones =
            buildActiveInteractiveZones(service.subjectChests, room: room);
        expect(
          roomZones.any((z) => z.kind == InteractiveZoneKind.doorPortal),
          isTrue,
        );
        expect(
          roomZones.any((z) => z.kind == InteractiveZoneKind.restSpot),
          isTrue,
        );
        expect(
          roomZones.any((z) => z.kind == InteractiveZoneKind.peerStudent),
          isTrue,
        );
      }

      expect(PlayerRestState.sitting.isResting, isTrue);
      expect(PlayerRestState.napping.isResting, isTrue);
      expect(PlayerRestState.sleeping.isResting, isTrue);
      expect(PlayerRestState.none.isResting, isFalse);

      // MIS Control Sheet: PKLP (Term 1) is Finished -> excluded; PGP & UCSP are Active
      expect(service.isSubjectActiveInControlSheet('PKLP'), isFalse);
      expect(service.isSubjectActiveInControlSheet('PGP'), isTrue);
      expect(service.isSubjectActiveInControlSheet('UCSP'), isTrue);
      expect(service.isSubjectActiveInControlSheet('PKLP TERM 2'), isTrue);

      // Strict Student Enrollment Filtering: student enrolled only in PGP, UCSP, and finished PKLP
      service.applyUserEnrollmentFilter(
        isFaculty: false,
        enrolledSubjects: const [
          SubjectItem(code: 'PGP', name: 'Philippine Governance and Politics'),
          SubjectItem(
              code: 'UCSP',
              name: 'Understanding Culture, Society and Politics'),
          SubjectItem(
              code: 'PKLP',
              name: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino'),
        ],
      );
      final filteredChestNames =
          service.subjectChests.map((c) => c.subjectName).toSet();
      expect(filteredChestNames, equals({'PGP', 'UCSP'}));
      expect(filteredChestNames.contains('PHILO'), isFalse);
      expect(filteredChestNames.contains('PKLP'), isFalse);

      for (final act in service.activities) {
        expect({'PGP', 'UCSP'}.contains(act.subject), isTrue);
      }
      for (final qItem in service.quizQuestions) {
        expect({'PGP', 'UCSP'}.contains(qItem.subject), isTrue);
      }

      // Thought Bubble recording
      service.recordThoughtBubble(
        senderName: 'AetherScholar',
        senderRole: 'Student',
        roomName: 'Park',
        text: 'Studying PGP under the Campus Park trees!',
      );
      expect(service.thoughtMessages, isNotEmpty);
      expect(
        service.thoughtMessages.first.text,
        'Studying PGP under the Campus Park trees!',
      );

      // 8. Phase 4: Only Lobbyist NPC remains; Class Room Podium & Chairs; Park Trees;
      //    Canteen Vending Machines; Guided Walk Paths; 100% Atlas Sprite Key Verification
      expect(kLobbyNpcs.length, 1);
      expect(kLobbyNpcs.first.id, 'npc_receptionist');
      expect(kLobbyPeerStudents, isNotEmpty);

      final atlasFile = File('assets/school_lobby/catalog/atlas.json');
      expect(atlasFile.existsSync(), isTrue);
      final atlasJson =
          jsonDecode(atlasFile.readAsStringSync()) as Map<String, dynamic>;
      final validSprites =
          (atlasJson['frames'] as Map<String, dynamic>).keys.toSet();

      for (final room in LobbyRoomId.values) {
        final pieces = furnitureForRoom(room);
        expect(pieces, isNotEmpty);
        for (final piece in pieces) {
          expect(
            validSprites.contains(piece.spriteKey),
            isTrue,
            reason:
                'Room $room piece at (${piece.x}, ${piece.y}) uses missing spriteKey "${piece.spriteKey}"',
          );
        }
        expect(walkPathsForRoom(room), isNotEmpty);
        expect(floorSignpostsForRoom(room), isNotEmpty);
      }

      // Verify Class Room has Teacher Podium zone & Canteen has Vending Machine zones
      final classroomZones = buildActiveInteractiveZones(
        service.subjectChests,
        room: LobbyRoomId.classroom,
      );
      expect(
        classroomZones
            .any((z) => z.kind == InteractiveZoneKind.classroomPodium),
        isTrue,
      );

      final canteenZones = buildActiveInteractiveZones(
        service.subjectChests,
        room: LobbyRoomId.canteen,
      );
      expect(
        canteenZones.any((z) => z.kind == InteractiveZoneKind.vendingMachine),
        isTrue,
      );

      // 9. Live Multiplayer Presence Engine (LobbyPresenceService):
      //    Verify remote players join, sync look/nickname/room/rest/thought/wave, interpolate smoothly, and leave cleanly.
      final presence = LobbyPresenceService.instance;
      await presence.startPresence(
        session: const UserSession(
          id: '2024-00142',
          name: 'Juan Dela Cruz',
          isFaculty: false,
          subjects: [],
        ),
        nickname: 'AetherScholar',
        look: customLook,
        equippedBadgeIcon: '👑',
        initialRoom: LobbyRoomId.mainLobby,
        initialPos: kPlayerSpawnPoint,
      );
      expect(presence.totalOnlineCount, 1);

      presence.handleIncomingPresencePayload({
        'app': 'mis_shs_lobby_v1',
        'type': 'hello_join',
        'peerKey': '2024-00999_54321',
        'userId': '2024-00999',
        'nickname': 'Bea_HUMSS',
        'isFaculty': false,
        'look': 'preset:2',
        'badgeIcon': '🏆',
        'room': 'mainLobby',
        'x': 620,
        'y': 540,
        'facing': 'right',
        'isWalking': true,
        'rest': 'none',
        'thought': 'Hi everyone in the Main Lobby!',
        'ts': DateTime.now().millisecondsSinceEpoch,
      });

      expect(presence.totalOnlineCount, 2);
      expect(presence.playersForRoom(LobbyRoomId.mainLobby).length, 1);
      expect(presence.playersForRoom(LobbyRoomId.classroom), isEmpty);

      final remoteBea = presence.playersForRoom(LobbyRoomId.mainLobby).first;
      expect(remoteBea.nickname, 'Bea_HUMSS');
      expect(remoteBea.equippedBadgeIcon, '🏆');
      expect(remoteBea.hasActiveThought, isTrue);
      expect(remoteBea.thoughtText, 'Hi everyone in the Main Lobby!');

      // Move Bea by 60 pixels with seq=2 and verify 60 FPS interpolation glides her toward targetPos
      presence.handleIncomingPresencePayload({
        'app': 'mis_shs_lobby_v1',
        'type': 'state',
        'peerKey': '2024-00999_54321',
        'userId': '2024-00999',
        'nickname': 'Bea_HUMSS',
        'isFaculty': false,
        'look': 'preset:2',
        'badgeIcon': '🏆',
        'room': 'mainLobby',
        'x': 680,
        'y': 540,
        'vx': 180,
        'vy': 0,
        'facing': 'right',
        'isWalking': true,
        'rest': 'none',
        'thought': 'Hi everyone in the Main Lobby!',
        'sessionMs': 1000,
        'seq': 2,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });

      // Verify out-of-order older packet (seq=1) is strictly ignored and cannot rewind position
      presence.handleIncomingPresencePayload({
        'app': 'mis_shs_lobby_v1',
        'type': 'state',
        'peerKey': '2024-00999_54321',
        'userId': '2024-00999',
        'nickname': 'Bea_HUMSS',
        'isFaculty': false,
        'look': 'preset:2',
        'badgeIcon': '🏆',
        'room': 'mainLobby',
        'x': 400,
        'y': 400,
        'facing': 'left',
        'isWalking': false,
        'rest': 'none',
        'thought': 'Old stale packet',
        'sessionMs': 1000,
        'seq': 1,
        'ts': DateTime.now().millisecondsSinceEpoch - 5000,
      });
      expect(remoteBea.targetPos.dx, 680.0);
      expect(remoteBea.thoughtText, 'Hi everyone in the Main Lobby!');

      final moved =
          presence.tickInterpolation(0.05, LobbyRoomId.mainLobby);
      expect(moved, isTrue);
      expect(remoteBea.currentPos.dx, greaterThan(620.0));
      expect(remoteBea.currentPos.dx, lessThanOrEqualTo(700.0));

      // Verify 'leave' packet cleanly removes remote player
      presence.handleIncomingPresencePayload({
        'app': 'mis_shs_lobby_v1',
        'type': 'leave',
        'peerKey': '2024-00999_54321',
      });
      expect(presence.totalOnlineCount, 1);
      expect(presence.allRemotePlayers, isEmpty);
    },
  );

  test(
    'Phase 5: Authentic .docx Exam Bank rotation, 24h Chest Cooldown & 2h Relocation, Furniture Rest/Cushion Layering, Shop XP Exchange, 1h Radio Garden Lock, SFX & Moderation',
    () async {
      final service = LobbyDataService.instance;
      await service.init('2024-00888');

      // 1. Authentic .docx Exam Bank (40+ questions across PKLP TERM 2, PPG, PGP, UCSP, PHILO)
      //    & Non-Repeating Per-Student Question Rotation
      expect(kAuthenticExamQuestionBank.length, greaterThanOrEqualTo(40));
      final subjectsInBank =
          kAuthenticExamQuestionBank.map((q) => q.subject).toSet();
      expect(
        subjectsInBank,
        containsAll(['PKLP TERM 2', 'PPG', 'PGP', 'UCSP', 'PHILO']),
      );

      final seenIds = <String>{};
      final totalPool = service.quizQuestions.length;
      expect(totalPool, greaterThanOrEqualTo(40));
      for (var i = 0; i < totalPool; i++) {
        final q = service.pickRandomQuestionForSmallChest('small_chest_1');
        expect(seenIds.contains(q.id), isFalse,
            reason: 'Question ${q.id} repeated before pool exhaustion at draw $i');
        seenIds.add(q.id);
        await service.submitSmallChestQuizAnswer(
          smallChestId: 'small_chest_${(i % 8) + 1}',
          question: q,
          selectedIndex: q.correctIndex,
        );
      }
      expect(seenIds.length, totalPool);
      // Next draw after exhausting all 40+ questions cleanly resets and continues rotating
      final afterResetQuestion =
          service.pickRandomQuestionForSmallChest('small_chest_1');
      expect(afterResetQuestion.id, isNotEmpty);

      // 2. 24-Hour (86,400s) Small Mystery Chest Cooldown + Lock on First Click (even on wrong answer)
      expect(
        LobbyDataService.kSmallChestCooldownMs,
        equals(24 * 60 * 60 * 1000),
      );
      final nowMs = DateTime.now().millisecondsSinceEpoch;
      final wrongIdx = (afterResetQuestion.correctIndex + 1) % 4;
      await service.submitSmallChestQuizAnswer(
        smallChestId: 'small_chest_7',
        question: afterResetQuestion,
        selectedIndex: wrongIdx,
        nowMs: nowMs,
      );
      expect(service.isSmallChestOnCooldown('small_chest_7', nowMs), isTrue);
      final remSec = service.smallChestRemainingSeconds('small_chest_7', nowMs);
      expect(remSec, greaterThan(86000));
      expect(remSec, lessThanOrEqualTo(86400));
      expect(
        service.smallChestFormattedCooldown('small_chest_7', nowMs),
        contains('h'),
      );

      // 3. Dynamic 2-Hour Small Mystery Chest Walkable Relocation
      const windowA = 1000 * (2 * 60 * 60 * 1000);
      const windowB = 1001 * (2 * 60 * 60 * 1000);
      final posA =
          smallChestPositionFor2HourWindow('small_chest_1', nowMs: windowA);
      final posB =
          smallChestPositionFor2HourWindow('small_chest_1', nowMs: windowB);
      expect(posA != posB, isTrue);

      final mainSolids = buildLobbySolids(
        service.subjectChests,
        room: LobbyRoomId.mainLobby,
      );
      expect(mainSolids, isNotEmpty);

      // 4. Furniture Anti-Bump Colliders + Furniture-Only Rest Spots + Elevated Cushion SortY
      for (final room in LobbyRoomId.values) {
        final spots = restSpotsForRoom(room);
        expect(spots, isNotEmpty);
        for (final s in spots) {
          // Every rest spot has a distinct walkable standPosition dismount offset
          expect(s.standPosition != s.position, isTrue);
          // Resting characters sort at pos.dy + 38.0 so they render ON TOP OF furniture cushions
          expect(
            s.effectiveSortY,
            equals(s.position.dy + 38.0),
          );
        }
      }

      // Verify Campus Shop (`🛍️`) & Campus Radio Base (`📻`) interactive zones exist in Main Lobby
      final mainZones = buildActiveInteractiveZones(
        service.subjectChests,
        room: LobbyRoomId.mainLobby,
      );
      expect(
        mainZones.any((z) => z.kind == InteractiveZoneKind.campusShop),
        isTrue,
      );
      expect(
        mainZones.any((z) => z.kind == InteractiveZoneKind.radioBase),
        isTrue,
      );

      // 5. Campus Cosmetics Shop (`LobbyShopService`): Starter items free, locked items exchanged for XP
      final shop = LobbyShopService.instance;
      expect(
        shop.isCosmeticUnlocked('outfit', '1-1', isFaculty: false),
        isTrue,
      );
      expect(
        shop.isCosmeticUnlocked('hat', '5-1', isFaculty: false),
        isFalse,
      );
      final xpBeforeShop = service.progress.xp;
      final levelBeforeShop = service.progress.level;
      final availBeforeShop = service.progress.availableXp;
      final hatCost = shop.costForCosmetic('hat', '5-1');
      expect(hatCost, 90);
      expect(availBeforeShop, greaterThanOrEqualTo(hatCost));

      final bought = await service.purchaseShopCosmetic(
        itemKey: 'hat:5-1',
        costXp: hatCost,
      );
      expect(bought, isTrue);
      expect(
        shop.isCosmeticUnlocked('hat', '5-1', isFaculty: false),
        isTrue,
      );
      expect(service.progress.availableXp, availBeforeShop - hatCost);
      // Lifetime XP and Level are preserved when spending XP in the Campus Shop!
      expect(service.progress.xp, xpBeforeShop);
      expect(service.progress.level, levelBeforeShop);

      // 6. Campus Radio Base (`LobbyRadioService`): 1-Hour (3,600s) Channel Lock
      final radio = LobbyRadioService.instance;
      radio.resetForTesting();
      expect(radio.canChangeChannel(nowMs: 1000000), isTrue);
      final tuned = await radio.changeStation(
        'rg_manila_opm',
        changedBy: 'Juan',
        nowMs: 1000000,
      );
      expect(tuned, isTrue);
      expect(radio.activeStationId, 'rg_manila_opm');
      // 10 minutes later: channel is locked (50 minutes / 3,000s remaining)
      expect(radio.canChangeChannel(nowMs: 1000000 + 600000), isFalse);
      expect(radio.remainingCooldownSeconds(nowMs: 1000000 + 600000), 3000);
      final blockedTune = await radio.changeStation(
        'rg_cebu_fm',
        changedBy: 'Pedro',
        nowMs: 1000000 + 600000,
      );
      expect(blockedTune, isFalse);
      expect(radio.activeStationId, 'rg_manila_opm');
      // 60 minutes later: 1-hour lock expires and channel can be changed again!
      expect(radio.canChangeChannel(nowMs: 1000000 + 3600000), isTrue);

      // 7. Bilingual Profanity Filter (`LobbyModerationService`) & Synthesized WAV SFX (`LobbyAudioService`)
      final mod = LobbyModerationService.instance;
      expect(mod.containsProfanity('Hello classmates, let us study PGP!'), isFalse);
      expect(mod.containsProfanity('Hoy gago ka'), isTrue);
      expect(mod.containsProfanity('What the fuck is this'), isTrue);
      expect(mod.sanitizeText('Hoy gago ka'), 'Hoy **** ka');

      final wavBytes = LobbyAudioService.synthesizeToneSequenceWav(
        const [523.25, 659.25],
        noteDurationMs: 50,
      );
      expect(wavBytes.length, greaterThan(44));
      expect(String.fromCharCodes(wavBytes.sublist(0, 4)), 'RIFF');
      expect(String.fromCharCodes(wavBytes.sublist(8, 12)), 'WAVE');
    },
  );
}
