import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'lobby_data_service.dart';
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

    // 6a. Furniture pieces (non-rug)
    for (final piece in roomPieces) {
      if (piece.isFloorRug) continue;
      drawables.add(
        _YSortedDrawable(
          sortY: piece.sortY,
          draw: (c) => _drawFurniturePiece(c, piece, pixelPaint),
        ),
      );
    }

    // 6b. NPCs in this room
    for (final npc in npcsForRoom(currentRoom)) {
      drawables.add(
        _YSortedDrawable(
          sortY: npc.y,
          draw: (c) => _drawNpc(c, npc, pixelPaint),
        ),
      );
    }

    // 6c. Classmate Peer Students in this room (with Sit/Nap/Sleep poses + Thought Bubbles!)
    for (final peer in peersForRoom(currentRoom)) {
      drawables.add(
        _YSortedDrawable(
          sortY: peer.y,
          draw: (c) => _drawPeerStudent(c, peer, pixelPaint),
        ),
      );
    }

    // 6d. Subject-Labeled Large Treasure Chests & Small Mystery Chests (in Main Lobby)
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

      for (final zone in INTERACTIVE_ZONES) {
        if (zone.kind != InteractiveZoneKind.smallMysteryChest) continue;
        final remainingSec = smallChestRemainingSec[zone.id] ?? 0;
        final isHighlighted = highlightedZone?.id == zone.id;
        drawables.add(
          _YSortedDrawable(
            sortY: zone.y,
            draw: (c) => _drawSmallMysteryChest(
              c,
              zone: zone,
              remainingCooldownSec: remainingSec,
              isHighlighted: isHighlighted,
            ),
          ),
        );
      }
    }

    // 6e. Player Avatar + Rest Pose (Sit/Nap/Sleep) + Floating Nameplate + Thought Bubble
    drawables.add(
      _YSortedDrawable(
        sortY: playerPos.dy,
        draw: (c) => _drawPlayer(c, pixelPaint),
      ),
    );

    drawables.sort((a, b) => a.sortY.compareTo(b.sortY));
    for (final item in drawables) {
      item.draw(canvas);
    }

    canvas.restore();
  }

  void _paintLobbyShell(Canvas canvas) {
    // Outer drop shadow
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(
            -12, -8, kLobbyWorldWidth + 24, kLobbyWorldHeight + 24),
        const Radius.circular(16),
      ),
      Paint()..color = Colors.black.withOpacity(0.65),
    );

    const floorRect = Rect.fromLTWH(0, 0, kLobbyWorldWidth, kLobbyWorldHeight);

    // Room-specific floor palette
    Color baseFloorColor;
    Color altFloorColor;
    Color gridColor;

    switch (currentRoom) {
      case LobbyRoomId.park:
        baseFloorColor =
            isDarkMode ? const Color(0xFF0E291E) : const Color(0xFF65A34E);
        altFloorColor =
            isDarkMode ? const Color(0xFF0B2219) : const Color(0xFF5B9644);
        gridColor = isDarkMode
            ? const Color(0xFF1E4631).withOpacity(0.42)
            : const Color(0xFF4A7F35).withOpacity(0.35);
        break;
      case LobbyRoomId.classroom:
        baseFloorColor =
            isDarkMode ? const Color(0xFF172336) : const Color(0xFFE2E8F0);
        altFloorColor =
            isDarkMode ? const Color(0xFF131D2E) : const Color(0xFFCBD5E1);
        gridColor = isDarkMode
            ? const Color(0xFF2B3D59).withOpacity(0.45)
            : const Color(0xFF94A3B8).withOpacity(0.40);
        break;
      case LobbyRoomId.canteen:
        baseFloorColor =
            isDarkMode ? const Color(0xFF231924) : const Color(0xFFFDE68A);
        altFloorColor =
            isDarkMode ? const Color(0xFF1A121B) : const Color(0xFFFCD34D);
        gridColor = isDarkMode
            ? const Color(0xFF3F2B42).withOpacity(0.45)
            : const Color(0xFFD97706).withOpacity(0.28);
        break;
      case LobbyRoomId.facultyRoom:
        baseFloorColor =
            isDarkMode ? const Color(0xFF1A182E) : const Color(0xFFC7B299);
        altFloorColor =
            isDarkMode ? const Color(0xFF141225) : const Color(0xFFBBA388);
        gridColor = isDarkMode
            ? const Color(0xFF312E52).withOpacity(0.45)
            : const Color(0xFF998267).withOpacity(0.42);
        break;
      case LobbyRoomId.mainLobby:
        baseFloorColor =
            isDarkMode ? const Color(0xFF152033) : const Color(0xFFD8C5A8);
        altFloorColor =
            isDarkMode ? const Color(0xFF111A2B) : const Color(0xFFD1BC9D);
        gridColor = isDarkMode
            ? const Color(0xFF283953).withOpacity(0.42)
            : const Color(0xFFBFA888).withOpacity(0.45);
        break;
    }

    canvas.drawRect(floorRect, Paint()..color = baseFloorColor);

    final altTilePaint = Paint()..color = altFloorColor;
    final gridLinePaint = Paint()
      ..color = gridColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (var r = 2; r < kLobbyRows; r++) {
      for (var c = 0; c < kLobbyCols; c++) {
        final rect =
            Rect.fromLTWH(c * kTileSize, r * kTileSize, kTileSize, kTileSize);
        if ((r + c).isOdd) {
          canvas.drawRect(rect, altTilePaint);
        }
        canvas.drawRect(rect, gridLinePaint);
      }
    }

    // Room-specific architectural floor features
    if (currentRoom == LobbyRoomId.mainLobby) {
      // Center Grand Campus Walkway Carpet Runner
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(720, 260, 96, kLobbyWorldHeight - 288),
          const Radius.circular(8),
        ),
        Paint()
          ..color = isDarkMode
              ? const Color(0xFF1E3A5F).withOpacity(0.32)
              : const Color(0xFF0F766E).withOpacity(0.11),
      );

      // Bulletin Board Reading Floor (Top-Left Wing)
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(44, 92, 460, 190),
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
              const Color(0xFF3B1D5E).withOpacity(isDarkMode ? 0.36 : 0.22),
      );
      canvas.drawRRect(
        sanctuaryRect,
        Paint()
          ..color = const Color(0xFFF59E0B).withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
      );
    } else if (currentRoom == LobbyRoomId.park) {
      // Cobblestone Park Walkways (Horizontal & Vertical paths)
      final pathPaint = Paint()
        ..color = isDarkMode
            ? const Color(0xFF334155).withOpacity(0.65)
            : const Color(0xFFD6D3D1).withOpacity(0.85);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(96, 504, kLobbyWorldWidth - 144, 80),
          const Radius.circular(12),
        ),
        pathPaint,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(728, 160, 80, kLobbyWorldHeight - 240),
          const Radius.circular(12),
        ),
        pathPaint,
      );

      // Sparkling Central Park Pond (`x: 640..896, y: 420..600`)
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
      // Lily pads & water ripples
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
    } else if (currentRoom == LobbyRoomId.classroom) {
      // Front Wooden Teaching Stage
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(280, 96, 976, 150),
          const Radius.circular(10),
        ),
        Paint()
          ..color =
              isDarkMode ? const Color(0xFF3B281E) : const Color(0xFFB4845C),
      );
    } else if (currentRoom == LobbyRoomId.canteen) {
      // Canteen Food Service Zone Floor
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(960, 100, 460, 160),
          const Radius.circular(12),
        ),
        Paint()
          ..color =
              const Color(0xFFF97316).withOpacity(isDarkMode ? 0.25 : 0.18),
      );
    } else if (currentRoom == LobbyRoomId.facultyRoom) {
      // Executive Carpet Centerpiece
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(480, 280, 576, 360),
          const Radius.circular(16),
        ),
        Paint()
          ..color =
              const Color(0xFF7C3AED).withOpacity(isDarkMode ? 0.28 : 0.18),
      );
    }

    // Night / Dark Mode warm ambient light pools
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

    // 3/4-Perspective Top Wall (`WALL_HEIGHT = 82`)
    const topWallFace = Rect.fromLTWH(0, 14, kLobbyWorldWidth, 68);
    canvas.drawRect(
      topWallFace,
      Paint()
        ..color = currentRoom == LobbyRoomId.park
            ? (isDarkMode ? const Color(0xFF143325) : const Color(0xFF3F6212))
            : (isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE7DFD3)),
    );
    // Classroom Giant Green Chalkboard on Top Wall
    if (currentRoom == LobbyRoomId.classroom) {
      final boardRect = RRect.fromRectAndRadius(
        const Rect.fromLTWH(490, 20, 556, 48),
        const Radius.circular(4),
      );
      canvas.drawRRect(boardRect.inflate(3),
          Paint()..color = const Color(0xFF78350F));
      canvas.drawRRect(
          boardRect, Paint()..color = const Color(0xFF064E3B));
    }
    canvas.drawRect(
      const Rect.fromLTWH(0, 66, kLobbyWorldWidth, 16),
      Paint()
        ..color =
            isDarkMode ? const Color(0xFF334155) : const Color(0xFF9C8468),
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 82, kLobbyWorldWidth, 12),
      Paint()..color = Colors.black.withOpacity(isDarkMode ? 0.35 : 0.14),
    );

    // Perimeter dark architectural wall caps
    final wallCapPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF26243A);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kLobbyWorldWidth, 16),
      wallCapPaint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 32, kLobbyWorldHeight),
      wallCapPaint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(kLobbyWorldWidth - 32, 0, 32, kLobbyWorldHeight),
      wallCapPaint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(0, kLobbyWorldHeight - 24, kLobbyWorldWidth, 24),
      wallCapPaint,
    );
  }

  void _paintZoneFloorDecals(Canvas canvas) {
    if (currentRoom == LobbyRoomId.mainLobby) {
      _drawFloorPlaque(
        canvas,
        text: '📌 BULLETIN WALL',
        center: const Offset(268, 250),
        color: const Color(0xFF0284C7),
      );
      _drawFloorPlaque(
        canvas,
        text: '⚔️ QUEST COUNTER',
        center: const Offset(768, 256),
        color: const Color(0xFFD97706),
      );
      _drawFloorPlaque(
        canvas,
        text: "🎓 TEACHER'S CORNER",
        center: const Offset(1248, 256),
        color: const Color(0xFFB45309),
      );
      _drawFloorPlaque(
        canvas,
        text: '🛋️ STUDENT LOUNGE (SIT / NAP / SLEEP)',
        center: const Offset(416, 420),
        color: const Color(0xFF059669),
      );
      _drawFloorPlaque(
        canvas,
        text: '💎 ENROLLED REVIEWER TREASURE VAULT',
        center: const Offset(1168, 568),
        color: const Color(0xFF9333EA),
      );
    } else if (currentRoom == LobbyRoomId.park) {
      _drawFloorPlaque(
        canvas,
        text: '🌳 CAMPUS NATURE PARK & POND',
        center: const Offset(768, 360),
        color: const Color(0xFF059669),
      );
      _drawFloorPlaque(
        canvas,
        text: '🛌 PICNIC NAP & SLEEPING LAWN',
        center: const Offset(420, 650),
        color: const Color(0xFF0D9488),
      );
    } else if (currentRoom == LobbyRoomId.classroom) {
      _drawFloorPlaque(
        canvas,
        text: '🏫 SHS LECTURE STAGE & CHALKBOARD',
        center: const Offset(768, 265),
        color: const Color(0xFFD97706),
      );
      _drawFloorPlaque(
        canvas,
        text: '🪑 STUDENT DESKS (TAP INTERACT TO SIT OR NAP)',
        center: const Offset(768, 345),
        color: const Color(0xFF0284C7),
      );
    } else if (currentRoom == LobbyRoomId.canteen) {
      _drawFloorPlaque(
        canvas,
        text: '🍱 STUDENT CANTEEN & MERIENDA COUNTER',
        center: const Offset(1084, 255),
        color: const Color(0xFFEA580C),
      );
      _drawFloorPlaque(
        canvas,
        text: '🪑 DINING TABLES & COZY NAP BOOTH',
        center: const Offset(600, 430),
        color: const Color(0xFFD97706),
      );
    } else if (currentRoom == LobbyRoomId.facultyRoom) {
      _drawFloorPlaque(
        canvas,
        text: '🎓 FACULTY CONSULTATION & ADVISORY ROOM',
        center: const Offset(768, 270),
        color: const Color(0xFF7C3AED),
      );
    }

    // Render glowing Campus Door Portals (`🚪`) in the current room
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
      }
    }

    // Draw interactive highlight ring around the currently active zone
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

    // Floating Door Banner overhead
    final tp = TextPainter(
      text: TextSpan(
        text: '🚪 ${zone.label}',
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
          letterSpacing: 0.6,
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
    canvas.drawRRect(rect, Paint()..color = color.withOpacity(0.82));
    tp.paint(
      canvas,
      Offset(center.dx - tp.width / 2, center.dy - tp.height / 2),
    );
  }

  void _paintNavigationOverlay(Canvas canvas) {
    if (activePath.isNotEmpty) {
      final pathPaint = Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.55)
        ..style = PaintingStyle.fill;
      for (final wp in activePath) {
        canvas.drawCircle(wp, 3.5, pathPaint);
      }
    }

    if (tapPulseTarget != null && tapPulseProgress < 1.0) {
      final radius = 8.0 + 16.0 * tapPulseProgress;
      final alpha = (1.0 - tapPulseProgress).clamp(0.0, 1.0);
      canvas.drawCircle(
        tapPulseTarget!,
        radius,
        Paint()
          ..color = const Color(0xFF38BDF8).withOpacity(0.75 * alpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2,
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
    if (sheet != null) {
      final frameIdx = computeCharacterFrameIndex(
        facing: npc.facing,
        isWalking: false,
        stepFrame: (animTick ~/ 2) % kCharFramesPerDirection,
      );
      final src = Rect.fromLTWH(
        frameIdx * kCharFrameWidth,
        0,
        kCharFrameWidth,
        kCharFrameHeight,
      );
      final dst = Rect.fromLTWH(
        npc.x - kCharFrameWidth / 2,
        npc.y - kCharFrameHeight + 8,
        kCharFrameWidth,
        kCharFrameHeight,
      );
      canvas.drawOval(
        Rect.fromCenter(center: Offset(npc.x, npc.y + 4), width: 22, height: 8),
        Paint()..color = Colors.black.withOpacity(0.28),
      );
      canvas.drawImageRect(sheet, src, dst, pixelPaint);
    }

    _drawFloatingNameplate(
      canvas,
      anchor: Offset(npc.x, npc.y - 54),
      name: npc.name,
      roleTag: npc.roleTag,
      isGoldTag: npc.isGoldTag,
      badgeIcon: npc.id == 'npc_receptionist'
          ? '✨'
          : (npc.isGoldTag ? '🎓' : '📚'),
    );
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

  /// Shared character sprite + rest pose renderer (recycled & expanded from `SeatManager.ts`).
  void _drawCharacterWithRestState(
    Canvas canvas, {
    required ui.Image? sheet,
    required Offset pos,
    required AvatarFacing facing,
    required bool isWalking,
    required PlayerRestState restState,
    required Paint pixelPaint,
  }) {
    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(pos.dx, pos.dy + 4),
        width: restState == PlayerRestState.sleeping ? 38 : 24,
        height: restState == PlayerRestState.sleeping ? 12 : 9,
      ),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    if (sheet == null) return;

    final stepFrame = restState.isResting
        ? (animTick ~/ 3) % kCharFramesPerDirection
        : animTick % kCharFramesPerDirection;
    final frameIdx = computeCharacterFrameIndex(
      facing: restState == PlayerRestState.sleeping ? AvatarFacing.down : facing,
      isWalking: isWalking && !restState.isResting,
      stepFrame: stepFrame,
    );
    final src = Rect.fromLTWH(
      frameIdx * kCharFrameWidth,
      0,
      kCharFrameWidth,
      kCharFrameHeight,
    );

    if (restState == PlayerRestState.sleeping) {
      // Cozy pixel pillow underneath the sleeping student's head
      final pillowRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pos.dx - 14, pos.dy - 4),
          width: 18,
          height: 13,
        ),
        const Radius.circular(4),
      );
      canvas.drawRRect(pillowRect, Paint()..color = const Color(0xFFF8FAFC));
      canvas.drawRRect(
        pillowRect,
        Paint()
          ..color = const Color(0xFF94A3B8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );

      // Rotate character sprite horizontally (-90 deg) for lying down sleep pose
      canvas.save();
      canvas.translate(pos.dx, pos.dy - 6);
      canvas.rotate(-math.pi / 2);
      final dst = Rect.fromCenter(
        center: Offset.zero,
        width: kCharFrameWidth,
        height: kCharFrameHeight,
      );
      canvas.drawImageRect(sheet, src, dst, pixelPaint);
      canvas.restore();

      // Animated rising `💤 Zzz...` sleep particles
      final floatOffset = (animTick % 12) * 1.4;
      final zzzTp = TextPainter(
        text: const TextSpan(
          text: '🛌 💤 Zzz...',
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
        Offset(pos.dx + 10, pos.dy - 36 - floatOffset),
      );
    } else {
      // Standing, Sitting (`+6px` seat drop), or Napping (`+7px` seat drop + gentle nod)
      final seatDropY = restState == PlayerRestState.sitting
          ? 6.0
          : (restState == PlayerRestState.napping
              ? 7.0 + math.sin(animTick * 0.25) * 1.2
              : 0.0);
      final dst = Rect.fromLTWH(
        pos.dx - kCharFrameWidth / 2,
        pos.dy - kCharFrameHeight + 8 + seatDropY,
        kCharFrameWidth,
        kCharFrameHeight,
      );
      canvas.drawImageRect(sheet, src, dst, pixelPaint);

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
          Offset(pos.dx + 12, pos.dy - 42 - floatOffset),
        );
      }
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

  /// Renders a Small Mystery Chest (`small_chest_1..8`).
  void _drawSmallMysteryChest(
    Canvas canvas, {
    required InteractiveZone zone,
    required int remainingCooldownSec,
    required bool isHighlighted,
  }) {
    final pos = zone.center;
    final isOnCooldown = remainingCooldownSec > 0;
    final bob = math.sin((animTick + pos.dy) * 0.35) * 2.0;

    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy + 4), width: 28, height: 10),
      Paint()..color = Colors.black.withOpacity(0.38),
    );

    final boxRect =
        Rect.fromCenter(center: Offset(pos.dx, pos.dy - 4), width: 24, height: 18);

    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect.inflate(1.2), const Radius.circular(3)),
      Paint()..color = const Color(0xFF1E1B18),
    );

    if (isOnCooldown) {
      final openLid =
          Rect.fromLTWH(boxRect.left, boxRect.top - 6, boxRect.width, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(openLid, const Radius.circular(2)),
        Paint()..color = const Color(0xFF6B7280),
      );
      canvas.drawRect(
        Rect.fromLTWH(boxRect.left + 2, boxRect.top, boxRect.width - 4, 7),
        Paint()..color = const Color(0xFF111827),
      );
      canvas.drawRect(
        Rect.fromLTWH(
            boxRect.left, boxRect.top + 7, boxRect.width, boxRect.height - 7),
        Paint()..color = const Color(0xFF78350F),
      );

      final mins = remainingCooldownSec ~/ 60;
      final secs = (remainingCooldownSec % 60).toString().padLeft(2, '0');
      final tp = TextPainter(
        text: TextSpan(
          text: '⏳ $mins:$secs',
          style: const TextStyle(
            color: Color(0xFFCBD5E1),
            fontSize: 8.5,
            fontWeight: FontWeight.w800,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final pill = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(pos.dx, pos.dy - 24),
          width: tp.width + 10,
          height: tp.height + 4,
        ),
        const Radius.circular(6),
      );
      canvas.drawRRect(
          pill, Paint()..color = const Color(0xFF0F172A).withOpacity(0.85));
      tp.paint(
        canvas,
        Offset(pos.dx - tp.width / 2, pos.dy - 24 - tp.height / 2),
      );
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(2.5)),
        Paint()..color = const Color(0xFF6D28D9),
      );
      final gold = Paint()..color = const Color(0xFFFACC15);
      canvas.drawRect(
        Rect.fromLTWH(boxRect.left, boxRect.top + 7, boxRect.width, 2.5),
        gold,
      );
      canvas.drawRect(
        Rect.fromCenter(
            center: Offset(pos.dx, boxRect.top + 8), width: 6, height: 6),
        gold,
      );

      final badgeY = pos.dy - 25 + bob;
      final tp = TextPainter(
        text: const TextSpan(
          text: '✨ ? QUIZ',
          style: TextStyle(
            color: Color(0xFFFDE047),
            fontSize: 8.5,
            fontWeight: FontWeight.w900,
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
        const Radius.circular(99),
      );
      canvas.drawRRect(
        pill,
        Paint()..color = const Color(0xFF3B0764).withOpacity(0.92),
      );
      canvas.drawRRect(
        pill,
        Paint()
          ..color = isHighlighted
              ? const Color(0xFFFDE047)
              : const Color(0xFFA855F7)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
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
