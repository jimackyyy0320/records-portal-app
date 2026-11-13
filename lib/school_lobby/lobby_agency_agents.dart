import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'lobby_data_service.dart';
import 'school_lobby_avatar.dart';
import 'school_lobby_config.dart';

/// Activity state in the 60 FPS autonomous behavior state machine inspired by
/// `msitarzewski/agency-agents` & `Parcha-ai/ai-office`.
enum AgencyAgentActivityState {
  walking,
  walkingToSeat,
  inspecting,
  sitting,
  conversingWithPlayer;

  String get statusBadge {
    switch (this) {
      case AgencyAgentActivityState.walking:
        return '🚶 Walking Patrol';
      case AgencyAgentActivityState.walkingToSeat:
        return '🚶 Walking to Seat';
      case AgencyAgentActivityState.inspecting:
        return '🔍 Inspecting Station';
      case AgencyAgentActivityState.sitting:
        return '🪑 Resting at Seat';
      case AgencyAgentActivityState.conversingWithPlayer:
        return '👋 Talking with You';
    }
  }
}

/// A single message in the live conversational thread between the student and an AI Teacher.
class AgencyChatMessage {
  final String sender; // 'teacher' or 'student'
  final String text;
  final int timestampMs;

  const AgencyChatMessage({
    required this.sender,
    required this.text,
    required this.timestampMs,
  });

  bool get isTeacher => sender == 'teacher';
}

/// Structured Agent Persona modeled directly on `msitarzewski/agency-agents`:
/// - `identity`: Role, academic background, and operational identity
/// - `personalityVibe`: Distinct voice, tone, and demeanor
/// - `coreMission`: Domain-specific objectives for PKLP, PPG, or UCSP
/// - `communicationStyle`: How the teacher speaks, coaches, and gives feedback
class AgencyPersonaSpec {
  final String agentId;
  final String name;
  final String subjectCode; // Strictly 'PKLP', 'PPG', or 'UCSP' (or 'CAMPUS' for staff NPCs)
  final String fullSubjectTitle;
  final String roleBadge;
  final String presetName;
  final LobbyRoomId room;
  final int accentColor;
  final String identity;
  final String personalityVibe;
  final String coreMission;
  final String communicationStyle;
  final List<Offset> patrolWaypoints;
  final List<String> stationLabels;
  final Offset? favoriteSeatPos;
  final AvatarFacing favoriteSeatFacing;
  final List<String> walkingThoughts;
  final List<String> proximityGreetings;
  final Map<String, String> topicKnowledgeBase;
  final List<String> examTips;
  final List<String> realLifeExamples;

  const AgencyPersonaSpec({
    required this.agentId,
    required this.name,
    required this.subjectCode,
    required this.fullSubjectTitle,
    required this.roleBadge,
    required this.presetName,
    required this.room,
    required this.accentColor,
    required this.identity,
    required this.personalityVibe,
    required this.coreMission,
    required this.communicationStyle,
    required this.patrolWaypoints,
    required this.stationLabels,
    this.favoriteSeatPos,
    this.favoriteSeatFacing = AvatarFacing.down,
    required this.walkingThoughts,
    required this.proximityGreetings,
    required this.topicKnowledgeBase,
    required this.examTips,
    required this.realLifeExamples,
  });

  bool get isSubjectMentor =>
      subjectCode == 'PKLP' || subjectCode == 'PPG' || subjectCode == 'UCSP';
}

/// Live runtime state of an autonomous walking & talking AI Teacher or Campus NPC.
class AgencyAgentRuntimeState {
  final AgencyPersonaSpec spec;
  Offset currentPos;
  AvatarFacing facing;
  AgencyAgentActivityState activityState;
  PlayerRestState restState;
  int currentWaypointIndex;
  double stateTimerSec;
  double waveTimerSec;
  String activeBubbleText;
  int interactionCount;

  AgencyAgentRuntimeState({
    required this.spec,
    required this.currentPos,
    this.facing = AvatarFacing.down,
    this.activityState = AgencyAgentActivityState.walking,
    this.restState = PlayerRestState.none,
    this.currentWaypointIndex = 0,
    this.stateTimerSec = 0.0,
    this.waveTimerSec = 0.0,
    required this.activeBubbleText,
    this.interactionCount = 0,
  });

  bool get isWalking =>
      (activityState == AgencyAgentActivityState.walking ||
          activityState == AgencyAgentActivityState.walkingToSeat) &&
      !restState.isResting;

  bool get isWaving => waveTimerSec > 0.0;
}

/// Official `msitarzewski/agency-agents` Persona Registry for the 8 AI Subject Teachers
/// (strictly covering the 3 Portal subjects: `PKLP`, `PPG`, and `UCSP`) and 7 Campus Staff NPCs.
const List<AgencyPersonaSpec> kAgencyTeacherPersonas = <AgencyPersonaSpec>[
  // ═══════════════════════════════════════════════════════════════════════════
  // 1. GURO LAKAMBINI — PKLP AI Teacher (Main Lobby West & Commons)
  // ═══════════════════════════════════════════════════════════════════════════
  AgencyPersonaSpec(
    agentId: 'small_chest_1',
    name: 'Guro Lakambini',
    subjectCode: 'PKLP',
    fullSubjectTitle: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino (PKLP)',
    roleBadge: '🤖📜 PKLP AI Teacher',
    presetName: 'Amelia',
    room: LobbyRoomId.mainLobby,
    accentColor: 0xFFF97316,
    identity:
        'Makabayan Historian & Cultural Archivist who connects pre-colonial, colonial, and contemporary Philippine history to everyday student life.',
    personalityVibe:
        'Warm, poetic, makabayan, and deeply encouraging — treats history as a living story rather than dates to memorize.',
    coreMission:
        'Guide learners to analyze historical roots of Filipino society (Polo y Servicio, Reduccion, 1937 Women\'s Suffrage, Neocolonialism, and Social Movements).',
    communicationStyle:
        'Conversational Filipino & English (Taglish) with vivid historical storytelling and reflective Socratic questions.',
    patrolWaypoints: <Offset>[
      Offset(280, 340),
      Offset(440, 340),
      Offset(440, 460),
      Offset(360, 620),
      Offset(280, 460),
    ],
    stationLabels: <String>[
      'Bulletin Board History Archive',
      'Main Hallway Crossroads',
      'West Commons Reading Lounge',
      'Main Lobby Group Study Table',
      'West Corridor Gallery',
    ],
    favoriteSeatPos: Offset(208, 528),
    favoriteSeatFacing: AvatarFacing.down,
    walkingThoughts: <String>[
      '💭 [PKLP] Ang kasaysayan ay hindi lang nakaraan — ito ay gabay sa ating kasalukuyan! 📜',
      '💭 [PKLP] Naalala mo ba kung paano ipinaglaban nina Pura Villanueva Kalaw ang Women\'s Suffrage noong 1937?',
      '💭 [PKLP] Bakit kaya tinawag na "Reduccion" ang pagtitipon ng mga Pilipino sa ilalim ng tunog ng kampana?',
      '💭 Kausapin mo ako habang naglalakad para mag-review sa PKLP (+25 XP)! ✨',
    ],
    proximityGreetings: <String>[
      '👋 Magandang araw! Halika, pag-usapan natin ang Kasaysayan at Lipunang Pilipino (PKLP)!',
      '👋 Kumusta ang pag-aaral mo sa PKLP? May tanong ka ba o handa ka na sa ating Daily Exam Challenge?',
      '👋 Mabuhay! Natutuwa akong makita kang nagre-review dito sa Main Lobby!',
    ],
    topicKnowledgeBase: <String, String>{
      'polo':
          'Sa patakarang **Polo y Servicio** noong panahon ng Espanyol, sapilitang pinagtatrabaho ang mga kalalakihang Pilipino (16–60 taong gulang) sa paggawa ng tulay, simbahan, at barko nang 40 araw bawat taon. Nagdulot ito ng pagkawalay sa pamilya at pagbagsak ng agrikultura.',
      'suffrage':
          'Ang **Kilusang Suffrage noong 1937** na pinangunahan nina **Pura Villanueva Kalaw** at **Concepcion Felix** ay nagtagumpay nang bumoto ang mahigit 447,725 kababaihang Pilipina sa plebisito upang makamit ang karapatang bumoto!',
      'neokolonyalismo':
          'Ang **Neokolonyalismo** ay ang di-tuwirang kontrol ng makapangyarihang bansa sa ekonomiya, kultura (colonial mentality), at politika ng isang malayang bansa sa pamamagitan ng utang panlabas at di-pantay na kasunduan.',
      'repormista':
          'Ang mga **Repormista (Kilusang Propaganda)** tulad nina Rizal, Del Pilar, at Lopez Jaena ay gumamit ng panulat (*La Solidaridad*) para sa mapayapang reporma, samantalang ang **Katipunan (Rebolusyonaryo)** nina Bonifacio ay naglayong makamit ang ganap na kalayaan.',
    },
    examTips: <String>[
      '💡 **PKLP Exam Tip #1**: Kapag "Tama o Mali" sa PKLP, suriin kung ang pahayag ay nagpapakita ng **kritikal na kamalayang panlipunan** (hal. ang kasaysayan ay para sa bayan, hindi lang sa iilan).',
      '💡 **PKLP Exam Tip #2**: Tandaan ang pagkakaiba ng **Kolonyalismo** (tuwirang pananakop) at **Neokolonyalismo** (impluwensiya sa ekonomiya, kultura, at kaisipan matapos ang kalayaan).',
      '💡 **PKLP Exam Tip #3**: Sa mga kilusang panlipunan, laging naiuugnay ang **Kilusang Suffrage (1937)** sa karapatan ng kababaihan sa politika at edukasyon.',
    ],
    realLifeExamples: <String>[
      '🇵🇭 **Real-Life PKLP Connection**: Kapag tinatangkilik natin ang sariling wika, lokal na produkto, at kritikal na pagsusuri ng balita sa social media, nilalabanan natin ang *colonial mentality* at *historical distortion*!',
      '🇵🇭 **Real-Life PKLP Connection**: Tuwing bumoboto ang kababaihan at kabataan sa halalan ngayon, bunga iyan ng mahabang pakikibaka mula sa 1937 Plebiscite hanggang sa kasalukuyan.',
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 2. ATTY. LAUREL — PPG AI Teacher (Main Lobby Center & East)
  // ═══════════════════════════════════════════════════════════════════════════
  AgencyPersonaSpec(
    agentId: 'small_chest_2',
    name: 'Atty. Laurel',
    subjectCode: 'PPG',
    fullSubjectTitle: 'Philippine Politics and Governance (PPG)',
    roleBadge: '🤖⚖️ PPG AI Teacher',
    presetName: 'Adam',
    room: LobbyRoomId.mainLobby,
    accentColor: 0xFFF59E0B,
    identity:
        'Constitutional Law Mentor & Socratic Debate Coach specializing in State Sovereignty, Power Dynamics, and Democratic Institutions.',
    personalityVibe:
        'Sharp, articulate, fair-minded, and inspiring — loves asking Socratic questions that make students think like lawmakers and citizens.',
    coreMission:
        'Master the foundations of Philippine Politics and Governance: Politics (Harold Lasswell), 4 Elements of the State, Forms of Power, and the 3 Branches of Government.',
    communicationStyle:
        'Clear, structured legal-academic English with Filipino civic examples and memorable mnemonics.',
    patrolWaypoints: <Offset>[
      Offset(640, 360),
      Offset(880, 360),
      Offset(880, 520),
      Offset(640, 520),
    ],
    stationLabels: <String>[
      'Central Rotunda North',
      'East Corridor Crossroads',
      'Central Commons Plaza',
      'Main Lobby Lecture Walk',
    ],
    favoriteSeatPos: Offset(496, 528),
    favoriteSeatFacing: AvatarFacing.down,
    walkingThoughts: <String>[
      '💭 [PPG] Harold Lasswell defined Politics as "Who gets what, when, and how." ⚖️',
      '💭 [PPG] Remember the 4 Elements of a State: People, Territory, Government, and Sovereignty!',
      '💭 [PPG] Legitimacy + Authority = Stable Democratic Governance! 🏛️',
      '💭 Walk up to me for a live PPG Socratic chat or your Daily Exam Question (+25 XP)!',
    ],
    proximityGreetings: <String>[
      '👋 Good day, future leader! Ready to discuss Philippine Politics and Governance (PPG)?',
      '👋 Counsel approaches! Would you like a quick PPG concept breakdown or today\'s Exam Challenge?',
      '👋 Welcome! Let us sharpen your constitutional and political analysis skills today.',
    ],
    topicKnowledgeBase: <String, String>{
      'state':
          'A **State** is a political community with **4 essential elements**: (1) **People** (population), (2) **Territory** (aerial, terrestrial, fluvial/maritime domains), (3) **Government** (agency through which the will of the state is formulated), and (4) **Sovereignty** (supreme power to command internally and be independent externally). Meanwhile, a **Nation** is an ethnic/cultural concept bound by shared identity.',
      'power':
          'In PPG (French & Raven\'s Taxonomy of Power): **Coercive Power** relies on fear/punishment; **Reward Power** relies on incentives; **Legitimate Power** comes from an official position/office; **Expert Power** comes from specialized knowledge/skills; and **Referent Power** comes from charisma and respect.',
      'branches':
          'Under the **1987 Philippine Constitution**: (1) **Legislative** (Congress: Senate + House of Representatives) **makes laws**; (2) **Executive** (President, VP, Cabinet) **enforces/executes laws**; (3) **Judicial** (Supreme Court & lower courts) **interprets laws** and settles actual controversies.',
      'governance':
          '**Government** is the formal institution/instrument of the State, whereas **Governance** is the broader process of decision-making and the process by which decisions are implemented (involving state, civil society, and private sector). Key indicators of **Good Governance**: Participation, Rule of Law, Transparency, Responsiveness, Consensus Orientation, Equity, Effectiveness/Efficiency, and Accountability.',
    },
    examTips: <String>[
      '💡 **PPG Exam Tip #1**: Don\'t confuse **State** (political/legal concept with 4 elements including Sovereignty) with **Nation** (cultural/historical concept of shared identity).',
      '💡 **PPG Exam Tip #2**: When a question asks about **"Who gets what, when, and how"**, the answer is always **Harold Lasswell\'s** definition of Politics!',
      '💡 **PPG Exam Tip #3**: If someone obeys a doctor because of medical expertise, that\'s **Expert Power**; if they obey a police officer or judge because of legal office, that\'s **Legitimate Power**.',
    ],
    realLifeExamples: <String>[
      '🇵🇭 **Real-Life PPG Connection**: When Congress passes the national budget (Legislative), the President signs and implements it through departments like DepEd (Executive), and the Supreme Court reviews its constitutionality (Judicial) — that\'s **Separation of Powers & Checks and Balances** in action!',
      '🇵🇭 **Real-Life PPG Connection**: Freedom of Information (FOI) portals and public barangay assemblies are direct examples of **Transparency** and **Participatory Good Governance**.',
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 3. DR. JOCANO — UCSP AI Teacher (Main Lobby East & Reviewer Vault)
  // ═══════════════════════════════════════════════════════════════════════════
  AgencyPersonaSpec(
    agentId: 'small_chest_3',
    name: 'Dr. Jocano',
    subjectCode: 'UCSP',
    fullSubjectTitle: 'Understanding Culture, Society and Politics (UCSP)',
    roleBadge: '🤖🏛️ UCSP AI Teacher',
    presetName: 'Bob',
    room: LobbyRoomId.mainLobby,
    accentColor: 0xFF10B981,
    identity:
        'Field Anthropologist & Sociologist inspired by F. Landa Jocano, studying how Culture, Society, and Politics shape human behavior.',
    personalityVibe:
        'Curious, observant, empathetic, and intellectually playful — helps students see everyday life through an anthropological lens.',
    coreMission:
        'Help students master Anthropology, Sociology, and Political Science, Cultural Relativism vs. Ethnocentrism, Symbols/Norms/Values, and Socialization.',
    communicationStyle:
        'Engaging bilingual social-science mentorship packed with concrete cultural comparisons and easy-to-remember distinctions.',
    patrolWaypoints: <Offset>[
      Offset(1020, 360),
      Offset(1220, 360),
      Offset(1020, 540),
      Offset(980, 740),
      Offset(768, 740),
      Offset(352, 768),
    ],
    stationLabels: <String>[
      'East Academic Gallery',
      'Teacher\'s Corner Approach',
      'Reviewer Vault Entrance',
      'South Study Promenade',
      'South Lobby Atrium',
      'Quiet Reading Approach',
    ],
    favoriteSeatPos: Offset(352, 828),
    favoriteSeatFacing: AvatarFacing.down,
    walkingThoughts: <String>[
      '💭 [UCSP] Cultural Relativism means understanding a culture from its own context, not judging it! 🌍',
      '💭 [UCSP] Anthropology studies culture, Sociology studies society, Political Science studies power! 🏛️',
      '💭 [UCSP] Material culture (artifacts/tools) vs. Non-material culture (beliefs/norms/values)!',
      '💭 Come chat with me about UCSP or take today\'s UCSP Exam Question (+25 XP)! 🎓',
    ],
    proximityGreetings: <String>[
      '👋 Hello, young social scientist! Walking around observing campus culture? Let\'s talk UCSP!',
      '👋 Great to see you! Want to review Cultural Relativism, Norms, and Socialization, or take your UCSP Quiz?',
      '👋 Mabuhay! Every interaction in this lobby is a mini-society in action. Ask me anything about UCSP!',
    ],
    topicKnowledgeBase: <String, String>{
      'relativism':
          '**Cultural Relativism** (Franz Boas) is the principle that a person\'s beliefs and practices should be understood based on that person\'s own culture. By contrast, **Ethnocentrism** (William Graham Sumner) is judging another culture solely by the standards of one\'s own culture (believing one\'s group is superior), while **Xenocentrism** is preferring foreign goods/culture over one\'s own.',
      'disciplines':
          'The 3 pillars of **UCSP**: (1) **Anthropology** — holistic study of humans, evolutionary history, and **Culture** (Cultural, Biological, Linguistic, Archaeology); (2) **Sociology** — scientific study of **Society**, social interactions, institutions, and stratification; (3) **Political Science** — systematic study of **Politics**, state, governance, and power.',
      'culture':
          '**Culture** is "that complex whole which encompasses beliefs, practices, values, attitudes, laws, norms, artifacts, symbols, and knowledge" (E.B. Tylor). It is **learned** (via *Enculturation* / *Socialization*), **shared**, **symbolic**, **dynamic/adaptive**, and **integrated**.',
      'norms':
          'Types of **Social Norms**: (1) **Folkways** — everyday customs/etiquette (e.g., *pagmamano*, dress code) without severe moral punishment; (2) **Mores** — strict moral norms of right and wrong; (3) **Taboos** — deeply forbidden acts; (4) **Laws** — formally codified norms enforced by the State.',
    },
    examTips: <String>[
      '💡 **UCSP Exam Tip #1**: Memorize the trio: **Anthropology = Culture**, **Sociology = Society & Social Interaction**, **Political Science = Power & Government**.',
      '💡 **UCSP Exam Tip #2**: If a statement says *"Our culture\'s way is the only right way"*, that is **Ethnocentrism**. If it says *"Preferring imported products over local ones"*, that is **Xenocentrism**.',
      '💡 **UCSP Exam Tip #3**: Culture is **NOT biologically inherited** — it is **learned** through **Enculturation** and **Socialization**!',
    ],
    realLifeExamples: <String>[
      '🇵🇭 **Real-Life UCSP Connection**: *Pagmamano* and saying *"po" at "opo"* are Filipino **Folkways/Norms** passed down through family **Enculturation**!',
      '🇵🇭 **Real-Life UCSP Connection**: Appreciating indigenous weaves (*Inabel*, *T\'nalak*) within their sacred community meaning rather than treating them as mere fashion is practicing **Cultural Relativism**.',
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 4. PROP. BONIFACIO — PKLP AI Teacher (Campus Park)
  // ═══════════════════════════════════════════════════════════════════════════
  AgencyPersonaSpec(
    agentId: 'small_chest_4',
    name: 'Prop. Bonifacio',
    subjectCode: 'PKLP',
    fullSubjectTitle: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino (PKLP)',
    roleBadge: '🤖📜 PKLP AI Teacher',
    presetName: 'Ash',
    room: LobbyRoomId.park,
    accentColor: 0xFFF97316,
    identity:
        'Social Movements & People\'s History Educator who teaches PKLP along the scenic Campus Park trails.',
    personalityVibe:
        'Passionate, grounded, patriotic, and approachable — loves walking among the park trees while discussing Filipino resilience.',
    coreMission:
        'Connect Philippine historical struggles (Katipunan, Sakdalista, Hukbalahap, Peasant & Labor movements, and Civic Nationalism) to student civic awareness.',
    communicationStyle:
        'Dynamic, inspiring Filipino & English commentary with memorable historical contrasts.',
    patrolWaypoints: <Offset>[
      Offset(560, 390),
      Offset(960, 390),
      Offset(980, 620),
      Offset(560, 620),
    ],
    stationLabels: <String>[
      'North-West Koi Pond Trail',
      'North-East Garden Walk',
      'South-East Park Arbor',
      'Park Outdoor Group Study Circle',
    ],
    favoriteSeatPos: Offset(452, 326),
    favoriteSeatFacing: AvatarFacing.down,
    walkingThoughts: <String>[
      '💭 [PKLP] Ang tunay na pagmamahal sa bayan ay makikita sa malasakit sa kapwa Pilipino! 🌳',
      '💭 [PKLP] Alam mo ba ang kaibahan ng Kilusang Propaganda at Katipunan (KKK)? 📜',
      '💭 [PKLP] Ang kasaysayan mula sa pananaw ng mga karaniwang tao ay tinatawag na "Kasaysayan mula sa Ibaba"!',
      '💭 Halika dito sa Park! Mag-usap tayo tungkol sa PKLP o sagutan ang Daily Exam (+25 XP)!',
    ],
    proximityGreetings: <String>[
      '👋 Mabuhay, mag-aaral! Kay sarap mag-review ng PKLP dito sa sariwang hangin ng Campus Park!',
      '👋 Kumusta! Gusto mo bang pag-usapan ang mga kilusang panlipunan sa PKLP o kumuha ng Exam Question?',
      '👋 Halika! Sabay tayong mag-aral ng Kasaysayan at Lipunang Pilipino!',
    ],
    topicKnowledgeBase: <String, String>{
      'katipunan':
          'Ang **KKK (Kataastaasang Kagalanggalangang Katipunan ng mga Anak ng Bayan)** na itinatag noong Hulyo 7, 1892 nina **Andres Bonifacio**, Teodoro Plata, at Ladislao Diwa ay naglayon ng ganap na kalayaan sa pamamagitan ng pagkakaisa at rebolusyon, gabay ang *Kartilya ng Katipunan* ni Emilio Jacinto.',
      'pantayong':
          'Ang **Pantayong Pananaw** (Dr. Zeus Salazar) ay ang pag-aaral at pagsulat ng kasaysayan ng Pilipinas gamit ang sariling wika at kaisipang Pilipino ("mula sa atin, para sa atin") upang maunawaan ang ating kabihasnan.',
      'lipunan':
          'Sa PKLP, sinusuri natin kung paano hinubog ng **heograpiya**, **kolonyalismo**, at **pakikibaka ng mamamayan** ang estruktura ng lipunang Pilipino mula sa *Barangay* (Datu, Maharlika, Timawa, Alipin) hanggang sa makabagong republika.',
    },
    examTips: <String>[
      '💡 **PKLP Exam Tip**: Tandaan na si **Andres Bonifacio** ang *Ama ng Katipunan (Supremo)* at si **Emilio Jacinto** ang *Utak ng Katipunan* na sumulat ng **Kartilya**.',
      '💡 **PKLP Exam Tip**: Sa pagsusuri ng lipunan, ang pakikibaka ay hindi lamang armadong labanan — kabilang dito ang **panulat, sining, edukasyon, at mapayapang pagkilos**.',
    ],
    realLifeExamples: <String>[
      '🇵🇭 **Real-Life PKLP Connection**: Ang *Bayanihan* sa panahon ng sakuna at community pantries ay patunay na buhay ang diwa ng *pakikipagkapwa* at *damayan* sa lipunang Pilipino!',
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 5. PROF. RANDOLF — UCSP AI Teacher (Campus Park South & East)
  // ═══════════════════════════════════════════════════════════════════════════
  AgencyPersonaSpec(
    agentId: 'small_chest_5',
    name: 'Prof. Randolf',
    subjectCode: 'UCSP',
    fullSubjectTitle: 'Understanding Culture, Society and Politics (UCSP)',
    roleBadge: '🤖🏛️ UCSP AI Teacher',
    presetName: 'Alex',
    room: LobbyRoomId.park,
    accentColor: 0xFF10B981,
    identity:
        'Public Sociologist & Cultural Critic inspired by Randolf David, exploring Socialization, Status/Roles, and Social Groups.',
    personalityVibe:
        'Relaxed, reflective, conversational, and witty — turns a walk in the park into an eye-opening sociology discussion.',
    coreMission:
        'Clarify Socialization vs. Enculturation, Achieved vs. Ascribed Status, Primary vs. Secondary Groups, and Conformity/Deviance.',
    communicationStyle:
        'Warm, relatable mentor who uses school and family examples to explain sociological terms effortlessly.',
    patrolWaypoints: <Offset>[
      Offset(940, 620),
      Offset(580, 620),
      Offset(580, 390),
      Offset(940, 390),
    ],
    stationLabels: <String>[
      'Sunset Garden Walk',
      'West Picnic Study Lawn',
      'North Shade Trees',
      'East Koi Pond Overlook',
    ],
    favoriteSeatPos: Offset(1076, 326),
    favoriteSeatFacing: AvatarFacing.down,
    walkingThoughts: <String>[
      '💭 [UCSP] Ascribed Status is what you\'re born with; Achieved Status is what you earn through effort! 🎓',
      '💭 [UCSP] Family and close barkada are Primary Groups; clubs and corporations are Secondary Groups!',
      '💭 [UCSP] Symbols, Language, Norms, and Values are the building blocks of every Culture! 🌍',
      '💭 Talk to me here in the Park for UCSP study coaching or your Daily Exam (+25 XP)!',
    ],
    proximityGreetings: <String>[
      '👋 Hey there! Enjoying the Campus Park? Let\'s chat about UCSP while we\'re here!',
      '👋 Hello! Do you want a quick review on Social Status, Groups & Culture, or today\'s UCSP Exam Question?',
      '👋 Welcome to the Park Study Circle! Ask me any UCSP question on your mind.',
    ],
    topicKnowledgeBase: <String, String>{
      'status':
          '**Status** is a social position a person holds: **Ascribed Status** is assigned at birth or involuntarily (e.g., sex, royal birth, being a firstborn), while **Achieved Status** is earned through personal effort and choice (e.g., becoming an Honor Student, Lawyer, or Teacher). **Role** is the behavior expected of someone who holds a particular status.',
      'groups':
          '**Primary Group** (Charles Horton Cooley) is a small, intimate, long-lasting group with face-to-face emotional bonds (e.g., **family**, close childhood friends). **Secondary Group** is larger, goal-oriented, and impersonal (e.g., a project committee, university class, or workplace).',
      'socialization':
          '**Socialization** is the lifelong process of learning to become a functioning member of society, whereas **Enculturation** specifically refers to learning the traits, values, and symbols of one\'s own culture. Key **Agents of Socialization**: Family (primary), School, Peer Group, Mass Media/Social Media, and Religion.',
    },
    examTips: <String>[
      '💡 **UCSP Exam Tip**: Remember: **Status** you *occupy*; **Role** you *play*! (e.g., Status = Student; Role = studying and participating in class).',
      '💡 **UCSP Exam Tip**: **Family** is always the **most important primary agent of socialization** in UCSP exams.',
    ],
    realLifeExamples: <String>[
      '🇵🇭 **Real-Life UCSP Connection**: When you study hard in MIS-SHS and earn a badge or high grade, that is an **Achieved Status**!',
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 6. SEN. TAÑADA — PPG AI Teacher (SHS Class Room)
  // ═══════════════════════════════════════════════════════════════════════════
  AgencyPersonaSpec(
    agentId: 'small_chest_6',
    name: 'Sen. Tañada',
    subjectCode: 'PPG',
    fullSubjectTitle: 'Philippine Politics and Governance (PPG)',
    roleBadge: '🤖⚖️ PPG AI Teacher',
    presetName: 'Jenny',
    room: LobbyRoomId.classroom,
    accentColor: 0xFFF59E0B,
    identity:
        'Constitutional Parliamentarian & Classroom PPG Lecturer who patrols the classroom aisles and coaches students right at their desks.',
    personalityVibe:
        'Energetic, principled, structured, and supportive — makes constitutional law and political ideologies crystal clear.',
    coreMission:
        'Coach students on Political Ideologies (Liberalism, Conservatism, Socialism), 3 Branches of Government, Decentralization/Local Government, and Citizenship.',
    communicationStyle:
        'Interactive classroom recitation style with crisp comparisons and instant feedback.',
    patrolWaypoints: <Offset>[
      Offset(768, 260),
      Offset(768, 460),
      Offset(768, 660),
      Offset(768, 820),
      Offset(768, 460),
    ],
    stationLabels: <String>[
      'Classroom Lecture Podium',
      'Row 1 Student Desks Aisle',
      'Row 2 Student Desks Aisle',
      'Row 3 Group Study Table',
      'Center Classroom Carpet',
    ],
    favoriteSeatPos: Offset(314, 868),
    favoriteSeatFacing: AvatarFacing.down,
    walkingThoughts: <String>[
      '💭 [PPG] Legislative makes laws, Executive enforces laws, Judicial interprets laws! ⚖️',
      '💭 [PPG] Liberalism champions individual rights & liberty; Conservatism values tradition & stability!',
      '💭 [PPG] Checks and Balances prevent any single branch of government from abusing power! 🏛️',
      '💭 Raise your hand or tap me in the Classroom for PPG coaching & your Daily Exam (+25 XP)!',
    ],
    proximityGreetings: <String>[
      '👋 Class is in session! Ready for a friendly PPG recitation or study chat?',
      '👋 Good day! Checking your Personal Classroom Table? Ask me anything about PPG!',
      '👋 Welcome to the SHS Classroom! Let\'s ace Philippine Politics and Governance together.',
    ],
    topicKnowledgeBase: <String, String>{
      'ideologies':
          'Major **Political Ideologies** in PPG: (1) **Liberalism** — emphasizes individual liberty, equal rights, consent of the governed, and rule of law; (2) **Conservatism** — values tradition, social order, and organic gradual change; (3) **Socialism** — emphasizes social equality, collective welfare, and public ownership/regulation of key resources; (4) **Anarchism** — rejects all involuntary coercive state hierarchy.',
      'constitution':
          'Under the **1987 Constitution**, **Article II** is the *Declaration of Principles and State Policies* ("The Philippines is a democratic and republican State. Sovereignty resides in the people..."), and **Article III** is the *Bill of Rights* (protecting due process, equal protection, freedom of speech, religion, and assembly).',
      'qualifications':
          'Qualifications for **President of the Philippines** (Art. VII, Sec. 2): (1) Natural-born citizen, (2) Registered voter, (3) Able to read and write, (4) At least **40 years of age** on the day of the election, and (5) Resident of the Philippines for at least **10 years** immediately preceding the election.',
    },
    examTips: <String>[
      '💡 **PPG Exam Tip**: Memorize minimum ages in the 1987 Constitution: **President/VP = 40**, **Senator = 35**, **District/Party-List Representative = 25**!',
      '💡 **PPG Exam Tip**: Whenever an exam question highlights **individual liberty, human rights, and limited government**, choose **Liberalism**.',
    ],
    realLifeExamples: <String>[
      '🇵🇭 **Real-Life PPG Connection**: Your right to express peaceful opinions and join student organizations is directly protected by **Article III (Bill of Rights)** of the 1987 Constitution!',
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 7. GAT MABINI — PKLP AI Teacher (Student Canteen)
  // ═══════════════════════════════════════════════════════════════════════════
  AgencyPersonaSpec(
    agentId: 'small_chest_7',
    name: 'Gat Mabini',
    subjectCode: 'PKLP',
    fullSubjectTitle: 'Pag-aaral ng Kasaysayan at Lipunang Pilipino (PKLP)',
    roleBadge: '🤖📜 PKLP AI Teacher',
    presetName: 'Molly',
    room: LobbyRoomId.canteen,
    accentColor: 0xFFF97316,
    identity:
        'Historical Philosopher & Civic Ethics Mentor inspired by Apolinario Mabini ("Ang Dakilang Lumpo" at "Utak ng Himagsikan").',
    personalityVibe:
        'Thoughtful, calm, wise, and warm — loves having merienda table conversations with students about history and moral citizenship.',
    coreMission:
        'Teach the Malolos Republic, True Decalogue (Ang Tunay na Sampung Utos), American & Japanese occupation lessons, and post-war Filipino society.',
    communicationStyle:
        'Eloquent yet accessible Taglish mentorship that links historical integrity to student life.',
    patrolWaypoints: <Offset>[
      Offset(740, 290),
      Offset(740, 480),
      Offset(740, 720),
      Offset(540, 290),
    ],
    stationLabels: <String>[
      'Canteen North Promenade',
      'Canteen Group Study Tables',
      'South Merienda Stools',
      'Vending & Snack Concourse',
    ],
    favoriteSeatPos: Offset(1180, 860),
    favoriteSeatFacing: AvatarFacing.down,
    walkingThoughts: <String>[
      '💭 [PKLP] "Gamitin mo ang isip at puso para sa kabutihan ng iyong kapwa at bayan." 📜',
      '💭 [PKLP] Alam mo ba kung paano ginamit ng mga Amerikano ang sistema ng edukasyon (Thomasites)?',
      '💭 [PKLP] Ang Malolos Constitution (1899) ang unang demokratikong konstitusyon sa Asya! 🇵🇭',
      '💭 Habang nagmemerienda sa Canteen, mag-chat tayo tungkol sa PKLP (+25 XP)! ☕',
    ],
    proximityGreetings: <String>[
      '👋 Kumusta! Nagmemerienda ka ba? Halika, kwentuhan tayo tungkol sa PKLP!',
      '👋 Magandang araw! May tanong ka ba sa Kasaysayan at Lipunang Pilipino o handa ka na sa Exam Challenge?',
      '👋 Masarap mag-aral ng PKLP habang umiinom ng palamig dito sa Canteen!',
    ],
    topicKnowledgeBase: <String, String>{
      'malolos':
          'Ang **Unang Republika ng Pilipinas (Malolos Republic)** na pinasinayaan noong Enero 23, 1899 sa Barasoain Church, Bulacan ang kauna-unahang republikang konstitusyonal sa Asya. Si **Apolinario Mabini** ang nagsilbing punong tagapayo at punong ministro nito.',
      'thomasites':
          'Noong panahon ng **Kolonyalismong Amerikano**, ipinadala ang mga **Thomasites** (mga gurong Amerikano sakay ng *USS Thomas* noong 1901) upang magturo ng Ingles at pampublikong edukasyon — na nagbukas ng paaralan ngunit nagtanim din ng *colonial mentality* at *benevolent assimilation*.',
      'batas_militar':
          'Sa pag-aaral ng kontemporaryong kasaysayan sa PKLP, mahalagang suriin ang mga aral ng **Batas Militar (Martial Law)**, karapatang pantao, at **1986 People Power** upang mapangalagaan ang demokrasya at katotohanan.',
    },
    examTips: <String>[
      '💡 **PKLP Exam Tip**: Tandaan: Si **Apolinario Mabini** ay ang *Utak ng Himagsikan* (*El Verdadero Decalogo*), habang si **Emilio Jacinto** ay ang *Utak ng Katipunan* (*Kartilya*).',
      '💡 **PKLP Exam Tip**: Ang patakarang **Benevolent Assimilation** ni Pangulong William McKinley ay ginamit ng Amerika upang bigyang-katwiran ang pananakop sa Pilipinas.',
    ],
    realLifeExamples: <String>[
      '🇵🇭 **Real-Life PKLP Connection**: Ang pampublikong sistema ng edukasyon at unibersidad sa Pilipinas ay may malalim na kasaysayan mula pa noong panahon ng Espanyol at Amerikano na patuloy nating pinauunlad para sa bawat kabataang Pilipino.',
    ],
  ),

  // ═══════════════════════════════════════════════════════════════════════════
  // 8. DR. MIRIAM — PPG & UCSP AI Teacher (Faculty Consultation Room)
  // ═══════════════════════════════════════════════════════════════════════════
  AgencyPersonaSpec(
    agentId: 'small_chest_8',
    name: 'Dr. Miriam',
    subjectCode: 'PPG',
    fullSubjectTitle: 'Philippine Politics & Governance (PPG) & UCSP',
    roleBadge: '🤖⚖️ PPG & UCSP AI Teacher',
    presetName: 'Lucy',
    room: LobbyRoomId.facultyRoom,
    accentColor: 0xFFA855F7,
    identity:
        'Constitutional Law & Political Sociology Titan inspired by Sen. Miriam Defensor-Santiago — fearless, brilliant, and devoted to youth excellence.',
    personalityVibe:
        'Witty, razor-sharp, high-energy, and deeply supportive of hardworking students — combines academic rigor with memorable humor.',
    coreMission:
        'Provide advanced consultation across both PPG (Constitutional Law, State, Governance, International Law) and UCSP (Political Institutions, Stratification, Social Change).',
    communicationStyle:
        'Punchy, authoritative, and motivating English/Taglish mentorship that challenges students to aim for academic excellence.',
    patrolWaypoints: <Offset>[
      Offset(540, 480),
      Offset(768, 480),
      Offset(980, 480),
      Offset(980, 680),
      Offset(540, 680),
    ],
    stationLabels: <String>[
      'West Faculty Advisory Desk',
      'Central Faculty Consultation Table',
      'East Faculty Desk',
      'Faculty Group Study Lounge',
      'Faculty Reference Library',
    ],
    favoriteSeatPos: Offset(1180, 760),
    favoriteSeatFacing: AvatarFacing.down,
    walkingThoughts: <String>[
      '💭 [PPG] Sovereignty resides in the people and all government authority emanates from them! ⚡',
      '💭 [UCSP] Social Stratification ranks people by wealth, power, and prestige — education empowers mobility! 🎓',
      '💭 [PPG & UCSP] Excellence is not an act, it is a habit! Come consult with me! ⚖️',
      '💭 Step into the Faculty Room to chat with me or take a PPG/UCSP Exam Question (+25 XP)!',
    ],
    proximityGreetings: <String>[
      '👋 Welcome to the Faculty Consultation Room! Ready to exercise your brain cells in PPG & UCSP?',
      '👋 Speak up, scholar! Do you need constitutional & sociological advice or today\'s Exam Challenge?',
      '👋 Brilliant minds never stop asking questions! Let\'s review PPG and UCSP together.',
    ],
    topicKnowledgeBase: <String, String>{
      'sovereignty':
          '**Sovereignty** has two aspects: (1) **Internal Sovereignty** — the supreme power of the State to command and enforce obedience from all persons and organizations within its territory; and (2) **External Sovereignty (Independence)** — freedom of the State from foreign control or intervention.',
      'stratification':
          'In UCSP, **Social Stratification** is the hierarchical arrangement of individuals into social classes based on **Wealth** (economic), **Power** (political), and **Prestige** (social honor). **Open Systems (Class)** allow **Social Mobility** through education and achievement, whereas **Closed Systems (Caste)** fix status by birth.',
      'authority':
          'Max Weber\'s **3 Types of Legitimate Authority** (bridging PPG & UCSP): (1) **Traditional Authority** — based on long-standing customs/hereditary rule (monarchs, datus); (2) **Charismatic Authority** — based on extraordinary personal heroism or inspiration of a leader; (3) **Rational-Legal (Bureaucratic) Authority** — based on enacted laws, constitution, and formal rules.',
    },
    examTips: <String>[
      '💡 **Dr. Miriam\'s Exam Tip #1**: Memorize Max Weber\'s 3 Authorities: **Traditional** (custom/monarchy), **Charismatic** (personal magnetism), and **Rational-Legal** (constitution/modern elected officials)!',
      '💡 **Dr. Miriam\'s Exam Tip #2**: When asked how a citizen moves up in a class system through education and career, the sociological term is **Upward Vertical Social Mobility**.',
    ],
    realLifeExamples: <String>[
      '🇵🇭 **Real-Life PPG & UCSP Connection**: Elected mayors, senators, and the President exercise **Rational-Legal Authority** because their power comes from the Constitution and the ballot, not hereditary birthright!',
    ],
  ),
];

/// Roaming & Stationed Campus Staff NPCs (Receptionist Aiko, Shopkeeper Mina, DJ Rico, Park Keeper Mang Basyong,
/// Classroom Adviser Ma'am Clara, Canteen Barista Chef Marco, Faculty Head Sir Dante) with autonomous movement!
const List<AgencyPersonaSpec> kAgencyStaffNpcPersonas = <AgencyPersonaSpec>[
  AgencyPersonaSpec(
    agentId: 'npc_receptionist',
    name: 'Aiko (Lobbyist)',
    subjectCode: 'CAMPUS',
    fullSubjectTitle: 'MIS-SHS Campus Reception & Quest Desk',
    roleBadge: 'Quest Desk ✨',
    presetName: 'Lucy',
    room: LobbyRoomId.mainLobby,
    accentColor: 0xFFF59E0B,
    identity: 'Campus Receptionist & Quest Coordinator.',
    personalityVibe: 'Cheerful, welcoming, and helpful.',
    coreMission: 'Guide students to Quest Links, Subject Chests, and AI Teachers.',
    communicationStyle: 'Friendly campus guide.',
    patrolWaypoints: <Offset>[
      Offset(768, 134),
      Offset(716, 134),
      Offset(820, 134),
    ],
    stationLabels: <String>['Quest Counter Center', 'Quest Counter West', 'Quest Counter East'],
    walkingThoughts: <String>[
      '💭 Welcome to MIS-SHS! Talk to our walking AI Teachers for PKLP, PPG & UCSP!',
      '💭 Check the Quest Counter for new Teacher Activity Links (+XP & Badges)! ✨',
    ],
    proximityGreetings: <String>[
      '👋 Welcome to the Main Lobby! Tap the Quest Counter to view your enrolled Activity Links!',
    ],
    topicKnowledgeBase: <String, String>{},
    examTips: <String>[],
    realLifeExamples: <String>[],
  ),
  AgencyPersonaSpec(
    agentId: 'npc_shopkeeper',
    name: 'Mina (Shopkeeper)',
    subjectCode: 'CAMPUS',
    fullSubjectTitle: 'Campus Cosmetics & Classroom Table Decor Shop',
    roleBadge: 'Campus Shop 🛍️',
    presetName: 'Jenny',
    room: LobbyRoomId.mainLobby,
    accentColor: 0xFFF59E0B,
    identity: 'Curator of Student Cosmetics & Classroom Table Space Decor.',
    personalityVibe: 'Stylish, upbeat, and encouraging.',
    coreMission: 'Help students exchange earned XP for outfits, hats, chairs, mini lights, and frames.',
    communicationStyle: 'Warm shopkeeper.',
    patrolWaypoints: <Offset>[
      Offset(932, 136),
      Offset(972, 136),
      Offset(972, 224),
      Offset(900, 224),
      Offset(972, 224),
    ],
    stationLabels: <String>['Shop Counter', 'Table Decor Display', 'Cosmetics Rack'],
    walkingThoughts: <String>[
      '💭 New Classroom Table Decor in stock: Mini Lights 💡, Frames 🖼️, and Ergonomic Chairs 🪑!',
      '💭 Earn XP from PKLP, PPG & UCSP AI Teachers to unlock items in the Campus Shop! 🛍️',
    ],
    proximityGreetings: <String>[
      '👋 Hi there! Want to decorate your Personal Classroom Table or unlock a new outfit with XP?',
    ],
    topicKnowledgeBase: <String, String>{},
    examTips: <String>[],
    realLifeExamples: <String>[],
  ),
  AgencyPersonaSpec(
    agentId: 'npc_radio_dj',
    name: 'DJ Rico (Radio Base)',
    subjectCode: 'CAMPUS',
    fullSubjectTitle: 'MIS-SHS Campus Radio Base (Powered by Radio Garden)',
    roleBadge: 'Radio Garden 📻',
    presetName: 'Alex',
    room: LobbyRoomId.mainLobby,
    accentColor: 0xFF10B981,
    identity: 'Campus Radio DJ spinning Lofi Study Beats, Manila OPM, and Jazz.',
    personalityVibe: 'Cool, musical, and upbeat.',
    coreMission: 'Keep the campus energized with live Radio Garden streams (1h channel lock).',
    communicationStyle: 'Smooth radio host.',
    patrolWaypoints: <Offset>[
      Offset(604, 136),
      Offset(564, 136),
      Offset(564, 224),
      Offset(632, 224),
      Offset(564, 224),
    ],
    stationLabels: <String>['Radio Turntable', 'Speaker Stack West', 'Radio Request Board'],
    walkingThoughts: <String>[
      '💭 🎵 Live on Campus Radio! Tune in to Lofi Study Beats or Manila OPM FM! 📻',
      '💭 Remember: the campus radio station can be changed once every hour!',
    ],
    proximityGreetings: <String>[
      '👋 Yo! Tap the Radio Base to play live study music or switch the campus station! 📻',
    ],
    topicKnowledgeBase: <String, String>{},
    examTips: <String>[],
    realLifeExamples: <String>[],
  ),
  AgencyPersonaSpec(
    agentId: 'npc_park_keeper',
    name: 'Mang Basyong (Park Guide)',
    subjectCode: 'CAMPUS',
    fullSubjectTitle: 'Campus Park & Koi Pond Groundskeeper',
    roleBadge: 'Park Keeper 🌳',
    presetName: 'Bob',
    room: LobbyRoomId.park,
    accentColor: 0xFF10B981,
    identity: 'Caretaker of the Campus Park trees, koi pond, and outdoor study benches.',
    personalityVibe: 'Kind, grandfatherly, and nature-loving.',
    coreMission: 'Keep the park peaceful for students studying PKLP and UCSP.',
    communicationStyle: 'Warm Taglish.',
    patrolWaypoints: <Offset>[
      Offset(768, 288),
      Offset(520, 340),
      Offset(1020, 340),
    ],
    stationLabels: <String>['Koi Pond North', 'West Shade Trees', 'East Flower Garden'],
    walkingThoughts: <String>[
      '💭 Kay ganda ng panahon! Pwede kayong umupo o umidlip sa mga bangko sa Park 🌳',
      '💭 Nandito sina Prop. Bonifacio (PKLP) at Prof. Randolf (UCSP) na naglalakad sa Park!',
    ],
    proximityGreetings: <String>[
      '👋 Magandang araw, anak! Magpahinga o mag-group study kayo dito sa Campus Park!',
    ],
    topicKnowledgeBase: <String, String>{},
    examTips: <String>[],
    realLifeExamples: <String>[],
  ),
  AgencyPersonaSpec(
    agentId: 'npc_classroom_adviser',
    name: "Ma'am Clara (Adviser)",
    subjectCode: 'CAMPUS',
    fullSubjectTitle: 'SHS Homeroom & Classroom Table Coordinator',
    roleBadge: 'Homeroom 🏫',
    presetName: 'Molly',
    room: LobbyRoomId.classroom,
    accentColor: 0xFFF59E0B,
    identity: 'SHS Homeroom Adviser overseeing student desks and classroom recitations.',
    personalityVibe: 'Caring, organized, and proud of her students.',
    coreMission: 'Help students find their Personal Classroom Table and Group Study seats.',
    communicationStyle: 'Supportive homeroom teacher.',
    patrolWaypoints: <Offset>[
      Offset(752, 224),
      Offset(560, 280),
      Offset(960, 280),
    ],
    stationLabels: <String>['Teacher Podium', 'Row 1 West Aisle', 'Row 1 East Aisle'],
    walkingThoughts: <String>[
      '💭 Your Personal Classroom Table is in Row 1 Center-Left (📌 Marked with your name)!',
      '💭 Only you can sit on and decorate your Personal Table — or join classmates at Row 3 Group Study!',
    ],
    proximityGreetings: <String>[
      '👋 Welcome to class! Sit at your Personal Table in Row 1 or talk to Sen. Tañada (PPG)!',
    ],
    topicKnowledgeBase: <String, String>{},
    examTips: <String>[],
    realLifeExamples: <String>[],
  ),
  AgencyPersonaSpec(
    agentId: 'npc_canteen_barista',
    name: 'Chef Marco (Barista)',
    subjectCode: 'CAMPUS',
    fullSubjectTitle: 'SHS Canteen Merienda & Café Bar',
    roleBadge: 'Canteen Café ☕',
    presetName: 'Adam',
    room: LobbyRoomId.canteen,
    accentColor: 0xFFF97316,
    identity: 'Head Barista & Chef of the SHS Student Canteen.',
    personalityVibe: 'Energetic, hospitable, and food-loving.',
    coreMission: 'Keep students fueled with milktea, calamansi coolers, and steamed siomai.',
    communicationStyle: 'Cheerful chef.',
    patrolWaypoints: <Offset>[
      Offset(1080, 220),
      Offset(940, 220),
      Offset(1180, 220),
    ],
    stationLabels: <String>['Espresso Bar', 'Merienda Counter West', 'Pastry Counter East'],
    walkingThoughts: <String>[
      '💭 Fresh Milktea 🧋, Calamansi Cooler 🥤 & Siomai 🥟 ready at the Canteen Vending Bar!',
      '💭 Gat Mabini (PKLP AI Teacher) is walking around the dining tables — say hi!',
    ],
    proximityGreetings: <String>[
      '👋 Order up! Grab a brain-boosting snack and sit with friends at the Canteen Group Study Booths!',
    ],
    topicKnowledgeBase: <String, String>{},
    examTips: <String>[],
    realLifeExamples: <String>[],
  ),
  AgencyPersonaSpec(
    agentId: 'npc_faculty_coordinator',
    name: 'Sir Dante (Head Adviser)',
    subjectCode: 'CAMPUS',
    fullSubjectTitle: 'Faculty Consultation & Academic Records Coordinator',
    roleBadge: 'Faculty Head 🎓',
    presetName: 'Ash',
    room: LobbyRoomId.facultyRoom,
    accentColor: 0xFFA855F7,
    identity: 'Senior Academic Coordinator in the Faculty Room.',
    personalityVibe: 'Dignified, encouraging, and scholarly.',
    coreMission: 'Coordinate academic consultations alongside Dr. Miriam (PPG & UCSP).',
    communicationStyle: 'Mentoring faculty head.',
    patrolWaypoints: <Offset>[
      Offset(752, 268),
      Offset(420, 268),
      Offset(1080, 268),
    ],
    stationLabels: <String>['Central Faculty Desk', 'West Advisory Desk', 'East Advisory Desk'],
    walkingThoughts: <String>[
      '💭 Dr. Miriam is patrolling the Faculty Room for PPG & UCSP consultations!',
      '💭 Feel free to use the Faculty Seminar Lounge on the south-east rug for peer study!',
    ],
    proximityGreetings: <String>[
      '👋 Welcome to the Faculty Room! Consult with Dr. Miriam or review your progress anytime.',
    ],
    topicKnowledgeBase: <String, String>{},
    examTips: <String>[],
    realLifeExamples: <String>[],
  ),
];

/// Singleton service managing the autonomous 60 FPS locomotion, proximity eye-contact,
/// resting cycles, and `msitarzewski/agency-agents` conversational intelligence for
/// all 8 AI Subject Teachers (`PKLP`, `PPG`, `UCSP`) and 7 Campus Staff NPCs.
class LobbyAgencyAgentsService extends ChangeNotifier {
  LobbyAgencyAgentsService._() {
    _initRuntimeStates();
  }

  static final LobbyAgencyAgentsService instance = LobbyAgencyAgentsService._();

  final Map<String, AgencyAgentRuntimeState> _states =
      <String, AgencyAgentRuntimeState>{};
  final Map<String, List<AgencyChatMessage>> _chatHistories =
      <String, List<AgencyChatMessage>>{};

  void _initRuntimeStates() {
    _states.clear();
    var idx = 0;
    for (final spec in [...kAgencyTeacherPersonas, ...kAgencyStaffNpcPersonas]) {
      final startPos = spec.patrolWaypoints.isNotEmpty
          ? spec.patrolWaypoints.first
          : const Offset(768, 420);
      final startThought = spec.walkingThoughts.isNotEmpty
          ? spec.walkingThoughts.first
          : '💭 Ready to help you study!';
      _states[spec.agentId] = AgencyAgentRuntimeState(
        spec: spec,
        currentPos: startPos,
        facing: AvatarFacing.down,
        activityState: AgencyAgentActivityState.walking,
        restState: PlayerRestState.none,
        currentWaypointIndex: spec.patrolWaypoints.length > 1 ? 1 : 0,
        // Stagger initial timers so agents don't all pause at the exact same instant
        stateTimerSec: 2.0 + (idx % 4) * 1.3,
        activeBubbleText: startThought,
      );
      idx++;
    }
  }

  /// Resets all agent positions and states for deterministic unit testing.
  @visibleForTesting
  void resetForTesting() {
    _initRuntimeStates();
    _chatHistories.clear();
  }

  AgencyPersonaSpec? personaForId(String agentId) => _states[agentId]?.spec;

  AgencyAgentRuntimeState? runtimeStateForId(String agentId) =>
      _states[agentId];

  /// Returns all AI Subject Teacher runtime states (`PKLP`, `PPG`, `UCSP`) in [room].
  List<AgencyAgentRuntimeState> teacherStatesForRoom(LobbyRoomId room) {
    return kAgencyTeacherPersonas
        .where((p) => p.room == room)
        .map((p) => _states[p.agentId]!)
        .toList();
  }

  /// Returns all AI Subject Teacher runtime states across all 5 rooms.
  List<AgencyAgentRuntimeState> get allTeacherStates =>
      kAgencyTeacherPersonas.map((p) => _states[p.agentId]!).toList();

  /// Returns all Campus Staff NPC runtime states in [room].
  List<AgencyAgentRuntimeState> staffNpcStatesForRoom(LobbyRoomId room) {
    return kAgencyStaffNpcPersonas
        .where((p) => p.room == room)
        .map((p) => _states[p.agentId]!)
        .toList();
  }

  /// Advances the 60 FPS autonomous behavior state machine for all AI Teachers and NPCs in [room]:
  /// - `walking`: Walks smoothly (`74 px/s` for AI Teachers, `52 px/s` for Staff NPCs) toward the next waypoint.
  /// - `walkingToSeat`: Walks naturally to `favoriteSeatPos` before sitting (no teleportation).
  /// - `inspecting`: Pauses naturally at a station (`3.2s`) and rotates through contextual study thoughts.
  /// - `sitting`: Occasionally sits down at `favoriteSeatPos` (`PlayerRestState.sitting`) using the 2-slice seated pixel posture.
  /// - `conversingWithPlayer`: When the student approaches within engage radius, the AI Teacher stops walking,
  ///   stands up if seated, turns to face the student (`AvatarFacing`), waves (`👋`), and greets them.
  ///
  /// Returns `true` if any visible agent state (position, facing, activity, rest pose, bubble, or wave) changed.
  bool tick(
    double dt, {
    required LobbyRoomId room,
    required Offset playerPos,
  }) {
    final safeDt = dt.clamp(0.0, 0.25);
    if (safeDt <= 0.0) return false;
    var anyChanged = false;

    for (final state in _states.values) {
      if (state.spec.room != room) continue;

      final prevPos = state.currentPos;
      final prevFacing = state.facing;
      final prevActivity = state.activityState;
      final prevRest = state.restState;
      final prevBubble = state.activeBubbleText;
      final prevWaving = state.isWaving;

      if (state.waveTimerSec > 0.0) {
        state.waveTimerSec = math.max(0.0, state.waveTimerSec - safeDt);
      }

      final distToPlayer = (playerPos - state.currentPos).distance;
      final engageRadius = state.spec.isSubjectMentor ? 115.0 : 92.0;

      // 1. Proximity Awareness & Eye Contact: stop and face the player when nearby!
      if (distToPlayer <= engageRadius) {
        if (state.activityState !=
            AgencyAgentActivityState.conversingWithPlayer) {
          state.activityState = AgencyAgentActivityState.conversingWithPlayer;
          state.restState = PlayerRestState.none;
          state.waveTimerSec = 2.6;
          if (state.spec.proximityGreetings.isNotEmpty) {
            final gIdx =
                state.interactionCount % state.spec.proximityGreetings.length;
            state.activeBubbleText = state.spec.proximityGreetings[gIdx];
            state.interactionCount++;
          }
        }
        state.facing =
            _facingFromDelta(playerPos - state.currentPos, state.facing);
      } else {
        // If player walked away after conversing, resume walking patrol!
        if (state.activityState ==
            AgencyAgentActivityState.conversingWithPlayer) {
          state.activityState = AgencyAgentActivityState.walking;
          state.restState = PlayerRestState.none;
          if (state.spec.walkingThoughts.isNotEmpty) {
            state.activeBubbleText = state.spec.walkingThoughts[
                state.currentWaypointIndex %
                    state.spec.walkingThoughts.length];
          }
        }

        // 2. Handle Sitting / Inspecting timers
        if (state.activityState == AgencyAgentActivityState.inspecting ||
            state.activityState == AgencyAgentActivityState.sitting) {
          state.stateTimerSec -= safeDt;
          if (state.stateTimerSec <= 0.0) {
            state.activityState = AgencyAgentActivityState.walking;
            state.restState = PlayerRestState.none;
            if (state.spec.patrolWaypoints.isNotEmpty) {
              state.currentWaypointIndex =
                  (state.currentWaypointIndex + 1) %
                      state.spec.patrolWaypoints.length;
            }
            if (state.spec.walkingThoughts.isNotEmpty) {
              state.activeBubbleText = state.spec.walkingThoughts[
                  state.currentWaypointIndex %
                      state.spec.walkingThoughts.length];
            }
          }
        } else if (state.activityState ==
            AgencyAgentActivityState.walkingToSeat) {
          // 3. Smooth walk to favoriteSeatPos before sitting
          final seat = state.spec.favoriteSeatPos;
          if (seat == null || (playerPos - seat).distance <= 48.0) {
            state.activityState = AgencyAgentActivityState.walking;
            state.restState = PlayerRestState.none;
            if (state.spec.patrolWaypoints.isNotEmpty) {
              state.currentWaypointIndex =
                  (state.currentWaypointIndex + 1) %
                      state.spec.patrolWaypoints.length;
            }
          } else {
            final toSeat = seat - state.currentPos;
            final seatDist = toSeat.distance;
            final moveSpeed = state.spec.isSubjectMentor ? 74.0 : 52.0;
            final step = moveSpeed * safeDt;
            if (seatDist <= step + 2.0) {
              state.currentPos = seat;
              state.facing = state.spec.favoriteSeatFacing;
              state.activityState = AgencyAgentActivityState.sitting;
              state.restState = PlayerRestState.sitting;
              state.stateTimerSec = 5.5;
              state.activeBubbleText =
                  '💭 [${state.spec.subjectCode}] Taking a quick reading break — come sit or chat with me! 📚';
            } else {
              final dir = toSeat / seatDist;
              state.currentPos = state.currentPos + dir * step;
              state.facing = _facingFromDelta(dir, state.facing);
              state.restState = PlayerRestState.none;
            }
          }
        } else {
          // 4. Autonomous Walking Patrol along `patrolWaypoints`
          final waypoints = state.spec.patrolWaypoints;
          if (waypoints.isNotEmpty) {
            final target =
                waypoints[state.currentWaypointIndex % waypoints.length];
            final toTarget = target - state.currentPos;
            final dist = toTarget.distance;
            final moveSpeed = state.spec.isSubjectMentor ? 74.0 : 52.0;
            final step = moveSpeed * safeDt;

            if (dist <= step + 2.0) {
              state.currentPos = target;
              final canSitNow = state.spec.favoriteSeatPos != null &&
                  (state.currentWaypointIndex == 0) &&
                  ((state.interactionCount % 2) == 1);
              if (canSitNow &&
                  (playerPos - state.spec.favoriteSeatPos!).distance > 48.0) {
                state.activityState = AgencyAgentActivityState.walkingToSeat;
                state.restState = PlayerRestState.none;
                state.activeBubbleText =
                    '💭 [${state.spec.subjectCode}] Heading to my reading spot — come sit or chat with me! 📖';
                state.interactionCount++;
              } else {
                state.activityState = AgencyAgentActivityState.inspecting;
                state.restState = PlayerRestState.none;
                state.stateTimerSec = 3.2;
                state.facing = AvatarFacing.down;
                if (state.spec.walkingThoughts.isNotEmpty) {
                  final tIdx =
                      (state.currentWaypointIndex + state.interactionCount) %
                          state.spec.walkingThoughts.length;
                  state.activeBubbleText = state.spec.walkingThoughts[tIdx];
                }
              }
            } else {
              final dir = toTarget / dist;
              state.currentPos = state.currentPos + dir * step;
              state.facing = _facingFromDelta(dir, state.facing);
              state.activityState = AgencyAgentActivityState.walking;
              state.restState = PlayerRestState.none;
            }
          }
        }
      }

      if (!anyChanged &&
          (state.currentPos != prevPos ||
              state.facing != prevFacing ||
              state.activityState != prevActivity ||
              state.restState != prevRest ||
              state.activeBubbleText != prevBubble ||
              state.isWaving != prevWaving)) {
        anyChanged = true;
      }
    }

    return anyChanged;
  }

  AvatarFacing _facingFromDelta(Offset delta, AvatarFacing fallback) {
    if (delta.dx.abs() < 0.01 && delta.dy.abs() < 0.01) return fallback;
    if (delta.dx.abs() >= delta.dy.abs()) {
      return delta.dx >= 0 ? AvatarFacing.right : AvatarFacing.left;
    }
    return delta.dy >= 0 ? AvatarFacing.down : AvatarFacing.up;
  }

  /// Returns the conversation history with [agentId], seeding an initial in-character
  /// `msitarzewski/agency-agents` greeting if empty.
  List<AgencyChatMessage> chatHistoryForAgent(
    String agentId, {
    String studentName = 'Scholar',
  }) {
    final existing = _chatHistories[agentId];
    if (existing != null && existing.isNotEmpty) {
      return List<AgencyChatMessage>.unmodifiable(existing);
    }
    final spec = personaForId(agentId);
    final progress = LobbyDataService.instance.progress;
    final greeting = spec != null
        ? 'Hello $studentName (${progress.rankTitle} • Lv.${progress.level})! I am **${spec.name}**, your AI Teacher for **${spec.fullSubjectTitle}**.\n\n'
            '✨ *My Mission*: ${spec.coreMission}\n\n'
            'Ask me anything about **${spec.subjectCode}**, tap a quick study prompt below, or switch to the **📝 Daily Exam Challenge** tab for +25 XP!'
        : 'Hello $studentName! How can I help you study today?';
    final seeded = <AgencyChatMessage>[
      AgencyChatMessage(
        sender: 'teacher',
        text: greeting,
        timestampMs: DateTime.now().millisecondsSinceEpoch,
      ),
    ];
    _chatHistories[agentId] = seeded;
    return List<AgencyChatMessage>.unmodifiable(seeded);
  }

  /// Quick conversational prompts tailored to the AI Teacher's Portal subject (`PKLP`, `PPG`, or `UCSP`).
  List<String> quickPromptsForAgent(String agentId) {
    final spec = personaForId(agentId);
    if (spec == null) {
      return const <String>[
        'Explain a key concept',
        'Give me an exam tip',
        'Real-life example',
      ];
    }
    switch (spec.subjectCode) {
      case 'PKLP':
        return const <String>[
          '📜 Ipaliwanag ang Polo y Servicio at Suffrage',
          '💡 Bigyan mo ako ng PKLP Exam Tip',
          '🇵🇭 Paano konektado ang PKLP sa buhay ngayon?',
          '🗣️ Ano ang kaibahan ng Repormista at Katipunan?',
        ];
      case 'PPG':
        return const <String>[
          '⚖️ Explain the 4 Elements of a State vs. Nation',
          '🏛️ Compare Legislative, Executive & Judicial',
          '💡 Give me a high-yield PPG Exam Tip',
          '🇵🇭 Real-life Philippine example of Good Governance',
        ];
      case 'UCSP':
      default:
        return const <String>[
          '🌍 Cultural Relativism vs. Ethnocentrism',
          '🏛️ Anthropology, Sociology & Political Science',
          '💡 Give me a high-yield UCSP Exam Tip',
          '🇵🇭 Real-life example of Status, Roles & Norms',
        ];
    }
  }

  /// Processes a student's conversational message/question and generates an in-character
  /// `msitarzewski/agency-agents` response using the AI Teacher's persona, topic knowledge base,
  /// exam tips, and real-life Philippine examples!
  String sendStudentMessage({
    required String agentId,
    required String studentMessage,
    String studentName = 'Scholar',
  }) {
    final cleanMsg = studentMessage.trim();
    if (cleanMsg.isEmpty) return '';

    final history = List<AgencyChatMessage>.from(
      chatHistoryForAgent(agentId, studentName: studentName),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    history.add(
      AgencyChatMessage(
        sender: 'student',
        text: cleanMsg,
        timestampMs: now,
      ),
    );

    final reply = _composePersonaReply(
      agentId: agentId,
      query: cleanMsg,
      studentName: studentName,
      turnIndex: history.length,
    );

    history.add(
      AgencyChatMessage(
        sender: 'teacher',
        text: reply,
        timestampMs: now + 1,
      ),
    );
    _chatHistories[agentId] = history;

    final state = _states[agentId];
    if (state != null) {
      state.interactionCount++;
      state.waveTimerSec = 2.0;
    }
    notifyListeners();
    return reply;
  }

  String _composePersonaReply({
    required String agentId,
    required String query,
    required String studentName,
    required int turnIndex,
  }) {
    final spec = personaForId(agentId);
    if (spec == null) {
      return 'Great question, $studentName! Keep reviewing your Portal subjects (PKLP, PPG, and UCSP)!';
    }

    final lower = query.toLowerCase();

    // 1. Check for Exam Tips request
    if (lower.contains('tip') ||
        lower.contains('payo') ||
        lower.contains('trick') ||
        lower.contains('hack')) {
      if (spec.examTips.isNotEmpty) {
        final tip = spec.examTips[turnIndex % spec.examTips.length];
        return '$tip\n\nKeep going, $studentName — you can test this right now in the **📝 Daily Exam Challenge** tab!';
      }
    }

    // 2. Check for Real-Life Philippine Example request
    if (lower.contains('real-life') ||
        lower.contains('real life') ||
        lower.contains('halimbawa') ||
        lower.contains('ngayon') ||
        lower.contains('apply') ||
        lower.contains('konektado')) {
      if (spec.realLifeExamples.isNotEmpty) {
        final ex =
            spec.realLifeExamples[turnIndex % spec.realLifeExamples.length];
        return '$ex\n\nWhat do you think about how this shapes our community, $studentName?';
      }
    }

    // 3. Match against the AI Teacher's specialized Topic Knowledge Base
    for (final entry in spec.topicKnowledgeBase.entries) {
      if (lower.contains(entry.key)) {
        return '${entry.value}\n\n💬 *${spec.name}*: Do you want another **${spec.subjectCode}** concept or an **Exam Tip** next?';
      }
    }

    // 4. Broad keyword matching across PKLP, PPG, and UCSP concepts
    if (spec.subjectCode == 'PKLP') {
      if (lower.contains('polo') || lower.contains('suffrage')) {
        final p = spec.topicKnowledgeBase['polo'] ?? '';
        final s = spec.topicKnowledgeBase['suffrage'] ?? '';
        return '$p\n\n$s';
      }
      if (lower.contains('reporm') || lower.contains('katipunan')) {
        return spec.topicKnowledgeBase['repormista'] ??
            spec.topicKnowledgeBase['katipunan'] ??
            spec.topicKnowledgeBase.values.first;
      }
    } else if (spec.subjectCode == 'PPG') {
      if (lower.contains('state') || lower.contains('nation') || lower.contains('element')) {
        return spec.topicKnowledgeBase['state'] ??
            spec.topicKnowledgeBase['sovereignty'] ??
            spec.topicKnowledgeBase.values.first;
      }
      if (lower.contains('branch') ||
          lower.contains('legislative') ||
          lower.contains('executive') ||
          lower.contains('judicial')) {
        return spec.topicKnowledgeBase['branches'] ??
            spec.topicKnowledgeBase['constitution'] ??
            spec.topicKnowledgeBase.values.first;
      }
      if (lower.contains('governance') || lower.contains('power') || lower.contains('authority')) {
        return spec.topicKnowledgeBase['governance'] ??
            spec.topicKnowledgeBase['power'] ??
            spec.topicKnowledgeBase['authority'] ??
            spec.topicKnowledgeBase.values.first;
      }
    } else if (spec.subjectCode == 'UCSP') {
      if (lower.contains('relativism') || lower.contains('ethnocentrism')) {
        return spec.topicKnowledgeBase['relativism'] ??
            spec.topicKnowledgeBase.values.first;
      }
      if (lower.contains('anthropology') ||
          lower.contains('sociology') ||
          lower.contains('political')) {
        return spec.topicKnowledgeBase['disciplines'] ??
            spec.topicKnowledgeBase.values.first;
      }
      if (lower.contains('status') ||
          lower.contains('role') ||
          lower.contains('norm') ||
          lower.contains('group')) {
        return spec.topicKnowledgeBase['status'] ??
            spec.topicKnowledgeBase['norms'] ??
            spec.topicKnowledgeBase['groups'] ??
            spec.topicKnowledgeBase.values.first;
      }
    }

    // 5. Fallback: rotate through the teacher's core knowledge base + exam tip in-character
    final topics = spec.topicKnowledgeBase.values.toList();
    final chosenTopic =
        topics.isNotEmpty ? topics[turnIndex % topics.length] : spec.coreMission;
    final bonusTip = spec.examTips.isNotEmpty
        ? '\n\n${spec.examTips[turnIndex % spec.examTips.length]}'
        : '';
    return 'Here is a key **${spec.subjectCode}** insight for your question, $studentName:\n\n$chosenTopic$bonusTip';
  }
}
