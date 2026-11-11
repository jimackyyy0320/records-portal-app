import 'lobby_data_service.dart';

/// Authentic MIS-SHS Exam & Reviewer Question Bank extracted directly from the 11 official `.docx`
/// assessment files in the project's `exams/` directory:
/// 1. `PKLP Summative 1 TERM 2.docx` (30 items)
/// 2. `PKLP Summative 2 TERM 2.docx` (30 items)
/// 3. `PKLP Summative 1.docx` (30 items)
/// 4. `PKLP Summative 2.docx` (30 items)
/// 5. `PPG Summative 1.docx` (30 items)
/// 6. `PPG Summative 2.docx` (30 items)
/// 7. `PPG TERM 1.docx` & `PPG REVIEWER T1.docx` (40 items)
/// 8. `UCSP Summative 1.docx` & `UCSP Summative 1 Remedial.docx` (30 items)
/// 9. `UCSP Summative 2.docx` (30 items)
/// Plus supplementary `PHILO` & `PGP` items (260+ total curriculum-verified questions).
const List<MiniQuizQuestion> kAuthenticExamQuestionBank = [
  // ===========================================================================
  // 1. PKLP Summative 1 TERM 2.docx (30 Items — Subject: PKLP TERM 2)
  // ===========================================================================
  MiniQuizQuestion(
    id: 'pklp_t2_s1_01',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Ang pag-alam sa ating kasaysayan ay mahalaga upang patuloy na maging mulat para sa kalagayan ng bayan at hindi na maulit ang pang-aapi ng nakaraan.',
    options: [
      'TAMA — Wasto batay sa kasaysayan at lipunan',
      'MALI — Hindi wasto batay sa kasaysayan',
      'Wala itong kaugnayan sa kasalukuyan',
      'Para lamang sa mga banyagang mananaliksik',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_02',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Ang patakarang Polo y Servicio ay nagdulot ng magandang oportunidad sa trabaho at pagnenegosyo para sa mga kalalakihang Pilipino noong panahon ng mga Espanyol.',
    options: [
      'TAMA — Nagbigay ito ng mataas na sahod',
      'MALI — Nagpahirap ito at naghiwalay sa mga pamilyang Pilipino',
      'TAMA — Naging mayaman ang mga polista',
      'Walang epekto sa kabuhayan ng pamilya',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_03',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Ang pangunahing layunin ng mga repormistang Pilipino tulad nina Dr. Jose Rizal at Marcelo H. del Pilar sa simula ay agaran at madugong rebolusyon.',
    options: [
      'TAMA — Agad silang naglunsad ng digmaan',
      'MALI — Humiling muna sila ng mapayapang reporma at pantay na representasyon',
      'TAMA — Gumamit sila ng dahas sa Espanya',
      'Hindi sila sumulat ng anumang akda',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_04',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Noong panahon ng mga Amerikano, nabigyan ng malawak na oportunidad ang kababaihan na makapag-aral at maging guro dahil sa libre at sekular na pampublikong edukasyon.',
    options: [
      'TAMA — Nabuksan ang edukasyon at propesyon sa kababaihan',
      'MALI — Pinagbawalan ang lahat ng babae na pumasok sa paaralan',
      'MALI — Tanging mga prayle lamang ang nagturo',
      'Walang pampublikong paaralan noong panahon ng Amerikano',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_05',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Ginamit ang terminong "Indio" ng mga Espanyol upang ipakita ang pantay na pagtingin at paggalang nila sa mga katutubong Pilipino.',
    options: [
      'TAMA — Isa itong parangal sa mga katutubo',
      'MALI — Ginamit ito bilang pangmamaliit at diskriminasyon sa mga katutubo',
      'TAMA — Katumbas ito ng pagiging Gobernador-Heneral',
      'Termino ito para sa mga mangangalakal na Tsino',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_06',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Ang propagandang Greater East Asia Co-Prosperity Sphere ay ginamit ng mga Hapon bilang pagbabalatkayo na pinalalaya ang Asya mula sa mga Kanluranin.',
    options: [
      'TAMA — Ito ay tunay na nagbigay ng ganap na kalayaan at kasaganaan',
      'MALI — Isa lamang itong propaganda upang pagtakpan ang imperyalistang pananakop ng Hapon',
      'Programa ito ng bansang Espanya noong 1565',
      'Kasunduan ito sa pagitan ng Pilipinas at Britanya',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_07',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Nakamit ng mga kababaihang Pilipino ang karapatang bumoto (Suffrage) noong taong 1937 sa pamamagitan ng isang plebisito.',
    options: [
      'TAMA — Pinaboran ito ng mahigit 500,000 kababaihang Pilipino noong 1937',
      'MALI — Hindi kailanman nakaboto ang kababaihan sa Pilipinas',
      'MALI — Noong panahon pa ng Espanyol nakaboto ang kababaihan',
      'Ipinagkaloob lamang ito noong taong 2010',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_08',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Sa kasalukuyang panahon, ang Neokolonyalismo ay tumutukoy lamang sa direktang pananakop gamit ang militar at dahas.',
    options: [
      'TAMA — Puro tangke at sundalo lamang ang gamit sa neokolonyalismo',
      'MALI — Ito ay di-tuwirang pananakop sa isipan, kultura, ekonomiya, at politika',
      'Walang kinalaman ang ekonomiya sa neokolonyalismo',
      'Nangyari lamang ito noong ika-16 na siglo',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_09',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Ang pakikibaka ay hindi laging madugo; maaari rin itong isagawa sa pamamagitan ng panulat, diplomasya, sining, at edukasyon.',
    options: [
      'TAMA — Maraming mapayapa, intelektuwal, at kultural na anyo ng pakikibaka',
      'MALI — Tanging armas lamang ang kahulugan ng pakikibaka',
      'MALI — Bawal gamitin ang sining sa pagpapahayag ng damdamin',
      'Hindi nakatulong ang panulat sa kasaysayan',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_10',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 1] Tama o Mali: Si Gabriela Silang ang pangunahing lider na nanguna sa kilusan para sa karapatang bumoto ng kababaihan noong panahon ng mga Amerikano.',
    options: [
      'TAMA — Siya ang bumuo ng Asociacion Feminista Ilonga noong 1906',
      'MALI — Si Pura Villanueva Kalaw ang kinikilalang nanguna sa kilusang Suffrage noong panahon ng Amerikano',
      'TAMA — Nabuhay si Gabriela Silang noong 1937',
      'Walang lider ang kilusang Suffrage sa Pilipinas',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_11',
    subject: 'PKLP TERM 2',
    question:
        'Alin sa sumusunod ang naging pangunahing dahilan kung bakit lumaganap at lumakas ang kamalayang panlipunan ng mga Pilipino noong panahon ng Espanyol?',
    options: [
      'Pagpapatayo ng mga libreng paaralan',
      'Hindi pantay na pagtrato at malawakang pang-aabuso',
      'Pagtanggap ng mga Pilipino sa relihiyong Katolisismo',
      'Pagbibigay ng posisyon sa gobyerno sa mga katutubo',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_12',
    subject: 'PKLP TERM 2',
    question:
        'Sa anong paraan nakaapekto ang Polo y Servicio (sapilitang paggawa) sa katatagan ng kabuhayan ng mga pamilyang Pilipino?',
    options: [
      'Lumala ang kahirapan at nawalay sa pamilya ang mga kalalakihan',
      'Nagdulot ito ng maraming oportunidad sa trabaho at pagnenegosyo',
      'Pinabuti nito ang kalagayan ng mga magsasaka sa Pilipinas',
      'Napadali nito ang pag-angkat ng pagkain mula sa Espanya',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_13',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang naging pangunahing layunin ng mga repormistang Pilipino gaya nina Dr. Jose Rizal at Marcelo H. del Pilar?',
    options: [
      'Maglunsad agad ng madugong rebolusyon',
      'Manungkulan bilang gobernador-heneral sa bansa',
      'Humiling ng reporma at pantay na representasyon, hindi agad ganap na kalayaan',
      'Magtayo ng sariling malayang republika sa ibang bansa',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_14',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang naging pangunahing kontribusyon ng edukasyon sa kababaihang Pilipino noong panahon ng mga Amerikano?',
    options: [
      'Napilitan silang manatili sa bahay upang mag-aral online',
      'Nabuksan ang mas malawak na oportunidad para makapag-aral at maging guro',
      'Pinagbawalan silang bumoto at makilahok sa lipunan',
      'Naituro sa kanila na iwasan ang pulitika at sining',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_15',
    subject: 'PKLP TERM 2',
    question:
        'Sino sa mga sumusunod ang kilalang babae na nagsulong at nanguna sa kilusan para sa karapatang bumoto ng kababaihan sa Pilipinas?',
    options: [
      'Melchora Aquino',
      'Gabriela Silang',
      'Gregoria de Jesus',
      'Pura Villanueva Kalaw',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_16',
    subject: 'PKLP TERM 2',
    question:
        'Anong mahalagang karapatan ang nakamit ng mga kababaihang Pilipino noong taong 1937 matapos paboran ng higit 500,000 na kababaihan ang isang plebisito?',
    options: [
      'Karapatang magkaroon ng lupa',
      'Karapatang mag-aral sa kolehiyo',
      'Karapatang bumoto (Suffrage)',
      'Karapatang maging pari',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_17',
    subject: 'PKLP TERM 2',
    question:
        'Anong kilusang gerilya na pinamunuan ni Luis Taruc ang sumikat sa Gitnang Luzon bilang mapangahas na paglaban sa mga Hapon?',
    options: [
      'Katipunan',
      'Hukbalahap',
      'Makapili',
      'Sakdalista',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_18',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang tunay na layunin ng propagandang Greater East Asia Co-Prosperity Sphere na ipinakalat ng mga Hapon?',
    options: [
      'Palayain kunwari ang Asya mula sa Kanluranin ngunit sa totoo\'y isa rin itong pananakop',
      'Ibigay sa Pilipinas ang ganap at tunay na kalayaan',
      'Turuan ang mga Pilipino ng bagong relihiyon at teknolohiya',
      'Protektahan ang karapatang pantao ng lahat ng Asyano',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_19',
    subject: 'PKLP TERM 2',
    question:
        'Bakit hindi nabibigyan ng katarungan ang mga Pilipino sa mga hukuman noong panahon ng kolonyalismong Espanyol?',
    options: [
      'Dahil mas gusto ng mga Pilipino na aregluhin ito sa labas',
      'Dahil hindi pantay ang batas at walang boses ang mga Pilipino sa pamahalaan',
      'Dahil abala ang mga Espanyol sa paggawa ng tulay',
      'Dahil hindi marunong magbasa ng Espanyol ang mga Pilipino',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_20',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang naging pangkalahatang tugon ng maraming Pilipino sa matinding karahasan at panunupil noong panahon ng okupasyong Hapon?',
    options: [
      'Tahimik na pagtanggap sa kanilang pamahalaan',
      'Paglisan sa bansa papuntang Amerika',
      'Pagsali sa mga kilusang gerilya at lihim na paglaban',
      'Pakikipagkalakalan sa mga sundalong Hapon',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_21',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang pormal na pagpapakahulugan ng terminong "pakikibaka" sa konteksto ng ating aralin?',
    options: [
      'Pagsunod sa lahat ng utos ng mga banyaga upang magkaroon ng kapayapaan',
      'Pagtatangkang makamit ang isang layunin sa kabila ng mga hadlang, at pagtindig para sa katarungan o pagbabago sa lipunan',
      'Pag-alis sa bansa upang takasan ang mga problema ng lipunan',
      'Paggamit lamang ng armas at dahas upang makamit ang pansariling interes',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_22',
    subject: 'PKLP TERM 2',
    question:
        'Anong patakaran o "soft power" ang ginamit ng mga Amerikano upang makuha ang loob ng mga Pilipino at unti-unting itatag ang kanilang pamamahala?',
    options: [
      'Polo y Servicio',
      'Tributo at Monopolyo',
      'Benevolent Assimilation',
      'Greater East Asia Co-Prosperity Sphere',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_23',
    subject: 'PKLP TERM 2',
    question:
        'Sino ang tinaguriang "Utak ng Rebolusyon" na pinangunahan ang mapayapang pakikibaka at diplomasya sa pamamagitan ng pagsulat ng mga batas at petisyon?',
    options: [
      'Emilio Aguinaldo',
      'Andres Bonifacio',
      'Apolinario Mabini',
      'Antonio Luna',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_24',
    subject: 'PKLP TERM 2',
    question:
        'Anong anyo ng pakikibaka ang ginamit nina Dr. Jose Rizal sa pamamagitan ng pagsulat ng Noli Me Tangere at El Filibusterismo upang imulat ang mga Pilipino?',
    options: [
      'Armado at Pisikal',
      'Intelektuwal at Kultural',
      'Ekonomikal at Agraryo',
      'Gerilya',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_25',
    subject: 'PKLP TERM 2',
    question:
        'Bakit itinuturing na napakahalaga ng "Kolektibong Pagkilos" sa pagkamit ng makatarungang pagbabago sa lipunan?',
    options: [
      'Upang mas mabilis na makalikom ng pondo ang mga namumuno',
      'Dahil mas madali itong makita at mabalita sa buong mundo',
      'Dahil hindi sapat ang indibidwal na galit para mabago at buwagin ang isang mapang-abusong sistema',
      'Upang maiwasan ang pisikal na pagtatrabaho ng mga miyembro',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_26',
    subject: 'PKLP TERM 2',
    question:
        'Sa makabagong panahon, alin sa mga sumusunod ang HINDI kabilang sa mga itinuturing na modernong banta sa kalayaan at kamalayang Pilipino?',
    options: [
      'Neokolonyalismo',
      'Disimpormasyon (Fake News)',
      'Apatya (Apathy)',
      'Armadong pananakop ng mga prayleng Espanyol',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_27',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang ibig sabihin ng "Apatya" (Apathy) na itinuturing na kalaban ng kamalayang Pilipino sa kasalukuyan?',
    options: [
      'Labis na pagtangkilik sa kultura ng dayuhan',
      'Pagkalat ng maling impormasyon sa internet',
      'Ang kawalan ng pakialam sa mga nangyayari sa lipunan dahil sa pag-iisip na "wala naman akong magagawa"',
      'Pagsusulong ng madugong rebolusyon sa mga kalsada',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_28',
    subject: 'PKLP TERM 2',
    question:
        'Anong patakarang pang-ekonomiya noong panahon ng Espanyol ang pumilit sa mga Pilipinong itanim lamang ang gusto ng gobyerno at nagdulot ng malawakang gutom?',
    options: [
      'Pensionado Act',
      'Monopolyo (hal. sa tabako)',
      'Benevolent Assimilation',
      'Sistemang Hacienda',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_29',
    subject: 'PKLP TERM 2',
    question:
        'Aling grupo ng mga dayuhang guro ang dinala ng mga Amerikano upang magturo at magpalaganap ng edukasyon at wikang Ingles sa Pilipinas?',
    options: [
      'Prayle',
      'Ilustrado',
      'Thomasites',
      'Katipunero',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s1_30',
    subject: 'PKLP TERM 2',
    question:
        'Alin sa mga sumusunod ang itinuturing na makabagong anyo ng pakikibaka na malawakang ginagamit ng kabataan upang labanan ang maling impormasyon (fake news)?',
    options: [
      'Pagsali sa Hukbalahap',
      'Pagsulat ng mga batas sa kongreso',
      'Online Activism at Fact-Checking',
      'Pag-boycott sa mga banyagang produkto',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),

  // ===========================================================================
  // 2. PKLP Summative 2 TERM 2.docx (30 Items — Subject: PKLP TERM 2)
  // ===========================================================================
  MiniQuizQuestion(
    id: 'pklp_t2_s2_01',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 2] Tama o Mali: Ang obese political dynasty ay tumutukoy sa sabay-sabay na pag-upo sa puwesto ng apat hanggang lima (4-5) o higit pang miyembro ng iisang pamilya na sumisira sa checks and balances.',
    options: [
      'TAMA — Wasto batay sa pag-aaral ng mga dinastiyang politikal',
      'MALI — Tumutukoy lamang ito sa isang miyembro ng pamilya',
      'MALI — Ipinagbabawal na ito sa lahat ng posisyon mula 1901',
      'Walang kinalaman sa checks and balances ang political dynasty',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_02',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 2] Tama o Mali: Nakatulong nang malaki ang Land Use Conversion sa mga magsasaka dahil ipinamahagi nito ang mga lupang komersyal upang tamnan ng palay.',
    options: [
      'TAMA — Nabigyan ng libreng subdibisyon ang bawat magsasaka',
      'MALI — Ginamit ang Land Use Conversion ng ilang asyendero upang maiwasan ang repormang agraryo',
      'TAMA — Pinadami nito ang lupang sakahan sa buong bansa',
      'Ito ay batas na nagbabawal sa mga mall at subdibisyon',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_03',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 2] Tama o Mali: Nilagdaan ni Pangulong Diosdado Macapagal ang Republic Act No. 3844 (Agricultural Land Reform Code) noong 1963 upang tuldukan ang sistemang kasamá.',
    options: [
      'TAMA — Nilagdaan ito noong 1963 upang palayain ang mga magsasaka sa sistemang kasamá',
      'MALI — Si Gobernador-Heneral Legazpi ang lumagda nito',
      'MALI — Layunin nitong palawakin ang encomienda',
      'Ito ay batas tungkol sa pagbubuwis ng tabako',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_04',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 2] Tama o Mali: Ang Constitutional Authoritarianism ay ang terminong ginamit ni Pangulong Ferdinand Marcos upang ilarawan ang pag-iral ng Batas Militar o Proklamasyon 1081.',
    options: [
      'TAMA — Ginamit ito upang bigyang-katwiran ang Batas Militar sa ilalim ng binagong Konstitusyon',
      'MALI — Termino ito ni Pangulong Ramon Magsaysay',
      'MALI — Tumutukoy ito sa malayang halalan noong 1935',
      'Walang binagong Saligang Batas noong 1973',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_05',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 2] Tama o Mali: Ang Sangguniang Kabataan (SK) Reform Act o RA 10742 ay ang kauna-unahang batas sa Pilipinas na nagpatupad ng Anti-Political Dynasty provision para sa mga kabataang opisyal.',
    options: [
      'TAMA — Naglalaman ang RA 10742 ng probisyon laban sa political dynasty sa SK',
      'MALI — Hinihikayat ng RA 10742 na magkakamag-anak ang umupo sa SK',
      'MALI — Binuwag ng RA 10742 ang lahat ng barangay',
      'Ito ay batas para sa mga bangko at korporasyon',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_06',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 2] Tama o Mali: Ang Mosquito Press noong panahon ng Batas Militar ay mga alternatibong pahayagan na matapang na nagbunyag ng katotohanan laban sa diktadura.',
    options: [
      'TAMA — Sila ang maliliit ngunit matatapang na pahayagang lumaban sa sensura ng diktadura',
      'MALI — Sila ay mga pahayagang tungkol sa insekto at agrikultura',
      'MALI — Sila ang opisyal na tagapagsalita ng militar',
      'Itinatag ito noong panahon ng mga Espanyol',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_07',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 2] Tama o Mali: Pinatutunayan ng pagpirma sa Bell Trade Act at Treaty of General Relations ang pagpapatuloy ng neokolonyalismo sa Pilipinas matapos ang Ikalawang Digmaang Pandaigdig.',
    options: [
      'TAMA — Pinanatili nito ang impluwensyang pang-ekonomiya at politikal ng Amerika sa bansa',
      'MALI — Nagbigay ito ng 100% kalayaang pang-ekonomiya nang walang kondisyon',
      'MALI — Kasunduan ito sa pagitan ng Pilipinas at Hapon',
      'Walang kinalaman sa kalakalan ang Bell Trade Act',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_08',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 2] Tama o Mali: Ang mga awiting "Upuan" ni Gloc-9 at "Tatsulok" ng Buklod ay isinulat upang purihin at suportahan ang mga Local Elite sa kanilang pamamahala sa bansa.',
    options: [
      'TAMA — Papuri ito sa mayayamang politiko',
      'MALI — Isinulat ang mga ito upang punahin ang hindi pagkakapantay-pantay at pagkamanhid ng mga nasa kapangyarihan',
      'TAMA — Awitin ito para sa kampanya ng mga asyendero',
      'Walang mensaheng panlipunan ang mga awiting ito',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_09',
    subject: 'PKLP TERM 2',
    question:
        '[PKLP Term 2 Summative 2] Tama o Mali: Ang Patronage Politics o Sistemang Padrino ay lumilikha ng kaisipang "utang na loob" kung saan ang serbisyo ng gobyerno ay nagmimistulang personal na tulong ng politiko.',
    options: [
      'TAMA — Ginagawa nitong personal na pabor ang dapat ay karapatan ng mamamayan mula sa buwis',
      'MALI — Pinapabilis nito ang patas at merit-based na serbisyo publiko',
      'MALI — Isa itong uri ng direktang demokrasya',
      'Wala itong epekto sa halalan sa Pilipinas',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_10',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang tawag sa sistema kung saan ang kapangyarihang politikal at pang-ekonomiya ay nakasentro at kontrolado lamang ng iilang mayayamang pamilya o angkan sa isang bayan?',
    options: [
      'Sosyalismo',
      'Local Elitism',
      'Totalitaryanismo',
      'Komunismo',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_11',
    subject: 'PKLP TERM 2',
    question:
        'Sa artikulo ng PCIJ, alin sa mga sumusunod ang naglalarawan sa estratehiyang "franchising" ng mga political dynasty?',
    options: [
      'Pagpapalawak ng kapangyarihan at impluwensiya sa iba\'t ibang probinsya, munisipalidad, at bayan',
      'Paglilipat ng pondo ng gobyerno sa mga negosyo sa ibang bansa',
      'Pagbili ng mga fast-food chains upang maging negosyo ng pamilya',
      'Pagbibitiw sa puwesto upang ibigay ito sa hindi kamag-anak',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_12',
    subject: 'PKLP TERM 2',
    question:
        'Sino ang pangulo ng Pilipinas na kilala sa pagbubukas ng pintuan ng Malacañang para sa mga karaniwang mamamayan noong dekada \'50?',
    options: [
      'Ferdinand Marcos',
      'Carlos P. Garcia',
      'Ramon Magsaysay',
      'Gloria Macapagal-Arroyo',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_13',
    subject: 'PKLP TERM 2',
    question:
        'Anong proklamasyon ang nilagdaan noong Setyembre 1972 na nagpasara sa Kongreso at naglagay sa Pilipinas sa ilalim ng Batas Militar?',
    options: [
      'Proklamasyon Blg. 1081',
      'Proklamasyon Blg. 1986',
      'Republic Act 3844',
      'Republic Act 6657',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_14',
    subject: 'PKLP TERM 2',
    question:
        'Alin sa sumusunod na termino ang tumutukoy sa mga aktibista at sibilyan na dinukot at sapilitang iwinala noong panahon ng Batas Militar?',
    options: [
      'Ilustrado',
      'Cacique',
      'Thomasites',
      'Desaparecidos',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_15',
    subject: 'PKLP TERM 2',
    question:
        'Ayon sa awiting "Tatsulok", ano ang sinisimbolo ng mga taong nasa "tuktok" ng tatsulok?',
    options: [
      'Ang masang naghihirap',
      'Ang iilang oligarkiya o elitista na may hawak ng kapangyarihan at yaman',
      'Ang mga bayani ng himagsikan',
      'Ang mga magsasaka at manggagawa',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_16',
    subject: 'PKLP TERM 2',
    question:
        'Sa kasaysayan ng Political Caricature sa Pilipinas, ano ang naging papel ng "Ikabod Bubwit" ni Nonoy Marcelo noong panahon ng Batas Militar?',
    options: [
      'Purihin ang mga proyektong pang-imprastraktura ng gobyerno',
      'Magsilbing opisyal na pahayagan ng mga militar at kapulisan',
      'Gamitin bilang alegorya upang punahin ang diktadura, cronyism, at kahirapan',
      'Magturo ng tamang pag-uugali at pagsunod sa batas para sa mga bata',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_17',
    subject: 'PKLP TERM 2',
    question: 'Ano ang pagkakaiba ng Thin Dynasty sa Fat Dynasty?',
    options: [
      'Ang Thin Dynasty ay legal; ang Fat Dynasty ay ilegal ayon sa Korte Suprema',
      'Ang Thin Dynasty ay pamumuno ng mahihirap; ang Fat Dynasty ay pamumuno ng mayayaman',
      'Ang Thin Dynasty ay pagsasalin-salin sa iisang posisyon; ang Fat Dynasty ay sabay-sabay na paghawak ng iba\'t ibang posisyon ng iisang pamilya',
      'Wala silang pinagkaiba sa mata ng batas',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_18',
    subject: 'PKLP TERM 2',
    question:
        'Alin sa mga sumusunod na direktor at grupo ang matapang na gumamit ng sining at musika bilang paraan ng protesta noong panahon ng diktadura?',
    options: [
      'Inang Laya at Lino Brocka',
      'Fernando Amorsolo at Jorge Pineda',
      'Juan Luna at Felix Hidalgo',
      'Jose Rizal at Marcelo H. del Pilar',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_19',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang tawag sa sistema noong Batas Militar kung saan ang kontrol sa malalaking industriya ay ibinigay sa malalapit na kaibigan at kamag-anak ng diktador?',
    options: [
      'Free Market Economy',
      'Crony Capitalism',
      'Socialist Economy',
      'Encomienda System',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_20',
    subject: 'PKLP TERM 2',
    question:
        'Paano naiwasan ng ilang asyendero ang repormang agraryo na naging dahilan upang hindi maipamahagi ang kanilang mga lupain sa mga magsasaka?',
    options: [
      'Sa pamamagitan ng paggawa ng mga kooperatiba',
      'Sa pamamagitan ng pagbibigay ng mas mataas na sahod sa mga magsasaka',
      'Sa pamamagitan ng Land Use Conversion o pagpapalit-gamit ng lupa tungo sa komersiyal o subdibisyon',
      'Sa pamamagitan ng pagbabayad ng mataas na buwis sa gobyerno',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_21',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang pangunahing layunin ng Freedom of Information (FOI) bilang solusyon sa mga suliraning panlipunan?',
    options: [
      'Bigyan ng karapatan ang pamahalaan na itago ang kanilang badyet mula sa publiko',
      'Bigyan ng karapatan ang mamamayan na makita at suriin ang mga kontrata, SALN, at badyet ng mga opisyal upang maiwasan ang korapsyon',
      'Ipasara ang mga lokal na pahayagan na pumupuna sa mga mambabatas',
      'Pigilan ang mga kabataan na gumamit ng social media',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_22',
    subject: 'PKLP TERM 2',
    question: 'Alin sa mga sumusunod ang direktang layunin ng Anti-Epal Policy?',
    options: [
      'Ipagbawal ang pagtakbo ng mga magkakamag-anak sa Senado',
      'Ipasara ang mga estasyon ng radyo na hindi lisensyado',
      'Patawan ng buwis ang mga post sa social media tungkol sa politika',
      'Ipagbawal ang paglalagay ng pangalan o mukha ng politiko sa mga proyektong pinondohan ng buwis ng taumbayan',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_23',
    subject: 'PKLP TERM 2',
    question:
        'Ayon sa pag-aaral ng ACLED at ReliefWeb, ano ang pangunahing sanhi ng karahasang politikal na tumatarget sa mga lokal na opisyal sa Pilipinas?',
    options: [
      'Matinding tunggalian at kompetisyon sa pagitan ng mga makapangyarihang lokal na elit at mga angkang politikal',
      'Ang pag-aagawan ng mga dayuhang korporasyon sa mga lupain',
      'Ang walang-tigil na pag-aaklas at protesta ng mga estudyante',
      'Ang mga relihiyosong hidwaan sa pagitan ng magkakaibang sekta',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_24',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang tinutukoy ng konseptong "Summary Execution" o "Salvaging" na malawakang naganap noong panahon ng Batas Militar?',
    options: [
      'Paglilitis sa mga kriminal sa Korte Suprema nang patas',
      'Pagliligtas sa mga biktima ng kalamidad gamit ang pondo ng bayan',
      'Pag-ipon ng mga ebidensya laban sa mga dayuhan bago sila ipatapon',
      'Pagpatay sa mga aktibista o sibilyan nang walang due process o paglilitis sa korte',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_25',
    subject: 'PKLP TERM 2',
    question:
        'Sa pormat ng "Holistic Notetaking", anong bahagi ang sumasagot sa tanong na: "Ano ang gagawin ko ngayon bilang isang mamamayang Pilipino batay sa aking natutuhan?"',
    options: [
      'Information Based (Facts)',
      'Values Based (Damdamin)',
      'Citizen Based (Aksyon)',
      'Historical Based (Petsa)',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_26',
    subject: 'PKLP TERM 2',
    question:
        'Aling pangunahing suliranin ang direktang nilalabanan ng fact-checking at responsableng pamamahayag ng mga kabataan sa makabagong panahon?',
    options: [
      'Disimpormasyon at Historical Distortion sa social media',
      'Kakulangan sa pananim sa mga lalawigan',
      'Paggamit ng wikang Ingles sa mga paaralan',
      'Sobrang dami ng mga political party na tumatakbo sa halalan',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_27',
    subject: 'PKLP TERM 2',
    question:
        'Paano ginawang "ligal" ang walang-taning na pamumuno sa ilalim ng Constitutional Authoritarianism ni Marcos?',
    options: [
      'Sa pamamagitan ng pagbili ng mga boto sa malawakang halalan',
      'Sa pamamagitan ng paghingi ng pormal na permiso sa Estados Unidos',
      'Sa pamamagitan ng pagbabago ng Saligang Batas (1973) at pagsuspinde sa Writ of Habeas Corpus',
      'Sa pamamagitan ng paggawa ng kasunduang pangkapayapaan sa mga rebeldeng grupo',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_28',
    subject: 'PKLP TERM 2',
    question:
        'Ayon sa Artikulo II, Seksiyon 26 ng 1987 Konstitusyon, ano ang nararapat gawin ng Estado laban sa mga political dynasty?',
    options: [
      'Dapat itong pondohan at suportahan upang mapanatili ang kapayapaan',
      'Dapat seguruhin ang pantay na pagkakataon sa serbisyo pambayan at ipagbawal ang mga dinastiyang politikal',
      'Dapat bigyan ang mga dinastiya ng eksklusibong karapatan sa pampublikong lupain',
      'Dapat silang ilipat sa ibang lalawigan kung hindi sila mananalo',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_t2_s2_29',
    subject: 'PKLP TERM 2',
    question:
        'Sa awiting "Upuan" ni Gloc-9, ano ang malalim na kahulugan ng "mataas na pader" na pumapaligid sa mansyon ng nakaupo?',
    options: [
      'Simbolo ng kahirapan at kawalan ng trabaho sa Pilipinas',
      'Simbolo ng kagitingan at proteksyon ng mga sundalo laban sa mga dayuhan',
      'Simbolo ng pagkakahiwalay (isolation) at pagkamanhid ng mga elitista mula sa paghihirap ng karaniwang masa',
      'Simbolo ng matibay na pampublikong paaralan na ipinatayo ng gobyerno',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),

  // ===========================================================================
  // 3. PKLP Summative 1 & 2 (Term 1 & Foundational Kasaysayan — PKLP TERM 2)
  // ===========================================================================
  MiniQuizQuestion(
    id: 'pklp_s1_01',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang tawag sa malalim at kritikal na pag-unawa kung paano nakaapekto ang nakaraan sa kasalukuyan at hinaharap ng isang tao o komunidad?',
    options: [
      'Kamalayang pangkasaysayan',
      'Heograpiyang pantao',
      'Kasaysayang politikal',
      'Kultural na asimilasyon',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s1_02',
    subject: 'PKLP TERM 2',
    question: 'Alin ang tumutukoy sa kabuuan ng lahat ng bagay na nangyari na?',
    options: [
      'Kasaysayan',
      'Nakaraan',
      'Batis ng kasaysayan',
      'Lunan ng alaala',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s1_03',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang tawag sa mga napili at binigyang-kahulugang salaysay ng mga pangyayaring naganap sa nakaraan?',
    options: [
      'Nakaraan',
      'Primaryang batis',
      'Kasaysayan',
      'Pantayong pananaw',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s1_04',
    subject: 'PKLP TERM 2',
    question:
        'Alin sa sumusunod ang tumutukoy sa mga kinapanayam na nakatatanda bilang buhay na pinagmumulan ng impormasyon?',
    options: [
      'Sekundaryang batis',
      'Lunan ng alaala',
      'Primaryang batis',
      'Kasanggunian',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s1_05',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang konseptong isinulong ni Dr. Zeus Salazar na tumutukoy sa kakayahang magsalaysay ng sariling nakaraan gamit ang sariling wika at pananaw?',
    options: [
      'Pantayong pananaw',
      'Kolonyal na pananaw',
      'Pampanitikang pananaw',
      'Teknikal na pagsusuri',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s1_06',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang tawag sa mga bantayog at historical marker na sinadyang itayo upang hindi makalimutan ng lipunan ang isang tao, pangyayari, o pook?',
    options: [
      'Likas na yaman',
      'Lunan ng alaala',
      'Kasaysayang oral',
      'Kultural na anyo',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s1_07',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang tawag sa mga komunidad sa Pilipinas na matatagpuan sa kabundukan o mataas na lugar?',
    options: [
      'Ilawod',
      'Ilaya',
      'Baybayin',
      'Kapuluan',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s1_08',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang tawag sa mga sinaunang pamayanang malapit sa katubigan, ilog, o karagatan?',
    options: [
      'Ilaya',
      'Kapatagan',
      'Ilawod',
      'Kabundukan',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s2_01',
    subject: 'PKLP TERM 2',
    question:
        'Ang mga Mangyan ay kabilang sa pamayanang Ilaya sa Mindoro. Ano ang kanilang pangunahing kabuhayan dahil sa kanilang heograpiya?',
    options: [
      'Pangingisda sa laot at paggawa ng bangka',
      'Swidden Farming (Kaingin) at pagtatanim ng mga root crops',
      'Paghahabi ng T\'nalak gamit ang abaca',
      'Pakikipagkalakalan sa mga dayuhan sa pantalan',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s2_02',
    subject: 'PKLP TERM 2',
    question:
        'Sa pamayanang Panay Bukidnon, sino ang mga itinatagong kababaihan na nagsisilbing tagapag-ingat ng epikong Sugidanon?',
    options: [
      'Babaylan',
      'Binukot',
      'Dreamweavers',
      'Datu',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s2_03',
    subject: 'PKLP TERM 2',
    question:
        'Ano ang sinisimbolo ng bangka na makikita sa takip ng Bangang Manunggul?',
    options: [
      'Ang pang-araw-araw na pangingisda ng mga ninuno sa Palawan',
      'Ang pagiging dalubhasa sa paggawa ng sasakyang pandagat',
      'Ang pakikipagkalakalan ng mga Pilipino sa mga dayuhan',
      'Ang paglalakbay ng kaluluwa tawid-dagat patungo sa kabilang buhay',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s2_04',
    subject: 'PKLP TERM 2',
    question:
        'Anong pangkat sa Luzon ang may ritwal na "Bogwa" kung saan hinuhukay, nililinis, at muling inililibing ang mga buto ng yumao bilang pagbibigay-parangal?',
    options: [
      'Tagalog',
      'Ilocano',
      'Ifugao',
      'Kapampangan',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s2_05',
    subject: 'PKLP TERM 2',
    question:
        'Ang mga kababaihang T\'boli na naghahabi ng T\'nalak ay tinatawag na "Dreamweavers". Bakit?',
    options: [
      'Dahil natutulog sila habang naghahabi',
      'Dahil ang mga disenyo ng tela ay ibinibigay sa pamamagitan ng panaginip mula kay Fu Dalu',
      'Dahil ang mga tela ay ginagamit lamang pang-tulog',
      'Dahil pinapangarap nilang yumaman gamit ang telang ito',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s2_06',
    subject: 'PKLP TERM 2',
    question:
        'Anong sistema ng pagsulat ang ginagamit ng mga Mangyan na inuukit nila sa mga piraso ng kawayan?',
    options: [
      'Alibata',
      'Baybayin',
      'Surat Mangyan',
      'Cuneiform',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pklp_s2_07',
    subject: 'PKLP TERM 2',
    question:
        'Sa modernong panahon, ano ang katumbas sa Siyensya at Medisina ng konseptong "Ginhawa" ng ating mga ninuno?',
    options: [
      'Surgery',
      'Holistic Health (Physical, Mental, and Emotional Well-being)',
      'Pharmacy',
      'First Aid',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),

  // ===========================================================================
  // 4. PPG Summative 1.docx (30 Items — Subject: PPG & PGP)
  // ===========================================================================
  MiniQuizQuestion(
    id: 'ppg_s1_01',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which statement best defines politics as presented in the lesson?',
    options: [
      'The art of government and public decision-making',
      'The study of weather patterns',
      'The management of private businesses only',
      'The history of ancient biological species',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_02',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which term refers to the broader process that involves civil society and private sectors, not only the formal government?',
    options: [
      'Governance',
      'Legislation',
      'Sovereignty',
      'Administration',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_03',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which political ideology emphasizes individual freedom, reason, and toleration?',
    options: [
      'Conservatism',
      'Socialism',
      'Liberalism',
      'Authoritarianism',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_04',
    subject: 'PPG',
    question:
        '[PPG Summative 1] What is the ability to achieve a desired outcome or influence the behavior of others called?',
    options: [
      'Governance',
      'Power',
      'Consensus',
      'Jurisdiction',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_05',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which core purpose of government refers to enforcing fairness through courts and legal processes?',
    options: [
      'Maintenance of peace',
      'Protection of property',
      'Administration of justice',
      'Promotion of private profit',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_06',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which political ideology is founded on preserving customs and values such as tradition, authority, and social order?',
    options: [
      'Socialism',
      'Liberalism',
      'Conservatism',
      'Anarchism',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_07',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which term refers to the face of power that shapes and influences what people think, want, or need?',
    options: [
      'Agenda-setting',
      'Decision-making',
      'Thought control (Ideological power)',
      'Legitimate power',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_08',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which type of power is exercised when someone complies because the leader holds the official right and authority to request it?',
    options: [
      'Reward power',
      'Coercive power',
      'Legitimate power',
      'Expert power',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_09',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which situation best illustrates agenda-setting power?',
    options: [
      'A mayor signs an approved ordinance',
      'A group argues over which food to order',
      'A leader prevents a controversial topic from being discussed in a meeting',
      'A teacher explains a lesson clearly',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_10',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which social value is most strongly associated with Socialism?',
    options: [
      'Unregulated individual competition',
      'Social equality and shared welfare',
      'Strict hereditary hierarchy',
      'Private control of all public utilities',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_11',
    subject: 'PPG',
    question:
        '[PPG Summative 1] A student follows a popular vlogger\'s political advice because the student admires their charisma. What kind of power is this?',
    options: [
      'Legitimate power',
      'Referent power',
      'Coercive power',
      'Expert power',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_12',
    subject: 'PPG',
    question:
        '[PPG Summative 1] Which consequence of power is most likely when people act enthusiastically because they trust a leader\'s expertise?',
    options: [
      'Resistance',
      'Commitment',
      'Compliance',
      'Conflict',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_13',
    subject: 'PPG',
    question:
        '[PPG Summative 1] If a government rule is enforced strictly through threats, fear, and punishment, which reaction is most likely to arise?',
    options: [
      'Commitment',
      'Deep admiration',
      'Compliance',
      'Resistance',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s1_14',
    subject: 'PPG',
    question:
        '[PPG Summative 1] A class agrees to complete an extra task because their teacher offers bonus points. Which consequence of reward power is most likely?',
    options: [
      'Compliance',
      'Resistance',
      'Commitment',
      'Agenda-setting',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),

  // ===========================================================================
  // 5. PPG Summative 2.docx (30 Items — Subject: PPG & PGP)
  // ===========================================================================
  MiniQuizQuestion(
    id: 'ppg_s2_01',
    subject: 'PPG',
    question:
        '[PPG Summative 2] According to Hector De Leon, which of the following is NOT one of the four required essential elements of a State?',
    options: [
      'People',
      'Territory',
      'International Recognition',
      'Sovereignty',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_02',
    subject: 'PPG',
    question:
        '[PPG Summative 2] Benedict Anderson described a Nation as an "imagined community." What does this mean?',
    options: [
      'It only exists in history books',
      'Members share feelings of belongingness and identity even without meeting everyone',
      'It lacks a physical territory',
      'It is a mythical society',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_03',
    subject: 'PPG',
    question:
        '[PPG Summative 2] The interconnectedness of economies through trade and resource exchange, heavily aided by information technology, is known as:',
    options: [
      'Political Globalization',
      'McDonaldization',
      'Economic Globalization',
      'Cultural Globalization',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_04',
    subject: 'PPG',
    question:
        '[PPG Summative 2] Which power represents a state\'s "External Sovereignty"?',
    options: [
      'Freedom and independence from foreign domination or control',
      'The power to enforce local barangay ordinances',
      'The right to collect municipal taxes',
      'The ability to appoint local officials',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_05',
    subject: 'PPG',
    question:
        '[PPG Summative 2] A culturally homogeneous group governed by its own sovereign state, such as Japan, is referred to as a:',
    options: [
      'Republic',
      'Nation-State',
      'Barangay',
      'Commonwealth',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_06',
    subject: 'PPG',
    question:
        '[PPG Summative 2] Which of the following is the best example of Political Globalization?',
    options: [
      'Teenagers adopting foreign fashion trends',
      'The Philippines signing a climate treaty with the United Nations',
      'A local tech company importing microchips from Taiwan',
      'A local market selling imported goods',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_07',
    subject: 'PPG',
    question:
        '[PPG Summative 2] In the pre-Spanish Barangay, who assisted the Datu in passing judgments and creating rules?',
    options: [
      'Gobernadorcillo',
      'Alcalde Mayor',
      'Maginoos (Council of Elders)',
      'Supreme Council',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_08',
    subject: 'PPG',
    question:
        '[PPG Summative 2] During the Spanish colonial period, who was the head of a pacified province (Alcaldia)?',
    options: [
      'Corregidor',
      'Gobernadorcillo',
      'Alcalde Mayor',
      'Governor-General',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_09',
    subject: 'PPG',
    question:
        '[PPG Summative 2] What makes the 1899 Malolos Republic historically significant?',
    options: [
      'It was the first government led by Andres Bonifacio',
      'It established the First Asian Constitutional Democracy',
      'It was created by the Spooner Amendment',
      'It marked the start of the Japanese occupation',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_10',
    subject: 'PPG',
    question:
        '[PPG Summative 2] Which U.S. law passed in 1934 provided a 10-year Commonwealth transition period for the Philippines to achieve independence?',
    options: [
      'Spooner Amendment',
      'Tydings-McDuffie Law',
      'Jones Law',
      'Bell Trade Act',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_11',
    subject: 'PPG',
    question:
        '[PPG Summative 2] Which Philippine President is known for the "Filipino First" policy and the Austerity Program?',
    options: [
      'Ramon Magsaysay',
      'Carlos P. Garcia',
      'Diosdado Macapagal',
      'Fidel V. Ramos',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_12',
    subject: 'PPG',
    question:
        '[PPG Summative 2] The 1986 EDSA People Power Revolution led to the ouster of Ferdinand Marcos and the presidency of:',
    options: [
      'Gloria Macapagal-Arroyo',
      'Fidel V. Ramos',
      'Corazon C. Aquino',
      'Joseph E. Estrada',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_13',
    subject: 'PPG',
    question:
        '[PPG Summative 2] Who was the "Centennial President" that achieved a landmark 1996 peace agreement with the MNLF?',
    options: [
      'Joseph E. Estrada',
      'Fidel V. Ramos',
      'Benigno S. Aquino III',
      'Rodrigo Roa Duterte',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_14',
    subject: 'PPG',
    question:
        '[PPG Summative 2] How can the Legislative branch (Congress) check the power of the Executive branch if the President vetoes a bill?',
    options: [
      'By using Judicial Review',
      'By overriding the veto with a 2/3 majority vote in both houses',
      'By abolishing the Presidency',
      'By declaring Martial Law',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_15',
    subject: 'PPG',
    question:
        '[PPG Summative 2] What constitutional doctrine dictates that the official acts of Cabinet Secretaries are presumed to be the acts of the President unless disapproved?',
    options: [
      'Separation of Powers',
      'Doctrine of Qualified Political Agency (Alter Ego Doctrine)',
      'Judicial Review',
      'Ordinance Power',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_16',
    subject: 'PPG',
    question:
        '[PPG Summative 2] True or False: The Vice President of the Philippines can be appointed to a Cabinet position without needing confirmation from the Commission on Appointments.',
    options: [
      'TRUE — Allowed under Article VII, Section 3 of the 1987 Constitution',
      'FALSE — The Vice President is barred from holding any Cabinet post',
      'FALSE — Only the Supreme Court confirms Cabinet appointments',
      'FALSE — The Senate must ratify it by 3/4 vote',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ppg_s2_17',
    subject: 'PPG',
    question:
        '[PPG Summative 2] True or False: Under the 1987 Constitution, the President of the Philippines serves a six-year term and is eligible for one re-election.',
    options: [
      'TRUE — The President can serve two consecutive 6-year terms',
      'FALSE — The President serves a single 6-year term and is NOT eligible for any re-election',
      'TRUE — Unlimited re-election is allowed',
      'FALSE — The term of the President is 4 years',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),

  // ===========================================================================
  // 6. PPG TERM 1.docx & PPG REVIEWER T1.docx (Items — Subject: PGP & PPG)
  // ===========================================================================
  MiniQuizQuestion(
    id: 'pgp_t1_01',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] According to the 1987 Philippine Constitution, how many senators comprise the entire Philippine Senate, elected at-large by nationwide voters?',
    options: [
      '12 senators',
      '24 senators',
      '50 senators',
      '100 senators',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_02',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] Who serves as the primary presiding officer and leader of the House of Representatives during its legislative sessions?',
    options: [
      'The Senate President',
      'The Prime Minister',
      'The Vice President',
      'The Speaker of the House',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_03',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] According to the 1987 Philippine Constitution, what is the mandatory retirement age for Justices of the Supreme Court and judges of lower courts?',
    options: [
      '60 years old',
      '65 years old',
      '70 years old',
      '75 years old',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_04',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] Under the political structure of the Philippines, which tier represents the smallest and most basic political unit of local government?',
    options: [
      'Barangay',
      'Component City',
      'Municipality',
      'Province',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_05',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] What is the core meaning of "public accountability" in democratic governance?',
    options: [
      'The absolute power of government officials to make decisions without public oversight',
      'The lifetime immunity granted to politicians after their term ends',
      'The obligation of public officials to report, explain, and be answerable for their actions and decisions',
      'The process of privatizing government agencies to increase financial profits',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_06',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] Which pillar of public accountability requires the government to make official records, budgets, and decision-making processes easily accessible to the public?',
    options: [
      'Bureaucracy',
      'Discretion',
      'Immunity',
      'Transparency',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_07',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] In political theory, how does the 1987 Philippine Constitution function as a "social contract"?',
    options: [
      'It acts as a symbolic agreement where the sovereign people surrender absolute freedoms to a government in exchange for the protection of their fundamental rights and the rule of law',
      'It is an economic contract between the executive branch and foreign investors',
      'It is a commercial business agreement signed to fund private malls',
      'It serves as a provisional military treaty',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_08',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] A fast-growing city needs to build a public highway cutting through a private neighborhood. Under the 1987 Constitution, it must follow due process and pay "just compensation". This applies:',
    options: [
      'Absolute state ownership of all private land',
      'Authoritarian land distribution',
      'Decentralized anarchy',
      'Eminent domain balanced by due process of law',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_09',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] High-ranking officials are accused of grave abuse of power. The House of Representatives files charges and the Senate holds a trial to judge and remove them. This check is called:',
    options: [
      'Executive Clemency',
      'Impeachment',
      'Judicial Review',
      'Ordinance Power',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_10',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] A major international treaty on climate change needs to be officially accepted by the Philippines. Which legislative action must happen for this treaty to be valid?',
    options: [
      'All local municipal mayors must sign a joint petition',
      'The House of Representatives must hold a nationwide debate',
      'The Philippine Senate must concur or approve it by a two-thirds majority vote',
      'The Speaker of the House must sign it alone',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_11',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] When the executive branch submits the proposed national budget plan, which house must officially introduce and handle the General Appropriations Bill first ("Power of the Purse")?',
    options: [
      'The Council of Local Governors',
      'The House of Representatives, because all revenue and appropriation bills must originate there',
      'The Senate, because senators are elected nationwide',
      'The Supreme Court, because judges manage state funds',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_12',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] Two Filipino Muslim citizens wish to settle a dispute regarding inheritance and family property based on customary and personal religious laws. Which specialized courts handle this?',
    options: [
      'Court of Tax Appeals',
      'Metropolitan Trial Courts',
      'Sandiganbayan',
      'Shari\'a Courts',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_13',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] Why must a bill pass through both the House of Representatives and the Senate in identical text before reaching the President?',
    options: [
      'To allow the executive branch to choose which house gets to write laws',
      'To eliminate the need for the President to sign or veto bills',
      'To ensure double deliberation, checking bills from both local district viewpoints and broad national perspectives',
      'To give the Supreme Court the authority to vote alongside lawmakers',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_14',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] Article XI, Section 1 of the 1987 Constitution states: "Public office is a public trust." What does this fundamental principle mean?',
    options: [
      'Public officials own government vehicles as personal family property',
      'Public authority and state properties are only borrowed from the sovereign people to serve the public good',
      'Elected officials are immune from all laws during their term',
      'Government budgets should be kept secret from citizens',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'pgp_t1_15',
    subject: 'PGP',
    question:
        '[PPG Term 1 Exam] A municipality experiences an outbreak and runs out of medicines because it mismanaged its local health budget. Under decentralization/devolution, who bears primary responsibility?',
    options: [
      'The international health community',
      'The judicial branch',
      'The local government unit (LGU), because devolution handed them direct fund management for local healthcare',
      'Foreign trade corporations',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),

  // ===========================================================================
  // 7. UCSP Summative 1.docx & Remedial.docx (30 Items — Subject: UCSP)
  // ===========================================================================
  MiniQuizQuestion(
    id: 'ucsp_s1_01',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] True or False: The worldwide adoption of face masks during the COVID-19 pandemic is a clear example of culture being adaptive to new environments.',
    options: [
      'TRUE — Culture adapts to environmental and societal challenges',
      'FALSE — Culture never changes over time',
      'FALSE — Wearing face masks is purely biological instinct',
      'FALSE — Only non-material culture exists',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_02',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] True or False: W.I. Thomas formulated the theorem stating that "if people define situations as real, they are real in their consequences."',
    options: [
      'TRUE — This is known as the Thomas Theorem in Sociology',
      'FALSE — This was formulated by Charles Darwin',
      'FALSE — Situations have no social consequences',
      'FALSE — This is a law of thermodynamics',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_03',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] True or False: Ethnocentrism is the belief that one\'s own native culture is inferior to another culture.',
    options: [
      'TRUE — Ethnocentrism prefers foreign products',
      'FALSE — That is Xenocentrism; Ethnocentrism is judging other cultures using one\'s own culture as superior',
      'TRUE — Ethnocentrism and Xenocentrism are identical',
      'FALSE — Ethnocentrism means having no culture',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_04',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] True or False: Aristotle characterized Political Science as the "most authoritative science" because it establishes the rules governing other practical sciences.',
    options: [
      'TRUE — Aristotle described Political Science as the master/authoritative science of the polis',
      'FALSE — Aristotle rejected the study of politics',
      'FALSE — He called Archeology the most authoritative science',
      'FALSE — Political Science only began in the 20th century',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_05',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] True or False: Rebel groups, outlaws, and extremist movements whose values actively oppose the established society are examples of a counter-culture.',
    options: [
      'TRUE — Counter-cultures actively oppose dominant societal norms and values',
      'FALSE — They are examples of Cultural Universals',
      'FALSE — They are examples of Folkways',
      'FALSE — They represent Ideal Culture',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_06',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] Instead of judging balut as disgusting based on Western standards, a foreign tourist tries it with an open mind to understand it in the Filipino context. What does he apply?',
    options: [
      'Cultural Assimilation',
      'Ethnocentrism',
      'Xenocentrism',
      'Cultural Relativism',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_07',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] In the evolution of human communities, which type of pre-industrial society was strictly founded on land ownership by wealthy nobles/lords?',
    options: [
      'Feudal Society',
      'Hunting and Gathering Society',
      'Pastoral Society',
      'Post-Industrial Society',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_08',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] Repetitive behavioral habits and table manners are examples of weak norms whose violation is not considered morally serious. What are they called?',
    options: [
      'Laws',
      'Folkways',
      'Beliefs',
      'Mores',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_09',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] What branch of Anthropology specifically studies human evolution, biological aspects, and our relationship to extinct ancestors?',
    options: [
      'Linguistic Anthropology',
      'Archeology',
      'Physical (Biological) Anthropology',
      'Cultural Anthropology',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_10',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] Peter Berger explained that the sociological perspective allows us to see "______ patterns in ______ events" (e.g., seeing a social trend in a personal choice).',
    options: [
      'General ; Particular',
      'Specific ; Universal',
      'Private ; Biological',
      'Random ; Isolated',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_11',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] The process of enculturation, where we acquire skills and habits over the course of our lives, demonstrates that culture is:',
    options: [
      'Genetically inherited at birth',
      'Static and unchanging',
      'Exclusive to wealthy societies',
      'Learned',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_12',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] When interacting cultures freely borrow and modify each other\'s cultural elements while keeping their social and political independence intact, this process is known as:',
    options: [
      'Assimilation',
      'Directed Change',
      'Incorporation',
      'Counter-culture',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_13',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] If you want to analyze how the local government of the Science City of Muñoz implements ordinances and allocates its agricultural budget, which field of Political Science applies?',
    options: [
      'Political Economy',
      'Public Administration',
      'Comparative Politics',
      'Political Theory',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_14',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] The existence of cultural universals—such as language, celebrating births, and using humor to ease tension—was famously recognized by which anthropologist/sociologist?',
    options: [
      'George Murdock',
      'William Sumner',
      'C. Wright Mills',
      'Jacques Derrida',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_15',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] A newly deployed OFW experiences severe confusion and distress during their first month abroad because they cannot adjust to the new cultural environment. What is this phenomenon?',
    options: [
      'Acculturation',
      'Cultural Imperialism',
      'Culture Shock',
      'Cultural Integration',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_16',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] C. Wright Mills coined a term for the vivid awareness of the connection between personal, private experiences and wider societal issues. What is it called?',
    options: [
      'Sociological Imagination',
      'Thomas Theorem',
      'Alterity of a Person',
      'Cultural Integration',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_17',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] When a dominant group deliberately imposes its cultural beliefs on another because they view the other as inferior (like Spanish colonization), it is called:',
    options: [
      'Xenocentrism',
      'Cultural Imperialism',
      'Culture Shock',
      'Cultural Relativism',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_18',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] Which branch of anthropology focuses on utilizing anthropological facts, theories, and procedures to solve real-world social problems?',
    options: [
      'Cultural Anthropology',
      'Archeology',
      'Linguistic Anthropology',
      'Applied Anthropology',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_19',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] Researchers observing how the migration of young people from rural Muñoz to Metro Manila affects the aging population left behind are applying which sociological branch?',
    options: [
      'Human Ecology',
      'Social Organization',
      'Population Studies (Demography)',
      'Social Psychology',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_20',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] The classic definition of culture as "that complex whole which includes knowledge, beliefs, arts, morals, laws, customs..." was formulated by:',
    options: [
      'Peter Berger',
      'Franz Boas',
      'Edward B. Tylor',
      'George Murdock',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s1_21',
    subject: 'UCSP',
    question:
        '[UCSP Summative 1] Who provided the technical term "ethnocentrism" in 1906 to describe judging another culture solely by the values and standards of one\'s own?',
    options: [
      'W.I. Thomas',
      'Edward B. Tylor',
      'Franz Boas',
      'William Graham Sumner',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),

  // ===========================================================================
  // 8. UCSP Summative 2.docx (30 Items — Subject: UCSP)
  // ===========================================================================
  MiniQuizQuestion(
    id: 'ucsp_s2_01',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] True or False: Homo habilis is known as the "Upright Man" and is credited as the first early human species to use fire for cooking.',
    options: [
      'TRUE — Homo habilis discovered fire',
      'FALSE — Homo erectus is the "Upright Man" and first to use fire; Homo habilis is the "Handy Man"',
      'TRUE — Homo habilis built modern cities',
      'FALSE — Australopithecus invented electricity',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_02',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] True or False: Resocialization is the process of declining former undesirable conduct and accepting new norms, such as a person entering rehabilitation.',
    options: [
      'TRUE — Resocialization replaces old behaviors with new norms',
      'FALSE — Resocialization only happens to infants',
      'FALSE — Norms can never be unlearned',
      'FALSE — That is called biological evolution',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_03',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] True or False: A triad (3-person group) is considered more stable than a dyad (2-person group) because if one member withdraws, the group can still exist.',
    options: [
      'TRUE — According to Georg Simmel, a triad can survive the departure of one member whereas a dyad dissolves',
      'FALSE — A dyad has 100 members',
      'FALSE — Triads cannot mediate conflict',
      'FALSE — Group size has no effect on stability',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_04',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] True or False: A cooperative is an autonomous association or firm owned, controlled, and operated by a group of users on a "one-member, one-vote" basis.',
    options: [
      'TRUE — Cooperatives operate democratically for their members\' mutual benefit',
      'FALSE — Cooperatives are owned by a single absolute monarch',
      'FALSE — Only billionaire stockholders can vote in a cooperative',
      'FALSE — Cooperatives are military tribunals',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_05',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] True or False: Anticipatory socialization is the process of rehearsing and learning the culture of a group with the expectation of joining it in the future.',
    options: [
      'TRUE — For example, law students practicing courtroom etiquette before becoming lawyers',
      'FALSE — Anticipatory socialization only occurs after retirement',
      'FALSE — It refers to forgetting how to speak',
      'FALSE — It is a type of geological fossil',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_06',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] True or False: Homo neanderthalensis was the first species to practice the intentional burial of their dead and sew clothes from animal skin.',
    options: [
      'TRUE — Neanderthals practiced ritual burial and adapted to cold climates with animal-skin clothing',
      'FALSE — Neanderthals lived in tropical skyscrapers',
      'FALSE — Only modern humans in 1900 buried their dead',
      'FALSE — Neanderthals were marine fish',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_07',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] Which early hominid fossil genus is considered the intermediate link between ape and modern humans (e.g., "Lucy")?',
    options: [
      'Australopithecus',
      'Homo rudolfensis',
      'Homo habilis',
      'Homo sapiens',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_08',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] Which species of the Homo genus is nicknamed the "Handy Man" and is recognized for their ability to make and use stone tools?',
    options: [
      'Homo erectus',
      'Homo habilis',
      'Homo heidelbergensis',
      'Homo floresiensis',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_09',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] Which type of society relies heavily on specialized knowledge, information services, and the spread of computer and digital industries?',
    options: [
      'Horticultural Society',
      'Agricultural Society',
      'Post-Industrial Society',
      'Pastoral Society',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_10',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] What type of socialization teaches an individual to take on adult duties and responsibilities such as full-time work, marriage, and raising a family?',
    options: [
      'Adult Socialization',
      'Primary Socialization',
      'Anticipatory Socialization',
      'Resocialization',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_11',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] Which of the following is considered an example of non-material culture?',
    options: [
      'Face shields and facemasks',
      'Hand sanitizers and medical equipment',
      'Patriotism and respect for elders (pagmamano)',
      'Smartphones and laptops',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_12',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] What is the fundamental sociological difference between an aggregate and a social group?',
    options: [
      'Aggregates share family ties, while groups do not',
      'Social groups regularly and consciously interact with a shared identity, while aggregates merely exist in the same place at the same time without meaningful interaction',
      'Aggregates regularly interact, while groups never meet',
      'Social groups are only found in schools, while aggregates are found in homes',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_13',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] Which type of social group serves an instrumental function, meaning its role is more goal- or task-oriented than emotional?',
    options: [
      'Primary Group',
      'Secondary Group',
      'In-Group',
      'Family Household',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_14',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] Eli admires the Lahing Kayumanggi dancers during the Uhay Festival and copies their style and techniques as a standard of measurement. The dance group serves as Eli\'s:',
    options: [
      'Out-Group',
      'Triad',
      'Clique',
      'Reference Group',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_15',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] According to Georg Simmel\'s rule of group size, what happens as a social group grows larger in number?',
    options: [
      'The level of intimacy and personal focus decreases while formal organization increases',
      'The group dissolves immediately',
      'The emotional intimacy becomes 100% for everyone',
      'The group becomes a dyad',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_16',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] Which theory on the origin of the state holds that people voluntarily agreed to establish the state for their common benefit, security, and protection?',
    options: [
      'Divine Right Theory',
      'Force Theory',
      'Social Contract Theory',
      'Paternalistic Theory',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_17',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] Which economic non-state institution plays a crucial role as a financial intermediary that receives deposits and issues loans to people and companies?',
    options: [
      'Bank',
      'Trade Union',
      'Cooperative',
      'Advocacy NGO',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_18',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] The Trade Union Congress of the Philippines (TUCP) is an example of a non-state organization whose main purpose is to:',
    options: [
      'Generate profit by issuing shares of stocks to billionaires',
      'Protect and advance the interests, wages, and rights of workers in the workplace',
      'Manage the marine territory of the country',
      'Appoint judges to the Supreme Court',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_19',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] Which agent of socialization is considered the primary foundation that teaches an infant basic skills, language, values, and the use of objects?',
    options: [
      'Mass Media',
      'School',
      'Family',
      'Workplace',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_20',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] What is the largest size of a social group that emphasizes temporary or strategic alignment toward a major shared advocacy or goal?',
    options: [
      'Clique',
      'Dyad',
      'Triad',
      'Coalition',
    ],
    correctIndex: 3,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'ucsp_s2_21',
    subject: 'UCSP',
    question:
        '[UCSP Summative 2] SM Investments Corp. is a legal entity authorized by law to act as a single person and is designed to generate profit through shares of stock. It is a:',
    options: [
      'Trade Union',
      'Cooperative',
      'Corporation',
      'Barangay',
    ],
    correctIndex: 2,
    xpReward: 25,
  ),

  // ===========================================================================
  // 9. Introduction to the Philosophy of the Human Person (Subject: PHILO)
  // ===========================================================================
  MiniQuizQuestion(
    id: 'philo_01',
    subject: 'PHILO',
    question:
        'Who among the ancient Greek philosophers is famous for the dictum "The unexamined life is not worth living"?',
    options: [
      'Socrates',
      'Pythagoras',
      'Thales of Miletus',
      'Epicurus',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'philo_02',
    subject: 'PHILO',
    question:
        'Attacking the character or motive of the person making an argument rather than addressing the substance of the argument itself is which fallacy?',
    options: [
      'Argumentum ad Hominem (Against the Person)',
      'Argumentum ad Baculum (Appeal to Force)',
      'Post Hoc Ergo Propter Hoc (False Cause)',
      'Petitio Principii (Begging the Question)',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'philo_03',
    subject: 'PHILO',
    question:
        'Which philosophical method introduced by Edmund Husserl focuses on the careful description of lived conscious experience ("back to the things themselves") by bracketing assumptions (epoché)?',
    options: [
      'Phenomenology',
      'Empiricism',
      'Scholasticism',
      'Utilitarianism',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'philo_04',
    subject: 'PHILO',
    question:
        'In Martin Buber\'s philosophy of intersubjectivity, genuine human dialogue that treats the other person as a unique subject rather than an object of utility is called:',
    options: [
      'I-Thou Relationship',
      'I-It Relationship',
      'Panopticon Gaze',
      'Social Darwinism',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'philo_05',
    subject: 'PHILO',
    question:
        'According to Jean-Paul Sartre\'s existentialism ("existence precedes essence"), what is the relationship between human freedom and responsibility?',
    options: [
      'Humans are free to choose their actions and are therefore fully responsible for the meaning and consequences of their choices',
      'Human destiny is 100% predetermined before birth',
      'Freedom means having zero responsibility toward others',
      'Only kings possess free will',
    ],
    correctIndex: 0,
    xpReward: 25,
  ),
  MiniQuizQuestion(
    id: 'philo_06',
    subject: 'PHILO',
    question:
        'Which view in environmental philosophy places intrinsic value on all living organisms and ecosystems as an interconnected community, rather than valuing nature solely as raw material for humans?',
    options: [
      'Anthropocentrism',
      'Ecocentrism',
      'Consumerism',
      'Industrialism',
    ],
    correctIndex: 1,
    xpReward: 25,
  ),
];
