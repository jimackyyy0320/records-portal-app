import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../spritecast_engine.dart';

/// Base pixel tile dimension in world units (`16×16` classic Metroidvania tile grid).
/// Paired with the `320×180` pixel-perfect reference viewport (`20 × 11.25` visible tiles),
/// giving Silksong / Terraria cavern scale with crisp readability on mobile screens.
const double kDungeonTileSize = 16.0;

/// Pixel-perfect reference viewport dimensions (`2d-pixel-perfect` standard 16:9).
const double kDungeonRefWidth = 320.0;
const double kDungeonRefHeight = 180.0;

/// All 19 architectural, traversal, hazard, and interactive dungeon tile types.
enum DungeonTileType {
  empty, // '.' — open walkable air
  solidStone, // '#' — auto-tiled solid cavern stone / brickwork
  mossyStone, // 'M' — solid stone with lush era foliage/moss top cap
  oneWayBridge, // '=' — semi-solid wooden platform (jump up through, press Down+Jump to drop)
  ladderVine, // 'H' — climbable bamboo ladder / hanging vine / iron chain
  spikes, // '^' — sharp thorns/bayonets/spikes (pogo-bounceable with downward slash!)
  crumbleBlock, // 'C' — fragile ledge that shakes and collapses 0.45s after stepping on it
  pogoLantern, // 'O' — suspended iron lantern/ring that resets air-dash when pogo-slashed
  grappleRing, // 'G' — brass silk-needle grapple anchor point across wide chasms
  breakableCrate, // 'X' — wooden supply crate/urn that shatters for Shards & Health Orbs
  crystalVein, // '*' — Terraria-style glowing shard crystal vein (3 hits to mine Shards!)
  switchPedestal, // 'S' — constitutional chime switch that opens a Locked Charter Gate
  lockedGate, // 'D' — heavy iron Charter Gate blocking passage until room switch is struck
  campfireBench, // 'B' — Bahay-Pulungan Sanctuary Bench (save, heal, equip Charms, craft)
  loreTablet, // 'L' — glowing Saligang Tala stone inscription unlocking Codex knowledge
  treasureChest, // 'K' — ornate dungeon chest holding Relic Shards or new Charms
  roomPortal, // 'P' — doorway/archway transitioning to an adjacent chamber
  wallTorch, // 'T' — flickering wall sconce casting SpriteCast stepped pixel light
  secretWall, // '?' — cracked hidden wall (looks solid until slashed 2x, revealing secrets!)
}

extension DungeonTileTypeX on DungeonTileType {
  /// Returns `true` if this tile blocks full 4-sided AABB movement.
  bool get isFullSolid =>
      this == DungeonTileType.solidStone ||
      this == DungeonTileType.mossyStone ||
      this == DungeonTileType.crumbleBlock ||
      this == DungeonTileType.lockedGate ||
      this == DungeonTileType.secretWall;

  /// Returns `true` if this tile is a semi-solid one-way platform.
  bool get isOneWay => this == DungeonTileType.oneWayBridge;

  /// Returns `true` if the player can climb vertically on this tile.
  bool get isClimbable => this == DungeonTileType.ladderVine;

  /// Returns `true` if touching this tile without i-frames inflicts hazard damage.
  bool get isHazard => this == DungeonTileType.spikes;

  /// Returns `true` if a downward slash bounces the player upward (Silksong pogo!).
  bool get isPogoTarget =>
      this == DungeonTileType.spikes || this == DungeonTileType.pogoLantern;

  /// Returns `true` if this tile can be struck by melee attacks to break or trigger.
  bool get isStrikeable =>
      this == DungeonTileType.breakableCrate ||
      this == DungeonTileType.crystalVein ||
      this == DungeonTileType.switchPedestal ||
      this == DungeonTileType.secretWall ||
      this == DungeonTileType.pogoLantern;

  /// Returns `true` if this tile emits dynamic warm/cool cavern light.
  bool get isLightSource =>
      this == DungeonTileType.wallTorch ||
      this == DungeonTileType.campfireBench ||
      this == DungeonTileType.pogoLantern ||
      this == DungeonTileType.crystalVein ||
      this == DungeonTileType.loreTablet;
}

/// Parses an ASCII map character into a [DungeonTileType].
DungeonTileType dungeonTileFromChar(String ch) {
  switch (ch) {
    case '#':
      return DungeonTileType.solidStone;
    case 'M':
      return DungeonTileType.mossyStone;
    case '=':
      return DungeonTileType.oneWayBridge;
    case 'H':
      return DungeonTileType.ladderVine;
    case '^':
      return DungeonTileType.spikes;
    case 'C':
      return DungeonTileType.crumbleBlock;
    case 'O':
      return DungeonTileType.pogoLantern;
    case 'G':
      return DungeonTileType.grappleRing;
    case 'X':
      return DungeonTileType.breakableCrate;
    case '*':
      return DungeonTileType.crystalVein;
    case 'S':
      return DungeonTileType.switchPedestal;
    case 'D':
      return DungeonTileType.lockedGate;
    case 'B':
      return DungeonTileType.campfireBench;
    case 'L':
      return DungeonTileType.loreTablet;
    case 'K':
      return DungeonTileType.treasureChest;
    case 'P':
      return DungeonTileType.roomPortal;
    case 'T':
      return DungeonTileType.wallTorch;
    case '?':
      return DungeonTileType.secretWall;
    default:
      return DungeonTileType.empty;
  }
}

/// Era-specific visual theme strictly derived from SpriteCast `ENDESGA-32` / `Sweetie-16`
/// palettes (`craft-game-floors` Art Direction Floor).
class DungeonEraTheme {
  final int actNumber;
  final String eraTitle;
  final String yearSpan;
  final Color skyTop;
  final Color skyBottom;
  final Color parallaxFar;
  final Color parallaxMid;
  final Color stoneLight;
  final Color stoneMid;
  final Color stoneDark;
  final Color mossOrTrim;
  final Color torchGlow;
  final Color accentHighlight;
  final double cavernDarknessAlpha;

  const DungeonEraTheme({
    required this.actNumber,
    required this.eraTitle,
    required this.yearSpan,
    required this.skyTop,
    required this.skyBottom,
    required this.parallaxFar,
    required this.parallaxMid,
    required this.stoneLight,
    required this.stoneMid,
    required this.stoneDark,
    required this.mossOrTrim,
    required this.torchGlow,
    required this.accentHighlight,
    this.cavernDarknessAlpha = 0.42,
  });
}

/// Curated 7-Era Dungeon Palettes rooted in SpriteCast `ENDESGA-32` & `Sweetie-16`.
final List<DungeonEraTheme> kDungeonEraThemes = <DungeonEraTheme>[
  // Act I: Pre-Colonial Balangay Sea-Caves (Emerald / Torch Amber)
  DungeonEraTheme(
    actNumber: 1,
    eraTitle: 'Balangay Sea-Caverns',
    yearSpan: 'c. 1500 • Pre-Colonial Barangay',
    skyTop: SpriteCastPalette.endesga32[15],
    skyBottom: SpriteCastPalette.endesga32[14],
    parallaxFar: const Color(0xFF132D30),
    parallaxMid: const Color(0xFF1B433E),
    stoneLight: SpriteCastPalette.endesga32[3],
    stoneMid: SpriteCastPalette.endesga32[4],
    stoneDark: SpriteCastPalette.endesga32[5],
    mossOrTrim: SpriteCastPalette.endesga32[12],
    torchGlow: SpriteCastPalette.endesga32[10],
    accentHighlight: SpriteCastPalette.endesga32[11],
    cavernDarknessAlpha: 0.34,
  ),
  // Act II: Intramuros Belltower Bastion (Terracotta / Midnight Slate)
  DungeonEraTheme(
    actNumber: 2,
    eraTitle: 'Intramuros Belltower Bastion',
    yearSpan: '1571–1896 • Spanish Centralization',
    skyTop: SpriteCastPalette.endesga32[25],
    skyBottom: SpriteCastPalette.endesga32[24],
    parallaxFar: const Color(0xFF1F2238),
    parallaxMid: const Color(0xFF312A3E),
    stoneLight: SpriteCastPalette.endesga32[21],
    stoneMid: SpriteCastPalette.endesga32[22],
    stoneDark: SpriteCastPalette.endesga32[23],
    mossOrTrim: SpriteCastPalette.endesga32[0],
    torchGlow: SpriteCastPalette.endesga32[9],
    accentHighlight: SpriteCastPalette.endesga32[10],
    cavernDarknessAlpha: 0.46,
  ),
  // Act III: Barasoain Charter Catacombs (Candle Gold / Parchment Stone)
  DungeonEraTheme(
    actNumber: 3,
    eraTitle: 'Barasoain Charter Catacombs',
    yearSpan: '1898–1899 • Malolos Republic',
    skyTop: const Color(0xFF231826),
    skyBottom: SpriteCastPalette.endesga32[6],
    parallaxFar: const Color(0xFF33212C),
    parallaxMid: const Color(0xFF4B2D33),
    stoneLight: SpriteCastPalette.endesga32[2],
    stoneMid: SpriteCastPalette.endesga32[31],
    stoneDark: SpriteCastPalette.endesga32[5],
    mossOrTrim: SpriteCastPalette.endesga32[10],
    torchGlow: SpriteCastPalette.endesga32[11],
    accentHighlight: SpriteCastPalette.endesga32[8],
    cavernDarknessAlpha: 0.40,
  ),
  // Act IV: Jones Bridge Sky-Citadel (Azure Steel / Art Deco Brass)
  DungeonEraTheme(
    actNumber: 4,
    eraTitle: 'Commonwealth Sky-Citadel',
    yearSpan: '1902–1941 • American & Commonwealth Era',
    skyTop: SpriteCastPalette.endesga32[24],
    skyBottom: SpriteCastPalette.endesga32[16],
    parallaxFar: const Color(0xFF1A3A63),
    parallaxMid: const Color(0xFF2C4D75),
    stoneLight: SpriteCastPalette.endesga32[20],
    stoneMid: SpriteCastPalette.endesga32[21],
    stoneDark: SpriteCastPalette.endesga32[23],
    mossOrTrim: SpriteCastPalette.endesga32[17],
    torchGlow: SpriteCastPalette.endesga32[18],
    accentHighlight: SpriteCastPalette.endesga32[11],
    cavernDarknessAlpha: 0.28,
  ),
  // Act V: Corregidor Malinta Tunnels (Ash Concrete / Crimson Alert)
  DungeonEraTheme(
    actNumber: 5,
    eraTitle: 'Malinta War Tunnels',
    yearSpan: '1942–1945 • Wartime Occupation',
    skyTop: SpriteCastPalette.endesga32[25],
    skyBottom: const Color(0xFF281F26),
    parallaxFar: const Color(0xFF2B242B),
    parallaxMid: const Color(0xFF3B3238),
    stoneLight: SpriteCastPalette.endesga32[21],
    stoneMid: SpriteCastPalette.endesga32[22],
    stoneDark: SpriteCastPalette.endesga32[24],
    mossOrTrim: SpriteCastPalette.endesga32[7],
    torchGlow: SpriteCastPalette.endesga32[8],
    accentHighlight: SpriteCastPalette.endesga32[9],
    cavernDarknessAlpha: 0.56,
  ),
  // Act VI: Obsidian Censor Vault (Deep Plum / Neon Cyan Searchlights)
  DungeonEraTheme(
    actNumber: 6,
    eraTitle: 'Obsidian Censor Vault',
    yearSpan: '1972–1986 • Martial Law & Resistance',
    skyTop: SpriteCastPalette.endesga32[25],
    skyBottom: SpriteCastPalette.endesga32[27],
    parallaxFar: const Color(0xFF251A36),
    parallaxMid: const Color(0xFF39234D),
    stoneLight: SpriteCastPalette.endesga32[22],
    stoneMid: SpriteCastPalette.endesga32[23],
    stoneDark: SpriteCastPalette.endesga32[25],
    mossOrTrim: SpriteCastPalette.endesga32[28],
    torchGlow: SpriteCastPalette.endesga32[18],
    accentHighlight: SpriteCastPalette.endesga32[26],
    cavernDarknessAlpha: 0.54,
  ),
  // Act VII: Altar of the 1987 Sovereign Sun (Radiant Gold / Royal Indigo)
  DungeonEraTheme(
    actNumber: 7,
    eraTitle: 'Spire of the Sovereign Sun',
    yearSpan: '1987–Present • People Power Constitution',
    skyTop: SpriteCastPalette.endesga32[24],
    skyBottom: SpriteCastPalette.endesga32[16],
    parallaxFar: const Color(0xFF273668),
    parallaxMid: const Color(0xFF423D70),
    stoneLight: SpriteCastPalette.endesga32[2],
    stoneMid: SpriteCastPalette.endesga32[3],
    stoneDark: SpriteCastPalette.endesga32[5],
    mossOrTrim: SpriteCastPalette.endesga32[10],
    torchGlow: SpriteCastPalette.endesga32[11],
    accentHighlight: SpriteCastPalette.endesga32[11],
    cavernDarknessAlpha: 0.22,
  ),
];

DungeonEraTheme dungeonThemeForAct(int actNumber) {
  final idx = (actNumber - 1).clamp(0, kDungeonEraThemes.length - 1);
  return kDungeonEraThemes[idx];
}

/// Doorway connecting two chambers in a multi-room Metroidvania dungeon.
class DungeonRoomExit {
  final int col;
  final int row;
  final String targetRoomId;
  final int targetSpawnCol;
  final int targetSpawnRow;
  final String label;
  final bool requiresBossDefeat;

  const DungeonRoomExit({
    required this.col,
    required this.row,
    required this.targetRoomId,
    required this.targetSpawnCol,
    required this.targetSpawnRow,
    required this.label,
    this.requiresBossDefeat = false,
  });
}

/// Enemy placement descriptor inside a chamber.
class DungeonEnemySpawnSpec {
  final String spawnId;
  final String archetypeId;
  final int col;
  final int row;
  final int patrolRadiusTiles;

  const DungeonEnemySpawnSpec({
    required this.spawnId,
    required this.archetypeId,
    required this.col,
    required this.row,
    this.patrolRadiusTiles = 4,
  });
}

/// Static blueprint for one interconnected Metroidvania dungeon chamber.
class DungeonChamberSpec {
  final String id;
  final int actNumber;
  final String title;
  final String subtitle;
  final List<String> asciiGrid; // rows of equal-length tile characters
  final int defaultSpawnCol;
  final int defaultSpawnRow;
  final List<DungeonRoomExit> exits;
  final List<DungeonEnemySpawnSpec> enemySpawns;
  final String? bossId;
  final int bossSpawnCol;
  final int bossSpawnRow;
  final List<String> loreTabletIds;
  final List<String> chestRewardIds;
  final bool isDarkCavern;
  final bool isBossArena;
  final bool isBenchSanctuary;
  final int minimapCol;
  final int minimapRow;

  const DungeonChamberSpec({
    required this.id,
    required this.actNumber,
    required this.title,
    required this.subtitle,
    required this.asciiGrid,
    required this.defaultSpawnCol,
    required this.defaultSpawnRow,
    this.exits = const <DungeonRoomExit>[],
    this.enemySpawns = const <DungeonEnemySpawnSpec>[],
    this.bossId,
    this.bossSpawnCol = 0,
    this.bossSpawnRow = 0,
    this.loreTabletIds = const <String>[],
    this.chestRewardIds = const <String>[],
    this.isDarkCavern = false,
    this.isBossArena = false,
    this.isBenchSanctuary = false,
    this.minimapCol = 0,
    this.minimapRow = 0,
  });

  int get rows => asciiGrid.length;
  int get cols => asciiGrid.isEmpty ? 0 : asciiGrid.first.length;
  double get worldWidth => cols * kDungeonTileSize;
  double get worldHeight => rows * kDungeonTileSize;

  DungeonTileType tileAt(int col, int row) {
    if (row < 0 || row >= rows) return DungeonTileType.solidStone;
    final line = asciiGrid[row];
    if (col < 0 || col >= line.length) return DungeonTileType.solidStone;
    return dungeonTileFromChar(line[col]);
  }
}

/// Runtime state of a fragile crumble tile (`C`) in the active chamber.
class CrumbleTileState {
  final int col;
  final int row;
  double shakeTimer; // > 0 while trembling before collapse
  double respawnTimer; // > 0 while collapsed and awaiting respawn
  bool collapsed;

  CrumbleTileState({
    required this.col,
    required this.row,
    this.shakeTimer = 0.0,
    this.respawnTimer = 0.0,
    this.collapsed = false,
  });

  String get key => '${col}_$row';
}

/// Runtime state of a breakable crate (`X`), crystal vein (`*`), switch (`S`),
/// or secret wall (`?`) inside the active chamber.
class BreakableTileState {
  final int col;
  final int row;
  final DungeonTileType kind;
  int hp;
  bool brokenOrTriggered;
  double hitFlashTimer;

  BreakableTileState({
    required this.col,
    required this.row,
    required this.kind,
    required this.hp,
    this.brokenOrTriggered = false,
    this.hitFlashTimer = 0.0,
  });

  String get key => '${col}_$row';
}

/// Terraria-style physical loot pickup dropped by crates, crystal veins, and enemies.
enum DungeonLootKind {
  archipelagoShard, // Currency for Blade upgrades & Charm crafting
  resolveOrb, // Restores 1 Resolve Mask HP
  silkMote, // Restores +18 Civic Silk
  relicFragment, // Rare bonus shards (+15)
}

class DungeonLootDrop {
  final String id;
  final DungeonLootKind kind;
  final int amount;
  double x;
  double y;
  double vx;
  double vy;
  double ageSec;
  bool collected;

  DungeonLootDrop({
    required this.id,
    required this.kind,
    required this.amount,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.ageSec = 0.0,
    this.collected = false,
  });
}

/// Mutable runtime tile overlay layer for the currently loaded chamber
/// (tracks collapsed crumble blocks, opened gates, broken secret walls & crates).
class DungeonChamberRuntime {
  final DungeonChamberSpec spec;
  final Map<String, CrumbleTileState> crumbleBlocks = <String, CrumbleTileState>{};
  final Map<String, BreakableTileState> breakables = <String, BreakableTileState>{};
  final List<DungeonLootDrop> lootDrops = <DungeonLootDrop>[];
  bool roomGateUnlocked;
  bool bossDefeatedInRoom;

  DungeonChamberRuntime(
    this.spec, {
    Set<String> alreadyBrokenKeys = const <String>{},
    this.roomGateUnlocked = false,
    this.bossDefeatedInRoom = false,
  }) {
    for (var r = 0; r < spec.rows; r++) {
      for (var c = 0; c < spec.cols; c++) {
        final t = spec.tileAt(c, r);
        final key = '${c}_$r';
        if (t == DungeonTileType.crumbleBlock) {
          crumbleBlocks[key] = CrumbleTileState(col: c, row: r);
        } else if (t == DungeonTileType.breakableCrate) {
          breakables[key] = BreakableTileState(
            col: c,
            row: r,
            kind: t,
            hp: 1,
            brokenOrTriggered: alreadyBrokenKeys.contains('${spec.id}:$key'),
          );
        } else if (t == DungeonTileType.crystalVein) {
          breakables[key] = BreakableTileState(
            col: c,
            row: r,
            kind: t,
            hp: 3,
            brokenOrTriggered: alreadyBrokenKeys.contains('${spec.id}:$key'),
          );
        } else if (t == DungeonTileType.secretWall) {
          breakables[key] = BreakableTileState(
            col: c,
            row: r,
            kind: t,
            hp: 2,
            brokenOrTriggered: alreadyBrokenKeys.contains('${spec.id}:$key'),
          );
        } else if (t == DungeonTileType.switchPedestal) {
          breakables[key] = BreakableTileState(
            col: c,
            row: r,
            kind: t,
            hp: 1,
            brokenOrTriggered: roomGateUnlocked,
          );
        }
      }
    }
  }

  /// Resolves the live effective [DungeonTileType] at `(col, row)`, accounting
  /// for collapsed crumble blocks, unlocked gates, and broken secret walls/crates.
  DungeonTileType effectiveTileAt(int col, int row) {
    final base = spec.tileAt(col, row);
    final key = '${col}_$row';
    if (base == DungeonTileType.crumbleBlock) {
      final st = crumbleBlocks[key];
      if (st != null && st.collapsed) return DungeonTileType.empty;
    } else if (base == DungeonTileType.lockedGate) {
      if (roomGateUnlocked) return DungeonTileType.empty;
    } else if (base == DungeonTileType.secretWall ||
        base == DungeonTileType.breakableCrate ||
        base == DungeonTileType.crystalVein) {
      final st = breakables[key];
      if (st != null && st.brokenOrTriggered) return DungeonTileType.empty;
    }
    return base;
  }

  bool isSolidAt(int col, int row) => effectiveTileAt(col, row).isFullSolid;
}

/// Upgradeable Blade / Needle Tiers forged at Bahay-Pulungan Benches.
enum DungeonBladeTier {
  bambooSpear, // Tier 0 — Starter (10 dmg)
  kampilanEdge, // Tier 1 — Forged (15 dmg, 45 Shards)
  malolosSteel, // Tier 2 — Forged (22 dmg, 110 Shards)
  sovereignGold, // Tier 3 — Masterwork (32 dmg, 210 Shards)
}

extension DungeonBladeTierX on DungeonBladeTier {
  String get displayName {
    switch (this) {
      case DungeonBladeTier.bambooSpear:
        return 'Balangay Needle';
      case DungeonBladeTier.kampilanEdge:
        return 'Kampilan Silk-Blade';
      case DungeonBladeTier.malolosSteel:
        return 'Malolos Tempered Steel';
      case DungeonBladeTier.sovereignGold:
        return 'Sovereign Sun-Needle';
    }
  }

  int get baseDamage {
    switch (this) {
      case DungeonBladeTier.bambooSpear:
        return 10;
      case DungeonBladeTier.kampilanEdge:
        return 15;
      case DungeonBladeTier.malolosSteel:
        return 22;
      case DungeonBladeTier.sovereignGold:
        return 32;
    }
  }

  double get reachBonusPx {
    switch (this) {
      case DungeonBladeTier.bambooSpear:
        return 0.0;
      case DungeonBladeTier.kampilanEdge:
        return 3.0;
      case DungeonBladeTier.malolosSteel:
        return 6.0;
      case DungeonBladeTier.sovereignGold:
        return 10.0;
    }
  }

  int get upgradeShardCost {
    switch (this) {
      case DungeonBladeTier.bambooSpear:
        return 0;
      case DungeonBladeTier.kampilanEdge:
        return 45;
      case DungeonBladeTier.malolosSteel:
        return 110;
      case DungeonBladeTier.sovereignGold:
        return 210;
    }
  }

  Color get slashArcColor {
    switch (this) {
      case DungeonBladeTier.bambooSpear:
        return SpriteCastPalette.endesga32[2]; // warm ivory silk
      case DungeonBladeTier.kampilanEdge:
        return SpriteCastPalette.endesga32[18]; // bright cyan steel
      case DungeonBladeTier.malolosSteel:
        return SpriteCastPalette.endesga32[10]; // amber steel
      case DungeonBladeTier.sovereignGold:
        return SpriteCastPalette.endesga32[11]; // radiant gold
    }
  }
}

/// The 5 Unlockable Constitutional Silk Skills (cast using the Civic Silk Spool).
enum DungeonSilkSkillId {
  sanduguanThread, // Blazing dash-pierce through enemies
  silkBind, // Focused golden heal restoring 35% Resolve HP
  scalesTempest, // Spinning AoE whirlwind deflecting projectiles
  habeasAegis, // Timed 0.25s Parry Shield triggering golden counter-freeze
  sovereignSunburst, // Screen-wide ultimate constitutional beam
}

class DungeonSilkSkillSpec {
  final DungeonSilkSkillId id;
  final String name;
  final String constitutionalSubtitle;
  final String description;
  final int silkCost;
  final double cooldownSec;
  final double damageMultiplier;
  final int unlockAct;
  final Color fxColor;

  const DungeonSilkSkillSpec({
    required this.id,
    required this.name,
    required this.constitutionalSubtitle,
    required this.description,
    required this.silkCost,
    required this.cooldownSec,
    required this.damageMultiplier,
    required this.unlockAct,
    required this.fxColor,
  });
}

const List<DungeonSilkSkillSpec> kDungeonSilkSkills = <DungeonSilkSkillSpec>[
  DungeonSilkSkillSpec(
    id: DungeonSilkSkillId.sanduguanThread,
    name: 'Sanduguan Thread',
    constitutionalSubtitle: 'Pre-Colonial Blood Pact Lunge',
    description:
        'Unleash a blazing crimson needle-lunge that pierces armored foes with brief invulnerability.',
    silkCost: 24,
    cooldownSec: 0.75,
    damageMultiplier: 2.1,
    unlockAct: 1,
    fxColor: Color(0xFFF77622),
  ),
  DungeonSilkSkillSpec(
    id: DungeonSilkSkillId.silkBind,
    name: 'Silk Bind',
    constitutionalSubtitle: 'Babaylan Focus & Restoration',
    description:
        'Weave golden silk threads around Alon to restore 2 Resolve Masks (works grounded or mid-air!).',
    silkCost: 33,
    cooldownSec: 1.0,
    damageMultiplier: 0.0,
    unlockAct: 1,
    fxColor: Color(0xFF63C74D),
  ),
  DungeonSilkSkillSpec(
    id: DungeonSilkSkillId.scalesTempest,
    name: 'Scales Tempest',
    constitutionalSubtitle: 'Checks & Balances Cyclone',
    description:
        'Spin twin azure silk arcs around Alon, shredding nearby foes and deflecting enemy projectiles.',
    silkCost: 30,
    cooldownSec: 1.15,
    damageMultiplier: 2.4,
    unlockAct: 2,
    fxColor: Color(0xFF2CE8F5),
  ),
  DungeonSilkSkillSpec(
    id: DungeonSilkSkillId.habeasAegis,
    name: 'Habeas Aegis',
    constitutionalSubtitle: 'Art. III Due Process Parry',
    description:
        'Raise a 0.25s emerald counter-ward. Blocking an attack triggers a Golden Parry Freeze and massive blast!',
    silkCost: 20,
    cooldownSec: 0.9,
    damageMultiplier: 3.0,
    unlockAct: 3,
    fxColor: Color(0xFF38B764),
  ),
  DungeonSilkSkillSpec(
    id: DungeonSilkSkillId.sovereignSunburst,
    name: 'Sovereign Sunburst',
    constitutionalSubtitle: 'Art. II Sec. 1 • Ultimate Art',
    description:
        'Channel all seven Charter Seals into a blazing horizontal beam of constitutional radiance!',
    silkCost: 55,
    cooldownSec: 2.2,
    damageMultiplier: 4.2,
    unlockAct: 5,
    fxColor: Color(0xFFFEE761),
  ),
];

DungeonSilkSkillSpec silkSkillSpecFor(DungeonSilkSkillId id) {
  return kDungeonSilkSkills.firstWhere((s) => s.id == id);
}

/// Hollow Knight / Silksong-style Charm / Talisman equipped at Bahay-Pulungan Benches.
class DungeonCharmSpec {
  final String id;
  final String name;
  final String description;
  final int notchCost;
  final int craftShardCost;
  final Color badgeColor;

  const DungeonCharmSpec({
    required this.id,
    required this.name,
    required this.description,
    required this.notchCost,
    required this.craftShardCost,
    required this.badgeColor,
  });
}

const List<DungeonCharmSpec> kDungeonCharmCatalog = <DungeonCharmSpec>[
  DungeonCharmSpec(
    id: 'quick_slash_bolo',
    name: 'Quick-Slash Bolo',
    description: 'Reduces melee slash cooldown by 28% for rapid combo chains.',
    notchCost: 2,
    craftShardCost: 35,
    badgeColor: Color(0xFFE43B44),
  ),
  DungeonCharmSpec(
    id: 'long_needle',
    name: 'Long-Needle Reach',
    description: 'Extends sword & pogo-slash reach by +30% for safer spacing.',
    notchCost: 2,
    craftShardCost: 40,
    badgeColor: Color(0xFF0099DB),
  ),
  DungeonCharmSpec(
    id: 'babaylan_bind',
    name: 'Babaylan Fast-Bind',
    description: 'Silk Bind weaves 35% faster and restores +1 bonus Resolve Mask.',
    notchCost: 2,
    craftShardCost: 50,
    badgeColor: Color(0xFF63C74D),
  ),
  DungeonCharmSpec(
    id: 'tarsier_lantern',
    name: 'Tarsier Lantern Sight',
    description: 'Expands Umalo\'s cavern light radius by +45% & reveals nearby secret walls.',
    notchCost: 1,
    craftShardCost: 25,
    badgeColor: Color(0xFFFEE761),
  ),
  DungeonCharmSpec(
    id: 'magnet_shard',
    name: 'Archipelago Magnet',
    description: 'Pulls dropped Shards and Silk Motes toward Alon from across the room.',
    notchCost: 1,
    craftShardCost: 20,
    badgeColor: Color(0xFFFEAE34),
  ),
  DungeonCharmSpec(
    id: 'iron_parry_crest',
    name: 'Iron Parry Crest',
    description: 'Widens Habeas Aegis parry window to 0.36s and boosts counter blast by +35%.',
    notchCost: 2,
    craftShardCost: 55,
    badgeColor: Color(0xFF38B764),
  ),
  DungeonCharmSpec(
    id: 'double_pogo_boots',
    name: 'Wind-Step Anklets',
    description: 'Grants an extra mid-air Double Jump and +12% movement agility.',
    notchCost: 3,
    craftShardCost: 75,
    badgeColor: Color(0xFF2CE8F5),
  ),
  DungeonCharmSpec(
    id: 'scholars_silk',
    name: "Scholar's Silk Spool",
    description: 'Every melee strike generates +40% extra Civic Silk.',
    notchCost: 2,
    craftShardCost: 45,
    badgeColor: Color(0xFFB55088),
  ),
  DungeonCharmSpec(
    id: 'charter_ward',
    name: 'Charter Stalwart Ward',
    description: 'Extends post-damage invulnerability by +0.55s and dampens knockback.',
    notchCost: 1,
    craftShardCost: 30,
    badgeColor: Color(0xFF8B9BB4),
  ),
  DungeonCharmSpec(
    id: 'sovereign_heart',
    name: 'Sovereign Heart',
    description: 'Grants +2 bonus Maximum Resolve Masks while equipped.',
    notchCost: 3,
    craftShardCost: 90,
    badgeColor: Color(0xFFFF0044),
  ),
];

/// Frame-by-frame control input snapshot (shared by Mobile Touch Controls & Keyboard).
class DungeonPlayerInput {
  final double moveX; // -1.0 .. +1.0
  final double moveY; // -1.0 (up) .. +1.0 (down)
  final bool jumpHeld;
  final bool jumpJustPressed;
  final bool jumpJustReleased;
  final bool dashJustPressed;
  final bool slashJustPressed;
  final bool skillJustPressed;
  final bool grappleJustPressed;
  final bool healHeld;
  final bool interactJustPressed;

  const DungeonPlayerInput({
    this.moveX = 0.0,
    this.moveY = 0.0,
    this.jumpHeld = false,
    this.jumpJustPressed = false,
    this.jumpJustReleased = false,
    this.dashJustPressed = false,
    this.slashJustPressed = false,
    this.skillJustPressed = false,
    this.grappleJustPressed = false,
    this.healHeld = false,
    this.interactJustPressed = false,
  });

  bool get dropThroughRequested => moveY > 0.55 && jumpJustPressed;
}

/// Ghost trail sample captured during Silk Dash for Silksong-style afterimages.
class DashAfterimage {
  final double x;
  final double y;
  final int facing;
  double alpha;

  DashAfterimage({
    required this.x,
    required this.y,
    required this.facing,
    this.alpha = 0.65,
  });
}

/// Complete live kinematics, combat resource, & game-feel animation state for Alon.
class DungeonPlayerPhysicsState {
  // Position (top-left of Alon's AABB collider in world pixels)
  double x;
  double y;
  final double width;
  final double height;

  // Velocity (world px/sec)
  double vx;
  double vy;
  int facing; // +1 right, -1 left

  // Ground / Wall / Climb contact flags
  bool isGrounded;
  bool isOnOneWayPlatform;
  bool isTouchingWallLeft;
  bool isTouchingWallRight;
  bool isWallSliding;
  bool isOnLadder;

  // Silksong platforming forgiveness & maneuver timers
  double coyoteTimer;
  double jumpBufferTimer;
  double dropThroughTimer;
  double wallCoyoteTimer;
  int wallCoyoteDir; // -1 wall on left, +1 wall on right
  double wallJumpLockTimer;

  // Dash & air-maneuver state
  double dashTimer;
  double dashCooldownTimer;
  int dashDir;
  bool airDashAvailable;
  bool doubleJumpAvailable;

  // Grapple silk-needle hook state
  bool grappleActive;
  double grappleTargetX;
  double grappleTargetY;
  double grappleTimer;
  double grappleCooldownTimer;

  // Combat / survivability stats
  int resolveHp; // Current Resolve Masks (e.g. 6..10)
  int maxResolveHp;
  double civicSilk; // 0..maxCivicSilk
  double maxCivicSilk;
  double invulnTimer;
  double knockbackLockTimer;
  double pogoBounceTimer;

  // Game-feel visual squash/stretch, run phase, and dash ghosts
  double squashX;
  double squashY;
  double runAnimTime;
  double idleTime;
  final List<DashAfterimage> afterimages = <DashAfterimage>[];

  // Last safe non-hazard ground position for spike respawn recovery
  double lastSafeGroundX;
  double lastSafeGroundY;

  DungeonPlayerPhysicsState({
    required this.x,
    required this.y,
    this.width = 10.0,
    this.height = 14.0,
    this.vx = 0.0,
    this.vy = 0.0,
    this.facing = 1,
    this.isGrounded = false,
    this.isOnOneWayPlatform = false,
    this.isTouchingWallLeft = false,
    this.isTouchingWallRight = false,
    this.isWallSliding = false,
    this.isOnLadder = false,
    this.coyoteTimer = 0.0,
    this.jumpBufferTimer = 0.0,
    this.dropThroughTimer = 0.0,
    this.wallCoyoteTimer = 0.0,
    this.wallCoyoteDir = 0,
    this.wallJumpLockTimer = 0.0,
    this.dashTimer = 0.0,
    this.dashCooldownTimer = 0.0,
    this.dashDir = 1,
    this.airDashAvailable = true,
    this.doubleJumpAvailable = false,
    this.grappleActive = false,
    this.grappleTargetX = 0.0,
    this.grappleTargetY = 0.0,
    this.grappleTimer = 0.0,
    this.grappleCooldownTimer = 0.0,
    this.resolveHp = 6,
    this.maxResolveHp = 6,
    this.civicSilk = 50.0,
    this.maxCivicSilk = 100.0,
    this.invulnTimer = 0.0,
    this.knockbackLockTimer = 0.0,
    this.pogoBounceTimer = 0.0,
    this.squashX = 1.0,
    this.squashY = 1.0,
    this.runAnimTime = 0.0,
    this.idleTime = 0.0,
  })  : lastSafeGroundX = x,
        lastSafeGroundY = y;

  double get centerX => x + width * 0.5;
  double get centerY => y + height * 0.5;
  double get bottom => y + height;
  double get right => x + width;
  Rect get hitbox => Rect.fromLTWH(x, y, width, height);
  bool get isDashing => dashTimer > 0.0;
  bool get isInvulnerable => invulnTimer > 0.0 || isDashing;

  void addSilk(double amount) {
    civicSilk = (civicSilk + amount).clamp(0.0, maxCivicSilk);
  }

  bool spendSilk(double cost) {
    if (civicSilk + 0.001 < cost) return false;
    civicSilk = math.max(0.0, civicSilk - cost);
    return true;
  }
}

/// Persistent Metroidvania Dungeon progression bundled into the student's cloud save!
class DungeonProgressSave {
  final int archipelagoShards;
  final DungeonBladeTier bladeTier;
  final int bonusMaxResolveMasks; // Earned via Bench Mastery Trials & Chests (0..4)
  final int bonusMaxSilk; // 0..60
  final int maxCharmNotches; // Starts at 4, upgradable up to 8
  final Set<String> unlockedCharmIds;
  final List<String> equippedCharmIds;
  final Set<DungeonSilkSkillId> unlockedSkills;
  final DungeonSilkSkillId activeSkill;
  final Set<String> discoveredChamberIds;
  final Set<String> openedChestIds;
  final Set<String> brokenSecretKeys;
  final Set<String> unlockedGateChamberIds;
  final Set<String> defeatedBossIds;
  final String checkpointChamberId;
  final int checkpointCol;
  final int checkpointRow;
  final int elixirCount;

  const DungeonProgressSave({
    this.archipelagoShards = 0,
    this.bladeTier = DungeonBladeTier.bambooSpear,
    this.bonusMaxResolveMasks = 0,
    this.bonusMaxSilk = 0,
    this.maxCharmNotches = 4,
    this.unlockedCharmIds = const <String>{'tarsier_lantern'},
    this.equippedCharmIds = const <String>['tarsier_lantern'],
    this.unlockedSkills = const <DungeonSilkSkillId>{
      DungeonSilkSkillId.sanduguanThread,
      DungeonSilkSkillId.silkBind,
    },
    this.activeSkill = DungeonSilkSkillId.sanduguanThread,
    this.discoveredChamberIds = const <String>{'act1_c1_shore'},
    this.openedChestIds = const <String>{},
    this.brokenSecretKeys = const <String>{},
    this.unlockedGateChamberIds = const <String>{},
    this.defeatedBossIds = const <String>{},
    this.checkpointChamberId = 'act1_c1_shore',
    this.checkpointCol = 4,
    this.checkpointRow = 14,
    this.elixirCount = 1,
  });

  bool hasCharmEquipped(String charmId) => equippedCharmIds.contains(charmId);

  int get usedCharmNotches {
    var total = 0;
    for (final id in equippedCharmIds) {
      for (final spec in kDungeonCharmCatalog) {
        if (spec.id == id) {
          total += spec.notchCost;
          break;
        }
      }
    }
    return total;
  }

  int get effectiveMaxResolveMasks =>
      6 + bonusMaxResolveMasks + (hasCharmEquipped('sovereign_heart') ? 2 : 0);

  double get effectiveMaxSilk => (100 + bonusMaxSilk).toDouble();

  DungeonProgressSave copyWith({
    int? archipelagoShards,
    DungeonBladeTier? bladeTier,
    int? bonusMaxResolveMasks,
    int? bonusMaxSilk,
    int? maxCharmNotches,
    Set<String>? unlockedCharmIds,
    List<String>? equippedCharmIds,
    Set<DungeonSilkSkillId>? unlockedSkills,
    DungeonSilkSkillId? activeSkill,
    Set<String>? discoveredChamberIds,
    Set<String>? openedChestIds,
    Set<String>? brokenSecretKeys,
    Set<String>? unlockedGateChamberIds,
    Set<String>? defeatedBossIds,
    String? checkpointChamberId,
    int? checkpointCol,
    int? checkpointRow,
    int? elixirCount,
  }) {
    return DungeonProgressSave(
      archipelagoShards: archipelagoShards ?? this.archipelagoShards,
      bladeTier: bladeTier ?? this.bladeTier,
      bonusMaxResolveMasks: bonusMaxResolveMasks ?? this.bonusMaxResolveMasks,
      bonusMaxSilk: bonusMaxSilk ?? this.bonusMaxSilk,
      maxCharmNotches: maxCharmNotches ?? this.maxCharmNotches,
      unlockedCharmIds: unlockedCharmIds ?? this.unlockedCharmIds,
      equippedCharmIds: equippedCharmIds ?? this.equippedCharmIds,
      unlockedSkills: unlockedSkills ?? this.unlockedSkills,
      activeSkill: activeSkill ?? this.activeSkill,
      discoveredChamberIds: discoveredChamberIds ?? this.discoveredChamberIds,
      openedChestIds: openedChestIds ?? this.openedChestIds,
      brokenSecretKeys: brokenSecretKeys ?? this.brokenSecretKeys,
      unlockedGateChamberIds:
          unlockedGateChamberIds ?? this.unlockedGateChamberIds,
      defeatedBossIds: defeatedBossIds ?? this.defeatedBossIds,
      checkpointChamberId: checkpointChamberId ?? this.checkpointChamberId,
      checkpointCol: checkpointCol ?? this.checkpointCol,
      checkpointRow: checkpointRow ?? this.checkpointRow,
      elixirCount: elixirCount ?? this.elixirCount,
    );
  }

  /// Union-merges two saves safely across devices without losing unlocked skills,
  /// forged blade tiers, charms, discovered map rooms, or defeated bosses.
  DungeonProgressSave mergeWith(DungeonProgressSave other) {
    final mergedTier = bladeTier.index >= other.bladeTier.index
        ? bladeTier
        : other.bladeTier;
    return DungeonProgressSave(
      archipelagoShards: math.max(archipelagoShards, other.archipelagoShards),
      bladeTier: mergedTier,
      bonusMaxResolveMasks:
          math.max(bonusMaxResolveMasks, other.bonusMaxResolveMasks),
      bonusMaxSilk: math.max(bonusMaxSilk, other.bonusMaxSilk),
      maxCharmNotches: math.max(maxCharmNotches, other.maxCharmNotches),
      unlockedCharmIds: <String>{...unlockedCharmIds, ...other.unlockedCharmIds},
      equippedCharmIds: equippedCharmIds.isNotEmpty
          ? equippedCharmIds
          : other.equippedCharmIds,
      unlockedSkills: <DungeonSilkSkillId>{
        ...unlockedSkills,
        ...other.unlockedSkills,
      },
      activeSkill: activeSkill,
      discoveredChamberIds: <String>{
        ...discoveredChamberIds,
        ...other.discoveredChamberIds,
      },
      openedChestIds: <String>{...openedChestIds, ...other.openedChestIds},
      brokenSecretKeys: <String>{...brokenSecretKeys, ...other.brokenSecretKeys},
      unlockedGateChamberIds: <String>{
        ...unlockedGateChamberIds,
        ...other.unlockedGateChamberIds,
      },
      defeatedBossIds: <String>{...defeatedBossIds, ...other.defeatedBossIds},
      checkpointChamberId: checkpointChamberId,
      checkpointCol: checkpointCol,
      checkpointRow: checkpointRow,
      elixirCount: math.max(elixirCount, other.elixirCount),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'archipelagoShards': archipelagoShards,
        'bladeTier': bladeTier.name,
        'bonusMaxResolveMasks': bonusMaxResolveMasks,
        'bonusMaxSilk': bonusMaxSilk,
        'maxCharmNotches': maxCharmNotches,
        'unlockedCharmIds': unlockedCharmIds.toList(),
        'equippedCharmIds': equippedCharmIds,
        'unlockedSkills': unlockedSkills.map((s) => s.name).toList(),
        'activeSkill': activeSkill.name,
        'discoveredChamberIds': discoveredChamberIds.toList(),
        'openedChestIds': openedChestIds.toList(),
        'brokenSecretKeys': brokenSecretKeys.toList(),
        'unlockedGateChamberIds': unlockedGateChamberIds.toList(),
        'defeatedBossIds': defeatedBossIds.toList(),
        'checkpointChamberId': checkpointChamberId,
        'checkpointCol': checkpointCol,
        'checkpointRow': checkpointRow,
        'elixirCount': elixirCount,
      };

  factory DungeonProgressSave.fromJson(Map<String, dynamic> json) {
    final rawTier = json['bladeTier']?.toString() ?? '';
    final tier = DungeonBladeTier.values.firstWhere(
      (e) => e.name == rawTier,
      orElse: () => DungeonBladeTier.bambooSpear,
    );
    final rawSkills = (json['unlockedSkills'] as List?)
            ?.map((e) => e.toString())
            .toSet() ??
        const <String>{};
    final skills = <DungeonSilkSkillId>{
      DungeonSilkSkillId.sanduguanThread,
      DungeonSilkSkillId.silkBind,
      ...DungeonSilkSkillId.values.where((s) => rawSkills.contains(s.name)),
    };
    final rawActive = json['activeSkill']?.toString() ?? '';
    final active = DungeonSilkSkillId.values.firstWhere(
      (e) => e.name == rawActive,
      orElse: () => DungeonSilkSkillId.sanduguanThread,
    );
    return DungeonProgressSave(
      archipelagoShards:
          ((json['archipelagoShards'] as num?)?.toInt() ?? 0).clamp(0, 99999),
      bladeTier: tier,
      bonusMaxResolveMasks:
          ((json['bonusMaxResolveMasks'] as num?)?.toInt() ?? 0).clamp(0, 4),
      bonusMaxSilk:
          ((json['bonusMaxSilk'] as num?)?.toInt() ?? 0).clamp(0, 60),
      maxCharmNotches:
          ((json['maxCharmNotches'] as num?)?.toInt() ?? 4).clamp(4, 8),
      unlockedCharmIds: <String>{
        'tarsier_lantern',
        ...?((json['unlockedCharmIds'] as List?)?.map((e) => e.toString())),
      },
      equippedCharmIds: (json['equippedCharmIds'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          const <String>['tarsier_lantern'],
      unlockedSkills: skills,
      activeSkill: active,
      discoveredChamberIds: <String>{
        'act1_c1_shore',
        ...?((json['discoveredChamberIds'] as List?)?.map((e) => e.toString())),
      },
      openedChestIds: (json['openedChestIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{},
      brokenSecretKeys: (json['brokenSecretKeys'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{},
      unlockedGateChamberIds: (json['unlockedGateChamberIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{},
      defeatedBossIds: (json['defeatedBossIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{},
      checkpointChamberId:
          json['checkpointChamberId']?.toString() ?? 'act1_c1_shore',
      checkpointCol: (json['checkpointCol'] as num?)?.toInt() ?? 4,
      checkpointRow: (json['checkpointRow'] as num?)?.toInt() ?? 14,
      elixirCount: ((json['elixirCount'] as num?)?.toInt() ?? 1).clamp(0, 9),
    );
  }

  String encodeJsonString() => jsonEncode(toJson());
}
