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
      final c1 = ((expanded.right - 0.01) / kTileSize).floor().clamp(0, cols - 1);
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
          // Prevent corner-cutting through solid corners
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

/// Holds loaded TinyFloor sprite atlases (`floor-items.png`, `floor-sheet.png`, `atlas.json`, NPC sheets).
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
      npcSheets[npc.id] = await AvatarSpriteCache.instance.resolveLookSpriteSheet(
        LobbyAvatarLook(isPreset: true, presetName: npc.presetName),
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

/// CustomPainter that renders the 2D Pixel Student School Lobby:
/// - 3/4-perspective walls & wood/tile school flooring
/// - Distinct visual zone floor accents & labels
/// - Tap-to-walk target ring pulse
/// - Proximity zone ring highlight
/// - Y-sorted furniture (`floor-items.png`), NPCs, Subject-Labeled Large Treasure Chests
///   (with permanent floating color-coded banners), 4 Small Mystery Chests (with `✨ ?` or open cooldown sprite),
///   and the Player Avatar + Floating Nameplate + Equipped Badge Icon + Wave emote!
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
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Deep backdrop
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF090E1A),
    );

    canvas.save();
    // Apply camera transform centered on viewport
    canvas.translate(size.width / 2, size.height / 2);
    canvas.scale(cameraZoom);
    canvas.translate(-cameraCenter.dx, -cameraCenter.dy);

    // 2. Render School Lobby Floor & 3/4 Perspective Walls (recycled from `shell.ts`)
    _paintLobbyShell(canvas);

    // 3. Render Floor Rugs (bottom layer)
    final pixelPaint = Paint()..filterQuality = FilterQuality.none;
    for (final piece in kSchoolLobbyPieces) {
      if (!piece.isFloorRug) continue;
      _drawFurniturePiece(canvas, piece, pixelPaint);
    }

    // 4. Render Distinct Zone Floor Labels & Interactive Proximity Rings
    _paintZoneFloorDecals(canvas);

    // 5. Render Tap-to-Walk path breadcrumbs & pulse ring (`pulseTile` from `MovementManager.ts`)
    _paintNavigationOverlay(canvas);

    // 6. Build Y-sorted renderables (`depthForY(y) = y` from `office.ts`)
    final drawables = <_YSortedDrawable>[];

    // 6a. Furniture pieces (non-rug)
    for (final piece in kSchoolLobbyPieces) {
      if (piece.isFloorRug) continue;
      drawables.add(
        _YSortedDrawable(
          sortY: piece.sortY,
          draw: (c) => _drawFurniturePiece(c, piece, pixelPaint),
        ),
      );
    }

    // 6b. NPCs (Anime Receptionist at Quest Counter + Faculty Adviser at Teacher's Corner)
    for (final npc in kLobbyNpcs) {
      drawables.add(
        _YSortedDrawable(
          sortY: npc.y,
          draw: (c) => _drawNpc(c, npc, pixelPaint),
        ),
      );
    }

    // 6c. Subject-Labeled Large Treasure Chests in the Reviewer Treasure Corner
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

    // 6d. 4 Small Mystery Chests (with sparkling `?` or open 2-min cooldown sprite)
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

    // 6e. Player Avatar + Floating Nameplate + Equipped Badge Icon
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
        const Rect.fromLTWH(-12, -8, kLobbyWorldWidth + 24, kLobbyWorldHeight + 24),
        const Radius.circular(16),
      ),
      Paint()..color = Colors.black.withOpacity(0.65),
    );

    // Main school wood/tile floor (Day Warm Timber vs Night Midnight Slate)
    const floorRect = Rect.fromLTWH(0, 0, kLobbyWorldWidth, kLobbyWorldHeight);
    final baseFloorColor =
        isDarkMode ? const Color(0xFF152033) : const Color(0xFFD8C5A8);
    final altFloorColor =
        isDarkMode ? const Color(0xFF111A2B) : const Color(0xFFD1BC9D);
    final gridColor = isDarkMode
        ? const Color(0xFF283953).withOpacity(0.42)
        : const Color(0xFFBFA888).withOpacity(0.45);

    canvas.drawRect(floorRect, Paint()..color = baseFloorColor);

    // Checkerboard & plank tile grid (`TILE = 32`, `48 x 34` tiles)
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

    // Center Grand Campus Walkway Carpet Runner (Vertical & Horizontal Crossroads)
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

    // Distinct visual zone floor tinting
    // 1. Bulletin Board Reading Floor (Top-Left Wing)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(44, 92, 460, 190),
        const Radius.circular(10),
      ),
      Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(isDarkMode ? 0.14 : 0.10),
    );

    // 2. Reviewer Treasure Corner Sanctuary Floor (Expanded Bottom-Right Wing)
    final sanctuaryRect = RRect.fromRectAndRadius(
      const Rect.fromLTWH(880, 460, 580, 560),
      const Radius.circular(14),
    );
    canvas.drawRRect(
      sanctuaryRect,
      Paint()
        ..color = const Color(0xFF3B1D5E).withOpacity(isDarkMode ? 0.36 : 0.22),
    );
    canvas.drawRRect(
      sanctuaryRect,
      Paint()
        ..color = const Color(0xFFF59E0B).withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2,
    );

    // Warm golden ambient light pools when Night / Dark Study Campus mode is active
    if (isDarkMode) {
      final glowCenters = <Offset>[
        const Offset(268, 175), // Bulletin Wall
        const Offset(768, 200), // Quest Counter
        const Offset(1248, 200), // Teacher's Corner
        const Offset(416, 672), // Student Lounge
        const Offset(1168, 760), // Reviewer Treasure Vault
        playerPos, // Subtle lantern glow around the player
      ];
      for (final center in glowCenters) {
        final radius = center == playerPos ? 130.0 : 210.0;
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

    // 3/4-Perspective Top Wall (`WALL_HEIGHT = 82` from `shell.ts`)
    const topWallFace = Rect.fromLTWH(0, 14, kLobbyWorldWidth, 68);
    canvas.drawRect(
      topWallFace,
      Paint()
        ..color =
            isDarkMode ? const Color(0xFF1E293B) : const Color(0xFFE7DFD3),
    );
    // Lower wainscot molding along the top wall
    canvas.drawRect(
      const Rect.fromLTWH(0, 66, kLobbyWorldWidth, 16),
      Paint()
        ..color =
            isDarkMode ? const Color(0xFF334155) : const Color(0xFF9C8468),
    );
    // Wall drop shadow (`SHADOW = 0.86`)
    canvas.drawRect(
      const Rect.fromLTWH(0, 82, kLobbyWorldWidth, 12),
      Paint()..color = Colors.black.withOpacity(isDarkMode ? 0.35 : 0.14),
    );

    // Perimeter dark architectural wall caps (`TOP = #26243a` from `shell.ts`)
    final wallCapPaint = Paint()
      ..color = isDarkMode ? const Color(0xFF0F172A) : const Color(0xFF26243A);
    // Top cap
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, kLobbyWorldWidth, 16),
      wallCapPaint,
    );
    // Left wall cap
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 32, kLobbyWorldHeight),
      wallCapPaint,
    );
    // Right wall cap
    canvas.drawRect(
      const Rect.fromLTWH(kLobbyWorldWidth - 32, 0, 32, kLobbyWorldHeight),
      wallCapPaint,
    );
    // Bottom wall cap with school entrance mat in the middle (708..828)
    canvas.drawRect(
      const Rect.fromLTWH(0, kLobbyWorldHeight - 24, 704, 24),
      wallCapPaint,
    );
    canvas.drawRect(
      const Rect.fromLTWH(832, kLobbyWorldHeight - 24, 704, 24),
      wallCapPaint,
    );
    // School Lobby Entrance Threshold Mat (Bottom Center)
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(708, kLobbyWorldHeight - 26, 120, 22),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF0F766E),
    );
  }

  void _paintZoneFloorDecals(Canvas canvas) {
    // Subtle zone floor title plaques for the 5 expanded campus wings
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
      text: '🛋️ STUDENT LOUNGE & STUDY COMMONS',
      center: const Offset(416, 420),
      color: const Color(0xFF059669),
    );
    _drawFloorPlaque(
      canvas,
      text: '💎 REVIEWER TREASURE VAULT',
      center: const Offset(1168, 568),
      color: const Color(0xFF9333EA),
    );

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
    // Path breadcrumbs when Tap-to-Walk is active
    if (activePath.isNotEmpty) {
      final pathPaint = Paint()
        ..color = const Color(0xFF38BDF8).withOpacity(0.55)
        ..style = PaintingStyle.fill;
      for (final wp in activePath) {
        canvas.drawCircle(wp, 3.5, pathPaint);
      }
    }

    // Tap target ring (`pulseTile` from `MovementManager.ts`)
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
      // Idle facing down (frame 18..23)
      final frameIdx = computeCharacterFrameIndex(
        facing: AvatarFacing.down,
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
      // Ground shadow
      canvas.drawOval(
        Rect.fromCenter(center: Offset(npc.x, npc.y + 4), width: 22, height: 8),
        Paint()..color = Colors.black.withOpacity(0.28),
      );
      canvas.drawImageRect(sheet, src, dst, pixelPaint);
    }

    // Floating NPC Nameplate
    _drawFloatingNameplate(
      canvas,
      anchor: Offset(npc.x, npc.y - 54),
      name: npc.name,
      roleTag: npc.roleTag,
      isGoldTag: npc.isGoldTag,
      badgeIcon: npc.id == 'npc_receptionist'
          ? '✨'
          : (npc.id == 'npc_teacher' ? '🎓' : '📚'),
    );
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

    // 1. Chest Ground Shadow & Glow
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

    // 2. Pixel Art Large Ornate Treasure Chest (36x28 px)
    final chestRect =
        Rect.fromCenter(center: Offset(pos.dx, pos.dy - 6), width: 38, height: 28);
    // Outer dark pixel border
    canvas.drawRRect(
      RRect.fromRectAndRadius(chestRect.inflate(1.5), const Radius.circular(4)),
      Paint()..color = const Color(0xFF1E1B18),
    );
    // Rich timber base
    canvas.drawRRect(
      RRect.fromRectAndRadius(chestRect, const Radius.circular(3)),
      Paint()..color = const Color(0xFF78350F),
    );
    // Chest lid (top half tinted with subject color + gold trim)
    final lidRect = Rect.fromLTWH(
        chestRect.left, chestRect.top, chestRect.width, chestRect.height * 0.48);
    canvas.drawRRect(
      RRect.fromRectAndRadius(lidRect, const Radius.circular(3)),
      Paint()
        ..color = Color.lerp(const Color(0xFF92400E), subjectColor, 0.38)!,
    );
    // Gold vertical bands
    final goldPaint = Paint()..color = const Color(0xFFFACC15);
    canvas.drawRect(
      Rect.fromLTWH(chestRect.left + 5, chestRect.top, 4, chestRect.height),
      goldPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(chestRect.right - 9, chestRect.top, 4, chestRect.height),
      goldPaint,
    );
    // Gold horizontal seam & center lock plate
    canvas.drawRect(
      Rect.fromLTWH(
          chestRect.left, chestRect.top + 12, chestRect.width, 3),
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

    // 3. Permanent Floating Pixel Banner Directly Above the Chest
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
    // Banner shadow
    canvas.drawRRect(
      bannerRect.shift(const Offset(0, 2)),
      Paint()..color = Colors.black.withOpacity(0.5),
    );
    // Banner fill & subject color border
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

  /// Renders a Small Mystery Chest (`small_chest_1..4`) with either:
  /// - Closed chest sprite + bobbing `✨ ?` indicator overhead (when ready), OR
  /// - Open chest sprite + live cooldown timer (`1:45`) overhead (when on 2-min cooldown).
  void _drawSmallMysteryChest(
    Canvas canvas, {
    required InteractiveZone zone,
    required int remainingCooldownSec,
    required bool isHighlighted,
  }) {
    final pos = zone.center;
    final isOnCooldown = remainingCooldownSec > 0;
    final bob = math.sin((animTick + pos.dy) * 0.35) * 2.0;

    // Shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(pos.dx, pos.dy + 4), width: 28, height: 10),
      Paint()..color = Colors.black.withOpacity(0.38),
    );

    final boxRect =
        Rect.fromCenter(center: Offset(pos.dx, pos.dy - 4), width: 24, height: 18);

    // Outer pixel outline
    canvas.drawRRect(
      RRect.fromRectAndRadius(boxRect.inflate(1.2), const Radius.circular(3)),
      Paint()..color = const Color(0xFF1E1B18),
    );

    if (isOnCooldown) {
      // OPEN CHEST SPRITE (dark interior + tilted open lid behind)
      final openLid =
          Rect.fromLTWH(boxRect.left, boxRect.top - 6, boxRect.width, 8);
      canvas.drawRRect(
        RRect.fromRectAndRadius(openLid, const Radius.circular(2)),
        Paint()..color = const Color(0xFF6B7280),
      );
      // Dark interior hollow
      canvas.drawRect(
        Rect.fromLTWH(boxRect.left + 2, boxRect.top, boxRect.width - 4, 7),
        Paint()..color = const Color(0xFF111827),
      );
      // Lower wooden base
      canvas.drawRect(
        Rect.fromLTWH(
            boxRect.left, boxRect.top + 7, boxRect.width, boxRect.height - 7),
        Paint()..color = const Color(0xFF78350F),
      );

      // Cooldown timer tag overhead
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
      // CLOSED MYSTERY CHEST SPRITE (purple-gold RPG mini chest + sparkling `✨ ?`)
      canvas.drawRRect(
        RRect.fromRectAndRadius(boxRect, const Radius.circular(2.5)),
        Paint()..color = const Color(0xFF6D28D9),
      );
      // Gold trim & clasp
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

      // Bobbing `✨ ?` overhead indicator
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
    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(playerPos.dx, playerPos.dy + 4), width: 24, height: 9),
      Paint()..color = Colors.black.withOpacity(0.35),
    );

    if (playerSheet != null) {
      final frameIdx = computeCharacterFrameIndex(
        facing: playerFacing,
        isWalking: playerIsWalking,
        stepFrame: animTick % kCharFramesPerDirection,
      );
      final src = Rect.fromLTWH(
        frameIdx * kCharFrameWidth,
        0,
        kCharFrameWidth,
        kCharFrameHeight,
      );
      final dst = Rect.fromLTWH(
        playerPos.dx - kCharFrameWidth / 2,
        playerPos.dy - kCharFrameHeight + 8,
        kCharFrameWidth,
        kCharFrameHeight,
      );
      canvas.drawImageRect(playerSheet!, src, dst, pixelPaint);
    }

    // Floating Nameplate at `TAG_OFFSET_Y = -52` (recycled from `PlayerManager.ts` / `SceneLabel.ts`)
    _drawFloatingNameplate(
      canvas,
      anchor: Offset(playerPos.dx, playerPos.dy - 54),
      name: playerName,
      roleTag: isFaculty ? 'Teacher' : 'Student',
      isGoldTag: isFaculty,
      badgeIcon: equippedBadgeIcon,
    );

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
