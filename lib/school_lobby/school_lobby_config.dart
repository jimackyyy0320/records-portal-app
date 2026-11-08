import 'dart:ui';
import 'lobby_data_service.dart';

/// Core tile & expanded world constants (`48 x 34` tiles = `1536 x 1088` world pixels — ~4x larger!).
const double kTileSize = 32.0;
const int kLobbyCols = 48;
const int kLobbyRows = 34;
const double kLobbyWorldWidth = kLobbyCols * kTileSize; // 1536 px
const double kLobbyWorldHeight = kLobbyRows * kTileSize; // 1088 px
const double kPlayerHalfWidth = 10.0;
const double kPlayerMoveSpeed = 235.0; // pixels per second across expanded campus

/// Spawn point in the center Student Lounge & Study Commons open courtyard.
const Offset kPlayerSpawnPoint = Offset(768.0, 544.0);

/// Zone types for wiring interactive modals in the School Lobby.
enum InteractiveZoneKind {
  questCounter,
  teacherCorner,
  bulletinBoard,
  studentLounge,
  reviewerTreasureArea,
  subjectChest,
  smallMysteryChest,
}

/// Clean `INTERACTIVE_ZONES` configuration entry (`{ id, label, x, y, radius }`).
class InteractiveZone {
  final String id;
  final String label;
  final double x;
  final double y;
  final double radius;
  final InteractiveZoneKind kind;
  final String subtitle;
  final int accentColor;
  final String? subjectChestId;

  const InteractiveZone({
    required this.id,
    required this.label,
    required this.x,
    required this.y,
    required this.radius,
    required this.kind,
    this.subtitle = '',
    this.accentColor = 0xFF38BDF8,
    this.subjectChestId,
  });

  Offset get center => Offset(x, y);
}

/// Base `INTERACTIVE_ZONES` configuration array for the 5 core School Lobby zones
/// plus 8 Small Mystery Chests distributed across the `48 x 34` campus map.
const List<InteractiveZone> INTERACTIVE_ZONES = [
  // 1. Reception / Quest Counter Area (North-Center Atrium)
  InteractiveZone(
    id: 'quest_counter',
    label: 'Reception / Quest Counter',
    x: 768.0,
    y: 196.0,
    radius: 95.0,
    kind: InteractiveZoneKind.questCounter,
    subtitle: 'View Quests, Claim Badges & Post Activities',
    accentColor: 0xFFF59E0B,
  ),
  // 2. Teacher's Corner / Faculty Suite (North-East Wing)
  InteractiveZone(
    id: 'teacher_corner',
    label: "Teacher's Corner",
    x: 1248.0,
    y: 196.0,
    radius: 92.0,
    kind: InteractiveZoneKind.teacherCorner,
    subtitle: 'Faculty Advisory Desk & Subject Chest Manager',
    accentColor: 0xFFEAB308,
  ),
  // 3. Bulletin Board Wall Gallery (North-West Wing)
  InteractiveZone(
    id: 'bulletin_board',
    label: 'Bulletin Board Wall',
    x: 268.0,
    y: 182.0,
    radius: 92.0,
    kind: InteractiveZoneKind.bulletinBoard,
    subtitle: 'MIS-SHS Announcements & Honor Leaderboard',
    accentColor: 0xFF38BDF8,
  ),
  // 4. Student Lounge & Study Tables (Central & West Commons)
  InteractiveZone(
    id: 'student_lounge',
    label: 'Student Lounge & Study Commons',
    x: 416.0,
    y: 620.0,
    radius: 96.0,
    kind: InteractiveZoneKind.studentLounge,
    subtitle: 'Peer Study Hub & Avatar Emote Lounge',
    accentColor: 0xFF10B981,
  ),

  // 8 Small Mystery Chests (`small_chest_1` .. `small_chest_8`) across the campus
  InteractiveZone(
    id: 'small_chest_1',
    label: 'Small Mystery Chest #1',
    x: 112.0,
    y: 288.0,
    radius: 58.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  InteractiveZone(
    id: 'small_chest_2',
    label: 'Small Mystery Chest #2',
    x: 528.0,
    y: 268.0,
    radius: 58.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  InteractiveZone(
    id: 'small_chest_3',
    label: 'Small Mystery Chest #3',
    x: 1024.0,
    y: 268.0,
    radius: 58.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  InteractiveZone(
    id: 'small_chest_4',
    label: 'Small Mystery Chest #4',
    x: 1424.0,
    y: 320.0,
    radius: 58.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  InteractiveZone(
    id: 'small_chest_5',
    label: 'Small Mystery Chest #5',
    x: 128.0,
    y: 688.0,
    radius: 58.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  InteractiveZone(
    id: 'small_chest_6',
    label: 'Small Mystery Chest #6',
    x: 160.0,
    y: 960.0,
    radius: 58.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  InteractiveZone(
    id: 'small_chest_7',
    label: 'Small Mystery Chest #7',
    x: 640.0,
    y: 944.0,
    radius: 58.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  InteractiveZone(
    id: 'small_chest_8',
    label: 'Small Mystery Chest #8',
    x: 1424.0,
    y: 960.0,
    radius: 58.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
];

/// Computes the world position `(x, y)` for each Subject-Labeled Large Treasure Chest
/// inside the expanded Reviewer Treasure Vault Sanctuary (South-East Wing: x 940..1420, y 580..960).
Offset subjectChestPosition(int index) {
  const cols = 2;
  const startX = 1048.0;
  const spacingX = 240.0;
  const startY = 636.0;
  const spacingY = 148.0;

  final col = index % cols;
  final row = index ~/ cols;
  return Offset(
    startX + col * spacingX,
    (startY + row * spacingY).clamp(560.0, 988.0),
  );
}

/// Builds the complete list of active interactive zones, merging `INTERACTIVE_ZONES`
/// with the dynamic Subject-Labeled Large Treasure Chests from `LobbyDataService`.
List<InteractiveZone> buildActiveInteractiveZones(List<SubjectChest> chests) {
  final dynamicChests = <InteractiveZone>[];
  for (var i = 0; i < chests.length; i++) {
    final chest = chests[i];
    final pos = subjectChestPosition(i);
    dynamicChests.add(
      InteractiveZone(
        id: 'subject_chest_${chest.id}',
        label: '${chest.subjectName} Reviewer Chest',
        x: pos.dx,
        y: pos.dy,
        radius: 66.0,
        kind: InteractiveZoneKind.subjectChest,
        subtitle:
            '${chest.reviewers.length} Reviewer(s) • ${chest.totalQuestions} Quiz Qs',
        accentColor: chest.colorValue,
        subjectChestId: chest.id,
      ),
    );
  }
  return [...dynamicChests, ...INTERACTIVE_ZONES];
}

/// Furniture / Object placement recycled from TinyFloor's `atlas.json` + `office.ts`.
class LobbyFurniturePiece {
  final String spriteKey;
  final double x;
  final double y;
  final bool isFloorRug;
  final bool isWallMounted;
  final Rect? collider;

  const LobbyFurniturePiece({
    required this.spriteKey,
    required this.x,
    required this.y,
    this.isFloorRug = false,
    this.isWallMounted = false,
    this.collider,
  });

  double get sortY {
    if (isFloorRug) return -1000.0;
    if (isWallMounted) return y + 8.0;
    return collider?.bottom ?? (y + 32.0);
  }
}

/// Static NPCs stationed in the School Lobby (Anime Receptionist + Faculty Mentor + Librarian).
class LobbyNpc {
  final String id;
  final String name;
  final String roleTag;
  final bool isGoldTag;
  final String presetName;
  final double x;
  final double y;
  final String greeting;

  const LobbyNpc({
    required this.id,
    required this.name,
    required this.roleTag,
    required this.isGoldTag,
    required this.presetName,
    required this.x,
    required this.y,
    required this.greeting,
  });
}

const List<LobbyNpc> kLobbyNpcs = [
  LobbyNpc(
    id: 'npc_receptionist',
    name: 'Aira (Quest Guide)',
    roleTag: 'Quest Counter',
    isGoldTag: true,
    presetName: 'Amelia',
    x: 768.0,
    y: 122.0,
    greeting: 'Welcome! Tap Interact for Quests & Badges!',
  ),
  LobbyNpc(
    id: 'npc_faculty',
    name: 'Faculty Adviser',
    roleTag: 'Teacher',
    isGoldTag: true,
    presetName: 'Edward',
    x: 1248.0,
    y: 122.0,
    greeting: 'Reviewers & Subject Chests are open!',
  ),
  LobbyNpc(
    id: 'npc_vault_keeper',
    name: 'Kael (Vault Keeper)',
    roleTag: 'Reviewer Vault',
    isGoldTag: false,
    presetName: 'Lucy',
    x: 1168.0,
    y: 526.0,
    greeting: 'Open the Subject Chests below to study!',
  ),
];

/// Complete Expanded `48 x 34` Student School Lobby furniture & zone pieces.
const List<LobbyFurniturePiece> kSchoolLobbyPieces = [
  // ===========================================================================
  // 1. FLOOR RUGS (Non-blocking bottom layer)
  // ===========================================================================
  // North-Center Reception / Quest Counter Grand Carpet
  LobbyFurniturePiece(spriteKey: 'ours-rug-sunset', x: 640, y: 140, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'ours-rug-sunset', x: 768, y: 140, isFloorRug: true),
  // North-West Bulletin Gallery Carpet
  LobbyFurniturePiece(spriteKey: 'rug-blue', x: 144, y: 136, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'rug-blue', x: 272, y: 136, isFloorRug: true),
  // North-East Teacher's Corner Carpet
  LobbyFurniturePiece(spriteKey: 'rug-grey', x: 1152, y: 136, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'rug-grey', x: 1248, y: 136, isFloorRug: true),
  // Central Spawn Courtyard Rugs
  LobbyFurniturePiece(spriteKey: 'ours-rug-lagoon', x: 640, y: 468, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'ours-rug-lagoon', x: 768, y: 468, isFloorRug: true),
  // South-West Student Lounge & Study Commons Rugs
  LobbyFurniturePiece(spriteKey: 'ours-rug-lagoon', x: 224, y: 540, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'ours-rug-lagoon', x: 352, y: 540, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'rug-blue', x: 224, y: 780, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'rug-blue', x: 352, y: 780, isFloorRug: true),
  // South-East Reviewer Treasure Vault Sanctuary Carpets
  LobbyFurniturePiece(spriteKey: 'ours-rug-plum', x: 960, y: 580, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'rug-red', x: 1088, y: 580, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'ours-rug-plum', x: 1216, y: 580, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'rug-red', x: 960, y: 720, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'ours-rug-plum', x: 1088, y: 720, isFloorRug: true),
  LobbyFurniturePiece(spriteKey: 'rug-red', x: 1216, y: 720, isFloorRug: true),

  // ===========================================================================
  // 2. NORTH-WEST WING: BULLETIN & HONOR WALL GALLERY
  // ===========================================================================
  LobbyFurniturePiece(spriteKey: 'wall-notice', x: 80, y: 18, isWallMounted: true),
  LobbyFurniturePiece(spriteKey: 'wall-charts', x: 156, y: 18, isWallMounted: true),
  LobbyFurniturePiece(spriteKey: 'world-map', x: 232, y: 24, isWallMounted: true),
  LobbyFurniturePiece(spriteKey: 'wall-poster', x: 308, y: 18, isWallMounted: true),
  LobbyFurniturePiece(spriteKey: 'wall-painting', x: 384, y: 18, isWallMounted: true),
  LobbyFurniturePiece(
    spriteKey: 'board-pins',
    x: 140,
    y: 84,
    collider: Rect.fromLTWH(140, 100, 64, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'board-chart',
    x: 236,
    y: 78,
    collider: Rect.fromLTWH(236, 100, 64, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'board-pie',
    x: 332,
    y: 78,
    collider: Rect.fromLTWH(332, 100, 64, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'bench-pale',
    x: 180,
    y: 196,
    collider: Rect.fromLTWH(182, 212, 60, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'bench-pale',
    x: 288,
    y: 196,
    collider: Rect.fromLTWH(290, 212, 60, 24),
  ),

  // ===========================================================================
  // 3. NORTH-CENTER WING: GRAND RECEPTION / QUEST COUNTER HALL
  // ===========================================================================
  LobbyFurniturePiece(spriteKey: 'window-office-3', x: 520, y: 16, isWallMounted: true),
  LobbyFurniturePiece(spriteKey: 'wall-trophy', x: 644, y: 16, isWallMounted: true),
  LobbyFurniturePiece(spriteKey: 'ours-clock', x: 752, y: 20, isWallMounted: true),
  LobbyFurniturePiece(spriteKey: 'wall-trophy', x: 860, y: 16, isWallMounted: true),
  LobbyFurniturePiece(spriteKey: 'window-office-3', x: 920, y: 16, isWallMounted: true),

  // Twin Reception / Quest Counter Desks
  LobbyFurniturePiece(
    spriteKey: 'desks-single-maple-1-n4',
    x: 608,
    y: 88,
    collider: Rect.fromLTWH(612, 112, 152, 42),
  ),
  LobbyFurniturePiece(
    spriteKey: 'desks-single-maple-1-n4',
    x: 772,
    y: 88,
    collider: Rect.fromLTWH(776, 112, 152, 42),
  ),
  LobbyFurniturePiece(
    spriteKey: 'plant-tall',
    x: 564,
    y: 92,
    collider: Rect.fromLTWH(568, 126, 24, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'plant-tall',
    x: 940,
    y: 92,
    collider: Rect.fromLTWH(944, 126, 24, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'lamp-blue',
    x: 530,
    y: 84,
    collider: Rect.fromLTWH(534, 134, 24, 22),
  ),
  LobbyFurniturePiece(
    spriteKey: 'lamp-blue',
    x: 980,
    y: 84,
    collider: Rect.fromLTWH(984, 134, 24, 22),
  ),

  // ===========================================================================
  // 4. NORTH-EAST WING: TEACHER'S CORNER & FACULTY ADVISORY SUITE
  // ===========================================================================
  LobbyFurniturePiece(
    spriteKey: 'wall-bookcase',
    x: 1096,
    y: 8,
    collider: Rect.fromLTWH(1096, 68, 64, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'wall-bookcase-pale',
    x: 1164,
    y: 8,
    collider: Rect.fromLTWH(1164, 68, 64, 28),
  ),
  LobbyFurniturePiece(spriteKey: 'wall-cert', x: 1240, y: 16, isWallMounted: true),
  LobbyFurniturePiece(
    spriteKey: 'wall-bookcase-red',
    x: 1284,
    y: 8,
    collider: Rect.fromLTWH(1284, 68, 64, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'wall-cabinet',
    x: 1356,
    y: 8,
    collider: Rect.fromLTWH(1356, 68, 64, 28),
  ),
  // Faculty Desks
  LobbyFurniturePiece(
    spriteKey: 'desks-single-walnut-1-n4',
    x: 1120,
    y: 92,
    collider: Rect.fromLTWH(1124, 116, 152, 42),
  ),
  LobbyFurniturePiece(
    spriteKey: 'desks-single-oak-1-n4',
    x: 1284,
    y: 92,
    collider: Rect.fromLTWH(1288, 116, 152, 42),
  ),
  LobbyFurniturePiece(spriteKey: 'ours-globe', x: 1240, y: 104),
  LobbyFurniturePiece(spriteKey: 'ours-books', x: 1320, y: 104),

  // ===========================================================================
  // 5. CENTRAL & SOUTH-WEST WING: STUDENT LOUNGE & STUDY COMMONS
  // ===========================================================================
  // Refreshment Bar along West Wall
  LobbyFurniturePiece(
    spriteKey: 'wall-vending',
    x: 48,
    y: 380,
    collider: Rect.fromLTWH(52, 432, 120, 40),
  ),
  LobbyFurniturePiece(
    spriteKey: 'water-cooler',
    x: 52,
    y: 500,
    collider: Rect.fromLTWH(54, 532, 28, 26),
  ),
  LobbyFurniturePiece(
    spriteKey: 'mini-fridge',
    x: 52,
    y: 576,
    collider: Rect.fromLTWH(54, 596, 44, 26),
  ),

  // Lounge Sofa Cluster #1 (Mid-West)
  LobbyFurniturePiece(
    spriteKey: 'sofa-corner',
    x: 196,
    y: 448,
    collider: Rect.fromLTWH(200, 488, 88, 48),
  ),
  LobbyFurniturePiece(
    spriteKey: 'coffee-table',
    x: 304,
    y: 492,
    collider: Rect.fromLTWH(306, 504, 60, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'egg-chair-teal',
    x: 384,
    y: 484,
    collider: Rect.fromLTWH(386, 500, 28, 26),
  ),
  LobbyFurniturePiece(
    spriteKey: 'egg-chair-mustard',
    x: 384,
    y: 544,
    collider: Rect.fromLTWH(386, 560, 28, 26),
  ),
  LobbyFurniturePiece(
    spriteKey: 'egg-chair-coral',
    x: 224,
    y: 564,
    collider: Rect.fromLTWH(226, 580, 28, 26),
  ),

  // Collaborative Study Tables (South-West & Center-South)
  LobbyFurniturePiece(
    spriteKey: 'meeting-table',
    x: 196,
    y: 672,
    collider: Rect.fromLTWH(204, 698, 208, 56),
  ),
  LobbyFurniturePiece(spriteKey: 'ours-books', x: 236, y: 692),
  LobbyFurniturePiece(spriteKey: 'laptop-open', x: 300, y: 684),
  LobbyFurniturePiece(spriteKey: 'ours-notebook', x: 356, y: 696),

  LobbyFurniturePiece(
    spriteKey: 'meeting-table-small',
    x: 472,
    y: 680,
    collider: Rect.fromLTWH(478, 706, 148, 48),
  ),
  LobbyFurniturePiece(spriteKey: 'ours-books', x: 508, y: 700),
  LobbyFurniturePiece(spriteKey: 'ours-mug-teal', x: 556, y: 700),

  LobbyFurniturePiece(
    spriteKey: 'meeting-table-small',
    x: 232,
    y: 836,
    collider: Rect.fromLTWH(238, 862, 148, 48),
  ),
  LobbyFurniturePiece(spriteKey: 'ours-notebook', x: 276, y: 856),
  LobbyFurniturePiece(spriteKey: 'ours-pen-cup', x: 324, y: 856),

  // Indoor Campus Courtyard Trees & Lamps
  LobbyFurniturePiece(
    spriteKey: 'tree',
    x: 540,
    y: 348,
    collider: Rect.fromLTWH(568, 438, 40, 32),
  ),
  LobbyFurniturePiece(
    spriteKey: 'tree-small',
    x: 896,
    y: 368,
    collider: Rect.fromLTWH(912, 434, 32, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'lamp-red',
    x: 468,
    y: 500,
    collider: Rect.fromLTWH(472, 550, 24, 24),
  ),

  // ===========================================================================
  // 6. SOUTH-EAST WING: GRAND REVIEWER TREASURE VAULT SANCTUARY
  // ===========================================================================
  // Bookshelf Colonnade framing the Sanctuary Entrance
  LobbyFurniturePiece(
    spriteKey: 'bookshelf',
    x: 912,
    y: 468,
    collider: Rect.fromLTWH(914, 498, 60, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'shelving',
    x: 980,
    y: 468,
    collider: Rect.fromLTWH(982, 498, 60, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'shelving',
    x: 1272,
    y: 468,
    collider: Rect.fromLTWH(1274, 498, 60, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'bookshelf',
    x: 1340,
    y: 468,
    collider: Rect.fromLTWH(1342, 498, 60, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'plant-snake',
    x: 874,
    y: 474,
    collider: Rect.fromLTWH(876, 508, 26, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'plant-snake',
    x: 1412,
    y: 474,
    collider: Rect.fromLTWH(1414, 508, 26, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'lamp-blue',
    x: 912,
    y: 720,
    collider: Rect.fromLTWH(916, 770, 24, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'lamp-blue',
    x: 1396,
    y: 720,
    collider: Rect.fromLTWH(1400, 770, 24, 24),
  ),
];

/// Builds all solid collision rectangles (perimeter walls + furniture + chest footprints)
/// across the expanded `48 x 34` School Lobby campus.
List<Rect> buildLobbySolids(List<SubjectChest> chests) {
  final solids = <Rect>[
    // Top wall (3/4 perspective wall height = 88px)
    const Rect.fromLTWH(0, 0, kLobbyWorldWidth, 88),
    // Bottom wall
    const Rect.fromLTWH(0, kLobbyWorldHeight - 28, kLobbyWorldWidth, 28),
    // Left wall
    const Rect.fromLTWH(0, 0, 36, kLobbyWorldHeight),
    // Right wall
    const Rect.fromLTWH(kLobbyWorldWidth - 36, 0, 36, kLobbyWorldHeight),
  ];

  // Furniture colliders
  for (final piece in kSchoolLobbyPieces) {
    if (piece.collider != null) {
      solids.add(piece.collider!);
    }
  }

  // Subject Chest colliders
  for (var i = 0; i < chests.length; i++) {
    final pos = subjectChestPosition(i);
    solids.add(Rect.fromCenter(center: pos, width: 42, height: 28));
  }

  // Small Mystery Chest colliders
  for (final zone in INTERACTIVE_ZONES) {
    if (zone.kind == InteractiveZoneKind.smallMysteryChest) {
      solids.add(Rect.fromCenter(center: zone.center, width: 28, height: 22));
    }
  }

  return solids;
}
