import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../spritecast_engine.dart';
import 'dungeon_audio.dart';
import 'dungeon_combat.dart';
import 'dungeon_models.dart';
import 'dungeon_renderer.dart';

/// High-level movement & attack behavior pattern for regular dungeon enemies & Rival Mateo.
enum DungeonEnemyBehavior {
  patrolLunger, // Patrols ledges, telegraphs wind-up, lunges forward
  shieldedLancer, // Front-shielded soldier; blocks frontal normal hits, charges after wind-up
  swoopingFlyer, // Floating cave/belltower wisp that orbits & swoops diagonally
  leapingRaider, // Crouches in telegraph, then arcs through air toward hero
  laserMarksman, // Projects aim laser during wind-up, then fires fast deflectable bolt
  spreadCaster, // Hovers/backs off and casts 3-way arcane/ink volley
  mortarTurret, // Stationary armored turret firing gravity-arced parabolic shells
  juggernautSlammer, // Heavy front-shielded bruiser; wind-up slam emits twin ground shockwaves
  rivalDuelist, // Recurring Rival Mateo: agile leap, dash-thrust, kunai throw & backstep
  multiPhaseBoss, // One of the 7 Multi-Phase Era Bosses with posture & Counter-Break
}

/// Finite state machine phases for every dungeon enemy & boss.
enum DungeonEnemyAiState {
  patrol,
  windup, // Unmistakable telegraph flash / aim laser before attacking!
  attack,
  recover,
  staggered, // Boss posture broken -> Constitutional Counter-Break window open!
  phaseShift, // Brief invincible roar & shockwave when crossing Boss Phase 2 / 3 threshold
}

/// Signature attack patterns executed by the 7 Multi-Phase Era Bosses.
enum DungeonBossAttackKind {
  dashThrust,
  groundShockwaveSlam,
  fanVolley,
  aimedSniperBarrage,
  leapingDiveSlam,
  parabolicArtillery,
  radialDecreeNova,
}

/// Historical Constitutional Counter-Break prompt unlocked when staggering an Era Boss.
class DungeonCounterBreakPrompt {
  final String bossId;
  final String loreEntryId;
  final String promptTitle;
  final String question;
  final List<String> options; // 2 punchy rapid-tap constitutional counters
  final int correctIndex;
  final String successBanner;
  final String constitutionalNote;

  const DungeonCounterBreakPrompt({
    required this.bossId,
    required this.loreEntryId,
    required this.promptTitle,
    required this.question,
    required this.options,
    required this.correctIndex,
    required this.successBanner,
    required this.constitutionalNote,
  });
}

/// Static blueprint for a regular enemy, Rival Mateo, or one of the 7 Multi-Phase Era Bosses.
class DungeonEnemyArchetype {
  final String id;
  final String displayName;
  final String subtitle;
  final int actNumber;
  final DungeonEnemyBehavior behavior;
  final bool isBoss;
  final bool isRival;
  final bool isFlying;
  final bool hasFrontShield;
  final double width;
  final double height;
  final int maxHp;
  final int contactDamage;
  final int attackDamage;
  final double moveSpeed;
  final double aggroRangePx;
  final double attackRangePx;
  final double windupSec;
  final double attackDurationSec;
  final double recoverSec;
  final int shardDropMin;
  final int shardDropMax;
  final int xpReward;
  final double staggerThreshold; // Posture needed to trigger Boss Stagger
  final Color primaryColor;
  final Color accentColor;
  final List<DungeonBossAttackKind> phase1Attacks;
  final List<DungeonBossAttackKind> phase2Attacks;
  final List<DungeonBossAttackKind> phase3Attacks;
  final DungeonCounterBreakPrompt? counterBreak;

  const DungeonEnemyArchetype({
    required this.id,
    required this.displayName,
    required this.subtitle,
    required this.actNumber,
    required this.behavior,
    this.isBoss = false,
    this.isRival = false,
    this.isFlying = false,
    this.hasFrontShield = false,
    required this.width,
    required this.height,
    required this.maxHp,
    this.contactDamage = 1,
    this.attackDamage = 1,
    required this.moveSpeed,
    required this.aggroRangePx,
    required this.attackRangePx,
    required this.windupSec,
    required this.attackDurationSec,
    required this.recoverSec,
    required this.shardDropMin,
    required this.shardDropMax,
    required this.xpReward,
    this.staggerThreshold = 85.0,
    required this.primaryColor,
    required this.accentColor,
    this.phase1Attacks = const <DungeonBossAttackKind>[],
    this.phase2Attacks = const <DungeonBossAttackKind>[],
    this.phase3Attacks = const <DungeonBossAttackKind>[],
    this.counterBreak,
  });

  bool get hasThreePhases => phase3Attacks.isNotEmpty;
}

// ═══════════════════════════════════════════════════════════════════════════
//  14 REGULAR ENEMY ARCHETYPES + RECURRING RIVAL MATEO
// ═══════════════════════════════════════════════════════════════════════════

final Map<String, DungeonEnemyArchetype> kDungeonEnemyArchetypes =
    <String, DungeonEnemyArchetype>{
  // 1. Act I — Coastal Patrol Sentinel
  'barangay_scout': DungeonEnemyArchetype(
    id: 'barangay_scout',
    displayName: 'Barangay Sentinel',
    subtitle: 'Coastal Spear Patroller',
    actNumber: 1,
    behavior: DungeonEnemyBehavior.patrolLunger,
    width: 12.0,
    height: 15.0,
    maxHp: 32,
    moveSpeed: 46.0,
    aggroRangePx: 112.0,
    attackRangePx: 42.0,
    windupSec: 0.44,
    attackDurationSec: 0.24,
    recoverSec: 0.55,
    shardDropMin: 6,
    shardDropMax: 10,
    xpReward: 18,
    primaryColor: SpriteCastPalette.endesga32[13],
    accentColor: SpriteCastPalette.endesga32[10],
  ),

  // 2. Act I — Swooping Cave Wisp
  'cave_alimaong': DungeonEnemyArchetype(
    id: 'cave_alimaong',
    displayName: 'Cave Alimaong',
    subtitle: 'Swooping Cavern Wisp',
    actNumber: 1,
    behavior: DungeonEnemyBehavior.swoopingFlyer,
    isFlying: true,
    width: 12.0,
    height: 12.0,
    maxHp: 24,
    moveSpeed: 64.0,
    aggroRangePx: 136.0,
    attackRangePx: 92.0,
    windupSec: 0.48,
    attackDurationSec: 0.36,
    recoverSec: 0.65,
    shardDropMin: 6,
    shardDropMax: 11,
    xpReward: 20,
    primaryColor: SpriteCastPalette.endesga32[17],
    accentColor: SpriteCastPalette.endesga32[18],
  ),

  // 3. Act I — Reef Raider Leaper
  'raider_leaper': DungeonEnemyArchetype(
    id: 'raider_leaper',
    displayName: 'Reef Raider',
    subtitle: 'Acrobatic Leaping Striker',
    actNumber: 1,
    behavior: DungeonEnemyBehavior.leapingRaider,
    width: 13.0,
    height: 15.0,
    maxHp: 38,
    moveSpeed: 54.0,
    aggroRangePx: 128.0,
    attackRangePx: 84.0,
    windupSec: 0.42,
    attackDurationSec: 0.45,
    recoverSec: 0.52,
    shardDropMin: 8,
    shardDropMax: 13,
    xpReward: 24,
    primaryColor: SpriteCastPalette.endesga32[0],
    accentColor: SpriteCastPalette.endesga32[11],
  ),

  // 4. Act II — Guardia Shielded Lancer (counter via pogo, dash-behind, or Silk Skill!)
  'guardia_lancer': DungeonEnemyArchetype(
    id: 'guardia_lancer',
    displayName: 'Guardia Lancer',
    subtitle: 'Front-Shielded Halberdier',
    actNumber: 2,
    behavior: DungeonEnemyBehavior.shieldedLancer,
    hasFrontShield: true,
    width: 14.0,
    height: 17.0,
    maxHp: 52,
    moveSpeed: 38.0,
    aggroRangePx: 120.0,
    attackRangePx: 54.0,
    windupSec: 0.52,
    attackDurationSec: 0.30,
    recoverSec: 0.68,
    shardDropMin: 11,
    shardDropMax: 16,
    xpReward: 30,
    primaryColor: SpriteCastPalette.endesga32[23],
    accentColor: SpriteCastPalette.endesga32[10],
  ),

  // 4b. Act II — Spanish Conquistador (Toledo Broadsword & Castilian Buckler Raider!)
  'spanish_conquistador': DungeonEnemyArchetype(
    id: 'spanish_conquistador',
    displayName: 'Spanish Conquistador',
    subtitle: 'Toledo Broadsword Tercio',
    actNumber: 2,
    behavior: DungeonEnemyBehavior.patrolLunger,
    width: 14.0,
    height: 17.0,
    maxHp: 46,
    moveSpeed: 56.0,
    aggroRangePx: 138.0,
    attackRangePx: 54.0,
    windupSec: 0.42,
    attackDurationSec: 0.28,
    recoverSec: 0.52,
    shardDropMin: 12,
    shardDropMax: 18,
    xpReward: 32,
    primaryColor: SpriteCastPalette.endesga32[21],
    accentColor: SpriteCastPalette.endesga32[8],
  ),

  // 5. Act II — Intramuros Musketeer (crimson aim laser telegraph!)
  'intramuros_musketeer': DungeonEnemyArchetype(
    id: 'intramuros_musketeer',
    displayName: 'Intramuros Musketeer',
    subtitle: 'Laser-Sighted Marksman',
    actNumber: 2,
    behavior: DungeonEnemyBehavior.laserMarksman,
    width: 12.0,
    height: 16.0,
    maxHp: 34,
    moveSpeed: 32.0,
    aggroRangePx: 170.0,
    attackRangePx: 155.0,
    windupSec: 0.62,
    attackDurationSec: 0.16,
    recoverSec: 0.85,
    shardDropMin: 10,
    shardDropMax: 15,
    xpReward: 28,
    primaryColor: SpriteCastPalette.endesga32[7],
    accentColor: SpriteCastPalette.endesga32[20],
  ),

  // 6. Act II — Belltower Nightwing
  'belltower_bat': DungeonEnemyArchetype(
    id: 'belltower_bat',
    displayName: 'Belltower Nightwing',
    subtitle: 'Dive-Bombing Spire Stalker',
    actNumber: 2,
    behavior: DungeonEnemyBehavior.swoopingFlyer,
    isFlying: true,
    width: 13.0,
    height: 11.0,
    maxHp: 30,
    moveSpeed: 74.0,
    aggroRangePx: 145.0,
    attackRangePx: 98.0,
    windupSec: 0.40,
    attackDurationSec: 0.34,
    recoverSec: 0.58,
    shardDropMin: 9,
    shardDropMax: 14,
    xpReward: 26,
    primaryColor: SpriteCastPalette.endesga32[27],
    accentColor: SpriteCastPalette.endesga32[29],
  ),

  // 7. Act III — Malolos Catacomb Duelist
  'malolos_swordsman': DungeonEnemyArchetype(
    id: 'malolos_swordsman',
    displayName: 'Catacomb Duelist',
    subtitle: 'Swift Sabre Fencer',
    actNumber: 3,
    behavior: DungeonEnemyBehavior.patrolLunger,
    width: 13.0,
    height: 16.0,
    maxHp: 56,
    moveSpeed: 64.0,
    aggroRangePx: 132.0,
    attackRangePx: 52.0,
    windupSec: 0.38,
    attackDurationSec: 0.24,
    recoverSec: 0.48,
    shardDropMin: 13,
    shardDropMax: 19,
    xpReward: 34,
    primaryColor: SpriteCastPalette.endesga32[16],
    accentColor: SpriteCastPalette.endesga32[11],
  ),

  // 8. Act III — Charter Scribe Acolyte (3-way deflectable bolt fan!)
  'tribunal_acolyte': DungeonEnemyArchetype(
    id: 'tribunal_acolyte',
    displayName: 'Tribunal Acolyte',
    subtitle: 'Floating Decree Caster',
    actNumber: 3,
    behavior: DungeonEnemyBehavior.spreadCaster,
    isFlying: true,
    width: 13.0,
    height: 16.0,
    maxHp: 46,
    moveSpeed: 48.0,
    aggroRangePx: 160.0,
    attackRangePx: 135.0,
    windupSec: 0.56,
    attackDurationSec: 0.22,
    recoverSec: 0.90,
    shardDropMin: 14,
    shardDropMax: 20,
    xpReward: 36,
    primaryColor: SpriteCastPalette.endesga32[27],
    accentColor: SpriteCastPalette.endesga32[18],
  ),

  // 9. Act IV — Commonwealth Clockwork Automaton
  'deco_automaton': DungeonEnemyArchetype(
    id: 'deco_automaton',
    displayName: 'Clockwork Sentinel',
    subtitle: 'Art-Deco Armored Guard',
    actNumber: 4,
    behavior: DungeonEnemyBehavior.shieldedLancer,
    hasFrontShield: true,
    width: 16.0,
    height: 18.0,
    maxHp: 74,
    moveSpeed: 42.0,
    aggroRangePx: 132.0,
    attackRangePx: 62.0,
    windupSec: 0.50,
    attackDurationSec: 0.32,
    recoverSec: 0.62,
    shardDropMin: 16,
    shardDropMax: 23,
    xpReward: 42,
    primaryColor: SpriteCastPalette.endesga32[21],
    accentColor: SpriteCastPalette.endesga32[18],
  ),

  // 10. Act IV — Sky-Bridge Marksman
  'skybridge_sniper': DungeonEnemyArchetype(
    id: 'skybridge_sniper',
    displayName: 'Sky-Bridge Sniper',
    subtitle: 'High-Altitude Marksman',
    actNumber: 4,
    behavior: DungeonEnemyBehavior.laserMarksman,
    width: 13.0,
    height: 16.0,
    maxHp: 48,
    moveSpeed: 36.0,
    aggroRangePx: 195.0,
    attackRangePx: 180.0,
    windupSec: 0.58,
    attackDurationSec: 0.18,
    recoverSec: 0.76,
    shardDropMin: 15,
    shardDropMax: 22,
    xpReward: 40,
    primaryColor: SpriteCastPalette.endesga32[16],
    accentColor: SpriteCastPalette.endesga32[26],
  ),

  // 11. Act V — Corregidor Mortar Turret (parabolic arcing shells!)
  'bunker_mortar': DungeonEnemyArchetype(
    id: 'bunker_mortar',
    displayName: 'Bunker Mortar',
    subtitle: 'Parabolic Artillery Emplacement',
    actNumber: 5,
    behavior: DungeonEnemyBehavior.mortarTurret,
    width: 16.0,
    height: 14.0,
    maxHp: 68,
    moveSpeed: 0.0,
    aggroRangePx: 190.0,
    attackRangePx: 175.0,
    windupSec: 0.64,
    attackDurationSec: 0.20,
    recoverSec: 1.05,
    shardDropMin: 18,
    shardDropMax: 26,
    xpReward: 46,
    primaryColor: SpriteCastPalette.endesga32[14],
    accentColor: SpriteCastPalette.endesga32[9],
  ),

  // 12. Act V — Imperial Assault Commando
  'imperial_commando': DungeonEnemyArchetype(
    id: 'imperial_commando',
    displayName: 'Assault Commando',
    subtitle: 'Rapid Leaping Striker',
    actNumber: 5,
    behavior: DungeonEnemyBehavior.leapingRaider,
    width: 14.0,
    height: 16.0,
    maxHp: 72,
    moveSpeed: 72.0,
    aggroRangePx: 150.0,
    attackRangePx: 96.0,
    windupSec: 0.38,
    attackDurationSec: 0.42,
    recoverSec: 0.46,
    shardDropMin: 18,
    shardDropMax: 26,
    xpReward: 48,
    primaryColor: SpriteCastPalette.endesga32[6],
    accentColor: SpriteCastPalette.endesga32[8],
  ),

  // 12b. Act V — Imperial Japanese Gunto Katana Warrior (Iaido Dash-Slash Officer!)
  'japanese_katana_warrior': DungeonEnemyArchetype(
    id: 'japanese_katana_warrior',
    displayName: 'Imperial Gunto Warrior',
    subtitle: 'Shin-Gunto Katana Duelist',
    actNumber: 5,
    behavior: DungeonEnemyBehavior.patrolLunger,
    width: 14.0,
    height: 17.0,
    maxHp: 82,
    moveSpeed: 78.0,
    aggroRangePx: 162.0,
    attackRangePx: 66.0,
    windupSec: 0.36,
    attackDurationSec: 0.28,
    recoverSec: 0.48,
    shardDropMin: 20,
    shardDropMax: 28,
    xpReward: 52,
    primaryColor: SpriteCastPalette.endesga32[14],
    accentColor: SpriteCastPalette.endesga32[26],
  ),

  // 13. Act VI — Obsidian Censor Drone
  'censor_drone': DungeonEnemyArchetype(
    id: 'censor_drone',
    displayName: 'Censor Drone',
    subtitle: 'Surveillance Decree Eye',
    actNumber: 6,
    behavior: DungeonEnemyBehavior.spreadCaster,
    isFlying: true,
    width: 14.0,
    height: 14.0,
    maxHp: 66,
    moveSpeed: 58.0,
    aggroRangePx: 175.0,
    attackRangePx: 148.0,
    windupSec: 0.50,
    attackDurationSec: 0.22,
    recoverSec: 0.74,
    shardDropMin: 20,
    shardDropMax: 28,
    xpReward: 52,
    primaryColor: SpriteCastPalette.endesga32[24],
    accentColor: SpriteCastPalette.endesga32[26],
  ),

  // 14. Act VI–VII — Armored Censor Juggernaut (front shield + twin floor shockwaves!)
  'iron_juggernaut': DungeonEnemyArchetype(
    id: 'iron_juggernaut',
    displayName: 'Iron Juggernaut',
    subtitle: 'Shockwave Bastion',
    actNumber: 6,
    behavior: DungeonEnemyBehavior.juggernautSlammer,
    hasFrontShield: true,
    width: 18.0,
    height: 22.0,
    maxHp: 112,
    contactDamage: 1,
    attackDamage: 2,
    moveSpeed: 32.0,
    aggroRangePx: 138.0,
    attackRangePx: 72.0,
    windupSec: 0.66,
    attackDurationSec: 0.28,
    recoverSec: 0.86,
    shardDropMin: 26,
    shardDropMax: 36,
    xpReward: 65,
    primaryColor: SpriteCastPalette.endesga32[22],
    accentColor: SpriteCastPalette.endesga32[26],
  ),

  // 15. Recurring Rival Encounter — Rival Mateo (agile Silksong mirror duel!)
  'rival_mateo': DungeonEnemyArchetype(
    id: 'rival_mateo',
    displayName: 'Rival Mateo',
    subtitle: 'Sworn Duelist Challenger',
    actNumber: 2,
    behavior: DungeonEnemyBehavior.rivalDuelist,
    isBoss: true,
    isRival: true,
    width: 13.0,
    height: 17.0,
    maxHp: 155,
    contactDamage: 1,
    attackDamage: 1,
    moveSpeed: 96.0,
    aggroRangePx: 220.0,
    attackRangePx: 105.0,
    windupSec: 0.38,
    attackDurationSec: 0.30,
    recoverSec: 0.44,
    shardDropMin: 45,
    shardDropMax: 60,
    xpReward: 95,
    staggerThreshold: 65.0,
    primaryColor: SpriteCastPalette.endesga32[16],
    accentColor: SpriteCastPalette.endesga32[18],
    phase1Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.fanVolley,
      DungeonBossAttackKind.leapingDiveSlam,
    ],
    phase2Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.leapingDiveSlam,
      DungeonBossAttackKind.aimedSniperBarrage,
    ],
    counterBreak: const DungeonCounterBreakPrompt(
      bossId: 'rival_mateo',
      loreEntryId: 'lore_rival_mateo_oath',
      promptTitle: 'RIVAL CLASH — COUNTER-BREAK!',
      question:
          'Mateo claims power alone maintains peace. What makes authority legitimate in a democracy?',
      options: <String>[
        'Consent of the governed & rule of law',
        'Unchecked decrees by one ruler',
      ],
      correctIndex: 0,
      successBanner: 'CONSENT PREVAILS!',
      constitutionalNote:
          'Democratic sovereignty flows from the people, never from arbitrary force.',
    ),
  ),
};

// ═══════════════════════════════════════════════════════════════════════════
//  ALL 7 MULTI-PHASE ERA BOSSES (ACTS I–VII) WITH COUNTER-BREAK PROMPTS
// ═══════════════════════════════════════════════════════════════════════════

final Map<String, DungeonEnemyArchetype> kDungeonBossArchetypes =
    <String, DungeonEnemyArchetype>{
  // ACT I BOSS — Datu Makisig (Pre-Colonial Barangay & Sanduguan)
  'boss_datu_makisig': DungeonEnemyArchetype(
    id: 'boss_datu_makisig',
    displayName: 'Datu Makisig',
    subtitle: 'Keeper of the Sanduguan',
    actNumber: 1,
    behavior: DungeonEnemyBehavior.multiPhaseBoss,
    isBoss: true,
    width: 22.0,
    height: 26.0,
    maxHp: 210,
    contactDamage: 1,
    attackDamage: 1,
    moveSpeed: 74.0,
    aggroRangePx: 260.0,
    attackRangePx: 145.0,
    windupSec: 0.54,
    attackDurationSec: 0.34,
    recoverSec: 0.62,
    shardDropMin: 60,
    shardDropMax: 75,
    xpReward: 130,
    staggerThreshold: 72.0,
    primaryColor: SpriteCastPalette.endesga32[0],
    accentColor: SpriteCastPalette.endesga32[11],
    phase1Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.groundShockwaveSlam,
    ],
    phase2Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.leapingDiveSlam,
      DungeonBossAttackKind.groundShockwaveSlam,
      DungeonBossAttackKind.fanVolley,
    ],
    counterBreak: const DungeonCounterBreakPrompt(
      bossId: 'boss_datu_makisig',
      loreEntryId: 'lore_act1_sanduguan',
      promptTitle: 'ACT I COUNTER-BREAK — BARANGAY CHARTER!',
      question:
          'In pre-colonial barangays, who advised the Datu in settling community disputes?',
      options: <String>[
        'Council of Elders (Maginoo / Umalahokan)',
        'Foreign Viceroys from across the sea',
      ],
      correctIndex: 0,
      successBanner: 'SANDUGUAN SEALED!',
      constitutionalNote:
          'Early Filipino barangays practiced customary law guided by the Datu and elders.',
    ),
  ),

  // ACT II BOSS — Gobernador-Heneral Valdés (Colonial Citadel)
  'boss_valdes': DungeonEnemyArchetype(
    id: 'boss_valdes',
    displayName: 'Gobernador-Heneral Valdés',
    subtitle: 'Iron Viceroy of Intramuros',
    actNumber: 2,
    behavior: DungeonEnemyBehavior.multiPhaseBoss,
    isBoss: true,
    hasFrontShield: true,
    width: 24.0,
    height: 28.0,
    maxHp: 265,
    contactDamage: 1,
    attackDamage: 1,
    moveSpeed: 64.0,
    aggroRangePx: 270.0,
    attackRangePx: 165.0,
    windupSec: 0.52,
    attackDurationSec: 0.36,
    recoverSec: 0.58,
    shardDropMin: 75,
    shardDropMax: 95,
    xpReward: 155,
    staggerThreshold: 88.0,
    primaryColor: SpriteCastPalette.endesga32[7],
    accentColor: SpriteCastPalette.endesga32[10],
    phase1Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.aimedSniperBarrage,
      DungeonBossAttackKind.groundShockwaveSlam,
    ],
    phase2Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.aimedSniperBarrage,
      DungeonBossAttackKind.fanVolley,
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.groundShockwaveSlam,
    ],
    counterBreak: const DungeonCounterBreakPrompt(
      bossId: 'boss_valdes',
      loreEntryId: 'lore_act2_propaganda',
      promptTitle: 'ACT II COUNTER-BREAK — LA SOLIDARIDAD!',
      question:
          'What core reform did Rizal and the Propaganda Movement demand for Filipinos?',
      options: <String>[
        'Equal rights & representation under the law',
        'Permanent forced labor (Polo y Servicio)',
      ],
      correctIndex: 0,
      successBanner: 'REFORM DECLARED!',
      constitutionalNote:
          'The Propaganda Movement championed civil liberties, free press, and equality before the law.',
    ),
  ),

  // ACT III BOSS — Felipe Calderón (Malolos Catacombs & 1899 Constitution)
  'boss_calderon': DungeonEnemyArchetype(
    id: 'boss_calderon',
    displayName: 'Felipe Calderón',
    subtitle: 'Architect of the Malolos Charter',
    actNumber: 3,
    behavior: DungeonEnemyBehavior.multiPhaseBoss,
    isBoss: true,
    isFlying: true,
    width: 22.0,
    height: 28.0,
    maxHp: 300,
    contactDamage: 1,
    attackDamage: 1,
    moveSpeed: 76.0,
    aggroRangePx: 280.0,
    attackRangePx: 185.0,
    windupSec: 0.48,
    attackDurationSec: 0.34,
    recoverSec: 0.54,
    shardDropMin: 90,
    shardDropMax: 115,
    xpReward: 180,
    staggerThreshold: 96.0,
    primaryColor: SpriteCastPalette.endesga32[27],
    accentColor: SpriteCastPalette.endesga32[18],
    phase1Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.fanVolley,
      DungeonBossAttackKind.aimedSniperBarrage,
      DungeonBossAttackKind.leapingDiveSlam,
    ],
    phase2Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.radialDecreeNova,
      DungeonBossAttackKind.fanVolley,
      DungeonBossAttackKind.aimedSniperBarrage,
    ],
    counterBreak: const DungeonCounterBreakPrompt(
      bossId: 'boss_calderon',
      loreEntryId: 'lore_act3_malolos_1899',
      promptTitle: 'ACT III COUNTER-BREAK — 1899 MALOLOS CHARTER!',
      question:
          'What historic first did the 1899 Malolos Constitution establish in Asia?',
      options: <String>[
        'Asia\'s first democratic republic with a Bill of Rights',
        'A hereditary monarchy without a legislature',
      ],
      correctIndex: 0,
      successBanner: 'REPUBLIC AFFIRMED!',
      constitutionalNote:
          'Drafted at Barasoain Church, the 1899 Malolos Constitution created a representative republic with separation of powers.',
    ),
  ),

  // ACT IV BOSS — The Commonwealth Warden (1935 Sky-Bridge Bastion)
  'boss_commonwealth_warden': DungeonEnemyArchetype(
    id: 'boss_commonwealth_warden',
    displayName: 'Commonwealth Warden',
    subtitle: 'Sentinel of the 1935 Transition',
    actNumber: 4,
    behavior: DungeonEnemyBehavior.multiPhaseBoss,
    isBoss: true,
    hasFrontShield: true,
    width: 26.0,
    height: 30.0,
    maxHp: 350,
    contactDamage: 1,
    attackDamage: 2,
    moveSpeed: 72.0,
    aggroRangePx: 285.0,
    attackRangePx: 175.0,
    windupSec: 0.48,
    attackDurationSec: 0.36,
    recoverSec: 0.52,
    shardDropMin: 110,
    shardDropMax: 135,
    xpReward: 210,
    staggerThreshold: 108.0,
    primaryColor: SpriteCastPalette.endesga32[16],
    accentColor: SpriteCastPalette.endesga32[18],
    phase1Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.groundShockwaveSlam,
      DungeonBossAttackKind.fanVolley,
    ],
    phase2Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.leapingDiveSlam,
      DungeonBossAttackKind.radialDecreeNova,
      DungeonBossAttackKind.groundShockwaveSlam,
    ],
    counterBreak: const DungeonCounterBreakPrompt(
      bossId: 'boss_commonwealth_warden',
      loreEntryId: 'lore_act4_commonwealth_1935',
      promptTitle: 'ACT IV COUNTER-BREAK — 1935 CONSTITUTION!',
      question:
          'Which branch structure did the 1935 Constitution enshrine to prevent tyranny?',
      options: <String>[
        'Three co-equal branches with checks & balances',
        'Executive rule with no independent courts',
      ],
      correctIndex: 0,
      successBanner: 'CHECKS & BALANCES!',
      constitutionalNote:
          'Executive, Legislative, and Judicial branches check one another to safeguard liberty.',
    ),
  ),

  // ACT V BOSS — Imperial Commander of Corregidor (1943 Occupation)
  'boss_imperial_commander': DungeonEnemyArchetype(
    id: 'boss_imperial_commander',
    displayName: 'Imperial Commander',
    subtitle: 'Fortress Marshal of Corregidor',
    actNumber: 5,
    behavior: DungeonEnemyBehavior.multiPhaseBoss,
    isBoss: true,
    width: 24.0,
    height: 28.0,
    maxHp: 400,
    contactDamage: 1,
    attackDamage: 2,
    moveSpeed: 84.0,
    aggroRangePx: 295.0,
    attackRangePx: 190.0,
    windupSec: 0.44,
    attackDurationSec: 0.34,
    recoverSec: 0.48,
    shardDropMin: 130,
    shardDropMax: 160,
    xpReward: 245,
    staggerThreshold: 118.0,
    primaryColor: SpriteCastPalette.endesga32[6],
    accentColor: SpriteCastPalette.endesga32[9],
    phase1Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.parabolicArtillery,
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.groundShockwaveSlam,
    ],
    phase2Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.parabolicArtillery,
      DungeonBossAttackKind.leapingDiveSlam,
      DungeonBossAttackKind.aimedSniperBarrage,
    ],
    counterBreak: const DungeonCounterBreakPrompt(
      bossId: 'boss_imperial_commander',
      loreEntryId: 'lore_act5_wartime_resilience',
      promptTitle: 'ACT V COUNTER-BREAK — UNBROKEN SOVEREIGNTY!',
      question:
          'Why was the wartime 1943 Charter rejected once liberation was achieved?',
      options: <String>[
        'It was drafted under occupation without free popular ratification',
        'Because it granted too many citizen freedoms',
      ],
      correctIndex: 0,
      successBanner: 'LIBERATION RESTORED!',
      constitutionalNote:
          'A legitimate constitution requires free ratification by a sovereign people, never coercion.',
    ),
  ),

  // ACT VI BOSS — The Iron Censor (Martial Law Obsidian Vault — 3 Phases!)
  'boss_iron_censor': DungeonEnemyArchetype(
    id: 'boss_iron_censor',
    displayName: 'The Iron Censor',
    subtitle: 'Warden of the Obsidian Vault',
    actNumber: 6,
    behavior: DungeonEnemyBehavior.multiPhaseBoss,
    isBoss: true,
    hasFrontShield: true,
    width: 28.0,
    height: 32.0,
    maxHp: 470,
    contactDamage: 1,
    attackDamage: 2,
    moveSpeed: 78.0,
    aggroRangePx: 300.0,
    attackRangePx: 200.0,
    windupSec: 0.44,
    attackDurationSec: 0.34,
    recoverSec: 0.46,
    shardDropMin: 155,
    shardDropMax: 190,
    xpReward: 290,
    staggerThreshold: 128.0,
    primaryColor: SpriteCastPalette.endesga32[24],
    accentColor: SpriteCastPalette.endesga32[26],
    phase1Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.aimedSniperBarrage,
      DungeonBossAttackKind.groundShockwaveSlam,
    ],
    phase2Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.fanVolley,
      DungeonBossAttackKind.groundShockwaveSlam,
      DungeonBossAttackKind.leapingDiveSlam,
    ],
    phase3Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.radialDecreeNova,
      DungeonBossAttackKind.aimedSniperBarrage,
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.groundShockwaveSlam,
    ],
    counterBreak: const DungeonCounterBreakPrompt(
      bossId: 'boss_iron_censor',
      loreEntryId: 'lore_act6_habeas_corpus',
      promptTitle: 'ACT VI COUNTER-BREAK — WRIT OF HABEAS CORPUS!',
      question:
          'What constitutional safeguard protects citizens against arbitrary arrest without judicial review?',
      options: <String>[
        'Privilege of the Writ of Habeas Corpus & Due Process',
        'Indefinite detention by secret decree',
      ],
      correctIndex: 0,
      successBanner: 'CENSORSHIP SHATTERED!',
      constitutionalNote:
          'Under the 1987 Charter, even Martial Law cannot automatically abolish courts or civil liberties.',
    ),
  ),

  // ACT VII FINALE BOSS — The Sovereign Guardian of 1987 (Epic 3-Phase Finale!)
  'boss_sovereign_guardian': DungeonEnemyArchetype(
    id: 'boss_sovereign_guardian',
    displayName: 'The Sovereign Guardian',
    subtitle: 'Final Trial of the 1987 Charter',
    actNumber: 7,
    behavior: DungeonEnemyBehavior.multiPhaseBoss,
    isBoss: true,
    width: 30.0,
    height: 34.0,
    maxHp: 580,
    contactDamage: 1,
    attackDamage: 2,
    moveSpeed: 90.0,
    aggroRangePx: 320.0,
    attackRangePx: 220.0,
    windupSec: 0.42,
    attackDurationSec: 0.34,
    recoverSec: 0.42,
    shardDropMin: 240,
    shardDropMax: 300,
    xpReward: 420,
    staggerThreshold: 140.0,
    primaryColor: SpriteCastPalette.endesga32[10],
    accentColor: SpriteCastPalette.endesga32[11],
    phase1Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.fanVolley,
      DungeonBossAttackKind.groundShockwaveSlam,
    ],
    phase2Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.leapingDiveSlam,
      DungeonBossAttackKind.radialDecreeNova,
      DungeonBossAttackKind.aimedSniperBarrage,
    ],
    phase3Attacks: const <DungeonBossAttackKind>[
      DungeonBossAttackKind.radialDecreeNova,
      DungeonBossAttackKind.parabolicArtillery,
      DungeonBossAttackKind.dashThrust,
      DungeonBossAttackKind.leapingDiveSlam,
      DungeonBossAttackKind.groundShockwaveSlam,
    ],
    counterBreak: const DungeonCounterBreakPrompt(
      bossId: 'boss_sovereign_guardian',
      loreEntryId: 'lore_act7_sovereignty_1987',
      promptTitle: 'FINAL COUNTER-BREAK — ARTICLE II, SECTION 1!',
      question:
          'According to Article II, Section 1 of the 1987 Philippine Constitution, where does sovereignty reside?',
      options: <String>[
        'Sovereignty resides in the people & all government authority emanates from them',
        'Sovereignty belongs exclusively to appointed officials',
      ],
      correctIndex: 0,
      successBanner: 'SOVEREIGNTY CROWNED!',
      constitutionalNote:
          'Article II, Sec. 1 affirms that the Philippines is a democratic and republican State whose power comes from the people.',
    ),
  ),
};

/// Resolves any regular enemy, Rival Mateo, or Era Boss archetype by [id].
DungeonEnemyArchetype? lookupDungeonArchetype(String id) {
  return kDungeonBossArchetypes[id] ?? kDungeonEnemyArchetypes[id];
}

// ═══════════════════════════════════════════════════════════════════════════
//  LIVE ENEMY / BOSS INSTANCE (`DungeonCombatTarget`)
// ═══════════════════════════════════════════════════════════════════════════

class DungeonEnemyInstance implements DungeonCombatTarget {
  @override
  final String id;
  final DungeonEnemyArchetype archetype;

  double x;
  double y;
  double vx = 0.0;
  double vy = 0.0;
  final double homeX;
  final double homeY;
  final double patrolHalfWidthPx;

  @override
  int hp;
  @override
  final int maxHp;

  @override
  int facing = -1;
  bool isGrounded = false;
  double hitFlashTimer = 0.0;
  double animPhase = 0.0;

  // Finite State Machine
  DungeonEnemyAiState aiState = DungeonEnemyAiState.patrol;
  double stateTimer = 0.0;
  double attackCooldown = 0.65;
  int attackCycleIndex = 0;
  DungeonBossAttackKind currentBossAttack = DungeonBossAttackKind.dashThrust;

  // Boss Phase & Posture / Counter-Break state
  int phase = 1; // 1, 2, or 3
  double staggerAccum = 0.0;
  bool counterBreakUsedThisStagger = false;
  bool hasDealtDamageInCurrentAttack = false;

  // Aim telegraph line endpoint (rendered by `DungeonWorldPainter`!)
  Offset? aimTelegraphEnd;

  // Cached swoop/dive target vector
  double _targetVx = 0.0;
  double _targetVy = 0.0;

  DungeonEnemyInstance({
    required this.id,
    required this.archetype,
    required this.x,
    required this.y,
    required this.patrolHalfWidthPx,
    int? overrideMaxHp,
  })  : homeX = x,
        homeY = y,
        maxHp = overrideMaxHp ?? archetype.maxHp,
        hp = overrideMaxHp ?? archetype.maxHp;

  @override
  Rect get hitbox => Rect.fromLTWH(x, y, archetype.width, archetype.height);

  @override
  bool get isAlive => hp > 0;

  @override
  bool get isBoss => archetype.isBoss;

  @override
  bool get isShieldedFront =>
      archetype.hasFrontShield &&
      aiState != DungeonEnemyAiState.staggered &&
      aiState != DungeonEnemyAiState.recover;

  bool get isTelegraphing => aiState == DungeonEnemyAiState.windup;
  bool get isStaggered => aiState == DungeonEnemyAiState.staggered;

  double get hpRatio => maxHp <= 0 ? 0.0 : (hp / maxHp).clamp(0.0, 1.0);
  double get staggerRatio => archetype.staggerThreshold <= 0
      ? 0.0
      : (staggerAccum / archetype.staggerThreshold).clamp(0.0, 1.0);

  @override
  int receiveDamage({
    required int amount,
    required double knockbackVx,
    required double knockbackVy,
    required bool isSkillOrCrit,
    required double attackerCenterX,
    required double attackerCenterY,
  }) {
    if (!isAlive || aiState == DungeonEnemyAiState.phaseShift) return 0;

    // Front shield blocks standard horizontal strikes from the front;
    // downward pogo attacks from above, dashes behind, and Silk Skills bypass it!
    if (isShieldedFront && !isSkillOrCrit) {
      final attackedFromAbove = attackerCenterY < hitbox.top + 3.0;
      final attackedFromFront =
          (facing > 0 && attackerCenterX > hitbox.center.dx) ||
              (facing < 0 && attackerCenterX < hitbox.center.dx);
      if (attackedFromFront && !attackedFromAbove) {
        // Light shield pushback, zero HP damage
        vx += (knockbackVx * 0.25).clamp(-60.0, 60.0);
        return 0;
      }
    }

    final effectiveDamage = isStaggered ? (amount * 1.45).round() : amount;
    hp = math.max(0, hp - effectiveDamage);
    hitFlashTimer = 0.12;

    // Bosses resist heavy knockback so arenas stay dramatic and readable
    final kbScale = isBoss ? 0.22 : (archetype.moveSpeed == 0.0 ? 0.0 : 0.78);
    vx += knockbackVx * kbScale;
    if (!archetype.isFlying && archetype.moveSpeed > 0.0) {
      vy = math.min(vy, knockbackVy * kbScale * 0.65);
    }

    // Accumulate Boss posture toward Staggered Constitutional Counter-Break!
    if (isBoss && !isStaggered && hp > 0) {
      final postureGain = effectiveDamage * (isSkillOrCrit ? 1.55 : 1.0);
      staggerAccum = math.min(archetype.staggerThreshold, staggerAccum + postureGain);
    }

    return effectiveDamage;
  }

  /// Adds direct bonus posture shock (e.g. from a timed Habeas Aegis Golden Parry!).
  void applyParryPostureShock(double postureAmount) {
    if (!isBoss || !isAlive || isStaggered) return;
    staggerAccum = math.min(archetype.staggerThreshold, staggerAccum + postureAmount);
  }

  /// Converts live state into [DungeonEntityRenderSpec] for [DungeonWorldPainter].
  DungeonEntityRenderSpec toRenderSpec() {
    return DungeonEntityRenderSpec(
      id: id,
      archetypeId: archetype.id,
      hitbox: hitbox,
      facing: facing,
      hp: hp,
      maxHp: maxHp,
      isBoss: isBoss,
      isShieldedFront: isShieldedFront,
      isTelegraphing: isTelegraphing,
      isStaggered: isStaggered,
      hitFlashTimer: hitFlashTimer,
      primaryColor: archetype.primaryColor,
      accentColor: archetype.accentColor,
      animPhase: animPhase,
      aimTelegraphEnd: aimTelegraphEnd,
      aiStateName: aiState.name,
      bossPhase: phase,
      stateTimer: stateTimer,
      vx: vx,
      vy: vy,
      isFlying: archetype.isFlying,
      isRival: archetype.isRival,
      bossAttackName: currentBossAttack.name,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  ENEMY / BOSS EVENT STREAM & MANAGER
// ═══════════════════════════════════════════════════════════════════════════

enum DungeonEnemyEventKind {
  enemyAttacked,
  enemyDefeated,
  bossPhaseChanged,
  bossStaggered,
  counterBreakSucceeded,
  counterBreakMissed,
  bossDefeated,
}

class DungeonEnemyEvent {
  final DungeonEnemyEventKind kind;
  final String entityId;
  final String archetypeId;
  final double x;
  final double y;
  final int value;
  final String? message;
  final String? loreEntryId;
  final DungeonSfxCue? sfx;
  final double shakeIntensity;

  const DungeonEnemyEvent({
    required this.kind,
    required this.entityId,
    required this.archetypeId,
    required this.x,
    required this.y,
    this.value = 0,
    this.message,
    this.loreEntryId,
    this.sfx,
    this.shakeIntensity = 0.0,
  });
}

/// Manages all active enemies, Rival Mateo duels, and Multi-Phase Era Bosses inside
/// the current dungeon chamber, including telegraphed AI, projectiles, loot bursts,
/// and Staggered Constitutional Counter-Breaks.
class DungeonEnemyManager {
  final List<DungeonEnemyInstance> enemies = <DungeonEnemyInstance>[];
  int _projSeq = 1;
  int _lootSeq = 1;

  /// Active boss (or Rival Mateo) in the chamber, if alive.
  DungeonEnemyInstance? get activeBoss {
    for (final e in enemies) {
      if (e.isBoss && e.isAlive) return e;
    }
    return null;
  }

  /// Non-null while an Era Boss / Rival Mateo is staggered and awaiting 1-tap Counter-Break.
  DungeonCounterBreakPrompt? get activeCounterBreakPrompt {
    final boss = activeBoss;
    if (boss == null || !boss.isStaggered || boss.counterBreakUsedThisStagger) {
      return null;
    }
    return boss.archetype.counterBreak;
  }

  /// All currently alive targets passed to [DungeonCombatEngine.step].
  List<DungeonCombatTarget> get aliveCombatTargets =>
      enemies.where((e) => e.isAlive).toList(growable: false);

  /// Render descriptors passed directly to [DungeonWorldPainter].
  List<DungeonEntityRenderSpec> buildRenderSpecs() =>
      enemies.where((e) => e.isAlive).map((e) => e.toRenderSpec()).toList(growable: false);

  /// Spawns all enemies & boss specified by [spec].
  void spawnForChamber(
    DungeonChamberSpec spec, {
    required bool bossAlreadyDefeated,
    Set<String> defeatedIds = const <String>{},
  }) {
    enemies.clear();

    for (final sp in spec.enemySpawns) {
      final arch = lookupDungeonArchetype(sp.archetypeId);
      if (arch == null) continue;
      if (arch.isRival && defeatedIds.contains(sp.spawnId)) continue;
      if (arch.isBoss && !arch.isRival && bossAlreadyDefeated) continue;
      final sx = sp.col * kDungeonTileSize + (kDungeonTileSize - arch.width) * 0.5;
      final sy = (sp.row + 1) * kDungeonTileSize - arch.height;
      // Scale Rival Mateo slightly when encountered in later Acts
      final scaledHp = arch.isRival
          ? (arch.maxHp + (spec.actNumber - 2).clamp(0, 5) * 45)
          : arch.maxHp;
      enemies.add(
        DungeonEnemyInstance(
          id: sp.spawnId,
          archetype: arch,
          x: sx,
          y: sy,
          patrolHalfWidthPx: sp.patrolRadiusTiles * kDungeonTileSize,
          overrideMaxHp: scaledHp,
        ),
      );
    }

    if (spec.bossId != null && !bossAlreadyDefeated) {
      final bossArch = lookupDungeonArchetype(spec.bossId!);
      if (bossArch != null) {
        final bx = spec.bossSpawnCol * kDungeonTileSize +
            (kDungeonTileSize - bossArch.width) * 0.5;
        final by = (spec.bossSpawnRow + 1) * kDungeonTileSize - bossArch.height;
        enemies.add(
          DungeonEnemyInstance(
            id: 'boss_${spec.id}_${bossArch.id}',
            archetype: bossArch,
            x: bx,
            y: by,
            patrolHalfWidthPx: 8.0 * kDungeonTileSize,
          ),
        );
      }
    }
  }

  /// Steps every enemy and boss AI state machine, physics, telegraphed attacks,
  /// projectiles, contact/lunge collisions, boss phase transitions, and death loot drops.
  List<DungeonEnemyEvent> step({
    required double dt,
    required DungeonPlayerPhysicsState player,
    required DungeonChamberRuntime chamber,
    required DungeonCombatEngine combat,
    required DungeonProgressSave progress,
    List<DungeonCombatEvent>? combatEventsOut,
  }) {
    final events = <DungeonEnemyEvent>[];
    if (dt <= 0.0) return events;
    final safeDt = dt.clamp(0.0, 0.05);

    for (var i = enemies.length - 1; i >= 0; i--) {
      final e = enemies[i];

      // 1. Handle newly defeated enemy / boss!
      if (!e.isAlive) {
        _handleEnemyDefeated(e, chamber, combat, events);
        enemies.removeAt(i);
        continue;
      }

      e.animPhase += safeDt;
      if (e.hitFlashTimer > 0.0) {
        e.hitFlashTimer = math.max(0.0, e.hitFlashTimer - safeDt);
      }
      if (e.attackCooldown > 0.0) {
        e.attackCooldown = math.max(0.0, e.attackCooldown - safeDt);
      }
      e.aimTelegraphEnd = null;

      // 2. Boss Phase Transitions & Stagger Trigger Checks
      if (e.isBoss) {
        _checkBossPhaseAndStagger(e, combat, events);
      }

      // 3. Step AI Behavior State Machine
      _stepEnemyAi(
        e: e,
        dt: safeDt,
        player: player,
        chamber: chamber,
        combat: combat,
        events: events,
      );

      // 4. Apply Gravity & Swept Tile Collision
      _stepEnemyPhysics(e, safeDt, chamber);

      // 5. Check Contact / Active Attack Hitbox against Player (supports Golden Parry!)
      if (!e.isStaggered && e.aiState != DungeonEnemyAiState.phaseShift) {
        final attackActive = e.aiState == DungeonEnemyAiState.attack;
        final hurtbox = attackActive ? e.hitbox.inflate(2.5) : e.hitbox.deflate(1.5);
        if (hurtbox.overlaps(player.hitbox)) {
          final dmg = attackActive
              ? e.archetype.attackDamage
              : e.archetype.contactDamage;
          final combatEvs = combatEventsOut ?? <DungeonCombatEvent>[];
          final hitRes = combat.resolveIncomingPlayerHit(
            player: player,
            progress: progress,
            damage: dmg,
            sourceX: e.hitbox.center.dx,
            sourceY: e.hitbox.center.dy,
            targets: aliveCombatTargets,
            events: combatEvs,
          );
          if (hitRes.parried) {
            // Golden Parry deals HUGE posture shock to bosses & interrupts regular attackers!
            e.applyParryPostureShock(e.archetype.staggerThreshold * 0.42);
            e.vx = -e.facing * 110.0;
            e.aiState = DungeonEnemyAiState.recover;
            e.stateTimer = 0.65;
          }
        }
      }
    }

    return events;
  }

  /// Resolves the student's 1-tap Constitutional Counter-Break choice during a Boss Stagger!
  DungeonEnemyEvent? resolveCounterBreak({
    required int chosenOptionIndex,
    required DungeonPlayerPhysicsState player,
    required DungeonCombatEngine combat,
    required DungeonProgressSave progress,
  }) {
    final boss = activeBoss;
    final prompt = activeCounterBreakPrompt;
    if (boss == null || prompt == null) return null;

    boss.counterBreakUsedThisStagger = true;
    final isCorrect = chosenOptionIndex == prompt.correctIndex;

    if (isCorrect) {
      // MASSIVE Golden Constitutional Finisher!
      final finisherDmg = math.max(45, (boss.maxHp * 0.25).round());
      boss.hp = math.max(0, boss.hp - finisherDmg);
      boss.hitFlashTimer = 0.26;
      boss.staggerAccum = 0.0;
      boss.aiState = DungeonEnemyAiState.recover;
      boss.stateTimer = 0.85;

      // Refill Silk & restore +2 Resolve Masks + dramatic 110ms Hit-Stop!
      player.civicSilk = player.maxCivicSilk;
      player.resolveHp = math.min(player.maxResolveHp, player.resolveHp + 2);
      combat.hitStop.trigger(0.110);
      combat.floatingNumbers.add(
        FloatingCombatNumber(
          text: '${prompt.successBanner} -$finisherDmg',
          color: SpriteCastPalette.endesga32[11],
          x: boss.hitbox.center.dx,
          y: boss.hitbox.top - 10.0,
          isCritical: true,
          durationSec: 1.15,
        ),
      );

      return DungeonEnemyEvent(
        kind: DungeonEnemyEventKind.counterBreakSucceeded,
        entityId: boss.id,
        archetypeId: boss.archetype.id,
        x: boss.hitbox.center.dx,
        y: boss.hitbox.center.dy,
        value: finisherDmg,
        message: prompt.successBanner,
        loreEntryId: prompt.loreEntryId,
        sfx: DungeonSfxCue.parryGoldenClang,
        shakeIntensity: 7.5,
      );
    } else {
      // Boss shakes off stagger and resumes battle cleanly (no harsh penalty!)
      boss.staggerAccum = 0.0;
      boss.aiState = DungeonEnemyAiState.recover;
      boss.stateTimer = 0.45;
      combat.floatingNumbers.add(
        FloatingCombatNumber(
          text: 'GUARD RECOVERED',
          color: SpriteCastPalette.endesga32[20],
          x: boss.hitbox.center.dx,
          y: boss.hitbox.top - 8.0,
        ),
      );
      return DungeonEnemyEvent(
        kind: DungeonEnemyEventKind.counterBreakMissed,
        entityId: boss.id,
        archetypeId: boss.archetype.id,
        x: boss.hitbox.center.dx,
        y: boss.hitbox.center.dy,
        sfx: DungeonSfxCue.shieldClang,
      );
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  INTERNAL BOSS PHASE, STAGGER & AI STATE MACHINES
  // ═══════════════════════════════════════════════════════════════════════════

  void _checkBossPhaseAndStagger(
    DungeonEnemyInstance boss,
    DungeonCombatEngine combat,
    List<DungeonEnemyEvent> events,
  ) {
    // 1. Check Phase 2 (<= 62% HP) and Phase 3 (<= 32% HP for 3-phase bosses)
    final ratio = boss.hpRatio;
    var targetPhase = boss.phase;
    if (boss.archetype.hasThreePhases && ratio <= 0.32 && boss.phase < 3) {
      targetPhase = 3;
    } else if (ratio <= 0.62 && boss.phase < 2) {
      targetPhase = 2;
    }

    if (targetPhase != boss.phase) {
      boss.phase = targetPhase;
      boss.aiState = DungeonEnemyAiState.phaseShift;
      boss.stateTimer = 0.72;
      boss.vx = 0.0;
      boss.attackCooldown = 0.35;
      combat.floatingNumbers.add(
        FloatingCombatNumber(
          text: 'PHASE $targetPhase!',
          color: SpriteCastPalette.endesga32[9],
          x: boss.hitbox.center.dx,
          y: boss.hitbox.top - 12.0,
          isCritical: true,
          durationSec: 1.0,
        ),
      );
      events.add(
        DungeonEnemyEvent(
          kind: DungeonEnemyEventKind.bossPhaseChanged,
          entityId: boss.id,
          archetypeId: boss.archetype.id,
          x: boss.hitbox.center.dx,
          y: boss.hitbox.center.dy,
          value: targetPhase,
          message: '${boss.archetype.displayName} — Phase $targetPhase!',
          sfx: DungeonSfxCue.bossTelegraphHorn,
          shakeIntensity: 6.0,
        ),
      );
      return;
    }

    // 2. Check Posture Stagger -> Opens Staggered Constitutional Counter-Break!
    if (boss.aiState != DungeonEnemyAiState.staggered &&
        boss.aiState != DungeonEnemyAiState.phaseShift &&
        boss.staggerAccum >= boss.archetype.staggerThreshold) {
      boss.aiState = DungeonEnemyAiState.staggered;
      boss.stateTimer = 3.8; // Generous window to tap the Constitutional Counter!
      boss.counterBreakUsedThisStagger = false;
      boss.vx = 0.0;
      combat.hitStop.trigger(0.085);
      combat.floatingNumbers.add(
        FloatingCombatNumber(
          text: 'STAGGERED!',
          color: SpriteCastPalette.endesga32[11],
          x: boss.hitbox.center.dx,
          y: boss.hitbox.top - 12.0,
          isCritical: true,
          durationSec: 1.0,
        ),
      );
      events.add(
        DungeonEnemyEvent(
          kind: DungeonEnemyEventKind.bossStaggered,
          entityId: boss.id,
          archetypeId: boss.archetype.id,
          x: boss.hitbox.center.dx,
          y: boss.hitbox.center.dy,
          message: 'COUNTER-BREAK READY!',
          sfx: DungeonSfxCue.parryGoldenClang,
          shakeIntensity: 5.5,
        ),
      );
    }
  }

  void _stepEnemyAi({
    required DungeonEnemyInstance e,
    required double dt,
    required DungeonPlayerPhysicsState player,
    required DungeonChamberRuntime chamber,
    required DungeonCombatEngine combat,
    required List<DungeonEnemyEvent> events,
  }) {
    final dx = player.centerX - e.hitbox.center.dx;
    final dy = player.centerY - e.hitbox.center.dy;
    final dist = math.sqrt(dx * dx + dy * dy);
    final dirToPlayer = dx >= 0 ? 1 : -1;

    switch (e.aiState) {
      case DungeonEnemyAiState.phaseShift:
        e.stateTimer -= dt;
        e.vx *= 0.85;
        if (e.stateTimer <= 0.0) {
          // Emit dramatic phase-shift radial burst
          _spawnRadialVolley(e, combat, count: e.phase >= 3 ? 8 : 6, speed: 112.0);
          e.aiState = DungeonEnemyAiState.patrol;
        }
        return;

      case DungeonEnemyAiState.staggered:
        e.stateTimer -= dt;
        e.vx *= 0.82;
        if (e.stateTimer <= 0.0) {
          e.staggerAccum = 0.0;
          e.aiState = DungeonEnemyAiState.recover;
          e.stateTimer = 0.40;
        }
        return;

      case DungeonEnemyAiState.recover:
        e.stateTimer -= dt;
        e.vx *= 0.86;
        if (e.archetype.isFlying) e.vy *= 0.86;
        if (e.stateTimer <= 0.0) {
          e.aiState = DungeonEnemyAiState.patrol;
          final phaseSpeedMult = e.isBoss ? (1.0 - (e.phase - 1) * 0.16) : 1.0;
          e.attackCooldown = (e.archetype.recoverSec * phaseSpeedMult).clamp(0.24, 1.2);
        }
        return;

      case DungeonEnemyAiState.patrol:
        _stepPatrolOrChase(e, dt, dx, dy, dist, dirToPlayer, chamber);
        if (dist <= e.archetype.attackRangePx && e.attackCooldown <= 0.0) {
          _beginTelegraphWindup(e, player, dx, dy, dirToPlayer);
        }
        return;

      case DungeonEnemyAiState.windup:
        e.stateTimer -= dt;
        e.vx *= 0.78;
        if (e.archetype.isFlying) e.vy *= 0.78;
        // Aim laser telegraph for marksmen & sniper bosses
        if (e.archetype.behavior == DungeonEnemyBehavior.laserMarksman ||
            (e.isBoss &&
                e.currentBossAttack == DungeonBossAttackKind.aimedSniperBarrage)) {
          e.facing = dirToPlayer;
          e.aimTelegraphEnd = Offset(player.centerX, player.centerY);
        }
        if (e.stateTimer <= 0.0) {
          _executeAttack(e, player, dx, dy, combat, events);
        }
        return;

      case DungeonEnemyAiState.attack:
        e.stateTimer -= dt;
        if (e.archetype.behavior == DungeonEnemyBehavior.swoopingFlyer) {
          e.vx = e._targetVx;
          e.vy = e._targetVy;
        }
        if (e.stateTimer <= 0.0) {
          e.aiState = DungeonEnemyAiState.recover;
          e.stateTimer = e.archetype.recoverSec * (e.isBoss ? 0.78 : 1.0);
        }
        return;
    }
  }

  void _stepPatrolOrChase(
    DungeonEnemyInstance e,
    double dt,
    double dx,
    double dy,
    double dist,
    int dirToPlayer,
    DungeonChamberRuntime chamber,
  ) {
    final arch = e.archetype;
    if (arch.moveSpeed <= 0.0) {
      e.facing = dirToPlayer;
      e.vx = 0.0;
      return;
    }

    final speedMult = e.isBoss ? (1.0 + (e.phase - 1) * 0.18) : 1.0;

    if (arch.isFlying) {
      if (dist <= arch.aggroRangePx) {
        e.facing = dirToPlayer;
        // Hover slightly above player's head at comfortable attack altitude
        final desiredX = e.hitbox.center.dx +
            (dx.abs() > arch.attackRangePx * 0.65 ? dirToPlayer * 24.0 : -dirToPlayer * 12.0);
        final desiredY = (e.homeY - 8.0) + math.sin(e.animPhase * 2.8) * 10.0;
        final toX = desiredX - e.hitbox.center.dx;
        final toY = desiredY - e.hitbox.center.dy;
        final len = math.max(1.0, math.sqrt(toX * toX + toY * toY));
        e.vx = (toX / len) * arch.moveSpeed * speedMult;
        e.vy = (toY / len) * arch.moveSpeed * 0.65;
      } else {
        // Gentle figure-8 cave hover around home point
        final targetX = e.homeX + math.sin(e.animPhase * 1.3) * e.patrolHalfWidthPx * 0.5;
        final targetY = e.homeY + math.cos(e.animPhase * 2.1) * 10.0;
        e.vx = (targetX - e.x).clamp(-arch.moveSpeed, arch.moveSpeed);
        e.vy = (targetY - e.y).clamp(-arch.moveSpeed * 0.6, arch.moveSpeed * 0.6);
        if (e.vx.abs() > 4.0) e.facing = e.vx >= 0 ? 1 : -1;
      }
      return;
    }

    // Grounded movement: chase within aggro range, or patrol safely within ledge bounds
    if (dist <= arch.aggroRangePx) {
      e.facing = dirToPlayer;
      final keepDistance = arch.behavior == DungeonEnemyBehavior.laserMarksman;
      if (keepDistance && dx.abs() < 64.0) {
        e.vx = -dirToPlayer * arch.moveSpeed * 0.7;
      } else if (dx.abs() > 12.0) {
        e.vx = dirToPlayer * arch.moveSpeed * speedMult;
      } else {
        e.vx *= 0.8;
      }
      // Rival Mateo & agile bosses hop over small obstacles if blocked!
      if (e.isGrounded &&
          (arch.isRival || arch.behavior == DungeonEnemyBehavior.leapingRaider) &&
          _hasWallAhead(e, chamber)) {
        e.vy = -240.0;
      }
    } else {
      // Calm ledge patrol (turns around at patrol limit, wall, or cliff edge!)
      if (e.x <= e.homeX - e.patrolHalfWidthPx) e.facing = 1;
      if (e.x >= e.homeX + e.patrolHalfWidthPx) e.facing = -1;
      if (_hasWallAhead(e, chamber) || !_hasFloorAhead(e, chamber)) {
        e.facing = -e.facing;
      }
      e.vx = e.facing * arch.moveSpeed * 0.62;
    }
  }

  void _beginTelegraphWindup(
    DungeonEnemyInstance e,
    DungeonPlayerPhysicsState player,
    double dx,
    double dy,
    int dirToPlayer,
  ) {
    e.facing = dirToPlayer;
    e.aiState = DungeonEnemyAiState.windup;
    e.hasDealtDamageInCurrentAttack = false;

    final phaseSpeedup = e.isBoss ? (1.0 - (e.phase - 1) * 0.14) : 1.0;
    e.stateTimer = (e.archetype.windupSec * phaseSpeedup).clamp(0.28, 0.75);

    if (e.isBoss) {
      final pool = e.phase >= 3 && e.archetype.phase3Attacks.isNotEmpty
          ? e.archetype.phase3Attacks
          : (e.phase >= 2 && e.archetype.phase2Attacks.isNotEmpty
              ? e.archetype.phase2Attacks
              : e.archetype.phase1Attacks);
      if (pool.isNotEmpty) {
        e.currentBossAttack = pool[e.attackCycleIndex % pool.length];
        e.attackCycleIndex++;
      }
    }

    // Subtle pull-back anticipation impulse (`craft-game-floors` telegraph!)
    if (!e.archetype.isFlying && e.archetype.moveSpeed > 0.0) {
      e.vx = -dirToPlayer * 22.0;
    }
  }

  void _executeAttack(
    DungeonEnemyInstance e,
    DungeonPlayerPhysicsState player,
    double dx,
    double dy,
    DungeonCombatEngine combat,
    List<DungeonEnemyEvent> events,
  ) {
    e.aiState = DungeonEnemyAiState.attack;
    e.stateTimer = e.archetype.attackDurationSec;
    final dir = e.facing;

    if (e.isBoss) {
      _executeBossAttack(e, player, dx, dy, combat);
    } else {
      switch (e.archetype.behavior) {
        case DungeonEnemyBehavior.patrolLunger:
        case DungeonEnemyBehavior.shieldedLancer:
          e.vx = dir * (e.archetype.moveSpeed * 2.85);
          break;
        case DungeonEnemyBehavior.leapingRaider:
          e.vx = dir * 155.0;
          e.vy = -255.0;
          break;
        case DungeonEnemyBehavior.swoopingFlyer:
          final len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
          e._targetVx = (dx / len) * 165.0;
          e._targetVy = (dy / len) * 145.0;
          e.vx = e._targetVx;
          e.vy = e._targetVy;
          break;
        case DungeonEnemyBehavior.laserMarksman:
          _spawnAimedBolt(e, player, combat, speed: 185.0);
          break;
        case DungeonEnemyBehavior.spreadCaster:
          _spawnFanVolley(e, player, combat, count: 3, spreadRad: 0.42, speed: 125.0);
          break;
        case DungeonEnemyBehavior.mortarTurret:
          _spawnParabolicShell(e, player, combat);
          break;
        case DungeonEnemyBehavior.juggernautSlammer:
          _spawnGroundShockwaves(e, combat, speed: 135.0);
          break;
        case DungeonEnemyBehavior.rivalDuelist:
        case DungeonEnemyBehavior.multiPhaseBoss:
          _executeBossAttack(e, player, dx, dy, combat);
          break;
      }
    }

    events.add(
      DungeonEnemyEvent(
        kind: DungeonEnemyEventKind.enemyAttacked,
        entityId: e.id,
        archetypeId: e.archetype.id,
        x: e.hitbox.center.dx,
        y: e.hitbox.center.dy,
        sfx: e.isBoss ? DungeonSfxCue.slashFinisher : DungeonSfxCue.slashLight,
      ),
    );
  }

  void _executeBossAttack(
    DungeonEnemyInstance boss,
    DungeonPlayerPhysicsState player,
    double dx,
    double dy,
    DungeonCombatEngine combat,
  ) {
    final speedBoost = 1.0 + (boss.phase - 1) * 0.16;
    switch (boss.currentBossAttack) {
      case DungeonBossAttackKind.dashThrust:
        boss.vx = boss.facing * 230.0 * speedBoost;
        break;
      case DungeonBossAttackKind.groundShockwaveSlam:
        boss.vx = 0.0;
        _spawnGroundShockwaves(boss, combat, speed: 142.0 * speedBoost);
        break;
      case DungeonBossAttackKind.fanVolley:
        _spawnFanVolley(
          boss,
          player,
          combat,
          count: boss.phase >= 2 ? 5 : 3,
          spreadRad: boss.phase >= 2 ? 0.72 : 0.48,
          speed: 132.0 * speedBoost,
        );
        break;
      case DungeonBossAttackKind.aimedSniperBarrage:
        _spawnAimedBolt(boss, player, combat, speed: 195.0 * speedBoost);
        if (boss.phase >= 2) {
          _spawnAimedBolt(boss, player, combat, speed: 155.0 * speedBoost);
        }
        break;
      case DungeonBossAttackKind.leapingDiveSlam:
        boss.vx = boss.facing * 175.0 * speedBoost;
        boss.vy = -275.0;
        _spawnGroundShockwaves(boss, combat, speed: 118.0 * speedBoost);
        break;
      case DungeonBossAttackKind.parabolicArtillery:
        _spawnParabolicShell(boss, player, combat);
        if (boss.phase >= 2) {
          _spawnParabolicShell(boss, player, combat, arcOffsetVx: boss.facing * 35.0);
        }
        break;
      case DungeonBossAttackKind.radialDecreeNova:
        _spawnRadialVolley(
          boss,
          combat,
          count: boss.phase >= 3 ? 8 : 6,
          speed: 118.0 * speedBoost,
        );
        break;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  PROJECTILE SPAWNERS (ALL DEFLECTABLE BY SCALES TEMPEST!)
  // ═══════════════════════════════════════════════════════════════════════════

  void _spawnAimedBolt(
    DungeonEnemyInstance src,
    DungeonPlayerPhysicsState player,
    DungeonCombatEngine combat, {
    required double speed,
  }) {
    final dx = player.centerX - src.hitbox.center.dx;
    final dy = player.centerY - src.hitbox.center.dy;
    final len = math.max(1.0, math.sqrt(dx * dx + dy * dy));
    combat.projectiles.add(
      DungeonProjectile(
        id: 'ep_${_projSeq++}',
        isPlayerOwned: false,
        deflectable: true,
        x: src.hitbox.center.dx + src.facing * (src.archetype.width * 0.45),
        y: src.hitbox.center.dy,
        vx: (dx / len) * speed,
        vy: (dy / len) * speed,
        radius: src.isBoss ? 4.5 : 3.5,
        damage: src.archetype.attackDamage,
        color: src.archetype.accentColor,
      ),
    );
  }

  void _spawnFanVolley(
    DungeonEnemyInstance src,
    DungeonPlayerPhysicsState player,
    DungeonCombatEngine combat, {
    required int count,
    required double spreadRad,
    required double speed,
  }) {
    final baseAngle = math.atan2(
      player.centerY - src.hitbox.center.dy,
      player.centerX - src.hitbox.center.dx,
    );
    for (var i = 0; i < count; i++) {
      final frac = count == 1 ? 0.0 : (i / (count - 1)) - 0.5;
      final angle = baseAngle + frac * spreadRad;
      combat.projectiles.add(
        DungeonProjectile(
          id: 'ep_${_projSeq++}',
          isPlayerOwned: false,
          deflectable: true,
          x: src.hitbox.center.dx,
          y: src.hitbox.center.dy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          radius: 4.0,
          damage: src.archetype.attackDamage,
          color: src.archetype.accentColor,
        ),
      );
    }
  }

  void _spawnRadialVolley(
    DungeonEnemyInstance src,
    DungeonCombatEngine combat, {
    required int count,
    required double speed,
  }) {
    for (var i = 0; i < count; i++) {
      final angle = (i * math.pi * 2.0) / count;
      combat.projectiles.add(
        DungeonProjectile(
          id: 'ep_${_projSeq++}',
          isPlayerOwned: false,
          deflectable: true,
          x: src.hitbox.center.dx,
          y: src.hitbox.center.dy,
          vx: math.cos(angle) * speed,
          vy: math.sin(angle) * speed,
          radius: 4.2,
          damage: src.archetype.attackDamage,
          color: SpriteCastPalette.endesga32[11],
        ),
      );
    }
  }

  void _spawnGroundShockwaves(
    DungeonEnemyInstance src,
    DungeonCombatEngine combat, {
    required double speed,
  }) {
    final footY = src.hitbox.bottom - 4.0;
    for (final dir in const <int>[-1, 1]) {
      combat.projectiles.add(
        DungeonProjectile(
          id: 'ep_${_projSeq++}',
          isPlayerOwned: false,
          deflectable: true,
          x: src.hitbox.center.dx + dir * 6.0,
          y: footY,
          vx: dir * speed,
          vy: 0.0,
          radius: 5.0,
          damage: src.archetype.attackDamage,
          color: SpriteCastPalette.endesga32[9],
          remainingLifeSec: 1.8,
        ),
      );
    }
  }

  void _spawnParabolicShell(
    DungeonEnemyInstance src,
    DungeonPlayerPhysicsState player,
    DungeonCombatEngine combat, {
    double arcOffsetVx = 0.0,
  }) {
    final dx = (player.centerX - src.hitbox.center.dx).clamp(-165.0, 165.0);
    combat.projectiles.add(
      DungeonProjectile(
        id: 'ep_${_projSeq++}',
        isPlayerOwned: false,
        deflectable: true,
        x: src.hitbox.center.dx,
        y: src.hitbox.top + 2.0,
        vx: dx * 1.22 + arcOffsetVx,
        vy: -135.0,
        gravity: 420.0,
        radius: 4.5,
        damage: src.archetype.attackDamage,
        color: SpriteCastPalette.endesga32[9],
        remainingLifeSec: 2.6,
      ),
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  ENEMY PHYSICS & DEFEAT LOOT DROPS
  // ═══════════════════════════════════════════════════════════════════════════

  void _stepEnemyPhysics(
    DungeonEnemyInstance e,
    double dt,
    DungeonChamberRuntime chamber,
  ) {
    if (!e.archetype.isFlying) {
      e.vy = math.min(360.0, e.vy + 760.0 * dt);
    }

    // Horizontal move + solid wall clamp
    final nextX = e.x + e.vx * dt;
    if (!_collidesSolid(nextX, e.y, e.archetype.width, e.archetype.height, chamber)) {
      e.x = nextX;
    } else {
      e.vx = 0.0;
    }

    // Vertical move + floor/one-way-bridge/ceiling clamp
    final prevBottom = e.y + e.archetype.height;
    final nextY = e.y + e.vy * dt;
    if (e.vy >= 0.0) {
      final bottomRow = ((nextY + e.archetype.height) / kDungeonTileSize).floor();
      final minC = (e.x / kDungeonTileSize).floor();
      final maxC = ((e.x + e.archetype.width - 0.1) / kDungeonTileSize).floor();
      final tileTop = bottomRow * kDungeonTileSize;
      var landed = false;
      for (var c = minC; c <= maxC; c++) {
        final tile = chamber.effectiveTileAt(c, bottomRow);
        if (chamber.isSolidAt(c, bottomRow) ||
            (!e.archetype.isFlying &&
                tile.isOneWay &&
                prevBottom <= tileTop + 2.5)) {
          landed = true;
          break;
        }
      }
      if (landed) {
        e.y = tileTop - e.archetype.height;
        e.vy = 0.0;
        e.isGrounded = true;
      } else {
        e.y = nextY;
        e.isGrounded = false;
      }
    } else {
      if (!_collidesSolid(e.x, nextY, e.archetype.width, e.archetype.height, chamber)) {
        e.y = nextY;
        e.isGrounded = false;
      } else {
        final topRow = (nextY / kDungeonTileSize).floor();
        e.y = (topRow + 1) * kDungeonTileSize;
        e.vy = 0.0;
      }
    }
  }

  bool _collidesSolid(
    double left,
    double top,
    double w,
    double h,
    DungeonChamberRuntime chamber,
  ) {
    final minC = (left / kDungeonTileSize).floor();
    final maxC = ((left + w - 0.1) / kDungeonTileSize).floor();
    final minR = (top / kDungeonTileSize).floor();
    final maxR = ((top + h - 0.1) / kDungeonTileSize).floor();
    for (var r = minR; r <= maxR; r++) {
      for (var c = minC; c <= maxC; c++) {
        if (chamber.isSolidAt(c, r)) return true;
      }
    }
    return false;
  }

  bool _hasWallAhead(DungeonEnemyInstance e, DungeonChamberRuntime chamber) {
    final probeX = e.facing > 0 ? e.x + e.archetype.width + 2.0 : e.x - 2.0;
    final col = (probeX / kDungeonTileSize).floor();
    final row = ((e.y + e.archetype.height * 0.5) / kDungeonTileSize).floor();
    return chamber.isSolidAt(col, row);
  }

  bool _hasFloorAhead(DungeonEnemyInstance e, DungeonChamberRuntime chamber) {
    final probeX = e.facing > 0 ? e.x + e.archetype.width + 3.0 : e.x - 3.0;
    final col = (probeX / kDungeonTileSize).floor();
    final row = ((e.y + e.archetype.height + 3.0) / kDungeonTileSize).floor();
    final tile = chamber.effectiveTileAt(col, row);
    return (chamber.isSolidAt(col, row) || tile.isOneWay) && !tile.isHazard;
  }

  void _handleEnemyDefeated(
    DungeonEnemyInstance e,
    DungeonChamberRuntime chamber,
    DungeonCombatEngine combat,
    List<DungeonEnemyEvent> events,
  ) {
    final cx = e.hitbox.center.dx;
    final cy = e.hitbox.center.dy;
    final shardCount = e.isBoss ? 8 : 3;
    final shardValue = math.max(
      2,
      ((e.archetype.shardDropMin + e.archetype.shardDropMax) ~/ 2) ~/ shardCount,
    );

    for (var i = 0; i < shardCount; i++) {
      final spread = (i - (shardCount - 1) * 0.5) * 28.0;
      chamber.lootDrops.add(
        DungeonLootDrop(
          id: 'eloot_${_lootSeq++}',
          kind: DungeonLootKind.archipelagoShard,
          amount: shardValue,
          x: cx,
          y: cy,
          vx: spread,
          vy: -115.0 - (i % 3) * 24.0,
        ),
      );
    }

    // Drop a glowing Silk Mote (and Resolve Orb on bosses/heavy foes!)
    chamber.lootDrops.add(
      DungeonLootDrop(
        id: 'eloot_${_lootSeq++}',
        kind: DungeonLootKind.silkMote,
        amount: e.isBoss ? 25 : 10,
        x: cx + 4.0,
        y: cy,
        vx: 22.0,
        vy: -135.0,
      ),
    );
    if (e.isBoss || e.archetype.maxHp >= 65) {
      chamber.lootDrops.add(
        DungeonLootDrop(
          id: 'eloot_${_lootSeq++}',
          kind: DungeonLootKind.resolveOrb,
          amount: e.isBoss ? 2 : 1,
          x: cx - 4.0,
          y: cy,
          vx: -24.0,
          vy: -145.0,
        ),
      );
    }

    if (e.isBoss) {
      combat.hitStop.trigger(0.120);
      combat.floatingNumbers.add(
        FloatingCombatNumber(
          text: '${e.archetype.displayName.toUpperCase()} DEFEATED!',
          color: SpriteCastPalette.endesga32[11],
          x: cx,
          y: cy - 14.0,
          isCritical: true,
          durationSec: 1.4,
        ),
      );
      events.add(
        DungeonEnemyEvent(
          kind: DungeonEnemyEventKind.bossDefeated,
          entityId: e.id,
          archetypeId: e.archetype.id,
          x: cx,
          y: cy,
          value: e.archetype.xpReward,
          message: '${e.archetype.displayName} Vanquished!',
          loreEntryId: e.archetype.counterBreak?.loreEntryId,
          sfx: DungeonSfxCue.victoryFanfare,
          shakeIntensity: 8.5,
        ),
      );
    } else {
      events.add(
        DungeonEnemyEvent(
          kind: DungeonEnemyEventKind.enemyDefeated,
          entityId: e.id,
          archetypeId: e.archetype.id,
          x: cx,
          y: cy,
          value: e.archetype.xpReward,
          sfx: DungeonSfxCue.enemyHit,
          shakeIntensity: 2.5,
        ),
      );
    }
  }
}
