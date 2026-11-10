import 'package:flutter/material.dart';
import 'lobby_data_service.dart';
import 'school_lobby_avatar.dart';

/// TinyFloor core tile & character frame constants recycled from:
/// - `_reference_tinyfloor/web-shared/src/lib/characterSheet.ts`
/// - `_reference_tinyfloor/app-frontend/src/lib/MovementManager.ts`
/// - `_reference_tinyfloor/app-frontend/src/lib/SeatManager.ts`
/// - `_reference_tinyfloor/shared-protocol/src/shell.ts`
const double kTileSize = 32.0;

/// Expanded 4x Campus World (`48 x 34` tiles = `1536 x 1088` px).
const int kLobbyCols = 48;
const int kLobbyRows = 34;
const double kLobbyWorldWidth = kLobbyCols * kTileSize; // 1536 px
const double kLobbyWorldHeight = kLobbyRows * kTileSize; // 1088 px

const double kPlayerMoveSpeed = 215.0; // Crisp campus walking speed
const double kPlayerHalfWidth = 11.0;

/// Player default spawn point in the Grand Central Crossroads Hub of the Main Lobby.
const Offset kPlayerSpawnPoint = Offset(768, 560);

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

  /// Spawn coordinate placed directly on each room's main entrance walk path.
  Offset get defaultSpawn {
    switch (this) {
      case LobbyRoomId.mainLobby:
        return kPlayerSpawnPoint;
      case LobbyRoomId.park:
        return const Offset(1360, 544);
      case LobbyRoomId.classroom:
        return const Offset(768, 920);
      case LobbyRoomId.canteen:
        return const Offset(768, 200);
      case LobbyRoomId.facultyRoom:
        return const Offset(180, 544);
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
  vendingMachine,
  classroomPodium,
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

/// Guided Walk Path segment rendered on the floor (`floor-sheet.png` tiles + border trim + directional chevrons)
/// so students are clearly guided to every door, chest, desk, and counter instead of wandering aimlessly.
class LobbyWalkPathSegment {
  final Rect rect;
  final String style; // 'paving' | 'carpet_gold' | 'carpet_blue' | 'carpet_royal' | 'wood_aisle' | 'checker'
  final int borderColor;
  final String? arrowDir; // 'up' | 'down' | 'left' | 'right'

  const LobbyWalkPathSegment({
    required this.rect,
    this.style = 'paving',
    this.borderColor = 0xFF38BDF8,
    this.arrowDir,
  });
}

/// Painted floor directional signpost placed along walk paths & crossroads.
class LobbyFloorSignpost {
  final Offset center;
  final String text;
  final int colorValue;

  const LobbyFloorSignpost({
    required this.center,
    required this.text,
    required this.colorValue,
  });
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

/// Classmate / Peer Student in a room whom the player can approach to chat via Thought Bubbles (`💭`).
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

/// Guided Walk Paths per Room (`walkPathsForRoom`).
const List<LobbyWalkPathSegment> _kMainLobbyWalkPaths = [
  // Central Crossroads Plaza at Spawn (768, 560)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(688, 488, 160, 144),
    style: 'carpet_gold',
    borderColor: 0xFFF59E0B,
  ),
  // North Royal Runner -> Quest Counter & Lobbyist Aiko (768, 215)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(728, 210, 80, 282),
    style: 'carpet_gold',
    borderColor: 0xFFF59E0B,
    arrowDir: 'up',
  ),
  // Upper West Academic Corridor -> Class Room Door (520, 108) & Bulletin Board (268, 175)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(240, 144, 492, 64),
    style: 'paving',
    borderColor: 0xFFF59E0B,
    arrowDir: 'left',
  ),
  // Upper East Faculty Corridor -> Teacher's Corner (1248, 210) & Faculty Door (1468, 340)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(804, 176, 484, 64),
    style: 'carpet_royal',
    borderColor: 0xFFA855F7,
    arrowDir: 'right',
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(1224, 236, 240, 136),
    style: 'carpet_royal',
    borderColor: 0xFFA855F7,
    arrowDir: 'right',
  ),
  // West Garden Walk Path -> Campus Park Door (68, 544) & Student Lounge
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(68, 512, 624, 68),
    style: 'paving',
    borderColor: 0xFF10B981,
    arrowDir: 'left',
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(384, 576, 64, 160),
    style: 'carpet_blue',
    borderColor: 0xFF38BDF8,
    arrowDir: 'down',
  ),
  // East Vault Walk Path -> Enrolled Subject Reviewer Chests (920..1420, 620..940)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(844, 512, 360, 68),
    style: 'carpet_royal',
    borderColor: 0xFFA855F7,
    arrowDir: 'right',
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(1136, 576, 68, 360),
    style: 'carpet_royal',
    borderColor: 0xFFA855F7,
    arrowDir: 'down',
  ),
  // South Promenade -> Student Canteen Door (768, 1030)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(728, 628, 80, 402),
    style: 'paving',
    borderColor: 0xFFF97316,
    arrowDir: 'down',
  ),
];

const List<LobbyWalkPathSegment> _kParkWalkPaths = [
  // East-West Main Cobblestone Nature Trail from Lobby Gate (1456, 544)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(896, 508, 560, 72),
    style: 'paving',
    borderColor: 0xFF10B981,
    arrowDir: 'left',
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(160, 508, 480, 72),
    style: 'paving',
    borderColor: 0xFF10B981,
    arrowDir: 'left',
  ),
  // Pond Promenade Loop around the Central Koi Pond (640..896, 420..600)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(584, 356, 368, 60),
    style: 'paving',
    borderColor: 0xFF0EA5E9,
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(584, 604, 368, 60),
    style: 'paving',
    borderColor: 0xFF0EA5E9,
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(584, 412, 56, 196),
    style: 'paving',
    borderColor: 0xFF0EA5E9,
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(896, 412, 56, 196),
    style: 'paving',
    borderColor: 0xFF0EA5E9,
  ),
  // North Bench Grove Trail & South Picnic Lawn Trails
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(732, 220, 72, 140),
    style: 'paving',
    borderColor: 0xFF10B981,
    arrowDir: 'up',
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(388, 576, 64, 160),
    style: 'paving',
    borderColor: 0xFF10B981,
    arrowDir: 'down',
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(1068, 576, 64, 160),
    style: 'paving',
    borderColor: 0xFF10B981,
    arrowDir: 'down',
  ),
];

const List<LobbyWalkPathSegment> _kClassroomWalkPaths = [
  // Central Classroom Aisle from South Door (768, 1024) straight up to Teacher Podium (768, 245)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(728, 248, 80, 776),
    style: 'carpet_gold',
    borderColor: 0xFFF59E0B,
    arrowDir: 'up',
  ),
  // Row 1 Desk Aisle (y: 416..464)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(240, 418, 1056, 48),
    style: 'wood_aisle',
    borderColor: 0xFF38BDF8,
  ),
  // Row 2 Desk Aisle (y: 596..644)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(240, 598, 1056, 48),
    style: 'wood_aisle',
    borderColor: 0xFF38BDF8,
  ),
  // Row 3 Desk & Back Study Lounge Aisle (y: 776..824)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(240, 778, 1056, 48),
    style: 'wood_aisle',
    borderColor: 0xFF38BDF8,
  ),
];

const List<LobbyWalkPathSegment> _kCanteenWalkPaths = [
  // Central Canteen Promenade from North Door (768, 112)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(728, 112, 80, 820),
    style: 'checker',
    borderColor: 0xFFF97316,
    arrowDir: 'down',
  ),
  // North Vending Machine & Coffee Counter Service Lane
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(176, 204, 556, 60),
    style: 'checker',
    borderColor: 0xFF0EA5E9,
    arrowDir: 'left',
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(804, 204, 540, 60),
    style: 'checker',
    borderColor: 0xFFF97316,
    arrowDir: 'right',
  ),
  // Dining Table Row Aisles
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(220, 488, 1096, 52),
    style: 'checker',
    borderColor: 0xFFF59E0B,
  ),
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(220, 738, 1096, 52),
    style: 'checker',
    borderColor: 0xFFF59E0B,
  ),
];

const List<LobbyWalkPathSegment> _kFacultyWalkPaths = [
  // West-to-East Royal Carpet Runner from West Lobby Door (80, 544)
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(80, 508, 1280, 72),
    style: 'carpet_royal',
    borderColor: 0xFFA855F7,
    arrowDir: 'right',
  ),
  // Central Adviser Consultation Aisle
  LobbyWalkPathSegment(
    rect: Rect.fromLTWH(728, 220, 80, 640),
    style: 'carpet_gold',
    borderColor: 0xFFF59E0B,
    arrowDir: 'up',
  ),
];

List<LobbyWalkPathSegment> walkPathsForRoom(LobbyRoomId room) {
  switch (room) {
    case LobbyRoomId.mainLobby:
      return _kMainLobbyWalkPaths;
    case LobbyRoomId.park:
      return _kParkWalkPaths;
    case LobbyRoomId.classroom:
      return _kClassroomWalkPaths;
    case LobbyRoomId.canteen:
      return _kCanteenWalkPaths;
    case LobbyRoomId.facultyRoom:
      return _kFacultyWalkPaths;
  }
}

/// Painted directional signposts placed right around spawn & intersections so students
/// immediately see where every walk path leads on mobile screens!
List<LobbyFloorSignpost> floorSignpostsForRoom(LobbyRoomId room) {
  switch (room) {
    case LobbyRoomId.mainLobby:
      return const [
        // Immediately visible around Central Spawn (768, 560)
        LobbyFloorSignpost(
          center: Offset(768, 462),
          text: '⬆️ QUEST COUNTER • ↖️ CLASS ROOM 🏫',
          colorValue: 0xFFD97706,
        ),
        LobbyFloorSignpost(
          center: Offset(585, 546),
          text: '⬅️ PARK DOOR 🌳 & LOUNGE',
          colorValue: 0xFF059669,
        ),
        LobbyFloorSignpost(
          center: Offset(955, 546),
          text: '➡️ SUBJECT CHESTS 📦 & FACULTY 🎓',
          colorValue: 0xFF7C3AED,
        ),
        LobbyFloorSignpost(
          center: Offset(768, 650),
          text: '⬇️ CANTEEN DOOR 🍱',
          colorValue: 0xFFEA580C,
        ),
        // Destination plaques
        LobbyFloorSignpost(
          center: Offset(768, 256),
          text: '⚔️ QUEST COUNTER (AIKO)',
          colorValue: 0xFFD97706,
        ),
        LobbyFloorSignpost(
          center: Offset(268, 232),
          text: '📌 BULLETIN WALL',
          colorValue: 0xFF0284C7,
        ),
        LobbyFloorSignpost(
          center: Offset(1248, 256),
          text: "🎓 TEACHER'S CORNER",
          colorValue: 0xFFB45309,
        ),
        LobbyFloorSignpost(
          center: Offset(1168, 595),
          text: '💎 ENROLLED SUBJECT CHEST VAULT',
          colorValue: 0xFF9333EA,
        ),
      ];
    case LobbyRoomId.park:
      return const [
        LobbyFloorSignpost(
          center: Offset(1195, 544),
          text: '⬅️ POND LOOP, TREES & PICNIC LAWNS 🌳',
          colorValue: 0xFF059669,
        ),
        LobbyFloorSignpost(
          center: Offset(768, 385),
          text: '🌊 CENTRAL PARK KOI POND & SHADED BENCHES',
          colorValue: 0xFF0284C7,
        ),
        LobbyFloorSignpost(
          center: Offset(420, 668),
          text: '🛌 WEST PICNIC NAP & SLEEPING LAWN',
          colorValue: 0xFF0D9488,
        ),
        LobbyFloorSignpost(
          center: Offset(1100, 668),
          text: '🌸 EAST FLOWER GROVE & SLEEPING LAWN',
          colorValue: 0xFF059669,
        ),
      ];
    case LobbyRoomId.classroom:
      return const [
        LobbyFloorSignpost(
          center: Offset(768, 855),
          text: '⬆️ TEACHER PODIUM 🎙️ & 12 STUDENT DESKS 🪑',
          colorValue: 0xFFD97706,
        ),
        LobbyFloorSignpost(
          center: Offset(768, 268),
          text: '🎙️ TEACHER PODIUM & LECTURE STAGE',
          colorValue: 0xFFB45309,
        ),
        LobbyFloorSignpost(
          center: Offset(490, 442),
          text: '🪑 ROW 1 DESKS (SIT / NAP)',
          colorValue: 0xFF0284C7,
        ),
        LobbyFloorSignpost(
          center: Offset(490, 622),
          text: '🪑 ROW 2 DESKS (SIT / NAP)',
          colorValue: 0xFF0284C7,
        ),
      ];
    case LobbyRoomId.canteen:
      return const [
        LobbyFloorSignpost(
          center: Offset(545, 234),
          text: '⬅️ DRINK & SNACK VENDING MACHINES 🥤',
          colorValue: 0xFF0284C7,
        ),
        LobbyFloorSignpost(
          center: Offset(995, 234),
          text: '➡️ COFFEE & MERIENDA COUNTER 🍱',
          colorValue: 0xFFEA580C,
        ),
        LobbyFloorSignpost(
          center: Offset(768, 355),
          text: '⬇️ 6 DINING TABLES & CORNER NAP BOOTH 🪑',
          colorValue: 0xFFD97706,
        ),
      ];
    case LobbyRoomId.facultyRoom:
      return const [
        LobbyFloorSignpost(
          center: Offset(390, 544),
          text: '➡️ FACULTY ADVISER DESKS 🎓 & LOUNGE 🛋️',
          colorValue: 0xFF7C3AED,
        ),
        LobbyFloorSignpost(
          center: Offset(768, 275),
          text: '🎓 FACULTY CONSULTATION & ADVISORY DESKS',
          colorValue: 0xFFD97706,
        ),
      ];
  }
}

/// Core `INTERACTIVE_ZONES` config array in `mainLobby` + Campus Doors.
const List<InteractiveZone> INTERACTIVE_ZONES = [
  // ── 4 CAMPUS DOORS FROM MAIN LOBBY ──
  InteractiveZone(
    id: 'door_to_park',
    label: '🌳 Door to Campus Park',
    subtitle: 'Follow the cobblestone trail to the Park trees, pond & picnic lawns',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.mainLobby,
    x: 68,
    y: 544,
    radius: 78,
    accentColor: 0xFF10B981,
    targetRoom: LobbyRoomId.park,
    targetSpawn: Offset(1360, 544),
  ),
  InteractiveZone(
    id: 'door_to_classroom',
    label: '🏫 Door to SHS Class Room',
    subtitle: 'Enter the Class Room with Teacher Podium & 12 student desks',
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
    subtitle: 'Visit the Canteen vending machines, coffee counter & dining tables',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.mainLobby,
    x: 768,
    y: 1030,
    radius: 82,
    accentColor: 0xFFF97316,
    targetRoom: LobbyRoomId.canteen,
    targetSpawn: Offset(768, 200),
  ),
  InteractiveZone(
    id: 'door_to_faculty_room',
    label: '🎓 Door to Faculty Room',
    subtitle: 'Enter the Faculty Consultation Room, bookshelves & lounge sofas',
    kind: InteractiveZoneKind.doorPortal,
    room: LobbyRoomId.mainLobby,
    x: 1468,
    y: 340,
    radius: 78,
    accentColor: 0xFFA855F7,
    targetRoom: LobbyRoomId.facultyRoom,
    targetSpawn: Offset(180, 544),
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
    subtitle: 'Talk to Lobbyist Aiko • Launch Activity Links & Mark as Done (+XP)',
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
    subtitle: 'Faculty advisory desk • Manage Reviewer Links & Activity Links',
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
    subtitle: 'Walk up to your enrolled Subject Chests to open Reviewer Links (+XP)',
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
    x: 640,
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

/// Return doors + interactive stations inside the 4 sub-rooms (`Park`, `Class Room`, `Canteen`, `Faculty Room`).
const List<InteractiveZone> kSubRoomDoorZones = [
  // Park -> Main Lobby (East Gate)
  InteractiveZone(
    id: 'park_door_to_lobby',
    label: '🏛️ Gate Back to Main School Lobby',
    subtitle: 'Return to the Main School Lobby crossroads',
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
  // Classroom Teacher Podium & Lecture Board (North Center Stage)
  InteractiveZone(
    id: 'classroom_podium_zone',
    label: '🎙️ Teacher Podium & Lecture Stage',
    subtitle: 'Check class study links or manage Reviewer & Activity Links',
    kind: InteractiveZoneKind.classroomPodium,
    room: LobbyRoomId.classroom,
    x: 768,
    y: 235,
    radius: 96,
    accentColor: 0xFFF59E0B,
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
  // Canteen Drink & Snack Vending Machine Bank (North-West)
  InteractiveZone(
    id: 'canteen_vending_west',
    label: '🥤 Drink & Snack Vending Machines',
    subtitle: 'Tap Interact to grab an iced drink or snack from the vending machine!',
    kind: InteractiveZoneKind.vendingMachine,
    room: LobbyRoomId.canteen,
    x: 340,
    y: 210,
    radius: 100,
    accentColor: 0xFF0EA5E9,
  ),
  // Canteen Merienda & Coffee Bar (North-East)
  InteractiveZone(
    id: 'canteen_vending_east',
    label: '🍱 Canteen Coffee & Merienda Counter',
    subtitle: 'Tap Interact to grab hot coffee, matcha, or study snacks!',
    kind: InteractiveZoneKind.vendingMachine,
    room: LobbyRoomId.canteen,
    x: 1120,
    y: 210,
    radius: 100,
    accentColor: 0xFFF97316,
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
  // Faculty Consultation Desk Zone
  InteractiveZone(
    id: 'faculty_consultation_desk',
    label: '🎓 Faculty Advisory & Link Desk',
    subtitle: 'Consult active subject links or manage Reviewer & Activity Links',
    kind: InteractiveZoneKind.teacherCorner,
    room: LobbyRoomId.facultyRoom,
    x: 768,
    y: 350,
    radius: 96,
    accentColor: 0xFFA855F7,
  ),
];

/// Interactive Rest Spots across all 5 rooms so students can Sit (`🪑`), Nap (`😪`), or Sleep (`🛌`).
const List<LobbyRestSpot> kLobbyRestSpots = [
  // Main Lobby Sofas & Study Chairs
  LobbyRestSpot(
    id: 'rest_lobby_sofa_1',
    label: 'Lounge Nap Sofa (West)',
    room: LobbyRoomId.mainLobby,
    x: 208,
    y: 520,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_lobby_sofa_2',
    label: 'Lounge Study Sofa (East)',
    room: LobbyRoomId.mainLobby,
    x: 496,
    y: 520,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_lobby_chair_1',
    label: 'Study Commons Chair A',
    room: LobbyRoomId.mainLobby,
    x: 240,
    y: 676,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_lobby_chair_2',
    label: 'Study Commons Chair B',
    room: LobbyRoomId.mainLobby,
    x: 528,
    y: 676,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_lobby_sofa_south',
    label: 'Quiet Reading Daybed Sofa',
    room: LobbyRoomId.mainLobby,
    x: 352,
    y: 816,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),

  // Campus Park Benches & Picnic Nap Lawns
  LobbyRestSpot(
    id: 'rest_park_bench_1',
    label: 'Shaded Tree Bench (North-West)',
    room: LobbyRoomId.park,
    x: 452,
    y: 320,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_park_bench_2',
    label: 'Pondside Park Bench (North-East)',
    room: LobbyRoomId.park,
    x: 1076,
    y: 320,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_park_bench_3',
    label: 'Koi Pond Viewing Bench (North)',
    room: LobbyRoomId.park,
    x: 768,
    y: 356,
    facing: AvatarFacing.down,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_park_picnic_1',
    label: 'Lagoon Picnic Nap Blanket (West)',
    room: LobbyRoomId.park,
    x: 420,
    y: 724,
    facing: AvatarFacing.right,
    canSleepFlat: true,
  ),
  LobbyRestSpot(
    id: 'rest_park_picnic_2',
    label: 'Sunset Tree Sleeping Lawn (East)',
    room: LobbyRoomId.park,
    x: 1100,
    y: 724,
    facing: AvatarFacing.left,
    canSleepFlat: true,
  ),

  // SHS Class Room: 8 Interactive Student Desk Chairs + Teacher Chair + Back-Row Lounge Sofa
  LobbyRestSpot(
    id: 'rest_classroom_r1_c1',
    label: 'Row 1 Student Desk #1 (West)',
    room: LobbyRoomId.classroom,
    x: 340,
    y: 428,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_r1_c2',
    label: 'Row 1 Student Desk #2 (Center-Left)',
    room: LobbyRoomId.classroom,
    x: 560,
    y: 428,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_r1_c3',
    label: 'Row 1 Student Desk #3 (Center-Right)',
    room: LobbyRoomId.classroom,
    x: 960,
    y: 428,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_r1_c4',
    label: 'Row 1 Student Desk #4 (East)',
    room: LobbyRoomId.classroom,
    x: 1180,
    y: 428,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_r2_c1',
    label: 'Row 2 Student Desk #5 (West)',
    room: LobbyRoomId.classroom,
    x: 340,
    y: 608,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_r2_c2',
    label: 'Row 2 Student Desk #6 (Center-Left)',
    room: LobbyRoomId.classroom,
    x: 560,
    y: 608,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_r2_c3',
    label: 'Row 2 Student Desk #7 (Center-Right)',
    room: LobbyRoomId.classroom,
    x: 960,
    y: 608,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_r2_c4',
    label: 'Row 2 Student Desk #8 (East)',
    room: LobbyRoomId.classroom,
    x: 1180,
    y: 608,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_classroom_back_nap',
    label: 'Back-Row Student Study & Nap Sofa',
    room: LobbyRoomId.classroom,
    x: 1160,
    y: 855,
    facing: AvatarFacing.up,
    canSleepFlat: true,
  ),

  // Canteen Dining Booths & Lounge Couches
  LobbyRestSpot(
    id: 'rest_canteen_table_1',
    label: 'Canteen Dining Table #1 (West)',
    room: LobbyRoomId.canteen,
    x: 372,
    y: 486,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_canteen_table_2',
    label: 'Canteen Dining Table #2 (Center-West)',
    room: LobbyRoomId.canteen,
    x: 590,
    y: 486,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_canteen_table_3',
    label: 'Canteen Dining Table #3 (Center-East)',
    room: LobbyRoomId.canteen,
    x: 960,
    y: 486,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_canteen_table_4',
    label: 'Canteen Dining Table #4 (East)',
    room: LobbyRoomId.canteen,
    x: 1200,
    y: 486,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_canteen_booth_nap',
    label: 'Canteen Cozy Corner Sofa Booth',
    room: LobbyRoomId.canteen,
    x: 1180,
    y: 840,
    facing: AvatarFacing.left,
    canSleepFlat: true,
  ),

  // Faculty Room Consultation Chairs & Lounge Sofa
  LobbyRestSpot(
    id: 'rest_faculty_consult_1',
    label: 'Student Consultation Chair (Center)',
    room: LobbyRoomId.facultyRoom,
    x: 768,
    y: 440,
    facing: AvatarFacing.up,
    canSleepFlat: false,
  ),
  LobbyRestSpot(
    id: 'rest_faculty_lounge_sofa',
    label: 'Faculty Guest Waiting Sofa',
    room: LobbyRoomId.facultyRoom,
    x: 1180,
    y: 740,
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
    presetName: 'Amelia',
    room: LobbyRoomId.mainLobby,
    x: 340,
    y: 590,
    facing: AvatarFacing.right,
    restState: PlayerRestState.none,
    defaultThought: '💭 Follow the purple carpet east to open our Subject Chests!',
    sampleReplies: [
      '💭 Follow the walk paths! Each path has floor signposts so you never get lost.',
      '💭 Whenever our teacher posts a Reviewer or Activity link, we can mark it as done for XP!',
      '💭 Good luck on our recitation today! Kaya natin \'to! ✨',
    ],
  ),
  LobbyPeerStudent(
    id: 'peer_main_marco',
    name: 'Marco (GAS 12)',
    presetName: 'Alex',
    room: LobbyRoomId.mainLobby,
    x: 496,
    y: 520,
    facing: AvatarFacing.down,
    restState: PlayerRestState.napping,
    defaultThought: '💭 Quick power nap on the sofa before heading to the Class Room... 😪',
    sampleReplies: [
      '💭 *yawns* Just taking a 5-minute nap before we walk up to the Class Room door! 😪',
      '💭 Try sitting or napping on the sofa too! Just tap Interact when you\'re near a seat.',
      '💭 Let\'s grab cold drinks from the Canteen vending machines down south!',
    ],
  ),

  // Park Peers
  LobbyPeerStudent(
    id: 'peer_park_bea',
    name: 'Bea (STEM 12)',
    presetName: 'Molly',
    room: LobbyRoomId.park,
    x: 560,
    y: 520,
    facing: AvatarFacing.down,
    restState: PlayerRestState.none,
    defaultThought: '💭 The trees and cobblestone trail around the pond are so relaxing 🌳',
    sampleReplies: [
      '💭 Hi classmate! The Campus Park is full of shade trees and flower bushes now.',
      '💭 You can lie down and sleep on the picnic rugs under the trees! 🛌',
      '💭 Fresh air really helps before checking our Subject Chests!',
    ],
  ),
  LobbyPeerStudent(
    id: 'peer_park_carlo',
    name: 'Carlo (HUMSS 12)',
    presetName: 'Ash',
    room: LobbyRoomId.park,
    x: 1100,
    y: 724,
    facing: AvatarFacing.left,
    restState: PlayerRestState.sleeping,
    defaultThought: '💭 Zzz... resting under the park trees... 💤',
    sampleReplies: [
      '💭 Zzz... Five more minutes on the park picnic blanket please... 🛌💤',
      '💭 Woke up refreshed! Time to complete our Reviewer & Activity links!',
    ],
  ),

  // Class Room Peers
  LobbyPeerStudent(
    id: 'peer_class_jamie',
    name: 'Jamie (ABM 12)',
    presetName: 'Jenny',
    room: LobbyRoomId.classroom,
    x: 560,
    y: 428,
    facing: AvatarFacing.up,
    restState: PlayerRestState.sitting,
    defaultThought: '💭 Sitting in Row 1 right in front of the Teacher Podium! 📝',
    sampleReplies: [
      '💭 Pick any of the 12 student desks! You can sit or nap at your chair.',
      '💭 Walk up the center carpet aisle to check the Teacher Podium & Lecture Board!',
      '💭 Which subject are you studying first today?',
    ],
  ),

  // Canteen Peers
  LobbyPeerStudent(
    id: 'peer_canteen_enz',
    name: 'Enzo (TVL 12)',
    presetName: 'Bob',
    room: LobbyRoomId.canteen,
    x: 590,
    y: 486,
    facing: AvatarFacing.down,
    restState: PlayerRestState.sitting,
    defaultThought: '💭 The new drink & snack vending machines in the Canteen are awesome! 🥤',
    sampleReplies: [
      '💭 Walk up to the Vending Machines on the north wall and tap Interact to grab a drink!',
      '💭 Study group + snacks at the Canteen tables is the best combo!',
    ],
  ),

  // Faculty Room Peer
  LobbyPeerStudent(
    id: 'peer_faculty_lara',
    name: 'Lara (Class Rep)',
    presetName: 'Lucy',
    room: LobbyRoomId.facultyRoom,
    x: 560,
    y: 520,
    facing: AvatarFacing.right,
    restState: PlayerRestState.none,
    defaultThought: '💭 Checking if new Reviewer or Activity links were posted 📌',
    sampleReplies: [
      '💭 Whenever our teacher adds a Reviewer or Activity link, we can mark it as done for XP!',
      '💭 Only active enrolled subjects from the MIS Control Sheet appear in our chests.',
    ],
  ),
];

/// Anchor positions for Subject-Labeled Large Treasure Chests inside the
/// Expanded Reviewer Treasure Corner (`x: 920..1460, y: 620..950` in `mainLobby`).
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
/// EVERY `spriteKey` below is verified against `assets/school_lobby/catalog/atlas.json`!
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

/// 1. MAIN SCHOOL LOBBY (`48 x 34` tiles = `1536 x 1088` px) — 100% Verified `atlas.json` Sprites.
const List<LobbyFurniturePiece> kSchoolLobbyPieces = [
  // ── FLOOR RUGS (non-collidable, rendered beneath characters) ──
  LobbyFurniturePiece(
    spriteKey: 'rug-red',
    x: 704,
    y: 224,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-lagoon',
    x: 160,
    y: 600,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-lagoon',
    x: 448,
    y: 600,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-sunset',
    x: 296,
    y: 780,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-plum',
    x: 1184,
    y: 210,
    collidable: false,
    isFloorRug: true,
  ),

  // ── 1. SCHOOL BULLETIN BOARD WALL (Top-Left Wing: x 64..480) ──
  LobbyFurniturePiece(
      spriteKey: 'window-office-3', x: 64, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall-charts', x: 176, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'notice-board', x: 256, y: 24, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'board-pins', x: 332, y: 24, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'world-map', x: 408, y: 24, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-clock', x: 480, y: 26, collidable: false),
  LobbyFurniturePiece(spriteKey: 'wall-bookcase', x: 88, y: 52),
  LobbyFurniturePiece(spriteKey: 'bookshelf', x: 416, y: 78),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 52, y: 88),

  // ── 2. RECEPTION / QUEST COUNTER (Top-Center Hall: x 560..976) ──
  LobbyFurniturePiece(
      spriteKey: 'wall-notice', x: 640, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall-trophy', x: 752, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall-cert', x: 792, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall-shelf', x: 848, y: 18, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desks-front-maple-2', x: 560, y: 136),
  LobbyFurniturePiece(
      spriteKey: 'setup-monitors', x: 720, y: 130, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-lamp-teal', x: 600, y: 136, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'desk-phone-a', x: 860, y: 148, collidable: false),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 520, y: 140),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 984, y: 140),

  // ── 3. TEACHER'S CORNER (Top-Right Wing: x 1060..1460) ──
  LobbyFurniturePiece(
      spriteKey: 'wall-painting', x: 1080, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'board-chart', x: 1180, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'window-office-3', x: 1320, y: 18, collidable: false),
  LobbyFurniturePiece(spriteKey: 'wall-bookcase-red', x: 1056, y: 52),
  LobbyFurniturePiece(spriteKey: 'wall-bookcase-pale', x: 1124, y: 52),
  LobbyFurniturePiece(spriteKey: 'desks-single-walnut-1-n4', x: 1184, y: 140),
  LobbyFurniturePiece(
      spriteKey: 'setup-laptop', x: 1216, y: 136, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-globe', x: 1192, y: 150, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-books', x: 1304, y: 150, collidable: false),
  LobbyFurniturePiece(spriteKey: 'water-cooler', x: 1424, y: 104),

  // ── 4. STUDENT LOUNGE & STUDY COMMONS (West & South-West Wing) ──
  LobbyFurniturePiece(
      spriteKey: 'sofa-three', x: 176, y: 484, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'sofa-three', x: 464, y: 484, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desks-single-maple-1-n4', x: 160, y: 576),
  LobbyFurniturePiece(
      spriteKey: 'ours-notebook', x: 196, y: 590, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-pen-cup', x: 240, y: 588, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desks-single-oak-1-n4', x: 448, y: 576),
  LobbyFurniturePiece(
      spriteKey: 'laptop-open', x: 488, y: 582, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-books', x: 540, y: 590, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 224, y: 652, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 512, y: 652, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'sofa-two', x: 320, y: 784, collidable: false),
  LobbyFurniturePiece(spriteKey: 'coffee-table', x: 320, y: 848),
  LobbyFurniturePiece(spriteKey: 'vending-drinks', x: 56, y: 720),
  LobbyFurniturePiece(spriteKey: 'vending-snacks', x: 56, y: 810),
  LobbyFurniturePiece(spriteKey: 'plant-snake', x: 368, y: 580),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 640, y: 780),

  // ── 5. REVIEWER TREASURE CORNER SANCTUARY (Bottom-Right Wing: x 880..1460) ──
  LobbyFurniturePiece(spriteKey: 'ours-bush-lilac', x: 896, y: 476),
  LobbyFurniturePiece(spriteKey: 'ours-bush-sage', x: 1424, y: 476),
  LobbyFurniturePiece(spriteKey: 'bookshelf', x: 1024, y: 476),
  LobbyFurniturePiece(spriteKey: 'shelving', x: 1092, y: 476),
  LobbyFurniturePiece(spriteKey: 'shelving', x: 1228, y: 476),
  LobbyFurniturePiece(spriteKey: 'bookshelf', x: 1296, y: 476),
  LobbyFurniturePiece(spriteKey: 'lamp-blue', x: 900, y: 640),
  LobbyFurniturePiece(spriteKey: 'lamp-red', x: 1424, y: 640),
  LobbyFurniturePiece(spriteKey: 'plant-small', x: 896, y: 880),
  LobbyFurniturePiece(spriteKey: 'plant-small', x: 1424, y: 880),
];

/// 2. CAMPUS NATURE PARK (`LobbyRoomId.park`) — Filled with Lush Trees, Bushes, Flowers, Benches & Picnic Rugs!
const List<LobbyFurniturePiece> kParkRoomPieces = [
  // ── PICNIC RUGS (non-collidable, rendered beneath characters) ──
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-lagoon',
    x: 356,
    y: 680,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-sunset',
    x: 1036,
    y: 680,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-plum',
    x: 200,
    y: 300,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug-blue',
    x: 1210,
    y: 300,
    collidable: false,
    isFloorRug: true,
  ),

  // ── NORTH WOODLAND TREE CANOPY (Large `tree` 96x128 & `tree-small` 64x96) ──
  LobbyFurniturePiece(spriteKey: 'tree', x: 64, y: 64),
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 180, y: 88),
  LobbyFurniturePiece(spriteKey: 'tree', x: 268, y: 64),
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 392, y: 88),
  LobbyFurniturePiece(spriteKey: 'tree', x: 520, y: 64),
  LobbyFurniturePiece(spriteKey: 'tree', x: 920, y: 64),
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 1044, y: 88),
  LobbyFurniturePiece(spriteKey: 'tree', x: 1140, y: 64),
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 1264, y: 88),
  LobbyFurniturePiece(spriteKey: 'tree', x: 1356, y: 64),

  // ── WEST & EAST GARDEN TREE GROVES ──
  LobbyFurniturePiece(spriteKey: 'tree', x: 64, y: 260),
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 80, y: 400),
  LobbyFurniturePiece(spriteKey: 'tree', x: 64, y: 620),
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 170, y: 780),
  LobbyFurniturePiece(spriteKey: 'tree', x: 64, y: 860),
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 1368, y: 260),
  LobbyFurniturePiece(spriteKey: 'tree', x: 1356, y: 640),
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 1270, y: 780),
  LobbyFurniturePiece(spriteKey: 'tree', x: 1356, y: 860),

  // ── SOUTH GARDEN BORDER TREES ──
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 310, y: 890),
  LobbyFurniturePiece(spriteKey: 'tree', x: 540, y: 876),
  LobbyFurniturePiece(spriteKey: 'tree', x: 900, y: 876),
  LobbyFurniturePiece(spriteKey: 'tree-small', x: 1140, y: 890),

  // ── PARK BENCHES (non-collidable so students can sit, nap, or sleep!) ──
  LobbyFurniturePiece(
      spriteKey: 'bench-pale', x: 420, y: 296, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'bench-pale', x: 1044, y: 296, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'bench-pale', x: 736, y: 332, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'bench-pale', x: 736, y: 668, collidable: false),

  // ── FLOWERING BUSHES, SHRUBS, WILDFLOWERS & NATURAL BOULDERS ──
  LobbyFurniturePiece(spriteKey: 'bush', x: 340, y: 220),
  LobbyFurniturePiece(spriteKey: 'bush', x: 1120, y: 220),
  LobbyFurniturePiece(spriteKey: 'ours-bush-sage', x: 536, y: 360),
  LobbyFurniturePiece(spriteKey: 'ours-bush-lilac', x: 964, y: 360),
  LobbyFurniturePiece(spriteKey: 'ours-bush-clay', x: 536, y: 590),
  LobbyFurniturePiece(spriteKey: 'ours-bush-white', x: 964, y: 590),
  LobbyFurniturePiece(spriteKey: 'ours-bush-small-clay', x: 300, y: 690),
  LobbyFurniturePiece(spriteKey: 'ours-bush-small-white', x: 500, y: 690),
  LobbyFurniturePiece(spriteKey: 'ours-bush-small-clay', x: 988, y: 690),
  LobbyFurniturePiece(spriteKey: 'ours-bush-small-white', x: 1180, y: 690),
  LobbyFurniturePiece(
      spriteKey: 'flowers', x: 256, y: 440, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'flowers-pink', x: 296, y: 456, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'flowers', x: 1180, y: 440, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'flowers-pink', x: 1220, y: 456, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'flowers-pink', x: 640, y: 320, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'flowers', x: 868, y: 320, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'grass', x: 360, y: 460, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'grass', x: 1120, y: 460, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'grass', x: 680, y: 760, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'grass', x: 830, y: 760, collidable: false),
  LobbyFurniturePiece(spriteKey: 'rocks', x: 560, y: 468),
  LobbyFurniturePiece(spriteKey: 'rocks-small', x: 912, y: 472),
  LobbyFurniturePiece(spriteKey: 'rocks', x: 640, y: 836),
  LobbyFurniturePiece(spriteKey: 'rocks-small', x: 860, y: 842),
];

/// 3. SHS CLASS ROOM (`LobbyRoomId.classroom`) — Teacher Podium, Lecture Stage, Boards & 12 Student Desks/Chairs!
const List<LobbyFurniturePiece> kClassroomPieces = [
  // ── STAGE & BACK-ROW STUDY RUGS ──
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-plum',
    x: 704,
    y: 156,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-lagoon',
    x: 1096,
    y: 828,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-small-sunset',
    x: 280,
    y: 840,
    collidable: false,
    isFloorRug: true,
  ),

  // ── FRONT LECTURE WALL: WINDOWS, CHARTS, CHALKBOARDS, WORLD MAP & CLOCK ──
  LobbyFurniturePiece(
      spriteKey: 'window-office-3', x: 88, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'board-chart', x: 280, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'board-pie', x: 360, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'board-blank', x: 1112, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'world-map', x: 1192, y: 24, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-clock', x: 1272, y: 24, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'window-office-3', x: 1344, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall-trophy', x: 444, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall-cert', x: 1064, y: 18, collidable: false),
  LobbyFurniturePiece(spriteKey: 'wall-bookcase', x: 184, y: 52),
  LobbyFurniturePiece(spriteKey: 'wall-bookcase-pale', x: 1288, y: 52),

  // ── FRONT TEACHER PODIUM & LECTURE DESK (Center Stage: x=688, y=156) ──
  LobbyFurniturePiece(
      spriteKey: 'chair-black-mesh', x: 752, y: 122, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desks-single-walnut-1-n4', x: 688, y: 156),
  LobbyFurniturePiece(
      spriteKey: 'microphone', x: 740, y: 162, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'laptop-open', x: 764, y: 158, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-globe', x: 700, y: 168, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-books', x: 808, y: 168, collidable: false),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 600, y: 148),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 904, y: 148),

  // ── ROW 1 STUDENT DESKS & CHAIRS (4 Desks + 4 Chairs + Notebooks/Books) ──
  LobbyFurniturePiece(spriteKey: 'desks-single-maple-1-n4', x: 260, y: 324),
  LobbyFurniturePiece(
      spriteKey: 'ours-notebook', x: 300, y: 340, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-pen-cup', x: 356, y: 338, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 324, y: 404, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-oak-1-n4', x: 480, y: 324),
  LobbyFurniturePiece(
      spriteKey: 'ours-books', x: 520, y: 340, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-notebook', x: 564, y: 340, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 544, y: 404, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-maple-1-n4', x: 880, y: 324),
  LobbyFurniturePiece(
      spriteKey: 'laptop-dark', x: 924, y: 332, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-pen-cup', x: 976, y: 338, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 944, y: 404, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-oak-1-n4', x: 1100, y: 324),
  LobbyFurniturePiece(
      spriteKey: 'ours-notebook', x: 1140, y: 340, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-books', x: 1188, y: 340, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 1164, y: 404, collidable: false),

  // ── ROW 2 STUDENT DESKS & CHAIRS (4 Desks + 4 Chairs) ──
  LobbyFurniturePiece(spriteKey: 'desks-single-oak-1-n4', x: 260, y: 504),
  LobbyFurniturePiece(
      spriteKey: 'ours-books', x: 304, y: 520, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-black-back', x: 324, y: 584, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-maple-1-n4', x: 480, y: 504),
  LobbyFurniturePiece(
      spriteKey: 'laptop-open', x: 524, y: 512, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-black-back', x: 544, y: 584, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-oak-1-n4', x: 880, y: 504),
  LobbyFurniturePiece(
      spriteKey: 'ours-notebook', x: 924, y: 520, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-black-back', x: 944, y: 584, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-maple-1-n4', x: 1100, y: 504),
  LobbyFurniturePiece(
      spriteKey: 'ours-pen-cup', x: 1144, y: 518, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-black-back', x: 1164, y: 584, collidable: false),

  // ── ROW 3 STUDENT DESKS & CHAIRS (4 Desks + 4 Chairs) ──
  LobbyFurniturePiece(spriteKey: 'desks-single-maple-1-n4', x: 260, y: 684),
  LobbyFurniturePiece(
      spriteKey: 'ours-notebook', x: 304, y: 700, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-mesh-back', x: 324, y: 764, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-oak-1-n4', x: 480, y: 684),
  LobbyFurniturePiece(
      spriteKey: 'ours-books', x: 524, y: 700, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-mesh-back', x: 544, y: 764, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-maple-1-n4', x: 880, y: 684),
  LobbyFurniturePiece(
      spriteKey: 'ours-notebook', x: 924, y: 700, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-mesh-back', x: 944, y: 764, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-oak-1-n4', x: 1100, y: 684),
  LobbyFurniturePiece(
      spriteKey: 'ours-books', x: 1144, y: 700, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-mesh-back', x: 1164, y: 764, collidable: false),

  // ── BACK-ROW CLASSROOM READING & NAP CORNER ──
  LobbyFurniturePiece(spriteKey: 'bookshelf', x: 96, y: 840),
  LobbyFurniturePiece(spriteKey: 'shelving', x: 164, y: 840),
  LobbyFurniturePiece(
      spriteKey: 'egg-chair-teal', x: 296, y: 842, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'sofa-three', x: 1128, y: 836, collidable: false),
  LobbyFurniturePiece(spriteKey: 'plant-snake', x: 88, y: 420),
  LobbyFurniturePiece(spriteKey: 'plant-snake', x: 1416, y: 420),
];

/// 4. STUDENT CANTEEN (`LobbyRoomId.canteen`) — Vending Machines, Coolers, Coffee Counter & 6 Dining Tables!
const List<LobbyFurniturePiece> kCanteenPieces = [
  // ── LOUNGE RUGS ──
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-sunset',
    x: 1116,
    y: 800,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-lagoon',
    x: 240,
    y: 800,
    collidable: false,
    isFloorRug: true,
  ),

  // ── NORTH-WEST VENDING MACHINE BANK (Drinks, Snacks, Wall Vending & Coolers) ──
  LobbyFurniturePiece(
      spriteKey: 'wall-poster', x: 96, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'window-blinds-3', x: 540, y: 18, collidable: false),
  LobbyFurniturePiece(spriteKey: 'vending-drinks', x: 144, y: 92),
  LobbyFurniturePiece(spriteKey: 'vending-snacks', x: 216, y: 92),
  LobbyFurniturePiece(spriteKey: 'wall-vending', x: 288, y: 76),
  LobbyFurniturePiece(spriteKey: 'vending-drinks', x: 424, y: 92),
  LobbyFurniturePiece(spriteKey: 'vending-snacks', x: 496, y: 92),
  LobbyFurniturePiece(spriteKey: 'water-cooler', x: 572, y: 108),
  LobbyFurniturePiece(spriteKey: 'mini-fridge', x: 612, y: 124),

  // ── NORTH-EAST MERIENDA & COFFEE COUNTER ──
  LobbyFurniturePiece(
      spriteKey: 'wall-painting', x: 900, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-clock', x: 1000, y: 24, collidable: false),
  LobbyFurniturePiece(spriteKey: 'wall-shelf-cooler', x: 880, y: 76),
  LobbyFurniturePiece(spriteKey: 'wall-coffee-table', x: 984, y: 76),
  LobbyFurniturePiece(spriteKey: 'wall-vending', x: 1056, y: 76),
  LobbyFurniturePiece(spriteKey: 'wall-cooler', x: 1192, y: 76),
  LobbyFurniturePiece(spriteKey: 'desks-front-maple-2', x: 920, y: 148),
  LobbyFurniturePiece(
      spriteKey: 'ours-mug-coral', x: 960, y: 156, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-mug-mustard', x: 1040, y: 156, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-mug-teal', x: 1120, y: 156, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-bottle', x: 1200, y: 156, collidable: false),

  // ── 6 DINING TABLES & CHAIRS (Row 1: y=370, Row 2: y=620) ──
  // Table 1 (West Row 1)
  LobbyFurniturePiece(spriteKey: 'meeting-table', x: 220, y: 370),
  LobbyFurniturePiece(
      spriteKey: 'ours-mug-coral', x: 280, y: 392, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-bottle', x: 360, y: 392, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 268, y: 458, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 356, y: 458, collidable: false),

  // Table 2 (Center-West Row 1)
  LobbyFurniturePiece(spriteKey: 'meeting-table-small', x: 500, y: 370),
  LobbyFurniturePiece(
      spriteKey: 'ours-mug-teal', x: 564, y: 392, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 536, y: 458, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 600, y: 458, collidable: false),

  // Table 3 (Center-East Row 1)
  LobbyFurniturePiece(spriteKey: 'meeting-table-small', x: 880, y: 370),
  LobbyFurniturePiece(
      spriteKey: 'ours-mug-mustard', x: 944, y: 392, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 916, y: 458, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 980, y: 458, collidable: false),

  // Table 4 (East Row 1)
  LobbyFurniturePiece(spriteKey: 'meeting-table', x: 1096, y: 370),
  LobbyFurniturePiece(
      spriteKey: 'ours-bottle', x: 1156, y: 392, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-mug-coral', x: 1236, y: 392, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 1144, y: 458, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 1232, y: 458, collidable: false),

  // Table 5 (West Row 2)
  LobbyFurniturePiece(spriteKey: 'meeting-table', x: 260, y: 620),
  LobbyFurniturePiece(
      spriteKey: 'ours-mug-mustard', x: 320, y: 642, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'stool', x: 308, y: 708, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'stool', x: 396, y: 708, collidable: false),

  // Table 6 (East Row 2)
  LobbyFurniturePiece(spriteKey: 'meeting-table', x: 920, y: 620),
  LobbyFurniturePiece(
      spriteKey: 'ours-mug-teal', x: 980, y: 642, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'stool', x: 968, y: 708, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'stool', x: 1056, y: 708, collidable: false),

  // ── COZY CANTEEN LOUNGE & NAP BOOTHS (South Corners) ──
  LobbyFurniturePiece(
      spriteKey: 'egg-chair-coral', x: 256, y: 816, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'egg-chair-mustard', x: 328, y: 816, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'sofa-three', x: 1148, y: 816, collidable: false),
  LobbyFurniturePiece(spriteKey: 'coffee-table', x: 1148, y: 880),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 88, y: 840),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 1408, y: 840),
];

/// 5. FACULTY CONSULTATION ROOM (`LobbyRoomId.facultyRoom`) — Adviser Desks, Bookcases & Waiting Lounge!
const List<LobbyFurniturePiece> kFacultyRoomPieces = [
  // ── RUGS ──
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-plum',
    x: 704,
    y: 360,
    collidable: false,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-lagoon',
    x: 1116,
    y: 700,
    collidable: false,
    isFloorRug: true,
  ),

  // ── NORTH WALL BOOKCASES, CHARTS & WINDOWS ──
  LobbyFurniturePiece(
      spriteKey: 'window-office-3', x: 120, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall-painting', x: 480, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'wall-charts', x: 736, y: 18, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'notice-board', x: 960, y: 24, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-clock', x: 1056, y: 24, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'window-office-3', x: 1280, y: 18, collidable: false),
  LobbyFurniturePiece(spriteKey: 'wall-bookcase', x: 240, y: 52),
  LobbyFurniturePiece(spriteKey: 'wall-bookcase-red', x: 310, y: 52),
  LobbyFurniturePiece(spriteKey: 'wall-bookcase-pale', x: 1120, y: 52),
  LobbyFurniturePiece(spriteKey: 'wall-cabinet', x: 1190, y: 52),

  // ── FACULTY CONSULTATION DESKS ──
  LobbyFurniturePiece(
      spriteKey: 'chair-black-mesh', x: 752, y: 268, collidable: false),
  LobbyFurniturePiece(spriteKey: 'desks-single-walnut-1-n4', x: 688, y: 300),
  LobbyFurniturePiece(
      spriteKey: 'setup-monitors', x: 720, y: 292, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-globe', x: 696, y: 312, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'chair-tan-back', x: 752, y: 416, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-oak-1-n4', x: 360, y: 300),
  LobbyFurniturePiece(
      spriteKey: 'setup-laptop', x: 392, y: 294, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-books', x: 368, y: 312, collidable: false),

  LobbyFurniturePiece(spriteKey: 'desks-single-maple-1-n4', x: 1020, y: 300),
  LobbyFurniturePiece(
      spriteKey: 'setup-laptop-b', x: 1052, y: 294, collidable: false),
  LobbyFurniturePiece(
      spriteKey: 'ours-pen-cup', x: 1032, y: 312, collidable: false),

  // ── WAITING LOUNGE & ARCHIVE SHELVES ──
  LobbyFurniturePiece(spriteKey: 'bookshelf', x: 240, y: 700),
  LobbyFurniturePiece(spriteKey: 'shelving', x: 312, y: 700),
  LobbyFurniturePiece(
      spriteKey: 'sofa-three', x: 1148, y: 716, collidable: false),
  LobbyFurniturePiece(spriteKey: 'coffee-table', x: 1148, y: 780),
  LobbyFurniturePiece(spriteKey: 'water-cooler', x: 1380, y: 112),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 580, y: 140),
  LobbyFurniturePiece(spriteKey: 'plant-tall', x: 940, y: 140),
];

/// Non-player staff characters rendered in the School Campus.
/// Phase 4 Requirement 1: Keep ONLY the Lobbyist (`npc_receptionist: Aiko`) and remove all other non-student NPCs!
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
    name: 'Aiko (Lobbyist)',
    roleTag: 'Lobbyist',
    isGoldTag: true,
    presetName: 'Lucy',
    room: LobbyRoomId.mainLobby,
    x: 768,
    y: 132,
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
/// Walk paths and interactive chairs/benches/rugs are kept 100% clear so pathfinding is seamless!
List<Rect> buildLobbySolids(
  List<SubjectChest> subjectChests, {
  LobbyRoomId room = LobbyRoomId.mainLobby,
}) {
  final solids = <Rect>[
    // Outer perimeter walls (expanded 1536 x 1088)
    const Rect.fromLTWH(0, 0, kLobbyWorldWidth, 82), // Top wall
    const Rect.fromLTWH(
        0, kLobbyWorldHeight - 24, kLobbyWorldWidth, 24), // Bottom wall
    const Rect.fromLTWH(0, 0, 32, kLobbyWorldHeight), // Left wall
    const Rect.fromLTWH(
        kLobbyWorldWidth - 32, 0, 32, kLobbyWorldHeight), // Right wall
  ];

  switch (room) {
    case LobbyRoomId.mainLobby:
      solids.addAll(const [
        // Reception Counter (`desks-front-maple-2`) collider
        Rect.fromLTWH(576, 148, 384, 44),
        // Teacher's Corner Desk collider
        Rect.fromLTWH(1192, 152, 144, 44),
        // Bookshelves along top walls
        Rect.fromLTWH(88, 82, 64, 34),
        Rect.fromLTWH(416, 82, 64, 36),
        Rect.fromLTWH(1056, 82, 128, 36),
        // Student Lounge study tables (chairs & sofas remain walkable for sitting/napping/sleeping!)
        Rect.fromLTWH(168, 586, 144, 38),
        Rect.fromLTWH(456, 586, 144, 38),
        Rect.fromLTWH(320, 852, 60, 28),
        // West Vending machines
        Rect.fromLTWH(56, 724, 56, 156),
        // Reviewer Sanctuary top bookshelves
        Rect.fromLTWH(1024, 480, 128, 34),
        Rect.fromLTWH(1228, 480, 128, 34),
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
      // Central Park Pond water collider (walkway loop around it is 100% open!)
      solids.add(const Rect.fromLTWH(640, 420, 256, 180));
      break;

    case LobbyRoomId.classroom:
      solids.addAll(const [
        // Front Teacher Podium Desk
        Rect.fromLTWH(696, 164, 144, 42),
        // Row 1 Student Desk tables (chairs below them at y=428 are walkable!)
        Rect.fromLTWH(268, 336, 144, 36),
        Rect.fromLTWH(488, 336, 144, 36),
        Rect.fromLTWH(888, 336, 144, 36),
        Rect.fromLTWH(1108, 336, 144, 36),
        // Row 2 Student Desk tables (chairs below them at y=608 are walkable!)
        Rect.fromLTWH(268, 516, 144, 36),
        Rect.fromLTWH(488, 516, 144, 36),
        Rect.fromLTWH(888, 516, 144, 36),
        Rect.fromLTWH(1108, 516, 144, 36),
        // Row 3 Student Desk tables (chairs below them at y=764 are walkable!)
        Rect.fromLTWH(268, 696, 144, 36),
        Rect.fromLTWH(488, 696, 144, 36),
        Rect.fromLTWH(888, 696, 144, 36),
        Rect.fromLTWH(1108, 696, 144, 36),
      ]);
      break;

    case LobbyRoomId.canteen:
      solids.addAll(const [
        // North-West Vending Machine Bank
        Rect.fromLTWH(144, 96, 480, 56),
        // North-East Merienda & Coffee Counter
        Rect.fromLTWH(920, 148, 400, 46),
        // Row 1 Dining tables (chairs below them at y=486 are walkable!)
        Rect.fromLTWH(228, 382, 204, 44),
        Rect.fromLTWH(508, 382, 144, 44),
        Rect.fromLTWH(888, 382, 144, 44),
        Rect.fromLTWH(1104, 382, 204, 44),
        // Row 2 Dining tables
        Rect.fromLTWH(268, 632, 204, 44),
        Rect.fromLTWH(928, 632, 204, 44),
      ]);
      break;

    case LobbyRoomId.facultyRoom:
      solids.addAll(const [
        // Faculty consultation desks
        Rect.fromLTWH(368, 312, 144, 42),
        Rect.fromLTWH(696, 312, 144, 42),
        Rect.fromLTWH(1028, 312, 144, 42),
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
    zones.addAll(
        INTERACTIVE_ZONES.where((z) => z.room == LobbyRoomId.mainLobby));
    for (var i = 0; i < subjectChests.length; i++) {
      final chest = subjectChests[i];
      final pos = subjectChestPosition(i);
      zones.add(
        InteractiveZone(
          id: 'subject_chest_${chest.id}',
          label: '📦 ${chest.subjectName} Reviewer Chest',
          subtitle: chest.reviewers.isEmpty
              ? 'Empty Vault • Teacher can add Reviewer Links (+XP)'
              : '${chest.reviewers.length} Reviewer Link(s) ready • Tap Interact to open',
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
