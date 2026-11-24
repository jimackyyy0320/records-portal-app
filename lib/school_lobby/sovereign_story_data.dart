import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'dungeon/dungeon_models.dart';
import 'pixelfx_engine.dart';

/// Art Bible (`craft-game-floors` Art Direction Floor):
/// Style Statement: "16-Bit Game Boy Advance LeafGreen Archipelago RPG: crisp pixel-art
/// tilemaps, chunky dark-slate outlines, era-shifting historical palettes, and luminous
/// `pixelfx` constitutional battle effects."
class SovereignEraPalette {
  final int groundPrimary;
  final int groundSecondary;
  final int wallOrTree;
  final int unrestGrass;
  final int roadTile;
  final int waterOrAccentTile;
  final int bahayRoof; // Terracotta Bahay-Pulungan (PokéCenter)
  final int tribunalRoof; // Tribunal Hall (Gym)
  final int uiAccent;
  final int shadowTone;
  final PixelFxPreset ambientFx;

  const SovereignEraPalette({
    required this.groundPrimary,
    required this.groundSecondary,
    required this.wallOrTree,
    required this.unrestGrass,
    required this.roadTile,
    required this.waterOrAccentTile,
    this.bahayRoof = 0xFFC95B3C,
    required this.tribunalRoof,
    required this.uiAccent,
    required this.shadowTone,
    required this.ambientFx,
  });
}

/// Legal Doctrines (the 4-Move Menu in Turn-Based Debate Battles).
class LegalDoctrineMove {
  final String id;
  final String name;
  final String tagalogSubtitle;
  final String description;
  final int basePower; // Depletes Opponent's Doubt Meter
  final int maxPp;
  final int resolveHeal; // Restores Alon's Civic Resolve (HP)
  final int accentColor;
  final PixelFxPreset fxPreset;

  const LegalDoctrineMove({
    required this.id,
    required this.name,
    required this.tagalogSubtitle,
    required this.description,
    required this.basePower,
    required this.maxPp,
    this.resolveHeal = 0,
    required this.accentColor,
    required this.fxPreset,
  });
}

const List<LegalDoctrineMove> kAlonDoctrineMoves = <LegalDoctrineMove>[
  LegalDoctrineMove(
    id: 'sanduguan',
    name: 'SANDUGUAN PACT',
    tagalogSubtitle: 'Pre-Colonial Customary Consensus',
    description:
        'Invokes inter-barangay blood compact & Council of Elders mediation to dissolve hostility.',
    basePower: 32,
    maxPp: 12,
    resolveHeal: 6,
    accentColor: 0xFFF97316,
    fxPreset: PixelFxPreset.sanduguanFlame,
  ),
  LegalDoctrineMove(
    id: 'checks_balances',
    name: 'CHECKS & BALANCES',
    tagalogSubtitle: 'Separation of Powers Doctrine',
    description:
        'Counterweights executive overreach with co-equal legislative and judicial scrutiny.',
    basePower: 38,
    maxPp: 10,
    resolveHeal: 0,
    accentColor: 0xFF38BDF8,
    fxPreset: PixelFxPreset.checksAndBalancesScales,
  ),
  LegalDoctrineMove(
    id: 'habeas_corpus',
    name: 'HABEAS CORPUS',
    tagalogSubtitle: 'Bill of Rights & Due Process Shield',
    description:
        'Shields citizens from arbitrary detention while restoring Alon\'s Civic Resolve (+18 HP).',
    basePower: 28,
    maxPp: 8,
    resolveHeal: 18,
    accentColor: 0xFF10B981,
    fxPreset: PixelFxPreset.habeasCorpusShield,
  ),
  LegalDoctrineMove(
    id: 'popular_sovereignty',
    name: 'POPULAR SOVEREIGNTY',
    tagalogSubtitle: 'Art. II Sec. 1 • Saligang Batas',
    description:
        'Unleashes the supreme constitutional principle that sovereignty resides in the Filipino people!',
    basePower: 48,
    maxPp: 5,
    resolveHeal: 0,
    accentColor: 0xFFFACC15,
    fxPreset: PixelFxPreset.sovereigntySunburst,
  ),
];

/// Historical Debate Question posed during a Turn-Based Debate Battle.
class DebateChallengeQuestion {
  final String prompt;
  final List<String> choices;
  final int correctIndex;
  final String constitutionalExplanation;
  final String recommendedDoctrineId;

  const DebateChallengeQuestion({
    required this.prompt,
    required this.choices,
    required this.correctIndex,
    required this.constitutionalExplanation,
    this.recommendedDoctrineId = 'checks_balances',
  });
}

/// Opponent in a Turn-Based Debate Battle (Unrest Citizen/Guard, Rival Mateo, or Historical Boss).
class DebateOpponentSpec {
  final String id;
  final String name;
  final String title;
  final String spriteRole; // 'rival', 'datu', 'governor', 'calderon', 'quezon', 'laurel', 'magistrate', 'commissioner', 'guard'
  final int maxDoubt;
  final int attackPower;
  final int primaryColor;
  final String introQuote;
  final String defeatQuote;
  final String argumentAttackName;
  final List<DebateChallengeQuestion> questions;
  final List<String> unlockedSaligangTalaIds;

  const DebateOpponentSpec({
    required this.id,
    required this.name,
    required this.title,
    required this.spriteRole,
    required this.maxDoubt,
    required this.attackPower,
    required this.primaryColor,
    required this.introQuote,
    required this.defeatQuote,
    required this.argumentAttackName,
    required this.questions,
    this.unlockedSaligangTalaIds = const <String>[],
  });
}

/// Interactive NPC or Puzzle Switch on an Act's 16×16 Tilemap Overworld.
class SovereignMapEntity {
  final String id;
  final String name;
  final String role; // 'npc', 'rival', 'boss', 'puzzle_node', 'bahay_historian', 'elite_four'
  final int col;
  final int row;
  final String facing; // 'up', 'down', 'left', 'right'
  final int color;
  final List<String> dialogueLines;
  final String? unlocksSaligangTalaId;
  final DebateOpponentSpec? battleSpec;
  final int? eliteStageIndex; // 1..4 for Act VII Constitutional Commission Gauntlet

  const SovereignMapEntity({
    required this.id,
    required this.name,
    required this.role,
    required this.col,
    required this.row,
    this.facing = 'down',
    required this.color,
    required this.dialogueLines,
    this.unlocksSaligangTalaId,
    this.battleSpec,
    this.eliteStageIndex,
  });
}

/// Entry in the **Saligang Tala** (The Civic Pokédex powered by Umalo the Tarsier).
class SaligangTalaEntry {
  final String id;
  final int actNumber;
  final String numberCode; // e.g. '#001'
  final String title;
  final String category; // 'Branch / Institution' | 'Official Title' | 'Charter / Law'
  final String eraLabel;
  final String summary;
  final String keyPrinciple;

  const SaligangTalaEntry({
    required this.id,
    required this.actNumber,
    required this.numberCode,
    required this.title,
    required this.category,
    required this.eraLabel,
    required this.summary,
    required this.keyPrinciple,
  });
}

/// Complete definition of one of the 7 Historical Acts in **Chronicles of the Sovereign**.
class SovereignActConfig {
  final int actNumber; // 1..7
  final String romanNumeral; // 'ACT I' .. 'ACT VII'
  final String zoneTitle;
  final String eraSubtitle;
  final String yearSpan;
  final String alonAttireName;
  final String alonAttireDescription;
  final int alonHatOrBadgeColor;
  final String charterSealId;
  final String charterSealName;
  final String charterSealIcon;
  final int charterSealColor;
  final String loloAmadoRadioIntro;
  final String tribunalPuzzleHint;
  final String puzzleNodeLabel;
  final SovereignEraPalette palette;
  final List<String> asciiMap; // 20 cols × 14 rows of 16×16 tiles
  final int spawnCol;
  final int spawnRow;
  final List<SovereignMapEntity> entities;
  final DebateOpponentSpec randomUnrestEncounter;

  const SovereignActConfig({
    required this.actNumber,
    required this.romanNumeral,
    required this.zoneTitle,
    required this.eraSubtitle,
    required this.yearSpan,
    required this.alonAttireName,
    required this.alonAttireDescription,
    required this.alonHatOrBadgeColor,
    required this.charterSealId,
    required this.charterSealName,
    required this.charterSealIcon,
    required this.charterSealColor,
    required this.loloAmadoRadioIntro,
    required this.tribunalPuzzleHint,
    required this.puzzleNodeLabel,
    required this.palette,
    required this.asciiMap,
    required this.spawnCol,
    required this.spawnRow,
    required this.entities,
    required this.randomUnrestEncounter,
  });
}

// ═══════════════════════════════════════════════════════════════════════════
//  THE SALIGANG TALA (CIVIC POKÉDEX) — 24 HISTORICAL ENTRIES
// ═══════════════════════════════════════════════════════════════════════════

const List<SaligangTalaEntry> kSaligangTalaCatalog = <SaligangTalaEntry>[
  // Act I: Pre-Colonial Barangay
  SaligangTalaEntry(
    id: 'tala_barangay',
    actNumber: 1,
    numberCode: '#001',
    title: 'Pre-Colonial Barangay',
    category: 'Branch / Institution',
    eraLabel: 'Pre-Colonial (c. 1500)',
    summary:
        'Independent coastal or riverine settlement of 30 to 100 families named after the Balangay boat. No national king ruled the archipelago; each barangay was a sovereign city-state.',
    keyPrinciple: 'Decentralized kinship governance & inter-barangay Sanduguan alliances.',
  ),
  SaligangTalaEntry(
    id: 'tala_datu',
    actNumber: 1,
    numberCode: '#002',
    title: 'Datu (Chieftain)',
    category: 'Official Title',
    eraLabel: 'Pre-Colonial (c. 1500)',
    summary:
        'Chief executive, legislator, and judge of the barangay, advised by the Maginoo (Council of Elders) and Babaylan (spiritual leader).',
    keyPrinciple: 'Fused executive, legislative, and judicial authority tempered by customary law.',
  ),
  SaligangTalaEntry(
    id: 'tala_umalohokan',
    actNumber: 1,
    numberCode: '#003',
    title: 'Umalohokan (Town Crier)',
    category: 'Official Title',
    eraLabel: 'Pre-Colonial (c. 1500)',
    summary:
        'Barangay messenger who walked through the plaza ringing a bell to promulgate new customary laws approved by the Datu and Maginoo.',
    keyPrinciple: 'Public notice and community awareness before a law takes effect.',
  ),

  // Act II: Spanish Centralization
  SaligangTalaEntry(
    id: 'tala_reduccion',
    actNumber: 2,
    numberCode: '#004',
    title: 'Reducción & Plaza Complex',
    category: 'Charter / Law',
    eraLabel: 'Spanish Era (1571–1896)',
    summary:
        'Colonial resettlement policy forcing scattered barangays into centralized pueblos "bajo el son de la campana" (under the sound of the church bell) for taxation and tribute.',
    keyPrinciple: 'Shift from autonomous barangays to centralized colonial administration.',
  ),
  SaligangTalaEntry(
    id: 'tala_cabeza_gobernadorcillo',
    actNumber: 2,
    numberCode: '#005',
    title: 'Cabeza de Barangay & Gobernadorcillo',
    category: 'Official Title',
    eraLabel: 'Spanish Era (1571–1896)',
    summary:
        'Former Datus were co-opted into the Principalía class as Cabezas (barrio tax collectors) and Gobernadorcillos (town mayors), while real local power belonged to the Spanish Parish Priest (Frailocracy).',
    keyPrinciple: 'Co-optation of indigenous elites and union of Church and State.',
  ),
  SaligangTalaEntry(
    id: 'tala_royal_audiencia',
    actNumber: 2,
    numberCode: '#006',
    title: 'Royal Audiencia & Gobernador-Heneral',
    category: 'Branch / Institution',
    eraLabel: 'Spanish Era (1571–1896)',
    summary:
        'The Gobernador-Heneral wielded kingly cumplase power (to suspend royal decrees), while the Royal Audiencia served as the highest colonial tribunal and advisory audit court.',
    keyPrinciple: 'Centralized vice-royal executive authority under the Spanish Crown.',
  ),

  // Act III: Revolutionary & First Republic
  SaligangTalaEntry(
    id: 'tala_katipunan_tejeros',
    actNumber: 3,
    numberCode: '#007',
    title: 'Katipunan & Tejeros Convention',
    category: 'Branch / Institution',
    eraLabel: 'Revolutionary Era (1892–1897)',
    summary:
        'Andres Bonifacio\'s Kataastaasang Sanggunian acted as a revolutionary shadow government until the 1897 Tejeros Convention replaced it with a Revolutionary Government led by Emilio Aguinaldo.',
    keyPrinciple: 'Transition from secret revolutionary society to republican statehood.',
  ),
  SaligangTalaEntry(
    id: 'tala_malolos_1899',
    actNumber: 3,
    numberCode: '#008',
    title: '1899 Malolos Constitution',
    category: 'Charter / Law',
    eraLabel: 'First Philippine Republic (1899)',
    summary:
        'Drafted at Barasoain Church by Felipe Calderón and guided by Apolinario Mabini, establishing the First Philippine Republic—the first democratic constitution in Asia.',
    keyPrinciple: 'Popular sovereignty, Bill of Rights, Separation of Church & State, and a powerful unicameral Assembly of Representatives.',
  ),

  // Act IV: American Insular Rule & 1935 Charter
  SaligangTalaEntry(
    id: 'tala_organic_acts',
    actNumber: 4,
    numberCode: '#009',
    title: 'Philippine Bill of 1902 & Jones Law of 1916',
    category: 'Charter / Law',
    eraLabel: 'American Civil Period (1901–1934)',
    summary:
        'Following the Taft Commission, the 1902 Cooper Act created the elected Philippine Assembly (1907), and the 1916 Jones Law established an all-Filipino bicameral Legislature (Senate & House) with a promise of independence.',
    keyPrinciple: 'Gradual Filipinization of the legislative branch and civil service.',
  ),
  SaligangTalaEntry(
    id: 'tala_1935_constitution',
    actNumber: 4,
    numberCode: '#010',
    title: '1935 Commonwealth Constitution',
    category: 'Charter / Law',
    eraLabel: 'Commonwealth Era (1935–1946)',
    summary:
        'Authorized by the Tydings-McDuffie Act and framed by Claro M. Recto and the "Seven Wise Men" under Pres. Manuel L. Quezon, plus the historic 1937 Women\'s Suffrage Plebiscite.',
    keyPrinciple: 'Three co-equal branches (Presidential system) and universal adult suffrage.',
  ),

  // Act V: Wartime Second Republic
  SaligangTalaEntry(
    id: 'tala_1943_constitution',
    actNumber: 5,
    numberCode: '#011',
    title: '1943 Wartime Constitution (Second Republic)',
    category: 'Charter / Law',
    eraLabel: 'Japanese Occupation (1943–1945)',
    summary:
        'Drafted by the KALIBAPI-appointed PCPI during World War II with Jose P. Laurel as President, concentrating executive survival governance under extreme wartime duress.',
    keyPrinciple: 'De facto wartime administration balancing national survival against foreign occupation.',
  ),

  // Act VI: Post-War Republic to Martial Law
  SaligangTalaEntry(
    id: 'tala_1973_martial_law',
    actNumber: 6,
    numberCode: '#012',
    title: 'Proclamation No. 1081 & 1973 Constitution',
    category: 'Charter / Law',
    eraLabel: 'Martial Law & Fourth Republic (1972–1986)',
    summary:
        'Replaced the 1935 presidential system with a modified parliamentary Batasang Pambansa, while Amendment No. 6 allowed the President to legislate directly by Presidential Decree alongside parliament.',
    keyPrinciple: 'Dangers of unchecked emergency powers, suspension of the writ of habeas corpus, and authoritarian decree-making.',
  ),

  // Act VII: People Power & 1987 Constitution
  SaligangTalaEntry(
    id: 'tala_edsa_concom',
    actNumber: 7,
    numberCode: '#013',
    title: '1986 People Power & Constitutional Commission',
    category: 'Branch / Institution',
    eraLabel: 'Post-EDSA Restoration (1986–1987)',
    summary:
        'Following the peaceful 1986 EDSA People Power Revolution, the 48-member Constitutional Commission presided over by Cecilia Muñoz-Palma drafted the 1987 Constitution, ratified by plebiscite on Feb 2, 1987.',
    keyPrinciple: 'Direct peaceful exercise of people power to restore constitutional democracy.',
  ),
  SaligangTalaEntry(
    id: 'tala_1987_legislative',
    actNumber: 7,
    numberCode: '#014',
    title: 'Article VI: Bicameral Congress & Party-List',
    category: 'Branch / Institution',
    eraLabel: '1987 Constitution (Present)',
    summary:
        'Vests legislative power in a 24-member Senate elected at-large and a House of Representatives (district + 20% Party-List system for marginalized sectors), plus people\'s initiative and referendum.',
    keyPrinciple: 'Bicameral deliberation, power of the purse, and inclusive sectoral representation.',
  ),
  SaligangTalaEntry(
    id: 'tala_1987_executive',
    actNumber: 7,
    numberCode: '#015',
    title: 'Article VII: Executive Term & Martial Law Limits',
    category: 'Branch / Institution',
    eraLabel: '1987 Constitution (Present)',
    summary:
        'Limits the President to a single 6-year term without re-election and subjects any Martial Law proclamation (max 60 days) to mandatory Congressional revocation/extension and Supreme Court review; the Constitution can never be suspended.',
    keyPrinciple: 'Constitutional safeguards against dictatorship and perpetual rule.',
  ),
  SaligangTalaEntry(
    id: 'tala_1987_judicial_commissions',
    actNumber: 7,
    numberCode: '#016',
    title: 'Articles VIII & IX: Judicial Review & Independent Commissions',
    category: 'Branch / Institution',
    eraLabel: '1987 Constitution (Present)',
    summary:
        'Expands Supreme Court judicial review to strike down grave abuse of discretion by any branch, and guarantees fiscal autonomy for COMELEC (Elections), COA (Audit), and CSC (Civil Service), alongside the Bill of Rights (Art. III).',
    keyPrinciple: 'Rule of law, independent accountability bodies, and inviolable human rights.',
  ),
];

// ═══════════════════════════════════════════════════════════════════════════
//  THE SEVEN-ACT STORY CAMPAIGN ("CHRONICLES OF THE SOVEREIGN")
// ═══════════════════════════════════════════════════════════════════════════
//
// Map Legend (20 cols × 14 rows of 16×16 tiles):
//   '.' = Walkable Ground / Grass / Floor
//   '=' = Walkable Road / Plaza Cobblestone / Carpet
//   '#' = Solid Wall / Deep Forest / Cliff
//   '~' = Impassable Water / River / Moat
//   'U' = Unrest Zone (Tall Grass — triggers random civic encounters)
//   'B' = Bahay-Pulungan Roof/Door (PokéCenter — heals Civic Resolve + 4-note chime)
//   'T' = Tribunal Hall Gate/Floor (Gym — requires solving Era Puzzle Nodes first!)

final List<SovereignActConfig> kSovereignActs = <SovereignActConfig>[
  // ─────────────────────────────────────────────────────────────────────────
  //  ACT I: ISLA MAGTANGGOL — THE PRE-COLONIAL BARANGAY (c. 1500)
  // ─────────────────────────────────────────────────────────────────────────
  SovereignActConfig(
    actNumber: 1,
    romanNumeral: 'ACT I',
    zoneTitle: 'Isla Magtanggol',
    eraSubtitle: 'The Pre-Colonial Barangay',
    yearSpan: 'c. 1500 CE',
    alonAttireName: 'Putong of the Tagapag-ingat',
    alonAttireDescription:
        'SHS Vest + Slung Satchel + Woven Crimson Putong Headband',
    alonHatOrBadgeColor: 0xFFEF4444,
    charterSealId: 'seal_1_balangay',
    charterSealName: 'Balangay Seal',
    charterSealIcon: '⛵',
    charterSealColor: 0xFF10B981,
    loloAmadoRadioIntro:
        '📻 *KZZT!* "Alon! Can you hear me through the Astrolabe? You\'ve landed on Isla Magtanggol around 1500 CE! Here there is no national king—each coastal Barangay of 30 to 100 families is an independent state. Follow the Umalohokan\'s bell, help the Babaylan and Maginoo mediate the trade dispute, and earn the Balangay Seal from Datu Lakandula! Are you ready to step into the chronicle?"',
    tribunalPuzzleHint:
        'Mediate the 2 Barangay Trade Compact Stones (🔔) with the Umalohokan & Babaylan before entering Datu Lakandula\'s Longhouse!',
    puzzleNodeLabel: 'Sanduguan Trade Stone',
    palette: const SovereignEraPalette(
      groundPrimary: 0xFF2E7D32,
      groundSecondary: 0xFF388E3C,
      wallOrTree: 0xFF1B5E20,
      unrestGrass: 0xFF66BB6A,
      roadTile: 0xFFD7CCC8,
      waterOrAccentTile: 0xFF0288D1,
      tribunalRoof: 0xFF8D6E63,
      uiAccent: 0xFF10B981,
      shadowTone: 0xFF0D2818,
      ambientFx: PixelFxPreset.ambientCampusMotes,
    ),
    asciiMap: const <String>[
      '~~~~################',
      '~~~##......TTT.....#',
      '~~##..===..===..B..#',
      '~~#...===..===.===.#',
      '~#..UUUU...===.===.#',
      '~#..UUUU...=======.#',
      '#....===...===.....#',
      '#....=========.UUUU#',
      '#....===...===.UUUU#',
      '#..B.===...===.....#',
      '#....===...========#',
      '~~#..===...........#',
      '~~~##=============##',
      '~~~~################',
    ],
    spawnCol: 5,
    spawnRow: 11,
    entities: const <SovereignMapEntity>[
      SovereignMapEntity(
        id: 'act1_bahay',
        name: 'Bahay-Pulungan Keeper Dayang',
        role: 'bahay_historian',
        col: 3,
        row: 9,
        color: 0xFF34D399,
        dialogueLines: <String>[
          'Welcome to the Bahay-Pulungan of Isla Magtanggol, young Tagapag-ingat!',
          '♫ [Four-Note Bamboo Chime] Your Civic Resolve and Legal Doctrines are fully restored!',
          'Remember: In a pre-colonial Barangay, the Datu consults the Maginoo (Council of Elders) before promulgating customary laws through the Umalohokan.',
        ],
        unlocksSaligangTalaId: 'tala_barangay',
      ),
      SovereignMapEntity(
        id: 'act1_umalohokan',
        name: 'Umalohokan (Town Crier)',
        role: 'puzzle_node',
        col: 6,
        row: 6,
        color: 0xFFFACC15,
        dialogueLines: <String>[
          '🔔 *CLANG! CLANG!* Hear ye, families of the coastal Barangay!',
          'You helped ring the bronze bell to announce the customary trade tariff across the plaza! (Puzzle Node 1/2 Activated)',
        ],
        unlocksSaligangTalaId: 'tala_umalohokan',
      ),
      SovereignMapEntity(
        id: 'act1_babaylan',
        name: 'Babaylan & Maginoo Elder',
        role: 'puzzle_node',
        col: 14,
        row: 5,
        color: 0xFFA855F7,
        dialogueLines: <String>[
          'The Council of Elders (Maginoo) and I have prepared the Sanduguan cup between the upland and coastal traders.',
          'By witnessing the blood compact and trial by wisdom, the Chief\'s Longhouse gate is now open! (Puzzle Node 2/2 Activated)',
        ],
        unlocksSaligangTalaId: 'tala_datu',
      ),
      SovereignMapEntity(
        id: 'act1_rival_mateo',
        name: 'Rival Mateo',
        role: 'rival',
        col: 11,
        row: 7,
        facing: 'left',
        color: 0xFFEF4444,
        dialogueLines: <String>[
          '[!] Mateo: "Alon?! So you touched that glowing bookshelf in the school lobby too!"',
          'Mateo: "Look at these scattered barangays—30 to 100 families consulting elders for every little trade law! Order requires one absolute ruler, not consensus!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_mateo_act1',
          name: 'Rival Mateo',
          title: 'Authoritarian Honors Student',
          spriteRole: 'rival',
          maxDoubt: 75,
          attackPower: 14,
          primaryColor: 0xFFEF4444,
          introQuote:
              'Consulting a Council of Elders is a waste of time! Prove to me that pre-colonial governance wasn\'t just chaos!',
          defeatQuote:
              'Tch... So customary laws and Sanduguan alliances actually kept peace without an emperor. Don\'t fall behind in Intramuros!',
          argumentAttackName: 'Iron-Fist Fallacy',
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'How were new laws made and announced in a pre-colonial Philippine barangay?',
              choices: <String>[
                'The Datu proposed laws with the Council of Elders (Maginoo), and the Umalohokan announced them with a bell.',
                'A single Emperor in Manila mailed written decrees to every province.',
                'The Spanish Governor-General enforced the Cumplase.',
                'Laws were voted on by a bicameral Senate and House.',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Customary laws were crafted by the Datu with the Maginoo (Council of Elders) and proclaimed publicly across the village by the Umalohokan.',
              recommendedDoctrineId: 'sanduguan',
            ),
          ],
        ),
      ),
      SovereignMapEntity(
        id: 'act1_boss_lakandula',
        name: 'Datu Lakandula',
        role: 'boss',
        col: 12,
        row: 2,
        facing: 'down',
        color: 0xFF10B981,
        dialogueLines: <String>[
          'Datu Lakandula: "You carry the Astrolabe of Kalayaan, young chronicler, and you have mediated our barangay compact."',
          'Datu Lakandula: "Before I entrust you with the Balangay Seal, show me that you understand how power is held in our shores!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_boss_lakandula',
          name: 'Datu Lakandula',
          title: 'Paramount Chieftain of the Barangay',
          spriteRole: 'datu',
          maxDoubt: 95,
          attackPower: 16,
          primaryColor: 0xFF10B981,
          introQuote:
              'In the Barangay, I lead warriors in battle, craft laws with the Maginoo, and judge disputes. Test your constitutional wisdom against mine!',
          defeatQuote:
              'Well spoken, Tagapag-ingat! Take the Balangay Seal—and remember that leadership begins with kinship and accountability.',
          argumentAttackName: 'Chieftain\'s Edict',
          unlockedSaligangTalaIds: <String>[
            'tala_barangay',
            'tala_datu',
            'tala_umalohokan',
          ],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'Which powers were fused in the person of the pre-colonial Datu?',
              choices: <String>[
                'Executive, Legislative, and Judicial powers within the barangay, advised by the Maginoo',
                'Only ceremonial power with zero authority over disputes',
                'Purely religious authority under the Pope',
                'Federal authority over all 7,000 islands',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'In the pre-colonial barangay, the Datu exercised executive, legislative, and judicial functions, guided by customary law and the Council of Elders (Maginoo).',
              recommendedDoctrineId: 'sanduguan',
            ),
            DebateChallengeQuestion(
              prompt:
                  'What ritual sealed peace treaties and trade alliances between two independent barangays?',
              choices: <String>[
                'Sanduguan (Blood Compact)',
                'Reducción under the church bell',
                'Polo y Servicio forced labor',
                'Royal Audiencia writ',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Sanduguan (blood compact) bound two autonomous barangays in mutual kinship, trade, and defense.',
              recommendedDoctrineId: 'sanduguan',
            ),
          ],
        ),
      ),
    ],
    randomUnrestEncounter: const DebateOpponentSpec(
      id: 'unrest_act1_merchant',
      name: 'Disputing Barangay Trader',
      title: 'Coastal Unrest Encounter',
      spriteRole: 'guard',
      maxDoubt: 55,
      attackPower: 11,
      primaryColor: 0xFFF59E0B,
      introQuote:
          'This river toll wasn\'t announced by the Umalohokan! Why should our boat pay tribute?',
      defeatQuote:
          'Now that the Maginoo and Umalohokan have clarified the customary tariff, we will trade in peace!',
      argumentAttackName: 'Unverified Rumor',
      questions: <DebateChallengeQuestion>[
        DebateChallengeQuestion(
          prompt:
              'What was the typical size and nature of a pre-colonial Philippine barangay?',
          choices: <String>[
            'An independent kinship settlement of 30 to 100 families led by a Datu',
            'A walled European citadel of 50,000 soldiers',
            'A province ruled by a Spanish Alcalde Mayor',
            'A parliamentary district under Amendment No. 6',
          ],
          correctIndex: 0,
          constitutionalExplanation:
              'Each barangay consisted of 30 to 100 families derived from the crew of a balangay boat, operating as an autonomous community.',
          recommendedDoctrineId: 'sanduguan',
        ),
      ],
    ),
  ),

  // ─────────────────────────────────────────────────────────────────────────
  //  ACT II: CIUDAD MURALLA — SPANISH CENTRALIZATION (1571–1896)
  // ─────────────────────────────────────────────────────────────────────────
  SovereignActConfig(
    actNumber: 2,
    romanNumeral: 'ACT II',
    zoneTitle: 'Ciudad Muralla',
    eraSubtitle: 'Spanish Centralization & Intramuros',
    yearSpan: '1571–1896',
    alonAttireName: 'Camisa de Chino & Pañuelo',
    alonAttireDescription:
        'Woven Camisa de Chino over SHS Vest + Astrolabe Pocket Compass',
    alonHatOrBadgeColor: 0xFF38BDF8,
    charterSealId: 'seal_2_real_cedula',
    charterSealName: 'Real Cédula Seal',
    charterSealIcon: '🏰',
    charterSealColor: 0xFF38BDF8,
    loloAmadoRadioIntro:
        '📻 *KZZT!* "Alon, welcome to walled Intramuros! Under Spanish rule, scattered barangays were forced into centralized towns under Reducción—bajo el son de la campana. Former Datus were demoted to tax-collecting Cabezas de Barangay and Gobernadorcillos, while the Parish Priest holds Frailocracy power. Appeal the Royal Audiencia case files to enter the Palacio del Gobernador! Are you ready to step into the chronicle?"',
    tribunalPuzzleHint:
        'Examine the Reducción Bell Registry and file the Appeal Writ at the Royal Audiencia (📜) to unlock the Palacio del Gobernador!',
    puzzleNodeLabel: 'Royal Audiencia Writ',
    palette: const SovereignEraPalette(
      groundPrimary: 0xFF475569,
      groundSecondary: 0xFF64748B,
      wallOrTree: 0xFF1E293B,
      unrestGrass: 0xFF78716C,
      roadTile: 0xFFCBD5E1,
      waterOrAccentTile: 0xFF0369A1,
      tribunalRoof: 0xFF0284C7,
      uiAccent: 0xFF38BDF8,
      shadowTone: 0xFF0F172A,
      ambientFx: PixelFxPreset.torchFlicker,
    ),
    asciiMap: const <String>[
      '####################',
      '#..B...====...TTT..#',
      '#......====...===..#',
      '#.####.====.#####..#',
      '#.#....====.....#..#',
      '#.#.UUUU=======.#..#',
      '#...UUUU===.....#..#',
      '#######.===.#####..#',
      '#.......===........#',
      '#..============....#',
      '#..===......===.UUU#',
      '#..===..B...===.UUU#',
      '#..============....#',
      '####################',
    ],
    spawnCol: 4,
    spawnRow: 12,
    entities: const <SovereignMapEntity>[
      SovereignMapEntity(
        id: 'act2_bahay',
        name: 'Archivist Padre Burgos',
        role: 'bahay_historian',
        col: 8,
        row: 11,
        color: 0xFF38BDF8,
        dialogueLines: <String>[
          'Step inside the Bahay-Pulungan of Intramuros, young scholar.',
          '♫ [Four-Note Sanctuary Chime] Your Civic Resolve is restored!',
          'Notice how Spain centralized the islands: National (Gobernador-Heneral), Provincial (Alcalde Mayor / Corregidor), Municipal (Gobernadorcillo), and Barrio (Cabeza de Barangay).',
        ],
        unlocksSaligangTalaId: 'tala_reduccion',
      ),
      SovereignMapEntity(
        id: 'act2_cabeza',
        name: 'Cabeza de Barangay Don Tiago',
        role: 'puzzle_node',
        col: 4,
        row: 4,
        color: 0xFFFACC15,
        dialogueLines: <String>[
          'Once my ancestors were sovereign Datus... now under Reducción, I am a Cabeza de Barangay forced to collect tribute and assign Polo y Servicio labor.',
          'Take this Municipal Padrón Registry to the Royal Audiencia! (Puzzle Node 1/2 Activated)',
        ],
        unlocksSaligangTalaId: 'tala_cabeza_gobernadorcillo',
      ),
      SovereignMapEntity(
        id: 'act2_audiencia',
        name: 'Magistrate of the Royal Audiencia',
        role: 'puzzle_node',
        col: 15,
        row: 5,
        color: 0xFF38BDF8,
        dialogueLines: <String>[
          'The Royal Audiencia—established in 1583 as the Supreme Court of the colony—accepts your petition against abusive tribute collection.',
          'With this judicial writ, the gates of the Palacio del Gobernador are now open! (Puzzle Node 2/2 Activated)',
        ],
        unlocksSaligangTalaId: 'tala_royal_audiencia',
      ),
      SovereignMapEntity(
        id: 'act2_boss_governor',
        name: 'El Gobernador-Heneral',
        role: 'boss',
        col: 15,
        row: 2,
        facing: 'down',
        color: 0xFF38BDF8,
        dialogueLines: <String>[
          'Gobernador-Heneral: "You dare invoke the Royal Audiencia before the Vice-Patron of the Crown?"',
          'Gobernador-Heneral: "By my Cumplase power, I can suspend even decrees from Madrid! Let us see if your constitutional principles can withstand colonial centralization!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_boss_governor',
          name: 'El Gobernador-Heneral',
          title: 'Representative of the Spanish Crown',
          spriteRole: 'governor',
          maxDoubt: 105,
          attackPower: 18,
          primaryColor: 0xFF38BDF8,
          introQuote:
              'Union of Church and State and the Cumplase keep this colony obedient under the sound of the bell!',
          defeatQuote:
              'Impossible! Your mastery of institutional checks has exposed the abuses of Frailocracy and unchecked executive discretion. Take the Real Cédula Seal!',
          argumentAttackName: 'Royal Cumplase Veto',
          unlockedSaligangTalaIds: <String>[
            'tala_reduccion',
            'tala_cabeza_gobernadorcillo',
            'tala_royal_audiencia',
          ],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'What happened to the pre-colonial Datus under the Spanish colonial hierarchy?',
              choices: <String>[
                'They were absorbed into the Principalía as tax-collecting Cabezas de Barangay and Gobernadorcillos.',
                'They were crowned Emperors of the Royal Audiencia.',
                'They were appointed Spanish Viceroys in Madrid.',
                'They became Senators in a bicameral Congress.',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Spain co-opted indigenous Datus into the lower rungs of colonial administration as Cabezas de Barangay (barrio) and Gobernadorcillos (pueblo).',
              recommendedDoctrineId: 'checks_balances',
            ),
            DebateChallengeQuestion(
              prompt:
                  'What was the "Cumplase" power exercised by the Spanish Gobernador-Heneral?',
              choices: <String>[
                'The power to suspend the implementation of Royal Decrees from Spain if deemed unsuitable to local conditions',
                'The power of Filipino women to vote in local plebiscites',
                'The separation of Church and State in Intramuros',
                'A blood compact between two barangays',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Cumplase ("I obey, but do not execute") allowed the Governor-General to disregard royal decrees, concentrating immense unchecked discretion.',
              recommendedDoctrineId: 'checks_balances',
            ),
          ],
        ),
      ),
    ],
    randomUnrestEncounter: const DebateOpponentSpec(
      id: 'unrest_act2_guardia',
      name: 'Guardia Civil Patrol',
      title: 'Intramuros Plaza Checkpoint',
      spriteRole: 'guard',
      maxDoubt: 60,
      attackPower: 13,
      primaryColor: 0xFF64748B,
      introQuote:
          'Halt! Present your Cédula Personal and explain why you question the Parish Friar\'s town decree!',
      defeatQuote:
          'Your Royal Audiencia citation is in order. You may pass through the plaza!',
      argumentAttackName: 'Frailocracy Inspection',
      questions: <DebateChallengeQuestion>[
        DebateChallengeQuestion(
          prompt:
              'What term describes the immense political and civic power wielded by Spanish friars in colonial towns?',
          choices: <String>[
            'Frailocracy (Rule of the Friars)',
            'Bicameralism',
            'Sanduguan',
            'Judicial Review',
          ],
          correctIndex: 0,
          constitutionalExplanation:
              'Because union of Church and State prevailed, the Spanish parish priest supervised local elections, taxation, education, and censorship—known as Frailocracy.',
          recommendedDoctrineId: 'habeas_corpus',
        ),
      ],
    ),
  ),

  // ─────────────────────────────────────────────────────────────────────────
  //  ACT III: BARASOAIN CROSSING — REVOLUTIONARY & FIRST REPUBLIC (1892–1899)
  // ─────────────────────────────────────────────────────────────────────────
  SovereignActConfig(
    actNumber: 3,
    romanNumeral: 'ACT III',
    zoneTitle: 'Barasoain Crossing',
    eraSubtitle: 'The Revolutionary & First Republic',
    yearSpan: '1892–1899',
    alonAttireName: 'Sash of the Malolos Delegate',
    alonAttireDescription:
        'Crimson-Blue Revolutionary Sash + Astrolabe of Kalayaan',
    alonHatOrBadgeColor: 0xFFF59E0B,
    charterSealId: 'seal_3_malolos_sun',
    charterSealName: 'Malolos Sun Seal',
    charterSealIcon: '☀️',
    charterSealColor: 0xFFFACC15,
    loloAmadoRadioIntro:
        '📻 *KZZT!* "From the torchlit Katipunan basements of Tondo through Tejeros and Biak-na-Bato, you have reached Malolos, Bulacan in 1899! Inside Barasoain Church, Apolinario Mabini and Felipe Calderón are framing Asia\'s first republican constitution. Watch out—Rival Mateo is trying to block the Assembly, claiming wartime requires dictatorship! Defeat Mateo and debate Calderón to earn the Malolos Sun Seal!"',
    tribunalPuzzleHint:
        'Consult Apolinario Mabini and ratify the Separation of Church & State draft (📜) to open the Barasoain Sanctuary!',
    puzzleNodeLabel: 'Malolos Charter Draft',
    palette: const SovereignEraPalette(
      groundPrimary: 0xFF78350F,
      groundSecondary: 0xFF92400E,
      wallOrTree: 0xFF451A03,
      unrestGrass: 0xFFB45309,
      roadTile: 0xFFFDE68A,
      waterOrAccentTile: 0xFFD97706,
      tribunalRoof: 0xFFF59E0B,
      uiAccent: 0xFFFACC15,
      shadowTone: 0xFF271001,
      ambientFx: PixelFxPreset.torchFlicker,
    ),
    asciiMap: const <String>[
      '####################',
      '#.......TTT........#',
      '#..B....===....B...#',
      '#.......===........#',
      '#.UUUU..===..UUUU..#',
      '#.UUUU=======UUUU..#',
      '#.....===.===......#',
      '#...=====.=====....#',
      '#...===.....===....#',
      '#...===========....#',
      '#.......===........#',
      '#.......===........#',
      '#.....=======......#',
      '####################',
    ],
    spawnCol: 9,
    spawnRow: 12,
    entities: const <SovereignMapEntity>[
      SovereignMapEntity(
        id: 'act3_bahay',
        name: 'Bahay-Pulungan Nurse Gregoria',
        role: 'bahay_historian',
        col: 3,
        row: 2,
        color: 0xFFFACC15,
        dialogueLines: <String>[
          'Rest here at the Malolos Bahay-Pulungan, Lakambini\'s chronicler.',
          '♫ [Four-Note Revolutionary Chime] Your Civic Resolve is restored!',
          'From the Katipunan\'s Supreme Council to the 1899 Malolos Congress, Filipinos proved our capacity for self-government.',
        ],
        unlocksSaligangTalaId: 'tala_katipunan_tejeros',
      ),
      SovereignMapEntity(
        id: 'act3_mabini',
        name: 'Apolinario Mabini (Sublime Paralytic)',
        role: 'puzzle_node',
        col: 4,
        row: 8,
        color: 0xFFFACC15,
        dialogueLines: <String>[
          'Apolinario Mabini: "True liberty is only for the virtuous, Alon. Our True Decalogue and Constitutional Program remind us that authority comes from the people."',
          'You organized the Revolutionary Congress credentials with Mabini! (Puzzle Node 1/2 Activated)',
        ],
        unlocksSaligangTalaId: 'tala_malolos_1899',
      ),
      SovereignMapEntity(
        id: 'act3_church_state_node',
        name: 'Delegate Pablo Tecson (Tie-Breaking Vote)',
        role: 'puzzle_node',
        col: 14,
        row: 8,
        color: 0xFF38BDF8,
        dialogueLines: <String>[
          'By a single tie-breaking vote in the Malolos Congress, Article 5—Separation of Church and State—has been ratified!',
          'The Barasoain Tribunal Hall doors now stand open! (Puzzle Node 2/2 Activated)',
        ],
      ),
      SovereignMapEntity(
        id: 'act3_rival_mateo',
        name: 'Rival Mateo',
        role: 'rival',
        col: 9,
        row: 5,
        facing: 'down',
        color: 0xFFEF4444,
        dialogueLines: <String>[
          '[!] Mateo: "Stop right there on the steps of Barasoain, Alon!"',
          'Mateo: "War with America is coming! Why let Felipe Calderón make a unicameral Assembly superior to the President? In a crisis, a legislature only slows down the general!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_mateo_act3',
          name: 'Rival Mateo',
          title: 'Advocate of Unchecked Wartime Rule',
          spriteRole: 'rival',
          maxDoubt: 95,
          attackPower: 17,
          primaryColor: 0xFFEF4444,
          introQuote:
              'A wartime republic has no time for a Congress or a Bill of Rights! Try to refute me!',
          defeatQuote:
              'Urgh! So Calderón intentionally empowered the Assembly of Representatives to prevent a military oligarchy...',
          argumentAttackName: 'Military Decree Strike',
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'Why did Felipe Calderón design a strong unicameral Assembly of Representatives in the 1899 Malolos Constitution?',
              choices: <String>[
                'To check executive/military abuse and ensure the people\'s representatives held supreme legislative authority',
                'To return the Philippines to Spanish Frailocracy',
                'To abolish all elections permanently',
                'To make the Parish Priest head of state',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Calderón feared a military dictatorship if the executive went unchecked, so the Malolos Constitution vested strong legislative oversight in the unicameral Assembly and its Permanent Commission.',
              recommendedDoctrineId: 'checks_balances',
            ),
          ],
        ),
      ),
      SovereignMapEntity(
        id: 'act3_boss_calderon',
        name: 'Felipe Calderón',
        role: 'boss',
        col: 9,
        row: 2,
        facing: 'down',
        color: 0xFFFACC15,
        dialogueLines: <String>[
          'Felipe Calderón: "Welcome to Barasoain Church, keeper of the Saligang Tala."',
          'Felipe Calderón: "Let us debate the pillars of the 1899 Political Constitution of the First Philippine Republic!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_boss_calderon',
          name: 'Felipe Calderón',
          title: 'Principal Author of the 1899 Malolos Charter',
          spriteRole: 'calderon',
          maxDoubt: 115,
          attackPower: 19,
          primaryColor: 0xFFFACC15,
          introQuote:
              'Sovereignty resides exclusively in the people! Show me your command of the First Republic\'s charter!',
          defeatQuote:
              'Magnificent! Asia\'s first democratic republic lives on in your arguments. Receive the Malolos Sun Seal!',
          argumentAttackName: 'Parliamentary Inquiry',
          unlockedSaligangTalaIds: <String>[
            'tala_katipunan_tejeros',
            'tala_malolos_1899',
          ],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'What historic milestone did the 1899 Malolos Constitution achieve?',
              choices: <String>[
                'It established the First Philippine Republic with Asia\'s first democratic constitution, a Bill of Rights, and Separation of Church and State.',
                'It created the 1973 Batasang Pambansa.',
                'It established the American Taft Commission.',
                'It enforced Reducción across Luzon.',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Promulgated on January 21, 1899 in Malolos, Bulacan, it created the First Philippine Republic with a comprehensive Bill of Rights and separation of Church and State.',
              recommendedDoctrineId: 'popular_sovereignty',
            ),
            DebateChallengeQuestion(
              prompt:
                  'What body acted as the legislative organ when the unicameral Malolos Assembly of Representatives was in recess?',
              choices: <String>[
                'The Permanent Commission (Comisión Permanente)',
                'The Royal Audiencia',
                'The Council of Trent',
                'The COMELEC',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'The Malolos Constitution created a 7-member Permanent Commission to watch over executive actions while the Assembly was in recess.',
              recommendedDoctrineId: 'checks_balances',
            ),
          ],
        ),
      ),
    ],
    randomUnrestEncounter: const DebateOpponentSpec(
      id: 'unrest_act3_delegate',
      name: 'Debating Malolos Delegate',
      title: 'Barasoain Plaza Encounter',
      spriteRole: 'guard',
      maxDoubt: 65,
      attackPower: 14,
      primaryColor: 0xFFD97706,
      introQuote:
          'What happened at the 1897 Tejeros Convention and the Pact of Biak-na-Bato? Test your revolutionary memory!',
      defeatQuote:
          'Indeed! History remembers every sacrifice on the road to Barasoain!',
      argumentAttackName: 'Factional Dispute',
      questions: <DebateChallengeQuestion>[
        DebateChallengeQuestion(
          prompt:
              'What significant political change occurred at the Tejeros Convention in March 1897?',
          choices: <String>[
            'The Katipunan was replaced by a Revolutionary Government with Emilio Aguinaldo elected President.',
            'Spain granted immediate independence without a treaty.',
            'The 1935 Commonwealth Constitution was signed.',
            'Women won the right to vote in a national plebiscite.',
          ],
          correctIndex: 0,
          constitutionalExplanation:
              'At Tejeros, Cavite (March 22, 1897), revolutionary leaders established a Revolutionary Government replacing the Katipunan Supreme Council.',
          recommendedDoctrineId: 'popular_sovereignty',
        ),
      ],
    ),
  ),

  // ─────────────────────────────────────────────────────────────────────────
  //  ACT IV: AVENIDA COMMONWEALTH — AMERICAN INSULAR RULE & 1935 CHARTER
  // ─────────────────────────────────────────────────────────────────────────
  SovereignActConfig(
    actNumber: 4,
    romanNumeral: 'ACT IV',
    zoneTitle: 'Avenida Commonwealth',
    eraSubtitle: 'Insular Rule & The 1935 Charter',
    yearSpan: '1901–1941',
    alonAttireName: 'Commonwealth Scholar Tie & Press Pin',
    alonAttireDescription:
        'Neoclassical Manila Scholar Tie + 1937 Suffrage Rosette',
    alonHatOrBadgeColor: 0xFF0EA5E9,
    charterSealId: 'seal_4_commonwealth',
    charterSealName: 'Commonwealth Shield',
    charterSealIcon: '🏛️',
    charterSealColor: 0xFF0EA5E9,
    loloAmadoRadioIntro:
        '📻 *KZZT!* "Welcome to early 20th-century Manila, Alon! Streetcars and public schoolhouses surround the neoclassical Legislative Building. Collect the Organic Acts—the Philippine Bill of 1902 and the Jones Law of 1916—and rally alongside the 1937 Suffragists before debating President Manuel L. Quezon and the Seven Wise Men on the 1935 Constitution!"',
    tribunalPuzzleHint:
        'Gather the Jones Law of 1916 Charter Scroll and the 1937 Women\'s Suffrage Plebiscite Ballot (🗳️) to enter the Legislative Building!',
    puzzleNodeLabel: 'Commonwealth Charter Key',
    palette: const SovereignEraPalette(
      groundPrimary: 0xFF0F766E,
      groundSecondary: 0xFF115E59,
      wallOrTree: 0xFF134E4A,
      unrestGrass: 0xFF2DD4BF,
      roadTile: 0xFFF1F5F9,
      waterOrAccentTile: 0xFF0284C7,
      tribunalRoof: 0xFF0369A1,
      uiAccent: 0xFF38BDF8,
      shadowTone: 0xFF042F2E,
      ambientFx: PixelFxPreset.ambientCampusMotes,
    ),
    asciiMap: const <String>[
      '####################',
      '#..B....TTT.....B..#',
      '#.......===........#',
      '#..=============...#',
      '#..===.......===...#',
      '#..===.UUUUU.===...#',
      '#..===.UUUUU.===...#',
      '#..=============...#',
      '#.......===........#',
      '#.UUUU..===..UUUU..#',
      '#.UUUU..===..UUUU..#',
      '#.......===........#',
      '#.....=======......#',
      '####################',
    ],
    spawnCol: 9,
    spawnRow: 12,
    entities: const <SovereignMapEntity>[
      SovereignMapEntity(
        id: 'act4_bahay',
        name: 'Thomasite & Normal School Historian',
        role: 'bahay_historian',
        col: 3,
        row: 1,
        color: 0xFF38BDF8,
        dialogueLines: <String>[
          'Welcome to the Avenida Commonwealth Bahay-Pulungan!',
          '♫ [Four-Note Neoclassical Chime] Your Civic Resolve is restored!',
          'From the 1901 Spooner Amendment & Taft Commission to the 1934 Tydings-McDuffie Act, Filipino lawmakers steadily reclaimed every branch of government.',
        ],
        unlocksSaligangTalaId: 'tala_organic_acts',
      ),
      SovereignMapEntity(
        id: 'act4_jones_law',
        name: 'Speaker Sergio Osmeña (Organic Acts Archive)',
        role: 'puzzle_node',
        col: 3,
        row: 6,
        color: 0xFFFACC15,
        dialogueLines: <String>[
          'The Philippine Bill of 1902 created the 1907 Philippine Assembly, and the Jones Law of 1916 replaced the American-controlled Philippine Commission with an all-Filipino Senate and House!',
          'You unlocked the Organic Acts Archive Key! (Puzzle Node 1/2 Activated)',
        ],
        unlocksSaligangTalaId: 'tala_organic_acts',
      ),
      SovereignMapEntity(
        id: 'act4_suffragist',
        name: 'Pura Villanueva Kalaw (1937 Suffragist)',
        role: 'puzzle_node',
        col: 15,
        row: 6,
        color: 0xFFEC4899,
        dialogueLines: <String>[
          'In the April 30, 1937 Plebiscite, over 447,725 Filipino women voted YES—exceeding the 300,000 threshold required by the 1935 Constitution to win the right to vote!',
          'With the Suffrage Ballot verified, the Legislative Building doors are open! (Puzzle Node 2/2 Activated)',
        ],
        unlocksSaligangTalaId: 'tala_1935_constitution',
      ),
      SovereignMapEntity(
        id: 'act4_boss_quezon',
        name: 'President Manuel L. Quezon',
        role: 'boss',
        col: 9,
        row: 2,
        facing: 'down',
        color: 0xFF0EA5E9,
        dialogueLines: <String>[
          'Pres. Manuel L. Quezon: "My loyalty to my party ends where my loyalty to my country begins!"',
          'Pres. Manuel L. Quezon: "Together with Claro M. Recto and the Seven Wise Men, we framed the 1935 Constitution. Show me your mastery of the Commonwealth Charter!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_boss_quezon',
          name: 'President Manuel L. Quezon',
          title: 'President of the Philippine Commonwealth',
          spriteRole: 'quezon',
          maxDoubt: 120,
          attackPower: 20,
          primaryColor: 0xFF0EA5E9,
          introQuote:
              'Better a government run like hell by Filipinos than a government run like heaven by Americans! Defend the 1935 Charter!',
          defeatQuote:
              'Bravo, young Tagapag-ingat! You have mastered the three-branch presidential system and social justice clauses. Bear the Commonwealth Shield with pride!',
          argumentAttackName: 'Social Justice Mandate',
          unlockedSaligangTalaIds: <String>[
            'tala_organic_acts',
            'tala_1935_constitution',
          ],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'Which 1916 U.S. law served as the first formal and official American commitment to grant independence to the Philippines as soon as a stable government was established?',
              choices: <String>[
                'The Jones Law (Philippine Autonomy Act of 1916)',
                'The Treaty of Paris of 1898',
                'The Royal Decree of 1583',
                'Proclamation No. 1081',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'The Jones Law of 1916 created a fully elected Filipino bicameral legislature (Senate and House) and declared U.S. intent to recognize Philippine independence.',
              recommendedDoctrineId: 'checks_balances',
            ),
            DebateChallengeQuestion(
              prompt:
                  'How did Filipino women win the right to vote under the 1935 Commonwealth Constitution?',
              choices: <String>[
                'Through the 1937 Women\'s Suffrage Plebiscite where over 447,000 women voted in favor (surpassing the 300,000 constitutional requirement)',
                'By decree of the Spanish Governor-General in 1863',
                'Through the 1897 Pact of Biak-na-Bato',
                'Only after the 1987 Constitution was ratified',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Article V of the 1935 Constitution required at least 300,000 women to vote affirmatively in a plebiscite; on April 30, 1937, 447,725 Filipino women voted YES.',
              recommendedDoctrineId: 'popular_sovereignty',
            ),
          ],
        ),
      ),
    ],
    randomUnrestEncounter: const DebateOpponentSpec(
      id: 'unrest_act4_debater',
      name: 'Insular Civil Service Examiner',
      title: 'Avenida Streetcar Encounter',
      spriteRole: 'guard',
      maxDoubt: 70,
      attackPower: 15,
      primaryColor: 0xFF0284C7,
      introQuote:
          'Before boarding the streetcar to the Legislative Building, can you distinguish the Taft Commission from the Tydings-McDuffie Act?',
      defeatQuote:
          'Spot on! The Tydings-McDuffie Act of 1934 authorized the 10-year Commonwealth transition!',
      argumentAttackName: 'Insular Audit',
      questions: <DebateChallengeQuestion>[
        DebateChallengeQuestion(
          prompt:
              'Which 1934 independence act authorized the drafting of the 1935 Constitution and established a 10-year Philippine Commonwealth transition period?',
          choices: <String>[
            'Tydings-McDuffie Act (Philippine Independence Act of 1934)',
            'Payne-Aldrich Tariff Act',
            'Sedition Law of 1901',
            'Malolos Charter Act',
          ],
          correctIndex: 0,
          constitutionalExplanation:
              'Secured by Manuel L. Quezon in 1934, the Tydings-McDuffie Act provided for a Constitutional Convention (led by Claro M. Recto) and a 10-year Commonwealth leading to July 4, 1946 independence.',
          recommendedDoctrineId: 'checks_balances',
        ),
      ],
    ),
  ),

  // ─────────────────────────────────────────────────────────────────────────
  //  ACT V: FOG OVER MANILA — THE WARTIME SECOND REPUBLIC (1941–1945)
  // ─────────────────────────────────────────────────────────────────────────
  SovereignActConfig(
    actNumber: 5,
    romanNumeral: 'ACT V',
    zoneTitle: 'Fog Over Manila',
    eraSubtitle: 'The Wartime Second Republic',
    yearSpan: '1941–1945',
    alonAttireName: 'Wartime Messenger Cloak',
    alonAttireDescription:
        'Muted Sepia Trench Vest + Hidden Astrolabe Lantern',
    alonHatOrBadgeColor: 0xFFD97706,
    charterSealId: 'seal_5_bamboo_resilience',
    charterSealName: 'Bamboo Resilience Seal',
    charterSealIcon: '🎍',
    charterSealColor: 0xFFD97706,
    loloAmadoRadioIntro:
        '📻 *KZZT!* "Keep your voice low, Alon... The color of Manila has turned to stormy sepia during World War II (1941–1945). Under the 1943 Constitution of the Japanese-sponsored Second Republic, President Jose P. Laurel walks a perilous tightrope—shielding Filipino youth from military conscription while keeping the nation alive. Balance the 2 Survival Governance Seals to enter the Tribunal Hall!"',
    tribunalPuzzleHint:
        'Activate the Food Relief Decree and the Anti-Conscription Shield (🎍) to unlock President Jose P. Laurel\'s Tribunal Hall!',
    puzzleNodeLabel: 'Survival Governance Seal',
    palette: const SovereignEraPalette(
      groundPrimary: 0xFF57534E,
      groundSecondary: 0xFF44403C,
      wallOrTree: 0xFF292524,
      unrestGrass: 0xFF78716C,
      roadTile: 0xFFA8A29E,
      waterOrAccentTile: 0xFF78350F,
      tribunalRoof: 0xFF92400E,
      uiAccent: 0xFFF59E0B,
      shadowTone: 0xFF1C1917,
      ambientFx: PixelFxPreset.unrestZoneRipples,
    ),
    asciiMap: const <String>[
      '####################',
      '#.......TTT........#',
      '#..B....===........#',
      '#.......===........#',
      '#.#####.===.#####..#',
      '#.#.....===.....#..#',
      '#.#.===========.#..#',
      '#...===.....===....#',
      '#.UUUU.......UUUU..#',
      '#.UUUU=======UUUU..#',
      '#.......===........#',
      '#.......===....B...#',
      '#.....=======......#',
      '####################',
    ],
    spawnCol: 9,
    spawnRow: 12,
    entities: const <SovereignMapEntity>[
      SovereignMapEntity(
        id: 'act5_bahay',
        name: 'Underground Historian Lola Rosa',
        role: 'bahay_historian',
        col: 15,
        row: 11,
        color: 0xFFF59E0B,
        dialogueLines: <String>[
          'Come in from the wartime fog, child. You are safe inside this Bahay-Pulungan.',
          '♫ [Four-Note Quiet Chime] Your Civic Resolve is restored!',
          'While President Quezon led the Commonwealth Government-in-Exile in Washington, Jose P. Laurel was instructed to remain in Manila to protect civilians as best he could.',
        ],
        unlocksSaligangTalaId: 'tala_1943_constitution',
      ),
      SovereignMapEntity(
        id: 'act5_relief_node',
        name: 'Civilian Food & Medicine Relief Post',
        role: 'puzzle_node',
        col: 4,
        row: 7,
        color: 0xFF10B981,
        dialogueLines: <String>[
          'You routed emergency rice rations to starving Manila families without surrendering the community roster! (Survival Balance 1/2 Activated)',
        ],
      ),
      SovereignMapEntity(
        id: 'act5_nonconscription_node',
        name: 'Anti-Conscription Legal Shield',
        role: 'puzzle_node',
        col: 14,
        row: 7,
        color: 0xFFFACC15,
        dialogueLines: <String>[
          'You drafted the diplomatic refusal preventing Filipino youth from being conscripted into the Imperial army! (Survival Balance 2/2 Activated)',
          'The Tribunal Hall of the Second Republic is now open!',
        ],
        unlocksSaligangTalaId: 'tala_1943_constitution',
      ),
      SovereignMapEntity(
        id: 'act5_boss_laurel',
        name: 'President Jose P. Laurel',
        role: 'boss',
        col: 9,
        row: 2,
        facing: 'down',
        color: 0xFFD97706,
        dialogueLines: <String>[
          'Pres. Jose P. Laurel: "Like bamboo in a typhoon, a nation under occupation must bend to survive without ever uprooting its soul."',
          'Pres. Jose P. Laurel: "Show me that you understand the legal and historical reality of the 1943 Constitution and the Second Republic!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_boss_laurel',
          name: 'President Jose P. Laurel',
          title: 'President of the Wartime Second Republic',
          spriteRole: 'laurel',
          maxDoubt: 125,
          attackPower: 20,
          primaryColor: 0xFFD97706,
          introQuote:
              'In times of foreign occupation, how do we judge a de facto government versus constitutional sovereignty?',
          defeatQuote:
              'Your judgment is clear and compassionate, Alon. Take the Bamboo Resilience Seal and carry our people\'s story forward!',
          argumentAttackName: 'Doctrine of Necessity',
          unlockedSaligangTalaIds: <String>['tala_1943_constitution'],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'What was the nature of the 1943 Constitution and the Second Philippine Republic under President Jose P. Laurel?',
              choices: <String>[
                'A Japanese-sponsored wartime republic (1943–1945) with a strong executive and unicameral National Assembly operating under occupation duress',
                'The pre-colonial barangay confederation of Madja-as',
                'The 1899 First Republic in Barasoain Church',
                'The 1986 Revolutionary Freedom Constitution',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Drafted by the PCPI and ratified by the KALIBAPI in 1943 during the Japanese occupation, the Second Republic sought to cushion the Filipino populace from harsher military rule.',
              recommendedDoctrineId: 'habeas_corpus',
            ),
          ],
        ),
      ),
    ],
    randomUnrestEncounter: const DebateOpponentSpec(
      id: 'unrest_act5_checkpoint',
      name: 'Wartime Checkpoint Sentry',
      title: 'Blackout Street Encounter',
      spriteRole: 'guard',
      maxDoubt: 75,
      attackPower: 16,
      primaryColor: 0xFF78716C,
      introQuote:
          'Curfew is in effect across Manila! State the constitutional status of the Commonwealth during the war!',
      defeatQuote:
          'Correct—the 1935 Commonwealth continued in exile and was restored upon liberation in 1945!',
      argumentAttackName: 'Curfew Interrogation',
      questions: <DebateChallengeQuestion>[
        DebateChallengeQuestion(
          prompt:
              'Which single political organization was permitted during the Japanese occupation to ratify the 1943 Constitution?',
          choices: <String>[
            'KALIBAPI (Kapisanan sa Paglilingkod sa Bagong Pilipinas)',
            'Katipunan (KKK)',
            'La Liga Filipina',
            'COMELEC',
          ],
          correctIndex: 0,
          constitutionalExplanation:
              'All pre-war political parties were dissolved and replaced by KALIBAPI, which selected the Preparatory Commission for Philippine Independence (PCPI).',
          recommendedDoctrineId: 'popular_sovereignty',
        ),
      ],
    ),
  ),

  // ─────────────────────────────────────────────────────────────────────────
  //  ACT VI: THE CONCRETE CITADEL — POST-WAR TO MARTIAL LAW (1946–1981)
  // ─────────────────────────────────────────────────────────────────────────
  SovereignActConfig(
    actNumber: 6,
    romanNumeral: 'ACT VI',
    zoneTitle: 'The Concrete Citadel',
    eraSubtitle: 'Post-War Republic to Martial Law',
    yearSpan: '1946–1981',
    alonAttireName: 'Campus Press Freedom Armband',
    alonAttireDescription:
        'SHS Vest + Underground Student Press Armband + Astrolabe',
    alonHatOrBadgeColor: 0xFFEF4444,
    charterSealId: 'seal_6_broken_chain',
    charterSealName: 'Broken Chain Seal',
    charterSealIcon: '⛓️',
    charterSealColor: 0xFFEF4444,
    loloAmadoRadioIntro:
        '📻 *KZZT—STATIC!* "Alon! After the 1946 Third Republic flag-raising, the ground shook and radio towers went dark—Proclamation No. 1081 (1972) has locked the curfew gates! Rival Mateo is enforcing the 1973 Constitution and Amendment No. 6, which lets one ruler issue decrees alongside the Batasang Pambansa. Recover the 2 censored Bill of Rights clauses from the printing presses and challenge the Citadel Magistrate!"',
    tribunalPuzzleHint:
        'Recover the 2 Censored Bill of Rights Clauses (📰 Free Press & Writ of Habeas Corpus) to unlock the Concrete Citadel Gate!',
    puzzleNodeLabel: 'Bill of Rights Clause',
    palette: const SovereignEraPalette(
      groundPrimary: 0xFF1E293B,
      groundSecondary: 0xFF0F172A,
      wallOrTree: 0xFF020617,
      unrestGrass: 0xFF334155,
      roadTile: 0xFF64748B,
      waterOrAccentTile: 0xFFDC2626,
      tribunalRoof: 0xFFB91C1C,
      uiAccent: 0xFFEF4444,
      shadowTone: 0xFF020617,
      ambientFx: PixelFxPreset.curfewSearchlight,
    ),
    asciiMap: const <String>[
      '####################',
      '#.......TTT........#',
      '#..B....===....B...#',
      '#.#####.===.#####..#',
      '#.#.....===.....#..#',
      '#.#.UUUU===UUUU.#..#',
      '#...===========....#',
      '###.===.....===.###',
      '#...===.###.===....#',
      '#..====.###.====...#',
      '#..===......===....#',
      '#..============....#',
      '#.......===........#',
      '####################',
    ],
    spawnCol: 9,
    spawnRow: 12,
    entities: const <SovereignMapEntity>[
      SovereignMapEntity(
        id: 'act6_bahay',
        name: 'Campus Editor Ka Noel',
        role: 'bahay_historian',
        col: 3,
        row: 2,
        color: 0xFFEF4444,
        dialogueLines: <String>[
          'Quick, inside the sanctuary! Keep your radio receiver hidden.',
          '♫ [Four-Note Underground Chime] Your Civic Resolve is restored!',
          'Under the 1973 Constitution and Amendment No. 6 (1976), legislative and executive powers were concentrated through Presidential Decrees and Letters of Instruction.',
        ],
        unlocksSaligangTalaId: 'tala_1973_martial_law',
      ),
      SovereignMapEntity(
        id: 'act6_press_clause_1',
        name: 'Hidden Student Printing Press (Freedom of Speech)',
        role: 'puzzle_node',
        col: 3,
        row: 10,
        color: 0xFFFACC15,
        dialogueLines: <String>[
          '📰 You recovered Clause I of the Bill of Rights: "No law shall be passed abridging the freedom of speech, of expression, or of the press!" (Clause 1/2 Recovered)',
        ],
        unlocksSaligangTalaId: 'tala_1973_martial_law',
      ),
      SovereignMapEntity(
        id: 'act6_press_clause_2',
        name: 'Supreme Court Dissent Archive (Writ of Habeas Corpus)',
        role: 'puzzle_node',
        col: 15,
        row: 10,
        color: 0xFF38BDF8,
        dialogueLines: <String>[
          '⚖️ You recovered Clause II of the Bill of Rights: Protection against arbitrary arrest and the constitutional limits on suspending the privilege of the Writ of Habeas Corpus! (Clause 2/2 Recovered)',
          'The Concrete Citadel curfew gate has unlocked!',
        ],
      ),
      SovereignMapEntity(
        id: 'act6_rival_mateo',
        name: 'Rival Mateo',
        role: 'rival',
        col: 9,
        row: 6,
        facing: 'down',
        color: 0xFFEF4444,
        dialogueLines: <String>[
          '[!] Mateo: "Look around you, Alon! Curfew gates are shut, and Amendment No. 6 lets the President legislate by decree whenever the Batasang Pambansa is slow!"',
          'Mateo: "Why bother with slow congressional debates when one leader can issue Presidential Decrees overnight?!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_mateo_act6',
          name: 'Rival Mateo',
          title: 'Enforcer of Amendment No. 6',
          spriteRole: 'rival',
          maxDoubt: 115,
          attackPower: 20,
          primaryColor: 0xFFEF4444,
          introQuote:
              'Amendment No. 6 is the ultimate efficiency! Why should checks and balances stand in the way of decrees?',
          defeatQuote:
              'Wait... Without independent checks, public debt and human rights abuses spiral with zero accountability? Meet me at the Highway of Gold for our final reckoning!',
          argumentAttackName: 'Presidential Decree Barrage',
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'What power did the controversial 1976 Amendment No. 6 to the 1973 Constitution grant the President?',
              choices: <String>[
                'The power to issue decrees, orders, and letters of instruction with the force of law alongside the Batasang Pambansa',
                'The abolition of the presidency in favor of barangay Datus',
                'A strict 4-year term limit with automatic judicial review',
                'Full independence for student newspapers and radio stations',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Amendment No. 6 allowed the President to continue exercising legislative power by decree even after the interim/regular Batasang Pambansa was convened, eroding separation of powers.',
              recommendedDoctrineId: 'checks_balances',
            ),
          ],
        ),
      ),
      SovereignMapEntity(
        id: 'act6_boss_magistrate',
        name: 'Chief Magistrate of the Citadel',
        role: 'boss',
        col: 9,
        row: 2,
        facing: 'down',
        color: 0xFFEF4444,
        dialogueLines: <String>[
          'Chief Magistrate: "Under Proclamation No. 1081 and the Political Question Doctrine, the Citadel claims its emergency powers are beyond judicial review."',
          'Chief Magistrate: "Can your Bill of Rights clauses shatter the Citadel\'s decree?"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_boss_magistrate',
          name: 'Chief Magistrate of the Citadel',
          title: 'Guardian of the 1973 Authoritarian Charter',
          spriteRole: 'magistrate',
          maxDoubt: 130,
          attackPower: 21,
          primaryColor: 0xFFEF4444,
          introQuote:
              'In the 1973 modified parliamentary system, executive and legislative authority converge! Present your defense!',
          defeatQuote:
              'The chains of unchecked emergency rule are broken! Take the Broken Chain Seal and march toward the Highway of Gold!',
          argumentAttackName: 'Curfew Detention Order',
          unlockedSaligangTalaIds: <String>['tala_1973_martial_law'],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'What form of legislature replaced the bicameral Congress under the 1973 Constitution?',
              choices: <String>[
                'A unicameral parliament called the Batasang Pambansa',
                'The Spanish Royal Audiencia',
                'The Malolos Permanent Commission',
                'The Taft Philippine Commission',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'The 1973 Constitution shifted the Philippines on paper to a modified parliamentary system with a unicameral Batasang Pambansa.',
              recommendedDoctrineId: 'habeas_corpus',
            ),
            DebateChallengeQuestion(
              prompt:
                  'Why is the privilege of the Writ of Habeas Corpus vital to citizens\' liberty?',
              choices: <String>[
                'It requires the state to produce a detained person in court and justify the legality of their arrest, preventing warrantless disappearance',
                'It allows the government to collect tribute without a receipt',
                'It grants the Governor-General power to veto Madrid\'s laws',
                'It merges the Senate and the Supreme Court',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'The Writ of Habeas Corpus is the fundamental constitutional safeguard against illegal and arbitrary detention.',
              recommendedDoctrineId: 'habeas_corpus',
            ),
          ],
        ),
      ),
    ],
    randomUnrestEncounter: const DebateOpponentSpec(
      id: 'unrest_act6_censor',
      name: 'Citadel Media Censor',
      title: 'Curfew Broadcast Checkpoint',
      spriteRole: 'guard',
      maxDoubt: 80,
      attackPower: 16,
      primaryColor: 0xFFEF4444,
      introQuote:
          'This radio frequency is closed under Proclamation No. 1081! Hand over your press credentials!',
      defeatQuote:
          'The truth cannot be silenced forever... Pass through to the press archive!',
      argumentAttackName: 'Padlock Order',
      questions: <DebateChallengeQuestion>[
        DebateChallengeQuestion(
          prompt:
              'On what date was Proclamation No. 1081 placing the entire Philippines under Martial Law signed?',
          choices: <String>[
            'September 21, 1972',
            'June 12, 1898',
            'July 4, 1946',
            'February 25, 1986',
          ],
          correctIndex: 0,
          constitutionalExplanation:
              'Proclamation No. 1081 was dated September 21, 1972 (and announced on television on September 23, 1972).',
          recommendedDoctrineId: 'habeas_corpus',
        ),
      ],
    ),
  ),

  // ─────────────────────────────────────────────────────────────────────────
  //  ACT VII: HIGHWAY OF GOLD — PEOPLE POWER & THE 1987 CONSTITUTION
  // ─────────────────────────────────────────────────────────────────────────
  SovereignActConfig(
    actNumber: 7,
    romanNumeral: 'ACT VII',
    zoneTitle: 'Highway of Gold',
    eraSubtitle: 'People Power & The 1987 Constitution',
    yearSpan: '1986–Present',
    alonAttireName: 'EDSA Sovereign Press Badge & Gold Stole',
    alonAttireDescription:
        'SHS Vest + 1986 Yellow Press Badge + Glowing Astrolabe of Kalayaan',
    alonHatOrBadgeColor: 0xFFFACC15,
    charterSealId: 'seal_7_sovereign_sun',
    charterSealName: 'Sovereign Sun Seal',
    charterSealIcon: '🌟',
    charterSealColor: 0xFFFACC15,
    loloAmadoRadioIntro:
        '📻 *KZZT!* "Alon! You have reached the Highway of Gold—February 1986 to the present day! Thousands of peaceful citizens are offering flowers and prayers to stop advancing tanks. Defeat Rival Mateo one final time, receive the blessing of 1986 Constitutional Commission President Cecilia Muñoz-Palma, and conquer the 4-Stage Constitutional Commission Gauntlet (Legislative, Executive, Judicial/Commissions, and The Sovereign Filipino People) to restore the Saligang Tala!"',
    tribunalPuzzleHint:
        'Unite with Cecilia Muñoz-Palma and defeat Rival Mateo on the Highway of Gold to enter the 1987 Constitutional Commission Gauntlet!',
    puzzleNodeLabel: '1986 ConCom Charter Scroll',
    palette: const SovereignEraPalette(
      groundPrimary: 0xFF065F46,
      groundSecondary: 0xFF047857,
      wallOrTree: 0xFF064E3B,
      unrestGrass: 0xFFFBBF24,
      roadTile: 0xFFFEF08A,
      waterOrAccentTile: 0xFF38BDF8,
      tribunalRoof: 0xFFF59E0B,
      uiAccent: 0xFFFACC15,
      shadowTone: 0xFF022C22,
      ambientFx: PixelFxPreset.peoplePowerRibbons,
    ),
    asciiMap: const <String>[
      '####################',
      '#......TTTTT.......#',
      '#..B...=====...B...#',
      '#......=====.......#',
      '#..=============...#',
      '#..===..===..===...#',
      '#..===..===..===...#',
      '#..=============...#',
      '#......=====.......#',
      '#.UUUU.=====.UUUU..#',
      '#.UUUU.=====.UUUU..#',
      '#......=====.......#',
      '#.....=======......#',
      '####################',
    ],
    spawnCol: 9,
    spawnRow: 12,
    entities: const <SovereignMapEntity>[
      SovereignMapEntity(
        id: 'act7_bahay',
        name: 'Bahay-Pulungan Radio Veritas Volunteer',
        role: 'bahay_historian',
        col: 3,
        row: 2,
        color: 0xFFFACC15,
        dialogueLines: <String>[
          'Mabuhay, Ang Tagapag-ingat! Welcome to the Highway of Gold Bahay-Pulungan!',
          '♫ [Four-Note Sovereign Fanfare] Your Civic Resolve and Doctrines are at peak strength!',
          'Ahead lies the 1986 Constitutional Commission Hall—our "Elite Four" constitutional gauntlet!',
        ],
        unlocksSaligangTalaId: 'tala_edsa_concom',
      ),
      SovereignMapEntity(
        id: 'act7_munoz_palma',
        name: 'Justice Cecilia Muñoz-Palma (ConCom President)',
        role: 'puzzle_node',
        col: 4,
        row: 6,
        color: 0xFFFACC15,
        dialogueLines: <String>[
          'Justice Cecilia Muñoz-Palma: "As President of the 1986 Constitutional Commission, we wove the lessons of our history into the 1987 Constitution so tyranny may never rise again."',
          'You received the Official 1987 Draft Scroll! (Puzzle Node 1/2 Activated)',
        ],
        unlocksSaligangTalaId: 'tala_edsa_concom',
      ),
      SovereignMapEntity(
        id: 'act7_edsa_citizens',
        name: 'Peaceful EDSA Citizen Barricade (Flowers & Radios)',
        role: 'puzzle_node',
        col: 14,
        row: 6,
        color: 0xFF34D399,
        dialogueLines: <String>[
          '🌼 Citizens hand you yellow flowers and a transistor radio: "Sovereignty resides in the people and all government authority emanates from them!"',
          'The Constitutional Commission Hall doors are now unlocked! (Puzzle Node 2/2 Activated)',
        ],
      ),
      SovereignMapEntity(
        id: 'act7_rival_mateo_final',
        name: 'Rival Mateo (Final Showdown)',
        role: 'rival',
        col: 9,
        row: 8,
        facing: 'down',
        color: 0xFFEF4444,
        dialogueLines: <String>[
          '[!] Mateo: "Alon... look at this boulevard. Unarmed citizens stopping tanks with flowers, prayers, and radios..."',
          'Mateo: "I spent this whole journey arguing that fear and iron-fisted rule were the only way to govern. Defeat me one last time and prove why constitutional democracy is stronger!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_mateo_act7',
          name: 'Rival Mateo',
          title: 'Final Ideological Reckoning',
          spriteRole: 'rival',
          maxDoubt: 125,
          attackPower: 20,
          primaryColor: 0xFFEF4444,
          introQuote:
              'Show me the core truth of the 1987 Constitution that unites every era we\'ve traveled through!',
          defeatQuote:
              'I finally understand, Alon... True stability doesn\'t come from one ruler\'s fist—it comes from an empowered citizenry, checks and balances, and an inviolable Bill of Rights. Go claim the final Seal!',
          argumentAttackName: 'Authoritarian Doubt',
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'According to Article II, Section 1 of the 1987 Philippine Constitution, where does sovereignty reside?',
              choices: <String>[
                'Sovereignty resides in the people and all government authority emanates from them.',
                'Sovereignty resides in the military and executive decrees.',
                'Sovereignty resides in foreign colonial commissions.',
                'Sovereignty resides exclusively in the Cabinet.',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Article II, Section 1 declares: "The Philippines is a democratic and republican State. Sovereignty resides in the people and all government authority emanates from them."',
              recommendedDoctrineId: 'popular_sovereignty',
            ),
          ],
        ),
      ),

      // ELITE FOUR GAUNTLET STAGE 1: COMMISSIONER ONE (LEGISLATIVE)
      SovereignMapEntity(
        id: 'act7_elite_1_legislative',
        name: 'Commissioner I (Legislative Pillar)',
        role: 'elite_four',
        eliteStageIndex: 1,
        col: 6,
        row: 4,
        facing: 'down',
        color: 0xFF38BDF8,
        dialogueLines: <String>[
          'Commissioner I (Legislative): "Welcome to Pillar I of the 1987 Constitutional Commission Gauntlet: Article VI — The Legislative Department!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_elite_1',
          name: 'Commissioner I (Legislative)',
          title: 'Guardian of Article VI • Bicameral Congress',
          spriteRole: 'commissioner',
          maxDoubt: 110,
          attackPower: 19,
          primaryColor: 0xFF38BDF8,
          introQuote:
              'Test your mastery of the restored bicameral Congress—the Senate, the House of Representatives, and the Party-List System!',
          defeatQuote:
              'Pillar I cleared! You have mastered bicameral checks and sectoral representation. Proceed to Commissioner II (Executive)!',
          argumentAttackName: 'Bicameral Filibuster',
          unlockedSaligangTalaIds: <String>['tala_1987_legislative'],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'How is legislative power structured under Article VI of the 1987 Philippine Constitution?',
              choices: <String>[
                'A bicameral Congress composed of a 24-member Senate elected at-large and a House of Representatives (district + Party-List representatives), plus people\'s initiative and referendum',
                'A unicameral Batasang Pambansa where the President also legislates by decree',
                'A colonial commission appointed by a foreign governor',
                'A council of Cabezas de Barangay without a Senate',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Article VI restored the bicameral Congress (Senate and House of Representatives) and introduced the Party-List system (up to 20% of the House) to give marginalized sectors a voice.',
              recommendedDoctrineId: 'checks_balances',
            ),
          ],
        ),
      ),

      // ELITE FOUR GAUNTLET STAGE 2: COMMISSIONER TWO (EXECUTIVE)
      SovereignMapEntity(
        id: 'act7_elite_2_executive',
        name: 'Commissioner II (Executive Pillar)',
        role: 'elite_four',
        eliteStageIndex: 2,
        col: 12,
        row: 4,
        facing: 'down',
        color: 0xFFF97316,
        dialogueLines: <String>[
          'Commissioner II (Executive): "Welcome to Pillar II: Article VII — The Executive Department and Never-Again Martial Law Safeguards!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_elite_2',
          name: 'Commissioner II (Executive)',
          title: 'Guardian of Article VII • Executive Limits',
          spriteRole: 'commissioner',
          maxDoubt: 120,
          attackPower: 20,
          primaryColor: 0xFFF97316,
          introQuote:
              'Never again shall emergency powers destroy the Constitution! Show me the 1987 safeguards on the Presidency!',
          defeatQuote:
              'Pillar II cleared! You know every constitutional lock against dictatorship. Proceed to Commissioner III (Judicial & Commissions)!',
          argumentAttackName: 'Executive Privilege Test',
          unlockedSaligangTalaIds: <String>['tala_1987_executive'],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'What are the strict limits placed on the President\'s term and Martial Law power under Article VII of the 1987 Constitution?',
              choices: <String>[
                'A single 6-year term with no re-election, a 60-day limit on Martial Law subject to Congressional revocation and Supreme Court review, and the Constitution cannot be suspended',
                'Unlimited 4-year terms and indefinite Martial Law without court review',
                'Automatic dissolution of Congress whenever Martial Law is declared',
                'Suspension of the Bill of Rights and closure of civilian courts',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Article VII, Section 4 limits the President to one 6-year term, and Section 18 subjects any Martial Law proclamation (max 60 days) to both Congressional and Supreme Court review.',
              recommendedDoctrineId: 'checks_balances',
            ),
          ],
        ),
      ),

      // ELITE FOUR GAUNTLET STAGE 3: COMMISSIONER THREE (JUDICIAL & COMMISSIONS)
      SovereignMapEntity(
        id: 'act7_elite_3_judicial',
        name: 'Commissioner III (Judicial & Commissions)',
        role: 'elite_four',
        eliteStageIndex: 3,
        col: 7,
        row: 2,
        facing: 'down',
        color: 0xFF10B981,
        dialogueLines: <String>[
          'Commissioner III: "Welcome to Pillar III: Article VIII (Judicial Power) & Article IX (Independent Constitutional Commissions: COMELEC, COA, CSC)!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_elite_3',
          name: 'Commissioner III (Judicial)',
          title: 'Guardian of Articles VIII & IX',
          spriteRole: 'commissioner',
          maxDoubt: 125,
          attackPower: 21,
          primaryColor: 0xFF10B981,
          introQuote:
              'How does the 1987 Constitution protect the courts and the three independent Constitutional Commissions?',
          defeatQuote:
              'Pillar III cleared! Now step forward to the Altar to face The Final Guardian—The Sovereign Filipino People!',
          argumentAttackName: 'Certiorari Writ',
          unlockedSaligangTalaIds: <String>['tala_1987_judicial_commissions'],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'Which three independent Constitutional Commissions are established under Article IX of the 1987 Constitution?',
              choices: <String>[
                'Civil Service Commission (CSC), Commission on Elections (COMELEC), and Commission on Audit (COA)',
                'Royal Audiencia, Taft Commission, and PCPI',
                'Senate, House of Representatives, and Cabinet',
                'Barangay Council, Sangguniang Kabataan, and KALIBAPI',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Article IX guarantees institutional independence and fiscal autonomy to CSC (merit-based civil service), COMELEC (free and honest elections), and COA (public funds audit).',
              recommendedDoctrineId: 'habeas_corpus',
            ),
          ],
        ),
      ),

      // ELITE FOUR GAUNTLET STAGE 4 (BOSS): THE FINAL GUARDIAN
      SovereignMapEntity(
        id: 'act7_boss_sovereign',
        name: 'The Final Guardian (The Sovereign Filipino People)',
        role: 'boss',
        eliteStageIndex: 4,
        col: 10,
        row: 1,
        facing: 'down',
        color: 0xFFFACC15,
        dialogueLines: <String>[
          '🌟 The Final Guardian: "We are the Sovereign Filipino People—from the rowers of the pre-colonial Balangay to the framers of Barasoain and the citizens of EDSA."',
          '🌟 The Final Guardian: "Unite every lesson across all seven eras to claim the Sovereign Sun Seal and restore the Saligang Tala!"',
        ],
        battleSpec: DebateOpponentSpec(
          id: 'battle_boss_sovereign',
          name: 'The Sovereign Filipino People',
          title: 'Supreme Constitutional Guardian • Art. II Sec. 1',
          spriteRole: 'commissioner',
          maxDoubt: 145,
          attackPower: 22,
          primaryColor: 0xFFFACC15,
          introQuote:
              'From the Barangay of 1500 to the 1987 Bill of Rights—prove that you are worthy of the title Master Historian: Ang Tagapag-ingat!',
          defeatQuote:
              'THE SALIGANG TALA IS WHOLE! All seven Charter Seals shine across time. Step onto the Altar of the Sovereign, Master Historian Alon!',
          argumentAttackName: 'Voice of the Archipelago',
          unlockedSaligangTalaIds: <String>[
            'tala_edsa_concom',
            'tala_1987_legislative',
            'tala_1987_executive',
            'tala_1987_judicial_commissions',
          ],
          questions: <DebateChallengeQuestion>[
            DebateChallengeQuestion(
              prompt:
                  'Trace the evolution of Philippine Constitutions in correct chronological order from 1899 to 1987:',
              choices: <String>[
                '1899 Malolos → 1935 Commonwealth → 1943 Wartime → 1973 Martial Law → 1987 People Power Constitution',
                '1935 Commonwealth → 1899 Malolos → 1987 People Power → 1973 Martial Law',
                '1973 Martial Law → 1943 Wartime → 1899 Malolos → 1935 Commonwealth',
                '1899 Malolos → 1973 Martial Law → 1935 Commonwealth → 1987 Constitution',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'The Philippine constitutional timeline flows from the 1899 Malolos Charter (First Republic), 1935 Commonwealth/Third Republic Charter, 1943 Wartime Charter, 1973 Parliamentary/Martial Law Charter, to the 1987 Constitution.',
              recommendedDoctrineId: 'popular_sovereignty',
            ),
            DebateChallengeQuestion(
              prompt:
                  'Why did the 1987 Constitution expand the definition of Judicial Power (Art. VIII, Sec. 1) beyond simply settling actual controversies?',
              choices: <String>[
                'To empower courts to determine whether there has been a grave abuse of discretion amounting to lack or excess of jurisdiction by any branch of government',
                'To allow judges to pass tax laws without Congress',
                'To restore the Spanish Governor-General\'s Cumplase',
                'To prevent citizens from invoking the Bill of Rights',
              ],
              correctIndex: 0,
              constitutionalExplanation:
                  'Learning from the Martial Law era when courts declined cases as "political questions," the 1987 Constitution explicitly mandated courts to strike down grave abuse of discretion by any branch.',
              recommendedDoctrineId: 'popular_sovereignty',
            ),
          ],
        ),
      ),
    ],
    randomUnrestEncounter: const DebateOpponentSpec(
      id: 'unrest_act7_constitutionalist',
      name: '1987 Plebiscite Campaigner',
      title: 'Highway of Gold Encounter',
      spriteRole: 'guard',
      maxDoubt: 80,
      attackPower: 16,
      primaryColor: 0xFFFACC15,
      introQuote:
          'We are preparing for the February 2, 1987 Constitutional Plebiscite! Let\'s review the Bill of Rights!',
      defeatQuote:
          'Mabuhay! You are ready for the Constitutional Commission Gauntlet!',
      argumentAttackName: 'Plebiscite Quiz',
      questions: <DebateChallengeQuestion>[
        DebateChallengeQuestion(
          prompt:
              'Which Article of the 1987 Philippine Constitution enshrines the Bill of Rights (due process, equal protection, free speech, and freedom from unreasonable searches)?',
          choices: <String>[
            'Article III (Bill of Rights)',
            'Article XIV',
            'Article XVIII',
            'Article I (National Territory)',
          ],
          correctIndex: 0,
          constitutionalExplanation:
              'Article III of the 1987 Constitution is the Bill of Rights, protecting civil and political liberties against state abuse.',
          recommendedDoctrineId: 'habeas_corpus',
        ),
      ],
    ),
  ),
];

/// Persistent save state for a student's **Chronicles of the Sovereign** campaign.
class SovereignCampaignSave {
  final int currentActNumber; // 1..7
  final Set<String> earnedSealIds; // up to 7 Charter Seals
  final Set<String> unlockedSaligangTalaIds; // up to 16+ Saligang Tala entries
  final Set<String> defeatedEntityIds; // Rival Mateo & Bosses defeated
  final Set<String> activatedPuzzleNodeIds; // Tribunal puzzle nodes solved
  final int civicResolveHp;
  final int maxCivicResolveHp;
  final bool completedAltarEnding;
  final DungeonProgressSave dungeonProgress;

  const SovereignCampaignSave({
    this.currentActNumber = 1,
    this.earnedSealIds = const <String>{},
    this.unlockedSaligangTalaIds = const <String>{'tala_barangay'},
    this.defeatedEntityIds = const <String>{},
    this.activatedPuzzleNodeIds = const <String>{},
    this.civicResolveHp = 100,
    this.maxCivicResolveHp = 100,
    this.completedAltarEnding = false,
    this.dungeonProgress = const DungeonProgressSave(),
  });

  SovereignCampaignSave copyWith({
    int? currentActNumber,
    Set<String>? earnedSealIds,
    Set<String>? unlockedSaligangTalaIds,
    Set<String>? defeatedEntityIds,
    Set<String>? activatedPuzzleNodeIds,
    int? civicResolveHp,
    int? maxCivicResolveHp,
    bool? completedAltarEnding,
    DungeonProgressSave? dungeonProgress,
  }) {
    return SovereignCampaignSave(
      currentActNumber: currentActNumber ?? this.currentActNumber,
      earnedSealIds: earnedSealIds ?? this.earnedSealIds,
      unlockedSaligangTalaIds:
          unlockedSaligangTalaIds ?? this.unlockedSaligangTalaIds,
      defeatedEntityIds: defeatedEntityIds ?? this.defeatedEntityIds,
      activatedPuzzleNodeIds:
          activatedPuzzleNodeIds ?? this.activatedPuzzleNodeIds,
      civicResolveHp: civicResolveHp ?? this.civicResolveHp,
      maxCivicResolveHp: maxCivicResolveHp ?? this.maxCivicResolveHp,
      completedAltarEnding: completedAltarEnding ?? this.completedAltarEnding,
      dungeonProgress: dungeonProgress ?? this.dungeonProgress,
    );
  }

  /// Merges this local save with a cloud [other] save by unioning earned seals,
  /// unlocked Saligang Tala entries, defeated entities, solved puzzles, and taking
  /// the furthest act progression so switching devices never regresses Story Mode.
  SovereignCampaignSave mergeWith(SovereignCampaignSave other) {
    final mergedMaxHp = maxCivicResolveHp >= other.maxCivicResolveHp
        ? maxCivicResolveHp
        : other.maxCivicResolveHp;
    final mergedHp = (civicResolveHp >= other.civicResolveHp
            ? civicResolveHp
            : other.civicResolveHp)
        .clamp(1, mergedMaxHp);
    return SovereignCampaignSave(
      currentActNumber: currentActNumber >= other.currentActNumber
          ? currentActNumber
          : other.currentActNumber,
      earnedSealIds: <String>{...earnedSealIds, ...other.earnedSealIds},
      unlockedSaligangTalaIds: <String>{
        ...unlockedSaligangTalaIds,
        ...other.unlockedSaligangTalaIds,
      },
      defeatedEntityIds: <String>{
        ...defeatedEntityIds,
        ...other.defeatedEntityIds,
      },
      activatedPuzzleNodeIds: <String>{
        ...activatedPuzzleNodeIds,
        ...other.activatedPuzzleNodeIds,
      },
      civicResolveHp: mergedHp,
      maxCivicResolveHp: mergedMaxHp,
      completedAltarEnding: completedAltarEnding || other.completedAltarEnding,
      dungeonProgress: dungeonProgress.mergeWith(other.dungeonProgress),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'currentActNumber': currentActNumber,
        'earnedSealIds': earnedSealIds.toList(),
        'unlockedSaligangTalaIds': unlockedSaligangTalaIds.toList(),
        'defeatedEntityIds': defeatedEntityIds.toList(),
        'activatedPuzzleNodeIds': activatedPuzzleNodeIds.toList(),
        'civicResolveHp': civicResolveHp,
        'maxCivicResolveHp': maxCivicResolveHp,
        'completedAltarEnding': completedAltarEnding,
        'dungeonProgress': dungeonProgress.toJson(),
      };

  factory SovereignCampaignSave.fromJson(Map<String, dynamic> json) {
    final rawDungeon = json['dungeonProgress'];
    return SovereignCampaignSave(
      currentActNumber:
          ((json['currentActNumber'] as num?)?.toInt() ?? 1).clamp(1, 7),
      earnedSealIds: (json['earnedSealIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{},
      unlockedSaligangTalaIds: (json['unlockedSaligangTalaIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{'tala_barangay'},
      defeatedEntityIds: (json['defeatedEntityIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{},
      activatedPuzzleNodeIds: (json['activatedPuzzleNodeIds'] as List?)
              ?.map((e) => e.toString())
              .toSet() ??
          const <String>{},
      civicResolveHp:
          ((json['civicResolveHp'] as num?)?.toInt() ?? 100).clamp(1, 200),
      maxCivicResolveHp:
          ((json['maxCivicResolveHp'] as num?)?.toInt() ?? 100).clamp(100, 200),
      completedAltarEnding: json['completedAltarEnding'] == true,
      dungeonProgress: rawDungeon is Map
          ? DungeonProgressSave.fromJson(Map<String, dynamic>.from(rawDungeon))
          : const DungeonProgressSave(),
    );
  }

  static const String _kSaveKeyPrefix = 'sovereign_rpg_save_v1_';

  static Future<SovereignCampaignSave> load(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString('$_kSaveKeyPrefix${userId.trim()}');
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          return SovereignCampaignSave.fromJson(
            Map<String, dynamic>.from(decoded),
          );
        }
      }
    } catch (_) {}
    return const SovereignCampaignSave();
  }

  Future<void> persist(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        '$_kSaveKeyPrefix${userId.trim()}',
        jsonEncode(toJson()),
      );
    } catch (_) {}
  }
}
