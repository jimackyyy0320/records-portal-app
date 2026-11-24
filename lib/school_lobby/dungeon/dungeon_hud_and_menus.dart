import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../spritecast_engine.dart';
import 'dungeon_enemies.dart';
import 'dungeon_maps.dart';
import 'dungeon_models.dart';

// ═══════════════════════════════════════════════════════════════════════════
//  PURE BENCH CRAFTING, FORGE, CHARM NOTCH & MASTERY TRIAL LOGIC
// ═══════════════════════════════════════════════════════════════════════════

/// Outcome of a Bench Forge, Charm Equip, Skill Swap, or Mastery Trial action.
class DungeonBenchResult {
  final DungeonProgressSave progress;
  final bool success;
  final String message;
  final int xpAwarded;

  const DungeonBenchResult({
    required this.progress,
    required this.success,
    required this.message,
    this.xpAwarded = 0,
  });
}

/// Subject-aligned *Saligang Tala* Mastery Trial taken at Bahay-Pulungan Benches.
class DungeonMasteryTrialQuestion {
  final String id;
  final int actNumber;
  final String subjectTag;
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final String explanation;

  const DungeonMasteryTrialQuestion({
    required this.id,
    required this.actNumber,
    required this.subjectTag,
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.explanation,
  });
}

/// 14 SHS-aligned Constitutional, History, Culture & Philosophy Bench Trials (2 per Act).
const List<DungeonMasteryTrialQuestion> kDungeonMasteryTrials =
    <DungeonMasteryTrialQuestion>[
  DungeonMasteryTrialQuestion(
    id: 'trial_act1_a',
    actNumber: 1,
    subjectTag: 'PKLP • Pre-Colonial',
    prompt: 'What was the traditional socio-political unit of pre-colonial Philippines?',
    choices: <String>[
      'The Barangay led by a Datu and council of elders',
      'A centralized imperial province ruled from Europe',
      'A feudal shogunate divided by samurai clans',
    ],
    correctIndex: 0,
    explanation:
        'Pre-colonial communities organized into autonomous barangays governed through customary law.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act1_b',
    actNumber: 1,
    subjectTag: 'UCSP • Civic Custom',
    prompt: 'What did the Sanduguan ritual symbolize between two barangays?',
    choices: <String>[
      'A solemn blood-compact pact of alliance and mutual trust',
      'An unconditional surrender of land ownership',
      'A taxation tribute paid to foreign ships',
    ],
    correctIndex: 0,
    explanation:
        'Sanduguan sealed peaceful diplomacy, brotherhood, and mutual defense.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act2_a',
    actNumber: 2,
    subjectTag: 'PKLP • Propaganda',
    prompt: 'Which publication served as the voice of the Filipino Propaganda Movement?',
    choices: <String>[
      'La Solidaridad',
      'Gaceta de Madrid',
      'El Comercio Real',
    ],
    correctIndex: 0,
    explanation:
        'La Solidaridad campaigned for civil liberties, press freedom, and equal rights.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act2_b',
    actNumber: 2,
    subjectTag: 'PHILO • Kartilya',
    prompt: 'According to Emilio Jacinto\'s Kartilya, what defines true human nobility?',
    choices: <String>[
      'Moral character, honor, and equal dignity of all persons',
      'Wealth and aristocratic lineage alone',
      'Unquestioning obedience to unjust commands',
    ],
    correctIndex: 0,
    explanation:
        'The Kartilya anchored Philippine civic ethics on universal human dignity and equality.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act3_a',
    actNumber: 3,
    subjectTag: 'PPG • 1899 Charter',
    prompt: 'Where was the 1899 Malolos Constitution drafted and proclaimed?',
    choices: <String>[
      'Barasoain Church in Malolos, Bulacan',
      'Fort Santiago in Intramuros',
      'Malinta Tunnel in Corregidor',
    ],
    correctIndex: 0,
    explanation:
        'The Malolos Congress met at Barasoain Church to frame Asia\'s first democratic republic.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act3_b',
    actNumber: 3,
    subjectTag: 'PPG • Separation of Powers',
    prompt: 'Why did the Malolos Charter separate Legislative, Executive, and Judicial branches?',
    choices: <String>[
      'To prevent concentration of absolute power in one office',
      'To abolish all courts and elections',
      'To hand lawmaking exclusively to military governors',
    ],
    correctIndex: 0,
    explanation:
        'Separation of powers protects citizens from arbitrary rule by balancing state authority.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act4_a',
    actNumber: 4,
    subjectTag: 'PPG • 1935 Charter',
    prompt: 'What 10-year transitional government was established under the 1935 Constitution?',
    choices: <String>[
      'The Commonwealth of the Philippines',
      'The First Malolos Republic',
      'The Parliamentary Assembly of 1973',
    ],
    correctIndex: 0,
    explanation:
        'The Commonwealth prepared the archipelago for full constitutional independence.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act4_b',
    actNumber: 4,
    subjectTag: 'UCSP • Suffrage',
    prompt: 'How did Filipino women win the constitutional right to vote in 1937?',
    choices: <String>[
      'Over 447,000 women voted "Yes" in a nationwide plebiscite',
      'By a foreign treaty with no Filipino vote',
      'Only appointed senators were allowed to vote',
    ],
    correctIndex: 0,
    explanation:
        'The 1937 plebiscite was a landmark victory for democratic inclusion and equal suffrage.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act5_a',
    actNumber: 5,
    subjectTag: 'PPG • Legitimacy',
    prompt: 'Why is free popular ratification vital to a legitimate constitution?',
    choices: <String>[
      'Because constitutional authority must come from the free consent of the people',
      'Because laws should be written secretly during occupation',
      'Because citizens have no voice in fundamental law',
    ],
    correctIndex: 0,
    explanation:
        'Without free ratification, a charter imposed under occupation lacks popular sovereignty.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act5_b',
    actNumber: 5,
    subjectTag: 'PPG • Art. II Sec. 3',
    prompt: 'What does "civilian supremacy over the military" mean in constitutional governance?',
    choices: <String>[
      'Elected civilian institutions hold supreme authority over armed forces at all times',
      'Military tribunals replace all civilian courts permanently',
      'Soldiers write statutes instead of Congress',
    ],
    correctIndex: 0,
    explanation:
        'Article II, Section 3 affirms civilian authority is, at all times, supreme over the military.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act6_a',
    actNumber: 6,
    subjectTag: 'PPG • Bill of Rights',
    prompt: 'What is the primary purpose of the Writ of Habeas Corpus?',
    choices: <String>[
      'To require authorities to bring a detained person before a court to verify lawful arrest',
      'To permit indefinite detention without trial',
      'To censor independent newspapers',
    ],
    correctIndex: 0,
    explanation:
        'Habeas Corpus is a cornerstone constitutional safeguard against arbitrary detention.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act6_b',
    actNumber: 6,
    subjectTag: 'UCSP • 1986 EDSA',
    prompt: 'How did the 1986 EDSA People Power Revolution reshape Philippine governance?',
    choices: <String>[
      'Millions peacefully united to restore democratic institutions and civil liberties',
      'It permanently suspended the Bill of Rights',
      'It dissolved all local barangays',
    ],
    correctIndex: 0,
    explanation:
        'Peaceful civic solidarity restored constitutional democracy and led to the 1987 Charter.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act7_a',
    actNumber: 7,
    subjectTag: 'PPG • 1987 Art. II',
    prompt: 'Under Article II, Section 1 of the 1987 Constitution, where does sovereignty reside?',
    choices: <String>[
      'In the people, and all government authority emanates from them',
      'In a single lifelong executive decree',
      'Only in unelected councils',
    ],
    correctIndex: 0,
    explanation:
        'Popular sovereignty is the bedrock of the democratic and republican Philippine State.',
  ),
  DungeonMasteryTrialQuestion(
    id: 'trial_act7_b',
    actNumber: 7,
    subjectTag: 'PPG • Art. III Due Process',
    prompt: 'What does Article III, Section 1 guarantee to every person in the Philippines?',
    choices: <String>[
      'No deprivation of life, liberty, or property without due process, nor denial of equal protection',
      'Immunity from all community laws for wealthy citizens',
      'Government authority to search homes without warrants',
    ],
    correctIndex: 0,
    explanation:
        'Due process and equal protection shield every citizen under the 1987 Bill of Rights.',
  ),
];

/// Pure, deterministic Bench Crafting, Forge, Charm Loadout, and Trial logic.
class DungeonBenchLogic {
  DungeonBenchLogic._();

  static const int kResolveElixirShardCost = 25;
  static const int kMaxElixirs = 5;

  /// Returns the next forgeable [DungeonBladeTier], or `null` if already Masterwork.
  static DungeonBladeTier? nextBladeTier(DungeonBladeTier current) {
    final nextIdx = current.index + 1;
    if (nextIdx >= DungeonBladeTier.values.length) return null;
    return DungeonBladeTier.values[nextIdx];
  }

  /// Shard cost to forge the next permanent Charm Notch (`4 -> 5 -> 6 -> 7 -> 8`).
  static int nextNotchShardCost(DungeonProgressSave progress) {
    return 65 + (progress.maxCharmNotches - 4).clamp(0, 4) * 35;
  }

  /// Forges the next Blade Tier at a Bahay-Pulungan Bench Workbench!
  static DungeonBenchResult upgradeBladeTier(DungeonProgressSave progress) {
    final next = nextBladeTier(progress.bladeTier);
    if (next == null) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Your blade is already forged to Sovereign Masterwork!',
      );
    }
    final cost = next.upgradeShardCost;
    if (progress.archipelagoShards < cost) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Need $cost Shards to forge ${next.displayName}.',
      );
    }
    final updated = progress.copyWith(
      archipelagoShards: progress.archipelagoShards - cost,
      bladeTier: next,
    );
    return DungeonBenchResult(
      progress: updated,
      success: true,
      message: 'Forged ${next.displayName} (${next.baseDamage} Base DMG)!',
      xpAwarded: 40,
    );
  }

  static DungeonCharmSpec? _findCharmSpec(String charmId) {
    for (final spec in kDungeonCharmCatalog) {
      if (spec.id == charmId) return spec;
    }
    return null;
  }

  /// Crafts & unlocks a Charm from [kDungeonCharmCatalog] using Archipelago Shards.
  static DungeonBenchResult craftCharm(
    DungeonProgressSave progress,
    String charmId,
  ) {
    final spec = _findCharmSpec(charmId);
    if (spec == null) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Unknown charm.',
      );
    }
    if (progress.unlockedCharmIds.contains(charmId)) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: '${spec.name} is already unlocked!',
      );
    }
    if (progress.archipelagoShards < spec.craftShardCost) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Need ${spec.craftShardCost} Shards to craft ${spec.name}.',
      );
    }
    final updated = progress.copyWith(
      archipelagoShards: progress.archipelagoShards - spec.craftShardCost,
      unlockedCharmIds: <String>{...progress.unlockedCharmIds, charmId},
    );
    return DungeonBenchResult(
      progress: updated,
      success: true,
      message: 'Crafted ${spec.name} (${spec.notchCost} Notches)!',
      xpAwarded: 25,
    );
  }

  /// Equips or unequips an unlocked Charm respecting the student's Notch budget.
  static DungeonBenchResult toggleEquipCharm(
    DungeonProgressSave progress,
    String charmId,
  ) {
    final spec = _findCharmSpec(charmId);
    if (spec == null) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Unknown charm.',
      );
    }
    if (!progress.unlockedCharmIds.contains(charmId)) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Craft or discover ${spec.name} first!',
      );
    }
    if (progress.equippedCharmIds.contains(charmId)) {
      final nextList = progress.equippedCharmIds
          .where((id) => id != charmId)
          .toList(growable: false);
      return DungeonBenchResult(
        progress: progress.copyWith(equippedCharmIds: nextList),
        success: true,
        message: 'Unequipped ${spec.name}.',
      );
    }
    if (progress.usedCharmNotches + spec.notchCost > progress.maxCharmNotches) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message:
            'Needs ${spec.notchCost} Notches (${progress.maxCharmNotches - progress.usedCharmNotches} free).',
      );
    }
    final nextList = <String>[...progress.equippedCharmIds, charmId];
    return DungeonBenchResult(
      progress: progress.copyWith(equippedCharmIds: nextList),
      success: true,
      message: 'Equipped ${spec.name}!',
    );
  }

  /// Brews +1 Resolve Elixir at the Campfire Bench (up to [kMaxElixirs]).
  static DungeonBenchResult craftResolveElixir(DungeonProgressSave progress) {
    if (progress.elixirCount >= kMaxElixirs) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Elixir satchel full ($kMaxElixirs/$kMaxElixirs).',
      );
    }
    if (progress.archipelagoShards < kResolveElixirShardCost) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Need $kResolveElixirShardCost Shards to brew an Elixir.',
      );
    }
    return DungeonBenchResult(
      progress: progress.copyWith(
        archipelagoShards: progress.archipelagoShards - kResolveElixirShardCost,
        elixirCount: progress.elixirCount + 1,
      ),
      success: true,
      message: 'Brewed +1 Resolve Elixir!',
    );
  }

  /// Forges +1 permanent Charm Notch slot (`maxCharmNotches` up to 8).
  static DungeonBenchResult expandCharmNotch(DungeonProgressSave progress) {
    if (progress.maxCharmNotches >= 8) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Maximum Charm Notches (8/8) already forged!',
      );
    }
    final cost = nextNotchShardCost(progress);
    if (progress.archipelagoShards < cost) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Need $cost Shards to forge an extra Charm Notch.',
      );
    }
    return DungeonBenchResult(
      progress: progress.copyWith(
        archipelagoShards: progress.archipelagoShards - cost,
        maxCharmNotches: progress.maxCharmNotches + 1,
      ),
      success: true,
      message: 'Forged Charm Notch ${progress.maxCharmNotches + 1}/8!',
      xpAwarded: 35,
    );
  }

  /// Selects an unlocked Constitutional Silk Skill for quick-cast in combat.
  static DungeonBenchResult selectActiveSkill(
    DungeonProgressSave progress,
    DungeonSilkSkillId skillId,
  ) {
    if (!progress.unlockedSkills.contains(skillId)) {
      final spec = silkSkillSpecFor(skillId);
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Clear Act ${spec.unlockAct} to unlock ${spec.name}!',
      );
    }
    final spec = silkSkillSpecFor(skillId);
    return DungeonBenchResult(
      progress: progress.copyWith(activeSkill: skillId),
      success: true,
      message: 'Active Silk Skill: ${spec.name}',
    );
  }

  /// Applies rewards for completing a *Saligang Tala* Bench Mastery Trial!
  static DungeonBenchResult applyMasteryTrialAnswer({
    required DungeonProgressSave progress,
    required DungeonMasteryTrialQuestion question,
    required int selectedIndex,
  }) {
    if (selectedIndex != question.correctIndex) {
      return DungeonBenchResult(
        progress: progress,
        success: false,
        message: 'Review: ${question.explanation}',
      );
    }

    // Grant Shards + XP + alternate permanent Max Resolve Mask & Max Silk Spool upgrades!
    var nextResolve = progress.bonusMaxResolveMasks;
    var nextSilk = progress.bonusMaxSilk;
    var upgradeNote = '';
    if (nextResolve < 4 && nextResolve * 15 <= nextSilk) {
      nextResolve += 1;
      upgradeNote = ' • +1 Max Resolve Mask!';
    } else if (nextSilk < 60) {
      nextSilk = math.min(60, nextSilk + 15);
      upgradeNote = ' • +15 Max Civic Silk!';
    }

    return DungeonBenchResult(
      progress: progress.copyWith(
        archipelagoShards: progress.archipelagoShards + 35,
        bonusMaxResolveMasks: nextResolve,
        bonusMaxSilk: nextSilk,
      ),
      success: true,
      message: 'Mastery Verified! +35 Shards & +50 XP$upgradeNote',
      xpAwarded: 50,
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  DIEGETIC SILKSONG × TERRARIA IN-GAME HUD & COUNTER-BREAK BANNER
// ═══════════════════════════════════════════════════════════════════════════

/// Crisp diegetic top HUD showing Resolve Masks, Civic Silk Spool, Shards, Elixirs,
/// Active Boss Nameplate + Posture Bar, and quick Map/Pause actions.
class DungeonDiegeticHud extends StatelessWidget {
  final DungeonPlayerPhysicsState player;
  final DungeonProgressSave progress;
  final DungeonChamberSpec chamber;
  final DungeonEnemyInstance? activeBoss;
  final VoidCallback onOpenMap;
  final VoidCallback onTogglePause;
  final VoidCallback? onUseElixir;

  const DungeonDiegeticHud({
    super.key,
    required this.player,
    required this.progress,
    required this.chamber,
    required this.onOpenMap,
    required this.onTogglePause,
    this.activeBoss,
    this.onUseElixir,
  });

  @override
  Widget build(BuildContext context) {
    final activeSkillSpec = silkSkillSpecFor(progress.activeSkill);
    final silkFrac = player.maxCivicSilk <= 0
        ? 0.0
        : (player.civicSilk / player.maxCivicSilk).clamp(0.0, 1.0);

    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Top-Left: Resolve Masks + Civic Silk Spool + Shards & Elixir
                Flexible(
                  child: _HudPanelBox(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Resolve Masks Row
                        Wrap(
                          spacing: 3,
                          runSpacing: 3,
                          children: List<Widget>.generate(player.maxResolveHp, (i) {
                            final filled = i < player.resolveHp;
                            return Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: filled
                                    ? SpriteCastPalette.endesga32[8]
                                    : SpriteCastPalette.endesga32[24],
                                border: Border.all(
                                  color: filled
                                      ? SpriteCastPalette.endesga32[11]
                                      : SpriteCastPalette.endesga32[22],
                                  width: 1.4,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 5),
                        // Civic Silk Spool Bar
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 96,
                              height: 8,
                              decoration: BoxDecoration(
                                color: SpriteCastPalette.ink,
                                border: Border.all(
                                  color: SpriteCastPalette.endesga32[18],
                                  width: 1.0,
                                ),
                                borderRadius: BorderRadius.circular(2),
                              ),
                              child: FractionallySizedBox(
                                alignment: Alignment.centerLeft,
                                widthFactor: silkFrac,
                                child: Container(
                                  color: silkFrac >= 0.35
                                      ? SpriteCastPalette.endesga32[18]
                                      : SpriteCastPalette.endesga32[17],
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${player.civicSilk.round()}',
                              style: const TextStyle(
                                color: Color(0xFF2CE8F5),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        // Shards + Active Skill + Elixir Pill (Wraps cleanly on compact screens!)
                        Wrap(
                          spacing: 6,
                          runSpacing: 3,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'SHARDS ${progress.archipelagoShards}',
                              style: const TextStyle(
                                color: Color(0xFFFEE761),
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 5,
                                vertical: 1,
                              ),
                              decoration: BoxDecoration(
                                color: activeSkillSpec.fxColor.withValues(alpha: 0.22),
                                border: Border.all(
                                  color: activeSkillSpec.fxColor,
                                  width: 1,
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                              child: Text(
                                activeSkillSpec.name.toUpperCase(),
                                style: TextStyle(
                                  color: activeSkillSpec.fxColor,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            if (progress.elixirCount > 0 && onUseElixir != null)
                              GestureDetector(
                                onTap: onUseElixir,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 5,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: SpriteCastPalette.endesga32[13]
                                        .withValues(alpha: 0.3),
                                    border: Border.all(
                                      color: SpriteCastPalette.endesga32[12],
                                    ),
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                  child: Text(
                                    'ELIXIR x${progress.elixirCount}',
                                    style: const TextStyle(
                                      color: Color(0xFF63C74D),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(width: 8),

                // Top-Right: Chamber Badge + Cartographer Map + Pause
                Flexible(
                  child: _HudPanelBox(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                chamber.title,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFFEAD4AA),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                chamber.subtitle,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Color(0xFF8B9BB4),
                                  fontSize: 9,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _HudIconButton(
                          icon: Icons.map_rounded,
                          tooltip: 'Cartographer Map (M)',
                          color: SpriteCastPalette.endesga32[10],
                          onTap: onOpenMap,
                        ),
                        const SizedBox(width: 4),
                        _HudIconButton(
                          icon: Icons.pause_rounded,
                          tooltip: 'Pause',
                          color: SpriteCastPalette.endesga32[20],
                          onTap: onTogglePause,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // Active Boss Multi-Phase HP & Posture Bar
            if (activeBoss != null) ...[
              const SizedBox(height: 6),
              _BossHealthAndPostureBar(boss: activeBoss!),
            ],
          ],
        ),
      ),
    );
  }
}

class _BossHealthAndPostureBar extends StatelessWidget {
  final DungeonEnemyInstance boss;
  const _BossHealthAndPostureBar({required this.boss});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 360),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: SpriteCastPalette.ink.withValues(alpha: 0.88),
        border: Border.all(
          color: boss.isStaggered
              ? SpriteCastPalette.endesga32[11]
              : SpriteCastPalette.endesga32[8],
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${boss.archetype.displayName.toUpperCase()} — PHASE ${boss.phase}',
                  style: const TextStyle(
                    color: Color(0xFFFEE761),
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.6,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${boss.hp}/${boss.maxHp}',
                style: const TextStyle(
                  color: Color(0xFFEAD4AA),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          // HP Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: boss.hpRatio,
              minHeight: 7,
              backgroundColor: SpriteCastPalette.endesga32[6],
              valueColor: AlwaysStoppedAnimation<Color>(
                boss.phase >= 3
                    ? SpriteCastPalette.endesga32[26]
                    : SpriteCastPalette.endesga32[8],
              ),
            ),
          ),
          const SizedBox(height: 3),
          // Golden Posture / Stagger Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: boss.isStaggered ? 1.0 : boss.staggerRatio,
              minHeight: 4,
              backgroundColor: SpriteCastPalette.endesga32[24],
              valueColor: AlwaysStoppedAnimation<Color>(
                boss.isStaggered
                    ? SpriteCastPalette.endesga32[11]
                    : SpriteCastPalette.endesga32[10],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Dramatic 1-Tap Constitutional Counter-Break Overlay displayed during a Boss Stagger!
class DungeonCounterBreakOverlay extends StatelessWidget {
  final DungeonCounterBreakPrompt prompt;
  final ValueChanged<int> onChooseOption;

  const DungeonCounterBreakOverlay({
    super.key,
    required this.prompt,
    required this.onChooseOption,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 440),
      margin: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpriteCastPalette.ink.withValues(alpha: 0.94),
        border: Border.all(
          color: SpriteCastPalette.endesga32[11],
          width: 2.2,
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x88FEAE34),
            blurRadius: 14,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            prompt.promptTitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFEE761),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            prompt.question,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Color(0xFFFFFFFF),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: List<Widget>.generate(prompt.options.length, (i) {
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(left: i == 0 ? 0 : 6),
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: SpriteCastPalette.endesga32[16],
                      foregroundColor: SpriteCastPalette.endesga32[19],
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                        side: const BorderSide(
                          color: Color(0xFF2CE8F5),
                          width: 1.4,
                        ),
                      ),
                    ),
                    onPressed: () => onChooseOption(i),
                    child: Text(
                      prompt.options[i],
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  BAHAY-PULUNGAN SANCTUARY BENCH MODAL (CHARMS, FORGE, TRIALS & WORLD MAP)
// ═══════════════════════════════════════════════════════════════════════════

/// Full-featured 4-tab Bahay-Pulungan Campfire Bench Sanctuary overlay.
class DungeonBenchSanctuaryModal extends StatefulWidget {
  final DungeonProgressSave initialProgress;
  final String currentChamberId;
  final int currentActNumber;
  final ValueChanged<DungeonProgressSave> onProgressChanged;
  final ValueChanged<int>? onAwardPortalXp;
  final ValueChanged<String>? onFastTravelToBench;
  final VoidCallback onClose;
  final int initialTabIndex;

  const DungeonBenchSanctuaryModal({
    super.key,
    required this.initialProgress,
    required this.currentChamberId,
    required this.currentActNumber,
    required this.onProgressChanged,
    required this.onClose,
    this.onAwardPortalXp,
    this.onFastTravelToBench,
    this.initialTabIndex = 0,
  });

  @override
  State<DungeonBenchSanctuaryModal> createState() =>
      _DungeonBenchSanctuaryModalState();
}

class _DungeonBenchSanctuaryModalState extends State<DungeonBenchSanctuaryModal> {
  late DungeonProgressSave _progress;
  late int _tabIndex;
  String _statusBanner = 'Resting at Bahay-Pulungan Sanctuary • Full Resolve Restored!';
  int _trialIndex = 0;

  @override
  void initState() {
    super.initState();
    _progress = widget.initialProgress;
    _tabIndex = widget.initialTabIndex.clamp(0, 3);
    // Start trials on the current Act's first question
    final matchIdx = kDungeonMasteryTrials.indexWhere(
      (q) => q.actNumber == widget.currentActNumber,
    );
    if (matchIdx >= 0) _trialIndex = matchIdx;
  }

  void _applyResult(DungeonBenchResult res) {
    setState(() {
      _progress = res.progress;
      _statusBanner = res.message;
    });
    widget.onProgressChanged(res.progress);
    if (res.xpAwarded > 0) {
      widget.onAwardPortalXp?.call(res.xpAwarded);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: SpriteCastPalette.ink.withValues(alpha: 0.90),
      child: SafeArea(
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 720, maxHeight: 540),
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2238),
              border: Border.all(
                color: SpriteCastPalette.endesga32[10],
                width: 2.2,
              ),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                // Header Bar
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: SpriteCastPalette.ink,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_fire_department_rounded,
                        color: Color(0xFFFEAE34),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'BAHAY-PULUNGAN SANCTUARY BENCH',
                          style: TextStyle(
                            color: Color(0xFFFEE761),
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF262B44),
                          border: Border.all(color: const Color(0xFFFEAE34)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'SHARDS: ${_progress.archipelagoShards}',
                          style: const TextStyle(
                            color: Color(0xFFFEE761),
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        onPressed: widget.onClose,
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Color(0xFFEAD4AA),
                        ),
                        tooltip: 'Resume Adventure',
                      ),
                    ],
                  ),
                ),

                // 4-Tab Bar
                Row(
                  children: [
                    _BenchTabButton(
                      label: 'CHARMS & SKILLS',
                      icon: Icons.auto_awesome_rounded,
                      selected: _tabIndex == 0,
                      onTap: () => setState(() => _tabIndex = 0),
                    ),
                    _BenchTabButton(
                      label: 'FORGE',
                      icon: Icons.hardware_rounded,
                      selected: _tabIndex == 1,
                      onTap: () => setState(() => _tabIndex = 1),
                    ),
                    _BenchTabButton(
                      label: 'SALIGANG TALA',
                      icon: Icons.menu_book_rounded,
                      selected: _tabIndex == 2,
                      onTap: () => setState(() => _tabIndex = 2),
                    ),
                    _BenchTabButton(
                      label: 'WORLD MAP',
                      icon: Icons.map_rounded,
                      selected: _tabIndex == 3,
                      onTap: () => setState(() => _tabIndex = 3),
                    ),
                  ],
                ),

                // Live Feedback Banner
                Container(
                  width: double.infinity,
                  color: const Color(0xFF262B44),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Text(
                    _statusBanner,
                    style: const TextStyle(
                      color: Color(0xFF2CE8F5),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                // Active Tab Body
                Expanded(
                  child: IndexedStack(
                    index: _tabIndex,
                    children: [
                      _buildCharmsAndSkillsTab(),
                      _buildForgeTab(),
                      _buildMasteryTrialsTab(),
                      DungeonCartographerMapView(
                        progress: _progress,
                        currentChamberId: widget.currentChamberId,
                        onFastTravelToBench: widget.onFastTravelToBench,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCharmsAndSkillsTab() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        // Charm Notch Meter
        Row(
          children: [
            Text(
              'CHARM NOTCHES (${_progress.usedCharmNotches}/${_progress.maxCharmNotches})',
              style: const TextStyle(
                color: Color(0xFFEAD4AA),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(width: 10),
            Wrap(
              spacing: 4,
              children: List<Widget>.generate(_progress.maxCharmNotches, (i) {
                final used = i < _progress.usedCharmNotches;
                return Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: used
                        ? SpriteCastPalette.endesga32[10]
                        : SpriteCastPalette.ink,
                    border: Border.all(
                      color: SpriteCastPalette.endesga32[11],
                      width: 1.4,
                    ),
                  ),
                );
              }),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // 10 Charms Grid
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kDungeonCharmCatalog.map((charm) {
            final unlocked = _progress.unlockedCharmIds.contains(charm.id);
            final equipped = _progress.equippedCharmIds.contains(charm.id);
            return SizedBox(
              width: 215,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: equipped
                      ? charm.badgeColor.withValues(alpha: 0.20)
                      : SpriteCastPalette.ink.withValues(alpha: 0.72),
                  border: Border.all(
                    color: equipped
                        ? charm.badgeColor
                        : (unlocked
                            ? SpriteCastPalette.endesga32[22]
                            : SpriteCastPalette.endesga32[23]),
                    width: equipped ? 1.8 : 1.0,
                  ),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: charm.badgeColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            charm.name,
                            style: const TextStyle(
                              color: Color(0xFFFFFFFF),
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '${charm.notchCost}N',
                          style: const TextStyle(
                            color: Color(0xFFFEE761),
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      charm.description,
                      style: const TextStyle(
                        color: Color(0xFFC0CBDC),
                        fontSize: 10,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: equipped
                              ? SpriteCastPalette.endesga32[7]
                              : (unlocked
                                  ? SpriteCastPalette.endesga32[13]
                                  : SpriteCastPalette.endesga32[16]),
                          foregroundColor: SpriteCastPalette.endesga32[19],
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          minimumSize: const Size(0, 28),
                        ),
                        onPressed: () {
                          if (unlocked) {
                            _applyResult(
                              DungeonBenchLogic.toggleEquipCharm(
                                _progress,
                                charm.id,
                              ),
                            );
                          } else {
                            _applyResult(
                              DungeonBenchLogic.craftCharm(_progress, charm.id),
                            );
                          }
                        },
                        child: Text(
                          equipped
                              ? 'UNEQUIP'
                              : (unlocked
                                  ? 'EQUIP'
                                  : 'CRAFT (${charm.craftShardCost} SHARDS)'),
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),

        const SizedBox(height: 14),
        const Text(
          'ACTIVE CONSTITUTIONAL SILK SKILL',
          style: TextStyle(
            color: Color(0xFFEAD4AA),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: kDungeonSilkSkills.map((skill) {
            final unlocked = _progress.unlockedSkills.contains(skill.id);
            final selected = _progress.activeSkill == skill.id;
            return ChoiceChip(
              selected: selected,
              selectedColor: skill.fxColor.withValues(alpha: 0.32),
              backgroundColor: SpriteCastPalette.ink,
              side: BorderSide(
                color: selected
                    ? skill.fxColor
                    : (unlocked
                        ? SpriteCastPalette.endesga32[22]
                        : SpriteCastPalette.endesga32[24]),
              ),
              label: Text(
                unlocked
                    ? '${skill.name} (${skill.silkCost} Silk)'
                    : '${skill.name} (Act ${skill.unlockAct})',
                style: TextStyle(
                  color: unlocked ? Colors.white : const Color(0xFF5A6988),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
              onSelected: (_) => _applyResult(
                DungeonBenchLogic.selectActiveSkill(_progress, skill.id),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildForgeTab() {
    final nextBlade = DungeonBenchLogic.nextBladeTier(_progress.bladeTier);
    final notchCost = DungeonBenchLogic.nextNotchShardCost(_progress);

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // 1. Blade Tier Forge Card
        _ForgeCard(
          title: 'TERRARIA BLADE FORGE',
          subtitle:
              'Current: ${_progress.bladeTier.displayName} (${_progress.bladeTier.baseDamage} DMG • +${_progress.bladeTier.reachBonusPx.round()}px Reach)',
          accentColor: _progress.bladeTier.slashArcColor,
          actionLabel: nextBlade == null
              ? 'MASTERWORK MAXED'
              : 'FORGE ${nextBlade.displayName.toUpperCase()} (${nextBlade.upgradeShardCost} SHARDS)',
          enabled: nextBlade != null &&
              _progress.archipelagoShards >= nextBlade.upgradeShardCost,
          onPressed: () =>
              _applyResult(DungeonBenchLogic.upgradeBladeTier(_progress)),
        ),
        const SizedBox(height: 10),

        // 2. Charm Notch Expansion Card
        _ForgeCard(
          title: 'FORGE CHARM NOTCH SLOT',
          subtitle:
              'Current Slots: ${_progress.maxCharmNotches}/8 • Equip stronger Silksong charm combos.',
          accentColor: SpriteCastPalette.endesga32[10],
          actionLabel: _progress.maxCharmNotches >= 8
              ? 'MAX NOTCHES (8/8)'
              : 'FORGE NOTCH ($notchCost SHARDS)',
          enabled: _progress.maxCharmNotches < 8 &&
              _progress.archipelagoShards >= notchCost,
          onPressed: () =>
              _applyResult(DungeonBenchLogic.expandCharmNotch(_progress)),
        ),
        const SizedBox(height: 10),

        // 3. Resolve Elixir Brewing Card
        _ForgeCard(
          title: 'BREW RESOLVE ELIXIR',
          subtitle:
              'Satchel: ${_progress.elixirCount}/${DungeonBenchLogic.kMaxElixirs} • Instant mid-boss +3 Resolve heal without channeling.',
          accentColor: SpriteCastPalette.endesga32[12],
          actionLabel: _progress.elixirCount >= DungeonBenchLogic.kMaxElixirs
              ? 'SATCHEL FULL'
              : 'BREW ELIXIR (${DungeonBenchLogic.kResolveElixirShardCost} SHARDS)',
          enabled: _progress.elixirCount < DungeonBenchLogic.kMaxElixirs &&
              _progress.archipelagoShards >=
                  DungeonBenchLogic.kResolveElixirShardCost,
          onPressed: () =>
              _applyResult(DungeonBenchLogic.craftResolveElixir(_progress)),
        ),
      ],
    );
  }

  Widget _buildMasteryTrialsTab() {
    final q = kDungeonMasteryTrials[_trialIndex % kDungeonMasteryTrials.length];

    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SpriteCastPalette.ink,
            border: Border.all(color: SpriteCastPalette.endesga32[18]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF124E89),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      q.subjectTag,
                      style: const TextStyle(
                        color: Color(0xFF2CE8F5),
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => setState(() {
                      _trialIndex =
                          (_trialIndex + 1) % kDungeonMasteryTrials.length;
                    }),
                    child: const Text(
                      'NEXT TRIAL →',
                      style: TextStyle(
                        color: Color(0xFFFEE761),
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                q.prompt,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              ...List<Widget>.generate(q.choices.length, (idx) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFF5A6988)),
                        alignment: Alignment.centerLeft,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () {
                        final res = DungeonBenchLogic.applyMasteryTrialAnswer(
                          progress: _progress,
                          question: q,
                          selectedIndex: idx,
                        );
                        _applyResult(res);
                        if (res.success) {
                          setState(() {
                            _trialIndex = (_trialIndex + 1) %
                                kDungeonMasteryTrials.length;
                          });
                        }
                      },
                      child: Text(
                        '${String.fromCharCode(65 + idx)}. ${q.choices[idx]}',
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'SALIGANG TALA ARCHIVE (DISCOVERED LORE TABLETS)',
          style: TextStyle(
            color: Color(0xFFEAD4AA),
            fontSize: 11,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        ...kDungeonLoreTablets.values.map((lore) {
          final actUnlocked = _progress.discoveredChamberIds.any(
            (cid) => lookupDungeonChamber(cid).actNumber == lore.actNumber,
          );
          return Container(
            margin: const EdgeInsets.only(bottom: 6),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: SpriteCastPalette.ink.withValues(alpha: 0.72),
              border: Border.all(
                color: actUnlocked
                    ? SpriteCastPalette.endesga32[10]
                    : SpriteCastPalette.endesga32[23],
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  actUnlocked
                      ? '${lore.title} (${lore.eraTag})'
                      : '??? • Explore Act ${lore.actNumber} to Discover',
                  style: TextStyle(
                    color: actUnlocked
                        ? const Color(0xFFFEE761)
                        : const Color(0xFF5A6988),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (actUnlocked) ...[
                  const SizedBox(height: 3),
                  Text(
                    lore.body,
                    style: const TextStyle(
                      color: Color(0xFFC0CBDC),
                      fontSize: 10,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    lore.constitutionLink,
                    style: const TextStyle(
                      color: Color(0xFF2CE8F5),
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CARTOGRAPHER FOG-OF-WAR METROIDVANIA WORLD MAP (ALL 35 CHAMBERS)
// ═══════════════════════════════════════════════════════════════════════════

/// Interactive Cartographer Map plotting all 7 Acts (35 rooms) with Fog-of-War,
/// Bench icons, Boss icons, current location beacon, and Sanctuary Fast-Travel!
class DungeonCartographerMapView extends StatelessWidget {
  final DungeonProgressSave progress;
  final String currentChamberId;
  final ValueChanged<String>? onFastTravelToBench;

  const DungeonCartographerMapView({
    super.key,
    required this.progress,
    required this.currentChamberId,
    this.onFastTravelToBench,
  });

  @override
  Widget build(BuildContext context) {
    final discoveredCount = progress.discoveredChamberIds.length;
    final discoveredBenches = kDungeonChambersById.values
        .where(
          (c) =>
              c.isBenchSanctuary &&
              progress.discoveredChamberIds.contains(c.id),
        )
        .toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: Wrap(
            spacing: 12,
            runSpacing: 4,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Text(
                'EXPLORED: $discoveredCount / ${kDungeonChambersById.length} CHAMBERS',
                style: const TextStyle(
                  color: Color(0xFFFEE761),
                  fontSize: 11,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Text(
                'CYAN = YOU  •  AMBER = BENCH  •  RED = BOSS',
                style: TextStyle(
                  color: Color(0xFF8B9BB4),
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: CustomPaint(
              size: const Size(double.infinity, 240),
              painter: DungeonCartographerMapPainter(
                progress: progress,
                currentChamberId: currentChamberId,
              ),
            ),
          ),
        ),
        if (onFastTravelToBench != null && discoveredBenches.isNotEmpty)
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              children: discoveredBenches.map((bench) {
                final isHere = bench.id == currentChamberId;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    backgroundColor: isHere
                        ? SpriteCastPalette.endesga32[10]
                        : SpriteCastPalette.ink,
                    side: BorderSide(
                      color: SpriteCastPalette.endesga32[10],
                    ),
                    label: Text(
                      isHere
                          ? 'ACT ${bench.actNumber} BENCH (HERE)'
                          : 'WARP: ACT ${bench.actNumber} BENCH',
                      style: TextStyle(
                        color: isHere ? SpriteCastPalette.ink : Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    onPressed: isHere
                        ? null
                        : () => onFastTravelToBench!(bench.id),
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

/// CustomPainter rendering the 5×7 Metroidvania World Graph with Fog-of-War.
class DungeonCartographerMapPainter extends CustomPainter {
  final DungeonProgressSave progress;
  final String currentChamberId;

  const DungeonCartographerMapPainter({
    required this.progress,
    required this.currentChamberId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(6)),
      Paint()..color = SpriteCastPalette.ink,
    );

    const cols = 5;
    const rows = 7;
    final cellW = (size.width - 28.0) / cols;
    final cellH = (size.height - 20.0) / rows;
    final boxW = math.min(cellW * 0.72, 92.0);
    final boxH = math.min(cellH * 0.64, 24.0);

    Rect rectFor(DungeonChamberSpec c) {
      final cx = 14.0 + (c.minimapCol + 0.5) * cellW;
      final cy = 10.0 + (c.minimapRow + 0.5) * cellH;
      return Rect.fromCenter(center: Offset(cx, cy), width: boxW, height: boxH);
    }

    // 1. Draw connecting corridors between discovered rooms
    final linkPaint = Paint()
      ..color = SpriteCastPalette.endesga32[22]
      ..strokeWidth = 2.0;
    for (final room in kDungeonChambersById.values) {
      if (!progress.discoveredChamberIds.contains(room.id)) continue;
      final a = rectFor(room).center;
      for (final ex in room.exits) {
        final target = kDungeonChambersById[ex.targetRoomId];
        if (target == null) continue;
        final b = rectFor(target).center;
        canvas.drawLine(a, b, linkPaint);
      }
    }

    // 2. Draw all 35 room nodes (discovered vs foggy adjacent silhouette)
    for (final room in kDungeonChambersById.values) {
      final r = rectFor(room);
      final discovered = progress.discoveredChamberIds.contains(room.id);
      final isCurrent = room.id == currentChamberId;
      final theme = dungeonThemeForAct(room.actNumber);

      if (!discovered) {
        // Fog-of-War shrouded outline
        canvas.drawRect(
          r,
          Paint()..color = const Color(0xFF1F2238).withValues(alpha: 0.45),
        );
        canvas.drawRect(
          r,
          Paint()
            ..color = SpriteCastPalette.endesga32[23].withValues(alpha: 0.4)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.0,
        );
        continue;
      }

      // Discovered room fill colored by Era theme
      canvas.drawRect(
        r,
        Paint()..color = theme.stoneMid.withValues(alpha: 0.85),
      );
      canvas.drawRect(
        r,
        Paint()
          ..color = isCurrent
              ? SpriteCastPalette.endesga32[18]
              : theme.accentHighlight
          ..style = PaintingStyle.stroke
          ..strokeWidth = isCurrent ? 2.2 : 1.1,
      );

      // Room Type Pip (Bench amber, Boss crimson/gold, Current cyan beacon)
      if (room.isBenchSanctuary) {
        canvas.drawCircle(
          Offset(r.left + 8, r.center.dy),
          3.2,
          Paint()..color = SpriteCastPalette.endesga32[10],
        );
      }
      if (room.isBossArena) {
        final defeated = room.bossId != null &&
            progress.defeatedBossIds.contains(room.bossId);
        canvas.drawCircle(
          Offset(r.right - 8, r.center.dy),
          3.6,
          Paint()
            ..color = defeated
                ? SpriteCastPalette.endesga32[11]
                : SpriteCastPalette.endesga32[8],
        );
      }
      if (isCurrent) {
        canvas.drawCircle(
          r.center,
          4.0,
          Paint()..color = SpriteCastPalette.endesga32[18],
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant DungeonCartographerMapPainter oldDelegate) {
    return oldDelegate.currentChamberId != currentChamberId ||
        oldDelegate.progress != progress;
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  PRIVATE STYLED WIDGET PRIMITIVES
// ═══════════════════════════════════════════════════════════════════════════

class _HudPanelBox extends StatelessWidget {
  final Widget child;
  const _HudPanelBox({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: SpriteCastPalette.ink.withValues(alpha: 0.84),
        border: Border.all(
          color: SpriteCastPalette.endesga32[22],
          width: 1.3,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: child,
    );
  }
}

class _HudIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  const _HudIconButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF262B44),
            border: Border.all(color: color.withValues(alpha: 0.7)),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Icon(icon, size: 15, color: color),
        ),
      ),
    );
  }
}

class _BenchTabButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _BenchTabButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF262B44) : const Color(0xFF181425),
            border: Border(
              bottom: BorderSide(
                color: selected
                    ? SpriteCastPalette.endesga32[11]
                    : Colors.transparent,
                width: 2.4,
              ),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 13,
                color: selected
                    ? SpriteCastPalette.endesga32[11]
                    : SpriteCastPalette.endesga32[21],
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected
                        ? SpriteCastPalette.endesga32[11]
                        : SpriteCastPalette.endesga32[21],
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForgeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;
  final String actionLabel;
  final bool enabled;
  final VoidCallback onPressed;

  const _ForgeCard({
    required this.title,
    required this.subtitle,
    required this.accentColor,
    required this.actionLabel,
    required this.enabled,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SpriteCastPalette.ink,
        border: Border.all(color: accentColor.withValues(alpha: 0.75), width: 1.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFC0CBDC),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: enabled
                  ? accentColor
                  : SpriteCastPalette.endesga32[23],
              foregroundColor: enabled
                  ? SpriteCastPalette.ink
                  : SpriteCastPalette.endesga32[21],
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
            onPressed: enabled ? onPressed : null,
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}
