import 'dungeon_enemies.dart';
import 'dungeon_models.dart';

/// Metadata describing one of the 7 Historical Era Metroidvania Dungeons.
class DungeonActWorldSpec {
  final int actNumber;
  final String title;
  final String eraYear;
  final String subtitle;
  final String entryChamberId;
  final String sanctuaryChamberId;
  final String bossChamberId;
  final String bossId;
  final String charterSealName;
  final DungeonSilkSkillId? unlockedSkillOnClear;
  final List<String> chamberIds;

  const DungeonActWorldSpec({
    required this.actNumber,
    required this.title,
    required this.eraYear,
    required this.subtitle,
    required this.entryChamberId,
    required this.sanctuaryChamberId,
    required this.bossChamberId,
    required this.bossId,
    required this.charterSealName,
    this.unlockedSkillOnClear,
    required this.chamberIds,
  });
}

/// Reward granted when opening a dungeon Treasure Chest (`'K'`).
class DungeonChestRewardSpec {
  final String id;
  final String title;
  final String description;
  final int shards;
  final String? unlockCharmId;
  final bool grantsResolveMaskShard;
  final bool grantsSilkSpoolBoost;
  final int bonusElixirs;

  const DungeonChestRewardSpec({
    required this.id,
    required this.title,
    required this.description,
    this.shards = 35,
    this.unlockCharmId,
    this.grantsResolveMaskShard = false,
    this.grantsSilkSpoolBoost = false,
    this.bonusElixirs = 0,
  });
}

/// *Saligang Tala* historical lore tablet inscribed inside dungeon chambers (`'L'`).
class DungeonLoreTabletSpec {
  final String id;
  final int actNumber;
  final String title;
  final String eraTag;
  final String body;
  final String constitutionLink;

  const DungeonLoreTabletSpec({
    required this.id,
    required this.actNumber,
    required this.title,
    required this.eraTag,
    required this.body,
    required this.constitutionLink,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  ALL 7 ERA DUNGEON ACTS (35 INTERCONNECTED METROIDVANIA CHAMBERS TOTAL)
// ═══════════════════════════════════════════════════════════════════════════

const List<DungeonActWorldSpec> kDungeonActWorlds = <DungeonActWorldSpec>[
  DungeonActWorldSpec(
    actNumber: 1,
    title: 'Coastal Caverns of the Barangay',
    eraYear: 'Pre-1565',
    subtitle: 'Tidal Grottoes & Sanduguan Altar',
    entryChamberId: 'act1_c1_shore',
    sanctuaryChamberId: 'act1_c3_sanctuary',
    bossChamberId: 'act1_c5_boss_sanduguan',
    bossId: 'boss_datu_makisig',
    charterSealName: 'Seal of the Sanduguan',
    unlockedSkillOnClear: DungeonSilkSkillId.sanduguanThread,
    chamberIds: <String>[
      'act1_c1_shore',
      'act1_c2_grotto',
      'act1_c3_sanctuary',
      'act1_c4_gauntlet',
      'act1_c5_boss_sanduguan',
    ],
  ),
  DungeonActWorldSpec(
    actNumber: 2,
    title: 'Intramuros Belltower & Citadel',
    eraYear: '1565–1896',
    subtitle: 'Stone Ramparts, Spires & Press Vaults',
    entryChamberId: 'act2_c1_gates',
    sanctuaryChamberId: 'act2_c3_sanctuary',
    bossChamberId: 'act2_c5_boss_valdes',
    bossId: 'boss_valdes',
    charterSealName: 'Seal of La Solidaridad',
    unlockedSkillOnClear: DungeonSilkSkillId.scalesTempest,
    chamberIds: <String>[
      'act2_c1_gates',
      'act2_c2_belltower',
      'act2_c3_sanctuary',
      'act2_c4_mateo_courtyard',
      'act2_c5_boss_valdes',
    ],
  ),
  DungeonActWorldSpec(
    actNumber: 3,
    title: 'Malolos Catacombs & Barasoain Crypt',
    eraYear: '1898–1899',
    subtitle: 'Candlelit Nave & First Republic Vaults',
    entryChamberId: 'act3_c1_nave',
    sanctuaryChamberId: 'act3_c3_sanctuary',
    bossChamberId: 'act3_c5_boss_calderon',
    bossId: 'boss_calderon',
    charterSealName: 'Seal of the Malolos Republic',
    unlockedSkillOnClear: DungeonSilkSkillId.habeasAegis,
    chamberIds: <String>[
      'act3_c1_nave',
      'act3_c2_catacombs',
      'act3_c3_sanctuary',
      'act3_c4_switch_crypt',
      'act3_c5_boss_calderon',
    ],
  ),
  DungeonActWorldSpec(
    actNumber: 4,
    title: 'Commonwealth Sky-Bridges',
    eraYear: '1935–1941',
    subtitle: 'Art-Deco Viaducts & Clockwork Towers',
    entryChamberId: 'act4_c1_viaduct',
    sanctuaryChamberId: 'act4_c3_sanctuary',
    bossChamberId: 'act4_c5_boss_warden',
    bossId: 'boss_commonwealth_warden',
    charterSealName: 'Seal of Checks & Balances',
    chamberIds: <String>[
      'act4_c1_viaduct',
      'act4_c2_clocktower',
      'act4_c3_sanctuary',
      'act4_c4_sky_gauntlet',
      'act4_c5_boss_warden',
    ],
  ),
  DungeonActWorldSpec(
    actNumber: 5,
    title: 'Corregidor Malinta Bunkers',
    eraYear: '1942–1945',
    subtitle: 'Fortified Tunnels & Artillery Trenches',
    entryChamberId: 'act5_c1_tunnel',
    sanctuaryChamberId: 'act5_c3_sanctuary',
    bossChamberId: 'act5_c5_boss_commander',
    bossId: 'boss_imperial_commander',
    charterSealName: 'Seal of Unbroken Sovereignty',
    chamberIds: <String>[
      'act5_c1_tunnel',
      'act5_c2_trenches',
      'act5_c3_sanctuary',
      'act5_c4_mateo_bunker',
      'act5_c5_boss_commander',
    ],
  ),
  DungeonActWorldSpec(
    actNumber: 6,
    title: 'The Obsidian Vault of Martial Law',
    eraYear: '1972–1986',
    subtitle: 'Blackout Checkpoints & Panopticon Shaft',
    entryChamberId: 'act6_c1_precinct',
    sanctuaryChamberId: 'act6_c3_sanctuary',
    bossChamberId: 'act6_c5_boss_censor',
    bossId: 'boss_iron_censor',
    charterSealName: 'Seal of Habeas Corpus',
    unlockedSkillOnClear: DungeonSilkSkillId.sovereignSunburst,
    chamberIds: <String>[
      'act6_c1_precinct',
      'act6_c2_panopticon',
      'act6_c3_sanctuary',
      'act6_c4_vault_gauntlet',
      'act6_c5_boss_censor',
    ],
  ),
  DungeonActWorldSpec(
    actNumber: 7,
    title: 'Golden Altar of the 1987 Charter',
    eraYear: '1987–Present',
    subtitle: 'Steps of People Power & Sovereign Trial',
    entryChamberId: 'act7_c1_ascension',
    sanctuaryChamberId: 'act7_c3_sanctuary',
    bossChamberId: 'act7_c5_boss_sovereign',
    bossId: 'boss_sovereign_guardian',
    charterSealName: 'Crown of the 1987 Charter',
    chamberIds: <String>[
      'act7_c1_ascension',
      'act7_c2_scales',
      'act7_c3_sanctuary',
      'act7_c4_hall_of_charters',
      'act7_c5_boss_sovereign',
    ],
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
//  CHEST REWARDS & SALIGANG TALA LORE TABLETS
// ═══════════════════════════════════════════════════════════════════════════

const Map<String, DungeonChestRewardSpec> kDungeonChestRewards =
    <String, DungeonChestRewardSpec>{
  'chest_act1_secret_shore': DungeonChestRewardSpec(
    id: 'chest_act1_secret_shore',
    title: 'Tide-Carved Charm Casket',
    description: 'Unlocks the Magnet Shard Charm & grants 35 Archipelago Shards.',
    shards: 35,
    unlockCharmId: 'magnet_shard',
  ),
  'chest_act1_sanctuary_cache': DungeonChestRewardSpec(
    id: 'chest_act1_sanctuary_cache',
    title: 'Babaylan Vitality Vessel',
    description: 'Grants +1 Max Resolve Mask Shard & 1 Resolve Elixir.',
    shards: 25,
    grantsResolveMaskShard: true,
    bonusElixirs: 1,
  ),
  'chest_act2_rampart_secret': DungeonChestRewardSpec(
    id: 'chest_act2_rampart_secret',
    title: 'Intramuros Duelist Reliquary',
    description: 'Unlocks Quick-Slash Bolo Charm & grants 45 Archipelago Shards.',
    shards: 45,
    unlockCharmId: 'quick_slash_bolo',
  ),
  'chest_act2_press_vault': DungeonChestRewardSpec(
    id: 'chest_act2_press_vault',
    title: 'La Solidaridad Silk Spool',
    description: 'Unlocks Scholar\'s Silk Charm & expands Max Silk Spool.',
    shards: 40,
    unlockCharmId: 'scholars_silk',
    grantsSilkSpoolBoost: true,
  ),
  'chest_act3_nave_relic': DungeonChestRewardSpec(
    id: 'chest_act3_nave_relic',
    title: 'Barasoain Needle Case',
    description: 'Unlocks Long-Needle Reach Charm & grants 55 Archipelago Shards.',
    shards: 55,
    unlockCharmId: 'long_needle',
  ),
  'chest_act3_assembly_vault': DungeonChestRewardSpec(
    id: 'chest_act3_assembly_vault',
    title: 'Malolos Sanctuary Elixir Crate',
    description: 'Unlocks Babaylan Fast-Bind Charm & grants +1 Resolve Elixir.',
    shards: 50,
    unlockCharmId: 'babaylan_bind',
    bonusElixirs: 1,
  ),
  'chest_act4_viaduct_cache': DungeonChestRewardSpec(
    id: 'chest_act4_viaduct_cache',
    title: 'Sky-Bridge Acrobatic Greaves',
    description: 'Unlocks Double-Pogo Boots Charm & grants 65 Archipelago Shards.',
    shards: 65,
    unlockCharmId: 'double_pogo_boots',
  ),
  'chest_act4_concourse_vault': DungeonChestRewardSpec(
    id: 'chest_act4_concourse_vault',
    title: 'Commonwealth Resolve Shard',
    description: 'Grants +1 Max Resolve Mask Shard & 60 Archipelago Shards.',
    shards: 60,
    grantsResolveMaskShard: true,
  ),
  'chest_act5_armory_secret': DungeonChestRewardSpec(
    id: 'chest_act5_armory_secret',
    title: 'Malinta Iron Parry Crest',
    description: 'Unlocks Iron Parry Crest Charm & grants 75 Archipelago Shards.',
    shards: 75,
    unlockCharmId: 'iron_parry_crest',
  ),
  'chest_act5_radio_cache': DungeonChestRewardSpec(
    id: 'chest_act5_radio_cache',
    title: 'Corregidor Supply Trunk',
    description: 'Expands Max Silk Spool & grants +2 Resolve Elixirs.',
    shards: 70,
    grantsSilkSpoolBoost: true,
    bonusElixirs: 2,
  ),
  'chest_act6_samizdat_vault': DungeonChestRewardSpec(
    id: 'chest_act6_samizdat_vault',
    title: 'Underground Charter Ward',
    description: 'Unlocks Charter Ward Charm & grants 90 Archipelago Shards.',
    shards: 90,
    unlockCharmId: 'charter_ward',
  ),
  'chest_act6_edsa_vigil_chest': DungeonChestRewardSpec(
    id: 'chest_act6_edsa_vigil_chest',
    title: 'People Power Resolve Vessel',
    description: 'Grants +1 Max Resolve Mask Shard & 85 Archipelago Shards.',
    shards: 85,
    grantsResolveMaskShard: true,
  ),
  'chest_act7_steps_vault': DungeonChestRewardSpec(
    id: 'chest_act7_steps_vault',
    title: 'Sovereign Heart Reliquary',
    description: 'Unlocks the Sovereign Heart Charm (+2 Max Resolve) & 110 Shards.',
    shards: 110,
    unlockCharmId: 'sovereign_heart',
  ),
  'chest_act7_sanctuary_final': DungeonChestRewardSpec(
    id: 'chest_act7_sanctuary_final',
    title: 'Golden Charter Reserve',
    description: 'Grants 140 Archipelago Shards, Max Silk boost & +2 Elixirs.',
    shards: 140,
    grantsSilkSpoolBoost: true,
    bonusElixirs: 2,
  ),
};

const Map<String, DungeonLoreTabletSpec> kDungeonLoreTablets =
    <String, DungeonLoreTabletSpec>{
  'lore_act1_barangay_law': DungeonLoreTabletSpec(
    id: 'lore_act1_barangay_law',
    actNumber: 1,
    title: 'Customary Law of the Barangay',
    eraTag: 'Pre-1565 • PKLP',
    body:
        'Before colonial charters, each coastal barangay governed itself through oral customs, elder councils (Maginoo), and the Sanduguan pact of mutual trust.',
    constitutionLink: 'Root of Local Autonomy & Community Governance',
  ),
  'lore_act1_umalahokan': DungeonLoreTabletSpec(
    id: 'lore_act1_umalahokan',
    actNumber: 1,
    title: 'Voice of the Umalahokan',
    eraTag: 'Pre-1565 • PKLP',
    body:
        'Public notice was essential even in ancient times: the Umalahokan announced newly agreed barangay rules across settlements so no citizen was punished in secret.',
    constitutionLink: 'Principle of Publication & Due Process',
  ),
  'lore_act2_propaganda_press': DungeonLoreTabletSpec(
    id: 'lore_act2_propaganda_press',
    actNumber: 2,
    title: 'Ink of La Solidaridad',
    eraTag: '1889 • PKLP / PPG',
    body:
        'Rizal, Del Pilar, and Lopez Jaena wielded essays and newspapers to demand freedom of speech, press liberties, and equal representation under law.',
    constitutionLink: 'Art. III, Sec. 4 — Freedom of Speech & the Press',
  ),
  'lore_act2_katipunan_kartilya': DungeonLoreTabletSpec(
    id: 'lore_act2_katipunan_kartilya',
    actNumber: 2,
    title: 'Kartilya ng Katipunan',
    eraTag: '1896 • PKLP / PHILO',
    body:
        'Emilio Jacinto taught that true nobility rests on honor, compassion, and equality of all persons regardless of birth or skin color.',
    constitutionLink: 'Art. III, Sec. 1 — Equal Protection of the Laws',
  ),
  'lore_act3_barasoain_assembly': DungeonLoreTabletSpec(
    id: 'lore_act3_barasoain_assembly',
    actNumber: 3,
    title: 'The Malolos Congress',
    eraTag: '1899 • PPG',
    body:
        'Inside Barasoain Church, delegates drafted Asia\'s first democratic republican constitution, affirming popular sovereignty and an extensive Bill of Rights.',
    constitutionLink: '1899 Malolos Constitution — Title IV Rights',
  ),
  'lore_act3_separation_powers': DungeonLoreTabletSpec(
    id: 'lore_act3_separation_powers',
    actNumber: 3,
    title: 'Three Pillars Against Absolutism',
    eraTag: '1899 • PPG',
    body:
        'Felipe Calderón insisted that legislative, executive, and judicial authority must never be merged in a single pair of hands.',
    constitutionLink: 'Separation of Powers Doctrine',
  ),
  'lore_act4_commonwealth_charter': DungeonLoreTabletSpec(
    id: 'lore_act4_commonwealth_charter',
    actNumber: 4,
    title: 'The 1935 Constitutional Convention',
    eraTag: '1935 • PPG / UCSP',
    body:
        'Drafted to guide the 10-year Commonwealth transition to independence, the 1935 Charter instituted a presidential system and strengthened social justice.',
    constitutionLink: '1935 Constitution — Social Justice & Judiciary',
  ),
  'lore_act4_womens_suffrage': DungeonLoreTabletSpec(
    id: 'lore_act4_womens_suffrage',
    actNumber: 4,
    title: '1937 Plebiscite for Women\'s Suffrage',
    eraTag: '1937 • UCSP / PPG',
    body:
        'Over 447,000 Filipino women voted overwhelmingly in the 1937 plebiscite, securing full electoral suffrage across the archipelago.',
    constitutionLink: 'Art. V — Universal Equal Suffrage',
  ),
  'lore_act5_malinta_resistance': DungeonLoreTabletSpec(
    id: 'lore_act5_malinta_resistance',
    actNumber: 5,
    title: 'Consent vs. Occupation',
    eraTag: '1943 • PKLP / PPG',
    body:
        'A constitution imposed under military occupation lacks popular ratification; true constitutional authority returns only when citizens choose freely.',
    constitutionLink: 'Popular Ratification & National Sovereignty',
  ),
  'lore_act5_guerrilla_unity': DungeonLoreTabletSpec(
    id: 'lore_act5_guerrilla_unity',
    actNumber: 5,
    title: 'Civilian Courage in Malinta',
    eraTag: '1942–1945 • PKLP',
    body:
        'Community networks across Luzon, Visayas, and Mindanao preserved civic solidarity even under blackout conditions.',
    constitutionLink: 'Art. II, Sec. 3 — Civilian Supremacy',
  ),
  'lore_act6_writ_habeas': DungeonLoreTabletSpec(
    id: 'lore_act6_writ_habeas',
    actNumber: 6,
    title: 'Shield of Habeas Corpus',
    eraTag: '1972–1986 • PPG',
    body:
        'The Writ of Habeas Corpus commands authorities to bring any detained person before an independent court to test whether detention is lawful.',
    constitutionLink: 'Art. III, Sec. 15 & Art. VII, Sec. 18 Safeguards',
  ),
  'lore_act6_edsa_vigil': DungeonLoreTabletSpec(
    id: 'lore_act6_edsa_vigil',
    actNumber: 6,
    title: 'Peaceful People Power',
    eraTag: 'February 1986 • PKLP / UCSP',
    body:
        'Millions of Filipinos stood peacefully along EDSA, demonstrating that civic unity and non-violent solidarity can peacefully restore constitutional democracy.',
    constitutionLink: 'Peaceful Assembly & Democratic Restoration',
  ),
  'lore_act7_bill_of_rights': DungeonLoreTabletSpec(
    id: 'lore_act7_bill_of_rights',
    actNumber: 7,
    title: 'Article III — The Bill of Rights',
    eraTag: '1987 • PPG',
    body:
        'Every person is guaranteed due process, equal protection, privacy of communication, free speech, peaceful assembly, and protection against unreasonable searches.',
    constitutionLink: '1987 Constitution — Article III',
  ),
  'lore_act7_sovereign_people': DungeonLoreTabletSpec(
    id: 'lore_act7_sovereign_people',
    actNumber: 7,
    title: 'We, the Sovereign Filipino People',
    eraTag: '1987 • PPG / PHILO',
    body:
        'The Preamble and Article II, Section 1 declare that sovereignty resides in the people and all government authority emanates from them.',
    constitutionLink: '1987 Constitution — Preamble & Art. II, Sec. 1',
  ),
};

// ═══════════════════════════════════════════════════════════════════════════
//  DETERMINISTIC RECTANGULAR CHAMBER BUILDER (ZERO JAGGED ROWS!)
// ═══════════════════════════════════════════════════════════════════════════

class _GridBuilder {
  final int cols;
  final int rows;
  final List<List<String>> _cells;

  _GridBuilder(this.cols, this.rows, {String borderChar = '#', String floorChar = 'M'})
      : _cells = List<List<String>>.generate(
          rows,
          (r) => List<String>.generate(cols, (c) {
            if (r == 0 || c == 0 || c == cols - 1) return borderChar;
            if (r == rows - 1) return borderChar;
            if (r == rows - 2) return floorChar;
            return '.';
          }),
        );

  void put(int c, int r, String ch) {
    if (r >= 0 && r < rows && c >= 0 && c < cols) {
      _cells[r][c] = ch;
    }
  }

  void hLine(int c1, int c2, int r, String ch) {
    for (var c = c1; c <= c2; c++) {
      put(c, r, ch);
    }
  }

  void vLine(int c, int r1, int r2, String ch) {
    for (var r = r1; r <= r2; r++) {
      put(c, r, ch);
    }
  }

  void fillRect(int c1, int r1, int c2, int r2, String ch) {
    for (var r = r1; r <= r2; r++) {
      for (var c = c1; c <= c2; c++) {
        put(c, r, ch);
      }
    }
  }

  /// Carves a spike trench into the floor (`rows - 2`) between `c1..c2`.
  void spikeTrench(int c1, int c2) {
    hLine(c1, c2, rows - 2, '^');
  }

  /// Builds a secret breakable wall alcove on the far-left or upper wall with reward tiles!
  void secretAlcoveRight({
    required int wallCol,
    required int topRow,
    required int bottomRow,
    required int chamberRightCol,
    String lootChar = 'K',
    String secondChar = '*',
  }) {
    // Solid roof & floor enclosing the secret chamber
    hLine(wallCol, chamberRightCol, topRow - 1, '#');
    hLine(wallCol, chamberRightCol, bottomRow + 1, 'M');
    fillRect(wallCol + 1, topRow, chamberRightCol, bottomRow, '.');
    // Breakable secret wall separating main cavern from treasure nook
    vLine(wallCol, topRow, bottomRow, '?');
    put(wallCol + 2, bottomRow, secondChar);
    put(chamberRightCol - 1, bottomRow, lootChar);
    put(wallCol + 2, topRow, 'T');
  }

  /// Builds a locked Charter Gate wall (`'D'`) blocking passage until Switch (`'S'`) is hit!
  void lockedGateWall(int gateCol, int topRow, int bottomRow) {
    vLine(gateCol, topRow, bottomRow, 'D');
  }

  List<String> build() => _cells.map((row) => row.join()).toList(growable: false);
}

// ═══════════════════════════════════════════════════════════════════════════
//  35 HAND-CRAFTED INTERCONNECTED DUNGEON CHAMBERS (5 PER ACT × 7 ACTS)
// ═══════════════════════════════════════════════════════════════════════════

final Map<String, DungeonChamberSpec> kDungeonChambersById = _buildAll35Chambers();

Map<String, DungeonChamberSpec> _buildAll35Chambers() {
  final rooms = <DungeonChamberSpec>[
    ..._buildAct1Chambers(),
    ..._buildAct2Chambers(),
    ..._buildAct3Chambers(),
    ..._buildAct4Chambers(),
    ..._buildAct5Chambers(),
    ..._buildAct6Chambers(),
    ..._buildAct7Chambers(),
  ];
  return <String, DungeonChamberSpec>{
    for (final room in rooms) room.id: room,
  };
}

// ─────────────────────────── ACT I (5 CHAMBERS) ───────────────────────────

List<DungeonChamberSpec> _buildAct1Chambers() {
  // 1. act1_c1_shore (44x16) — Tutorial landing, stepped platforms, crates, secret alcove
  final g1 = _GridBuilder(44, 16)
    ..hLine(8, 13, 11, '=')
    ..hLine(16, 22, 9, '=')
    ..hLine(25, 31, 11, '=')
    ..vLine(10, 11, 13, 'H')
    ..put(5, 11, 'T')
    ..put(18, 7, 'T')
    ..put(30, 9, 'T')
    ..put(12, 13, 'X')
    ..put(13, 13, 'X')
    ..put(20, 8, '*')
    ..put(28, 10, 'L')
    ..put(35, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 38,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 42,
      lootChar: 'K',
      secondChar: '*',
    );

  // 2. act1_c2_grotto (46x18) — Vertical shaft + Pogo-Lantern spike trench!
  final g2 = _GridBuilder(46, 18)
    ..put(2, 15, 'P')
    ..hLine(6, 11, 12, '=')
    ..vLine(7, 12, 15, 'H')
    ..hLine(14, 19, 9, '=')
    ..spikeTrench(16, 29)
    ..put(19, 13, 'O')
    ..put(23, 13, 'O')
    ..put(27, 13, 'O')
    ..put(23, 8, 'G')
    ..hLine(31, 37, 12, '=')
    ..put(34, 11, 'L')
    ..put(10, 11, 'X')
    ..put(35, 15, '*')
    ..put(8, 10, 'T')
    ..put(24, 6, 'T')
    ..put(39, 11, 'T')
    ..put(43, 15, 'P');

  // 3. act1_c3_sanctuary (34x16) — Bahay-Pulungan Campfire Bench Sanctuary + Upper Secret Chest
  final g3 = _GridBuilder(34, 16)
    ..put(2, 13, 'P')
    ..put(16, 13, 'B')
    ..put(13, 13, 'L')
    ..put(10, 11, 'T')
    ..put(22, 11, 'T')
    ..hLine(6, 12, 9, '=')
    ..hLine(20, 26, 9, '=')
    ..hLine(13, 21, 6, 'M')
    ..put(16, 5, 'K')
    ..put(19, 5, '*')
    ..put(17, 10, 'G')
    ..put(31, 13, 'P');

  // 4. act1_c4_gauntlet (48x18) — Crumble blocks, Pogo-Lanterns, Switch 'S' -> Locked Gate 'D'
  final g4 = _GridBuilder(48, 18)
    ..put(2, 15, 'P')
    ..spikeTrench(10, 21)
    ..hLine(12, 14, 13, 'C')
    ..put(17, 13, 'O')
    ..hLine(19, 20, 12, 'C')
    ..hLine(24, 32, 11, '=')
    ..vLine(25, 11, 15, 'H')
    ..hLine(16, 22, 7, '=')
    ..put(19, 6, 'S') // Switch perched above the chasm!
    ..put(12, 8, 'G')
    ..put(29, 8, 'G')
    ..put(28, 10, 'X')
    ..put(31, 15, '*')
    ..fillRect(38, 1, 39, 11, '#')
    ..lockedGateWall(38, 12, 15)
    ..put(8, 11, 'T')
    ..put(26, 9, 'T')
    ..put(42, 12, 'T')
    ..put(45, 15, 'P');

  // 5. act1_c5_boss_sanduguan (36x16) — Boss Arena: Datu Makisig!
  final g5 = _GridBuilder(36, 16)
    ..put(2, 13, 'P')
    ..hLine(7, 13, 10, '=')
    ..hLine(22, 28, 10, '=')
    ..put(18, 6, 'G')
    ..put(10, 7, 'T')
    ..put(25, 7, 'T')
    ..put(18, 11, 'T')
    ..put(33, 13, 'P');

  return <DungeonChamberSpec>[
    DungeonChamberSpec(
      id: 'act1_c1_shore',
      actNumber: 1,
      title: 'Moonlit Barangay Landing',
      subtitle: 'Act I • Coastal Caverns',
      asciiGrid: g1.build(),
      defaultSpawnCol: 3,
      defaultSpawnRow: 13,
      minimapCol: 0,
      minimapRow: 0,
      loreTabletIds: const <String>['lore_act1_barangay_law'],
      chestRewardIds: const <String>['chest_act1_secret_shore'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 35,
          row: 13,
          targetRoomId: 'act1_c2_grotto',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Sunken Sanduguan Grotto →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a1_c1_scout1',
          archetypeId: 'barangay_scout',
          col: 18,
          row: 13,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a1_c1_wisp1',
          archetypeId: 'cave_alimaong',
          col: 27,
          row: 7,
          patrolRadiusTiles: 3,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act1_c2_grotto',
      actNumber: 1,
      title: 'Sunken Sanduguan Grotto',
      subtitle: 'Act I • Pogo-Lantern Trench',
      asciiGrid: g2.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isDarkCavern: true,
      minimapCol: 1,
      minimapRow: 0,
      loreTabletIds: const <String>['lore_act1_umalahokan'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act1_c1_shore',
          targetSpawnCol: 33,
          targetSpawnRow: 13,
          label: '← Barangay Landing',
        ),
        DungeonRoomExit(
          col: 43,
          row: 15,
          targetRoomId: 'act1_c3_sanctuary',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Bahay-Pulungan Sanctuary →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a1_c2_wisp1',
          archetypeId: 'cave_alimaong',
          col: 18,
          row: 6,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a1_c2_raider1',
          archetypeId: 'raider_leaper',
          col: 35,
          row: 15,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act1_c3_sanctuary',
      actNumber: 1,
      title: 'Bahay-Pulungan Tide Sanctuary',
      subtitle: 'Act I • Campfire Bench Checkpoint',
      asciiGrid: g3.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBenchSanctuary: true,
      minimapCol: 2,
      minimapRow: 0,
      loreTabletIds: const <String>['lore_act1_barangay_law'],
      chestRewardIds: const <String>['chest_act1_sanctuary_cache'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act1_c2_grotto',
          targetSpawnCol: 41,
          targetSpawnRow: 15,
          label: '← Sanduguan Grotto',
        ),
        DungeonRoomExit(
          col: 31,
          row: 13,
          targetRoomId: 'act1_c4_gauntlet',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Reef Raider Chasm →',
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act1_c4_gauntlet',
      actNumber: 1,
      title: 'Reef Raider Chasm',
      subtitle: 'Act I • Charter Switch Gauntlet',
      asciiGrid: g4.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isDarkCavern: true,
      minimapCol: 3,
      minimapRow: 0,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act1_c3_sanctuary',
          targetSpawnCol: 29,
          targetSpawnRow: 13,
          label: '← Tide Sanctuary',
        ),
        DungeonRoomExit(
          col: 45,
          row: 15,
          targetRoomId: 'act1_c5_boss_sanduguan',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Altar of the Sanduguan →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a1_c4_scout1',
          archetypeId: 'barangay_scout',
          col: 28,
          row: 15,
          patrolRadiusTiles: 3,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a1_c4_raider1',
          archetypeId: 'raider_leaper',
          col: 33,
          row: 15,
          patrolRadiusTiles: 3,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a1_c4_wisp1',
          archetypeId: 'cave_alimaong',
          col: 20,
          row: 5,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act1_c5_boss_sanduguan',
      actNumber: 1,
      title: 'Altar of the Sanduguan',
      subtitle: 'Act I Boss • Datu Makisig',
      asciiGrid: g5.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBossArena: true,
      bossId: 'boss_datu_makisig',
      bossSpawnCol: 26,
      bossSpawnRow: 13,
      minimapCol: 4,
      minimapRow: 0,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act1_c4_gauntlet',
          targetSpawnCol: 42,
          targetSpawnRow: 15,
          label: '← Reef Raider Chasm',
        ),
        DungeonRoomExit(
          col: 33,
          row: 13,
          targetRoomId: 'act2_c1_gates',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Act II: Intramuros Bastion →',
          requiresBossDefeat: true,
        ),
      ],
    ),
  ];
}

// ─────────────────────────── ACT II (5 CHAMBERS) ──────────────────────────

List<DungeonChamberSpec> _buildAct2Chambers() {
  final g1 = _GridBuilder(46, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..hLine(10, 17, 10, '=')
    ..hLine(22, 29, 8, '=')
    ..vLine(12, 10, 13, 'H')
    ..put(14, 13, 'X')
    ..put(24, 7, 'L')
    ..put(9, 11, 'T')
    ..put(25, 6, 'T')
    ..put(37, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 40,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 44,
      lootChar: 'K',
      secondChar: '*',
    );

  final g2 = _GridBuilder(42, 20, floorChar: '#')
    ..put(2, 17, 'P')
    ..hLine(6, 13, 14, '=')
    ..vLine(8, 14, 17, 'H')
    ..hLine(16, 23, 11, '=')
    ..vLine(21, 11, 17, 'H')
    ..hLine(9, 16, 8, '=')
    ..hLine(25, 34, 8, '=')
    ..spikeTrench(11, 20)
    ..put(14, 15, 'O')
    ..put(18, 15, 'O')
    ..put(19, 6, 'G')
    ..put(29, 7, 'L')
    ..put(32, 17, '*')
    ..put(12, 6, 'T')
    ..put(30, 5, 'T')
    ..put(39, 17, 'P');

  final g3 = _GridBuilder(36, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..put(15, 13, 'B')
    ..put(12, 13, 'L')
    ..put(9, 11, 'T')
    ..put(21, 11, 'T')
    ..put(27, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 30,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 34,
      lootChar: 'K',
      secondChar: '*',
    );

  final g4 = _GridBuilder(46, 18, floorChar: '#')
    ..put(2, 15, 'P')
    ..hLine(9, 16, 11, '=')
    ..hLine(22, 29, 11, '=')
    ..hLine(16, 22, 7, '=')
    ..put(19, 6, 'S')
    ..put(14, 8, 'G')
    ..put(26, 8, 'G')
    ..fillRect(36, 1, 37, 11, '#')
    ..lockedGateWall(36, 12, 15)
    ..put(8, 9, 'T')
    ..put(28, 9, 'T')
    ..put(40, 12, 'T')
    ..put(43, 15, 'P');

  final g5 = _GridBuilder(38, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..hLine(7, 13, 10, '=')
    ..hLine(24, 30, 10, '=')
    ..put(14, 6, 'G')
    ..put(23, 6, 'G')
    ..put(19, 9, 'O')
    ..put(9, 7, 'T')
    ..put(28, 7, 'T')
    ..put(35, 13, 'P');

  return <DungeonChamberSpec>[
    DungeonChamberSpec(
      id: 'act2_c1_gates',
      actNumber: 2,
      title: 'Bastion Outer Wall',
      subtitle: 'Act II • Intramuros Ramparts',
      asciiGrid: g1.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      minimapCol: 0,
      minimapRow: 1,
      loreTabletIds: const <String>['lore_act2_propaganda_press'],
      chestRewardIds: const <String>['chest_act2_rampart_secret'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act1_c5_boss_sanduguan',
          targetSpawnCol: 30,
          targetSpawnRow: 13,
          label: '← Act I: Sanduguan Altar',
        ),
        DungeonRoomExit(
          col: 37,
          row: 13,
          targetRoomId: 'act2_c2_belltower',
          targetSpawnCol: 4,
          targetSpawnRow: 17,
          label: 'Belltower Spire →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a2_c1_lancer1',
          archetypeId: 'guardia_lancer',
          col: 18,
          row: 13,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a2_c1_musk1',
          archetypeId: 'intramuros_musketeer',
          col: 27,
          row: 7,
          patrolRadiusTiles: 2,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act2_c2_belltower',
      actNumber: 2,
      title: 'Spire of the Nightwings',
      subtitle: 'Act II • Belltower Ascent',
      asciiGrid: g2.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 17,
      isDarkCavern: true,
      minimapCol: 1,
      minimapRow: 1,
      loreTabletIds: const <String>['lore_act2_katipunan_kartilya'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 17,
          targetRoomId: 'act2_c1_gates',
          targetSpawnCol: 35,
          targetSpawnRow: 13,
          label: '← Bastion Outer Wall',
        ),
        DungeonRoomExit(
          col: 39,
          row: 17,
          targetRoomId: 'act2_c3_sanctuary',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'La Solidaridad Sanctuary →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a2_c2_bat1',
          archetypeId: 'belltower_bat',
          col: 14,
          row: 5,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a2_c2_bat2',
          archetypeId: 'belltower_bat',
          col: 28,
          row: 5,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a2_c2_musk1',
          archetypeId: 'intramuros_musketeer',
          col: 31,
          row: 7,
          patrolRadiusTiles: 2,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act2_c3_sanctuary',
      actNumber: 2,
      title: 'La Solidaridad Press Sanctuary',
      subtitle: 'Act II • Campfire Bench Checkpoint',
      asciiGrid: g3.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBenchSanctuary: true,
      minimapCol: 2,
      minimapRow: 1,
      loreTabletIds: const <String>['lore_act2_propaganda_press'],
      chestRewardIds: const <String>['chest_act2_press_vault'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act2_c2_belltower',
          targetSpawnCol: 37,
          targetSpawnRow: 17,
          label: '← Belltower Spire',
        ),
        DungeonRoomExit(
          col: 27,
          row: 13,
          targetRoomId: 'act2_c4_mateo_courtyard',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Cloister of the Sworn Duel →',
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act2_c4_mateo_courtyard',
      actNumber: 2,
      title: 'Cloister of the Sworn Duel',
      subtitle: 'Act II • Rival Mateo Encounter',
      asciiGrid: g4.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      minimapCol: 3,
      minimapRow: 1,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act2_c3_sanctuary',
          targetSpawnCol: 25,
          targetSpawnRow: 13,
          label: '← Press Sanctuary',
        ),
        DungeonRoomExit(
          col: 43,
          row: 15,
          targetRoomId: 'act2_c5_boss_valdes',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Viceroy\'s Garrison Hall →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a2_c4_rival_mateo',
          archetypeId: 'rival_mateo',
          col: 25,
          row: 15,
          patrolRadiusTiles: 6,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act2_c5_boss_valdes',
      actNumber: 2,
      title: 'Viceroy\'s Garrison Hall',
      subtitle: 'Act II Boss • Gobernador-Heneral Valdés',
      asciiGrid: g5.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBossArena: true,
      bossId: 'boss_valdes',
      bossSpawnCol: 28,
      bossSpawnRow: 13,
      minimapCol: 4,
      minimapRow: 1,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act2_c4_mateo_courtyard',
          targetSpawnCol: 40,
          targetSpawnRow: 15,
          label: '← Cloister Courtyard',
        ),
        DungeonRoomExit(
          col: 35,
          row: 13,
          targetRoomId: 'act3_c1_nave',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Act III: Barasoain Nave →',
          requiresBossDefeat: true,
        ),
      ],
    ),
  ];
}

// ─────────────────────────── ACT III (5 CHAMBERS) ─────────────────────────

List<DungeonChamberSpec> _buildAct3Chambers() {
  final g1 = _GridBuilder(46, 16, floorChar: 'M')
    ..put(2, 13, 'P')
    ..hLine(10, 17, 10, '=')
    ..hLine(23, 31, 9, '=')
    ..put(13, 13, 'X')
    ..put(27, 8, 'L')
    ..put(8, 10, 'T')
    ..put(20, 8, 'T')
    ..put(33, 10, 'T')
    ..put(37, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 40,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 44,
      lootChar: 'K',
      secondChar: '*',
    );

  final g2 = _GridBuilder(48, 18, floorChar: 'M')
    ..put(2, 15, 'P')
    ..spikeTrench(12, 31)
    ..hLine(13, 15, 13, 'C')
    ..put(18, 13, 'O')
    ..put(22, 12, 'O')
    ..hLine(25, 27, 13, 'C')
    ..put(29, 13, 'O')
    ..put(20, 7, 'G')
    ..put(28, 7, 'G')
    ..hLine(34, 41, 11, '=')
    ..put(38, 10, 'L')
    ..put(35, 15, '*')
    ..put(9, 11, 'T')
    ..put(24, 5, 'T')
    ..put(39, 9, 'T')
    ..put(45, 15, 'P');

  final g3 = _GridBuilder(36, 16, floorChar: 'M')
    ..put(2, 13, 'P')
    ..put(16, 13, 'B')
    ..put(13, 13, 'L')
    ..hLine(12, 22, 7, '=')
    ..put(17, 10, 'G')
    ..put(17, 6, 'K')
    ..put(20, 6, '*')
    ..put(9, 11, 'T')
    ..put(24, 11, 'T')
    ..put(33, 13, 'P');

  final g4 = _GridBuilder(48, 18, floorChar: '#')
    ..put(2, 15, 'P')
    ..hLine(8, 16, 11, '=')
    ..hLine(20, 30, 11, '=')
    ..vLine(10, 11, 15, 'H')
    ..hLine(15, 23, 7, '=')
    ..put(19, 6, 'S')
    ..put(13, 10, 'X')
    ..put(28, 10, '*')
    ..fillRect(38, 1, 39, 11, '#')
    ..lockedGateWall(38, 12, 15)
    ..put(11, 8, 'T')
    ..put(27, 8, 'T')
    ..put(42, 12, 'T')
    ..put(45, 15, 'P');

  final g5 = _GridBuilder(38, 18, floorChar: '#')
    ..put(2, 15, 'P')
    ..hLine(7, 13, 11, '=')
    ..hLine(24, 30, 11, '=')
    ..put(16, 10, 'O')
    ..put(21, 10, 'O')
    ..put(13, 6, 'G')
    ..put(24, 6, 'G')
    ..put(9, 8, 'T')
    ..put(28, 8, 'T')
    ..put(35, 15, 'P');

  return <DungeonChamberSpec>[
    DungeonChamberSpec(
      id: 'act3_c1_nave',
      actNumber: 3,
      title: 'Candlelit Barasoain Nave',
      subtitle: 'Act III • Malolos Catacombs',
      asciiGrid: g1.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      minimapCol: 0,
      minimapRow: 2,
      loreTabletIds: const <String>['lore_act3_barasoain_assembly'],
      chestRewardIds: const <String>['chest_act3_nave_relic'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act2_c5_boss_valdes',
          targetSpawnCol: 32,
          targetSpawnRow: 13,
          label: '← Act II: Garrison Hall',
        ),
        DungeonRoomExit(
          col: 37,
          row: 13,
          targetRoomId: 'act3_c2_catacombs',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Sunken Charter Catacombs →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a3_c1_sword1',
          archetypeId: 'malolos_swordsman',
          col: 18,
          row: 13,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a3_c1_acolyte1',
          archetypeId: 'tribunal_acolyte',
          col: 27,
          row: 6,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act3_c2_catacombs',
      actNumber: 3,
      title: 'Sunken Charter Catacombs',
      subtitle: 'Act III • Crumble & Pogo Abyss',
      asciiGrid: g2.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isDarkCavern: true,
      minimapCol: 1,
      minimapRow: 2,
      loreTabletIds: const <String>['lore_act3_separation_powers'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act3_c1_nave',
          targetSpawnCol: 35,
          targetSpawnRow: 13,
          label: '← Barasoain Nave',
        ),
        DungeonRoomExit(
          col: 45,
          row: 15,
          targetRoomId: 'act3_c3_sanctuary',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Malolos Assembly Sanctuary →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a3_c2_acolyte1',
          archetypeId: 'tribunal_acolyte',
          col: 21,
          row: 6,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a3_c2_sword1',
          archetypeId: 'malolos_swordsman',
          col: 38,
          row: 15,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act3_c3_sanctuary',
      actNumber: 3,
      title: 'Malolos Assembly Sanctuary',
      subtitle: 'Act III • Campfire Bench Checkpoint',
      asciiGrid: g3.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBenchSanctuary: true,
      minimapCol: 2,
      minimapRow: 2,
      loreTabletIds: const <String>['lore_act3_barasoain_assembly'],
      chestRewardIds: const <String>['chest_act3_assembly_vault'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act3_c2_catacombs',
          targetSpawnCol: 43,
          targetSpawnRow: 15,
          label: '← Charter Catacombs',
        ),
        DungeonRoomExit(
          col: 33,
          row: 13,
          targetRoomId: 'act3_c4_switch_crypt',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Hall of the Three Branches →',
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act3_c4_switch_crypt',
      actNumber: 3,
      title: 'Hall of the Three Branches',
      subtitle: 'Act III • Charter Switch Gauntlet',
      asciiGrid: g4.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isDarkCavern: true,
      minimapCol: 3,
      minimapRow: 2,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act3_c3_sanctuary',
          targetSpawnCol: 31,
          targetSpawnRow: 13,
          label: '← Malolos Sanctuary',
        ),
        DungeonRoomExit(
          col: 45,
          row: 15,
          targetRoomId: 'act3_c5_boss_calderon',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Sanctum of the First Republic →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a3_c4_lancer1',
          archetypeId: 'guardia_lancer',
          col: 20,
          row: 15,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a3_c4_sword1',
          archetypeId: 'malolos_swordsman',
          col: 30,
          row: 15,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a3_c4_acolyte1',
          archetypeId: 'tribunal_acolyte',
          col: 24,
          row: 6,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act3_c5_boss_calderon',
      actNumber: 3,
      title: 'Sanctum of the First Republic',
      subtitle: 'Act III Boss • Felipe Calderón',
      asciiGrid: g5.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isBossArena: true,
      bossId: 'boss_calderon',
      bossSpawnCol: 27,
      bossSpawnRow: 10,
      minimapCol: 4,
      minimapRow: 2,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act3_c4_switch_crypt',
          targetSpawnCol: 42,
          targetSpawnRow: 15,
          label: '← Hall of Three Branches',
        ),
        DungeonRoomExit(
          col: 35,
          row: 15,
          targetRoomId: 'act4_c1_viaduct',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Act IV: Commonwealth Sky-Bridges →',
          requiresBossDefeat: true,
        ),
      ],
    ),
  ];
}

// ─────────────────────────── ACT IV (5 CHAMBERS) ──────────────────────────

List<DungeonChamberSpec> _buildAct4Chambers() {
  final g1 = _GridBuilder(48, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..spikeTrench(14, 22)
    ..hLine(13, 23, 10, '=')
    ..put(18, 6, 'G')
    ..hLine(27, 34, 9, '=')
    ..put(31, 8, 'L')
    ..put(10, 11, 'T')
    ..put(26, 7, 'T')
    ..put(39, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 42,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 46,
      lootChar: 'K',
      secondChar: '*',
    );

  final g2 = _GridBuilder(44, 20, floorChar: '#')
    ..put(2, 17, 'P')
    ..hLine(7, 13, 14, '=')
    ..vLine(9, 14, 17, 'H')
    ..hLine(16, 22, 11, 'C')
    ..hLine(25, 32, 9, '=')
    ..put(19, 7, 'G')
    ..put(28, 6, 'G')
    ..spikeTrench(13, 27)
    ..put(16, 15, 'O')
    ..put(21, 15, 'O')
    ..put(25, 15, 'O')
    ..put(30, 8, 'L')
    ..put(36, 17, '*')
    ..put(11, 10, 'T')
    ..put(32, 7, 'T')
    ..put(41, 17, 'P');

  final g3 = _GridBuilder(36, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..put(15, 13, 'B')
    ..put(12, 13, 'L')
    ..put(9, 10, 'T')
    ..put(21, 10, 'T')
    ..put(27, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 30,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 34,
      lootChar: 'K',
      secondChar: '*',
    );

  final g4 = _GridBuilder(50, 18, floorChar: '#')
    ..put(2, 15, 'P')
    ..spikeTrench(11, 29)
    ..put(14, 13, 'O')
    ..put(18, 9, 'G')
    ..hLine(20, 22, 12, 'C')
    ..put(25, 13, 'O')
    ..put(28, 9, 'G')
    ..hLine(31, 37, 11, '=')
    ..hLine(18, 24, 6, '=')
    ..put(21, 5, 'S')
    ..fillRect(40, 1, 41, 11, '#')
    ..lockedGateWall(40, 12, 15)
    ..put(8, 10, 'T')
    ..put(24, 4, 'T')
    ..put(44, 12, 'T')
    ..put(47, 15, 'P');

  final g5 = _GridBuilder(38, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..hLine(6, 13, 10, '=')
    ..hLine(24, 31, 10, '=')
    ..hLine(15, 22, 7, '=')
    ..put(19, 10, 'O')
    ..put(11, 6, 'T')
    ..put(26, 6, 'T')
    ..put(35, 13, 'P');

  return <DungeonChamberSpec>[
    DungeonChamberSpec(
      id: 'act4_c1_viaduct',
      actNumber: 4,
      title: 'Manila Deco Viaduct',
      subtitle: 'Act IV • Commonwealth Sky-Bridges',
      asciiGrid: g1.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      minimapCol: 0,
      minimapRow: 3,
      loreTabletIds: const <String>['lore_act4_commonwealth_charter'],
      chestRewardIds: const <String>['chest_act4_viaduct_cache'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act3_c5_boss_calderon',
          targetSpawnCol: 32,
          targetSpawnRow: 15,
          label: '← Act III: First Republic Sanctum',
        ),
        DungeonRoomExit(
          col: 39,
          row: 13,
          targetRoomId: 'act4_c2_clocktower',
          targetSpawnCol: 4,
          targetSpawnRow: 17,
          label: 'Gearworks Ascent →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a4_c1_auto1',
          archetypeId: 'deco_automaton',
          col: 28,
          row: 13,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a4_c1_sniper1',
          archetypeId: 'skybridge_sniper',
          col: 32,
          row: 8,
          patrolRadiusTiles: 2,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act4_c2_clocktower',
      actNumber: 4,
      title: 'Gearworks Ascent',
      subtitle: 'Act IV • Clockwork Spire',
      asciiGrid: g2.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 17,
      minimapCol: 1,
      minimapRow: 3,
      loreTabletIds: const <String>['lore_act4_womens_suffrage'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 17,
          targetRoomId: 'act4_c1_viaduct',
          targetSpawnCol: 37,
          targetSpawnRow: 13,
          label: '← Deco Viaduct',
        ),
        DungeonRoomExit(
          col: 41,
          row: 17,
          targetRoomId: 'act4_c3_sanctuary',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Legislative Concourse →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a4_c2_sniper1',
          archetypeId: 'skybridge_sniper',
          col: 27,
          row: 8,
          patrolRadiusTiles: 2,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a4_c2_bat1',
          archetypeId: 'belltower_bat',
          col: 18,
          row: 5,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a4_c2_auto1',
          archetypeId: 'deco_automaton',
          col: 34,
          row: 17,
          patrolRadiusTiles: 3,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act4_c3_sanctuary',
      actNumber: 4,
      title: 'Legislative Concourse Bench',
      subtitle: 'Act IV • Campfire Bench Checkpoint',
      asciiGrid: g3.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBenchSanctuary: true,
      minimapCol: 2,
      minimapRow: 3,
      loreTabletIds: const <String>['lore_act4_commonwealth_charter'],
      chestRewardIds: const <String>['chest_act4_concourse_vault'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act4_c2_clocktower',
          targetSpawnCol: 39,
          targetSpawnRow: 17,
          label: '← Gearworks Ascent',
        ),
        DungeonRoomExit(
          col: 27,
          row: 13,
          targetRoomId: 'act4_c4_sky_gauntlet',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'High-Altitude Trial →',
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act4_c4_sky_gauntlet',
      actNumber: 4,
      title: 'High-Altitude Trial',
      subtitle: 'Act IV • Grapple & Switch Chasm',
      asciiGrid: g4.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      minimapCol: 3,
      minimapRow: 3,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act4_c3_sanctuary',
          targetSpawnCol: 25,
          targetSpawnRow: 13,
          label: '← Concourse Bench',
        ),
        DungeonRoomExit(
          col: 47,
          row: 15,
          targetRoomId: 'act4_c5_boss_warden',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Dome of Checks & Balances →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a4_c4_auto1',
          archetypeId: 'deco_automaton',
          col: 35,
          row: 15,
          patrolRadiusTiles: 3,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a4_c4_sniper1',
          archetypeId: 'skybridge_sniper',
          col: 34,
          row: 10,
          patrolRadiusTiles: 2,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act4_c5_boss_warden',
      actNumber: 4,
      title: 'Dome of Checks & Balances',
      subtitle: 'Act IV Boss • Commonwealth Warden',
      asciiGrid: g5.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBossArena: true,
      bossId: 'boss_commonwealth_warden',
      bossSpawnCol: 28,
      bossSpawnRow: 13,
      minimapCol: 4,
      minimapRow: 3,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act4_c4_sky_gauntlet',
          targetSpawnCol: 44,
          targetSpawnRow: 15,
          label: '← High-Altitude Trial',
        ),
        DungeonRoomExit(
          col: 35,
          row: 13,
          targetRoomId: 'act5_c1_tunnel',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Act V: Corregidor Tunnels →',
          requiresBossDefeat: true,
        ),
      ],
    ),
  ];
}

// ─────────────────────────── ACT V (5 CHAMBERS) ───────────────────────────

List<DungeonChamberSpec> _buildAct5Chambers() {
  final g1 = _GridBuilder(46, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..hLine(11, 18, 10, '=')
    ..hLine(23, 31, 9, '=')
    ..put(15, 13, 'X')
    ..put(26, 8, 'L')
    ..put(9, 10, 'T')
    ..put(25, 7, 'T')
    ..put(37, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 40,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 44,
      lootChar: 'K',
      secondChar: '*',
    );

  final g2 = _GridBuilder(48, 18, floorChar: '#')
    ..put(2, 15, 'P')
    ..spikeTrench(13, 28)
    ..put(16, 13, 'O')
    ..hLine(19, 21, 12, 'C')
    ..put(24, 13, 'O')
    ..put(27, 13, 'O')
    ..put(20, 7, 'G')
    ..hLine(31, 39, 11, '=')
    ..put(36, 10, 'L')
    ..put(34, 15, '*')
    ..put(10, 11, 'T')
    ..put(35, 8, 'T')
    ..put(45, 15, 'P');

  final g3 = _GridBuilder(36, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..put(16, 13, 'B')
    ..put(13, 13, 'L')
    ..hLine(12, 22, 8, '=')
    ..put(17, 7, 'K')
    ..put(19, 7, 'X')
    ..vLine(13, 8, 13, 'H')
    ..put(9, 10, 'T')
    ..put(24, 10, 'T')
    ..put(33, 13, 'P');

  final g4 = _GridBuilder(48, 18, floorChar: '#')
    ..put(2, 15, 'P')
    ..hLine(10, 17, 11, '=')
    ..hLine(24, 32, 11, '=')
    ..hLine(17, 23, 7, '=')
    ..put(20, 6, 'S')
    ..put(15, 8, 'G')
    ..put(26, 8, 'G')
    ..fillRect(38, 1, 39, 11, '#')
    ..lockedGateWall(38, 12, 15)
    ..put(10, 9, 'T')
    ..put(29, 9, 'T')
    ..put(42, 12, 'T')
    ..put(45, 15, 'P');

  final g5 = _GridBuilder(38, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..hLine(7, 14, 10, '=')
    ..hLine(23, 30, 10, '=')
    ..put(19, 6, 'G')
    ..put(10, 7, 'T')
    ..put(27, 7, 'T')
    ..put(35, 13, 'P');

  return <DungeonChamberSpec>[
    DungeonChamberSpec(
      id: 'act5_c1_tunnel',
      actNumber: 5,
      title: 'Malinta West Portal',
      subtitle: 'Act V • Corregidor Bunkers',
      asciiGrid: g1.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isDarkCavern: true,
      minimapCol: 0,
      minimapRow: 4,
      loreTabletIds: const <String>['lore_act5_malinta_resistance'],
      chestRewardIds: const <String>['chest_act5_armory_secret'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act4_c5_boss_warden',
          targetSpawnCol: 32,
          targetSpawnRow: 13,
          label: '← Act IV: Dome of Checks & Balances',
        ),
        DungeonRoomExit(
          col: 37,
          row: 13,
          targetRoomId: 'act5_c2_trenches',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Artillery Ravine →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a5_c1_commando1',
          archetypeId: 'imperial_commando',
          col: 19,
          row: 13,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a5_c1_mortar1',
          archetypeId: 'bunker_mortar',
          col: 29,
          row: 8,
          patrolRadiusTiles: 0,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act5_c2_trenches',
      actNumber: 5,
      title: 'Artillery Ravine',
      subtitle: 'Act V • Mortar & Pogo Crossing',
      asciiGrid: g2.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isDarkCavern: true,
      minimapCol: 1,
      minimapRow: 4,
      loreTabletIds: const <String>['lore_act5_guerrilla_unity'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act5_c1_tunnel',
          targetSpawnCol: 35,
          targetSpawnRow: 13,
          label: '← Malinta West Portal',
        ),
        DungeonRoomExit(
          col: 45,
          row: 15,
          targetRoomId: 'act5_c3_sanctuary',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Guerrilla Radio Sanctuary →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a5_c2_mortar1',
          archetypeId: 'bunker_mortar',
          col: 33,
          row: 10,
          patrolRadiusTiles: 0,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a5_c2_commando1',
          archetypeId: 'imperial_commando',
          col: 39,
          row: 15,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act5_c3_sanctuary',
      actNumber: 5,
      title: 'Guerrilla Radio Sanctuary',
      subtitle: 'Act V • Campfire Bench Checkpoint',
      asciiGrid: g3.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBenchSanctuary: true,
      minimapCol: 2,
      minimapRow: 4,
      loreTabletIds: const <String>['lore_act5_malinta_resistance'],
      chestRewardIds: const <String>['chest_act5_radio_cache'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act5_c2_trenches',
          targetSpawnCol: 43,
          targetSpawnRow: 15,
          label: '← Artillery Ravine',
        ),
        DungeonRoomExit(
          col: 33,
          row: 13,
          targetRoomId: 'act5_c4_mateo_bunker',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Battery Way Crossing →',
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act5_c4_mateo_bunker',
      actNumber: 5,
      title: 'Battery Way Crossing',
      subtitle: 'Act V • Rival Mateo Rematch',
      asciiGrid: g4.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isDarkCavern: true,
      minimapCol: 3,
      minimapRow: 4,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act5_c3_sanctuary',
          targetSpawnCol: 31,
          targetSpawnRow: 13,
          label: '← Radio Sanctuary',
        ),
        DungeonRoomExit(
          col: 45,
          row: 15,
          targetRoomId: 'act5_c5_boss_commander',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Command Bunker Citadel →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a5_c4_rival_mateo',
          archetypeId: 'rival_mateo',
          col: 26,
          row: 15,
          patrolRadiusTiles: 6,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a5_c4_mortar1',
          archetypeId: 'bunker_mortar',
          col: 30,
          row: 10,
          patrolRadiusTiles: 0,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act5_c5_boss_commander',
      actNumber: 5,
      title: 'Command Bunker Citadel',
      subtitle: 'Act V Boss • Imperial Commander',
      asciiGrid: g5.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBossArena: true,
      isDarkCavern: true,
      bossId: 'boss_imperial_commander',
      bossSpawnCol: 28,
      bossSpawnRow: 13,
      minimapCol: 4,
      minimapRow: 4,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act5_c4_mateo_bunker',
          targetSpawnCol: 42,
          targetSpawnRow: 15,
          label: '← Battery Way Crossing',
        ),
        DungeonRoomExit(
          col: 35,
          row: 13,
          targetRoomId: 'act6_c1_precinct',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Act VI: The Obsidian Vault →',
          requiresBossDefeat: true,
        ),
      ],
    ),
  ];
}

// ─────────────────────────── ACT VI (5 CHAMBERS) ──────────────────────────

List<DungeonChamberSpec> _buildAct6Chambers() {
  final g1 = _GridBuilder(46, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..hLine(10, 18, 10, '=')
    ..hLine(24, 32, 10, '=')
    ..put(13, 13, 'X')
    ..put(28, 9, 'L')
    ..put(9, 10, 'T')
    ..put(26, 7, 'T')
    ..put(37, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 40,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 44,
      lootChar: 'K',
      secondChar: '*',
    );

  final g2 = _GridBuilder(44, 20, floorChar: '#')
    ..put(2, 17, 'P')
    ..hLine(6, 13, 14, '=')
    ..vLine(8, 14, 17, 'H')
    ..hLine(16, 24, 11, '=')
    ..hLine(26, 35, 8, '=')
    ..spikeTrench(12, 27)
    ..put(15, 15, 'O')
    ..put(20, 15, 'O')
    ..put(25, 15, 'O')
    ..put(18, 7, 'G')
    ..put(28, 5, 'G')
    ..put(32, 7, 'L')
    ..put(36, 17, '*')
    ..put(10, 10, 'T')
    ..put(31, 5, 'T')
    ..put(41, 17, 'P');

  final g3 = _GridBuilder(36, 16, floorChar: '#')
    ..put(2, 13, 'P')
    ..put(15, 13, 'B')
    ..put(12, 13, 'L')
    ..put(9, 10, 'T')
    ..put(21, 10, 'T')
    ..put(27, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 30,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 34,
      lootChar: 'K',
      secondChar: '*',
    );

  final g4 = _GridBuilder(50, 18, floorChar: '#')
    ..put(2, 15, 'P')
    ..spikeTrench(12, 24)
    ..hLine(14, 16, 13, 'C')
    ..put(19, 13, 'O')
    ..put(22, 13, 'O')
    ..hLine(26, 36, 11, '=')
    ..hLine(16, 22, 7, '=')
    ..put(19, 6, 'S')
    ..put(15, 9, 'G')
    ..put(25, 9, 'G')
    ..fillRect(40, 1, 41, 11, '#')
    ..lockedGateWall(40, 12, 15)
    ..put(9, 10, 'T')
    ..put(29, 8, 'T')
    ..put(44, 12, 'T')
    ..put(47, 15, 'P');

  final g5 = _GridBuilder(40, 18, floorChar: '#')
    ..put(2, 15, 'P')
    ..hLine(7, 14, 11, '=')
    ..hLine(25, 32, 11, '=')
    ..put(16, 10, 'O')
    ..put(23, 10, 'O')
    ..put(14, 6, 'G')
    ..put(25, 6, 'G')
    ..put(10, 8, 'T')
    ..put(29, 8, 'T')
    ..put(37, 15, 'P');

  return <DungeonChamberSpec>[
    DungeonChamberSpec(
      id: 'act6_c1_precinct',
      actNumber: 6,
      title: 'Blackout Checkpoints',
      subtitle: 'Act VI • Obsidian Vault',
      asciiGrid: g1.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isDarkCavern: true,
      minimapCol: 0,
      minimapRow: 5,
      loreTabletIds: const <String>['lore_act6_writ_habeas'],
      chestRewardIds: const <String>['chest_act6_samizdat_vault'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act5_c5_boss_commander',
          targetSpawnCol: 32,
          targetSpawnRow: 13,
          label: '← Act V: Command Bunker',
        ),
        DungeonRoomExit(
          col: 37,
          row: 13,
          targetRoomId: 'act6_c2_panopticon',
          targetSpawnCol: 4,
          targetSpawnRow: 17,
          label: 'Surveillance Shaft →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a6_c1_drone1',
          archetypeId: 'censor_drone',
          col: 17,
          row: 6,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a6_c1_jug1',
          archetypeId: 'iron_juggernaut',
          col: 29,
          row: 13,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act6_c2_panopticon',
      actNumber: 6,
      title: 'Surveillance Shaft',
      subtitle: 'Act VI • Panopticon Ascent',
      asciiGrid: g2.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 17,
      isDarkCavern: true,
      minimapCol: 1,
      minimapRow: 5,
      loreTabletIds: const <String>['lore_act6_edsa_vigil'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 17,
          targetRoomId: 'act6_c1_precinct',
          targetSpawnCol: 35,
          targetSpawnRow: 13,
          label: '← Blackout Checkpoints',
        ),
        DungeonRoomExit(
          col: 41,
          row: 17,
          targetRoomId: 'act6_c3_sanctuary',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'EDSA Vigil Sanctuary →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a6_c2_drone1',
          archetypeId: 'censor_drone',
          col: 20,
          row: 5,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a6_c2_sniper1',
          archetypeId: 'skybridge_sniper',
          col: 30,
          row: 7,
          patrolRadiusTiles: 2,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act6_c3_sanctuary',
      actNumber: 6,
      title: 'EDSA Vigil Sanctuary',
      subtitle: 'Act VI • Campfire Bench Checkpoint',
      asciiGrid: g3.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBenchSanctuary: true,
      minimapCol: 2,
      minimapRow: 5,
      loreTabletIds: const <String>['lore_act6_edsa_vigil'],
      chestRewardIds: const <String>['chest_act6_edsa_vigil_chest'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act6_c2_panopticon',
          targetSpawnCol: 39,
          targetSpawnRow: 17,
          label: '← Surveillance Shaft',
        ),
        DungeonRoomExit(
          col: 27,
          row: 13,
          targetRoomId: 'act6_c4_vault_gauntlet',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Corridor of Silence →',
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act6_c4_vault_gauntlet',
      actNumber: 6,
      title: 'Corridor of Silence',
      subtitle: 'Act VI • Charter Switch Gauntlet',
      asciiGrid: g4.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isDarkCavern: true,
      minimapCol: 3,
      minimapRow: 5,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act6_c3_sanctuary',
          targetSpawnCol: 25,
          targetSpawnRow: 13,
          label: '← EDSA Vigil Sanctuary',
        ),
        DungeonRoomExit(
          col: 47,
          row: 15,
          targetRoomId: 'act6_c5_boss_censor',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Chamber of the Iron Censor →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a6_c4_jug1',
          archetypeId: 'iron_juggernaut',
          col: 33,
          row: 15,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a6_c4_drone1',
          archetypeId: 'censor_drone',
          col: 28,
          row: 6,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act6_c5_boss_censor',
      actNumber: 6,
      title: 'Chamber of the Iron Censor',
      subtitle: 'Act VI 3-Phase Boss • The Iron Censor',
      asciiGrid: g5.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isBossArena: true,
      isDarkCavern: true,
      bossId: 'boss_iron_censor',
      bossSpawnCol: 30,
      bossSpawnRow: 15,
      minimapCol: 4,
      minimapRow: 5,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act6_c4_vault_gauntlet',
          targetSpawnCol: 44,
          targetSpawnRow: 15,
          label: '← Corridor of Silence',
        ),
        DungeonRoomExit(
          col: 37,
          row: 15,
          targetRoomId: 'act7_c1_ascension',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Act VII: Golden Altar of 1987 →',
          requiresBossDefeat: true,
        ),
      ],
    ),
  ];
}

// ─────────────────────────── ACT VII (5 CHAMBERS) ─────────────────────────

List<DungeonChamberSpec> _buildAct7Chambers() {
  final g1 = _GridBuilder(48, 16, floorChar: 'M')
    ..put(2, 13, 'P')
    ..hLine(10, 18, 10, '=')
    ..hLine(24, 33, 9, '=')
    ..put(15, 13, 'X')
    ..put(29, 8, 'L')
    ..put(8, 10, 'T')
    ..put(21, 7, 'T')
    ..put(34, 10, 'T')
    ..put(39, 13, 'P')
    ..secretAlcoveRight(
      wallCol: 42,
      topRow: 10,
      bottomRow: 13,
      chamberRightCol: 46,
      lootChar: 'K',
      secondChar: '*',
    );

  final g2 = _GridBuilder(52, 18, floorChar: 'M')
    ..put(2, 15, 'P')
    ..spikeTrench(10, 35)
    ..put(13, 13, 'O')
    ..hLine(16, 18, 12, 'C')
    ..put(21, 13, 'O')
    ..put(23, 8, 'G')
    ..put(26, 13, 'O')
    ..hLine(29, 31, 12, 'C')
    ..put(34, 13, 'O')
    ..put(31, 8, 'G')
    ..hLine(38, 45, 11, '=')
    ..put(41, 10, 'L')
    ..put(40, 15, '*')
    ..put(8, 10, 'T')
    ..put(25, 5, 'T')
    ..put(43, 8, 'T')
    ..put(49, 15, 'P');

  final g3 = _GridBuilder(36, 16, floorChar: 'M')
    ..put(2, 13, 'P')
    ..put(16, 13, 'B')
    ..put(13, 13, 'L')
    ..hLine(12, 22, 8, '=')
    ..vLine(12, 8, 13, 'H')
    ..put(17, 7, 'K')
    ..put(20, 7, '*')
    ..put(9, 10, 'T')
    ..put(24, 10, 'T')
    ..put(33, 13, 'P');

  final g4 = _GridBuilder(50, 18, floorChar: '#')
    ..put(2, 15, 'P')
    ..hLine(8, 16, 11, '=')
    ..hLine(22, 33, 11, '=')
    ..hLine(16, 22, 7, '=')
    ..put(19, 6, 'S')
    ..put(14, 9, 'G')
    ..put(27, 9, 'G')
    ..fillRect(40, 1, 41, 11, '#')
    ..lockedGateWall(40, 12, 15)
    ..put(9, 8, 'T')
    ..put(29, 8, 'T')
    ..put(44, 12, 'T')
    ..put(47, 15, 'P');

  final g5 = _GridBuilder(42, 18, floorChar: 'M')
    ..put(2, 15, 'P')
    ..hLine(7, 14, 11, '=')
    ..hLine(27, 34, 11, '=')
    ..hLine(17, 24, 8, '=')
    ..put(15, 11, 'O')
    ..put(26, 11, 'O')
    ..put(13, 6, 'G')
    ..put(28, 6, 'G')
    ..put(10, 8, 'T')
    ..put(20, 5, 'T')
    ..put(31, 8, 'T');

  return <DungeonChamberSpec>[
    DungeonChamberSpec(
      id: 'act7_c1_ascension',
      actNumber: 7,
      title: 'Steps of People Power',
      subtitle: 'Act VII • Golden Colonnade',
      asciiGrid: g1.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      minimapCol: 0,
      minimapRow: 6,
      loreTabletIds: const <String>['lore_act7_bill_of_rights'],
      chestRewardIds: const <String>['chest_act7_steps_vault'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act6_c5_boss_censor',
          targetSpawnCol: 34,
          targetSpawnRow: 15,
          label: '← Act VI: Iron Censor Chamber',
        ),
        DungeonRoomExit(
          col: 39,
          row: 13,
          targetRoomId: 'act7_c2_scales',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Bridge of the Bill of Rights →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a7_c1_sword1',
          archetypeId: 'malolos_swordsman',
          col: 18,
          row: 13,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a7_c1_jug1',
          archetypeId: 'iron_juggernaut',
          col: 31,
          row: 13,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act7_c2_scales',
      actNumber: 7,
      title: 'Bridge of the Bill of Rights',
      subtitle: 'Act VII • Grand Silksong Chasm',
      asciiGrid: g2.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      minimapCol: 1,
      minimapRow: 6,
      loreTabletIds: const <String>['lore_act7_sovereign_people'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act7_c1_ascension',
          targetSpawnCol: 37,
          targetSpawnRow: 13,
          label: '← Steps of People Power',
        ),
        DungeonRoomExit(
          col: 49,
          row: 15,
          targetRoomId: 'act7_c3_sanctuary',
          targetSpawnCol: 4,
          targetSpawnRow: 13,
          label: 'Sovereign Flame Sanctuary →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a7_c2_drone1',
          archetypeId: 'censor_drone',
          col: 22,
          row: 5,
          patrolRadiusTiles: 5,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a7_c2_commando1',
          archetypeId: 'imperial_commando',
          col: 42,
          row: 15,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act7_c3_sanctuary',
      actNumber: 7,
      title: 'Sovereign Flame Sanctuary',
      subtitle: 'Act VII • Final Campfire Bench',
      asciiGrid: g3.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 13,
      isBenchSanctuary: true,
      minimapCol: 2,
      minimapRow: 6,
      loreTabletIds: const <String>['lore_act7_sovereign_people'],
      chestRewardIds: const <String>['chest_act7_sanctuary_final'],
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 13,
          targetRoomId: 'act7_c2_scales',
          targetSpawnCol: 47,
          targetSpawnRow: 15,
          label: '← Bridge of the Bill of Rights',
        ),
        DungeonRoomExit(
          col: 33,
          row: 13,
          targetRoomId: 'act7_c4_hall_of_charters',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'Hall of the Six Seals →',
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act7_c4_hall_of_charters',
      actNumber: 7,
      title: 'Hall of the Six Seals',
      subtitle: 'Act VII • Final Gauntlet & Gate',
      asciiGrid: g4.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      minimapCol: 3,
      minimapRow: 6,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act7_c3_sanctuary',
          targetSpawnCol: 31,
          targetSpawnRow: 13,
          label: '← Sovereign Flame Sanctuary',
        ),
        DungeonRoomExit(
          col: 47,
          row: 15,
          targetRoomId: 'act7_c5_boss_sovereign',
          targetSpawnCol: 4,
          targetSpawnRow: 15,
          label: 'The Sovereign Altar of 1987 →',
        ),
      ],
      enemySpawns: const <DungeonEnemySpawnSpec>[
        DungeonEnemySpawnSpec(
          spawnId: 'a7_c4_auto1',
          archetypeId: 'deco_automaton',
          col: 18,
          row: 15,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a7_c4_jug1',
          archetypeId: 'iron_juggernaut',
          col: 32,
          row: 15,
          patrolRadiusTiles: 4,
        ),
        DungeonEnemySpawnSpec(
          spawnId: 'a7_c4_acolyte1',
          archetypeId: 'tribunal_acolyte',
          col: 26,
          row: 6,
          patrolRadiusTiles: 4,
        ),
      ],
    ),
    DungeonChamberSpec(
      id: 'act7_c5_boss_sovereign',
      actNumber: 7,
      title: 'The Sovereign Altar of 1987',
      subtitle: 'Final 3-Phase Boss • The Sovereign Guardian',
      asciiGrid: g5.build(),
      defaultSpawnCol: 4,
      defaultSpawnRow: 15,
      isBossArena: true,
      bossId: 'boss_sovereign_guardian',
      bossSpawnCol: 31,
      bossSpawnRow: 15,
      minimapCol: 4,
      minimapRow: 6,
      exits: const <DungeonRoomExit>[
        DungeonRoomExit(
          col: 2,
          row: 15,
          targetRoomId: 'act7_c4_hall_of_charters',
          targetSpawnCol: 44,
          targetSpawnRow: 15,
          label: '← Hall of the Six Seals',
        ),
      ],
    ),
  ];
}

// ═══════════════════════════════════════════════════════════════════════════
//  LOOKUP HELPERS & AUTOMATED STRUCTURAL WORLD VALIDATOR
// ═══════════════════════════════════════════════════════════════════════════

DungeonChamberSpec lookupDungeonChamber(String chamberId) {
  return kDungeonChambersById[chamberId] ?? kDungeonChambersById['act1_c1_shore']!;
}

DungeonActWorldSpec actSpecForNumber(int actNumber) {
  final idx = (actNumber - 1).clamp(0, kDungeonActWorlds.length - 1);
  return kDungeonActWorlds[idx];
}

List<DungeonChamberSpec> chambersForAct(int actNumber) {
  final act = actSpecForNumber(actNumber);
  return act.chamberIds
      .map((id) => kDungeonChambersById[id])
      .whereType<DungeonChamberSpec>()
      .toList(growable: false);
}

/// Validates structural integrity across all 35 chambers, exits, spawn points,
/// enemy archetypes, bosses, treasure chests, and lore tablets.
/// Returns an empty list when 100% of maps are structurally sound!
List<String> validateAllDungeonMaps() {
  final errors = <String>[];

  if (kDungeonActWorlds.length != 7) {
    errors.add('Expected 7 Acts, found ${kDungeonActWorlds.length}');
  }

  for (final act in kDungeonActWorlds) {
    for (final cid in act.chamberIds) {
      if (!kDungeonChambersById.containsKey(cid)) {
        errors.add('Act ${act.actNumber} references missing chamber "$cid"');
      }
    }
    if (!kDungeonChambersById.containsKey(act.entryChamberId)) {
      errors.add('Act ${act.actNumber} missing entryChamberId "${act.entryChamberId}"');
    }
    if (!kDungeonChambersById.containsKey(act.bossChamberId)) {
      errors.add('Act ${act.actNumber} missing bossChamberId "${act.bossChamberId}"');
    }
    if (lookupDungeonArchetype(act.bossId) == null) {
      errors.add('Act ${act.actNumber} unknown bossId "${act.bossId}"');
    }
  }

  for (final spec in kDungeonChambersById.values) {
    if (spec.asciiGrid.isEmpty) {
      errors.add('${spec.id}: empty asciiGrid');
      continue;
    }
    final expectedCols = spec.cols;
    for (var r = 0; r < spec.rows; r++) {
      if (spec.asciiGrid[r].length != expectedCols) {
        errors.add(
          '${spec.id}: row $r length ${spec.asciiGrid[r].length} != $expectedCols',
        );
      }
    }

    // Validate default spawn tile is inside bounds & non-solid / non-hazard
    final spawnTile = spec.tileAt(spec.defaultSpawnCol, spec.defaultSpawnRow);
    if (spawnTile.isFullSolid || spawnTile.isHazard) {
      errors.add(
        '${spec.id}: default spawn (${spec.defaultSpawnCol},${spec.defaultSpawnRow}) blocked by $spawnTile',
      );
    }

    // Validate every room exit & its landing coordinates in the target chamber
    for (final ex in spec.exits) {
      final target = kDungeonChambersById[ex.targetRoomId];
      if (target == null) {
        errors.add('${spec.id}: exit targets missing room "${ex.targetRoomId}"');
        continue;
      }
      final portalTile = spec.tileAt(ex.col, ex.row);
      if (portalTile != DungeonTileType.roomPortal) {
        errors.add(
          '${spec.id}: exit at (${ex.col},${ex.row}) is $portalTile instead of roomPortal',
        );
      }
      final landTile = target.tileAt(ex.targetSpawnCol, ex.targetSpawnRow);
      if (landTile.isFullSolid || landTile.isHazard) {
        errors.add(
          '${spec.id} -> ${target.id}: target spawn (${ex.targetSpawnCol},${ex.targetSpawnRow}) blocked by $landTile',
        );
      }
    }

    // Validate every enemy spawn & boss spawn
    for (final sp in spec.enemySpawns) {
      if (lookupDungeonArchetype(sp.archetypeId) == null) {
        errors.add('${spec.id}: unknown enemy archetype "${sp.archetypeId}"');
      }
      final t = spec.tileAt(sp.col, sp.row);
      if (t.isFullSolid) {
        errors.add('${spec.id}: enemy ${sp.spawnId} spawned inside solid tile at (${sp.col},${sp.row})');
      }
    }
    if (spec.bossId != null) {
      if (lookupDungeonArchetype(spec.bossId!) == null) {
        errors.add('${spec.id}: unknown bossId "${spec.bossId}"');
      }
      final bt = spec.tileAt(spec.bossSpawnCol, spec.bossSpawnRow);
      if (bt.isFullSolid) {
        errors.add('${spec.id}: boss spawned inside solid tile');
      }
    }

    // Validate chest & lore catalog IDs
    for (final chestId in spec.chestRewardIds) {
      if (!kDungeonChestRewards.containsKey(chestId)) {
        errors.add('${spec.id}: missing chest reward "$chestId"');
      }
    }
    for (final loreId in spec.loreTabletIds) {
      if (!kDungeonLoreTablets.containsKey(loreId)) {
        errors.add('${spec.id}: missing lore tablet "$loreId"');
      }
    }
  }

  return errors;
}
