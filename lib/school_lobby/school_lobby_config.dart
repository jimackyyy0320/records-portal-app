import 'dart:ui';
import 'lobby_data_service.dart';

/// Core tile & world constants recycled from TinyFloor (`shell.ts` / `MovementManager.ts`).
const double kTileSize = 32.0;
const int kLobbyCols = 26;
const int kLobbyRows = 18;
const double kLobbyWorldWidth = kLobbyCols * kTileSize; // 832 px
const double kLobbyWorldHeight = kLobbyRows * kTileSize; // 576 px
const double kPlayerHalfWidth = 10.0;
const double kPlayerMoveSpeed = 195.0; // pixels per second

/// Spawn point in the center Student Lounge & Study Tables open floor.
const Offset kPlayerSpawnPoint = Offset(416.0, 308.0);

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
/// plus the 4 Small Mystery Chests.
const List<InteractiveZone> INTERACTIVE_ZONES = [
  // 1. Reception / Quest Counter Area (Top-Center desk area)
  InteractiveZone(
    id: 'quest_counter',
    label: 'Reception / Quest Counter',
    x: 416.0,
    y: 162.0,
    radius: 76.0,
    kind: InteractiveZoneKind.questCounter,
    subtitle: 'View Quests, Claim Badges & Post Activities',
    accentColor: 0xFFF59E0B,
  ),
  // 2. Teacher's Corner / Desk (Top-Right)
  InteractiveZone(
    id: 'teacher_corner',
    label: "Teacher's Corner",
    x: 696.0,
    y: 168.0,
    radius: 74.0,
    kind: InteractiveZoneKind.teacherCorner,
    subtitle: 'Faculty Advisory Desk & Subject Chest Manager',
    accentColor: 0xFFEAB308,
  ),
  // 3. Bulletin Board Wall (Top-Left wall)
  InteractiveZone(
    id: 'bulletin_board',
    label: 'Bulletin Board Wall',
    x: 144.0,
    y: 142.0,
    radius: 74.0,
    kind: InteractiveZoneKind.bulletinBoard,
    subtitle: 'MIS-SHS Announcements & Honor Leaderboard',
    accentColor: 0xFF38BDF8,
  ),
  // 4. Student Lounge & Study Tables (Center / Bottom-Left open floor)
  InteractiveZone(
    id: 'student_lounge',
    label: 'Student Lounge & Study Tables',
    x: 240.0,
    y: 368.0,
    radius: 74.0,
    kind: InteractiveZoneKind.studentLounge,
    subtitle: 'Peer Study Hub & Avatar Emote Lounge',
    accentColor: 0xFF10B981,
  ),
  // 5. Small Mystery Chest #1 (Top-Left near Bulletin Reading Nook)
  InteractiveZone(
    id: 'small_chest_1',
    label: 'Small Mystery Chest #1',
    x: 92.0,
    y: 230.0,
    radius: 52.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  // 6. Small Mystery Chest #2 (Bottom-Left Lounge Corner)
  InteractiveZone(
    id: 'small_chest_2',
    label: 'Small Mystery Chest #2',
    x: 92.0,
    y: 492.0,
    radius: 52.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  // 7. Small Mystery Chest #3 (Center Study Table Side)
  InteractiveZone(
    id: 'small_chest_3',
    label: 'Small Mystery Chest #3',
    x: 368.0,
    y: 486.0,
    radius: 52.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
  // 8. Small Mystery Chest #4 (Upper-Right Hallway Alcove)
  InteractiveZone(
    id: 'small_chest_4',
    label: 'Small Mystery Chest #4',
    x: 748.0,
    y: 256.0,
    radius: 52.0,
    kind: InteractiveZoneKind.smallMysteryChest,
    subtitle: 'Pop-Quiz Challenge (+20 XP)',
    accentColor: 0xFFA855F7,
  ),
];

/// Computes the world position `(x, y)` for each Subject-Labeled Large Treasure Chest
/// inside the Reviewer Treasure Corner (bottom-right sanctuary).
Offset subjectChestPosition(int index) {
  // 2-column grid inside the Reviewer Treasure Corner (x: 540..736, y: 368..496)
  const cols = 2;
  const startX = 566.0;
  const spacingX = 148.0;
  const startY = 382.0;
  const spacingY = 98.0;

  final col = index % cols;
  final row = index ~/ cols;
  return Offset(
    startX + col * spacingX,
    (startY + row * spacingY).clamp(320.0, 518.0),
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
        radius: 56.0,
        kind: InteractiveZoneKind.subjectChest,
        subtitle:
            '${chest.reviewers.length} Reviewer(s) • ${chest.totalQuestions} Quiz Qs',
        accentColor: chest.colorValue,
        subjectChestId: chest.id,
      ),
    );
  }
  // Place subject chests and small mystery chests first so specific object proximity wins
  // when standing right next to a chest.
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

/// Static NPCs stationed in the School Lobby (Anime Receptionist + Faculty Mentor).
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
    x: 416.0,
    y: 108.0,
    greeting: 'Welcome! Tap Interact for Quests & Badges!',
  ),
  LobbyNpc(
    id: 'npc_faculty',
    name: 'Faculty Adviser',
    roleTag: 'Teacher',
    isGoldTag: true,
    presetName: 'Edward',
    x: 696.0,
    y: 112.0,
    greeting: 'Reviewers & Subject Chests are open!',
  ),
];

/// Complete Student School Lobby furniture & zone pieces using TinyFloor's `atlas.json` sprites.
const List<LobbyFurniturePiece> kSchoolLobbyPieces = [
  // --- RUGS (Floor Layer, non-blocking) ---
  // Reception / Quest Counter Carpet (Top-Center)
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-sunset',
    x: 352,
    y: 118,
    isFloorRug: true,
  ),
  // Student Lounge Rug (Bottom-Left / Center)
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-lagoon',
    x: 148,
    y: 332,
    isFloorRug: true,
  ),
  // Teacher's Corner Rug (Top-Right)
  LobbyFurniturePiece(
    spriteKey: 'rug-grey',
    x: 648,
    y: 118,
    isFloorRug: true,
  ),
  // Reviewer Treasure Corner Sanctuary Rugs (Bottom-Right)
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-plum',
    x: 520,
    y: 344,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug-red',
    x: 648,
    y: 344,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-rug-plum',
    x: 520,
    y: 432,
    isFloorRug: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'rug-red',
    x: 648,
    y: 432,
    isFloorRug: true,
  ),

  // --- TOP WALL DECORATIONS: BULLETIN BOARD, QUEST BANNER & TEACHER CORNER ---
  // Bulletin Board Wall (Top-Left)
  LobbyFurniturePiece(
    spriteKey: 'wall-notice',
    x: 64,
    y: 18,
    isWallMounted: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'wall-charts',
    x: 132,
    y: 18,
    isWallMounted: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'world-map',
    x: 200,
    y: 26,
    isWallMounted: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'board-pins',
    x: 96,
    y: 80,
    collider: Rect.fromLTWH(96, 96, 64, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'board-chart',
    x: 168,
    y: 72,
    collider: Rect.fromLTWH(168, 96, 64, 24),
  ),

  // Top-Center Reception Windows, Clock & Trophy
  LobbyFurniturePiece(
    spriteKey: 'window-office-2',
    x: 292,
    y: 16,
    isWallMounted: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-clock',
    x: 400,
    y: 20,
    isWallMounted: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'window-office-2',
    x: 468,
    y: 16,
    isWallMounted: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'wall-trophy',
    x: 540,
    y: 18,
    isWallMounted: true,
  ),

  // Reception / Quest Counter Desk (Top-Center)
  LobbyFurniturePiece(
    spriteKey: 'desks-single-maple-1-n4',
    x: 336,
    y: 78,
    collider: Rect.fromLTWH(340, 102, 152, 42),
  ),
  LobbyFurniturePiece(
    spriteKey: 'plant-tall',
    x: 300,
    y: 82,
    collider: Rect.fromLTWH(304, 118, 24, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'plant-tall',
    x: 500,
    y: 82,
    collider: Rect.fromLTWH(504, 118, 24, 24),
  ),

  // Teacher's Corner / Faculty Desk (Top-Right)
  LobbyFurniturePiece(
    spriteKey: 'wall-bookcase',
    x: 596,
    y: 8,
    collider: Rect.fromLTWH(596, 68, 64, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'wall-cert',
    x: 666,
    y: 16,
    isWallMounted: true,
  ),
  LobbyFurniturePiece(
    spriteKey: 'wall-bookcase-red',
    x: 704,
    y: 8,
    collider: Rect.fromLTWH(704, 68, 64, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'desks-single-walnut-1-n4',
    x: 616,
    y: 82,
    collider: Rect.fromLTWH(620, 106, 152, 42),
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-globe',
    x: 740,
    y: 94,
  ),

  // --- STUDENT LOUNGE & STUDY TABLES (Center & Bottom-Left) ---
  // Cozy Lounge Sofas & Coffee Table (Bottom-Left)
  LobbyFurniturePiece(
    spriteKey: 'sofa-three',
    x: 112,
    y: 292,
    collider: Rect.fromLTWH(114, 318, 60, 32),
  ),
  LobbyFurniturePiece(
    spriteKey: 'coffee-table',
    x: 184,
    y: 320,
    collider: Rect.fromLTWH(186, 332, 60, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'egg-chair-teal',
    x: 256,
    y: 316,
    collider: Rect.fromLTWH(258, 332, 28, 26),
  ),
  LobbyFurniturePiece(
    spriteKey: 'egg-chair-mustard',
    x: 120,
    y: 382,
    collider: Rect.fromLTWH(122, 398, 28, 26),
  ),

  // Collaborative Study Table (Center-Left)
  LobbyFurniturePiece(
    spriteKey: 'meeting-table-small',
    x: 212,
    y: 416,
    collider: Rect.fromLTWH(218, 442, 148, 48),
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-books',
    x: 248,
    y: 436,
  ),
  LobbyFurniturePiece(
    spriteKey: 'ours-notebook',
    x: 298,
    y: 440,
  ),

  // Refreshment & Water Cooler Nook (Left Wall)
  LobbyFurniturePiece(
    spriteKey: 'vending-drinks',
    x: 42,
    y: 312,
    collider: Rect.fromLTWH(44, 352, 58, 34),
  ),
  LobbyFurniturePiece(
    spriteKey: 'water-cooler',
    x: 44,
    y: 396,
    collider: Rect.fromLTWH(46, 428, 28, 26),
  ),

  // --- REVIEWER TREASURE CORNER SANCTUARY (Bottom-Right) ---
  // Bookshelf Pillars framing the Reviewer Treasure Vaults
  LobbyFurniturePiece(
    spriteKey: 'bookshelf',
    x: 516,
    y: 274,
    collider: Rect.fromLTWH(518, 304, 60, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'bookshelf',
    x: 688,
    y: 274,
    collider: Rect.fromLTWH(690, 304, 60, 28),
  ),
  LobbyFurniturePiece(
    spriteKey: 'plant-snake',
    x: 484,
    y: 280,
    collider: Rect.fromLTWH(486, 314, 26, 24),
  ),
  LobbyFurniturePiece(
    spriteKey: 'plant-snake',
    x: 756,
    y: 280,
    collider: Rect.fromLTWH(758, 314, 26, 24),
  ),
];

/// Builds all solid collision rectangles (perimeter walls + furniture + chest footprints)
/// recycled from TinyFloor's `wallSolids` + `officeSolids`.
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
    solids.add(Rect.fromCenter(center: pos, width: 38, height: 26));
  }

  // Small Mystery Chest colliders
  for (final zone in INTERACTIVE_ZONES) {
    if (zone.kind == InteractiveZoneKind.smallMysteryChest) {
      solids.add(Rect.fromCenter(center: zone.center, width: 26, height: 20));
    }
  }

  return solids;
}
