import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:student_portal_app/config/app_config.dart';
import 'package:student_portal_app/models/portal_models.dart';
import 'package:student_portal_app/screens/auth_screen.dart';
import 'package:student_portal_app/screens/teacher_scanner_screen.dart';
import 'package:student_portal_app/services/api_service.dart';
import 'package:student_portal_app/services/local_database.dart';
import 'package:student_portal_app/services/session_service.dart';
import 'package:student_portal_app/utils/reviewer_outline_extractor.dart';
import 'package:student_portal_app/widgets/common_widgets.dart';
import 'package:student_portal_app/widgets/student_qr_generator.dart';
import 'package:student_portal_app/school_lobby/lobby_agency_agents.dart';
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
import 'package:student_portal_app/school_lobby/pixelfx_engine.dart';
import 'package:student_portal_app/school_lobby/sovereign_story_data.dart';
import 'package:student_portal_app/school_lobby/sovereign_story_screen.dart';
import 'package:student_portal_app/school_lobby/spritecast_engine.dart';
import 'package:student_portal_app/school_lobby/dungeon/dungeon_audio.dart';
import 'package:student_portal_app/school_lobby/dungeon/dungeon_combat.dart';
import 'package:student_portal_app/school_lobby/dungeon/dungeon_enemies.dart';
import 'package:student_portal_app/school_lobby/dungeon/dungeon_models.dart';
import 'package:student_portal_app/school_lobby/dungeon/dungeon_physics.dart';
import 'package:student_portal_app/school_lobby/dungeon/dungeon_renderer.dart';
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
      expect(zones.any((z) => z.id == 'small_chest_8'), isFalse);
      final facultyZones = buildActiveInteractiveZones(
        service.subjectChests,
        room: LobbyRoomId.facultyRoom,
      );
      expect(facultyZones.any((z) => z.id == 'small_chest_8'), isTrue);

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

      // 8. Phase 4 & 6: Room & Shop NPCs across all 5 rooms; Class Room Podium & Chairs; Park Trees;
      //    Canteen Vending Machines; Guided Walk Paths; 100% Atlas Sprite Key Verification
      expect(kLobbyNpcs.length, greaterThanOrEqualTo(7));
      expect(kLobbyNpcs.first.id, 'npc_receptionist');
      for (final room in LobbyRoomId.values) {
        expect(npcsForRoom(room), isNotEmpty);
      }
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
      // AI Mentor chests are subject-scoped (small_chest_1 -> PKLP only) and
      // never repeat a question within their subject until it is exhausted.
      final pklpFirst = service.pickRandomQuestionForSmallChest('small_chest_1');
      expect(pklpFirst.subject.toUpperCase(), startsWith('PKLP'));

      // Subject-neutral draws rotate through the ENTIRE deck with no repeats.
      for (var i = 0; i < totalPool; i++) {
        final q =
            service.pickRandomQuestionForSmallChest('generic_mystery_draw');
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
          service.pickRandomQuestionForSmallChest('generic_mystery_draw');
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
          // Resting characters sort at >= pos.dy + 38.0 so they render ON TOP OF furniture cushions
          expect(
            s.effectiveSortY,
            greaterThanOrEqualTo(s.position.dy + 38.0),
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

  test(
    'Phase 6: Parcha-ai AI Subject Mentors (Strictly PKLP, PPG, UCSP), Group Study Spaces in all 5 rooms, Personal Classroom Table Lock, Campus Shop Table Space Decor & Compact Room Bounds',
    () async {
      final service = LobbyDataService.instance;
      await service.init('2024-00777');

      // 1. Strict Portal Subject Constraint for AI Subject Mentor NPCs: ONLY PKLP, PPG, and UCSP
      expect(kAiSubjectMentors.length, 8);
      const allowedPortalSubjects = {'PKLP', 'PPG', 'UCSP'};
      for (final mentor in kAiSubjectMentors) {
        final baseSubject = mentor.subjectCode.split(' ').first;
        expect(
          allowedPortalSubjects.contains(baseSubject),
          isTrue,
          reason:
              'AI Mentor ${mentor.name} has subjectCode ${mentor.subjectCode}, which is outside {PKLP, PPG, UCSP}',
        );
        expect(findAiMentorById(mentor.id), isNotNull);
        expect(mentor.studyThoughts, isNotEmpty);

        // Verify AI Mentor strictly draws questions matching its Portal subject
        final q = service.pickRandomQuestionForSmallChest(
          mentor.id,
          preferredSubjectCode: mentor.subjectCode,
        );
        expect(
          q.subject.toUpperCase().startsWith(baseSubject),
          isTrue,
          reason:
              'AI Mentor ${mentor.name} (${mentor.subjectCode}) drew question with subject ${q.subject}',
        );
      }

      // 2. Group Study & Chat Spaces exist in all 5 rooms (`LobbyRoomId.values`)
      expect(kGroupStudySpaces.length, equals(5));
      for (final room in LobbyRoomId.values) {
        final roomStudySpace = groupStudySpaceForRoom(room);
        expect(roomStudySpace.room, equals(room));
        expect(
          roomStudySpace.seatSpotIds,
          isNotEmpty,
          reason: 'Room $room is missing Group Study Space seats',
        );
      }

      // 3. Compact Room Bounds (`roomBounds`) eliminate dead space in every room
      for (final room in LobbyRoomId.values) {
        final bounds = room.roomBounds;
        expect(bounds.width, lessThan(kLobbyWorldWidth));
        expect(bounds.height, lessThan(kLobbyWorldHeight));
        expect(bounds.width, greaterThanOrEqualTo(750.0));
        expect(bounds.height, greaterThanOrEqualTo(600.0));
      }

      // 4. Personal Student Classroom Table Assignment & Exclusive Ownership Lock
      final assignedFor777 = assignedClassroomDeskSpotIdForStudent('2024-00777');
      expect(isPersonalClassroomDeskSpot(assignedFor777), isTrue);
      expect(
        canStudentSitAtSpot(
          spotId: assignedFor777,
          studentId: '2024-00777',
          isFaculty: false,
        ),
        isTrue,
      );
      // Other students' personal Classroom tables are locked for non-faculty students
      final otherDeskId = kClassroomPersonalDeskSpotIds
          .firstWhere((id) => id != assignedFor777);
      expect(
        canStudentSitAtSpot(
          spotId: otherDeskId,
          studentId: '2024-00777',
          isFaculty: false,
        ),
        isFalse,
      );
      // Group Study tables in the Classroom are open to all students!
      expect(
        canStudentSitAtSpot(
          spotId: 'rest_classroom_group_1',
          studentId: '2024-00777',
          isFaculty: false,
        ),
        isTrue,
      );
      // Faculty advisers can inspect any seat
      expect(
        canStudentSitAtSpot(
          spotId: 'rest_classroom_r1_c1',
          studentId: 'FAC-001',
          isFaculty: true,
        ),
        isTrue,
      );

      // 5. Campus Shop Table Space Decor (`kTableDecorCatalog` & `LobbyTableDecorConfig`)
      final shop = LobbyShopService.instance;
      expect(shop.itemsForCategory('table_chair').length, greaterThanOrEqualTo(4));
      expect(shop.itemsForCategory('table_light').length, greaterThanOrEqualTo(4));
      expect(shop.itemsForCategory('table_frame').length, greaterThanOrEqualTo(4));
      expect(shop.itemsForCategory('table_mat').length, greaterThanOrEqualTo(4));
      expect(shop.itemsForCategory('table_prop').length, greaterThanOrEqualTo(4));

      // Starter table chair ('tan_classic') is unlocked by default; 'emerald_ergo' costs XP
      expect(
        shop.isCosmeticUnlocked('table_chair', 'tan_classic', isFaculty: false),
        isTrue,
      );
      expect(
        shop.isCosmeticUnlocked('table_chair', 'emerald_ergo', isFaculty: false),
        isFalse,
      );

      // Attempting to equip locked table items before purchasing is blocked by sanitizeTableDecorForUnlocked
      await service.updateTableDecor(
        const LobbyTableDecorConfig(
          chairStyle: 'emerald_ergo',
          miniLight: 'fairy_warm',
        ),
      );
      expect(service.progress.tableDecor.chairStyle, 'tan_classic');
      expect(service.progress.tableDecor.miniLight, 'none');

      // Award XP, purchase the Table Space items in the Campus Shop, and equip them!
      final postedQuest = await service.postActivity(
        title: 'UCSP Fieldwork Reflection',
        subject: 'UCSP',
        activityUrl: 'https://example.com/ucsp-fieldwork',
        xpReward: 500,
        badgeName: 'Culture Explorer',
        badgeIcon: '🌍',
        postedBy: 'Dr. Jocano',
      );
      await service.markActivityLaunched(postedQuest.id);
      await service.completeActivity(postedQuest);

      expect(
        await service.purchaseShopCosmetic(
          itemKey: 'table_chair:emerald_ergo',
          costXp: shop.costForCosmetic('table_chair', 'emerald_ergo'),
        ),
        isTrue,
      );
      expect(
        await service.purchaseShopCosmetic(
          itemKey: 'table_light:fairy_warm',
          costXp: shop.costForCosmetic('table_light', 'fairy_warm'),
        ),
        isTrue,
      );
      expect(
        await service.purchaseShopCosmetic(
          itemKey: 'table_frame:gold_cert',
          costXp: shop.costForCosmetic('table_frame', 'gold_cert'),
        ),
        isTrue,
      );
      expect(
        await service.purchaseShopCosmetic(
          itemKey: 'table_mat:mint_pad',
          costXp: shop.costForCosmetic('table_mat', 'mint_pad'),
        ),
        isTrue,
      );
      expect(
        await service.purchaseShopCosmetic(
          itemKey: 'table_prop:zen_bonsai',
          costXp: shop.costForCosmetic('table_prop', 'zen_bonsai'),
        ),
        isTrue,
      );

      // Update and persist the student's Classroom Table Space Decor
      await service.updateTableDecor(
        const LobbyTableDecorConfig(
          chairStyle: 'emerald_ergo',
          miniLight: 'fairy_warm',
          deskFrame: 'gold_cert',
          deskMat: 'mint_pad',
          deskProp: 'zen_bonsai',
        ),
      );
      expect(service.progress.tableDecor.chairStyle, 'emerald_ergo');
      expect(service.progress.tableDecor.miniLight, 'fairy_warm');
      expect(service.progress.tableDecor.deskFrame, 'gold_cert');
      expect(service.progress.tableDecor.deskMat, 'mint_pad');
      expect(service.progress.tableDecor.deskProp, 'zen_bonsai');

      // 6. Radio Fallback Streams configured for reliable Android MediaPlayer streaming
      for (final station in LobbyRadioService.kStations) {
        expect(station.streamUrl, isNotEmpty);
        expect(station.fallbackStreamUrls, isNotEmpty);
      }
    },
  );

  test(
    'School Lobby Phase 7: Agency-Agents Walking & Talking AI Teachers (PKLP, PPG, UCSP) across all 5 rooms',
    () async {
      final service = LobbyDataService.instance;
      await service.init('2024-00777');

      final agency = LobbyAgencyAgentsService.instance;
      agency.resetForTesting();

      // 1. Verify all 8 AI Subject Teachers strictly match PKLP, PPG, or UCSP and span all 5 rooms
      expect(kAgencyTeacherPersonas.length, 8);
      const allowedPortalSubjects = {'PKLP', 'PPG', 'UCSP'};
      final coveredRooms = <LobbyRoomId>{};
      for (final persona in kAgencyTeacherPersonas) {
        expect(
          allowedPortalSubjects.contains(persona.subjectCode),
          isTrue,
          reason:
              'Agency AI Teacher ${persona.name} has subject ${persona.subjectCode} outside {PKLP, PPG, UCSP}',
        );
        expect(persona.identity, isNotEmpty);
        expect(persona.personalityVibe, isNotEmpty);
        expect(persona.coreMission, isNotEmpty);
        expect(persona.patrolWaypoints.length, greaterThanOrEqualTo(3));
        coveredRooms.add(persona.room);
      }
      expect(coveredRooms.length, LobbyRoomId.values.length);

      // 2. Verify autonomous walking locomotion along waypoints when player is far away
      final lakambiniBefore = agency.runtimeStateForId('small_chest_1')!;
      final startPos = lakambiniBefore.currentPos;
      var moved = false;
      for (var i = 0; i < 10; i++) {
        if (agency.tick(
          0.1,
          room: LobbyRoomId.mainLobby,
          playerPos: const Offset(1350, 950),
        )) {
          moved = true;
        }
      }
      expect(moved, isTrue);
      final lakambiniAfterWalk = agency.runtimeStateForId('small_chest_1')!;
      expect(lakambiniAfterWalk.currentPos, isNot(equals(startPos)));
      expect(lakambiniAfterWalk.isWalking, isTrue);

      // Verify Dr. Jocano's favorite sofa aligns with calibrated rest_lobby_sofa_south center
      final jocano = agency.runtimeStateForId('small_chest_3')!;
      expect(jocano.spec.favoriteSeatPos, const Offset(352, 828));

      // Verify Staff NPC in Main Lobby also patrols autonomously
      final aikoBefore = agency.runtimeStateForId('npc_receptionist')!.currentPos;
      expect(aikoBefore, isNotNull);

      // 3. Verify proximity eye-contact, stopping, waving, and greeting within 115 px
      final nearPlayerPos =
          lakambiniAfterWalk.currentPos + const Offset(60, 0);
      final approached = agency.tick(
        0.05,
        room: LobbyRoomId.mainLobby,
        playerPos: nearPlayerPos,
      );
      expect(approached, isTrue);
      final conversing = agency.runtimeStateForId('small_chest_1')!;
      expect(
        conversing.activityState,
        AgencyAgentActivityState.conversingWithPlayer,
      );
      expect(conversing.isWaving, isTrue);
      expect(conversing.facing, AvatarFacing.right);

      // 4. Verify live in-character conversational coaching for PKLP, PPG, and UCSP
      final pklpReply = agency.sendStudentMessage(
        agentId: 'small_chest_1',
        studentMessage: 'Ipaliwanag ang Polo y Servicio at Suffrage',
        studentName: 'Juan',
      );
      expect(pklpReply.toLowerCase(), contains('polo'));
      expect(
        agency.chatHistoryForAgent('small_chest_1').length,
        greaterThanOrEqualTo(3),
      );

      final ppgReply = agency.sendStudentMessage(
        agentId: 'small_chest_2',
        studentMessage: 'Explain the 4 Elements of a State vs. Nation',
        studentName: 'Juan',
      );
      expect(ppgReply.toLowerCase(), contains('sovereignty'));

      final ucspReply = agency.sendStudentMessage(
        agentId: 'small_chest_3',
        studentMessage: 'Cultural Relativism vs. Ethnocentrism',
        studentName: 'Juan',
      );
      expect(ucspReply.toLowerCase(), contains('cultural relativism'));

      // 5. Verify interactive zones expose walking AI Teachers in sub-rooms too (e.g. Classroom & Park)
      final parkZones =
          buildActiveInteractiveZones(service.subjectChests, room: LobbyRoomId.park);
      expect(parkZones.any((z) => z.id == 'small_chest_4'), isTrue);
      final classroomZones = buildActiveInteractiveZones(
        service.subjectChests,
        room: LobbyRoomId.classroom,
      );
      expect(classroomZones.any((z) => z.id == 'small_chest_6'), isTrue);
    },
  );

  test(
    'School Lobby Phase 8: Chronicles of the Sovereign 7-Act LeafGreen RPG, Saligang Tala & patch-gg/pixelfx Engine',
    () async {
      final service = LobbyDataService.instance;
      await service.init('2024-00555');

      // 1. Verify Glowing Bookshelf Portal exists in Main Lobby interactive zones
      final mainZones = buildActiveInteractiveZones(
        service.subjectChests,
        room: LobbyRoomId.mainLobby,
      );
      expect(
        mainZones.any(
          (z) =>
              z.id == 'sovereign_story_bookshelf' &&
              z.kind == InteractiveZoneKind.storyBookshelfPortal,
        ),
        isTrue,
      );

      // 2. Verify patch-gg/pixelfx Dual-Buffer Frame, Deterministic PRNG, Pure & Simulated 120Hz Effects
      final frame = createFrame(64, 64);
      final auraFx = createFx(
        PixelFxPreset.bookshelfPortalAura,
        const PixelFxOptions(x: 32, y: 32, seed: 42),
      );
      auraFx.update(0.25);
      auraFx.draw(clearFrame(frame));
      final composited = compositeFrame(frame);
      expect(composited.any((px) => px != 0), isTrue);

      final swirlFx = createFx(
        PixelFxPreset.gbaBattleSwirl,
        const PixelFxOptions(x: 32, y: 32, seed: 99),
      );
      swirlFx.update(0.15);
      swirlFx.draw(clearFrame(frame));
      expect(compositeFrame(frame).any((px) => px != 0), isTrue);

      // 3. Verify all 7 Historical Acts, 4 Legal Doctrines, and Saligang Tala Catalog
      expect(kSovereignActs.length, 7);
      expect(kAlonDoctrineMoves.length, 4);
      expect(kSaligangTalaCatalog.length, greaterThanOrEqualTo(16));
      expect(kSovereignActs.first.zoneTitle, 'Isla Magtanggol');
      expect(kSovereignActs.last.zoneTitle, 'Highway of Gold');

      // 4. Verify Charter Seal XP & Master Historian ("Ang Tagapag-ingat") Badge unlocking
      final firstSealBadge = await service.awardSovereignCharterSealReward(
        sealId: kSovereignActs.first.charterSealId,
        sealName: kSovereignActs.first.charterSealName,
        sealIcon: kSovereignActs.first.charterSealIcon,
        sealColor: kSovereignActs.first.charterSealColor,
        totalSealsEarned: 1,
      );
      expect(firstSealBadge, isNotNull);
      expect(firstSealBadge!.id, 'badge_chronicle_keeper');

      final masterBadge = await service.awardSovereignCharterSealReward(
        sealId: kSovereignActs.last.charterSealId,
        sealName: kSovereignActs.last.charterSealName,
        sealIcon: kSovereignActs.last.charterSealIcon,
        sealColor: kSovereignActs.last.charterSealColor,
        totalSealsEarned: 7,
        completedAllSevenAltar: true,
      );
      expect(masterBadge, isNotNull);
      expect(masterBadge!.id, 'badge_master_historian');
      expect(masterBadge.badgeIcon, '👑');
    },
  );

  test(
    'Part 1/6: 240x160 GBA PixelFxFrame, Multi-Emitter Landmarks & Unrest Zone Tile Extraction across all 7 Acts',
    () {
      // 1. Verify authentic 240x160 GBA PixelFxFrame dimensions
      expect(kGbaFxFrameWidth, 240);
      expect(kGbaFxFrameHeight, 160);
      final gbaFrame = createFrame(kGbaFxFrameWidth, kGbaFxFrameHeight);
      expect(gbaFrame.colorBuffer.length, 240 * 160);
      expect(gbaFrame.lightBuffer.length, 240 * 160);

      // 2. Verify every one of the 7 Acts extracts valid Tribunal ('T'), Bahay ('B'), and Unrest ('U') points
      for (final act in kSovereignActs) {
        final tribunalPts = extractMapTileFxPoints(
          act.asciiMap,
          'T',
          clusterCentroids: true,
        );
        final bahayPts = extractMapTileFxPoints(
          act.asciiMap,
          'B',
          clusterCentroids: false,
        );
        final unrestPts = extractMapTileFxPoints(
          act.asciiMap,
          'U',
          clusterCentroids: true,
        );
        expect(tribunalPts.length, 1,
            reason: '${act.romanNumeral} must have 1 unified Tribunal Hall span');
        expect(bahayPts, isNotEmpty,
            reason: '${act.romanNumeral} must have at least 1 Bahay-Pulungan');
        expect(unrestPts, isNotEmpty,
            reason: '${act.romanNumeral} must have at least 1 Unrest Zone cluster');
      }

      // 3. Verify localized multi-emitter points for Torch Flicker (Act II & III) and Curfew Searchlight (Act VI)
      final act2Torches = computeActAmbientEmitterPoints(kSovereignActs[1]);
      expect(act2Torches.length, greaterThanOrEqualTo(3));
      final act6Searchlights = computeActAmbientEmitterPoints(kSovereignActs[5]);
      expect(act6Searchlights.length, 3);

      // 4. Verify multi-emitter drawAtPoints renders both Unrest ripples and localized Torches into 240x160 frame
      final unrestFx = createFx(
        PixelFxPreset.unrestZoneRipples,
        const PixelFxOptions(x: 120, y: 80, seed: 202),
      );
      unrestFx.update(0.35);
      final act1UnrestPts = extractMapTileFxPoints(
        kSovereignActs.first.asciiMap,
        'U',
        clusterCentroids: true,
      );
      unrestFx.drawAtPoints(clearFrame(gbaFrame), act1UnrestPts);
      expect(compositeFrame(gbaFrame).any((px) => px != 0), isTrue);

      final torchFx = createFx(
        PixelFxPreset.torchFlicker,
        const PixelFxOptions(x: 120, y: 80, seed: 997),
      );
      torchFx.update(0.25);
      torchFx.drawAtPoints(clearFrame(gbaFrame), act2Torches);
      expect(compositeFrame(gbaFrame).any((px) => px != 0), isTrue);
    },
  );

  test(
    'Part 2/6: Smooth GBA Tile Interpolation, Wall-Bump Rebound, 4-Dir Facing & Puzzle Prop Mapping',
    () {
      // 1. Verify smooth 150ms tile-to-tile glide interpolation
      final motion = AlonOverworldMotionState(col: 5, row: 11, facing: 'up');
      expect(motion.isMoving, isFalse);
      motion.startMoveTo(6, 11, 'right');
      expect(motion.isMoving, isTrue);
      expect(motion.facing, 'right');
      expect(motion.stepAnimFrame, 1);

      motion.tick(0.075); // Halfway through 150ms step
      expect(motion.visualCol, greaterThan(5.0));
      expect(motion.visualCol, lessThan(6.0));
      expect(motion.visualRow, 11.0);

      motion.tick(0.10); // Completed step
      expect(motion.isMoving, isFalse);
      expect(motion.visualCol, 6.0);

      // 2. Verify directional wall-bump rebound offset
      motion.triggerWallBump('up');
      expect(motion.isBumping, isTrue);
      motion.tick(0.07);
      expect(motion.bumpPixelOffset.dy, lessThan(0.0));
      motion.tick(0.10);
      expect(motion.isBumping, isFalse);
      expect(motion.bumpPixelOffset, Offset.zero);

      // 3. Verify immediate snapTo for Act transitions & Bahay-Pulungan respawn
      motion.snapTo(9, 12, facing: 'down');
      expect(motion.visualCol, 9.0);
      expect(motion.visualRow, 12.0);
      expect(motion.isMoving, isFalse);

      // 4. Verify 4-directional AvatarFacing mapping
      expect(parseStoryFacing('up'), AvatarFacing.up);
      expect(parseStoryFacing('down'), AvatarFacing.down);
      expect(parseStoryFacing('left'), AvatarFacing.left);
      expect(parseStoryFacing('right'), AvatarFacing.right);

      // 5. Verify every Puzzle Node across all 7 Acts resolves to a bespoke pixel prop
      final propMap = <String, SovereignPuzzlePropKind>{};
      for (final act in kSovereignActs) {
        for (final entity
            in act.entities.where((e) => e.role == 'puzzle_node')) {
          propMap[entity.id] = resolvePuzzleNodePropKind(entity, act.actNumber);
        }
      }
      expect(propMap.length, greaterThanOrEqualTo(14));
      expect(propMap['act1_umalohokan'], SovereignPuzzlePropKind.bronzeBell);
      expect(propMap['act1_babaylan'], SovereignPuzzlePropKind.sanduguanCup);
      expect(propMap['act2_audiencia'], SovereignPuzzlePropKind.waxScroll);
      expect(propMap['act4_suffragist'], SovereignPuzzlePropKind.ballotBox);
      expect(propMap['act6_press_clause_1'],
          SovereignPuzzlePropKind.printingPress);
      expect(
          propMap['act6_press_clause_2'], SovereignPuzzlePropKind.habeasShield);
      expect(propMap['act7_edsa_citizens'], SovereignPuzzlePropKind.edsaFlowers);
    },
  );

  test(
    'Part 3/6: GBA Battle Arena 9 Historical Portrait Roles, Choreography State & 240x120 pixelfx Beam',
    () {
      // 1. Verify all 9 historical portrait roles exist across the 7-Act campaign
      final resolvedRoles = <SovereignBattlePortraitRole>{};
      for (final act in kSovereignActs) {
        resolvedRoles.add(
          resolveBattlePortraitRole(act.randomUnrestEncounter.spriteRole),
        );
        for (final e in act.entities) {
          if (e.battleSpec != null) {
            resolvedRoles.add(
              resolveBattlePortraitRole(e.battleSpec!.spriteRole),
            );
          }
        }
      }
      expect(resolvedRoles, containsAll(SovereignBattlePortraitRole.values));

      // 2. Verify GBA Battle Choreography transitions (slide-in, doctrine strike, counter)
      final choreo = SovereignBattleChoreographyState();
      choreo.startIntro();
      expect(choreo.introSlideProgress, 0.0);
      choreo.tick(0.25);
      expect(choreo.introSlideProgress, greaterThan(0.4));
      choreo.tick(0.30);
      expect(choreo.introSlideProgress, 1.0);

      choreo.triggerAlonDoctrineStrike(0xFFFACC15);
      expect(choreo.alonAttackLunge, 1.0);
      expect(choreo.opponentHitFlash, 1.0);
      expect(choreo.isProjectileActive, isTrue);
      expect(choreo.projectileFromAlon, isTrue);
      choreo.tick(0.16);
      expect(choreo.projectileProgress, greaterThan(0.4));
      choreo.tick(0.40);
      expect(choreo.alonAttackLunge, 0.0);
      expect(choreo.isProjectileActive, isFalse);

      choreo.triggerOpponentCounter(0xFFEF4444);
      expect(choreo.opponentLunge, 1.0);
      expect(choreo.alonHitFlash, 1.0);
      expect(choreo.projectileFromAlon, isFalse);

      // 3. Verify 240x120 battle FX frame + drawDoctrineProjectileBeam rendering
      final battleFrame = createFrame(kGbaBattleFxWidth, kGbaBattleFxHeight);
      expect(battleFrame.colorBuffer.length, 240 * 120);
      drawDoctrineProjectileBeam(
        clearFrame(battleFrame),
        x0: 68,
        y0: 84,
        x1: 176,
        y1: 48,
        progress: 0.55,
        coreColor: 0xFFFFFFFF,
        glowColor: 0xFFFACC15,
      );
      expect(compositeFrame(battleFrame).any((px) => px != 0), isTrue);
    },
  );

  test(
    'Part 4/6: Strict AI Mentor Room Isolation, Solid Furniture Colliders, Nickname Moderation & Radio Clock Clamp',
    () async {
      final service = LobbyDataService.instance;
      await service.init('2024-00444');

      // 1. Strict room isolation: Main Lobby has ONLY small_chest_1..3 (zero ghost sub-room mentors)
      final lobbyMentors = buildActiveInteractiveZones(
        service.subjectChests,
        room: LobbyRoomId.mainLobby,
      )
          .where((z) => z.kind == InteractiveZoneKind.smallMysteryChest)
          .map((z) => z.id)
          .toSet();
      expect(lobbyMentors, equals({'small_chest_1', 'small_chest_2', 'small_chest_3'}));
      expect(lobbyMentors.contains('small_chest_4'), isFalse);
      expect(lobbyMentors.contains('small_chest_8'), isFalse);

      // 2. Solid furniture colliders include bookcases/vending/park rocks & bushes while keeping A* walkable
      final lobbySolids = buildLobbySolids(
        service.subjectChests,
        room: LobbyRoomId.mainLobby,
      );
      final parkSolids = buildLobbySolids(
        service.subjectChests,
        room: LobbyRoomId.park,
      );
      expect(lobbySolids.length, greaterThan(10));
      expect(parkSolids.length, greaterThan(12));
      final nav = LobbyNavGrid(
        cols: kLobbyCols,
        rows: kLobbyRows,
        solids: lobbySolids,
      );
      expect(nav.findPath(kPlayerSpawnPoint, const Offset(768, 196)), isNotEmpty);

      // 3. Avatar Nickname Profanity Sanitization (local save + incoming MQTT/UDP payload)
      await AvatarSpriteCache.instance.saveNickname('2024-00444', 'gago_student');
      final savedNick = await AvatarSpriteCache.instance.loadSavedNickname(
        '2024-00444',
        fallbackName: 'Student',
      );
      expect(savedNick.toLowerCase().contains('gago'), isFalse);

      final presence = LobbyPresenceService.instance;
      presence.enableNetworkTransport = false;
      presence.handleIncomingPresencePayload({
        'app': 'mis_shs_lobby_v1',
        'type': 'hello_join',
        'peerKey': '2024-00777_12345',
        'userId': '2024-00777',
        'nickname': 'putangina_troll',
        'room': 'mainLobby',
        'x': 500.0,
        'y': 500.0,
      });
      final remote = presence.allRemotePlayers
          .firstWhere((p) => p.userId == '2024-00777');
      expect(remote.nickname.toLowerCase().contains('putangina'), isFalse);
      presence.handleIncomingPresencePayload({
        'app': 'mis_shs_lobby_v1',
        'type': 'leave',
        'peerKey': '2024-00777_12345',
      });

      // 4. Campus Radio remote sync clamps malicious future timestamps (+24h skew)
      final radio = LobbyRadioService.instance;
      radio.resetForTesting();
      final localNow = 1700000000000;
      final forgedFutureTs = localNow + (24 * 60 * 60 * 1000);
      radio.applyRemoteRadioSync(
        stationId: 'rg_manila_opm',
        changedAtMs: forgedFutureTs,
        changedBy: 'SkewedPeer',
        localNowMs: localNow,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(radio.lastChangedAtMs, lessThanOrEqualTo(localNow));
      expect(
        radio.remainingCooldownSeconds(nowMs: localNow),
        lessThanOrEqualTo(3600),
      );
    },
  );

  test(
    'Part 5/6: ReviewerOutlineExtractor Slide Regex & Entities, Drive Chest Sync, Schedule Dismissal & Dark Mode',
    () async {
      // 1. Verify ReviewerOutlineExtractor does NOT split slide-header/slide-body into fake parts
      //    and does NOT double-unescape `&amp;lt;`!
      const sampleHtml = '''
        <section class="slide">
          <div class="slide-header"><h1>Philippine Constitution</h1></div>
          <div class="slide-body"><p>Article II &amp;lt;Sovereignty&amp;gt; resides in the people.</p></div>
        </section>
        <section class="slide">
          <div class="slide-title"><h2>Three Co-Equal Branches</h2></div>
          <div class="slide-body"><p>Legislative, Executive, and Judicial.</p></div>
        </section>
      ''';
      final extracted = ReviewerOutlineExtractor.extractOutline(
        rawHtml: sampleHtml,
        reviewerTitle: 'PPG Week 3',
      );
      expect(extracted.contains('[PART 1 OF 2]'), isTrue);
      expect(extracted.contains('[PART 2 OF 2]'), isTrue);
      expect(extracted.contains('[PART 3 OF'), isFalse);
      expect(extracted.contains('&lt;Sovereignty&gt;'), isTrue);

      // 2. Verify Google Drive Reviewer syncing populates `driveFileId` (`isFromDrive == true`) cleanly
      final service = LobbyDataService.instance;
      await service.init('2024-00515');
      final added = service.mergeDriveReviewerFilesForSubject(
        'PPG',
        const <ReviewerFile>[
          ReviewerFile(
            id: 'drive_abc123',
            name: 'Week 4 Checks and Balances.html',
            mimeType: 'text/html',
            url: 'https://drive.google.com/file/d/drive_abc123/view',
          ),
        ],
      );
      expect(added, 1);
      // Duplicate merge is a no-op
      final addedAgain = service.mergeDriveReviewerFilesForSubject(
        'PPG',
        const <ReviewerFile>[
          ReviewerFile(
            id: 'drive_abc123',
            name: 'Week 4 Checks and Balances.html',
            mimeType: 'text/html',
            url: 'https://drive.google.com/file/d/drive_abc123/view',
          ),
        ],
      );
      expect(addedAgain, 0);
      final ppgChest = service.subjectChests.firstWhere(
        (c) => LobbyDataService.normalizeSubjectCode(c.subjectName) == 'PPG',
      );
      final driveItem = ppgChest.reviewers
          .firstWhere((r) => r.driveFileId == 'drive_abc123');
      expect(driveItem.isFromDrive, isTrue);
      expect(driveItem.fileType, 'HTML');

      // 3. Verify StudentScheduleOverlay per-period dismissal stays dismissed for the same class
      final p1 = StudentScheduleOverlay.buildScheduleSessionKey(
          'Monday', 'PPG', '08:00 AM');
      final p2 = StudentScheduleOverlay.buildScheduleSessionKey(
          'Monday', 'UCSP', '09:30 AM');
      expect(
        StudentScheduleOverlay.shouldShowInClassWarning(
          activeSessionKey: p1,
          dismissedSessionKey: null,
        ),
        isTrue,
      );
      expect(
        StudentScheduleOverlay.shouldShowInClassWarning(
          activeSessionKey: p1,
          dismissedSessionKey: p1,
        ),
        isFalse,
      );
      expect(
        StudentScheduleOverlay.shouldShowInClassWarning(
          activeSessionKey: p2,
          dismissedSessionKey: p1,
        ),
        isTrue,
      );

      // 4. Verify Dark Mode activeCard & activeBg switch cleanly
      await ThemeController.instance.setDarkMode(true);
      expect(PortalColors.activeCard, PortalColors.darkSurface);
      expect(PortalColors.activeBg, PortalColors.darkBg);
      await ThemeController.instance.setDarkMode(false);
      expect(PortalColors.activeCard, Colors.white);
      expect(PortalColors.activeBg, PortalColors.parchment);
    },
  );

  test(
    'Part 6/6: Cloud Save + SovereignCampaignSave Merge, spentXp Union Reconciliation, iOS NDEF UTF-16/URI, WorkManager Scanner Creds, ApiException & Retry Cap',
    () async {
      // 1. Multi-device cloud merge: union unlocked cosmetics must sum paid costs (preventing XP duplication)
      //    and merge bundled SovereignCampaignSave Charter Seals & Saligang Tala entries.
      const localProgress = StudentLobbyProgress(
        xp: 400,
        spentXp: 90,
        unlockedCosmetics: <String>{'hat:5-1', 'outfit:1-1'}, // hat:5-1 = 90 XP, outfit:1-1 = starter (0 XP)
      );
      const localCampaign = SovereignCampaignSave(
        currentActNumber: 2,
        earnedSealIds: <String>{'seal_act1_balangay'},
        unlockedSaligangTalaIds: <String>{'tala_barangay', 'tala_datu'},
        activatedPuzzleNodeIds: <String>{'act1_node_1'},
      );
      const cloudCampaign = SovereignCampaignSave(
        currentActNumber: 4,
        earnedSealIds: <String>{'seal_act1_balangay', 'seal_act3_malolos'},
        unlockedSaligangTalaIds: <String>{'tala_malolos'},
        defeatedEntityIds: <String>{'act3_boss_calderon'},
      );
      final cloudPayload = <String, dynamic>{
        ...const StudentLobbyProgress(
          xp: 350,
          spentXp: 75,
          unlockedCosmetics: <String>{'outfit:4-1'}, // outfit:4-1 = 75 XP
        ).toJson(),
        'sovereignCampaign': cloudCampaign.toJson(),
      };

      final merged = LobbyDataService.mergeCloudPayload(
        localProgress: localProgress,
        localCampaign: localCampaign,
        cloudPayload: cloudPayload,
      );
      expect(merged.progress.xp, 400);
      expect(
        merged.progress.unlockedCosmetics,
        containsAll(<String>['hat:5-1', 'outfit:4-1', 'outfit:1-1']),
      );
      // 90 (hat:5-1) + 75 (outfit:4-1) + 0 (starter outfit:1-1) = 165 XP spent
      expect(merged.progress.spentXp, 165);
      expect(merged.progress.availableXp, 235);
      expect(merged.campaign, isNotNull);
      expect(merged.campaign!.currentActNumber, 4);
      expect(
        merged.campaign!.earnedSealIds,
        containsAll(<String>['seal_act1_balangay', 'seal_act3_malolos']),
      );
      expect(
        merged.campaign!.unlockedSaligangTalaIds,
        containsAll(<String>['tala_barangay', 'tala_datu', 'tala_malolos']),
      );
      expect(merged.campaign!.defeatedEntityIds, contains('act3_boss_calderon'));
      expect(merged.campaign!.activatedPuzzleNodeIds, contains('act1_node_1'));

      // 2. iOS NFC NDEF decoding: UTF-8 Text, UTF-16 BE/LE Text with BOM, and 0x55 URI Prefix restoration
      final utf8TextPayload = <int>[0x02, 0x65, 0x6E, ...utf8.encode('2024-00123')];
      expect(
        decodeNdefPayloadBytes(type: const [0x54], payload: utf8TextPayload),
        '2024-00123',
      );
      // UTF-16 BE with BOM (0xFE, 0xFF) for "AB-9"
      final utf16BePayload = <int>[
        0x82, // UTF-16 bit (0x80) | langLen=2
        0x65, 0x6E, // "en"
        0xFE, 0xFF, // BE BOM
        0x00, 0x41, // 'A'
        0x00, 0x42, // 'B'
        0x00, 0x2D, // '-'
        0x00, 0x39, // '9'
      ];
      expect(
        decodeNdefPayloadBytes(type: const [0x54], payload: utf16BePayload),
        'AB-9',
      );
      // UTF-16 LE with BOM (0xFF, 0xFE) for "2024"
      final utf16LePayload = <int>[
        0x82,
        0x65, 0x6E,
        0xFF, 0xFE, // LE BOM
        0x32, 0x00, // '2'
        0x30, 0x00, // '0'
        0x32, 0x00, // '2'
        0x34, 0x00, // '4'
      ];
      expect(
        decodeNdefPayloadBytes(type: const [0x54], payload: utf16LePayload),
        '2024',
      );
      // URI Record (0x55) with prefix code 0x04 ("https://")
      final uriPayload = <int>[
        0x04,
        ...utf8.encode('portal.mis.edu/pass?id=2024-00123'),
      ];
      final decodedUri =
          decodeNdefPayloadBytes(type: const [0x55], payload: uriPayload);
      expect(decodedUri, 'https://portal.mis.edu/pass?id=2024-00123');
      expect(Uri.tryParse(decodedUri)?.queryParameters['id'], '2024-00123');

      // 3. Background WorkManager scanner sync credentials survive "Stay Signed In = false"
      //    and are cleanly cleared on explicit logout.
      final facultySession = UserSession(
        id: 'FAC-001',
        name: 'Prof. Santos',
        isFaculty: true,
        subjects: const <SubjectItem>[],
        scannerAuthToken: 'hmac-scanner-token-123',
      );
      await SessionService.instance.saveSession(
        facultySession,
        staySignedIn: false,
      );
      SessionService.instance.resetMemoryCacheForTesting();
      expect(await SessionService.instance.restoreSession(), isNull);
      final bgCreds = await SessionService.instance.getScannerSyncCredentials();
      expect(bgCreds, isNotNull);
      expect(bgCreds!.facultyId, 'FAC-001');
      expect(bgCreds.scannerAuthToken, 'hmac-scanner-token-123');

      await SessionService.instance.clearSession();
      expect(await SessionService.instance.getScannerSyncCredentials(), isNull);

      // 4. ApiService.assertServerSuccess throws server-rejection ApiException (not masked by kv_cache)
      expect(
        () => ApiService.assertServerSuccess(
          const <String, dynamic>{
            'success': false,
            'message': 'Records not found.',
          },
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isServerRejection, 'isServerRejection', isTrue)
              .having((e) => e.message, 'message', 'Records not found.'),
        ),
      );
      expect(
        () => ApiService.assertServerSuccess(
          const <String, dynamic>{
            'status': 'ERROR',
            'message': 'Portal maintenance error',
          },
          checkStatusErrorOnly: true,
        ),
        throwsA(
          isA<ApiException>()
              .having((e) => e.isServerRejection, 'isServerRejection', isTrue),
        ),
      );

      // 5. LocalDatabase retry cap prevents malformed rows (>= 5 retries) from starving the queue
      final retryableScan = ScanLogEntry(
        logId: 'log_ok',
        scanType: ScanMode.attendance,
        timestamp: '2026-11-23 08:00:00',
        studentId: '2024-00123',
        subject: 'PPG',
        pointsAwarded: null,
        syncStatus: 'failed',
        retryCount: 4,
        createdAt: 1000,
      );
      final quarantinedScan = ScanLogEntry(
        logId: 'log_bad',
        scanType: ScanMode.attendance,
        timestamp: '2026-11-23 08:01:00',
        studentId: '2024-00123',
        subject: 'PPG',
        pointsAwarded: null,
        syncStatus: 'failed',
        retryCount: 5,
        createdAt: 1001,
      );
      final syncedScan = ScanLogEntry(
        logId: 'log_done',
        scanType: ScanMode.recitation,
        timestamp: '2026-11-23 08:02:00',
        studentId: '2024-00123',
        subject: 'PPG',
        pointsAwarded: 1,
        syncStatus: 'synced',
        retryCount: 0,
        createdAt: 1002,
      );
      expect(LocalDatabase.isEligibleForRetry(retryableScan), isTrue);
      expect(LocalDatabase.isEligibleForRetry(quarantinedScan), isFalse);
      expect(LocalDatabase.isEligibleForRetry(syncedScan), isFalse);
    },
  );

  testWidgets(
    'SpriteCast Integration: Unique Per-Student Classroom Desks, Claimable Seats, Multiplayer Desk Sync & Live Pixel Desk Studio',
    (WidgetTester tester) async {
      // 1. All 10 personal desks have distinct geometry and desk numbers 1..10
      expect(kClassroomDeskGeometries.length, 10);
      expect(
        kClassroomDeskGeometries.map((g) => g.deskNumber).toSet().length,
        10,
      );
      expect(
        kClassroomDeskGeometries.map((g) => g.deskRect).toSet().length,
        10,
      );

      // 2. Different students receive distinct personal desks (no longer forced onto 1 shared desk!)
      final assignedDesks = <String>{
        assignedClassroomDeskSpotIdForStudent('2024-00101'),
        assignedClassroomDeskSpotIdForStudent('2024-00102'),
        assignedClassroomDeskSpotIdForStudent('2024-00103'),
        assignedClassroomDeskSpotIdForStudent('2024-00104'),
        assignedClassroomDeskSpotIdForStudent('2024-00105'),
      };
      expect(assignedDesks.length, greaterThanOrEqualTo(4));

      // 3. Students can claim a specific personal desk and persist it in StudentLobbyProgress
      final dataService = LobbyDataService.instance;
      await dataService.init('2024-00612');
      await dataService.setAssignedDeskSpotId('rest_classroom_r3_c4');
      expect(dataService.progress.assignedDeskSpotId, 'rest_classroom_r3_c4');
      expect(
        canStudentSitAtSpot(
          spotId: 'rest_classroom_r3_c4',
          studentId: '2024-00612',
          preferredDeskSpotId: dataService.progress.assignedDeskSpotId,
          isFaculty: false,
        ),
        isTrue,
      );
      expect(
        canStudentSitAtSpot(
          spotId: 'rest_classroom_r1_c2',
          studentId: '2024-00612',
          preferredDeskSpotId: dataService.progress.assignedDeskSpotId,
          isFaculty: false,
        ),
        isFalse,
      );

      // 4. Multiplayer presence carries each classmate's claimed desk & SpriteCast decor live
      final presence = LobbyPresenceService.instance;
      presence.handleIncomingPresencePayload(<String, dynamic>{
        'app': 'mis_shs_lobby_v1',
        'type': 'state',
        'peerKey': 'peer_desk_test_1',
        'userId': '2024-00988',
        'nickname': 'Luna_HUMSS',
        'isFaculty': false,
        'look': 'preset:Alex',
        'desk': 'rest_classroom_r2_c3',
        'decor': 'cyber_neon|galaxy_mat|starlight_lantern|holo_plaque|zen_bonsai',
        'room': 'classroom',
        'x': 960,
        'y': 606,
        'facing': 'up',
        'isWalking': false,
        'rest': 'sitting',
        'sessionMs': 2000,
        'seq': 1,
      });
      final luna = presence.allRemotePlayers
          .firstWhere((p) => p.userId == '2024-00988');
      expect(luna.deskSpotId, 'rest_classroom_r2_c3');
      expect(luna.tableDecor.chairStyle, 'cyber_neon');
      expect(luna.tableDecor.deskMat, 'galaxy_mat');
      expect(luna.tableDecor.miniLight, 'starlight_lantern');
      expect(luna.tableDecor.deskFrame, 'holo_plaque');
      expect(luna.tableDecor.deskProp, 'zen_bonsai');

      // 5. SpriteCast palettes, quantized wind sway, and Desk Studio pixel widgets render cleanly
      expect(SpriteCastPalette.endesga32.length, 32);
      expect(SpriteCastPalette.sweetie16.length, 16);
      final swayVal = SpriteCastEngine.windSwayPx(15, 7, px: 1.0);
      expect(<double>[-1.0, 0.0, 1.0].contains(swayVal), isTrue);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                SpriteCastDeskStudioPreview(
                  decor: LobbyTableDecorConfig(
                    chairStyle: 'cyber_neon',
                    deskMat: 'galaxy_mat',
                    miniLight: 'starlight_lantern',
                    deskFrame: 'holo_plaque',
                    deskProp: 'zen_bonsai',
                  ),
                  ownerLabel: "★ Alon's Desk #10",
                  nightPreview: true,
                  animTick: 12,
                ),
                SpriteCastDeskItemThumbnail(
                  category: 'table_prop',
                  partId: 'trophy_mug',
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(SpriteCastDeskStudioPreview), findsOneWidget);
      expect(find.byType(SpriteCastDeskItemThumbnail), findsOneWidget);
    },
  );

  test(
    'Dungeon Part 1/8: 19 Tile Types, 7 Era Themes, 10 Charms, 5 Silk Skills, Save Merge & Silksong 2D Physics (Coyote, Buffer, Wall-Jump, Dash, Pogo, Grapple, Crumble, Spikes)',
    () {
      // 1. Models, Themes, Charms, Skills & Save round-trip/merge
      expect(kDungeonEraThemes.length, 7);
      expect(kDungeonCharmCatalog.length, 10);
      expect(kDungeonSilkSkills.length, 5);
      expect(dungeonTileFromChar('^').isPogoTarget, isTrue);
      expect(dungeonTileFromChar('O').isPogoTarget, isTrue);
      expect(dungeonTileFromChar('=').isOneWay, isTrue);
      expect(dungeonTileFromChar('H').isClimbable, isTrue);

      const saveA = DungeonProgressSave(
        archipelagoShards: 85,
        bladeTier: DungeonBladeTier.kampilanEdge,
        unlockedCharmIds: <String>{'tarsier_lantern', 'quick_slash_bolo'},
        equippedCharmIds: <String>['tarsier_lantern', 'quick_slash_bolo'],
        defeatedBossIds: <String>{'boss_act1_datu'},
      );
      final roundTrip = DungeonProgressSave.fromJson(saveA.toJson());
      expect(roundTrip.archipelagoShards, 85);
      expect(roundTrip.bladeTier, DungeonBladeTier.kampilanEdge);
      expect(roundTrip.usedCharmNotches, 3); // 1 + 2

      const saveB = DungeonProgressSave(
        archipelagoShards: 120,
        bladeTier: DungeonBladeTier.malolosSteel,
        unlockedCharmIds: <String>{'tarsier_lantern', 'sovereign_heart'},
        defeatedBossIds: <String>{'boss_act2_governor'},
      );
      final mergedSave = saveA.mergeWith(saveB);
      expect(mergedSave.archipelagoShards, 120);
      expect(mergedSave.bladeTier, DungeonBladeTier.malolosSteel);
      expect(
        mergedSave.unlockedCharmIds,
        containsAll(<String>['tarsier_lantern', 'quick_slash_bolo', 'sovereign_heart']),
      );
      expect(
        mergedSave.defeatedBossIds,
        containsAll(<String>['boss_act1_datu', 'boss_act2_governor']),
      );

      // 2. Test Chamber (24 x 12 tiles) with ledge, one-way bridge, wall, grapple ring, crumble block & spikes
      const testChamberSpec = DungeonChamberSpec(
        id: 'test_physics_room',
        actNumber: 1,
        title: 'Physics Crucible',
        subtitle: 'Unit Test Chamber',
        defaultSpawnCol: 2,
        defaultSpawnRow: 8,
        asciiGrid: <String>[
          '########################',
          '#......................#',
          '#......................#',
          '#..........G...........#',
          '#......................#',
          '#....====..............#',
          '#......................#',
          '#...............#......#',
          '#...............#......#',
          '######..CC....^^#......#',
          '#...............#......#',
          '########################',
        ],
      );

      final engine = DungeonPhysicsEngine();

      // 2a. Coyote Time: walk off row 9 ledge (col 5 -> col 6), wait 50ms airborne, jump still fires!
      final chamber1 = DungeonChamberRuntime(testChamberSpec);
      final player = DungeonPlayerPhysicsState(
        x: 5 * kDungeonTileSize + 2,
        y: 9 * kDungeonTileSize - 14.0,
      );
      // Settle on ledge first
      engine.step(
        dt: 1 / 60,
        player: player,
        chamber: chamber1,
        input: const DungeonPlayerInput(),
      );
      expect(player.isGrounded, isTrue);
      // Step right off the ledge into air (col 6)
      player.x = 6 * kDungeonTileSize + 4;
      engine.step(
        dt: 0.05,
        player: player,
        chamber: chamber1,
        input: const DungeonPlayerInput(moveX: 1.0),
      );
      expect(player.isGrounded, isFalse);
      expect(player.coyoteTimer, greaterThan(0.0));
      final coyoteEvents = engine.step(
        dt: 1 / 60,
        player: player,
        chamber: chamber1,
        input: const DungeonPlayerInput(jumpJustPressed: true, jumpHeld: true),
      );
      expect(
        coyoteEvents.any((e) => e.kind == DungeonPhysicsEventKind.jumped),
        isTrue,
      );
      expect(player.vy, lessThan(-300.0));

      // 2b. Jump Buffering: press jump slightly before landing -> auto-jumps on touch!
      final pBuf = DungeonPlayerPhysicsState(
        x: 2 * kDungeonTileSize,
        y: 9 * kDungeonTileSize - 22.0,
        vy: 140.0,
      );
      final bufEvents = <DungeonPhysicsEvent>[];
      bufEvents.addAll(
        engine.step(
          dt: 1 / 60,
          player: pBuf,
          chamber: chamber1,
          input: const DungeonPlayerInput(jumpJustPressed: true, jumpHeld: true),
        ),
      );
      for (var i = 0; i < 6; i++) {
        bufEvents.addAll(
          engine.step(
            dt: 1 / 60,
            player: pBuf,
            chamber: chamber1,
            input: const DungeonPlayerInput(jumpHeld: true),
          ),
        );
      }
      expect(
        bufEvents.any((e) => e.kind == DungeonPhysicsEventKind.jumped),
        isTrue,
      );

      // 2c. One-Way Platform landing & Down+Jump Drop-Through
      final pOneWay = DungeonPlayerPhysicsState(
        x: 6 * kDungeonTileSize,
        y: 5 * kDungeonTileSize - 16.0,
        vy: 80.0,
      );
      for (var i = 0; i < 6; i++) {
        engine.step(
          dt: 1 / 60,
          player: pOneWay,
          chamber: chamber1,
          input: const DungeonPlayerInput(),
        );
      }
      expect(pOneWay.isGrounded, isTrue);
      expect(pOneWay.isOnOneWayPlatform, isTrue);
      final yOnBridge = pOneWay.y;
      engine.step(
        dt: 1 / 60,
        player: pOneWay,
        chamber: chamber1,
        input: const DungeonPlayerInput(moveY: 1.0, jumpJustPressed: true),
      );
      for (var i = 0; i < 6; i++) {
        engine.step(
          dt: 1 / 60,
          player: pOneWay,
          chamber: chamber1,
          input: const DungeonPlayerInput(),
        );
      }
      expect(pOneWay.y, greaterThan(yOnBridge + 8.0));

      // 2d. Wall-Slide & Wall-Jump off col 16 solid pillar
      final pWall = DungeonPlayerPhysicsState(
        x: 16 * kDungeonTileSize - 10.5,
        y: 7 * kDungeonTileSize,
        vy: 260.0,
      );
      engine.step(
        dt: 0.04,
        player: pWall,
        chamber: chamber1,
        input: const DungeonPlayerInput(moveX: 1.0),
      );
      expect(pWall.isWallSliding, isTrue);
      expect(pWall.vy, lessThanOrEqualTo(engine.tunables.wallSlideMaxFall + 1.0));
      final wjEvents = engine.step(
        dt: 1 / 60,
        player: pWall,
        chamber: chamber1,
        input: const DungeonPlayerInput(
          moveX: 1.0,
          jumpJustPressed: true,
          jumpHeld: true,
        ),
      );
      expect(
        wjEvents.any((e) => e.kind == DungeonPhysicsEventKind.wallJumped),
        isTrue,
      );
      expect(pWall.vx, lessThan(-150.0)); // kicked left away from right wall
      expect(pWall.vy, lessThan(-300.0));

      // 2e. Air Silk Dash (consumes airDash + grants i-frames + ghost trail) & Pogo Reset!
      final pDash = DungeonPlayerPhysicsState(
        x: 6 * kDungeonTileSize,
        y: 2 * kDungeonTileSize,
        facing: 1,
      );
      final dashEvents = engine.step(
        dt: 0.04,
        player: pDash,
        chamber: chamber1,
        input: const DungeonPlayerInput(dashJustPressed: true),
      );
      expect(
        dashEvents.any((e) => e.kind == DungeonPhysicsEventKind.dashed),
        isTrue,
      );
      expect(pDash.isDashing, isTrue);
      expect(pDash.isInvulnerable, isTrue);
      expect(pDash.airDashAvailable, isFalse);
      expect(pDash.afterimages, isNotEmpty);

      final pogoEvt = engine.triggerPogoBounce(pDash, hasDoubleJumpCharm: true);
      expect(pogoEvt.kind, DungeonPhysicsEventKind.pogoBounced);
      expect(pDash.vy, lessThan(-350.0));
      expect(pDash.airDashAvailable, isTrue);
      expect(pDash.doubleJumpAvailable, isTrue);

      // 2f. Silk-Needle Grapple Hook zips toward Grapple Ring (`G` at col 11, row 3)
      final pGrapple = DungeonPlayerPhysicsState(
        x: 6 * kDungeonTileSize,
        y: 4 * kDungeonTileSize,
        facing: 1,
      );
      final grEvents = engine.step(
        dt: 1 / 60,
        player: pGrapple,
        chamber: chamber1,
        input: const DungeonPlayerInput(grappleJustPressed: true),
      );
      expect(
        grEvents.any((e) => e.kind == DungeonPhysicsEventKind.grappleStarted),
        isTrue,
      );
      expect(pGrapple.grappleActive, isTrue);
      expect(pGrapple.vx, greaterThan(200.0));

      // 2g. Crumble Block (`C` at col 8, row 9) collapses after 0.45s and regenerates
      final pCrumble = DungeonPlayerPhysicsState(
        x: 8 * kDungeonTileSize + 2,
        y: 9 * kDungeonTileSize - 14.0,
      );
      for (var i = 0; i < 36; i++) {
        engine.step(
          dt: 1 / 60,
          player: pCrumble,
          chamber: chamber1,
          input: const DungeonPlayerInput(),
        );
      }
      expect(chamber1.effectiveTileAt(8, 9), DungeonTileType.empty);

      // 2h. Spike Hazard Recovery (`^` at col 14, row 9) deducts 1 HP and restores safe ground
      final pSpike = DungeonPlayerPhysicsState(
        x: 2 * kDungeonTileSize,
        y: 9 * kDungeonTileSize - 14.0,
        resolveHp: 6,
      );
      engine.step(
        dt: 1 / 60,
        player: pSpike,
        chamber: chamber1,
        input: const DungeonPlayerInput(),
      );
      final safeX = pSpike.lastSafeGroundX;
      // Drop onto spike at col 14, row 9
      pSpike.x = 14 * kDungeonTileSize + 2;
      pSpike.y = 9 * kDungeonTileSize + 1;
      final spikeEvents = engine.step(
        dt: 1 / 60,
        player: pSpike,
        chamber: chamber1,
        input: const DungeonPlayerInput(),
      );
      expect(
        spikeEvents.any((e) => e.kind == DungeonPhysicsEventKind.hazardHit),
        isTrue,
      );
      expect(pSpike.resolveHp, 5);
      expect(pSpike.x, closeTo(safeX, 1.0));
      expect(pSpike.isInvulnerable, isTrue);
    },
  );

  test(
    'Dungeon Part 2/8: 3-Hit Combo, Pogo-Lanterns, 5 Constitutional Silk Skills, Golden Parry, Projectile Deflection, Breakables/Switches & 22 Procedural WAV SFX',
    () {
      // 1. Hit-Stop Manager: longest freeze wins & scales dt cleanly
      final hs = DungeonHitStopManager();
      hs.trigger(0.085);
      hs.trigger(0.040); // shorter freeze must NOT overwrite 85ms freeze
      expect(hs.remainingSec, closeTo(0.085, 0.001));
      final scaledDt = hs.applyToDt(0.016);
      expect(scaledDt, closeTo(0.016 * 0.05, 0.0002));
      expect(hs.isFrozen, isTrue);
      hs.applyToDt(0.10);
      expect(hs.isFrozen, isFalse);
      expect(hs.applyToDt(0.016), closeTo(0.016, 0.0001));

      // 2. Combat test chamber with crate ('X'), crystal ('*'), switch ('S'), gate ('D'), secret ('?'), lantern ('O')
      const combatRoomSpec = DungeonChamberSpec(
        id: 'test_combat_room',
        actNumber: 3,
        title: 'Combat Arena',
        subtitle: 'Part 2 Verification',
        defaultSpawnCol: 2,
        defaultSpawnRow: 8,
        asciiGrid: <String>[
          '########################',
          '#......................#',
          '#......................#',
          '#......................#',
          '#..........O...........#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#....X..*..S..D..?.....#',
          '########################',
        ],
      );

      final chamber = DungeonChamberRuntime(combatRoomSpec);
      final physics = DungeonPhysicsEngine();
      final combat = DungeonCombatEngine();

      const fullProgress = DungeonProgressSave(
        bladeTier: DungeonBladeTier.kampilanEdge, // 15 base dmg
        equippedCharmIds: <String>[
          'quick_slash_bolo',
          'long_needle',
          'babaylan_bind',
          'iron_parry_crest',
          'scholars_silk',
        ],
        unlockedSkills: <DungeonSilkSkillId>{
          DungeonSilkSkillId.sanduguanThread,
          DungeonSilkSkillId.silkBind,
          DungeonSilkSkillId.scalesTempest,
          DungeonSilkSkillId.habeasAegis,
          DungeonSilkSkillId.sovereignSunburst,
        },
      );

      // 3. 3-Hit Combo against dummy target + Scholar's Silk generation
      final dummy = _MockCombatTarget(
        id: 'enemy_1',
        hitbox: Rect.fromLTWH(52, 114, 14, 14),
        hp: 200,
      );
      final player = DungeonPlayerPhysicsState(
        x: 32,
        y: 114,
        facing: 1,
        isGrounded: true,
        resolveHp: 3,
        maxResolveHp: 6,
        civicSilk: 20.0,
      );

      final hitAmounts = <int>[];
      for (var stepIdx = 0; stepIdx < 3; stepIdx++) {
        // Let cooldown finish between swings
        combat.slashCooldownTimer = 0.0;
        final evs = combat.step(
          dt: 1 / 60,
          player: player,
          chamber: chamber,
          input: const DungeonPlayerInput(slashJustPressed: true),
          progress: fullProgress,
          physicsEngine: physics,
          targets: <DungeonCombatTarget>[dummy],
        );
        final hitEv = evs.firstWhere((e) => e.kind == DungeonCombatEventKind.enemyHit);
        hitAmounts.add(hitEv.value);
        // Clear finished slash before next swing
        combat.activeSlashes.clear();
      }
      // Step 0 & 1 = 15 dmg; Step 2 finisher (+25%) = 19 dmg!
      expect(hitAmounts[0], 15);
      expect(hitAmounts[1], 15);
      expect(hitAmounts[2], 19);
      // 3 hits * 14 silk (Scholar's Silk) + 20 starting = 62 silk
      expect(player.civicSilk, closeTo(62.0, 0.5));

      // 4. Downward Pogo-Slash onto Pogo-Lantern ('O' at col 11, row 4 -> x:176..192, y:64..80)
      player.x = 11 * kDungeonTileSize + 2;
      player.y = 3 * kDungeonTileSize;
      player.isGrounded = false;
      player.airDashAvailable = false;
      combat.slashCooldownTimer = 0.0;
      final pogoEvents = combat.step(
        dt: 1 / 60,
        player: player,
        chamber: chamber,
        input: const DungeonPlayerInput(moveY: 1.0, slashJustPressed: true),
        progress: fullProgress,
        physicsEngine: physics,
      );
      expect(
        pogoEvents.any((e) => e.kind == DungeonCombatEventKind.pogoLanternStruck),
        isTrue,
      );
      expect(player.vy, lessThan(-350.0));
      expect(player.airDashAvailable, isTrue);

      // 5. Scales Tempest deflects incoming enemy projectile!
      combat.activeSlashes.clear();
      player.x = 120;
      player.y = 110;
      player.civicSilk = 100.0;
      final enemyBolt = DungeonProjectile(
        id: 'bolt_1',
        isPlayerOwned: false,
        x: 138,
        y: 117,
        vx: -120.0,
        vy: 0.0,
        damage: 1,
        color: Colors.red,
      );
      combat.projectiles.add(enemyBolt);
      final skillEvs = <DungeonCombatEvent>[];
      expect(
        combat.tryCastSilkSkill(
          skillId: DungeonSilkSkillId.scalesTempest,
          player: player,
          progress: fullProgress,
          events: skillEvs,
        ),
        isTrue,
      );
      final tempestStepEvs = combat.step(
        dt: 1 / 60,
        player: player,
        chamber: chamber,
        input: const DungeonPlayerInput(),
        progress: fullProgress,
        physicsEngine: physics,
      );
      expect(
        tempestStepEvs.any((e) => e.kind == DungeonCombatEventKind.projectileDeflected),
        isTrue,
      );
      expect(enemyBolt.isPlayerOwned, isTrue);
      expect(enemyBolt.vx, greaterThan(120.0));

      // 6. Habeas Aegis Golden Parry: 0 damage, 100ms freeze, +35 Silk refund, counter-blast!
      combat.activeSkills.clear();
      player.civicSilk = 40.0;
      player.resolveHp = 4;
      player.invulnTimer = 0.0;
      final parryTarget = _MockCombatTarget(
        id: 'enemy_parry',
        hitbox: Rect.fromLTWH(142, 108, 16, 16),
        hp: 100,
      );
      final castParryEvs = <DungeonCombatEvent>[];
      expect(
        combat.tryCastSilkSkill(
          skillId: DungeonSilkSkillId.habeasAegis,
          player: player,
          progress: fullProgress,
          events: castParryEvs,
        ),
        isTrue,
      );
      expect(combat.isParryActive, isTrue);
      final parryRes = combat.resolveIncomingPlayerHit(
        player: player,
        progress: fullProgress,
        damage: 2,
        sourceX: 150,
        sourceY: 114,
        targets: <DungeonCombatTarget>[parryTarget],
        events: castParryEvs,
      );
      expect(parryRes.parried, isTrue);
      expect(parryRes.damaged, isFalse);
      expect(player.resolveHp, 4); // 0 damage taken!
      expect(player.civicSilk, closeTo(55.0, 0.5)); // 40 - 20 + 35 = 55!
      expect(combat.hitStop.remainingSec, closeTo(0.100, 0.005));
      expect(parryTarget.hp, lessThan(100)); // counter-blasted!

      // 7. Silk Bind healing channel (Babaylan Fast-Bind = 0.46s -> +3 Resolve Masks!)
      player.resolveHp = 2;
      player.civicSilk = 50.0;
      final bindEvs = <DungeonCombatEvent>[];
      for (var i = 0; i < 35; i++) {
        bindEvs.addAll(
          combat.step(
            dt: 1 / 60,
            player: player,
            chamber: chamber,
            input: const DungeonPlayerInput(healHeld: true),
            progress: fullProgress,
            physicsEngine: physics,
          ),
        );
      }
      expect(
        bindEvs.any((e) => e.kind == DungeonCombatEventKind.bindCompleted),
        isTrue,
      );
      expect(player.resolveHp, 5); // 2 + 3 = 5!

      // 8. Sovereign Sunburst ultimate beam hits distant enemy across the arena
      player.x = 32;
      player.y = 110;
      player.facing = 1;
      player.civicSilk = 80.0;
      final farBoss = _MockCombatTarget(
        id: 'boss_far',
        hitbox: Rect.fromLTWH(200, 108, 22, 22),
        hp: 300,
      );
      final beamEvs = <DungeonCombatEvent>[];
      expect(
        combat.tryCastSilkSkill(
          skillId: DungeonSilkSkillId.sovereignSunburst,
          player: player,
          progress: fullProgress,
          events: beamEvs,
        ),
        isTrue,
      );
      combat.step(
        dt: 1 / 60,
        player: player,
        chamber: chamber,
        input: const DungeonPlayerInput(),
        progress: fullProgress,
        physicsEngine: physics,
        targets: <DungeonCombatTarget>[farBoss],
      );
      expect(farBoss.hp, lessThan(250)); // 15 * 4.2 = 63 dmg!

      // 9. Breakables: Crate ('X' col 5), Crystal ('*' col 8), Switch ('S' col 11 -> unlocks 'D' col 14), Secret ('?' col 17)
      // Break crate at col 5, row 8
      player.x = 4 * kDungeonTileSize;
      player.y = 8 * kDungeonTileSize;
      player.facing = 1;
      combat.slashCooldownTimer = 0.0;
      combat.activeSlashes.clear();
      combat.step(
        dt: 1 / 60,
        player: player,
        chamber: chamber,
        input: const DungeonPlayerInput(slashJustPressed: true),
        progress: fullProgress,
        physicsEngine: physics,
      );
      expect(chamber.effectiveTileAt(5, 8), DungeonTileType.empty);
      expect(chamber.lootDrops, isNotEmpty);

      // Hit switch at col 11, row 8 -> unlocks gate 'D' at col 14, row 8
      expect(chamber.isSolidAt(14, 8), isTrue);
      player.x = 10 * kDungeonTileSize;
      combat.slashCooldownTimer = 0.0;
      combat.activeSlashes.clear();
      combat.step(
        dt: 1 / 60,
        player: player,
        chamber: chamber,
        input: const DungeonPlayerInput(slashJustPressed: true),
        progress: fullProgress,
        physicsEngine: physics,
      );
      expect(chamber.roomGateUnlocked, isTrue);
      expect(chamber.isSolidAt(14, 8), isFalse);

      // Break secret wall '?' at col 17, row 8 (takes 2 hits)
      expect(chamber.isSolidAt(17, 8), isTrue);
      player.x = 16 * kDungeonTileSize;
      for (var h = 0; h < 2; h++) {
        combat.slashCooldownTimer = 0.0;
        combat.activeSlashes.clear();
        combat.step(
          dt: 1 / 60,
          player: player,
          chamber: chamber,
          input: const DungeonPlayerInput(slashJustPressed: true),
          progress: fullProgress,
          physicsEngine: physics,
        );
      }
      expect(chamber.isSolidAt(17, 8), isFalse);

      // 10. All 22 Procedural WAV SFX cues synthesize valid RIFF/WAVE PCM buffers
      expect(DungeonSfxCue.values.length, 22);
      for (final cue in DungeonSfxCue.values) {
        final wav = DungeonAudioService.synthesizeCueWav(cue);
        expect(wav.length, greaterThan(44));
        expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
        expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
      }
    },
  );

  testWidgets(
    'Dungeon Part 3/8: Pixel-Perfect Camera Rig, 16-Neighbor Rule-Tile Masking, Viewport Culling & Full DungeonWorldPainter Render',
    (WidgetTester tester) async {
      // 1. Build a large 60x34 cavern chamber to test viewport culling & camera look-ahead
      final bigRows = List<String>.generate(34, (r) {
        if (r == 0 || r == 33) return List.filled(60, '#').join();
        if (r == 32) return '#${List.filled(58, '=').join()}#';
        return '#${List.filled(58, '.').join()}#';
      });
      final bigSpec = DungeonChamberSpec(
        id: 'test_big_cavern',
        actNumber: 3,
        title: 'Malolos Cavern Test',
        subtitle: 'Viewport Culling & Camera Rig',
        asciiGrid: bigRows,
        defaultSpawnCol: 5,
        defaultSpawnRow: 30,
        isDarkCavern: true,
      );
      final player = DungeonPlayerPhysicsState(
        x: 5 * kDungeonTileSize,
        y: 30 * kDungeonTileSize,
        facing: 1,
        isGrounded: true,
        resolveHp: 8,
        maxResolveHp: 8,
      );

      final camera = DungeonCameraRig();
      camera.snapTo(player, bigSpec);
      // Camera is clamped cleanly within [0, worldWidth - kDungeonRefWidth]
      expect(camera.x, greaterThanOrEqualTo(0.0));
      expect(camera.x, lessThanOrEqualTo(bigSpec.worldWidth - kDungeonRefWidth));
      expect(camera.y, greaterThanOrEqualTo(0.0));
      expect(camera.y, lessThanOrEqualTo(bigSpec.worldHeight - kDungeonRefHeight));

      // Viewport tile culling on a 60x34 chamber only visits ~23x14 tiles, never all 60x34!
      final bounds = camera.visibleTileBounds(bigSpec.cols, bigSpec.rows);
      expect(bounds.maxCol - bounds.minCol, lessThan(26));
      expect(bounds.maxRow - bounds.minRow, lessThan(18));

      // Directional look-ahead shifts smoothly when sprinting right
      final startCamX = camera.x;
      player.x = 320.0;
      player.vx = 180.0;
      player.facing = 1;
      for (var i = 0; i < 30; i++) {
        camera.update(dt: 1 / 60, player: player, spec: bigSpec);
      }
      expect(camera.x, greaterThan(startCamX + 80.0));
      expect(camera.lookAheadX, greaterThan(20.0));

      // Screenshake impulse adds intensity and decays exponentially toward 0
      camera.addShake(6.0);
      expect(camera.shakeIntensity, 6.0);
      for (var i = 0; i < 60; i++) {
        camera.update(dt: 1 / 60, player: player, spec: bigSpec);
      }
      expect(camera.shakeIntensity, lessThan(0.5));

      // 2. 16-Neighbor Rule-Tile Auto-Tiling Mask Verification
      // Row 0: ########
      // Row 1: #......#
      // Row 2: #..#...#  <- isolated stone at (3,2) => mask 0
      // Row 3: #......#
      // Row 4: #..MM?.#  <- (3,4) has E+S => mask 2|4 = 6; (4,4) has E+S+W => mask 2|4|8 = 14; (5,4) secretWall connects W+S => mask 4|8 = 12
      // Row 5: #..###.#  <- (4,5) surrounded N+E+S+W => mask 15
      // Row 6: ########
      const maskSpec = DungeonChamberSpec(
        id: 'test_rule_tiles',
        actNumber: 1,
        title: 'Rule-Tile Mask Grid',
        subtitle: '16-Neighbor Bitmask Check',
        asciiGrid: <String>[
          '########',
          '#......#',
          '#..#...#',
          '#......#',
          '#..MM?.#',
          '#..###.#',
          '########',
        ],
        defaultSpawnCol: 1,
        defaultSpawnRow: 5,
      );
      final maskChamber = DungeonChamberRuntime(maskSpec);
      expect(computeSolidNeighborMask(maskChamber, 3, 2), 0); // isolated
      expect(computeSolidNeighborMask(maskChamber, 3, 4), 2 | 4); // E + S
      expect(computeSolidNeighborMask(maskChamber, 4, 4), 2 | 4 | 8); // top-exposed floor
      expect(computeSolidNeighborMask(maskChamber, 5, 4), 4 | 8); // secret wall connects W + S
      expect(computeSolidNeighborMask(maskChamber, 4, 5), 15); // fully interior

      // 3. Full DungeonWorldPainter Widget Render Pass with ALL 19 Tile Types,
      //    Active Slashes, Silk Skills, Projectiles, Loot, Enemies, Bosses, Particles & Floating Numbers
      const showcaseSpec = DungeonChamberSpec(
        id: 'test_render_all_19',
        actNumber: 2,
        title: 'All-19 Tile Showcase Chamber',
        subtitle: 'Render Smoke & Craft Floor Verification',
        asciiGrid: <String>[
          '########################',
          '#..T...O...G....T......#',
          '#..===...C....H........#',
          '#.............H..B..L..#',
          '#..X..*..S..D.?..K..P..#',
          '#MMMMMMMM^^^^MMMMMMMMMM#',
          '########################',
        ],
        defaultSpawnCol: 2,
        defaultSpawnRow: 4,
        isDarkCavern: true,
      );
      final showcaseChamber = DungeonChamberRuntime(showcaseSpec);
      showcaseChamber.lootDrops.addAll(<DungeonLootDrop>[
        DungeonLootDrop(
          id: 'l1',
          kind: DungeonLootKind.archipelagoShard,
          amount: 5,
          x: 64,
          y: 68,
          vx: 0,
          vy: 0,
        ),
        DungeonLootDrop(
          id: 'l2',
          kind: DungeonLootKind.resolveOrb,
          amount: 1,
          x: 78,
          y: 68,
          vx: 0,
          vy: 0,
        ),
        DungeonLootDrop(
          id: 'l3',
          kind: DungeonLootKind.silkMote,
          amount: 10,
          x: 92,
          y: 68,
          vx: 0,
          vy: 0,
        ),
        DungeonLootDrop(
          id: 'l4',
          kind: DungeonLootKind.relicFragment,
          amount: 1,
          x: 106,
          y: 68,
          vx: 0,
          vy: 0,
        ),
      ]);

      final hero = DungeonPlayerPhysicsState(
        x: 3 * kDungeonTileSize,
        y: 4 * kDungeonTileSize,
        facing: 1,
        isGrounded: true,
        resolveHp: 8,
        maxResolveHp: 8,
      );
      hero.grappleActive = true;
      hero.grappleTargetX = 184;
      hero.grappleTargetY = 24;
      hero.afterimages.add(
        DashAfterimage(x: hero.x - 10, y: hero.y, facing: 1, alpha: 0.55),
      );

      const progress = DungeonProgressSave(
        bladeTier: DungeonBladeTier.kampilanEdge,
        equippedCharmIds: <String>['tarsier_lantern', 'babaylan_bind'],
        openedChestIds: <String>{},
      );
      final combat = DungeonCombatEngine();
      combat.isChannelingBind = true;
      combat.bindElapsedSec = 0.25;
      combat.parryWindowTimer = 0.12;
      combat.activeSlashes.add(
        ActiveSlashArc(
          id: 1,
          direction: DungeonSlashDirection.right,
          comboStep: 2,
          damage: 25,
          totalDurationSec: 0.16,
          reachPx: 32.0,
          thicknessPx: 22.0,
          arcColor: progress.bladeTier.slashArcColor,
        ),
      );
      combat.activeSkills.addAll(<ActiveSkillEffect>[
        ActiveSkillEffect(
          id: 2,
          skillId: DungeonSilkSkillId.scalesTempest,
          x: hero.centerX,
          y: hero.centerY,
          facing: 1,
          damage: 30,
          radiusOrLength: 42.0,
          heightPx: 42.0,
          color: SpriteCastPalette.endesga32[18],
          durationSec: 0.30,
        ),
        ActiveSkillEffect(
          id: 3,
          skillId: DungeonSilkSkillId.sovereignSunburst,
          x: hero.centerX,
          y: hero.centerY,
          facing: 1,
          damage: 60,
          radiusOrLength: 180.0,
          heightPx: 22.0,
          color: SpriteCastPalette.endesga32[11],
          durationSec: 0.34,
        ),
      ]);
      combat.projectiles.add(
        DungeonProjectile(
          id: 'proj_test',
          isPlayerOwned: false,
          x: 196,
          y: 64,
          vx: -90,
          vy: 0,
          damage: 1,
          color: SpriteCastPalette.endesga32[26],
        ),
      );
      combat.floatingNumbers.add(
        FloatingCombatNumber(
          text: 'PARRY!',
          x: hero.centerX,
          y: hero.y - 12,
          color: SpriteCastPalette.endesga32[11],
          isCritical: true,
        ),
      );

      final renderCamera = DungeonCameraRig()..snapTo(hero, showcaseSpec);
      final testEntities = <DungeonEntityRenderSpec>[
        const DungeonEntityRenderSpec(
          id: 'en_guard',
          archetypeId: 'guardia_halberdier',
          hitbox: Rect.fromLTWH(150, 62, 16, 18),
          facing: -1,
          hp: 30,
          maxHp: 50,
          primaryColor: Color(0xFF3A4466),
          accentColor: Color(0xFFFEAE34),
          isShieldedFront: true,
          isTelegraphing: true,
          aimTelegraphEnd: Offset(60, 68),
        ),
        const DungeonEntityRenderSpec(
          id: 'boss_act2',
          archetypeId: 'warden_castellan',
          hitbox: Rect.fromLTWH(230, 52, 26, 28),
          facing: -1,
          hp: 180,
          maxHp: 300,
          primaryColor: Color(0xFFA22633),
          accentColor: Color(0xFFFEE761),
          isBoss: true,
          isStaggered: true,
        ),
      ];
      final testParticles = <DungeonParticle>[
        DungeonParticle(
          x: 90,
          y: 66,
          vx: 14,
          vy: -22,
          size: 2.5,
          color: SpriteCastPalette.endesga32[11],
        ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomPaint(
                size: const Size(640, 360),
                painter: DungeonWorldPainter(
                  chamber: showcaseChamber,
                  player: hero,
                  combat: combat,
                  progress: progress,
                  camera: renderCamera,
                  worldTimeSec: 1.75,
                  entities: testEntities,
                  particles: testParticles,
                  highlightedGrappleAnchor: const Offset(184, 24),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);

      // 4. Custom School Lobby Avatar Sprite Rendering in Dungeon (with Dungeon-Only Gear)
      // Verify frame selection across idle-right, walk-left, airborne, and ladder climb
      hero.isOnLadder = false;
      hero.isGrounded = true;
      hero.facing = 1;
      hero.vx = 0.0;
      expect(computeDungeonHeroAvatarFrameIndex(hero, 0.0), inInclusiveRange(0, 5));

      hero.facing = -1;
      hero.vx = -120.0;
      hero.runAnimTime = 2.0;
      expect(computeDungeonHeroAvatarFrameIndex(hero, 0.5), inInclusiveRange(36, 41));

      hero.isOnLadder = true;
      hero.vy = -50.0;
      expect(computeDungeonHeroAvatarFrameIndex(hero, 1.0), inInclusiveRange(30, 35));
      hero.isOnLadder = false;
      hero.facing = 1;

      // Render a real 48-frame (1536x64) custom avatar sprite strip through DungeonWorldPainter
      final recorder = ui.PictureRecorder();
      final recCanvas = Canvas(recorder);
      recCanvas.drawRect(
        const Rect.fromLTWH(0, 0, kCharFrameWidth * 48, kCharFrameHeight),
        Paint()..color = const Color(0xFF4280DD),
      );
      final picture = recorder.endRecording();
      final customSheet = await picture.toImage(
        (kCharFrameWidth * 48).toInt(),
        kCharFrameHeight.toInt(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: CustomPaint(
                size: const Size(640, 360),
                painter: DungeonWorldPainter(
                  chamber: showcaseChamber,
                  player: hero,
                  combat: combat,
                  progress: progress,
                  camera: renderCamera,
                  worldTimeSec: 2.0,
                  entities: testEntities,
                  particles: testParticles,
                  highlightedGrappleAnchor: const Offset(184, 24),
                  playerAvatarSheet: customSheet,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(tester.takeException(), isNull);
      customSheet.dispose();
    },
  );

  test(
    'Dungeon Part 4/8: 14 Enemy Archetypes, Shield/Laser AI, Rival Mateo & 7 Multi-Phase Era Bosses with Staggered Constitutional Counter-Breaks',
    () {
      // 1. Catalog Integrity: 14 regular archetypes + Rival Mateo (15 total) & 7 Multi-Phase Era Bosses (Acts 1..7)
      expect(kDungeonEnemyArchetypes.length, 15);
      expect(kDungeonBossArchetypes.length, 7);
      final bossActs = kDungeonBossArchetypes.values.map((b) => b.actNumber).toSet();
      expect(bossActs, equals(<int>{1, 2, 3, 4, 5, 6, 7}));
      for (final boss in kDungeonBossArchetypes.values) {
        expect(boss.isBoss, isTrue);
        expect(boss.phase1Attacks, isNotEmpty);
        expect(boss.phase2Attacks, isNotEmpty);
        expect(boss.counterBreak, isNotNull);
        expect(boss.counterBreak!.options.length, 2);
        expect(boss.counterBreak!.loreEntryId, isNotEmpty);
      }
      expect(kDungeonBossArchetypes['boss_sovereign_guardian']!.hasThreePhases, isTrue);
      expect(kDungeonBossArchetypes['boss_iron_censor']!.hasThreePhases, isTrue);

      // 2. Arena Setup for Enemy AI & Shield/Laser Verification
      const arenaSpec = DungeonChamberSpec(
        id: 'test_part4_arena',
        actNumber: 2,
        title: 'Intramuros Bastion Arena',
        subtitle: 'Part 4 Enemy AI Test',
        asciiGrid: <String>[
          '########################',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '########################',
        ],
        defaultSpawnCol: 2,
        defaultSpawnRow: 8,
        enemySpawns: <DungeonEnemySpawnSpec>[
          DungeonEnemySpawnSpec(
            spawnId: 'sp_lancer',
            archetypeId: 'guardia_lancer',
            col: 8,
            row: 8,
          ),
          DungeonEnemySpawnSpec(
            spawnId: 'sp_musketeer',
            archetypeId: 'intramuros_musketeer',
            col: 15,
            row: 8,
          ),
        ],
      );
      final chamber = DungeonChamberRuntime(arenaSpec);
      final combat = DungeonCombatEngine();
      final manager = DungeonEnemyManager();
      manager.spawnForChamber(arenaSpec, bossAlreadyDefeated: false);
      expect(manager.enemies.length, 2);
      expect(manager.buildRenderSpecs().length, 2);

      // 3. Shielded Lancer blocks frontal normal hit, takes full damage from behind, above (pogo), or Silk Skill
      final lancer = manager.enemies.firstWhere((e) => e.id == 'sp_lancer');
      lancer.facing = -1; // facing left toward player
      final blocked = lancer.receiveDamage(
        amount: 20,
        knockbackVx: 80,
        knockbackVy: -40,
        isSkillOrCrit: false,
        attackerCenterX: lancer.hitbox.center.dx - 24.0,
        attackerCenterY: lancer.hitbox.center.dy,
      );
      expect(blocked, 0);

      // Pogo strike from above bypasses front shield!
      final pogoHit = lancer.receiveDamage(
        amount: 20,
        knockbackVx: 0,
        knockbackVy: 0,
        isSkillOrCrit: false,
        attackerCenterX: lancer.hitbox.center.dx - 6.0,
        attackerCenterY: lancer.hitbox.top - 10.0,
      );
      expect(pogoHit, 20);

      // Dash-behind hit from the right bypasses front shield!
      final backstab = lancer.receiveDamage(
        amount: 15,
        knockbackVx: -60,
        knockbackVy: 0,
        isSkillOrCrit: false,
        attackerCenterX: lancer.hitbox.center.dx + 22.0,
        attackerCenterY: lancer.hitbox.center.dy,
      );
      expect(backstab, 15);

      // 4. Intramuros Musketeer projects aim telegraph laser during wind-up, then fires deflectable bolt
      final musketeer = manager.enemies.firstWhere((e) => e.id == 'sp_musketeer');
      musketeer.attackCooldown = 0.0;
      final player = DungeonPlayerPhysicsState(
        x: 11 * kDungeonTileSize,
        y: 8 * kDungeonTileSize,
        facing: 1,
        isGrounded: true,
        resolveHp: 6,
        maxResolveHp: 8,
        civicSilk: 30.0,
      );
      const progress = DungeonProgressSave();

      var sawAimLaser = false;
      for (var f = 0; f < 65; f++) {
        manager.step(
          dt: 1 / 60,
          player: player,
          chamber: chamber,
          combat: combat,
          progress: progress,
        );
        if (musketeer.aimTelegraphEnd != null) {
          sawAimLaser = true;
        }
      }
      expect(sawAimLaser, isTrue);
      expect(combat.projectiles, isNotEmpty);
      expect(combat.projectiles.first.isPlayerOwned, isFalse);
      expect(combat.projectiles.first.deflectable, isTrue);

      // 5. Rival Mateo Encounter spawns & scales HP properly in Act 5
      const rivalSpec = DungeonChamberSpec(
        id: 'test_rival_chamber',
        actNumber: 5,
        title: 'Corregidor Crossing',
        subtitle: 'Rival Mateo Duel',
        asciiGrid: <String>[
          '####################',
          '#..................#',
          '#..................#',
          '#..................#',
          '#..................#',
          '####################',
        ],
        defaultSpawnCol: 2,
        defaultSpawnRow: 4,
        enemySpawns: <DungeonEnemySpawnSpec>[
          DungeonEnemySpawnSpec(
            spawnId: 'mateo_act5',
            archetypeId: 'rival_mateo',
            col: 14,
            row: 4,
          ),
        ],
      );
      final rivalMgr = DungeonEnemyManager()
        ..spawnForChamber(rivalSpec, bossAlreadyDefeated: false);
      expect(rivalMgr.activeBoss, isNotNull);
      expect(rivalMgr.activeBoss!.archetype.isRival, isTrue);
      expect(
        rivalMgr.activeBoss!.maxHp,
        greaterThan(kDungeonEnemyArchetypes['rival_mateo']!.maxHp),
      );

      // 6. Act VII 3-Phase Sovereign Guardian Finale: Phase 1 -> 2 -> 3, Stagger, Counter-Break & Defeat Loot
      const finaleSpec = DungeonChamberSpec(
        id: 'test_act7_altar',
        actNumber: 7,
        title: 'Altar of the 1987 Charter',
        subtitle: '3-Phase Sovereign Finale',
        asciiGrid: <String>[
          '########################',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '#......................#',
          '########################',
        ],
        defaultSpawnCol: 3,
        defaultSpawnRow: 6,
        bossId: 'boss_sovereign_guardian',
        bossSpawnCol: 17,
        bossSpawnRow: 6,
        isBossArena: true,
      );
      final finaleChamber = DungeonChamberRuntime(finaleSpec);
      final finaleCombat = DungeonCombatEngine();
      final bossMgr = DungeonEnemyManager()
        ..spawnForChamber(finaleSpec, bossAlreadyDefeated: false);

      final guardian = bossMgr.activeBoss!;
      expect(guardian.phase, 1);

      // Drop HP below 62% -> triggers Phase 2!
      guardian.hp = (guardian.maxHp * 0.58).round();
      final phase2Evs = bossMgr.step(
        dt: 1 / 60,
        player: player,
        chamber: finaleChamber,
        combat: finaleCombat,
        progress: progress,
      );
      expect(guardian.phase, 2);
      expect(
        phase2Evs.any((e) => e.kind == DungeonEnemyEventKind.bossPhaseChanged),
        isTrue,
      );
      // Finish phaseShift roar timer
      for (var i = 0; i < 50; i++) {
        bossMgr.step(
          dt: 1 / 60,
          player: player,
          chamber: finaleChamber,
          combat: finaleCombat,
          progress: progress,
        );
      }

      // Fill posture via Parry shock -> triggers Boss Stagger & Constitutional Counter-Break Prompt!
      guardian.applyParryPostureShock(guardian.archetype.staggerThreshold);
      final staggerEvs = bossMgr.step(
        dt: 1 / 60,
        player: player,
        chamber: finaleChamber,
        combat: finaleCombat,
        progress: progress,
      );
      expect(guardian.isStaggered, isTrue);
      expect(
        staggerEvs.any((e) => e.kind == DungeonEnemyEventKind.bossStaggered),
        isTrue,
      );
      final prompt = bossMgr.activeCounterBreakPrompt;
      expect(prompt, isNotNull);
      expect(prompt!.loreEntryId, 'lore_act7_sovereignty_1987');

      // Tap the correct Constitutional Counter-Break option!
      player.resolveHp = 4;
      player.civicSilk = 10.0;
      final hpBeforeCounter = guardian.hp;
      final cbEvent = bossMgr.resolveCounterBreak(
        chosenOptionIndex: prompt.correctIndex,
        player: player,
        combat: finaleCombat,
        progress: progress,
      );
      expect(cbEvent, isNotNull);
      expect(cbEvent!.kind, DungeonEnemyEventKind.counterBreakSucceeded);
      expect(guardian.hp, lessThan(hpBeforeCounter - 100));
      expect(player.resolveHp, 6); // +2 Resolve Masks restored!
      expect(player.civicSilk, player.maxCivicSilk); // Silk fully refilled!
      expect(finaleCombat.hitStop.remainingSec, closeTo(0.110, 0.005));

      // Drop HP below 32% -> triggers Phase 3!
      guardian.hp = (guardian.maxHp * 0.25).round();
      final phase3Evs = bossMgr.step(
        dt: 1 / 60,
        player: player,
        chamber: finaleChamber,
        combat: finaleCombat,
        progress: progress,
      );
      expect(guardian.phase, 3);
      expect(
        phase3Evs.any((e) => e.kind == DungeonEnemyEventKind.bossPhaseChanged),
        isTrue,
      );

      // Defeat Guardian -> emits bossDefeated + drops Archipelago Shards, Silk Mote & Resolve Orb!
      guardian.hp = 0;
      final defeatEvs = bossMgr.step(
        dt: 1 / 60,
        player: player,
        chamber: finaleChamber,
        combat: finaleCombat,
        progress: progress,
      );
      expect(
        defeatEvs.any((e) => e.kind == DungeonEnemyEventKind.bossDefeated),
        isTrue,
      );
      expect(bossMgr.activeBoss, isNull);
      expect(finaleChamber.lootDrops.length, greaterThanOrEqualTo(10));
    },
  );
}

class _MockCombatTarget implements DungeonCombatTarget {
  @override
  final String id;
  @override
  final Rect hitbox;
  @override
  int hp;
  @override
  final int maxHp;
  @override
  final bool isBoss;
  @override
  final bool isShieldedFront;
  @override
  final int facing;

  _MockCombatTarget({
    required this.id,
    required this.hitbox,
    required this.hp,
    this.isBoss = false,
    this.isShieldedFront = false,
    this.facing = -1,
  }) : maxHp = hp;

  @override
  bool get isAlive => hp > 0;

  @override
  int receiveDamage({
    required int amount,
    required double knockbackVx,
    required double knockbackVy,
    required bool isSkillOrCrit,
    required double attackerCenterX,
    required double attackerCenterY,
  }) {
    if (isShieldedFront && !isSkillOrCrit) {
      final fromFront =
          (facing > 0 && attackerCenterX > hitbox.center.dx) ||
              (facing < 0 && attackerCenterX < hitbox.center.dx);
      if (fromFront) return 0;
    }
    hp = hp - amount < 0 ? 0 : hp - amount;
    return amount;
  }
}
