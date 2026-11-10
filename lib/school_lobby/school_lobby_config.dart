import 'package:flutter/material.dart';
import 'lobby_data_service.dart';

/// TinyFloor core tile & character frame constants recycled from:
/// - `_reference_tinyfloor/web-shared/src/lib/characterSheet.ts`
/// - `_reference_tinyfloor/app-frontend/src/lib/MovementManager.ts`
/// - `_reference_tinyfloor/app-frontend/src/lib/SeatManager.ts`
const double kTileSize = 32.0;

/// Expanded 4x Campus World (`48 x 34` tiles = `1536 x 1088` px).
const int kLobbyCols = 48;
const int kLobbyRows = 34;
const double kLobbyWorldWidth = kLobbyCols * kTileSize; // 1536 px
const double kLobbyWorldHeight = kLobbyRows * kTileSize; // 1088 px

const double kCharFrameWidth = 32.0;
const double kCharFrameHeight = 64.0;
const int kCharFramesPerDirection = 6;
const int kCharTotalFrames = 24;

const double kPlayerMoveSpeed = 205.0; // Smooth campus walking speed
const double kPlayerHalfWidth = 11.0;

/// Player default spawn point in the Grand Central Courtyard of the Main Lobby.
const Offset kPlayerSpawnPoint = Offset(768, 560);

/// Facing directions matching TinyFloor's `DIR_OFFSET` in `characterSheet.ts`:
/// `right: 0, up: 6, left: 12, down: 18`
enum AvatarFacing {
  right(0),
  up(6),
  left(12),
  down(18);

  final int frameOffset;
  const AvatarFacing(this.frameOffset);
}

/// The 5 explorable Campus Rooms connected via interactive Doors (`🚪`):
/// 1. Main School Lobby (`mainLobby`)
/// 2. Campus Park (`park`)
/// 3. Class Room (`classroom`)
/// 4. School Canteen (`canteen`)
/// 5. Faculty Room (`facultyRoom`)
enum LobbyRoomId {
  mainLobby,
  park,
  classroom,
  canteen,
  facultyRoom,
}

extension LobbyRoomIdExt on LobbyRoomId {
  String get title {
    switch (this) {
      case LobbyRoomId.mainLobby:
        return 'Main School Lobby';
      case LobbyRoomId.park:
        return 'Campus Nature Park';
      case LobbyRoomId.classroom:
        return 'SHS Class Room';
      case LobbyRoomId.canteen:
        return 'Student Canteen';
      case LobbyRoomId.facultyRoom:
        return 'Faculty Consultation Room';
    }
  }

  String get shortLabel {
    switch (this) {
      case LobbyRoomId.mainLobby:
        return 'Main Lobby';
      case LobbyRoomId.park:
        return 'Park';
      case LobbyRoomId.classroom:
        return 'Class Room';
      case LobbyRoomId.canteen:
        return 'Canteen';
      case LobbyRoomId.facultyRoom:
        return 'Faculty Room';
    }
  }

  String get iconEmoji {
    switch (this) {
      case LobbyRoomId.mainLobby:
        return '🏛️';
      case LobbyRoomId.park:
        return '🌳';
      case LobbyRoomId.classroom:
        return '🏫';
      case LobbyRoomId.canteen:
        return '🍱';
      case LobbyRoomId.facultyRoom:
        return '🎓';
    }
  }

  int get accentColor {
    switch (this) {
      case LobbyRoomId.mainLobby:
        return 0xFF38BDF8;
      case LobbyRoomId.park:
        return 0xFF10B981;
      case LobbyRoomId.classroom:
        return 0xFFF59E0B;
      case LobbyRoomId.canteen:
        return 0xFFF97316;
      case LobbyRoomId.facultyRoom:
        return 0xFFA855F7;
    }
  }

  Offset get defaultSpawn {
    switch (this) {
      case LobbyRoomId.mainLobby:
        return kPlayerSpawnPoint;
      case LobbyRoomId.park:
        return const Offset(768, 920);
      case LobbyRoomId.classroom:
        return const Offset(768, 920);
      case LobbyRoomId.canteen:
        return const Offset(768, 920);
      case LobbyRoomId.facultyRoom:
        return const Offset(768, 920);
    }
  }
}

/// Student Rest States recycled & expanded from TinyFloor `SeatManager.ts`:
/// Students can Sit (`🪑`), Nap (`😪`), or Sleep (`🛌 💤`) on chairs, benches, sofas, desks, or park lawns!
enum PlayerRestState {
  none,
  sitting,
  napping,
  sleeping;

  bool get isResting => this != PlayerRestState.none;

  String get label {
    switch (this) {
      case PlayerRestState.none:
        return 'Standing';
      case PlayerRestState.sitting:
        return 'Sitting';
      case PlayerRestState.napping:
        return 'Napping';
      case PlayerRestState.sleeping:
        return 'Sleeping';
    }
  }

  String get emoji {
    switch (this) {
      case PlayerRestState.none:
        return '🚶';
      case PlayerRestState.sitting:
        return '🪑';
      case PlayerRestState.napping:
        return '😪';
      case PlayerRestState.sleeping:
        return '🛌';
    }
  }
}

/// Computes the 0..23 horizontal frame index on a TinyFloor `768x64` character sheet.
int computeCharacterFrameIndex({
  required AvatarFacing facing,
  required bool isWalking,
  required int stepFrame,
}) {
  if (!isWalking) {
    return facing.frameOffset + (stepFrame % 2 == 0 ? 0 : 3);
  }
  return facing.frameOffset + (stepFrame % kCharFramesPerDirection);
}

enum InteractiveZoneKind {
  questCounter,
  subjectChest,
  smallMysteryChest,
  teacherCorner,
  bulletinBoard,
  studentLounge,
  reviewerTreasureArea,
  doorPortal,
  restSpot,
  peerStudent,
}

/// Interactive zone definition (recycled from TinyFloor's `ProximityManager.ts`).
class InteractiveZone {
  final String id;
  final String label;
  final String subtitle;
  final InteractiveZoneKind kind;
  final LobbyRoomId room;
  final double x;
  final double y;
  final double radius;
  final int accentColor;
  final String? subjectChestId;
  final LobbyRoomId? targetRoom;
  final Offset? targetSpawn;
  final String? restSpotId;
  final String? peerStudentId;

  const InteractiveZone({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.kind,
    this.room = LobbyRoomId.mainLobby,
    required this.x,
    required this.y,
    this.radius = 68.0,
    required this.accentColor,
    this.subjectChestId,
    this.targetRoom,
    this.targetSpawn,
    this.restSpotId,
    this.peerStudentId,
  });

  Offset get center => Offset(x, y);
}

/// Interactive Rest Spot (Chair, Sofa, Park Bench, Classroom Desk, Canteen Seat, Nap Couch)
/// where students can Sit (`🪑`), Nap (`😪`), or Sleep (`🛌`).
class LobbyRestSpot {
  final String id;
  final String label;
  final LobbyRoomId room;
  final double x;
  final double y;
  final AvatarFacing facing;
  final bool canSleepFlat;

  const LobbyRestSpot({
    required this.id,
    required this.label,
    required this.room,
    required this.x,
    required this.y,
    this.facing = AvatarFacing.down,
    this.canSleepFlat = true,
  });

  Offset get position => Offset(x, y);
}

/// Classmate / Peer Student NPC in a room whom the player can approach to chat via Thought Bubbles (`💭`).
class LobbyPeerStudent {
  final String id;
  final String name;
  final String roleTag;
  final String presetName;
  final LobbyRoomId room;
  final double x;
  final double y;
  final AvatarFacing facing;
  final PlayerRestState restState;
  final String defaultThought;
  final List<String> sampleReplies;

  const LobbyPeerStudent({
    required this.id,
    required this.name,
    this.roleTag = 'Student',
    required this.presetName,
    required this.room,
    required this.x,
    required this.y,
    this.facing = AvatarFacing.down,
    this.restState = PlayerRestState.none,
    required this.defaultThought,
    required this.sampleReplies,
  });

  Offset get position => Offset(x, y);
}

/// Core `INTERACTIVE_ZONES` config array in `mainLobby` + Campus Doors.
const List<InteractiveZone> INTERACTIVE_ZONES = [
  // ── 4 CAMPUS DOORS FROM MAIN LOBBY ──
  InteractiveZone(
    id: 'door_to_park',
    label: '🌳 Door to Campus Park',
    subtitle: 'Step outside to the Park benches, pond & picnic nap lawn',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.mainLobby,
    x: 68,
    y: 544,
    radius: 78,
    accentColor: 0xFF10B981,
    targetRoom: LobbyRoomId.park,
    targetSpawn: Offset(1380, 544),
  ),
  InteractiveZone(
    id: 'door_to_classroom',
    label: '🏫 Door to SHS Class Room',
    subtitle: 'Enter the Class Room with student desks, blackboards & seats',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.mainLobby,
    x: 520,
    y: 108,
    radius: 78,
    accentColor: 0xFFF59E0B,
    targetRoom: LobbyRoomId.classroom,
    targetSpawn: Offset(768, 920),
  ),
  InteractiveZone(
    id: 'door_to_canteen',
    label: '🍱 Door to Student Canteen',
    subtitle: 'Visit the Canteen dining tables, snacks counter & chill seats',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.mainLobby,
    x: 768,
    y: 1030,
    radius: 82,
    accentColor: 0xFFF97316,
    targetRoom: LobbyRoomId.canteen,
    targetSpawn: Offset(768, 160),
  ),
  InteractiveZone(
    id: 'door_to_faculty_room',
    label: '🎓 Door to Faculty Room',
    subtitle: 'Enter the Faculty Consultation Room & quiet lounge sofas',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.mainLobby,
    x: 1468,
    y: 340,
    radius: 78,
    accentColor: 0xFFA855F7,
    targetRoom: LobbyRoomId.facultyRoom,
    targetSpawn: Offset(150, 544),
  ),

  // ── 5 DISTINCT MAIN LOBBY ZONES ──
  // 1. School Bulletin Board Wall (Top-Left Wing)
  InteractiveZone(
    id: 'bulletin_board',
    label: '📌 School Bulletin Board Wall',
    subtitle: 'View school notices, academic calendar & honor roll tips',
    kind: InteractiveZoneKind.bulletinBoard,
    room: LobbyRoomId.mainLobby,
    x: 268,
    y: 175,
    radius: 95,
    accentColor: 0xFF38BDF8,
  ),
  // 2. Reception / Quest Counter (Top-Center Grand Hall)
  InteractiveZone(
    id: 'quest_counter',
    label: '⚔️ Reception & Quest Counter',
    subtitle: 'Talk to the Anime Receptionist • View enrolled quests & earn badges',
    kind: InteractiveZoneKind.questCounter,
    room: LobbyRoomId.mainLobby,
    x: 768,
    y: 215,
    radius: 105,
    accentColor: 0xFFF59E0B,
  ),
  // 3. Teacher's Corner (Top-Right Wing)
  InteractiveZone(
    id: 'teacher_corner',
    label: "🎓 Teacher's Corner",
    subtitle: 'Faculty advisory desk • Post activities, reviewers & quizzes',
    kind: InteractiveZoneKind.teacherCorner,
    room: LobbyRoomId.mainLobby,
    x: 1248,
    y: 210,
    radius: 100,
    accentColor: 0xFFFACC15,
  ),
  // 4. Student Lounge & Study Tables (Bottom-Left & Center Wing)
  InteractiveZone(
    id: 'student_lounge',
    label: '🛋️ Student Lounge & Study Tables',
    subtitle: 'Sit, nap, sleep on sofas or chat via Thought Bubbles',
    kind: InteractiveZoneKind.studentLounge,
    room: LobbyRoomId.mainLobby,
    x: 416,
    y: 672,
    radius: 95,
    accentColor: 0xFF10B981,
  ),
  // 5. Reviewer Treasure Corner (Expanded Bottom-Right Sanctuary)
  InteractiveZone(
    id: 'reviewer_treasure_area',
    label: '💎 Reviewer Treasure Corner',
    subtitle: 'Walk up to your enrolled Subject Chests to open Google Drive reviewers',
    kind: InteractiveZoneKind.reviewerTreasureArea,
    room: LobbyRoomId.mainLobby,
    x: 1168,
    y: 620,
    radius: 78,
    accentColor: 0xFFA855F7,
  ),

  // ── 8 SMALL MYSTERY CHESTS (MINI QUIZ CHESTS) ACROSS THE EXPANDED MAP ──
  InteractiveZone(
    id: 'small_chest_1',
    label: '✨ Mystery Quiz Chest #1',
    subtitle: 'Answer 1 enrolled-subject pop-quiz question for +25 XP!',
    kind: InteractiveZoneKind.smallMysteryChest,
    room: LobbyRoomId.mainLobby,
    x: 128,
    y: 352,
    radius: 64,
    accentColor: 0xFFEC4899,
  ),
  InteractiveZone(
    id: 'small_chest_2',
    label: '✨ Mystery Quiz Chest #2',
    subtitle: 'Answer 1 enrolled-subject pop-quiz question for +25 XP!',
    kind: InteractiveZoneKind.smallMysteryChest,
    room: LobbyRoomId.mainLobby,
    x: 688,
    y: 448,
    radius: 64,
    accentColor: 0xFFEC4899,
  ),
  InteractiveZone(
    id: 'small_chest_3',
    label: '✨ Mystery Quiz Chest #3',
    subtitle: 'Answer 1 enrolled-subject pop-quiz question for +25 XP!',
    kind: InteractiveZoneKind.smallMysteryChest,
    room: LobbyRoomId.mainLobby,
    x: 1408,
    y: 416,
    radius: 64,
    accentColor: 0xFFEC4899,
  ),
  InteractiveZone(
    id: 'small_chest_4',
    label: '✨ Mystery Quiz Chest #4',
    subtitle: 'Answer 1 enrolled-subject pop-quiz question for +25 XP!',
    kind: InteractiveZoneKind.smallMysteryChest,
    room: LobbyRoomId.mainLobby,
    x: 560,
    y: 944,
    radius: 64,
    accentColor: 0xFFEC4899,
  ),
  InteractiveZone(
    id: 'small_chest_5',
    label: '✨ Mystery Quiz Chest #5',
    subtitle: 'Answer 1 enrolled-subject pop-quiz question for +25 XP!',
    kind: InteractiveZoneKind.smallMysteryChest,
    room: LobbyRoomId.mainLobby,
    x: 144,
    y: 944,
    radius: 64,
    accentColor: 0xFFEC4899,
  ),
  InteractiveZone(
    id: 'small_chest_6',
    label: '✨ Mystery Quiz Chest #6',
    subtitle: 'Answer 1 enrolled-subject pop-quiz question for +25 XP!',
    kind: InteractiveZoneKind.smallMysteryChest,
    room: LobbyRoomId.mainLobby,
    x: 928,
    y: 368,
    radius: 64,
    accentColor: 0xFFEC4899,
  ),
  InteractiveZone(
    id: 'small_chest_7',
    label: '✨ Mystery Quiz Chest #7',
    subtitle: 'Answer 1 enrolled-subject pop-quiz question for +25 XP!',
    kind: InteractiveZoneKind.smallMysteryChest,
    room: LobbyRoomId.mainLobby,
    x: 848,
    y: 944,
    radius: 64,
    accentColor: 0xFFEC4899,
  ),
  InteractiveZone(
    id: 'small_chest_8',
    label: '✨ Mystery Quiz Chest #8',
    subtitle: 'Answer 1 enrolled-subject pop-quiz question for +25 XP!',
    kind: InteractiveZoneKind.smallMysteryChest,
    room: LobbyRoomId.mainLobby,
    x: 1424,
    y: 944,
    radius: 64,
    accentColor: 0xFFEC4899,
  ),
];

/// Return doors inside the 4 sub-rooms (`Park`, `Class Room`, `Canteen`, `Faculty Room`).
const List<InteractiveZone> kSubRoomDoorZones = [
  // Park -> Main Lobby (East Gate)
  InteractiveZone(
    id: 'park_door_to_lobby',
    label: '🏛️ Gate Back to Main School Lobby',
    subtitle: 'Return to the Main School Lobby courtyard',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.park,
    x: 1456,
    y: 544,
    radius: 84,
    accentColor: 0xFF38BDF8,
    targetRoom: LobbyRoomId.mainLobby,
    targetSpawn: Offset(140, 544),
  ),
  // Classroom -> Main Lobby (South Door)
  InteractiveZone(
    id: 'classroom_door_to_lobby',
    label: '🏛️ Door Back to Main School Lobby',
    subtitle: 'Step out of the Class Room into the Main Lobby',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.classroom,
    x: 768,
    y: 1024,
    radius: 84,
    accentColor: 0xFF38BDF8,
    targetRoom: LobbyRoomId.mainLobby,
    targetSpawn: Offset(520, 175),
  ),
  // Canteen -> Main Lobby (North Door)
  InteractiveZone(
    id: 'canteen_door_to_lobby',
    label: '🏛️ Door Back to Main School Lobby',
    subtitle: 'Return from the Canteen to the Main School Lobby',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.canteen,
    x: 768,
    y: 112,
    radius: 84,
    accentColor: 0xFF38BDF8,
    targetRoom: LobbyRoomId.mainLobby,
    targetSpawn: Offset(768, 955),
  ),
  // Faculty Room -> Main Lobby (West Door)
  InteractiveZone(
    id: 'faculty_door_to_lobby',
    label: '🏛️ Door Back to Main School Lobby',
    subtitle: 'Leave the Faculty Consultation Room back to the Main Lobby',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.facultyRoom,
    x: 80,
    y: 544,
    radius: 84,
    accentColor: 0xFF38BDF8,
    targetRoom: LobbyRoomId.mainLobby,
    targetSpawn: Offset(1390, 340),
  ),
];

/// Interactive Rest Spots across all 5 rooms so students can Sit (`🪑`), Nap (`😪`), or Sleep (`🛌`).
const List<LobbyRestSpot> kLobbyRestSpots = [
  // Main Lobby Sofas & Study Chairs
  LobbyRestSpot(
    id: 'rest_lobby_sofa_1',
    label: 'Lounge Nap Sofa (West)',
    room: LobbyRoomId.mainLobby,
    x: 204,
    y: 516,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_lobby_sofa_2',
    label: 'Lounge Study Sofa (East)',
    room: LobbyRoomId.mainLobby,
    x: 492,
    y: 516,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_lobby_chair_1',
    label: 'Study Commons Chair A',
    room: LobbyRoomId.mainLobby,
    x: 256,
    y: 668,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_lobby_chair_2',
    label: 'Study Commons Chair B',
    room: LobbyRoomId.mainLobby,
    x: 544,
    y: 668,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_lobby_sofa_south',
    label: 'Quiet Reading Daybed Sofa',
    room: LobbyRoomId.mainLobby,
    x: 348,
    y: 804,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),

  // Campus Park Benches & Picnic Nap Lawns
  LobbyRestSpot(
    id: 'rest_park_bench_1',
    label: 'Shaded Park Bench (North)',
    room: LobbyRoomId.park,
    x: 460,
    y: 310,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_park_bench_2',
    label: 'Pondside Park Bench (East)',
    room: LobbyRoomId.park,
    x: 1080,
    y: 310,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_park_picnic_1',
    label: 'Soft Grass Picnic Nap Blanket (West)',
    room: LobbyRoomId.park,
    x: 420,
    y: 720,
    facing: AvatarFacing.right,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_park_picnic_2',
    label: 'Starlight Tree Sleeping Lawn (East)',
    room: LobbyRoomId.park,
    x: 1100,
    y: 720,
    facing: AvatarFacing.left,
    canSleepFlat: true,
  ),

  // Class Room Desks & Back-Row Nap Corner
  LobbyRestSpot(
    id: 'rest_classroom_desk_1',
    label: 'Front Row Student Desk #1',
    room: LobbyRoomId.classroom,
    x: 440,
    y: 455,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_desk_2',
    label: 'Center Student Desk #2',
    room: LobbyRoomId.classroom,
    x: 768,
    y: 455,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_desk_3',
    label: 'East Row Student Desk #3',
    room: LobbyRoomId.classroom,
    x: 1096,
    y: 455,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_back_nap',
    label: 'Back-Row Student Nap Couch',
    room: LobbyRoomId.classroom,
    x: 1120,
    y: 775,
    facing: AvatarFacing.up,
    canSleepFlat: true,
  ),

  // Canteen Dining Booths & Lounge Couches
  LobbyRestSpot(
    id: 'rest_canteen_table_1',
    label: 'Canteen Dining Seat (West)',
    room: LobbyRoomId.canteen,
    x: 440,
    y: 540,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_canteen_table_2',
    label: 'Canteen Dining Seat (Center)',
    room: LobbyRoomId.canteen,
    x: 768,
    y: 540,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_canteen_booth_nap',
    label: 'Canteen Cozy Corner Sofa Booth',
    room: LobbyRoomId.canteen,
    x: 1160,
    y: 780,
    facing: AvatarFacing.left,
    canSleepFlat: true,
  ),

  // Faculty Room Consultation Chairs & Lounge Sofa
  LobbyRestSpot(
    id: 'rest_faculty_consult_1',
    label: 'Student Consultation Chair',
    room: LobbyRoomId.facultyRoom,
    x: 768,
    y: 520,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_faculty_lounge_sofa',
    label: 'Faculty Guest Rest Sofa',
    room: LobbyRoomId.facultyRoom,
    x: 1160,
    y: 720,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
];

/// Classmate Peer Students across all 5 rooms with Cloud Thought Bubbles (`💭`)
/// whom the player can approach and communicate with!
const List<LobbyPeerStudent> kLobbyPeerStudents = [
  // Main Lobby Peers
  LobbyPeerStudent(
    id: 'peer_main_alyssa',
    name: 'Alyssa (HUMSS 12)',
    presetName: 'character_09',
    room: LobbyRoomId.mainLobby,
    x: 340,
    y: 590,
    facing: AvatarFacing.right,
    restState: PlayerRestState.none,
    defaultThought: '💭 Reviewing PGP Week 6 slides before the quiz!',
    sampleReplies: [
      '💭 Let\'s review PGP & UCSP together! The HTML slides in the chest are super clear.',
      '💭 Have you unlocked the Policy Vanguard badge at the Quest Counter yet?',
      '💭 Good luck on our recitation today! Kaya natin \'to! ✨',
    ],
  ),
  LobbyPeerStudent(
    id: 'peer_main_marco',
    name: 'Marco (GAS 12)',
    presetName: 'character_04',
    room: LobbyRoomId.mainLobby,
    x: 492,
    y: 516,
    facing: AvatarFacing.down,
    restState: PlayerRestState.napping,
    defaultThought: '💭 Quick power nap on the sofa before next period... 😪',
    sampleReplies: [
      '💭 *yawns* Just taking a 5-minute nap before we head to the Class Room! 😪',
      '💭 Try sitting or napping on the sofa too! It\'s super relaxing.',
      '💭 Let\'s grab snacks at the Canteen door down south after studying!',
    ],
  ),

  // Park Peers
  LobbyPeerStudent(
    id: 'peer_park_bea',
    name: 'Bea (STEM 12)',
    presetName: 'character_14',
    room: LobbyRoomId.park,
    x: 560,
    y: 520,
    facing: AvatarFacing.down,
    restState: PlayerRestState.none,
    defaultThought: '💭 The breeze by the Campus Park pond is so peaceful 🌿',
    sampleReplies: [
      '💭 Hi classmate! The Campus Park is my favorite spot to unwind between classes.',
      '💭 You can lie down and sleep on the picnic blankets by the trees! 🛌',
      '💭 Fresh air really helps before opening the Reviewer Chests!',
    ],
  ),
  LobbyPeerStudent(
    id: 'peer_park_carlo',
    name: 'Carlo (HUMSS 12)',
    presetName: 'character_11',
    room: LobbyRoomId.park,
    x: 1100,
    y: 720,
    facing: AvatarFacing.left,
    restState: PlayerRestState.sleeping,
    defaultThought: '💭 Zzz... dreaming of 100% attendance & recitation... 💤',
    sampleReplies: [
      '💭 Zzz... Five more minutes on the park lawn please... 🛌💤',
      '💭 Woke up refreshed! Time to ace the Mystery Quiz Chests!',
    ],
  ),

  // Class Room Peers
  LobbyPeerStudent(
    id: 'peer_class_jamie',
    name: 'Jamie (ABM 12)',
    presetName: 'character_06',
    room: LobbyRoomId.classroom,
    x: 610,
    y: 455,
    facing: AvatarFacing.up,
    restState: PlayerRestState.sitting,
    defaultThought: '💭 Taking notes on the 1987 Constitution & UCSP kinship 📝',
    sampleReplies: [
      '💭 Take a seat at any desk! We\'re reviewing PKLP Term 2 & PGP.',
      '💭 Extracting the .TXT outline from the HTML reviewer makes note-taking so fast!',
      '💭 Which subject is your favorite this semester?',
    ],
  ),

  // Canteen Peers
  LobbyPeerStudent(
    id: 'peer_canteen_enz',
    name: 'Enzo (TVL 12)',
    presetName: 'character_08',
    room: LobbyRoomId.canteen,
    x: 610,
    y: 540,
    facing: AvatarFacing.down,
    restState: PlayerRestState.sitting,
    defaultThought: '💭 Nothing beats hot pancit canton & iced tea at break time! 🍱',
    sampleReplies: [
      '💭 Pull up a chair! Study group + merienda at the Canteen is the best combo!',
      '💭 Don\'t forget to check your enrolled Subject Chests back in the Main Lobby.',
    ],
  ),

  // Faculty Room Peer
  LobbyPeerStudent(
    id: 'peer_faculty_lara',
    name: 'Lara (Class Rep)',
    presetName: 'character_15',
    room: LobbyRoomId.facultyRoom,
    x: 560,
    y: 520,
    facing: AvatarFacing.right,
    restState: PlayerRestState.none,
    defaultThought: '💭 Consulting with faculty about our Term 2 project 📌',
    sampleReplies: [
      '💭 Sir Jim Mark uploaded all the active HTML reviewers to Google Drive!',
      '💭 Only active subjects from the MIS Control Sheet appear in our chests now.',
    ],
  ),
];

/// Anchor positions for Subject-Labeled Large Treasure Chests inside the
/// Expanded Reviewer Treasure Corner (`x: 920..1460, y: 490..950` in `mainLobby`).
const List<Offset> kSubjectChestAnchorPoints = [
  Offset(980, 660), // Chest 1 (e.g. PGP)
  Offset(1168, 660), // Chest 2 (e.g. UCSP)
  Offset(1356, 660), // Chest 3 (e.g. PPG)
  Offset(980, 820), // Chest 4 (e.g. PKLP TERM 2)
  Offset(1168, 820), // Chest 5 (e.g. PHILO)
  Offset(1356, 820), // Chest 6
  Offset(1074, 940), // Chest 7
  Offset(1262, 940), // Chest 8
];

Offset subjectChestPosition(int index) {
  if (index < kSubjectChestAnchorPoints.length) {
    return kSubjectChestAnchorPoints[index];
  }
  final col = index % 3;
  final row = index ~/ 3;
  return Offset(980.0 + col * 188.0, 660.0 + row * 150.0);
}

/// Static Furniture & Prop placement using TinyFloor's `floor-items.png` & `atlas.json`.
class LobbyFurniturePiece {
  final String spriteKey;
  final double x;
  final double y;
  final bool collidable;
  final bool isFloorRug;

  const LobbyFurniturePiece({
    required this.spriteKey,
    required this.x,
    required this.y,
    this.collidable = true,
    this.isFloorRug = false,
  });

  double get sortY => isFloorRug ? -1000 : y + 24;
}

/// Expanded `48 x 34` (`1536 x 1088` px) Main School Lobby Layout.
const List<LobbyFurniturePiece> kSchoolLobbyPieces = [
  // ── FLOOR RUGS (non-collidable, rendered beneath characters) ──
  LobbyFurniturePiece(
    spriteKey: 'rug_blue_left',
    x: 180,
    y: 620,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug_blue_right',
    x: 244,
    y: 620,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug_blue_left',
    x: 480,
    y: 620,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug_blue_right',
    x: 544,
    y: 620,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug_red_top',
    x: 748,
    y: 230,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug_red_bottom',
    x: 748,
    y: 262,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug_green',
    x: 1228,
    y: 235,
    collidable: false,
    isFloorRug: true,
  ),

  // ── 1. SCHOOL BULLETIN BOARD WALL (Top-Left Wing: x 64..480) ──
  LobbyFurniturePiece(
      spriteKey: 'wall_chart_bars', x: 96, y: 20, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_chart_lines', x: 192, y: 20, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_notice_board', x: 288, y: 22, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_Calendar', x: 384, y: 22, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_clock', x: 448, y: 24, collidable: false),
  LobbyFurniturePiece(spriteKey: 'bookshelf_wide', x: 96, y: 86),
  LobbyFurniturePiece(spriteKey: 'bookshelf_tall_1', x: 416, y: 82),
  LobbyFurniturePiece(spriteKey: 'plant_small', x: 64, y: 98),

  // ── 2. RECEPTION / QUEST COUNTER (Top-Center Hall: x 620..920) ──
  LobbyFurniturePiece(
      spriteKey: 'wall_notice_board', x: 704, y: 22, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_shelf', x: 800, y: 28, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_wood_2', x: 688, y: 156),
  LobbyFurniturePiece(spriteKey: 'desk_wood_2', x: 752, y: 156),
  LobbyFurniturePiece(spriteKey: 'desk_wood_2', x: 816, y: 156),
  LobbyFurniturePiece(
      spriteKey: 'monitor_front', x: 760, y: 146, collidable: false),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 640, y: 140),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 896, y: 140),

  // ── 3. TEACHER'S CORNER (Top-Right Wing: x 1060..1460) ──
  LobbyFurniturePiece(
      spriteKey: 'wall_art_1', x: 1120, y: 20, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_chart_bars', x: 1248, y: 20, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_shelf', x: 1360, y: 28, collidable: false),
  LobbyFurniturePiece(spriteKey: 'bookshelf_tall_1', x: 1088, y: 82),
  LobbyFurniturePiece(spriteKey: 'bookshelf_tall_2', x: 1124, y: 82),
  LobbyFurniturePiece(spriteKey: 'bookshelf_wide', x: 1344, y: 86),
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 1200, y: 162),
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 1264, y: 162),
  LobbyFurniturePiece(
      spriteKey: 'monitor_front', x: 1236, y: 150, collidable: false),
  LobbyFurniturePiece(spriteKey: 'water_cooler', x: 1424, y: 110),

  // ── 4. STUDENT LOUNGE & STUDY COMMONS (Bottom-Left & Center-West Wing) ──
  LobbyFurniturePiece(
      spriteKey: 'sofa_grey_down', x: 176, y: 496, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'sofa_grey_down', x: 464, y: 496, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_grey_1', x: 176, y: 600),
  LobbyFurniturePiece(spriteKey: 'desk_grey_2', x: 240, y: 600),
  LobbyFurniturePiece(spriteKey: 'desk_grey_1', x: 464, y: 600),
  LobbyFurniturePiece(spriteKey: 'desk_grey_2', x: 528, y: 600),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 192, y: 652, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 256, y: 652, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 480, y: 652, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 544, y: 652, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'sofa_blue_down', x: 320, y: 784, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 320, y: 848),
  LobbyFurniturePiece(spriteKey: 'vending_machine', x: 64, y: 740),
  LobbyFurniturePiece(spriteKey: 'arcade_machine_1', x: 64, y: 820),
  LobbyFurniturePiece(spriteKey: 'plant_small', x: 368, y: 590),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 640, y: 780),

  // ── 5. REVIEWER TREASURE CORNER SANCTUARY (Bottom-Right Wing: x 880..1460) ──
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 896, y: 490),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 1424, y: 490),
  LobbyFurniturePiece(spriteKey: 'bookshelf_wide', x: 1056, y: 488),
  LobbyFurniturePiece(spriteKey: 'bookshelf_wide', x: 1216, y: 488),
  LobbyFurniturePiece(spriteKey: 'plant_small', x: 896, y: 880),
  LobbyFurniturePiece(spriteKey: 'plant_small', x: 1424, y: 880),
];

/// Furniture layouts for the 4 additional Campus Rooms (`Park`, `Class Room`, `Canteen`, `Faculty Room`).
const List<LobbyFurniturePiece> kParkRoomPieces = [
  // Lush trees & plants around the Park perimeter and pond
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 160, y: 140),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 320, y: 140),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 1180, y: 140),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 1340, y: 140),
  // Park Benches (non-collidable so students can sit/nap/sleep on them)
  LobbyFurniturePiece(
      spriteKey: 'sofa_grey_down', x: 432, y: 290, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'sofa_grey_down', x: 1052, y: 290, collidable: false),
  // Picnic Nap Blankets (rugs)
  LobbyFurniturePiece(
    spriteKey: 'rug_green',
    x: 390,
    y: 700,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug_blue_left',
    x: 1068,
    y: 700,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug_blue_right',
    x: 1132,
    y: 700,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(spriteKey: 'plant_small', x: 240, y: 680),
  LobbyFurniturePiece(spriteKey: 'plant_small', x: 1280, y: 680),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 220, y: 880),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 1280, y: 880),
];

const List<LobbyFurniturePiece> kClassroomPieces = [
  // Wall Blackboards / Charts / Clock
  LobbyFurniturePiece(
      spriteKey: 'wall_chart_lines', x: 380, y: 20, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_notice_board', x: 740, y: 20, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_Calendar', x: 960, y: 22, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_clock', x: 1140, y: 24, collidable: false),
  // Teacher Podium Desk (Front Center)
  LobbyFurniturePiece(spriteKey: 'desk_wood_2', x: 704, y: 190),
  LobbyFurniturePiece(spriteKey: 'desk_wood_2', x: 768, y: 190),
  LobbyFurniturePiece(
      spriteKey: 'monitor_front', x: 756, y: 178, collidable: false),
  LobbyFurniturePiece(spriteKey: 'bookshelf_wide', x: 160, y: 92),
  LobbyFurniturePiece(spriteKey: 'bookshelf_wide', x: 1280, y: 92),
  // Row 1 Student Desks & Chairs
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 416, y: 390),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 432, y: 442, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 586, y: 390),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 602, y: 442, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 744, y: 390),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 760, y: 442, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 1072, y: 390),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 1088, y: 442, collidable: false),
  // Row 2 Student Desks & Chairs
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 416, y: 580),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 432, y: 632, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 744, y: 580),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 760, y: 632, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_wood_1', x: 1072, y: 580),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 1088, y: 632, collidable: false),
  // Back-Row Student Nap Couch
  LobbyFurniturePiece(
      spriteKey: 'sofa_blue_down', x: 1092, y: 755, collidable: false),
];

const List<LobbyFurniturePiece> kCanteenPieces = [
  // Canteen Counter & Vending Machines
  LobbyFurniturePiece(spriteKey: 'vending_machine', x: 180, y: 110),
  LobbyFurniturePiece(spriteKey: 'vending_machine', x: 250, y: 110),
  LobbyFurniturePiece(spriteKey: 'water_cooler', x: 330, y: 120),
  LobbyFurniturePiece(spriteKey: 'desk_grey_2', x: 1020, y: 180),
  LobbyFurniturePiece(spriteKey: 'desk_grey_2', x: 1084, y: 180),
  LobbyFurniturePiece(spriteKey: 'desk_grey_2', x: 1148, y: 180),
  // Dining Tables & Chairs
  LobbyFurniturePiece(spriteKey: 'desk_grey_1', x: 416, y: 475),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 432, y: 528, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_grey_1', x: 586, y: 475),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 602, y: 528, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desk_grey_1', x: 744, y: 475),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 760, y: 528, collidable: false),
  // Cozy Canteen Booth Sofa
  LobbyFurniturePiece(
      spriteKey: 'sofa_grey_down', x: 1132, y: 760, collidable: false),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 140, y: 840),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 1360, y: 840),
];

const List<LobbyFurniturePiece> kFacultyRoomPieces = [
  LobbyFurniturePiece(
      spriteKey: 'wall_art_1', x: 520, y: 20, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_chart_bars', x: 760, y: 20, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall_notice_board', x: 980, y: 22, collidable: false),
  LobbyFurniturePiece(spriteKey: 'bookshelf_tall_1', x: 220, y: 84),
  LobbyFurniturePiece(spriteKey: 'bookshelf_tall_2', x: 260, y: 84),
  LobbyFurniturePiece(spriteKey: 'bookshelf_wide', x: 1180, y: 86),
  // Faculty Consultation Table
  LobbyFurniturePiece(spriteKey: 'desk_wood_2', x: 680, y: 390),
  LobbyFurniturePiece(spriteKey: 'desk_wood_2', x: 744, y: 390),
  LobbyFurniturePiece(spriteKey: 'desk_wood_2', x: 808, y: 390),
  LobbyFurniturePiece(
      spriteKey: 'chair_blue_up', x: 760, y: 505, collidable: false),
  // Faculty Lounge Rest Sofa
  LobbyFurniturePiece(
      spriteKey: 'sofa_blue_down', x: 1132, y: 700, collidable: false),
  LobbyFurniturePiece(spriteKey: 'water_cooler', x: 1360, y: 120),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 420, y: 140),
  LobbyFurniturePiece(spriteKey: 'plant_tall', x: 1080, y: 140),
];

/// Non-player characters rendered in the School Campus.
class LobbyNpc {
  final String id;
  final String name;
  final String roleTag;
  final bool isGoldTag;
  final String presetName;
  final LobbyRoomId room;
  final double x;
  final double y;
  final AvatarFacing facing;

  const LobbyNpc({
    required this.id,
    required this.name,
    required this.roleTag,
    required this.isGoldTag,
    required this.presetName,
    this.room = LobbyRoomId.mainLobby,
    required this.x,
    required this.y,
    this.facing = AvatarFacing.down,
  });
}

const List<LobbyNpc> kLobbyNpcs = [
  LobbyNpc(
    id: 'npc_receptionist',
    name: 'Aiko (Quest Guide)',
    roleTag: 'Reception',
    isGoldTag: true,
    presetName: 'character_02',
    room: LobbyRoomId.mainLobby,
    x: 768,
    y: 142,
    facing: AvatarFacing.down,
  ),
  LobbyNpc(
    id: 'npc_teacher',
    name: 'Sir Jim Mark',
    roleTag: 'Teacher',
    isGoldTag: true,
    presetName: 'character_05',
    room: LobbyRoomId.mainLobby,
    x: 1248,
    y: 142,
    facing: AvatarFacing.down,
  ),
  LobbyNpc(
    id: 'npc_librarian',
    name: 'Kuya Ben (Vault Keeper)',
    roleTag: 'Archivist',
    isGoldTag: false,
    presetName: 'character_12',
    room: LobbyRoomId.mainLobby,
    x: 1168,
    y: 545,
    facing: AvatarFacing.down,
  ),
  LobbyNpc(
    id: 'npc_canteen_chef',
    name: 'Ate Lorna (Canteen)',
    roleTag: 'Staff',
    isGoldTag: true,
    presetName: 'character_03',
    room: LobbyRoomId.canteen,
    x: 1100,
    y: 160,
    facing: AvatarFacing.down,
  ),
  LobbyNpc(
    id: 'npc_faculty_adviser',
    name: 'Ma\'am Reyes (Adviser)',
    roleTag: 'Teacher',
    isGoldTag: true,
    presetName: 'character_07',
    room: LobbyRoomId.facultyRoom,
    x: 768,
    y: 350,
    facing: AvatarFacing.down,
  ),
];

List<LobbyFurniturePiece> furnitureForRoom(LobbyRoomId room) {
  switch (room) {
    case LobbyRoomId.mainLobby:
      return kSchoolLobbyPieces;
    case LobbyRoomId.park:
      return kParkRoomPieces;
    case LobbyRoomId.classroom:
      return kClassroomPieces;
    case LobbyRoomId.canteen:
      return kCanteenPieces;
    case LobbyRoomId.facultyRoom:
      return kFacultyRoomPieces;
  }
}

List<LobbyNpc> npcsForRoom(LobbyRoomId room) {
  return kLobbyNpcs.where((n) => n.room == room).toList();
}

List<LobbyPeerStudent> peersForRoom(LobbyRoomId room) {
  return kLobbyPeerStudents.where((p) => p.room == room).toList();
}

List<LobbyRestSpot> restSpotsForRoom(LobbyRoomId room) {
  return kLobbyRestSpots.where((r) => r.room == room).toList();
}

/// Builds solid collision rectangles (`Rect`) for wall boundaries, furniture counters,
/// and dynamic Subject Chests in the given [room].
List<Rect> buildLobbySolids(
  List<SubjectChest> subjectChests, {
  LobbyRoomId room = LobbyRoomId.mainLobby,
}) {
  final solids = <Rect>[
    // Outer perimeter walls (expanded 1536 x 1088)
    const Rect.fromLTWH(0, 0, kLobbyWorldWidth, 82), // Top wall
    const Rect.fromLTWH(0, kLobbyWorldHeight - 24, kLobbyWorldWidth, 24), // Bottom wall
    const Rect.fromLTWH(0, 0, 32, kLobbyWorldHeight), // Left wall
    const Rect.fromLTWH(kLobbyWorldWidth - 32, 0, 32, kLobbyWorldHeight), // Right wall
  ];

  switch (room) {
    case LobbyRoomId.mainLobby:
      solids.addAll(const [
        // Reception Counter collider
        Rect.fromLTWH(684, 152, 184, 34),
        // Teacher's Corner Desk collider
        Rect.fromLTWH(1196, 158, 128, 34),
        // Bookshelves along top walls
        Rect.fromLTWH(92, 82, 60, 34),
        Rect.fromLTWH(412, 82, 32, 36),
        Rect.fromLTWH(1084, 82, 68, 36),
        Rect.fromLTWH(1340, 82, 60, 34),
        // Student Lounge study tables (chairs & sofas remain walkable for sitting/napping/sleeping!)
        Rect.fromLTWH(174, 598, 118, 28),
        Rect.fromLTWH(462, 598, 118, 28),
        Rect.fromLTWH(318, 846, 56, 26),
        // Arcade & Vending machines
        Rect.fromLTWH(60, 736, 40, 128),
        // Reviewer Sanctuary top bookshelves
        Rect.fromLTWH(1052, 488, 60, 32),
        Rect.fromLTWH(1212, 488, 60, 32),
      ]);
      for (var i = 0; i < subjectChests.length; i++) {
        final pos = subjectChestPosition(i);
        solids.add(
          Rect.fromCenter(
            center: pos,
            width: 34,
            height: 24,
          ),
        );
      }
      break;

    case LobbyRoomId.park:
      // Central Park Pond water collider
      solids.add(const Rect.fromLTWH(640, 420, 256, 180));
      break;

    case LobbyRoomId.classroom:
      solids.addAll(const [
        // Teacher podium desk
        Rect.fromLTWH(700, 188, 132, 32),
        // Student desk tables (chairs just below them are walkable so students can sit/nap!)
        Rect.fromLTWH(412, 386, 56, 26),
        Rect.fromLTWH(582, 386, 56, 26),
        Rect.fromLTWH(740, 386, 56, 26),
        Rect.fromLTWH(1068, 386, 56, 26),
        Rect.fromLTWH(412, 576, 56, 26),
        Rect.fromLTWH(740, 576, 56, 26),
        Rect.fromLTWH(1068, 576, 56, 26),
      ]);
      break;

    case LobbyRoomId.canteen:
      solids.addAll(const [
        // Food counter & vending machines
        Rect.fromLTWH(176, 106, 180, 42),
        Rect.fromLTWH(1016, 176, 196, 36),
        // Dining tables
        Rect.fromLTWH(412, 472, 56, 26),
        Rect.fromLTWH(582, 472, 56, 26),
        Rect.fromLTWH(740, 472, 56, 26),
      ]);
      break;

    case LobbyRoomId.facultyRoom:
      solids.addAll(const [
        // Faculty consultation table
        Rect.fromLTWH(676, 386, 196, 36),
      ]);
      break;
  }

  return solids;
}

/// Builds the full list of active `InteractiveZone`s in [room], combining:
/// - Static room zones & doors
/// - Enrolled active `SubjectChest`s (in `mainLobby`)
/// - Rest spots (`🪑 Sit / 😪 Nap / 🛌 Sleep`) in [room]
/// - Classmate Peer Students (`💭 Thought Bubble Chat`) in [room]
List<InteractiveZone> buildActiveInteractiveZones(
  List<SubjectChest> subjectChests, {
  LobbyRoomId room = LobbyRoomId.mainLobby,
}) {
  final zones = <InteractiveZone>[];

  if (room == LobbyRoomId.mainLobby) {
    zones.addAll(INTERACTIVE_ZONES.where((z) => z.room == LobbyRoomId.mainLobby));
    for (var i = 0; i < subjectChests.length; i++) {
      final chest = subjectChests[i];
      final pos = subjectChestPosition(i);
      zones.add(
        InteractiveZone(
          id: 'subject_chest_${chest.id}',
          label: '📦 ${chest.subjectName} Reviewer Chest',
          subtitle:
              '${chest.reviewers.length} Reviewer(s) ready • Tap Interact to open',
          kind: InteractiveZoneKind.subjectChest,
          room: LobbyRoomId.mainLobby,
          x: pos.dx,
          y: pos.dy,
          radius: 72.0,
          accentColor: chest.colorValue,
          subjectChestId: chest.id,
        ),
      );
    }
  } else {
    zones.addAll(kSubRoomDoorZones.where((z) => z.room == room));
  }

  // Add Rest Spots for this room (Sit, Nap, or Sleep)
  for (final spot in restSpotsForRoom(room)) {
    zones.add(
      InteractiveZone(
        id: 'rest_zone_${spot.id}',
        label: '🪑 ${spot.label}',
        subtitle: spot.canSleepFlat
            ? 'Tap Interact to Sit 🪑, Nap 😪, or Sleep 🛌'
            : 'Tap Interact to Sit 🪑 or Nap 😪 at this seat',
        kind: InteractiveZoneKind.restSpot,
        room: room,
        x: spot.x,
        y: spot.y,
        radius: 62.0,
        accentColor: 0xFF10B981,
        restSpotId: spot.id,
      ),
    );
  }

  // Add Classmate Peer Students for Thought Bubble chatting in this room
  for (final peer in peersForRoom(room)) {
    zones.add(
      InteractiveZone(
        id: 'peer_zone_${peer.id}',
        label: '💭 Chat with ${peer.name}',
        subtitle: peer.defaultThought,
        kind: InteractiveZoneKind.peerStudent,
        room: room,
        x: peer.x,
        y: peer.y,
        radius: 68.0,
        accentColor: 0xFF38BDF8,
        peerStudentId: peer.id,
      ),
    );
  }

  return zones;
}
