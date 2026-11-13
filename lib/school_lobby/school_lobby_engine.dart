import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lobby_agency_agents.dart';
import 'lobby_data_service.dart';
import 'lobby_presence_service.dart';
import 'lobby_shop_service.dart';
import 'school_lobby_avatar.dart';
import 'school_lobby_config.dart';

/// Recycled from TinyFloor `Navigation.ts`:
/// Walkable tile bitmap + 8-direction A* pathfinding + line-of-sight string-pulling (`straighten`).
class LobbyNavGrid {
  final int cols;
  final int rows;
  final List<bool> _blocked;

  LobbyNavGrid({
    required this.cols,
    required this.rows,
    required List<Rect> solids,
  }) : _blocked = List<bool>.filled(cols * rows, false) {
    const pad = 8.0;
    for (final s in solids) {
      final expanded = Rect.fromLTRB(
        s.left - pad,
        s.top - pad,
        s.right + pad,
        s.bottom + pad,
      );
      final c0 = (expanded.left / kTileSize).floor().clamp(0, cols - 1);
      final c1 =
          ((expanded.right - 0.01) / kTileSize).floor().clamp(0, cols - 1);
      final r0 = (expanded.top / kTileSize).floor().clamp(0, rows - 1);
      final r1 =
          ((expanded.bottom - 0.01) / kTileSize).floor().clamp(0, rows - 1);

      for (var r = r0; r <= r1; r++) {
        for (var c = c0; c <= c1; c++) {
          _blocked[r * cols + c] = true;
        }
      }
    }
  }

  bool isWalkableTile(int col, int row) {
    if (col < 1 || col >= cols - 1 || row < 2 || row >= rows - 1) {
      return false;
    }
    return !_blocked[row * cols + col];
  }

  PointInt? nearestWalkable(int targetCol, int targetRow) {
    final tc = targetCol.clamp(1, cols - 2);
    final tr = targetRow.clamp(2, rows - 2);
    if (isWalkableTile(tc, tr)) return PointInt(tc, tr);

    for (var radius = 1; radius <= 6; radius++) {
      PointInt? best;
      var bestDist = 999999.0;
      for (var dr = -radius; dr <= radius; dr++) {
        for (var dc = -radius; dc <= radius; dc++) {
          final c = tc + dc;
          final r = tr + dr;
          if (!isWalkableTile(c, r)) continue;
          final d = (dc * dc + dr * dr).toDouble();
          if (d < bestDist) {
            bestDist = d;
            best = PointInt(c, r);
          }
        }
      }
      if (best != null) return best;
    }
    return null;
  }

  Offset tileCenter(PointInt t) => Offset(
        (t.x + 0.5) * kTileSize,
        (t.y + 0.5) * kTileSize,
      );

  /// Computes a smoothed A* world-coordinate waypoint path from [start] to [goal].
  List<Offset> findPath(Offset start, Offset goal) {
    final startTile = nearestWalkable(
      (start.dx / kTileSize).floor(),
      (start.dy / kTileSize).floor(),
    );
    final endTile = nearestWalkable(
      (goal.dx / kTileSize).floor(),
      (goal.dy / kTileSize).floor(),
    );
    if (startTile == null || endTile == null) return const [];
    if (startTile == endTile) return [tileCenter(endTile)];

    final rawTiles = _findTilesAStar(startTile, endTile);
    if (rawTiles.isEmpty) return const [];

    final smoothed = _straighten(rawTiles);
    return smoothed.map(tileCenter).toList();
  }

  List<PointInt> _findTilesAStar(PointInt start, PointInt goal) {
    final open = <PointInt>[start];
    final cameFrom = <PointInt, PointInt>{};
    final gScore = <PointInt, double>{start: 0.0};
    final fScore = <PointInt, double>{start: _heuristic(start, goal)};
    final closed = <PointInt>{};

    const dirs = [
      PointInt(1, 0),
      PointInt(-1, 0),
      PointInt(0, 1),
      PointInt(0, -1),
      PointInt(1, 1),
      PointInt(1, -1),
      PointInt(-1, 1),
      PointInt(-1, -1),
    ];

    var iterations = 0;
    while (open.isNotEmpty && iterations < 800) {
      iterations++;
      open.sort(
          (a, b) => (fScore[a] ?? 999999).compareTo(fScore[b] ?? 999999));
      final current = open.removeAt(0);
      if (current == goal) {
        final path = <PointInt>[current];
        var curr = current;
        while (cameFrom.containsKey(curr)) {
          curr = cameFrom[curr]!;
          if (curr != start) {
            path.insert(0, curr);
          }
        }
        return path;
      }

      closed.add(current);

      for (final d in dirs) {
        final nx = current.x + d.x;
        final ny = current.y + d.y;
        final neighbor = PointInt(nx, ny);
        if (closed.contains(neighbor) || !isWalkableTile(nx, ny)) continue;

        final isDiag = d.x != 0 && d.y != 0;
        if (isDiag) {
          if (!isWalkableTile(current.x + d.x, current.y) ||
              !isWalkableTile(current.x, current.y + d.y)) {
            continue;
          }
        }

        final stepCost = isDiag ? 1.4142 : 1.0;
        final tentativeG = (gScore[current] ?? 999999) + stepCost;
        if (tentativeG < (gScore[neighbor] ?? 999999)) {
          cameFrom[neighbor] = current;
          gScore[neighbor] = tentativeG;
          fScore[neighbor] = tentativeG + _heuristic(neighbor, goal);
          if (!open.contains(neighbor)) {
            open.add(neighbor);
          }
        }
      }
    }
    return const [];
  }

  double _heuristic(PointInt a, PointInt b) {
    final dx = (a.x - b.x).abs().toDouble();
    final dy = (a.y - b.y).abs().toDouble();
    return math.sqrt(dx * dx + dy * dy);
  }

  List<PointInt> _straighten(List<PointInt> path) {
    if (path.length <= 2) return path;
    final out = <PointInt>[path.first];
    var anchor = 0;
    while (anchor < path.length - 1) {
      var furthest = anchor + 1;
      for (var i = path.length - 1; i > anchor + 1; i--) {
        if (_clearLine(path[anchor], path[i])) {
          furthest = i;
          break;
        }
      }
      out.add(path[furthest]);
      anchor = furthest;
    }
    return out;
  }

  bool _clearLine(PointInt a, PointInt b) {
    final dx = b.x - a.x;
    final dy = b.y - a.y;
    final steps = math.max(dx.abs(), dy.abs()) * 2;
    if (steps == 0) return true;
    for (var i = 1; i <= steps; i++) {
      final t = i / steps;
      final cx = (a.x + dx * t).round();
      final cy = (a.y + dy * t).round();
      if (!isWalkableTile(cx, cy)) return false;
    }
    return true;
  }
}

class PointInt {
  final int x;
  final int y;
  const PointInt(this.x, this.y);

  @override
  bool operator ==(Object other) =>
      other is PointInt && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);
}

/// Holds loaded TinyFloor sprite atlases (`floor-items.png`, `floor-sheet.png`, `atlas.json`, NPC & Peer sheets).
class SchoolLobbyAssetBundle {
  final ui.Image floorSheet;
  final ui.Image floorItems;
  final Map<String, Rect> itemFrames;
  final Map<String, ui.Image> npcSheets;

  const SchoolLobbyAssetBundle({
    required this.floorSheet,
    required this.floorItems,
    required this.itemFrames,
    required this.npcSheets,
  });

  static SchoolLobbyAssetBundle? _cached;

  static Future<SchoolLobbyAssetBundle> load() async {
    if (_cached != null) return _cached!;

    final floorSheet = await AvatarSpriteCache.instance
        .loadRawAssetImage('assets/school_lobby/catalog/floor-sheet.png');
    final floorItems = await AvatarSpriteCache.instance
        .loadRawAssetImage('assets/school_lobby/catalog/floor-items.png');

    final atlasRaw =
        await rootBundle.loadString('assets/school_lobby/catalog/atlas.json');
    final atlasJson = jsonDecode(atlasRaw) as Map<String, dynamic>;
    final framesJson =
        (atlasJson['frames'] as Map<String, dynamic>?) ?? const {};
    final parsedFrames = <String, Rect>{};

    framesJson.forEach((key, value) {
      if (value is List && value.length >= 4) {
        parsedFrames[key] = Rect.fromLTWH(
          (value[0] as num).toDouble(),
          (value[1] as num).toDouble(),
          (value[2] as num).toDouble(),
          (value[3] as num).toDouble(),
        );
      }
    });

    final npcSheets = <String, ui.Image>{};
    for (final npc in kLobbyNpcs) {
      npcSheets[npc.id] =
          await AvatarSpriteCache.instance.resolveLookSpriteSheet(
        LobbyAvatarLook(isPreset: true, presetName: npc.presetName),
      );
    }
    for (final peer in kLobbyPeerStudents) {
      npcSheets[peer.id] =
          await AvatarSpriteCache.instance.resolveLookSpriteSheet(
        LobbyAvatarLook(isPreset: true, presetName: peer.presetName),
      );
    }
    for (final mentor in kAiSubjectMentors) {
      npcSheets[mentor.id] =
          await AvatarSpriteCache.instance.resolveLookSpriteSheet(
        LobbyAvatarLook(isPreset: true, presetName: mentor.presetName),
      );
    }

    _cached = SchoolLobbyAssetBundle(
      floorSheet: floorSheet,
      floorItems: floorItems,
      itemFrames: parsedFrames,
      npcSheets: npcSheets,
    );
    return _cached!;
  }
}

/// CustomPainter that renders the 5-Room 2D Pixel Student Campus:
/// - Main School Lobby, Campus Park, Class Room, Student Canteen, and Faculty Room
/// - Interactive Doors (`🚪`), Rest Spots (`🪑 Sit`, `😪 Nap`, `🛌 Sleep`),
/// - Classmate Peer Students with Cloud Thought Bubbles (`💭`),
/// - Subject-Labeled Large Treasure Chests (filtered to enrolled active subjects),
/// - Small Mystery Quiz Chests, and Player Avatar with Rest Poses & Thought Bubbles!
class SchoolLobbyCanvasPainter extends CustomPainter {
  final SchoolLobbyAssetBundle assets;
  final ui.Image? playerSheet;
  final Offset playerPos;
  final AvatarFacing playerFacing;
  final bool playerIsWalking;
  final int animTick;
  final String playerName;
  final bool isFaculty;
  final String? equippedBadgeIcon;
  final double waveBubbleProgress; // 0..1 when waving
  final Offset cameraCenter;
  final double cameraZoom;
  final List<Offset> activePath;
  final Offset? tapPulseTarget;
  final double tapPulseProgress; // 0..1
  final InteractiveZone? highlightedZone;
  final List<SubjectChest> subjectChests;
  final Map<String, int> smallChestRemainingSec;
  final bool isDarkMode;
  final LobbyRoomId currentRoom;
  final PlayerRestState playerRestState;
  final String? playerThoughtText;
  final Map<String, String> activePeerThoughts;
  final List<RemoteLobbyPlayer> remotePlayers;
  final bool showOfflineClassmates;
  final Map<LobbyRoomId, int> roomOccupancyCounts;

  const SchoolLobbyCanvasPainter({
    required this.assets,
    required this.playerSheet,
    required this.playerPos,
    required this.playerFacing,
    required this.playerIsWalking,
    required this.animTick,
    required this.playerName,
    required this.isFaculty,
    required this.equippedBadgeIcon,
    required this.waveBubbleProgress,
    required this.cameraCenter,
    required this.cameraZoom,
    required this.activePath,
    required this.tapPulseTarget,
    required this.tapPulseProgress,
    required this.highlightedZone,
    required this.subjectChests,
    required this.smallChestRemainingSec,
    this.isDarkMode = false,
    this.currentRoom = LobbyRoomId.mainLobby,
    this.playerRestState = PlayerRestState.none,
    this.playerThoughtText,
    this.activePeerThoughts = const {},
    this.remotePlayers = const [],
    this.showOfflineClassmates = false,
    this.roomOccupancyCounts = const {},
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Deep backdrop
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF090E1A),
    );

    canvas.save();
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(cameraZoom);
    canvas.translate(-cameraCenter.dx, -cameraCenter.dy);

    // 2. Render Room Floor & 3/4 Perspective Walls + Doors
    _paintLobbyShell(canvas);

    // 3. Render Floor Rugs (bottom layer)
    final pixelPaint = Paint()..filterQuality = FilterQuality.none;
    final roomPieces = furnitureForRoom(currentRoom);
    for (final piece in roomPieces) {
      if (!piece.isFloorRug) continue;
      _drawFurniturePiece(canvas, piece, pixelPaint);
    }

    // 4. Render Distinct Zone Floor Decals, Doors & Interactive Proximity Rings
    _paintZoneFloorDecals(canvas);

    // 5. Render Tap-to-Walk path breadcrumbs & pulse ring
    _paintNavigationOverlay(canvas);

    // 6. Build Y-sorted renderables (`depthForY(y) = y` from `office.ts`)
    final drawables = <_YSortedDrawable>[];

    // 6a. Furniture pieces (non-rug) — y-sorted by the bottom base of each sprite
    for (final piece in roomPieces) {
      if (piece.isFloorRug) continue;
      final frameRect = assets.itemFrames[piece.spriteKey];
      final frameHeight = frameRect?.height ?? 32.0;
      final pieceSortY =
          piece.y <= 30.0 ? 80.0 : (piece.y + frameHeight - 8.0);
      drawables.add(
        _YSortedDrawable(
          sortY: pieceSortY,
          draw: (c) => _drawFurniturePiece(c, piece, pixelPaint),
        ),
      );
    }

    // 6b. NPCs in this room (walking & interactive via LobbyAgencyAgentsService)
    for (final npc in npcsForRoom(currentRoom)) {
      final agentState =
          LobbyAgencyAgentsService.instance.runtimeStateForId(npc.id);
      final npcSortY = agentState?.currentPos.dy ?? npc.y;
      drawables.add(
        _YSortedDrawable(
          sortY: npcSortY,
          draw: (c) => _drawNpc(c, npc, pixelPaint),
        ),
      );
    }

    // 6c. Live Multiplayer Remote Players in this room (with smooth 60 FPS movement, Sit/Nap/Sleep poses & live Thought Bubbles!)
    for (final rp in remotePlayers) {
      drawables.add(
        _YSortedDrawable(
          // Resting characters sort at +38px so they render ON TOP OF sofa/bench/chair cushions!
          sortY: rp.restState.isResting
              ? rp.currentPos.dy + 38.0
              : rp.currentPos.dy,
          draw: (c) => _drawRemotePlayer(c, rp, pixelPaint),
        ),
      );
    }

    // 6c-2. Optional Offline Practice Classmates (only if explicitly enabled by user)
    if (showOfflineClassmates) {
      for (final peer in peersForRoom(currentRoom)) {
        drawables.add(
          _YSortedDrawable(
            sortY: peer.restState.isResting ? peer.y + 38.0 : peer.y,
            draw: (c) => _drawPeerStudent(c, peer, pixelPaint),
          ),
        );
      }
    }

    // 6d. Subject-Labeled Large Treasure Chests (in Main Lobby)
    if (currentRoom == LobbyRoomId.mainLobby) {
      for (var i = 0; i < subjectChests.length; i++) {
        final chest = subjectChests[i];
        final pos = subjectChestPosition(i);
        final isHighlighted =
            highlightedZone?.id == 'subject_chest_${chest.id}';
        drawables.add(
          _YSortedDrawable(
            sortY: pos.dy,
            draw: (c) => _drawLargeSubjectChest(
              c,
              chest: chest,
              pos: pos,
              isHighlighted: isHighlighted,
            ),
          ),
        );
      }
    }

    // 6d-2. Walking & Talking AI Subject Teachers (`PKLP`, `PPG`, `UCSP`) across ALL 5 rooms!
    final activeZones =
        buildActiveInteractiveZones(subjectChests, room: currentRoom);
    for (final zone in activeZones) {
      if (zone.kind != InteractiveZoneKind.smallMysteryChest) continue;
      final remainingSec = smallChestRemainingSec[zone.id] ?? 0;
      final isHighlighted = highlightedZone?.id == zone.id;
      final agentState =
          LobbyAgencyAgentsService.instance.runtimeStateForId(zone.id);
      final isSitting =
          agentState?.activityState == AgencyAgentActivityState.sitting;
      drawables.add(
        _YSortedDrawable(
          sortY: isSitting ? zone.y + 38.0 : zone.y,
          draw: (c) => _drawSmallMysteryChest(
            c,
            zone: zone,
            remainingCooldownSec: remainingSec,
            isHighlighted: isHighlighted,
          ),
        ),
      );
    }

    // 6e. Player Avatar + Rest Pose (Sit/Nap/Sleep on furniture cushion) + Floating Nameplate + Thought Bubble
    drawables.add(
      _YSortedDrawable(
        sortY: playerRestState.isResting
            ? playerPos.dy + 38.0
            : playerPos.dy,
        draw: (c) => _drawPlayer(c, pixelPaint),
      ),
    );

    drawables.sort((a, b) => a.sortY.compareTo(b.sortY));
    for (final item in drawables) {
      item.draw(canvas);
    }

    canvas.restore();
  }

  /// Resolves a 1-based tile ID from TinyFloor's `floor-sheet.png` (`512x640` px, 16 columns of `32x32` tiles)
  /// as defined in `_reference_tinyfloor/shared-protocol/src/shell.ts`.
  Rect _floorSheetTileRect(int oneBasedTile) {
    final idx = (oneBasedTile - 1).clamp(0, 319);
    final col = idx % 16;
    final row = idx ~/ 16;
    return Rect.fromLTWH(col * kTileSize, row * kTileSize, kTileSize, kTileSize);
  }

  void _paintLobbyShell(Canvas canvas) {
    final pixelPaint = Paint()..filterQuality = FilterQuality.none;

    // Outer drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(
            -12, -8, kLobbyWorldWidth + 24, kLobbyWorldHeight + 24),
        const Radius.circular(16),
      ),
      Paint()..color = Colors.black.withOpacity(0.65),
    );

    // 1. Tile the entire room floor directly from `assets.floorSheet` (`floor-sheet.png`)
    // using TinyFloor's exact `FLOORS`, `MORE_FLOORS`, and `GROUNDS` tile coordinates (`shell.ts`)!
    for (var r = 2; r < kLobbyRows; r++) {
      for (var c = 0; c < kLobbyCols; c++) {
        final dst =
            Rect.fromLTWH(c * kTileSize, r * kTileSize, kTileSize, kTileSize);
        int tileId;
        switch (currentRoom) {
          case LobbyRoomId.park:
            // TinyFloor `GROUND_TILES.grass`: row 18, 8 seamless grass variations
            final grassVar = ((r * 7 + c * 13 + (r * c)) & 0x7fffffff) % 8;
            tileId = 18 * 16 + grassVar + 1;
            break;
          case LobbyRoomId.classroom:
            // Front Lecture Stage (`r: 3..7, c: 8..39`) uses `oak` (`242`), main floor uses `plank` (`108` / `92` shadow)
            if (r >= 3 && r <= 7 && c >= 8 && c <= 39) {
              tileId = 242; // `oak`
            } else {
              tileId = r == 2 ? 92 : 108; // `plank` with top wall shadow
            }
            break;
          case LobbyRoomId.canteen:
            // Canteen uses checkered `tile` (`172` / `156` shadow) & warm `rose` (`282`) in dining zones
            tileId = r == 2 ? 156 : 172;
            break;
          case LobbyRoomId.facultyRoom:
            // Faculty Room uses warm `oak` (`242`) with `mauve` (`207`) executive center carpet
            if (r >= 8 && r <= 18 && c >= 10 && c <= 37) {
              tileId = 207;
            } else {
              tileId = r == 2 ? 95 : 242;
            }
            break;
          case LobbyRoomId.mainLobby:
            // Main Lobby uses warm `plank-light` (`111` / `95` shadow) and `cream` (`246`)
            tileId = r == 2 ? 95 : 111;
            break;
        }
        canvas.drawImageRect(
          assets.floorSheet,
          _floorSheetTileRect(tileId),
          dst,
          pixelPaint,
        );
      }
    }

    // Subtle dark-mode night tint over the floor tiles while preserving pixel texture
    if (isDarkMode) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 64, kLobbyWorldWidth, kLobbyWorldHeight - 64),
        Paint()..color = const Color(0xFF090E1A).withOpacity(0.46),
      );
    }

    // 2. Room-specific architectural zones (Sanctuary border, Park Koi Pond, Classroom Stage trim)
    if (currentRoom == LobbyRoomId.mainLobby) {
      // Bulletin Board Reading Wing tint
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(44, 92, 460, 172),
          const Radius.circular(10),
        ),
        Paint()
          ..color =
              const Color(0xFF38BDF8).withOpacity(isDarkMode ? 0.14 : 0.10),
      );

      // Reviewer Treasure Corner Sanctuary Floor (Expanded Bottom-Right Wing)
      final sanctuaryRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(880, 460, 580, 560),
        const Radius.circular(14),
      );
      canvas.drawRRect(
        sanctuaryRect,
        Paint()
          ..color =
              const Color(0xFF3B1D5E).withOpacity(isDarkMode ? 0.34 : 0.18),
      );
      canvas.drawRRect(
        sanctuaryRect,
        Paint()
          ..color = const Color(0xFFF59E0B).withOpacity(0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    } else if (currentRoom == LobbyRoomId.park) {
      // Sparkling Central Park Koi Pond (`x: 640..896, y: 420..600`)
      final pondRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(640, 420, 256, 180),
        const Radius.circular(36),
      );
      canvas.drawRRect(
        pondRect.inflate(8),
        Paint()..color = const Color(0xFF78716C),
      );
      canvas.drawRRect(
        pondRect,
        Paint()
          ..color =
              isDarkMode ? const Color(0xFF0369A1) : const Color(0xFF0EA5E9),
      );
      // Lily pads & animated water ripples
      final ripple = 2.0 * math.sin(animTick * 0.35);
      canvas.drawCircle(
        const Offset(710, 485),
        14,
        Paint()..color = const Color(0xFF22C55E),
      );
      canvas.drawCircle(
        const Offset(820, 540),
        12,
        Paint()..color = const Color(0xFF16A34A),
      );
      canvas.drawCircle(
        const Offset(768, 510),
        22 + ripple,
        Paint()
          ..color = Colors.white.withOpacity(0.28)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6,
      );
    } else if (currentRoom == LobbyRoomId.classroom) {
      // Elevated Front Wooden Teaching Stage border
      final stageRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(256, 96, 1024, 152),
        const Radius.circular(10),
      );
      canvas.drawRRect(
        stageRect,
        Paint()
          ..color = const Color(0xFFF59E0B).withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
    }

    // 3. Render Guided Walk Paths (`walkPathsForRoom(currentRoom)`) with `floor-sheet.png` tiles + directional arrows!
    _paintGuidedWalkPaths(canvas, pixelPaint);

    // 4. Night / Dark Mode warm ambient light pools
    if (isDarkMode) {
      final glowCenters = <Offset>[
        const Offset(768, 220),
        const Offset(420, 620),
        const Offset(1140, 620),
        playerPos,
      ];
      for (final center in glowCenters) {
        final radius = center == playerPos ? 140.0 : 220.0;
        final shader = ui.Gradient.radial(
          center,
          radius,
          [
            const Color(0xFFFBBF24).withOpacity(0.16),
            const Color(0xFFF59E0B).withOpacity(0.05),
            Colors.transparent,
          ],
          const [0.0, 0.55, 1.0],
        );
        canvas.drawCircle(center, radius, Paint()..shader = shader);
      }
    }

    // 5. Render 3/4-Perspective Top Wall (`WALL_HEIGHT = 82`) using TinyFloor `WALLS` tiles from `floor-sheet.png`
    int wallUpperTile = 178; // `lavender` upper
    int wallLowerTile = 194; // `lavender` lower
    if (currentRoom == LobbyRoomId.canteen) {
      wallUpperTile = 146; // `brick` upper
      wallLowerTile = 162; // `brick` lower
    } else if (currentRoom == LobbyRoomId.facultyRoom) {
      wallUpperTile = 114; // `grey` upper
      wallLowerTile = 130; // `grey` lower
    } else if (currentRoom == LobbyRoomId.classroom) {
      wallUpperTile = 82; // `lavender-pattern` upper
      wallLowerTile = 98; // `lavender-pattern` lower
    }

    if (currentRoom == LobbyRoomId.park) {
      canvas.drawRect(
        const Rect.fromLTWH(0, 14, kLobbyWorldWidth, 68),
        Paint()
          ..color =
              isDarkMode ? const Color(0xFF143325) : const Color(0xFF3F6212),
      );
    } else {
      for (var c = 1; c < kLobbyCols - 1; c++) {
        canvas.drawImageRect(
          assets.floorSheet,
          _floorSheetTileRect(wallUpperTile),
          Rect.fromLTWH(c * kTileSize, 14, kTileSize, kTileSize),
          pixelPaint,
        );
        canvas.drawImageRect(
          assets.floorSheet,
          _floorSheetTileRect(wallLowerTile),
          Rect.fromLTWH(c * kTileSize, 46, kTileSize, kTileSize),
          pixelPaint,
        );
      }
      if (isDarkMode) {
        canvas.drawRect(
          const Rect.fromLTWH(0, 14, kLobbyWorldWidth, 68),
          Paint()..color = const Color(0xFF0F172A).withOpacity(0.42),
        );
      }
    }

    // Classroom Giant Green Chalkboard on Top Wall (center stage behind Teacher Podium)
    if (currentRoom == LobbyRoomId.classroom) {
      final boardRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(512, 18, 512, 52),
        const Radius.circular(4),
      );
      canvas.drawRRect(
          boardRect.inflate(3), Paint()..color = const Color(0xFF78350F));
      canvas.drawRRect(boardRect, Paint()..color = const Color(0xFF064E3B));
      // Chalk tray & chalk lines
      canvas.drawRect(
        const Rect.fromLTWH(524, 66, 488, 4),
        Paint()..color = const Color(0xFFD97706),
      );
      final chalkTp = TextPainter(
        text: const TextSpan(
          text: '📚 MIS-SHS CLASSROOM • CHECK SUBJECT CHESTS & QUEST LINKS',
          style: TextStyle(
            color: Color(0xFFE2E8F0),
            fontSize: 9.5,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      chalkTp.paint(
        canvas,
        Offset(768 - chalkTp.width / 2, 42 - chalkTp.height / 2),
      );
    }

    canvas.drawRect(
      const Rect.fromLTWH(0, 74, kLobbyWorldWidth, 8),
      Paint()
        ..color =
            isDarkMode ? const Color(0xFF334155) : const Color(0xFF9C8468),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 82, kLobbyWorldWidth, 10),
      Paint()..color = Colors.black.withOpacity(isDarkMode ? 0.35 : 0.14),
    );

    // Perimeter dark architectural wall caps (`#3a3a50` from `shell.ts`) clamped to compact `currentRoom.roomBounds`
    final bounds = currentRoom.roomBounds;
    final voidMaskPaint = Paint()..color = const Color(0xFF090E1A);
    // Mask exterior dead space outside compact room bounds
    if (bounds.left > 0) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, bounds.left, kLobbyWorldHeight),
        voidMaskPaint,
      );
    }
    if (bounds.right < kLobbyWorldWidth) {
      canvas.drawRect(
        Rect.fromLTWH(
            bounds.right, 0, kLobbyWorldWidth - bounds.right, kLobbyWorldHeight),
        voidMaskPaint,
      );
    }
    if (bounds.bottom < kLobbyWorldHeight) {
      canvas.drawRect(
        Rect.fromLTWH(
            0, bounds.bottom, kLobbyWorldWidth, kLobbyWorldHeight - bounds.bottom),
        voidMaskPaint,
      );
    }

    final wallCapPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF3A3A50);
    canvas.drawRect(
      Rect.fromLTWH(bounds.left - 16, 0, bounds.width + 32, 16),
      wallCapPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(bounds.left - 24, 0, 24, bounds.bottom + 24),
      wallCapPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(bounds.right, 0, 24, bounds.bottom + 24),
      wallCapPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(bounds.left - 24, bounds.bottom, bounds.width + 48, 24),
      wallCapPaint,
    );
  }

  /// Renders Pokémon-inspired Walk Paths (`LobbyWalkPathSegment`) across each room:
  /// - Outdoor (`park`): Pokémon Route sandy cobblestone trails (`#E7CBA9`) with rounded stepping stones
  ///   and pixel grass-tuft borders (`#3F6212` / `#65A30D`).
  /// - Indoor (`mainLobby`, `classroom`, `canteen`, `facultyRoom`): Pokémon Center / PokéMart woven runner
  ///   carpets with double-stitched pixel gold/cream trim (`#FDE68A` / `#78350F`) and woven diamond emblems.
  void _paintGuidedWalkPaths(Canvas canvas, Paint pixelPaint) {
    final segments = walkPathsForRoom(currentRoom);
    for (final seg in segments) {
      final r = seg.rect;
      final isOutdoor = currentRoom == LobbyRoomId.park || seg.style == 'paving';

      final cStart = (r.left / kTileSize).floor();
      final cEnd = (r.right / kTileSize).ceil();
      final rStart = (r.top / kTileSize).floor();
      final rEnd = (r.bottom / kTileSize).ceil();

      canvas.save();
      canvas.clipRRect(RRect.fromRectAndRadius(r, const Radius.circular(6)));

      for (var row = rStart; row < rEnd; row++) {
        for (var col = cStart; col < cEnd; col++) {
          final dst = Rect.fromLTWH(
              col * kTileSize, row * kTileSize, kTileSize, kTileSize);
          int tileId;
          switch (seg.style) {
            case 'paving':
              tileId = (18 + (row % 2)) * 16 + 8 + (col % 4) + 1;
              break;
            case 'carpet_gold':
              tileId = 204; // warm crimson Pokémon Center runner
              break;
            case 'carpet_royal':
              tileId = 207; // royal mauve runner
              break;
            case 'carpet_blue':
              tileId = 140; // slate runner
              break;
            case 'checker':
              tileId = 175; // olive checker runner
              break;
            case 'wood_aisle':
            default:
              tileId = 242; // warm oak aisle
              break;
          }
          canvas.drawImageRect(
            assets.floorSheet,
            _floorSheetTileRect(tileId),
            dst,
            pixelPaint,
          );
        }
      }

      if (isOutdoor) {
        // Pokémon FireRed/Emerald sandy route tint + pixel stepping stones
        canvas.drawRect(
          r,
          Paint()
            ..color = const Color(0xFFE7CBA9)
                .withValues(alpha: isDarkMode ? 0.22 : 0.34),
        );
        final stoneFill = Paint()
          ..color = const Color(0xFFD6B48A)
              .withValues(alpha: isDarkMode ? 0.45 : 0.65);
        final stoneRim = Paint()
          ..color = const Color(0xFF8C6D46)
              .withValues(alpha: isDarkMode ? 0.55 : 0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2;

        for (var y = r.top + 14; y < r.bottom - 10; y += 28) {
          for (var x = r.left + 16; x < r.right - 12; x += 32) {
            final jitterX = (((x.toInt() * 7 + y.toInt() * 13) % 7) - 3).toDouble();
            final jitterY = (((x.toInt() * 11 + y.toInt() * 5) % 5) - 2).toDouble();
            final stoneRect = RRect.fromRectAndRadius(
              Rect.fromCenter(
                center: Offset(x + jitterX, y + jitterY),
                width: 16,
                height: 10,
              ),
              const Radius.circular(4),
            );
            canvas.drawRRect(stoneRect, stoneFill);
            canvas.drawRRect(stoneRect, stoneRim);
          }
        }
      } else {
        // Subtle woven indoor carpet texture lines (every 8px)
        final weavePaint = Paint()
          ..color = Colors.black.withValues(alpha: 0.08)
          ..strokeWidth = 1.0;
        for (var y = r.top + 4; y < r.bottom; y += 8) {
          canvas.drawLine(Offset(r.left, y), Offset(r.right, y), weavePaint);
        }

        // Woven Pokémon Center diamond pattern along the center of the runner
        final isVertical = r.height > r.width;
        final length = isVertical ? r.height : r.width;
        final steps = (length / 64.0).floor().clamp(1, 16);
        final diamondFill = Paint()
          ..color = const Color(0xFFFDE68A).withValues(alpha: 0.38);
        final diamondStroke = Paint()
          ..color = const Color(0xFF78350F).withValues(alpha: 0.45)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0;
        for (var i = 1; i <= steps; i++) {
          final frac = i / (steps + 1);
          final center = isVertical
              ? Offset(r.center.dx, r.top + r.height * frac)
              : Offset(r.left + r.width * frac, r.center.dy);
          final path = Path()
            ..moveTo(center.dx, center.dy - 6)
            ..lineTo(center.dx + 6, center.dy)
            ..lineTo(center.dx, center.dy + 6)
            ..lineTo(center.dx - 6, center.dy)
            ..close();
          canvas.drawPath(path, diamondFill);
          canvas.drawPath(path, diamondStroke);
        }
      }
      canvas.restore();

      if (isOutdoor) {
        // Pokémon grass-tuft & pebble edging along path perimeter
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(6)),
          Paint()
            ..color = const Color(0xFF3F6212)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r.deflate(2.2), const Radius.circular(5)),
          Paint()
            ..color = const Color(0xFFA16207).withValues(alpha: 0.70)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.4,
        );
      } else {
        // Double-stitched pixel cream/gold carpet trim
        canvas.drawRRect(
          RRect.fromRectAndRadius(r, const Radius.circular(4)),
          Paint()
            ..color = const Color(0xFF78350F)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.6,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(r.deflate(2.2), const Radius.circular(3)),
          Paint()
            ..color = const Color(0xFFFDE68A).withValues(alpha: 0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6,
        );
      }
    }
  }

  void _paintZoneFloorDecals(Canvas canvas) {
    // 0. If in Classroom, render the student's Personal Table Space Decor & Desk Ownership Tags!
    if (currentRoom == LobbyRoomId.classroom) {
      _paintPersonalClassroomTableDecor(canvas);
    }

    // 1. Render all room directional signposts (`floorSignpostsForRoom(currentRoom)`)
    for (final post in floorSignpostsForRoom(currentRoom)) {
      _drawFloorPlaque(
        canvas,
        text: post.text,
        center: post.center,
        color: Color(post.colorValue),
      );
    }

    // 2. Render glowing Campus Door Portals (`🚪`), Group Study Spaces (`📚💬`) & interactive Rest Spot indicators
    final allZones =
        buildActiveInteractiveZones(subjectChests, room: currentRoom);
    for (final z in allZones) {
      if (z.kind == InteractiveZoneKind.doorPortal) {
        _drawDoorPortal(
          canvas,
          zone: z,
          isHighlighted: highlightedZone?.id == z.id,
        );
      } else if (z.kind == InteractiveZoneKind.restSpot) {
        _drawRestSpotIndicator(
          canvas,
          zone: z,
          isHighlighted: highlightedZone?.id == z.id,
        );
      } else if (z.kind == InteractiveZoneKind.vendingMachine ||
          z.kind == InteractiveZoneKind.classroomPodium ||
          z.kind == InteractiveZoneKind.campusShop ||
          z.kind == InteractiveZoneKind.radioBase ||
          z.kind == InteractiveZoneKind.studentLounge) {
        _drawSpecialStationIndicator(
          canvas,
          zone: z,
          isHighlighted: highlightedZone?.id == z.id,
        );
      }
    }

    // 3. Draw interactive highlight ring around the currently active zone
    if (highlightedZone != null) {
      final z = highlightedZone!;
      final pulse = 0.5 + 0.5 * math.sin(animTick * 0.35);
      final ringColor = Color(z.accentColor);
      canvas.drawCircle(
        z.center,
        z.radius * (0.94 + 0.06 * pulse),
        Paint()
          ..color = ringColor.withOpacity(0.14 + 0.08 * pulse)
          ..style = PaintingStyle.fill,
      );
      canvas.drawCircle(
        z.center,
        z.radius * (0.94 + 0.06 * pulse),
        Paint()
          ..color = ringColor.withOpacity(0.75)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    }
  }

  /// Renders the local student's custom Table Space decorations (`LobbyTableDecorConfig`)
  /// on their Personal Classroom Table (`x: 480, y: 324`, chair `x: 544, y: 404`), plus
  /// ownership plaques so every student knows which table is theirs!
  void _paintPersonalClassroomTableDecor(Canvas canvas) {
    final decor = LobbyDataService.instance.progress.tableDecor;
    const deskRect = Rect.fromLTWH(488, 326, 112, 46);
    const chairCenter = Offset(544, 404);

    // 1. Custom Chair Cushion tint around the personal chair (`decor.chairPrimaryColor`)
    final chairColor = decor.chairPrimaryColor;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: chairCenter, width: 34, height: 26),
        const Radius.circular(7),
      ),
      Paint()..color = chairColor.withValues(alpha: 0.78),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: chairCenter, width: 34, height: 26),
        const Radius.circular(7),
      ),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // 2. Desk Mat overlay on top of the student's personal desk (`decor.deskMatColor`)
    final matColor = decor.deskMatColor;
    if (matColor != null) {
      final matRect = RRect.fromRectAndRadius(
        Rect.fromCenter(center: deskRect.center, width: 90, height: 34),
        const Radius.circular(5),
      );
      canvas.drawRRect(
        matRect,
        Paint()..color = matColor.withValues(alpha: 0.80),
      );
      canvas.drawRRect(
        matRect,
        Paint()
          ..color = Colors.white.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }

    // 3. Mini Light (`fairy_warm`, `banker_brass`, `neon_strip`, `starlight_lantern`)
    if (decor.miniLight != 'none') {
      Color lightColor = const Color(0xFFFBBF24);
      String lightIcon = '🪔';
      if (decor.miniLight == 'fairy_warm') {
        lightColor = const Color(0xFFFDE047);
        lightIcon = '✨';
      } else if (decor.miniLight == 'neon_strip') {
        lightColor = const Color(0xFF06B6D4);
        lightIcon = '🌈';
      } else if (decor.miniLight == 'starlight_lantern') {
        lightColor = const Color(0xFFC084FC);
        lightIcon = '🏮';
      }
      final lampPos = Offset(deskRect.left + 18, deskRect.top + 15);
      final glowShader = ui.Gradient.radial(
        lampPos,
        38,
        [
          lightColor.withValues(alpha: 0.50),
          lightColor.withValues(alpha: 0.0),
        ],
      );
      canvas.drawCircle(lampPos, 38, Paint()..shader = glowShader);
      final tp = TextPainter(
        text: TextSpan(text: lightIcon, style: const TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(lampPos.dx - tp.width / 2, lampPos.dy - tp.height / 2));
    }

    // 4. Desk Frame (`gold_cert`, `pixel_portrait`, `holo_plaque`)
    if (decor.deskFrame != 'none') {
      String frameIcon = '🖼️';
      if (decor.deskFrame == 'gold_cert') frameIcon = '🏆';
      if (decor.deskFrame == 'holo_plaque') frameIcon = '💠';
      final framePos = Offset(deskRect.center.dx, deskRect.top + 13);
      final tp = TextPainter(
        text: TextSpan(text: frameIcon, style: const TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(
          canvas, Offset(framePos.dx - tp.width / 2, framePos.dy - tp.height / 2));
    }

    // 5. Table Prop (`textbooks_stack`, `zen_bonsai`, `gaming_laptop`, `trophy_mug`)
    if (decor.deskProp != 'none') {
      String propIcon = '📚';
      if (decor.deskProp == 'zen_bonsai') propIcon = '🪴';
      if (decor.deskProp == 'gaming_laptop') propIcon = '💻';
      if (decor.deskProp == 'trophy_mug') propIcon = '☕';
      final propPos = Offset(deskRect.right - 18, deskRect.top + 15);
      final tp = TextPainter(
        text: TextSpan(text: propIcon, style: const TextStyle(fontSize: 12)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(propPos.dx - tp.width / 2, propPos.dy - tp.height / 2));
    }

    // 6. Floating Ownership Badge above the player's Personal Classroom Table
    final ownerLabel = playerName.trim().isEmpty
        ? '📌 Your Personal Table'
        : '📌 ${playerName.split(' ').first}\'s Table';
    final tp = TextPainter(
      text: TextSpan(
        text: ownerLabel,
        style: const TextStyle(
          color: Color(0xFFFEF08A),
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final badgeRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(deskRect.center.dx, deskRect.top - 10),
        width: tp.width + 12,
        height: tp.height + 5,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.90),
    );
    canvas.drawRRect(
      badgeRect,
      Paint()
        ..color = const Color(0xFFF59E0B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    tp.paint(
      canvas,
      Offset(
        badgeRect.center.dx - tp.width / 2,
        badgeRect.center.dy - tp.height / 2,
      ),
    );
  }

  void _drawSpecialStationIndicator(
    Canvas canvas, {
    required InteractiveZone zone,
    required bool isHighlighted,
  }) {
    final pos = zone.center;
    final col = Color(zone.accentColor);
    final tp = TextPainter(
      text: TextSpan(
        text: zone.label,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy - 24),
        width: tp.width + 14,
        height: tp.height + 6,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pill,
      Paint()
        ..color = const Color(0xFF0F172A)
            .withOpacity(isHighlighted ? 0.96 : 0.84),
    );
    canvas.drawRRect(
      pill,
      Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.0 : 1.3,
    );
    tp.paint(
      canvas,
      Offset(pos.dx - tp.width / 2, pos.dy - 24 - tp.height / 2),
    );
  }

  /// Renders a glowing pixel Doorway / Portal (`🚪`) that students can walk up to and enter!
  void _drawDoorPortal(
    Canvas canvas, {
    required InteractiveZone zone,
    required bool isHighlighted,
  }) {
    final pos = zone.center;
    final doorColor = Color(zone.accentColor);
    final pulse = 0.5 + 0.5 * math.sin(animTick * 0.3);

    // Welcome mat / portal threshold
    final matRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: 78, height: 42),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      matRect,
      Paint()..color = const Color(0xFF0F172A).withOpacity(0.88),
    );
    canvas.drawRRect(
      matRect,
      Paint()
        ..color =
            doorColor.withOpacity(isHighlighted ? 0.98 : (0.65 + 0.25 * pulse))
        ..style = PaintingStyle.stroke
        ..strokeWidth = isHighlighted ? 2.8 : 2.0,
    );

    // Inner timber door arch
    final innerArch = RRect.fromRectAndRadius(
      Rect.fromCenter(center: pos, width: 64, height: 30),
      const Radius.circular(5),
    );
    canvas.drawRRect(
      innerArch,
      Paint()
        ..color = Color.lerp(const Color(0xFF78350F), doorColor, 0.32)!,
    );

    // Floating Door Banner overhead (with live Room Occupancy badge if peers are inside!)
    final targetOcc =
        zone.targetRoom != null ? (roomOccupancyCounts[zone.targetRoom!] ?? 0) : 0;
    final occSuffix = targetOcc > 0 ? ' • 🟢 $targetOcc Inside' : '';
    final tp = TextPainter(
      text: TextSpan(
        text: '🚪 ${zone.label}$occSuffix',
        style: const TextStyle(
          color: Colors.white,
          fontSize: 9.0,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.4,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final pillCenter = Offset(pos.dx, pos.dy - 30);
    final pillRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: pillCenter,
        width: tp.width + 14,
        height: tp.height + 6,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(
      pillRect,
      Paint()..color = const Color(0xFF0F172A).withOpacity(0.92),
    );
    canvas.drawRRect(
      pillRect,
      Paint()
        ..color = doorColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    tp.paint(
      canvas,
      Offset(pillCenter.dx - tp.width / 2, pillCenter.dy - tp.height / 2),
    );
  }

  /// Subtle seat cushion marker for interactive Rest Spots (`🪑 Sit / 😪 Nap / 🛌 Sleep`).
  void _drawRestSpotIndicator(
    Canvas canvas, {
    required InteractiveZone zone,
    required bool isHighlighted,
  }) {
    if (!isHighlighted) return;
    final pos = zone.center;
    final tp = TextPainter(
      text: const TextSpan(
        text: '🪑 Sit • 😪 Nap • 🛌 Sleep',
        style: TextStyle(
          color: Colors.white,
          fontSize: 8.2,
          fontWeight: FontWeight.w800,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    final pill = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy - 26),
        width: tp.width + 12,
        height: tp.height + 5,
      ),
      const Radius.circular(99),
    );
    canvas.drawRRect(
      pill,
      Paint()..color = const Color(0xFF065F46).withOpacity(0.92),
    );
    tp.paint(
      canvas,
      Offset(pos.dx - tp.width / 2, pos.dy - 26 - tp.height / 2),
    );
  }

  void _drawFloorPlaque(
    Canvas canvas, {
    required String text,
    required Offset center,
    required Color color,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 8.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final rect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: center,
        width: tp.width + 14,
        height: tp.height + 6,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(
      rect,
      Paint()..color = const Color(0xFF0F172A).withOpacity(0.84),
    );
    canvas.drawRRect(
      rect,
      Paint()
        ..color = color.withOpacity(0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  /// Renders the Golden Guided Breadcrumb Trail (`activePath`) + Tap-to-Walk pulse ring!
  void _paintNavigationOverlay(Canvas canvas) {
    if (activePath.isNotEmpty) {
      final points = <Offset>[playerPos, ...activePath];
      final linePaint = Paint()
        ..color = const Color(0xFFFACC15).withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round;

      for (var i = 0; i < points.length - 1; i++) {
        canvas.drawLine(points[i], points[i + 1], linePaint);
      }

      final dotPaint = Paint()
        ..color = const Color(0xFFFEF08A)
        ..style = PaintingStyle.fill;
      for (final wp in activePath) {
        canvas.drawCircle(wp, 4.5, dotPaint);
        canvas.drawCircle(
          wp,
          4.5,
          Paint()
            ..color = const Color(0xFFD97706)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }

      // Pulsing destination beacon at `activePath.last`
      final goal = activePath.last;
      final pulse = 0.5 + 0.5 * math.sin(animTick * 0.4);
      canvas.drawCircle(
        goal,
        12.0 + 5.0 * pulse,
        Paint()
          ..color = const Color(0xFFFACC15).withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }

    if (tapPulseTarget != null && tapPulseProgress < 1.0) {
      final radius = 8.0 + 16.0 * tapPulseProgress;
      final alpha = (1.0 - tapPulseProgress).clamp(0.0, 1.0);
      canvas.drawCircle(
        tapPulseTarget!,
        radius,
        Paint()
          ..color = const Color(0xFFFACC15).withOpacity(0.85 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4,
      );
    }
  }

  void _drawFurniturePiece(
    Canvas canvas,
    LobbyFurniturePiece piece,
    Paint pixelPaint,
  ) {
    final src = assets.itemFrames[piece.spriteKey];
    if (src == null) return;
    final dst = Rect.fromLTWH(piece.x, piece.y, src.width, src.height);
    canvas.drawImageRect(assets.floorItems, src, dst, pixelPaint);
  }

  void _drawNpc(Canvas canvas, LobbyNpc npc, Paint pixelPaint) {
    final sheet = assets.npcSheets[npc.id];
    final agentState =
        LobbyAgencyAgentsService.instance.runtimeStateForId(npc.id);
    final pos = agentState?.currentPos ?? Offset(npc.x, npc.y);
    final facing = agentState?.facing ?? npc.facing;
    final isWalking = agentState?.isWalking ?? false;

    _drawCharacterWithRestState(
      canvas,
      sheet: sheet,
      pos: pos,
      facing: facing,
      isWalking: isWalking,
      restState: PlayerRestState.none,
      pixelPaint: pixelPaint,
    );

    final statusSuffix = agentState != null &&
            agentState.activityState ==
                AgencyAgentActivityState.conversingWithPlayer
        ? '${npc.roleTag} 💬'
        : npc.roleTag;

    _drawFloatingNameplate(
      canvas,
      anchor: Offset(pos.dx, pos.dy - 54),
      name: npc.name,
      roleTag: statusSuffix,
      isGoldTag: npc.isGoldTag,
      badgeIcon: npc.id == 'npc_receptionist'
          ? '✨'
          : (npc.isGoldTag ? '🎓' : '📚'),
    );

    if (agentState != null && agentState.isWaving) {
      final waveTp = TextPainter(
        text: const TextSpan(
          text: '👋',
          style: TextStyle(fontSize: 15),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      waveTp.paint(canvas, Offset(pos.dx + 16, pos.dy - 48));
    }

    if (agentState != null &&
        agentState.activeBubbleText.isNotEmpty &&
        (playerPos - pos).distance <= 230.0) {
      _drawCloudThoughtBubble(
        canvas,
        anchor: Offset(pos.dx, pos.dy - 76),
        text: agentState.activeBubbleText,
        isHighlighted: agentState.activityState ==
            AgencyAgentActivityState.conversingWithPlayer,
      );
    }
  }

  /// Renders a Classmate Peer Student with their Sit/Nap/Sleep pose and Cloud Thought Bubble (`💭`)!
  void _drawPeerStudent(
    Canvas canvas,
    LobbyPeerStudent peer,
    Paint pixelPaint,
  ) {
    final sheet = assets.npcSheets[peer.id];
    final pos = peer.position;

    _drawCharacterWithRestState(
      canvas,
      sheet: sheet,
      pos: pos,
      facing: peer.facing,
      isWalking: false,
      restState: peer.restState,
      pixelPaint: pixelPaint,
    );

    final statusSuffix = peer.restState.isResting
        ? '${peer.restState.emoji} ${peer.restState.label}'
        : peer.roleTag;

    _drawFloatingNameplate(
      canvas,
      anchor: Offset(pos.dx, pos.dy - 54),
      name: peer.name,
      roleTag: statusSuffix,
      isGoldTag: false,
      badgeIcon: '💭',
    );

    // Show Cloud Thought Bubble when player is within 210px or when a custom reply is active
    final customReply = activePeerThoughts[peer.id];
    final distToPlayer = (playerPos - pos).distance;
    if (customReply != null || distToPlayer <= 210.0) {
      final bubbleText = customReply ?? peer.defaultThought;
      _drawCloudThoughtBubble(
        canvas,
        anchor: Offset(pos.dx, pos.dy - 76),
        text: bubbleText,
        isHighlighted: highlightedZone?.peerStudentId == peer.id,
      );
    }
  }

  /// Renders a Live Multiplayer Remote Player (`RemoteLobbyPlayer`) with smooth 60 FPS interpolated
  /// position, custom avatar sprite sheet, Sit/Nap/Sleep pose, Wave emote, and live Thought Bubble!
  void _drawRemotePlayer(
    Canvas canvas,
    RemoteLobbyPlayer rp,
    Paint pixelPaint,
  ) {
    final pos = rp.currentPos;
    final sheet = rp.spriteSheet ?? assets.npcSheets['npc_receptionist'];

    // Live online aura ring beneath the remote player's feet
    final pulse = 0.5 + 0.5 * math.sin(animTick * 0.35);
    final ringColor =
        rp.isFaculty ? const Color(0xFFFACC15) : const Color(0xFF10B981);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy + 4),
        width: 30 + 4 * pulse,
        height: 12 + 2 * pulse,
      ),
      Paint()
        ..color = ringColor.withOpacity(0.28 + 0.14 * pulse)
        ..style = PaintingStyle.fill,
    );

    _drawCharacterWithRestState(
      canvas,
      sheet: sheet,
      pos: pos,
      facing: rp.facing,
      isWalking: rp.isWalking,
      restState: rp.restState,
      pixelPaint: pixelPaint,
    );

    final roleTag = rp.isFaculty
        ? (rp.restState.isResting
            ? 'TEACHER • ${rp.restState.emoji}'
            : 'TEACHER 🟢')
        : (rp.restState.isResting
            ? '${rp.restState.emoji} ${rp.restState.label}'
            : 'ONLINE 🟢');

    _drawFloatingNameplate(
      canvas,
      anchor: Offset(pos.dx, pos.dy - 54),
      name: rp.nickname,
      roleTag: roleTag,
      isGoldTag: rp.isFaculty,
      badgeIcon: rp.equippedBadgeIcon ?? (rp.isFaculty ? '👑' : '🟢'),
    );

    if (rp.isWaving) {
      final waveTp = TextPainter(
        text: const TextSpan(
          text: '👋',
          style: TextStyle(fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      waveTp.paint(
        canvas,
        Offset(pos.dx + 16, pos.dy - 46),
      );
    }

    if (rp.hasActiveThought) {
      _drawCloudThoughtBubble(
        canvas,
        anchor: Offset(pos.dx, pos.dy - 76),
        text: rp.thoughtText!,
        isHighlighted: highlightedZone?.peerStudentId == rp.userId,
      );
    }
  }

  /// Shared character sprite + rest pose renderer calibrated to the exact `32x64` pixel anatomy
  /// (`y = 0..17` transparent headroom, `y = 18..45` head/face, `y = 46..55` torso/arms,
  /// `y = 56..59` hips/upper legs, `y = 60..63` shoes/feet):
  /// - **Sitting (`PlayerRestState.sitting`)**: Draws intact head + torso + hips (`src(fx, 0, 32, 56)`)
  ///   with foreshortened pixel-art shoes (`src(fx, 60, 32, 4)`) directly below on the seat cushion,
  ///   or overlays the `chair-tan-back` backrest from `floor-items.png` when facing `up` at a desk!
  /// - **Napping (`PlayerRestState.napping`)**: Same 2-slice seated posture + gentle `2px` breathing nod
  ///   + skin-tone adaptive pixel-art closed eyelids (`src(fx + 14, 38, 2, 2)` + `4x2` eyelashes).
  /// - **Sleeping (`PlayerRestState.sleeping`)**: Draws a `2x2`-grid pixel pillow on the left sofa/bench
  ///   cushion, rotates ONLY the head (`src(fx, 18, 32, 28)`) `-90°` onto the pillow with closed eyes,
  ///   and tucks the body under a `2x2`-grid pixel quilted blanket starting right at the chin!
  void _drawCharacterWithRestState(
    Canvas canvas, {
    required ui.Image? sheet,
    required Offset pos,
    required AvatarFacing facing,
    required bool isWalking,
    required PlayerRestState restState,
    required Paint pixelPaint,
  }) {
    // Shadow: on the floor when standing, or subtly on the seat cushion when resting
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(
          pos.dx,
          restState == PlayerRestState.sleeping
              ? pos.dy - 10
              : (restState.isResting ? pos.dy + 2 : pos.dy + 4),
        ),
        width: restState == PlayerRestState.sleeping ? 44 : 24,
        height: restState == PlayerRestState.sleeping ? 12 : 9,
      ),
      Paint()
        ..color = Colors.black
            .withValues(alpha: restState.isResting ? 0.20 : 0.35),
    );

    if (sheet == null) return;

    final stepFrame = restState.isResting
        ? 0
        : (animTick ~/ 2) % kCharFramesPerDirection;
    final frameIdx = computeCharacterFrameIndex(
      facing: restState == PlayerRestState.sleeping ? AvatarFacing.down : facing,
      isWalking: isWalking && !restState.isResting,
      stepFrame: stepFrame,
    );
    final fx = frameIdx * kCharFrameWidth;

    if (restState == PlayerRestState.sleeping) {
      // 1. Crisp 2x2-pixel-grid pillow on the left cushion (`pos.dx - 28, pos.dy - 20`)
      final px = pos.dx - 28.0;
      final py = pos.dy - 20.0;
      const pw = 20.0;
      const ph = 18.0;
      canvas.drawRect(
        Rect.fromLTWH(px, py, pw, ph),
        Paint()..color = const Color(0xFF334155),
      );
      canvas.drawRect(
        Rect.fromLTWH(px + 2, py + 2, pw - 4, ph - 4),
        Paint()..color = const Color(0xFFF8FAFC),
      );
      canvas.drawRect(
        Rect.fromLTWH(px + 4, py + ph - 4, pw - 6, 2),
        Paint()..color = const Color(0xFFCBD5E1),
      );

      // 2. Rotate ONLY the character's head (`y = 18..45`, height `28`) `-90°` onto the pillow
      // so no arms or shoulders stick out above/below the sofa!
      final headSrc = Rect.fromLTWH(fx, 18, kCharFrameWidth, 28);
      final skinSampleSrc = Rect.fromLTWH(fx + 14, 38, 2, 2);
      canvas.save();
      canvas.translate(pos.dx - 8.0, pos.dy - 10.0);
      canvas.rotate(-math.pi / 2);
      final headDst = Rect.fromCenter(
        center: Offset.zero,
        width: kCharFrameWidth,
        height: 28,
      );
      canvas.drawImageRect(sheet, headSrc, headDst, pixelPaint);

      // Skin-tone adaptive closed eyelids inside the rotated head frame (`top = -14` corresponds to `y = 18`)
      canvas.drawImageRect(
        sheet,
        skinSampleSrc,
        const Rect.fromLTWH(-16 + 10, -14 + 22, 2, 4),
        pixelPaint,
      );
      canvas.drawImageRect(
        sheet,
        skinSampleSrc,
        const Rect.fromLTWH(-16 + 20, -14 + 22, 2, 4),
        pixelPaint,
      );
      final eyelashPaint = Paint()..color = const Color(0xFF3B2F2F);
      canvas.drawRect(
        const Rect.fromLTWH(-16 + 9, -14 + 24, 4, 2),
        eyelashPaint,
      );
      canvas.drawRect(
        const Rect.fromLTWH(-16 + 19, -14 + 24, 4, 2),
        eyelashPaint,
      );
      canvas.restore();

      // 3. Crisp 2x2-pixel-grid quilted blanket starting right at the chin (`pos.dx + 4`)
      final bx = pos.dx + 4.0;
      final by = pos.dy - 20.0;
      const bw = 24.0;
      const bh = 20.0;
      // Outer pixel border
      canvas.drawRect(
        Rect.fromLTWH(bx, by, bw, bh),
        Paint()..color = const Color(0xFF1E293B),
      );
      // Main quilt fill
      canvas.drawRect(
        Rect.fromLTWH(bx + 2, by + 2, bw - 4, bh - 4),
        Paint()..color = const Color(0xFF3B82F6),
      );
      // Folded white sheet collar on the left edge (under the chin)
      canvas.drawRect(
        Rect.fromLTWH(bx + 2, by + 2, 4, bh - 4),
        Paint()..color = const Color(0xFFF1F5F9),
      );
      canvas.drawRect(
        Rect.fromLTWH(bx + 6, by + 2, 2, bh - 4),
        Paint()..color = const Color(0xFFCBD5E1),
      );
      // Top highlight & bottom shadow bands
      canvas.drawRect(
        Rect.fromLTWH(bx + 8, by + 2, bw - 10, 4),
        Paint()..color = const Color(0xFF60A5FA),
      );
      canvas.drawRect(
        Rect.fromLTWH(bx + 8, by + bh - 6, bw - 10, 4),
        Paint()..color = const Color(0xFF2563EB),
      );
      // Vertical pixel quilt stitch lines
      final stitchPaint = Paint()..color = const Color(0xFF1D4ED8);
      canvas.drawRect(
        Rect.fromLTWH(bx + 12, by + 2, 2, bh - 4),
        stitchPaint,
      );
      canvas.drawRect(
        Rect.fromLTWH(bx + 18, by + 2, 2, bh - 4),
        stitchPaint,
      );

      // 4. Animated rising `💤 Zzz...` sleep particles
      final floatOffset = (animTick % 12) * 1.3;
      final zzzTp = TextPainter(
        text: const TextSpan(
          text: '💤 Zzz...',
          style: TextStyle(
            color: Color(0xFFC4B5FD),
            fontSize: 9.5,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      zzzTp.paint(
        canvas,
        Offset(pos.dx + 4, pos.dy - 40 - floatOffset),
      );
    } else if (restState == PlayerRestState.sitting ||
        restState == PlayerRestState.napping) {
      // Gentle 2px pixel breathing nod when napping
      final nodY = restState == PlayerRestState.napping
          ? ((animTick ~/ 8) % 2) * 2.0
          : 0.0;
      final ox = pos.dx - kCharFrameWidth / 2;
      final oy = pos.dy - 56.0 + nodY;

      // 1. Intact Upper Body, Arms & Hips (`y = 0..55`, height `56`) seated on the cushion
      final upperSrc = Rect.fromLTWH(fx, 0, kCharFrameWidth, 56);
      final upperDst = Rect.fromLTWH(ox, oy, kCharFrameWidth, 56);
      canvas.drawImageRect(sheet, upperSrc, upperDst, pixelPaint);

      // 2. Foreshortened seated pixel-art Feet/Shoes (`y = 60..63`, height `4`) tucked directly below
      if (facing != AvatarFacing.up) {
        final feetSrc = Rect.fromLTWH(fx, 60, kCharFrameWidth, 4);
        final feetDst = Rect.fromLTWH(ox, pos.dy, kCharFrameWidth, 4);
        canvas.drawImageRect(sheet, feetSrc, feetDst, pixelPaint);
      }

      // 3. When Napping (and not facing away), draw skin-tone adaptive closed eyelids
      if (restState == PlayerRestState.napping && facing != AvatarFacing.up) {
        final skinSampleSrc = Rect.fromLTWH(fx + 14, 38, 2, 2);
        canvas.drawImageRect(
          sheet,
          skinSampleSrc,
          Rect.fromLTWH(ox + 10, oy + 40, 2, 4),
          pixelPaint,
        );
        canvas.drawImageRect(
          sheet,
          skinSampleSrc,
          Rect.fromLTWH(ox + 20, oy + 40, 2, 4),
          pixelPaint,
        );
        final eyelashPaint = Paint()..color = const Color(0xFF3B2F2F);
        canvas.drawRect(
          Rect.fromLTWH(ox + 9, oy + 42, 4, 2),
          eyelashPaint,
        );
        canvas.drawRect(
          Rect.fromLTWH(ox + 19, oy + 42, 4, 2),
          eyelashPaint,
        );
      }

      // 4. When facing UP (at a Classroom desk or Canteen table), overlay the lower backrest slice
      // of `chair-tan-back` from `floor-items.png` so the wooden backrest wraps cleanly behind their back!
      if (facing == AvatarFacing.up) {
        final chairFrame = assets.itemFrames['chair-tan-back'];
        if (chairFrame != null) {
          const offY = 10.0;
          final backSrc = Rect.fromLTWH(
            chairFrame.left,
            chairFrame.top + offY,
            chairFrame.width,
            chairFrame.height - offY,
          );
          final backDst = Rect.fromLTWH(
            pos.dx - 16.0,
            pos.dy - 24.0 + offY,
            chairFrame.width,
            chairFrame.height - offY,
          );
          canvas.drawImageRect(assets.floorItems, backSrc, backDst, pixelPaint);
        }
      }

      if (restState == PlayerRestState.napping) {
        final floatOffset = (animTick % 10) * 1.1;
        final napTp = TextPainter(
          text: const TextSpan(
            text: '😪 💤',
            style: TextStyle(fontSize: 10.5),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        napTp.paint(
          canvas,
          Offset(pos.dx + 12, pos.dy - 48 - floatOffset),
        );
      }
    } else {
      // Standing / Walking full sprite
      final src = Rect.fromLTWH(
        fx,
        0,
        kCharFrameWidth,
        kCharFrameHeight,
      );
      final dst = Rect.fromLTWH(
        pos.dx - kCharFrameWidth / 2,
        pos.dy - kCharFrameHeight + 8,
        kCharFrameWidth,
        kCharFrameHeight,
      );
      canvas.drawImageRect(sheet, src, dst, pixelPaint);
    }
  }

  /// Renders a Subject-Labeled Large Treasure Chest in the Reviewer Treasure Corner
  /// with a permanent floating color-coded Subject Banner directly above it!
  void _drawLargeSubjectChest(
    Canvas canvas, {
    required SubjectChest chest,
    required Offset pos,
    required bool isHighlighted,
  }) {
    final subjectColor = Color(chest.colorValue);
    final bob = math.sin((animTick + pos.dx) * 0.25) * 1.5;

    if (isHighlighted) {
      canvas.drawOval(
        Rect.fromCenter(
            center: Offset(pos.dx, pos.dy + 4), width: 52, height: 22),
        Paint()..color = subjectColor.withOpacity(0.42),
      );
    }
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy + 5), width: 42, height: 14),
      Paint()..color = Colors.black.withOpacity(0.45),
    );

    final chestRect =
        Rect.fromCenter(center: Offset(pos.dx, pos.dy - 6), width: 38, height: 28);
    canvas.drawRRect(
      RRect.fromRectAndRadius(chestRect.inflate(1.5), const Radius.circular(4)),
      Paint()..color = const Color(0xFF1E1B18),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(chestRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFF78350F),
    );
    final lidRect = Rect.fromLTWH(
        chestRect.left, chestRect.top, chestRect.width, chestRect.height * 0.48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lidRect, const Radius.circular(3)),
      Paint()
        ..color = Color.lerp(const Color(0xFF92400E), subjectColor, 0.38)!,
    );
    final goldPaint = Paint()..color = const Color(0xFFFACC15);
    canvas.drawRect(
      Rect.fromLTWH(chestRect.left + 5, chestRect.top, 4, chestRect.height),
      goldPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(chestRect.right - 9, chestRect.top, 4, chestRect.height),
      goldPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(chestRect.left, chestRect.top + 12, chestRect.width, 3),
      goldPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: Offset(pos.dx, chestRect.top + 13.5), width: 10, height: 9),
        const Radius.circular(2),
      ),
      Paint()..color = subjectColor,
    );
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(pos.dx, chestRect.top + 13.5), width: 4, height: 4),
      Paint()..color = Colors.white,
    );

    // Permanent Floating Pixel Banner Directly Above the Chest
    final bannerCenter = Offset(pos.dx, pos.dy - 34 + bob);
    final tp = TextPainter(
      text: TextSpan(
        children: [
          const TextSpan(
            text: '📦 ',
            style: TextStyle(fontSize: 9.5),
          ),
          TextSpan(
            text: chest.subjectName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          TextSpan(
            text: ' (${chest.reviewers.length})',
            style: TextStyle(
              color: Colors.white.withOpacity(0.85),
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final bannerRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: bannerCenter,
        width: tp.width + 14,
        height: tp.height + 7,
      ),
      const Radius.circular(7),
    );
    canvas.drawRRect(
      bannerRect.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    canvas.drawRRect(
      bannerRect,
      Paint()..color = const Color(0xFF0F172A).withOpacity(0.92),
    );
    canvas.drawRRect(
      bannerRect,
      Paint()
        ..color = subjectColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );
    tp.paint(
      canvas,
      Offset(bannerCenter.dx - tp.width / 2, bannerCenter.dy - tp.height / 2),
    );
  }

  /// Renders an autonomous walking & talking AI Subject Teacher (`msitarzewski/agency-agents` + `Parcha-ai/ai-office`)
  /// exclusively for the 3 official Portal subjects (`PKLP`, `PPG`, and `UCSP`)!
  void _drawSmallMysteryChest(
    Canvas canvas, {
    required InteractiveZone zone,
    required int remainingCooldownSec,
    required bool isHighlighted,
  }) {
    final agentState =
        LobbyAgencyAgentsService.instance.runtimeStateForId(zone.id);
    final pos = agentState?.currentPos ?? zone.center;
    final isOnCooldown = remainingCooldownSec > 0;
    final bob = math.sin((animTick + pos.dy) * 0.35) * 1.6;
    final mentor = findAiSubjectMentor(zone.id);
    final accentCol = Color(mentor?.accentColor ?? zone.accentColor);
    final pixelPaint = Paint()..filterQuality = FilterQuality.none;

    // 1. Glowing AI Teacher floor aura ring
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy + 4), width: 32, height: 12),
      Paint()
        ..color = isOnCooldown
            ? const Color(0xFF475569).withValues(alpha: 0.45)
            : accentCol.withValues(alpha: isHighlighted ? 0.58 : 0.32),
    );

    // 2. Render AI Teacher Character Sprite Sheet using `_drawCharacterWithRestState`
    // so they physically walk, turn to face the student, or sit at their favorite seat!
    final sheet =
        assets.npcSheets[zone.id] ?? assets.npcSheets['npc_receptionist'];
    final facing = agentState?.facing ??
        (((animTick ~/ 18) % 2 == 0)
            ? AvatarFacing.down
            : ((pos.dx < playerPos.dx)
                ? AvatarFacing.right
                : AvatarFacing.left));
    final isWalking = agentState?.isWalking ?? false;
    final restState =
        agentState?.activityState == AgencyAgentActivityState.sitting
            ? PlayerRestState.sitting
            : PlayerRestState.none;

    _drawCharacterWithRestState(
      canvas,
      sheet: sheet,
      pos: pos,
      facing: facing,
      isWalking: isWalking,
      restState: restState,
      pixelPaint: pixelPaint,
    );

    // Wave emote (`👋`) when the AI Teacher spots the student approaching!
    if (agentState != null && agentState.isWaving) {
      final waveTp = TextPainter(
        text: const TextSpan(
          text: '👋',
          style: TextStyle(fontSize: 15),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      waveTp.paint(canvas, Offset(pos.dx + 16, pos.dy - 48));
    }

    // 3. Floating Nameplate (`🤖 Guro Lakambini [PKLP • Walking / Talking]`)
    final mentorName = mentor?.name ?? zone.label;
    final activityBadge = agentState != null
        ? (agentState.activityState ==
                AgencyAgentActivityState.conversingWithPlayer
            ? '💬 Talking'
            : (agentState.activityState == AgencyAgentActivityState.sitting
                ? '🪑 Seated'
                : (agentState.isWalking ? '🚶 Patrol' : '📋 Ready')))
        : 'AI Mentor';
    final mentorTag = mentor != null
        ? '${mentor.subjectCode} • $activityBadge'
        : activityBadge;
    _drawFloatingNameplate(
      canvas,
      anchor: Offset(pos.dx, pos.dy - 54),
      name: mentorName,
      roleTag: mentorTag,
      isGoldTag: !isOnCooldown,
      badgeIcon: '🤖',
    );

    // 4. Live `msitarzewski/agency-agents` Conversational Speech / Study Bubble when player is nearby
    final liveBubble = agentState?.activeBubbleText ?? '';
    if (liveBubble.isNotEmpty && (playerPos - pos).distance <= 250.0) {
      _drawCloudThoughtBubble(
        canvas,
        anchor: Offset(pos.dx, pos.dy - 88),
        text: liveBubble,
        isHighlighted: isHighlighted ||
            agentState?.activityState ==
                AgencyAgentActivityState.conversingWithPlayer,
      );
    } else if (mentor != null &&
        mentor.studyThoughts.isNotEmpty &&
        (playerPos - pos).distance <= 240.0) {
      final thoughtIdx = (animTick ~/ 28) % mentor.studyThoughts.length;
      _drawCloudThoughtBubble(
        canvas,
        anchor: Offset(pos.dx, pos.dy - 88),
        text: mentor.studyThoughts[thoughtIdx],
        isHighlighted: isHighlighted,
      );
    }

    // 5. Quest & Chat Status Pill (`💬 Talk • 📝 PKLP Exam (+25 XP)` or `💬 Talk • ⏳ Cooldown`)
    final badgeY = pos.dy - 70 + bob;
    final subjShort = mentor?.subjectCode ?? 'EXAM';
    if (isOnCooldown) {
      final hours = remainingCooldownSec ~/ 3600;
      final mins = (remainingCooldownSec % 3600) ~/ 60;
      final secs = (remainingCooldownSec % 60).toString().padLeft(2, '0');
      final cooldownLabel = hours > 0
          ? '💬 Talk • ⏳ Exam ${hours}h ${mins}m'
          : '💬 Talk • ⏳ $mins:$secs';
      final tp = TextPainter(
        text: TextSpan(
          text: cooldownLabel,
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 8.2,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pos.dx, badgeY),
          width: tp.width + 10,
          height: tp.height + 4,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
        pill,
        Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.88),
      );
      tp.paint(
        canvas,
        Offset(pos.dx - tp.width / 2, badgeY - tp.height / 2),
      );
    } else {
      final tp = TextPainter(
        text: TextSpan(
          text: '💬 TALK • 📝 $subjShort EXAM (+25 XP)',
          style: const TextStyle(
            color: Color(0xFFFDE047),
            fontSize: 8.2,
            fontWeight: FontWeight.w900,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pos.dx, badgeY),
          width: tp.width + 12,
          height: tp.height + 4,
        ),
        const Radius.circular(99),
      );
      canvas.drawRRect(
        pill,
        Paint()..color = const Color(0xFF0F172A).withValues(alpha: 0.94),
      );
      canvas.drawRRect(
        pill,
        Paint()
          ..color = isHighlighted ? const Color(0xFFFDE047) : accentCol
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4,
      );
      tp.paint(
        canvas,
        Offset(pos.dx - tp.width / 2, badgeY - tp.height / 2),
      );
    }
  }

  void _drawPlayer(Canvas canvas, Paint pixelPaint) {
    _drawCharacterWithRestState(
      canvas,
      sheet: playerSheet,
      pos: playerPos,
      facing: playerFacing,
      isWalking: playerIsWalking,
      restState: playerRestState,
      pixelPaint: pixelPaint,
    );

    final baseRole = isFaculty ? 'Teacher' : 'Student';
    final roleWithRest = playerRestState.isResting
        ? '${playerRestState.emoji} ${playerRestState.label}'
        : baseRole;

    // Floating Nameplate
    _drawFloatingNameplate(
      canvas,
      anchor: Offset(playerPos.dx, playerPos.dy - 54),
      name: playerName,
      roleTag: roleWithRest,
      isGoldTag: isFaculty,
      badgeIcon: equippedBadgeIcon,
    );

    // Player Cloud Thought Bubble (`💭`) if active!
    if (playerThoughtText != null && playerThoughtText!.trim().isNotEmpty) {
      _drawCloudThoughtBubble(
        canvas,
        anchor: Offset(playerPos.dx, playerPos.dy - 78),
        text: playerThoughtText!,
        isHighlighted: true,
      );
    }

    // Wave Emote Bubble (`👋`) if active
    if (waveBubbleProgress > 0.0 && waveBubbleProgress < 1.0) {
      final rise = waveBubbleProgress * 12.0;
      final waveTp = TextPainter(
        text: const TextSpan(
          text: '👋',
          style: TextStyle(fontSize: 16),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      waveTp.paint(
        canvas,
        Offset(playerPos.dx + 14, playerPos.dy - 68 - rise),
      );
    }
  }

  /// Renders a crisp RPG Cloud Thought Bubble (`💭`) with trailing thought circles (`o` `O`)
  /// above a student's head for in-lobby communication!
  void _drawCloudThoughtBubble(
    Canvas canvas, {
    required Offset anchor,
    required String text,
    bool isHighlighted = false,
  }) {
    final clean = text.trim();
    if (clean.isEmpty) return;
    final display = clean.length > 56 ? '${clean.substring(0, 54)}…' : clean;

    final tp = TextPainter(
      text: TextSpan(
        text: display.startsWith('💭') ? display : '💭 $display',
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 9.0,
          fontWeight: FontWeight.w800,
          height: 1.2,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2,
    )..layout(maxWidth: 165);

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(anchor.dx, anchor.dy - tp.height / 2 - 4),
        width: tp.width + 18,
        height: tp.height + 10,
      ),
      const Radius.circular(14),
    );

    // Drop shadow
    canvas.drawRRect(
      bubbleRect.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    // Cloud fill & border
    final fillPaint = Paint()..color = const Color(0xFFF8FAFC).withOpacity(0.96);
    final borderPaint = Paint()
      ..color =
          isHighlighted ? const Color(0xFF0284C7) : const Color(0xFF64748B)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;

    canvas.drawRRect(bubbleRect, fillPaint);
    canvas.drawRRect(bubbleRect, borderPaint);

    // Trailing thought cloud circles (`O` then `o`) pointing down to the avatar's head
    final c1 = Offset(anchor.dx - 4, bubbleRect.bottom + 4);
    final c2 = Offset(anchor.dx - 8, bubbleRect.bottom + 9);
    canvas.drawCircle(c1, 3.2, fillPaint);
    canvas.drawCircle(c1, 3.2, borderPaint);
    canvas.drawCircle(c2, 2.0, fillPaint);
    canvas.drawCircle(c2, 2.0, borderPaint);

    tp.paint(
      canvas,
      Offset(
        bubbleRect.center.dx - tp.width / 2,
        bubbleRect.center.dy - tp.height / 2,
      ),
    );
  }

  void _drawFloatingNameplate(
    Canvas canvas, {
    required Offset anchor,
    required String name,
    required String roleTag,
    required bool isGoldTag,
    String? badgeIcon,
  }) {
    final cleanName =
        name.length > 18 ? '${name.substring(0, 16)}…' : name;
    final prefix =
        (badgeIcon != null && badgeIcon.isNotEmpty) ? '$badgeIcon ' : '';

    final tp = TextPainter(
      text: TextSpan(
        children: [
          if (prefix.isNotEmpty)
            TextSpan(
              text: prefix,
              style: const TextStyle(fontSize: 10),
            ),
          TextSpan(
            text: '$cleanName ',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          TextSpan(
            text: '[$roleTag]',
            style: TextStyle(
              color: isGoldTag
                  ? const Color(0xFFFACC15)
                  : const Color(0xFF34D399),
              fontSize: 8.5,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    final plateRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: anchor,
        width: tp.width + 14,
        height: tp.height + 6,
      ),
      const Radius.circular(99),
    );

    canvas.drawRRect(
      plateRect,
      Paint()..color = const Color(0xFF0F172A).withOpacity(0.84),
    );
    canvas.drawRRect(
      plateRect,
      Paint()
        ..color = isGoldTag
            ? const Color(0xFFFACC15).withOpacity(0.9)
            : const Color(0xFF38BDF8).withOpacity(0.75)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );

    tp.paint(
      canvas,
      Offset(anchor.dx - tp.width / 2, anchor.dy - tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant SchoolLobbyCanvasPainter oldDelegate) => true;
}

class _YSortedDrawable {
  final double sortY;
  final void Function(Canvas canvas) draw;

  const _YSortedDrawable({
    required this.sortY,
    required this.draw,
  });
}
