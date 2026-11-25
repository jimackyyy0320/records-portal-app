import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../spritecast_engine.dart';
import 'dungeon_models.dart';

/// Role of a friendly historical Filipino NPC encountered inside the dungeons.
enum DungeonNpcRole {
  questGiver, // Assigns & narrates the Act's liberation / defense mission
  captiveCitizen, // Trapped deeper in the dungeon waiting to be rescued!
}

/// Static specification for a friendly Filipino NPC rendered in-world.
class DungeonNpcAllySpec {
  final String id;
  final String name;
  final String roleTitle;
  final int actNumber;
  final String chamberId;
  final int col; // Tile column
  final int row; // Standing tile row (feet rest at `(row + 1) * 16`)
  final DungeonNpcRole role;
  final String missionId;
  final Color outfitPrimary;
  final Color outfitAccent;
  final Color hairOrHatColor;
  final bool wearsSalakotOrHat;
  final List<String> urgentDialogue;
  final List<String> liberatedDialogue;

  const DungeonNpcAllySpec({
    required this.id,
    required this.name,
    required this.roleTitle,
    required this.actNumber,
    required this.chamberId,
    required this.col,
    required this.row,
    required this.role,
    required this.missionId,
    required this.outfitPrimary,
    required this.outfitAccent,
    required this.hairOrHatColor,
    this.wearsSalakotOrHat = false,
    required this.urgentDialogue,
    required this.liberatedDialogue,
  });

  double get worldCenterX => (col + 0.5) * kDungeonTileSize;
  double get worldBottomY => (row + 1) * kDungeonTileSize;
}

/// Story mission binding together dungeon clearing, historical warrior sieges, and citizen rescues.
class DungeonStoryMissionSpec {
  final String id;
  final int actNumber;
  final String title;
  final String eraBanner;
  final String objectiveSummary;
  final String giverNpcId;
  final int requiredEnemyClears;
  final List<String> requiredRescueNpcIds;
  final int rewardShards;
  final int rewardXp;
  final int rewardElixirs;
  final String completionToast;

  const DungeonStoryMissionSpec({
    required this.id,
    required this.actNumber,
    required this.title,
    required this.eraBanner,
    required this.objectiveSummary,
    required this.giverNpcId,
    required this.requiredEnemyClears,
    this.requiredRescueNpcIds = const <String>[],
    required this.rewardShards,
    required this.rewardXp,
    this.rewardElixirs = 0,
    required this.completionToast,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  7 ERA LIBERATION & DEFENSE MISSIONS + 12 HISTORICAL FILIPINO NPCS
// ═══════════════════════════════════════════════════════════════════════════

const List<DungeonStoryMissionSpec> kDungeonStoryMissions =
    <DungeonStoryMissionSpec>[
  DungeonStoryMissionSpec(
    id: 'mission_act1_fisherfolk',
    actNumber: 1,
    title: 'Oath of the Coastal Barangay',
    eraBanner: 'ACT I MISSION • PRE-1565',
    objectiveSummary: 'Clear cavern raiders & rescue Boatbuilder Lakan in the Grotto',
    giverNpcId: 'npc_act1_hiraya',
    requiredEnemyClears: 4,
    requiredRescueNpcIds: <String>['npc_act1_lakan'],
    rewardShards: 50,
    rewardXp: 65,
    rewardElixirs: 1,
    completionToast: 'MISSION COMPLETE: Barangay Fisherfolk Protected! (+50 Shards, +1 Elixir)',
  ),
  DungeonStoryMissionSpec(
    id: 'mission_act2_fend_spaniards',
    actNumber: 2,
    title: 'Siege of the Intramuros Plaza',
    eraBanner: 'ACT II MISSION • FEND OFF SPANIARDS',
    objectiveSummary:
        'Fend off Spanish Conquistadors & Guardia Lancers, and free Printer Elias',
    giverNpcId: 'npc_act2_marcelo',
    requiredEnemyClears: 5,
    requiredRescueNpcIds: <String>['npc_act2_elias'],
    rewardShards: 75,
    rewardXp: 90,
    rewardElixirs: 1,
    completionToast:
        'MISSION COMPLETE: Spanish Garrison Repelled & La Solidaridad Press Saved! (+75 Shards)',
  ),
  DungeonStoryMissionSpec(
    id: 'mission_act3_barasoain_charter',
    actNumber: 3,
    title: 'Guardians of the Malolos Congress',
    eraBanner: 'ACT III MISSION • 1899 FIRST REPUBLIC',
    objectiveSummary:
        'Clear Catacomb infiltrators & escort Scribe Teodoro in the Charter Vaults',
    giverNpcId: 'npc_act3_oriang',
    requiredEnemyClears: 5,
    requiredRescueNpcIds: <String>['npc_act3_teodoro'],
    rewardShards: 85,
    rewardXp: 100,
    rewardElixirs: 0,
    completionToast:
        'MISSION COMPLETE: Malolos Constitutional Drafts Secured! (+85 Shards)',
  ),
  DungeonStoryMissionSpec(
    id: 'mission_act4_skybridge_relays',
    actNumber: 4,
    title: 'Sentinels of the Commonwealth Viaduct',
    eraBanner: 'ACT IV MISSION • 1935 COMMONWEALTH',
    objectiveSummary:
        'Clear rogue Clockwork Automatons & rescue Lineman Mateo-Cruz on the Spire',
    giverNpcId: 'npc_act4_tomas',
    requiredEnemyClears: 5,
    requiredRescueNpcIds: <String>['npc_act4_cruz'],
    rewardShards: 95,
    rewardXp: 110,
    rewardElixirs: 1,
    completionToast:
        'MISSION COMPLETE: Manila Sky-Bridge Safe for Citizens! (+95 Shards, +1 Elixir)',
  ),
  DungeonStoryMissionSpec(
    id: 'mission_act5_japanese_bunkers',
    actNumber: 5,
    title: 'Liberation of Malinta Tunnel',
    eraBanner: 'ACT V MISSION • FIGHT IMPERIAL WARRIORS',
    objectiveSummary:
        'Defeat Imperial Japanese Katana Warriors & Commandos, and free Medic Nieves',
    giverNpcId: 'npc_act5_ramon',
    requiredEnemyClears: 6,
    requiredRescueNpcIds: <String>['npc_act5_nieves'],
    rewardShards: 115,
    rewardXp: 135,
    rewardElixirs: 1,
    completionToast:
        'MISSION COMPLETE: Imperial Katana Garrison Defeated & Prisoners Freed! (+115 Shards)',
  ),
  DungeonStoryMissionSpec(
    id: 'mission_act6_mosquito_press',
    actNumber: 6,
    title: 'Voices Behind the Blackout',
    eraBanner: 'ACT VI MISSION • FREE CAMPUS PRESS',
    objectiveSummary:
        'Dismantle Censor Drones & Juggernauts, and free Student Editor Jun',
    giverNpcId: 'npc_act6_leni',
    requiredEnemyClears: 5,
    requiredRescueNpcIds: <String>['npc_act6_jun'],
    rewardShards: 125,
    rewardXp: 145,
    rewardElixirs: 0,
    completionToast:
        'MISSION COMPLETE: Underground Campus Press Restored! (+125 Shards)',
  ),
  DungeonStoryMissionSpec(
    id: 'mission_act7_sovereign_vigil',
    actNumber: 7,
    title: 'Stand at the Sovereign Barricade',
    eraBanner: 'ACT VII MISSION • 1987 PEOPLE POWER',
    objectiveSummary:
        'Clear the final bastion & rally Citizen Scholar Tala on the Bridge of Rights',
    giverNpcId: 'npc_act7_rosa',
    requiredEnemyClears: 5,
    requiredRescueNpcIds: <String>['npc_act7_tala'],
    rewardShards: 150,
    rewardXp: 175,
    rewardElixirs: 1,
    completionToast:
        'MISSION COMPLETE: The Sovereign People Stand United! (+150 Shards, +1 Elixir)',
  ),
];

const List<DungeonNpcAllySpec> kDungeonNpcAllies = <DungeonNpcAllySpec>[
  // ACT I
  DungeonNpcAllySpec(
    id: 'npc_act1_hiraya',
    name: 'Babaylan Hiraya',
    roleTitle: 'Keeper of Customary Law',
    actNumber: 1,
    chamberId: 'act1_c1_shore',
    col: 7,
    row: 17,
    role: DungeonNpcRole.questGiver,
    missionId: 'mission_act1_fisherfolk',
    outfitPrimary: Color(0xFF3E8948),
    outfitAccent: Color(0xFFFEE761),
    hairOrHatColor: Color(0xFF262B44),
    urgentDialogue: <String>[
      'Alon! Sea-raiders and cave wisps surged through our tidal caverns and cut off the Barangay!',
      'Our young boatbuilder Lakan is trapped deeper inside the Sunken Sanduguan Grotto.',
      'Please clear the cavern beasts and untie Lakan so our people can gather safely at the altar!',
    ],
    liberatedDialogue: <String>[
      'Salamat, Alon! Because you cleared the grotto and freed Lakan, our barangay lanterns burn bright again.',
      'May the Sanduguan thread guide your blade against Datu Makisig\'s trial ahead!',
    ],
  ),
  DungeonNpcAllySpec(
    id: 'npc_act1_lakan',
    name: 'Boatbuilder Lakan',
    roleTitle: 'Balangay Craftsman',
    actNumber: 1,
    chamberId: 'act1_c2_grotto',
    col: 54,
    row: 19,
    role: DungeonNpcRole.captiveCitizen,
    missionId: 'mission_act1_fisherfolk',
    outfitPrimary: Color(0xFF733E39),
    outfitAccent: Color(0xFF2CE8F5),
    hairOrHatColor: Color(0xFF181425),
    wearsSalakotOrHat: true,
    urgentDialogue: <String>[
      'You cut through these Raider ropes! Those Reef Raiders ambushed me while repairing our signal lanterns.',
      'Strike down any remaining beasts so the coastal trail back to Hiraya is safe!',
    ],
    liberatedDialogue: <String>[
      'The grotto path is clear! Take my gratitude, Alon—no storm can sink a united barangay.',
    ],
  ),

  // ACT II — FEND OFF SPANISH CONQUISTADORS & GUARDIA CIVIL
  DungeonNpcAllySpec(
    id: 'npc_act2_marcelo',
    name: 'Propagandista Marcelo',
    roleTitle: 'La Solidaridad Chronicler',
    actNumber: 2,
    chamberId: 'act2_c1_gates',
    col: 7,
    row: 17,
    role: DungeonNpcRole.questGiver,
    missionId: 'mission_act2_fend_spaniards',
    outfitPrimary: Color(0xFF124E89),
    outfitAccent: Color(0xFFFEE761),
    hairOrHatColor: Color(0xFF181425),
    urgentDialogue: <String>[
      'Hurry, Alon! Spanish Conquistadors in Toledo steel and Guardia Lancers are storming our Intramuros plaza!',
      'They seized our typesetter Elias and dragged him up the Belltower Spire to silence La Solidaridad.',
      'Fend off the Spanish soldiers along the ramparts and rescue Elias before the Viceroy burns our presses!',
    ],
    liberatedDialogue: <String>[
      'Mabuhay! You drove back the Spanish Conquistadors and brought Elias home unharmed!',
      'Truth printed in courage outlasts every colonial sword—press onward to Gobernador-Heneral Valdés!',
    ],
  ),
  DungeonNpcAllySpec(
    id: 'npc_act2_elias',
    name: 'Typesetter Elias',
    roleTitle: 'Underground Press Printer',
    actNumber: 2,
    chamberId: 'act2_c2_belltower',
    col: 56,
    row: 19,
    role: DungeonNpcRole.captiveCitizen,
    missionId: 'mission_act2_fend_spaniards',
    outfitPrimary: Color(0xFFEAD4AA),
    outfitAccent: Color(0xFFE43B44),
    hairOrHatColor: Color(0xFF3E2731),
    urgentDialogue: <String>[
      'Thank heavens! The Conquistadors chained me beside the belltower rafters—I hid the lead type-plates under my coat!',
      'Help Marcelo fend off the remaining Spanish patrol so we can relight the sanctuary press!',
    ],
    liberatedDialogue: <String>[
      'Every pamphlet of freedom will roll off our press tonight thanks to your blade, Alon!',
    ],
  ),

  // ACT III — MALOLOS CATACOMBS
  DungeonNpcAllySpec(
    id: 'npc_act3_oriang',
    name: 'Lakambini Oriang',
    roleTitle: 'Custodian of the Seal',
    actNumber: 3,
    chamberId: 'act3_c1_nave',
    col: 7,
    row: 17,
    role: DungeonNpcRole.questGiver,
    missionId: 'mission_act3_barasoain_charter',
    outfitPrimary: Color(0xFFA22633),
    outfitAccent: Color(0xFFFEE761),
    hairOrHatColor: Color(0xFF181425),
    urgentDialogue: <String>[
      'Inside Barasoain\'s nave, delegates are ratifying Asia\'s first democratic constitution—but saboteurs breached the crypt!',
      'Young Scribe Teodoro is pinned down in the Sunken Catacombs carrying Title IV of the Bill of Rights.',
      'Clear the catacomb halls and bring Teodoro safely back to the assembly!',
    ],
    liberatedDialogue: <String>[
      'Title IV stands intact! Because of you, the Malolos Republic\'s guarantee of citizen rights will endure.',
    ],
  ),
  DungeonNpcAllySpec(
    id: 'npc_act3_teodoro',
    name: 'Scribe Teodoro',
    roleTitle: 'Malolos Assembly Clerk',
    actNumber: 3,
    chamberId: 'act3_c2_catacombs',
    col: 58,
    row: 19,
    role: DungeonNpcRole.captiveCitizen,
    missionId: 'mission_act3_barasoain_charter',
    outfitPrimary: Color(0xFF3A4466),
    outfitAccent: Color(0xFF2CE8F5),
    hairOrHatColor: Color(0xFF262B44),
    urgentDialogue: <String>[
      'You found me! I kept the parchment scrolls dry above the spike chasm, but those duelists blocked every bridge.',
      'Finish sweeping the catacomb intruders and our Charter is saved!',
    ],
    liberatedDialogue: <String>[
      'The ink is dry and the Republic lives! Thank you, defender of Barasoain!',
    ],
  ),

  // ACT IV — COMMONWEALTH VIADUCT
  DungeonNpcAllySpec(
    id: 'npc_act4_tomas',
    name: 'Engineer Tomas',
    roleTitle: 'Civic Works Architect',
    actNumber: 4,
    chamberId: 'act4_c1_viaduct',
    col: 7,
    row: 17,
    role: DungeonNpcRole.questGiver,
    missionId: 'mission_act4_skybridge_relays',
    outfitPrimary: Color(0xFF0099DB),
    outfitAccent: Color(0xFFFEAE34),
    hairOrHatColor: Color(0xFF5A6988),
    wearsSalakotOrHat: true,
    urgentDialogue: <String>[
      'Rogue Clockwork Automatons locked down the Manila Art-Deco Sky-Bridge right before the Women\'s Suffrage plebiscite!',
      'Signal Lineman Cruz is stranded high in the Gearworks Spire. Clear the automatons and get him down safely!',
    ],
    liberatedDialogue: <String>[
      'All viaduct relays are green and the ballot ferries are moving! Magnificent work, Alon!',
    ],
  ),
  DungeonNpcAllySpec(
    id: 'npc_act4_cruz',
    name: 'Lineman Cruz',
    roleTitle: 'Commonwealth Signal Crew',
    actNumber: 4,
    chamberId: 'act4_c2_clocktower',
    col: 58,
    row: 19,
    role: DungeonNpcRole.captiveCitizen,
    missionId: 'mission_act4_skybridge_relays',
    outfitPrimary: Color(0xFF265C42),
    outfitAccent: Color(0xFFFEE761),
    hairOrHatColor: Color(0xFF3E2731),
    wearsSalakotOrHat: true,
    urgentDialogue: <String>[
      'Whew—those Sky-Bridge Snipers had my perch zeroed in! Thanks for cutting me loose!',
      'Clear out the rest of these rogue sentinels so we can reopen the Legislative Concourse!',
    ],
    liberatedDialogue: <String>[
      'Telegraph lines are humming across Luzon, Visayas, and Mindanao once more!',
    ],
  ),

  // ACT V — FIGHT WWII IMPERIAL JAPANESE KATANA WARRIORS & LIBERATE CORREGIDOR
  DungeonNpcAllySpec(
    id: 'npc_act5_ramon',
    name: 'Captain Ramon',
    roleTitle: 'Hunters-ROTC Guerrilla Scout',
    actNumber: 5,
    chamberId: 'act5_c1_tunnel',
    col: 7,
    row: 17,
    role: DungeonNpcRole.questGiver,
    missionId: 'mission_act5_japanese_bunkers',
    outfitPrimary: Color(0xFF265C42),
    outfitAccent: Color(0xFFFEAE34),
    hairOrHatColor: Color(0xFF733E39),
    wearsSalakotOrHat: true,
    urgentDialogue: <String>[
      'Alon, keep low! Elite Imperial Japanese Katana Warriors and Assault Commandos have fortified Malinta\'s lateral tunnels!',
      'Watch their Iaido stance—when a Gunto Katana Officer grips his scabbard and glints red, dash or parry before his lightning draw!',
      'Fight through the Japanese garrison and liberate Field Medic Nieves in the Artillery Ravine!',
    ],
    liberatedDialogue: <String>[
      'Incredible swordsmanship, Alon! You bested the Imperial Katana Officers and brought Medic Nieves back to our radio post!',
      'No occupation force can extinguish a nation whose people refuse to surrender their sovereignty!',
    ],
  ),
  DungeonNpcAllySpec(
    id: 'npc_act5_nieves',
    name: 'Medic Nieves',
    roleTitle: 'Resistance Field Nurse',
    actNumber: 5,
    chamberId: 'act5_c2_trenches',
    col: 58,
    row: 19,
    role: DungeonNpcRole.captiveCitizen,
    missionId: 'mission_act5_japanese_bunkers',
    outfitPrimary: Color(0xFFEAD4AA),
    outfitAccent: Color(0xFFE43B44),
    hairOrHatColor: Color(0xFF181425),
    urgentDialogue: <String>[
      'You broke through the katana guard! I was tending wounded civilians when the Imperial patrol sealed this trench.',
      'Defeat the remaining Japanese garrison troops so we can evacuate everyone to the Guerrilla Radio Sanctuary!',
    ],
    liberatedDialogue: <String>[
      'All wounded villagers are safe inside the sanctuary! Take this extra Resolve Elixir for the bunker ahead!',
    ],
  ),

  // ACT VI — MARTIAL LAW CAMPUS PRESS
  DungeonNpcAllySpec(
    id: 'npc_act6_leni',
    name: 'Editor Leni',
    roleTitle: 'Campus Collegian Writer',
    actNumber: 6,
    chamberId: 'act6_c1_precinct',
    col: 7,
    row: 17,
    role: DungeonNpcRole.questGiver,
    missionId: 'mission_act6_mosquito_press',
    outfitPrimary: Color(0xFF68386C),
    outfitAccent: Color(0xFFFEE761),
    hairOrHatColor: Color(0xFF181425),
    urgentDialogue: <String>[
      'Curfew sirens are wailing across the precinct, and Censor Juggernauts raided our student newsroom!',
      'Our layout editor Jun is being held without warrant in the Surveillance Shaft—invoke Habeas Corpus with your blade and free him!',
    ],
    liberatedDialogue: <String>[
      'Jun is free and the morning edition is already in every student\'s hands! Darkness always retreats before truth.',
    ],
  ),
  DungeonNpcAllySpec(
    id: 'npc_act6_jun',
    name: 'Photojournalist Jun',
    roleTitle: 'Mosquito Press Chronicler',
    actNumber: 6,
    chamberId: 'act6_c2_panopticon',
    col: 58,
    row: 19,
    role: DungeonNpcRole.captiveCitizen,
    missionId: 'mission_act6_mosquito_press',
    outfitPrimary: Color(0xFF3A4466),
    outfitAccent: Color(0xFFFEAE34),
    hairOrHatColor: Color(0xFF181425),
    urgentDialogue: <String>[
      'They confiscated my camera, not my courage—and I still hid the film roll in my boot!',
      'Smash the remaining Censor patrols so we can reach the EDSA Vigil Sanctuary!',
    ],
    liberatedDialogue: <String>[
      'Every frame of the people\'s peaceful march is preserved forever!',
    ],
  ),

  // ACT VII — 1987 SOVEREIGN BARRICADE
  DungeonNpcAllySpec(
    id: 'npc_act7_rosa',
    name: 'Teacher Rosa',
    roleTitle: 'Civic Educator & Poll Watcher',
    actNumber: 7,
    chamberId: 'act7_c1_ascension',
    col: 7,
    row: 17,
    role: DungeonNpcRole.questGiver,
    missionId: 'mission_act7_sovereign_vigil',
    outfitPrimary: Color(0xFFFEAE34),
    outfitAccent: Color(0xFFFFFFFF),
    hairOrHatColor: Color(0xFF262B44),
    urgentDialogue: <String>[
      'Welcome to the Steps of People Power, Alon! Citizens from every island have gathered to ratify the 1987 Constitution.',
      'Shadow remnants still block the Bridge of the Bill of Rights where Student Delegate Tala is holding the charter banner—stand with her!',
    ],
    liberatedDialogue: <String>[
      'From the ancient barangay to 1987, the Filipino people\'s sovereignty shines unbroken. Ascend to the Golden Altar, Champion!',
    ],
  ),
  DungeonNpcAllySpec(
    id: 'npc_act7_tala',
    name: 'Delegate Tala',
    roleTitle: 'Youth Charter Bearer',
    actNumber: 7,
    chamberId: 'act7_c2_scales',
    col: 60,
    row: 19,
    role: DungeonNpcRole.captiveCitizen,
    missionId: 'mission_act7_sovereign_vigil',
    outfitPrimary: Color(0xFF0099DB),
    outfitAccent: Color(0xFFFEE761),
    hairOrHatColor: Color(0xFF181425),
    urgentDialogue: <String>[
      'Alon! Together we carried the Preamble across the chasm! Clear the last remnants on this bridge so all citizens may cross!',
    ],
    liberatedDialogue: <String>[
      '"We, the sovereign Filipino people..." The Golden Altar awaits you!',
    ],
  ),
];

DungeonStoryMissionSpec missionForAct(int actNumber) {
  return kDungeonStoryMissions.firstWhere(
    (m) => m.actNumber == actNumber,
    orElse: () => kDungeonStoryMissions.first,
  );
}

List<DungeonNpcAllySpec> npcsForChamber(String chamberId) {
  return kDungeonNpcAllies
      .where((n) => n.chamberId == chamberId)
      .toList(growable: false);
}

/// Tracks per-Act enemy clears and citizen rescues, awarding mission completion
/// bonuses cleanly into [DungeonProgressSave].
class DungeonMissionTracker {
  final Map<int, int> _actEnemyClears = <int, int>{};

  int killsForAct(int actNumber, DungeonProgressSave progress) {
    final spec = missionForAct(actNumber);
    if (progress.completedMissionIds.contains(spec.id)) {
      return spec.requiredEnemyClears;
    }
    return (_actEnemyClears[actNumber] ?? 0).clamp(0, spec.requiredEnemyClears);
  }

  void resetForTesting() {
    _actEnemyClears.clear();
  }

  /// Records an enemy defeat in [actNumber] and evaluates whether the Act's story mission is now complete.
  ({
    DungeonProgressSave progress,
    DungeonStoryMissionSpec? completedMission,
  }) recordEnemyDefeated({
    required int actNumber,
    required DungeonProgressSave progress,
  }) {
    final spec = missionForAct(actNumber);
    if (progress.completedMissionIds.contains(spec.id)) {
      return (progress: progress, completedMission: null);
    }
    _actEnemyClears[actNumber] = (_actEnemyClears[actNumber] ?? 0) + 1;
    return _evaluateCompletion(spec: spec, progress: progress);
  }

  /// Marks an NPC interacted/rescued and evaluates whether the Act's story mission is now complete.
  ({
    DungeonProgressSave progress,
    bool newlyRescued,
    DungeonStoryMissionSpec? completedMission,
  }) interactWithNpc({
    required DungeonNpcAllySpec npc,
    required DungeonProgressSave progress,
  }) {
    var nextProgress = progress;
    var newlyRescued = false;
    if (npc.role == DungeonNpcRole.captiveCitizen &&
        !progress.rescuedNpcIds.contains(npc.id)) {
      newlyRescued = true;
      nextProgress = nextProgress.copyWith(
        rescuedNpcIds: <String>{...nextProgress.rescuedNpcIds, npc.id},
      );
    }
    final spec = missionForAct(npc.actNumber);
    final eval = _evaluateCompletion(spec: spec, progress: nextProgress);
    return (
      progress: eval.progress,
      newlyRescued: newlyRescued,
      completedMission: eval.completedMission,
    );
  }

  ({
    DungeonProgressSave progress,
    DungeonStoryMissionSpec? completedMission,
  }) _evaluateCompletion({
    required DungeonStoryMissionSpec spec,
    required DungeonProgressSave progress,
  }) {
    if (progress.completedMissionIds.contains(spec.id)) {
      return (progress: progress, completedMission: null);
    }
    final kills = _actEnemyClears[spec.actNumber] ?? 0;
    if (kills < spec.requiredEnemyClears) {
      return (progress: progress, completedMission: null);
    }
    for (final reqNpc in spec.requiredRescueNpcIds) {
      if (!progress.rescuedNpcIds.contains(reqNpc)) {
        return (progress: progress, completedMission: null);
      }
    }

    final rewarded = progress.copyWith(
      archipelagoShards: progress.archipelagoShards + spec.rewardShards,
      elixirCount: (progress.elixirCount + spec.rewardElixirs).clamp(0, 5),
      completedMissionIds: <String>{...progress.completedMissionIds, spec.id},
    );
    return (progress: rewarded, completedMission: spec);
  }

  /// Builds a concise live HUD objective line for the current Act.
  String buildHudStatusLine(int actNumber, DungeonProgressSave progress) {
    final spec = missionForAct(actNumber);
    if (progress.completedMissionIds.contains(spec.id)) {
      return '✓ ${spec.title.toUpperCase()} — LIBERATED';
    }
    final kills = killsForAct(actNumber, progress);
    final rescuedCount = spec.requiredRescueNpcIds
        .where((id) => progress.rescuedNpcIds.contains(id))
        .length;
    final totalRescues = spec.requiredRescueNpcIds.length;
    if (totalRescues > 0) {
      return '${spec.title}: Clear ($kills/${spec.requiredEnemyClears}) • Rescue ($rescuedCount/$totalRescues)';
    }
    return '${spec.title}: Clear ($kills/${spec.requiredEnemyClears})';
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  IN-WORLD PIXEL-ART FILIPINO NPC RENDERER & DIALOGUE MODAL
// ═══════════════════════════════════════════════════════════════════════════

class DungeonNpcSpritePainter {
  DungeonNpcSpritePainter._();

  static final Paint _fill = Paint()
    ..style = PaintingStyle.fill
    ..isAntiAlias = false;
  static final Paint _stroke = Paint()
    ..style = PaintingStyle.stroke
    ..isAntiAlias = false;

  /// Paints all friendly Filipino NPCs located in [chamberId] with pixel-art heritage attire,
  /// captive bindings (before rescue), celebratory wave (after rescue), and beacon icons.
  static void paintChamberNpcs({
    required Canvas canvas,
    required String chamberId,
    required DungeonProgressSave progress,
    required double playerCenterX,
    required double worldTimeSec,
  }) {
    final npcs = npcsForChamber(chamberId);
    if (npcs.isEmpty) return;
    final p = SpriteCastPalette.endesga32;

    for (final npc in npcs) {
      final cx = npc.worldCenterX;
      final bottomY = npc.worldBottomY;
      final isCaptiveBound = npc.role == DungeonNpcRole.captiveCitizen &&
          !progress.rescuedNpcIds.contains(npc.id);
      final missionDone = progress.completedMissionIds.contains(npc.missionId);
      final facing = playerCenterX >= cx ? 1.0 : -1.0;
      final breathe = math.sin(worldTimeSec * 3.4 + npc.col) * 0.5;

      // Contact shadow
      SpriteCastEngine.drawSteppedContactShadow(
        canvas,
        Rect.fromCenter(center: Offset(cx, bottomY), width: 10.0, height: 3.0),
        castDx: 1.2,
        castDy: 1.0,
        strength: 0.68,
        oval: true,
      );

      // Soft sanctuary lantern aura behind NPC so players spot allies in dark caverns
      SpriteCastEngine.drawSteppedPixelLightPool(
        canvas,
        Offset(cx, bottomY - 8.0),
        color: isCaptiveBound ? p[9] : p[18],
        radius: 26.0,
        intensity: 0.52,
      );

      final crouch = isCaptiveBound ? 2.0 : 0.0;

      // Outline silhouette
      _fill.color = SpriteCastPalette.ink;
      canvas.drawRect(
        Rect.fromLTWH(cx - 4.8, bottomY - 15.2 + crouch + breathe, 9.6, 15.2 - crouch),
        _fill,
      );

      // Boots / trousers
      _fill.color = p[24];
      canvas.drawRect(Rect.fromLTWH(cx - 3.2, bottomY - 3.5, 2.5, 3.5), _fill);
      canvas.drawRect(Rect.fromLTWH(cx + 0.7, bottomY - 3.5, 2.5, 3.5), _fill);

      // Heritage Baro't Saya / Camisa / Guerrilla Tunic
      _fill.color = npc.outfitPrimary;
      canvas.drawRect(
        Rect.fromLTWH(cx - 3.8, bottomY - 9.8 + crouch + breathe, 7.6, 6.4 - crouch * 0.5),
        _fill,
      );
      // Scarf / Panuelo / Sash accent
      _fill.color = npc.outfitAccent;
      canvas.drawRect(
        Rect.fromLTWH(cx - 3.8, bottomY - 9.8 + crouch + breathe, 7.6, 1.8),
        _fill,
      );

      // Head + Hair or Woven Salakot Hat
      _fill.color = p[3];
      canvas.drawRect(
        Rect.fromLTWH(cx - 3.2, bottomY - 14.4 + crouch + breathe, 6.4, 4.6),
        _fill,
      );
      _fill.color = npc.hairOrHatColor;
      if (npc.wearsSalakotOrHat) {
        canvas.drawRect(
          Rect.fromLTWH(cx - 5.2, bottomY - 14.8 + crouch + breathe, 10.4, 1.8),
          _fill,
        );
        canvas.drawRect(
          Rect.fromLTWH(cx - 2.8, bottomY - 16.4 + crouch + breathe, 5.6, 1.8),
          _fill,
        );
      } else {
        canvas.drawRect(
          Rect.fromLTWH(cx - 3.6, bottomY - 15.0 + crouch + breathe, 7.2, 2.2),
          _fill,
        );
      }
      // Eye facing Alon
      _fill.color = SpriteCastPalette.ink;
      canvas.drawRect(
        Rect.fromLTWH(
          cx + (facing > 0 ? 1.0 : -2.4),
          bottomY - 12.4 + crouch + breathe,
          1.4,
          1.4,
        ),
        _fill,
      );

      if (isCaptiveBound) {
        // Captive iron/rope bindings around torso + urgent SOS pulse!
        _fill.color = p[10];
        canvas.drawRect(Rect.fromLTWH(cx - 4.4, bottomY - 7.8 + crouch, 8.8, 1.3), _fill);
        canvas.drawRect(Rect.fromLTWH(cx - 4.4, bottomY - 5.6 + crouch, 8.8, 1.3), _fill);
      } else if (missionDone) {
        // Raised waving hand in gratitude!
        final waveY = math.sin(worldTimeSec * 8.0) * 1.4;
        _fill.color = p[3];
        canvas.drawRect(
          Rect.fromLTWH(cx + facing * 4.0, bottomY - 12.5 + waveY, 2.0, 3.2),
          _fill,
        );
      }

      // Floating pixel exclamation / rescue beacon above head
      final bob = math.sin(worldTimeSec * 5.2 + npc.col) * 1.6;
      final badgeCenter = Offset(cx, bottomY - 21.0 + bob);
      final badgeColor = isCaptiveBound
          ? p[8] // Urgent crimson-amber "FREE ME!"
          : (missionDone ? p[13] : p[11]); // Emerald when complete, Gold when active
      _fill.color = SpriteCastPalette.ink;
      canvas.drawRect(
        Rect.fromCenter(center: badgeCenter, width: 7.0, height: 8.0),
        _fill,
      );
      _fill.color = badgeColor;
      canvas.drawRect(
        Rect.fromCenter(center: badgeCenter, width: 5.0, height: 6.0),
        _fill,
      );
      _fill.color = SpriteCastPalette.ink;
      if (missionDone && !isCaptiveBound) {
        // Checkmark pixel glyph
        canvas.drawRect(Rect.fromLTWH(badgeCenter.dx - 1.5, badgeCenter.dy, 1.2, 1.8), _fill);
        canvas.drawRect(Rect.fromLTWH(badgeCenter.dx - 0.3, badgeCenter.dy - 1.2, 2.0, 1.2), _fill);
      } else {
        // Crisp '!' exclamation pixel glyph
        canvas.drawRect(Rect.fromLTWH(badgeCenter.dx - 0.6, badgeCenter.dy - 2.2, 1.2, 2.6), _fill);
        canvas.drawRect(Rect.fromLTWH(badgeCenter.dx - 0.6, badgeCenter.dy + 1.1, 1.2, 1.1), _fill);
      }
      _stroke
        ..color = badgeColor.withValues(alpha: 0.45)
        ..strokeWidth = 0.8;
      canvas.drawCircle(badgeCenter, 5.8, _stroke);
    }
  }
}

/// Interactive Story Dialogue & Mission Briefing Modal when speaking to or rescuing an NPC.
class DungeonNpcDialogueModal extends StatefulWidget {
  final DungeonNpcAllySpec npc;
  final DungeonStoryMissionSpec mission;
  final DungeonProgressSave progress;
  final int currentKills;
  final bool justRescued;
  final VoidCallback onClose;

  const DungeonNpcDialogueModal({
    super.key,
    required this.npc,
    required this.mission,
    required this.progress,
    required this.currentKills,
    required this.justRescued,
    required this.onClose,
  });

  @override
  State<DungeonNpcDialogueModal> createState() => _DungeonNpcDialogueModalState();
}

class _DungeonNpcDialogueModalState extends State<DungeonNpcDialogueModal> {
  int _lineIndex = 0;

  @override
  Widget build(BuildContext context) {
    final missionComplete =
        widget.progress.completedMissionIds.contains(widget.mission.id);
    final lines = (missionComplete && !widget.justRescued)
        ? widget.npc.liberatedDialogue
        : widget.npc.urgentDialogue;
    final safeIdx = _lineIndex.clamp(0, lines.length - 1);
    final isLastLine = safeIdx >= lines.length - 1;

    return Container(
      color: const Color(0xBD090A14),
      alignment: Alignment.center,
      padding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF15192B),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: missionComplete
                  ? const Color(0xFF63C74D)
                  : const Color(0xFFFEE761),
              width: 2,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x99000000),
                blurRadius: 24,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: Material(
            type: MaterialType.transparency,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color:
                                widget.npc.outfitPrimary.withValues(alpha: 0.32),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: widget.npc.outfitAccent),
                          ),
                          child: Text(
                            widget.justRescued
                                ? 'CITIZEN LIBERATED!'
                                : widget.mission.eraBanner,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: widget.npc.outfitAccent,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${safeIdx + 1} / ${lines.length}',
                        style: const TextStyle(
                          color: Color(0xFF8B9BB4),
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
              const SizedBox(height: 10),
              Text(
                widget.npc.name,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                widget.npc.roleTitle,
                style: const TextStyle(
                  color: Color(0xFF2CE8F5),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF0E111F),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFF2B3354)),
                ),
                child: Text(
                  '"${lines[safeIdx]}"',
                  style: const TextStyle(
                    color: Color(0xFFEAD4AA),
                    fontSize: 14,
                    height: 1.45,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              // Mission Tracker Card
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: const Color(0xFF1D233B),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: missionComplete
                        ? const Color(0xFF63C74D)
                        : const Color(0xFF3A4466),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      missionComplete
                          ? Icons.verified_rounded
                          : Icons.shield_outlined,
                      size: 18,
                      color: missionComplete
                          ? const Color(0xFF63C74D)
                          : const Color(0xFFFEAE34),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.mission.title,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            missionComplete
                                ? 'Mission Complete! Reward Claimed (+${widget.mission.rewardShards} Shards, +${widget.mission.rewardXp} XP)'
                                : '${widget.mission.objectiveSummary} (${widget.currentKills}/${widget.mission.requiredEnemyClears} Foes)',
                            style: const TextStyle(
                              color: Color(0xFFB8C4D8),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Align(
                alignment: Alignment.centerRight,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isLastLine
                        ? const Color(0xFF38B764)
                        : const Color(0xFF0099DB),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                  ),
                  onPressed: () {
                    if (!isLastLine) {
                      setState(() => _lineIndex++);
                    } else {
                      widget.onClose();
                    }
                  },
                  icon: Icon(
                    isLastLine
                        ? Icons.check_circle_outline_rounded
                        : Icons.arrow_forward_rounded,
                    size: 16,
                  ),
                  label: Text(
                    isLastLine ? 'CONTINUE MISSION' : 'NEXT',
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 12,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
              ),
            ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
