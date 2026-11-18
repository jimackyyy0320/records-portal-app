import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/portal_models.dart';
import 'lobby_audio_service.dart';
import 'lobby_data_service.dart';
import 'pixelfx_engine.dart';
import 'sovereign_story_data.dart';

enum _StoryShellState {
  title,
  overworld,
  battle,
  saligangTala,
  paused,
  altarVictory,
}

/// Floating combat/XP feedback text (`craft-game-floors` Game Feel Floor:
/// rises and fades over 0.65s).
class _FloatingJuiceText {
  final String text;
  final Color color;
  final Offset normalizedPos;
  double progress = 0.0;

  _FloatingJuiceText({
    required this.text,
    required this.color,
    required this.normalizedPos,
  });
}

/// **Chronicles of the Sovereign: A LeafGreen-Style RPG for Philippine Governance**
///
/// Triggered by stepping through the glowing bookshelf at the back of the 2D Virtual
/// School Lobby. Powered by the `patch-gg/pixelfx` procedural code-only pixel VFX engine.
class SovereignStoryScreen extends StatefulWidget {
  final UserSession session;
  final String playerNickname;

  const SovereignStoryScreen({
    super.key,
    required this.session,
    required this.playerNickname,
  });

  @override
  State<SovereignStoryScreen> createState() => _SovereignStoryScreenState();
}

class _SovereignStoryScreenState extends State<SovereignStoryScreen> {
  final FocusNode _focusNode = FocusNode();

  _StoryShellState _shellState = _StoryShellState.title;
  SovereignCampaignSave _save = const SovereignCampaignSave();
  bool _loadingSave = true;

  // Overworld state (20 cols × 14 rows of 16×16 pixel tiles)
  int _actIndex = 0; // 0..6 (Act I .. Act VII)
  int _alonCol = 5;
  int _alonRow = 11;
  String _alonFacing = 'up';
  int _stepAnimFrame = 0;
  double _idleTime = 0.0;

  // Rival Mateo `[!]` alert state
  String? _alertedRivalEntityId;
  double _rivalAlertTimer = 0.0;

  // Active Dialogue queue (Lolo Amado Radio, NPCs, Puzzle Nodes, Pre-Battle)
  String? _dialogueSpeaker;
  String? _dialogueSubtitle;
  int _dialogueColor = 0xFFFACC15;
  List<String> _dialogueQueue = const <String>[];
  int _dialogueIndex = 0;
  VoidCallback? _onDialogueComplete;

  // Screen-flashing GBA swirl transition overlay (`0..1`)
  double _swirlTransitionProgress = 1.0; // Starts with entry swirl!
  bool _swirlActive = true;

  // `patch-gg/pixelfx` frame buffers & controllers
  late final PixelFxFrame _overworldFxFrame = createFrame(160, 112);
  late final PixelFxFrame _battleFxFrame = createFrame(160, 96);
  late final PixelFxFrame _swirlFxFrame = createFrame(120, 84);

  late PixelFxController _ambientFxCtrl;
  late PixelFxController _unrestFxCtrl;
  late PixelFxController _swirlFxCtrl;
  PixelFxController? _overworldBurstFxCtrl;
  PixelFxController? _battleActiveFxCtrl;

  // Turn-Based Debate Battle state
  DebateOpponentSpec? _activeOpponent;
  String? _activeOpponentEntityId;
  bool _isBossBattle = false;
  int _opponentDoubtRemaining = 100; // Depletes to 0 to win!
  int _questionCursor = 0;
  final Map<String, int> _doctrinePpRemaining = <String, int>{};
  LegalDoctrineMove? _pendingDoctrineMove;
  bool _awaitingQuestionAnswer = false;
  String _battleLogMessage = '';
  bool _battleBusy = false;
  double _battleScreenShake = 0.0;
  double _milestoneFlashAlpha = 0.0;
  String? _milestoneBannerText;
  final List<_FloatingJuiceText> _floatingTexts = <_FloatingJuiceText>[];

  Timer? _tickTimer;

  SovereignActConfig get _currentAct => kSovereignActs[_actIndex];

  @override
  void initState() {
    super.initState();
    _initDoctrinePp();
    _ambientFxCtrl = createFx(
      PixelFxPreset.ambientCampusMotes,
      const PixelFxOptions(x: 80, y: 56, seed: 101),
    );
    _unrestFxCtrl = createFx(
      PixelFxPreset.unrestZoneRipples,
      const PixelFxOptions(x: 40, y: 40, seed: 202),
    );
    _swirlFxCtrl = createFx(
      PixelFxPreset.gbaBattleSwirl,
      const PixelFxOptions(x: 60, y: 42, seed: 777),
    );

    LobbyAudioService.instance.playGbaEncounterSwirl();
    _loadCampaignProgress();

    _tickTimer = Timer.periodic(
      const Duration(milliseconds: 33),
      (_) => _onTick(0.033),
    );
  }

  void _initDoctrinePp() {
    for (final m in kAlonDoctrineMoves) {
      _doctrinePpRemaining[m.id] = m.maxPp;
    }
  }

  Future<void> _loadCampaignProgress() async {
    final loaded = await SovereignCampaignSave.load(widget.session.id);
    if (!mounted) return;
    setState(() {
      _save = loaded;
      _actIndex = (loaded.currentActNumber - 1).clamp(0, kSovereignActs.length - 1);
      _alonCol = _currentAct.spawnCol;
      _alonRow = _currentAct.spawnRow;
      _alonFacing = 'up';
      _loadingSave = false;
    });
    _syncActAmbientFx();
  }

  void _syncActAmbientFx() {
    _ambientFxCtrl = createFx(
      _currentAct.palette.ambientFx,
      PixelFxOptions(
        x: 80,
        y: 56,
        seed: _currentAct.actNumber * 997,
      ),
    );
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    _focusNode.dispose();
    super.dispose();
  }

  void _triggerGbaSwirlTransition([VoidCallback? onMidSwirl]) {
    LobbyAudioService.instance.playGbaEncounterSwirl();
    HapticFeedback.mediumImpact();
    setState(() {
      _swirlActive = true;
      _swirlTransitionProgress = 0.0;
      _swirlFxCtrl.restart(DateTime.now().millisecondsSinceEpoch & 0xFFFF);
    });
    if (onMidSwirl != null) {
      Future.delayed(const Duration(milliseconds: 320), () {
        if (mounted) onMidSwirl();
      });
    }
  }

  void _onTick(double dt) {
    if (!mounted || _loadingSave) return;
    if (_shellState == _StoryShellState.paused) return;

    _idleTime += dt;
    _ambientFxCtrl.update(dt);
    _unrestFxCtrl.update(dt);

    if (_swirlActive) {
      _swirlFxCtrl.update(dt);
      _swirlTransitionProgress += dt * 1.45;
      if (_swirlTransitionProgress >= 1.0) {
        _swirlTransitionProgress = 1.0;
        _swirlActive = false;
      }
    }

    if (_overworldBurstFxCtrl != null) {
      _overworldBurstFxCtrl!.update(dt);
      if (_overworldBurstFxCtrl!.isFinished) {
        _overworldBurstFxCtrl = null;
      }
    }

    if (_battleActiveFxCtrl != null) {
      _battleActiveFxCtrl!.update(dt);
      if (_battleActiveFxCtrl!.isFinished) {
        _battleActiveFxCtrl = null;
      }
    }

    if (_battleScreenShake > 0) {
      _battleScreenShake = math.max(0.0, _battleScreenShake - dt * 18.0);
    }

    if (_milestoneFlashAlpha > 0) {
      _milestoneFlashAlpha = math.max(0.0, _milestoneFlashAlpha - dt * 2.5);
    }

    for (var i = _floatingTexts.length - 1; i >= 0; i--) {
      _floatingTexts[i].progress += dt * 1.5;
      if (_floatingTexts[i].progress >= 1.0) {
        _floatingTexts.removeAt(i);
      }
    }

    if (_rivalAlertTimer > 0) {
      _rivalAlertTimer = math.max(0.0, _rivalAlertTimer - dt);
      if (_rivalAlertTimer <= 0 && _alertedRivalEntityId != null) {
        final rivalId = _alertedRivalEntityId!;
        _alertedRivalEntityId = null;
        final entity = _currentAct.entities
            .where((e) => e.id == rivalId)
            .firstOrNull;
        if (entity != null) {
          _interactWithEntity(entity);
        }
      }
    }

    setState(() {});
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  OVERWORLD NAVIGATION, RIVAL `[!]` LINE-OF-SIGHT & INTERACTIONS
  // ─────────────────────────────────────────────────────────────────────────

  void _startAct(int index, {bool showLoloAmadoIntro = true}) {
    final targetIdx = index.clamp(0, kSovereignActs.length - 1);
    _triggerGbaSwirlTransition(() {
      setState(() {
        _actIndex = targetIdx;
        _alonCol = _currentAct.spawnCol;
        _alonRow = _currentAct.spawnRow;
        _alonFacing = 'up';
        _shellState = _StoryShellState.overworld;
        _alertedRivalEntityId = null;
      });
      _syncActAmbientFx();
      _save = _save.copyWith(currentActNumber: _currentAct.actNumber);
      unawaited(_save.persist(widget.session.id));

      if (showLoloAmadoIntro) {
        _showDialogue(
          speaker: 'Lolo Amado (Pocket Radio)',
          subtitle: '${_currentAct.romanNumeral}: ${_currentAct.zoneTitle} (${_currentAct.yearSpan})',
          color: _currentAct.charterSealColor,
          lines: <String>[
            _currentAct.loloAmadoRadioIntro,
            '🦜 Umalo the Tarsier unfurls his bamboo scroll: "Equipped ${_currentAct.alonAttireName}! Solve the Tribunal puzzle nodes to face the Era Leader!"',
          ],
        );
      }
    });
  }

  String _tileAt(int col, int row) {
    final map = _currentAct.asciiMap;
    if (row < 0 || row >= map.length) return '#';
    final line = map[row];
    if (col < 0 || col >= line.length) return '#';
    return line[col];
  }

  SovereignMapEntity? _entityAt(int col, int row) {
    for (final e in _currentAct.entities) {
      if (e.col == col && e.row == row) {
        // Hide Rival Mateo if already defeated in this Act
        if (e.role == 'rival' && _save.defeatedEntityIds.contains(e.id)) {
          continue;
        }
        return e;
      }
    }
    return null;
  }

  bool _areAllActPuzzleNodesSolved(SovereignActConfig act) {
    final nodes = act.entities.where((e) => e.role == 'puzzle_node');
    for (final n in nodes) {
      if (!_save.activatedPuzzleNodeIds.contains(n.id)) {
        return false;
      }
    }
    return true;
  }

  void _moveAlon(int dCol, int dRow, String facing) {
    if (_shellState != _StoryShellState.overworld) return;
    if (_dialogueQueue.isNotEmpty || _rivalAlertTimer > 0 || _swirlActive) {
      return;
    }

    setState(() {
      _alonFacing = facing;
      _stepAnimFrame = (_stepAnimFrame + 1) % 4;
    });

    final nextCol = _alonCol + dCol;
    final nextRow = _alonRow + dRow;

    // If an NPC/Boss/Node stands on the target tile, interact with them directly!
    final blockingEntity = _entityAt(nextCol, nextRow);
    if (blockingEntity != null) {
      _interactWithEntity(blockingEntity);
      return;
    }

    final tile = _tileAt(nextCol, nextRow);
    if (tile == '#' || tile == '~') {
      HapticFeedback.selectionClick();
      return;
    }

    // Check Tribunal Hall ('T') puzzle lock
    if (tile == 'T' && !_areAllActPuzzleNodesSolved(_currentAct)) {
      LobbyAudioService.instance.playQuizWrong();
      _showDialogue(
        speaker: 'Tribunal Hall Gate (Locked)',
        subtitle: _currentAct.zoneTitle,
        color: 0xFFF59E0B,
        lines: <String>[
          '🔒 The Tribunal Hall is sealed! ${_currentAct.tribunalPuzzleHint}',
        ],
      );
      return;
    }

    LobbyAudioService.instance.playStep();
    setState(() {
      _alonCol = nextCol;
      _alonRow = nextRow;
    });

    // 1. Check if Rival Mateo spots Alon within 4 tiles (`[!]` GBA Line-of-Sight)!
    for (final e in _currentAct.entities) {
      if (e.role == 'rival' && !_save.defeatedEntityIds.contains(e.id)) {
        final dist = (e.col - _alonCol).abs() + (e.row - _alonRow).abs();
        final aligned = e.col == _alonCol || e.row == _alonRow;
        if ((aligned && dist <= 4) || dist <= 2) {
          LobbyAudioService.instance.playGbaEncounterSwirl();
          HapticFeedback.heavyImpact();
          setState(() {
            _alertedRivalEntityId = e.id;
            _rivalAlertTimer = 0.85;
            _overworldBurstFxCtrl = createFx(
              PixelFxPreset.rivalExclamationPop,
              PixelFxOptions(
                x: (e.col * 8 + 4).toDouble(),
                y: (e.row * 8 + 4).toDouble(),
                seed: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
              ),
            );
          });
          return;
        }
      }
    }

    // 2. Check if stepping on a Bahay-Pulungan ('B') tile
    if (tile == 'B') {
      final bahayNpc = _currentAct.entities
          .where((e) => e.role == 'bahay_historian')
          .firstOrNull;
      if (bahayNpc != null) {
        _interactWithEntity(bahayNpc);
        return;
      }
    }

    // 3. Check if stepping in an Unrest Zone ('U' — LeafGreen Tall Grass equivalent)
    if (tile == 'U') {
      final roll = (DateTime.now().millisecondsSinceEpoch +
              _alonCol * 31 +
              _alonRow * 17) %
          100;
      if (roll < 26) {
        _startDebateBattle(
          _currentAct.randomUnrestEncounter,
          isBoss: false,
        );
      }
    }
  }

  void _interactFacingOrNearest() {
    if (_shellState != _StoryShellState.overworld) return;
    if (_dialogueQueue.isNotEmpty) {
      _advanceDialogue();
      return;
    }

    var targetCol = _alonCol;
    var targetRow = _alonRow;
    switch (_alonFacing) {
      case 'up':
        targetRow--;
        break;
      case 'down':
        targetRow++;
        break;
      case 'left':
        targetCol--;
        break;
      case 'right':
        targetCol++;
        break;
    }

    var entity = _entityAt(targetCol, targetRow);
    if (entity == null) {
      // Search adjacent 1-tile radius for mobile convenience
      for (final e in _currentAct.entities) {
        if (e.role == 'rival' && _save.defeatedEntityIds.contains(e.id)) {
          continue;
        }
        final dist = (e.col - _alonCol).abs() + (e.row - _alonRow).abs();
        if (dist <= 2) {
          entity = e;
          break;
        }
      }
    }

    if (entity != null) {
      _interactWithEntity(entity);
    } else {
      // Lolo Amado quick radio check
      _showDialogue(
        speaker: 'Lolo Amado & Umalo (Status Check)',
        subtitle: '${_currentAct.romanNumeral} • ${_currentAct.zoneTitle}',
        color: _currentAct.charterSealColor,
        lines: <String>[
          _areAllActPuzzleNodesSolved(_currentAct)
              ? '📻 Lolo Amado: "All puzzle nodes in ${_currentAct.zoneTitle} are solved! Enter the Tribunal Hall at the north of the map to challenge the Era Leader!"'
              : '📻 Lolo Amado: "${_currentAct.tribunalPuzzleHint}"',
        ],
      );
    }
  }

  void _interactWithEntity(SovereignMapEntity entity) {
    HapticFeedback.selectionClick();

    // Unlock Saligang Tala entry if attached
    if (entity.unlocksSaligangTalaId != null) {
      final nextTala = Set<String>.from(_save.unlockedSaligangTalaIds)
        ..add(entity.unlocksSaligangTalaId!);
      _save = _save.copyWith(unlockedSaligangTalaIds: nextTala);
      unawaited(_save.persist(widget.session.id));
    }

    if (entity.role == 'bahay_historian') {
      LobbyAudioService.instance.playBahayPulunganHealChime();
      _initDoctrinePp();
      _save = _save.copyWith(civicResolveHp: _save.maxCivicResolveHp);
      unawaited(_save.persist(widget.session.id));
      setState(() {
        _overworldBurstFxCtrl = createFx(
          PixelFxPreset.bahayPulunganHeal,
          PixelFxOptions(
            x: (_alonCol * 8 + 4).toDouble(),
            y: (_alonRow * 8 + 4).toDouble(),
            seed: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
          ),
        );
        _floatingTexts.add(
          _FloatingJuiceText(
            text: '+FULL CIVIC RESOLVE!',
            color: const Color(0xFF34D399),
            normalizedPos: const Offset(0.5, 0.55),
          ),
        );
      });
      _showDialogue(
        speaker: entity.name,
        subtitle: 'Bahay-Pulungan Rest Stop (Civic Resolve Restored)',
        color: entity.color,
        lines: entity.dialogueLines,
      );
      return;
    }

    if (entity.role == 'puzzle_node') {
      LobbyAudioService.instance.playChestOpen();
      final nextNodes = Set<String>.from(_save.activatedPuzzleNodeIds)
        ..add(entity.id);
      _save = _save.copyWith(activatedPuzzleNodeIds: nextNodes);
      unawaited(_save.persist(widget.session.id));
      setState(() {
        _overworldBurstFxCtrl = createFx(
          PixelFxPreset.astrolabePulse,
          PixelFxOptions(
            x: (entity.col * 8 + 4).toDouble(),
            y: (entity.row * 8 + 4).toDouble(),
            seed: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
          ),
        );
        _floatingTexts.add(
          _FloatingJuiceText(
            text: '✨ ${_currentAct.puzzleNodeLabel.toUpperCase()} UNLOCKED!',
            color: const Color(0xFFFACC15),
            normalizedPos: const Offset(0.5, 0.45),
          ),
        );
      });
      _showDialogue(
        speaker: entity.name,
        subtitle: _currentAct.puzzleNodeLabel,
        color: entity.color,
        lines: entity.dialogueLines,
      );
      return;
    }

    if (entity.role == 'elite_four') {
      final stage = entity.eliteStageIndex ?? 1;
      if (stage > 1) {
        final prevStageEntity = _currentAct.entities
            .where((e) => e.eliteStageIndex == stage - 1)
            .firstOrNull;
        if (prevStageEntity != null &&
            !_save.defeatedEntityIds.contains(prevStageEntity.id)) {
          LobbyAudioService.instance.playQuizWrong();
          _showDialogue(
            speaker: entity.name,
            subtitle: '1986 Constitutional Commission Gauntlet',
            color: entity.color,
            lines: <String>[
              '🔒 Complete Debate Pillar ${stage - 1} (${prevStageEntity.name}) first before challenging Pillar $stage!',
            ],
          );
          return;
        }
      }
    }

    if (entity.role == 'boss') {
      if (!_areAllActPuzzleNodesSolved(_currentAct)) {
        LobbyAudioService.instance.playQuizWrong();
        _showDialogue(
          speaker: entity.name,
          subtitle: 'Tribunal Hall Prerequisite',
          color: entity.color,
          lines: <String>[
            '🔒 ${_currentAct.tribunalPuzzleHint}',
          ],
        );
        return;
      }
      // For Act VII Final Guardian, require Rival Mateo & Commissioners I, II, III first
      if (_currentAct.actNumber == 7) {
        for (final reqId in const [
          'act7_rival_mateo_final',
          'act7_elite_1_legislative',
          'act7_elite_2_executive',
          'act7_elite_3_judicial',
        ]) {
          if (!_save.defeatedEntityIds.contains(reqId)) {
            LobbyAudioService.instance.playQuizWrong();
            _showDialogue(
              speaker: entity.name,
              subtitle: 'Constitutional Commission Gauntlet',
              color: 0xFFFACC15,
              lines: const <String>[
                '🔒 Defeat Rival Mateo and all three Constitutional Commissioners (Legislative, Executive, and Judicial) before facing The Final Guardian!',
              ],
            );
            return;
          }
        }
      }
    }

    if (entity.battleSpec != null) {
      _showDialogue(
        speaker: entity.name,
        subtitle: entity.battleSpec!.title,
        color: entity.color,
        lines: entity.dialogueLines,
        onComplete: () {
          _startDebateBattle(
            entity.battleSpec!,
            entityId: entity.id,
            isBoss: entity.role == 'boss',
          );
        },
      );
      return;
    }

    _showDialogue(
      speaker: entity.name,
      subtitle: _currentAct.zoneTitle,
      color: entity.color,
      lines: entity.dialogueLines,
    );
  }

  void _showDialogue({
    required String speaker,
    required String subtitle,
    required int color,
    required List<String> lines,
    VoidCallback? onComplete,
  }) {
    setState(() {
      _dialogueSpeaker = speaker;
      _dialogueSubtitle = subtitle;
      _dialogueColor = color;
      _dialogueQueue = lines;
      _dialogueIndex = 0;
      _onDialogueComplete = onComplete;
    });
  }

  void _advanceDialogue() {
    HapticFeedback.selectionClick();
    LobbyAudioService.instance.playBubblePop();
    if (_dialogueIndex + 1 < _dialogueQueue.length) {
      setState(() {
        _dialogueIndex++;
      });
    } else {
      final callback = _onDialogueComplete;
      setState(() {
        _dialogueQueue = const <String>[];
        _dialogueIndex = 0;
        _onDialogueComplete = null;
      });
      callback?.call();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  TURN-BASED DEBATE BATTLE ENGINE (GBA LEAFGREEN + `patch-gg/pixelfx`)
  // ─────────────────────────────────────────────────────────────────────────

  void _startDebateBattle(
    DebateOpponentSpec opponent, {
    String? entityId,
    required bool isBoss,
  }) {
    _triggerGbaSwirlTransition(() {
      setState(() {
        _shellState = _StoryShellState.battle;
        _activeOpponent = opponent;
        _activeOpponentEntityId = entityId;
        _isBossBattle = isBoss;
        _opponentDoubtRemaining = opponent.maxDoubt;
        _questionCursor = 0;
        _pendingDoctrineMove = null;
        _awaitingQuestionAnswer = false;
        _battleBusy = false;
        _battleLogMessage = '${opponent.name}: "${opponent.introQuote}"';
      });
    });
  }

  DebateChallengeQuestion get _currentBattleQuestion {
    final questions = _activeOpponent?.questions ?? const <DebateChallengeQuestion>[];
    if (questions.isEmpty) {
      return const DebateChallengeQuestion(
        prompt: 'Where does sovereignty reside in a democratic republic?',
        choices: <String>[
          'In the Filipino people (Article II, Section 1)',
          'In an absolute monarch',
          'In colonial decrees',
          'In martial rule',
        ],
        correctIndex: 0,
        constitutionalExplanation:
            'Sovereignty resides in the people and all government authority emanates from them.',
      );
    }
    return questions[_questionCursor % questions.length];
  }

  void _selectDoctrineMove(LegalDoctrineMove move) {
    if (_battleBusy || _activeOpponent == null) return;
    final pp = _doctrinePpRemaining[move.id] ?? 0;
    if (pp <= 0) {
      LobbyAudioService.instance.playQuizWrong();
      setState(() {
        _battleLogMessage =
            'No PP left for ${move.name}! Visit a Bahay-Pulungan or pick another Doctrine.';
      });
      return;
    }
    HapticFeedback.selectionClick();
    LobbyAudioService.instance.playBubblePop();
    setState(() {
      _pendingDoctrineMove = move;
      _awaitingQuestionAnswer = true;
      _battleLogMessage =
          'Invoke ${move.name} by answering this Constitutional Precedent!';
    });
  }

  Future<void> _submitDebateAnswer(int selectedChoiceIdx) async {
    if (_battleBusy || _activeOpponent == null || _pendingDoctrineMove == null) {
      return;
    }
    final move = _pendingDoctrineMove!;
    final q = _currentBattleQuestion;
    final opponent = _activeOpponent!;
    final isCorrect = selectedChoiceIdx == q.correctIndex;
    final isRecommended = move.id == q.recommendedDoctrineId;

    setState(() {
      _battleBusy = true;
      _awaitingQuestionAnswer = false;
      _doctrinePpRemaining[move.id] =
          math.max(0, (_doctrinePpRemaining[move.id] ?? 1) - 1);
    });

    if (isCorrect) {
      LobbyAudioService.instance.playQuizCorrect();
      HapticFeedback.heavyImpact();

      final multiplier = isRecommended ? 1.45 : 1.15;
      final damage = (move.basePower * multiplier).round();
      final heal = move.resolveHeal;

      setState(() {
        // Trigger `patch-gg/pixelfx` Doctrine animation on Opponent platform (x: 118, y: 34)
        _battleActiveFxCtrl = createFx(
          move.fxPreset,
          PixelFxOptions(
            x: 118,
            y: 34,
            seed: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
          ),
        );
        _battleScreenShake = 1.0;
        _opponentDoubtRemaining =
            math.max(0, _opponentDoubtRemaining - damage);
        if (heal > 0) {
          _save = _save.copyWith(
            civicResolveHp: math.min(
              _save.maxCivicResolveHp,
              _save.civicResolveHp + heal,
            ),
          );
        }
        _floatingTexts.add(
          _FloatingJuiceText(
            text: isRecommended
                ? '⚡ CRITICAL PRECEDENT! -$damage DOUBT'
                : '⚖️ VALID DOCTRINE! -$damage DOUBT',
            color: Color(move.accentColor),
            normalizedPos: const Offset(0.68, 0.28),
          ),
        );
        if (heal > 0) {
          _floatingTexts.add(
            _FloatingJuiceText(
              text: '+$heal CIVIC RESOLVE',
              color: const Color(0xFF34D399),
              normalizedPos: const Offset(0.28, 0.56),
            ),
          );
        }
        _battleLogMessage =
            'Alon invoked ${move.name}! ${q.constitutionalExplanation}';
      });

      await Future<void>.delayed(const Duration(milliseconds: 950));
      if (!mounted) return;

      // Secondary Doubt Shatter burst from `pixelfx`
      setState(() {
        _battleActiveFxCtrl = createFx(
          PixelFxPreset.doubtShatterBurst,
          PixelFxOptions(
            x: 118,
            y: 34,
            seed: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
          ),
        );
      });

      if (_opponentDoubtRemaining <= 0) {
        await _handleBattleVictory();
        return;
      }

      // Opponent counter-argument (weakened because Alon answered right)
      await Future<void>.delayed(const Duration(milliseconds: 700));
      if (!mounted) return;
      final counterDmg = math.max(4, opponent.attackPower ~/ 3);
      setState(() {
        _save = _save.copyWith(
          civicResolveHp: math.max(1, _save.civicResolveHp - counterDmg),
        );
        _questionCursor++;
        _pendingDoctrineMove = null;
        _battleBusy = false;
      });
    } else {
      // Wrong answer: Opponent's argument strikes Alon's Civic Resolve!
      LobbyAudioService.instance.playQuizWrong();
      HapticFeedback.vibrate();
      final dmg = opponent.attackPower;

      setState(() {
        _battleActiveFxCtrl = createFx(
          PixelFxPreset.doubtShatterBurst,
          PixelFxOptions(
            x: 44,
            y: 62,
            seed: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
          ),
        );
        _battleScreenShake = 1.2;
        _save = _save.copyWith(
          civicResolveHp: math.max(0, _save.civicResolveHp - dmg),
        );
        _floatingTexts.add(
          _FloatingJuiceText(
            text: '-$dmg CIVIC RESOLVE!',
            color: const Color(0xFFEF4444),
            normalizedPos: const Offset(0.30, 0.52),
          ),
        );
        _battleLogMessage =
            '${opponent.name} countered with ${opponent.argumentAttackName}! Tip: ${q.constitutionalExplanation}';
      });

      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (!mounted) return;

      if (_save.civicResolveHp <= 0) {
        // Return to Bahay-Pulungan with full HP!
        LobbyAudioService.instance.playBahayPulunganHealChime();
        _initDoctrinePp();
        _save = _save.copyWith(civicResolveHp: _save.maxCivicResolveHp);
        unawaited(_save.persist(widget.session.id));
        setState(() {
          _shellState = _StoryShellState.overworld;
          _alonCol = _currentAct.spawnCol;
          _alonRow = _currentAct.spawnRow;
          _battleBusy = false;
        });
        _showDialogue(
          speaker: 'Bahay-Pulungan Historian',
          subtitle: 'Civic Resolve Restored',
          color: 0xFF34D399,
          lines: const <String>[
            '♫ Your Civic Resolve faltered during the debate, so Umalo guided you back to the Bahay-Pulungan!',
            'Review the Saligang Tala entries and challenge the Tribunal again!',
          ],
        );
        return;
      }

      setState(() {
        _questionCursor++;
        _pendingDoctrineMove = null;
        _battleBusy = false;
      });
    }
  }

  Future<void> _handleBattleVictory() async {
    final opponent = _activeOpponent!;
    LobbyAudioService.instance.playCharterSealFanfare();

    // Record defeated entity & unlocked Saligang Tala entries
    final nextDefeated = Set<String>.from(_save.defeatedEntityIds);
    if (_activeOpponentEntityId != null) {
      nextDefeated.add(_activeOpponentEntityId!);
    }
    final nextTala = Set<String>.from(_save.unlockedSaligangTalaIds)
      ..addAll(opponent.unlockedSaligangTalaIds);
    final nextSeals = Set<String>.from(_save.earnedSealIds);

    final earnedNewSeal = _isBossBattle;
    if (earnedNewSeal) {
      nextSeals.add(_currentAct.charterSealId);
    }

    final nextActNum = earnedNewSeal
        ? math.min(7, _currentAct.actNumber + 1)
        : _save.currentActNumber;

    _save = _save.copyWith(
      currentActNumber: math.max(_save.currentActNumber, nextActNum),
      earnedSealIds: nextSeals,
      unlockedSaligangTalaIds: nextTala,
      defeatedEntityIds: nextDefeated,
    );
    await _save.persist(widget.session.id);

    // Trigger `craft-game-floors` Milestone Sequence (Flash -> Sting -> Banner -> Confetti)!
    setState(() {
      _milestoneFlashAlpha = 0.65;
      _milestoneBannerText = earnedNewSeal
          ? '${_currentAct.charterSealIcon} ${_currentAct.charterSealName.toUpperCase()} EARNED!'
          : '⚖️ DEBATE WON! +35 XP';
      _battleActiveFxCtrl = createFx(
        PixelFxPreset.charterSealUnlock,
        PixelFxOptions(
          x: 80,
          y: 52,
          seed: DateTime.now().millisecondsSinceEpoch & 0xFFFF,
        ),
      );
      _battleLogMessage = '${opponent.name}: "${opponent.defeatQuote}"';
    });

    // Sync XP & Badges with the Virtual School Lobby (`LobbyDataService`)!
    if (earnedNewSeal) {
      final allSevenDone = nextSeals.length >= 7;
      await LobbyDataService.instance.awardSovereignCharterSealReward(
        sealId: _currentAct.charterSealId,
        sealName: _currentAct.charterSealName,
        sealIcon: _currentAct.charterSealIcon,
        sealColor: _currentAct.charterSealColor,
        totalSealsEarned: nextSeals.length,
        completedAllSevenAltar: allSevenDone,
      );
    }

    await Future<void>.delayed(const Duration(milliseconds: 1650));
    if (!mounted) return;

    setState(() {
      _milestoneBannerText = null;
      _battleBusy = false;
      if (earnedNewSeal && _save.earnedSealIds.length >= 7) {
        _shellState = _StoryShellState.altarVictory;
        _save = _save.copyWith(completedAltarEnding: true);
        unawaited(_save.persist(widget.session.id));
      } else {
        _shellState = _StoryShellState.overworld;
      }
    });

    if (earnedNewSeal && _shellState == _StoryShellState.overworld) {
      final hasNextAct = _actIndex + 1 < kSovereignActs.length;
      final nextAct = hasNextAct ? kSovereignActs[_actIndex + 1] : null;
      _showDialogue(
        speaker: opponent.name,
        subtitle: '${_currentAct.charterSealIcon} ${_currentAct.charterSealName} Unlocked (+75 Lobby XP)',
        color: _currentAct.charterSealColor,
        lines: <String>[
          opponent.defeatQuote,
          '🌟 Alon received the ${_currentAct.charterSealName} (${_save.earnedSealIds.length}/7 Charter Seals) and Umalo updated the Saligang Tala!',
          if (nextAct != null)
            '📻 Lolo Amado: "The Astrolabe of Kalayaan is resonating! Step into ${nextAct.romanNumeral}: ${nextAct.zoneTitle} (${nextAct.yearSpan})!"',
        ],
        onComplete: () {
          if (hasNextAct) {
            _startAct(_actIndex + 1);
          }
        },
      );
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  KEYBOARD & D-PAD INPUT
  // ─────────────────────────────────────────────────────────────────────────

  void _handleKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent) return;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      setState(() {
        if (_shellState == _StoryShellState.overworld) {
          _shellState = _StoryShellState.paused;
        } else if (_shellState == _StoryShellState.paused) {
          _shellState = _StoryShellState.overworld;
        }
      });
      return;
    }

    if (_shellState == _StoryShellState.title) {
      if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
        _startAct(_actIndex);
      }
      return;
    }

    if (_shellState == _StoryShellState.overworld) {
      if (_dialogueQueue.isNotEmpty) {
        if (key == LogicalKeyboardKey.space ||
            key == LogicalKeyboardKey.enter ||
            key == LogicalKeyboardKey.keyE) {
          _advanceDialogue();
        }
        return;
      }
      if (key == LogicalKeyboardKey.arrowUp || key == LogicalKeyboardKey.keyW) {
        _moveAlon(0, -1, 'up');
      } else if (key == LogicalKeyboardKey.arrowDown ||
          key == LogicalKeyboardKey.keyS) {
        _moveAlon(0, 1, 'down');
      } else if (key == LogicalKeyboardKey.arrowLeft ||
          key == LogicalKeyboardKey.keyA) {
        _moveAlon(-1, 0, 'left');
      } else if (key == LogicalKeyboardKey.arrowRight ||
          key == LogicalKeyboardKey.keyD) {
        _moveAlon(1, 0, 'right');
      } else if (key == LogicalKeyboardKey.keyE ||
          key == LogicalKeyboardKey.space ||
          key == LogicalKeyboardKey.enter) {
        _interactFacingOrNearest();
      }
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  BUILD & SHELL VIEWS
  // ─────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF070B14),
      body: KeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: SafeArea(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Active Game Shell Screen
              _buildActiveShellBody(),

              // 2. Floating Juice Texts (`+XP`, `CRITICAL PRECEDENT!`, `+FULL CIVIC RESOLVE`)
              ..._floatingTexts.map((ft) {
                final dy = ft.normalizedPos.dy - ft.progress * 0.12;
                final alpha = (1.0 - ft.progress).clamp(0.0, 1.0);
                return Positioned(
                  left: MediaQuery.sizeOf(context).width *
                          ft.normalizedPos.dx -
                      95,
                  top: MediaQuery.sizeOf(context).height * dy,
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: alpha,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFF0F172A).withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: ft.color, width: 1.5),
                        ),
                        child: Text(
                          ft.text,
                          style: GoogleFonts.outfit(
                            color: ft.color,
                            fontSize: 12,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),

              // 3. Milestone Fullscreen Flash & Scale-Overshoot Banner (`craft-game-floors`)
              if (_milestoneFlashAlpha > 0)
                IgnorePointer(
                  child: Container(
                    color: const Color(0xFFFACC15)
                        .withValues(alpha: _milestoneFlashAlpha),
                  ),
                ),
              if (_milestoneBannerText != null)
                Center(
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.2, end: 1.0),
                    duration: const Duration(milliseconds: 350),
                    curve: Curves.easeOutBack,
                    builder: (context, scale, child) =>
                        Transform.scale(scale: scale, child: child),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 24, vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: const Color(0xFFFACC15), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFACC15)
                                .withValues(alpha: 0.55),
                            blurRadius: 24,
                          ),
                        ],
                      ),
                      child: Text(
                        _milestoneBannerText!,
                        style: GoogleFonts.outfit(
                          color: const Color(0xFFFEF08A),
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ),

              // 4. GBA Screen-Flashing Swirl Transition (`patch-gg/pixelfx` `gbaBattleSwirl`)
              if (_swirlActive)
                IgnorePointer(
                  child: CustomPaint(
                    painter: _GbaSwirlOverlayPainter(
                      frame: _swirlFxFrame,
                      controller: _swirlFxCtrl,
                      progress: _swirlTransitionProgress,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActiveShellBody() {
    switch (_shellState) {
      case _StoryShellState.title:
        return _buildTitleScreen();
      case _StoryShellState.overworld:
        return _buildOverworldScreen();
      case _StoryShellState.battle:
        return _buildBattleScreen();
      case _StoryShellState.saligangTala:
        return _buildSaligangTalaScreen();
      case _StoryShellState.paused:
        return _buildPauseScreen();
      case _StoryShellState.altarVictory:
        return _buildAltarVictoryScreen();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  1. TITLE SCREEN (`craft-game-floors` Game Shell Floor)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildTitleScreen() {
    final pulse = 0.55 + 0.45 * math.sin(_idleTime * 3.8);
    return Stack(
      fit: StackFit.expand,
      children: [
        // Live `pixelfx` Archipelago Backdrop
        CustomPaint(
          painter: _TitleBackdropPainter(
            fxFrame: _overworldFxFrame,
            fxController: _ambientFxCtrl,
            time: _idleTime,
          ),
        ),
        SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: Column(
                children: [
                  // Top Bar: Return to Virtual School Lobby + Saligang Tala
                  Row(
                    children: [
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          backgroundColor: const Color(0xCC0F172A),
                          side: const BorderSide(color: Colors.white30),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.arrow_back_rounded, size: 16),
                        label: const Text('Return to School Lobby'),
                      ),
                      const Spacer(),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF1E293B),
                          foregroundColor: const Color(0xFFFACC15),
                          side: const BorderSide(color: Color(0xFFFACC15)),
                        ),
                        onPressed: () => setState(
                            () => _shellState = _StoryShellState.saligangTala),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: Text(
                          'Saligang Tala (${_save.unlockedSaligangTalaIds.length}/${kSaligangTalaCatalog.length})',
                          style: GoogleFonts.outfit(
                              fontWeight: FontWeight.w800, fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // GBA LeafGreen Title Emblem Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: const Color(0xE60B132B),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                          color: const Color(0xFFFACC15), width: 2.2),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFF59E0B)
                              .withValues(alpha: 0.30),
                          blurRadius: 28,
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF065F46),
                            borderRadius: BorderRadius.circular(99),
                            border:
                                Border.all(color: const Color(0xFF34D399)),
                          ),
                          child: Text(
                            'LEAFGREEN-STYLE 16-BIT RPG • POWERED BY PATCH-GG/PIXELFX',
                            style: GoogleFonts.outfit(
                              color: const Color(0xFF6EE7B7),
                              fontSize: 10.5,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.9,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'CHRONICLES OF THE SOVEREIGN',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: const Color(0xFFFACC15),
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.1,
                            shadows: const [
                              Shadow(
                                color: Color(0xFF020617),
                                offset: Offset(0, 3),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Ang Tagapag-ingat • Philippine Politics, History & Constitutional Governance',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Living Cast Mini Showcase (Alon, Lolo Amado, Rival Mateo, Umalo)
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: const [
                            _CastBadgeChip(
                              emoji: '🧭',
                              name: 'Alon',
                              role: 'Ang Tagapag-ingat',
                              color: Color(0xFF38BDF8),
                            ),
                            _CastBadgeChip(
                              emoji: '📻',
                              name: 'Lolo Amado',
                              role: 'Archive Custodian',
                              color: Color(0xFFFACC15),
                            ),
                            _CastBadgeChip(
                              emoji: '❗',
                              name: 'Rival Mateo',
                              role: 'Iron-Fist Ideologue',
                              color: Color(0xFFEF4444),
                            ),
                            _CastBadgeChip(
                              emoji: '🐒',
                              name: 'Umalo',
                              role: 'Saligang Tala Tarsier',
                              color: Color(0xFF10B981),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // 7 Charter Seals Progress Bar
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E293B),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Column(
                            children: [
                              Text(
                                'SEVEN CHARTER SEALS (${_save.earnedSealIds.length}/7 COLLECTED)',
                                style: GoogleFonts.outfit(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.7,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                alignment: WrapAlignment.center,
                                children: kSovereignActs.map((act) {
                                  final earned = _save.earnedSealIds
                                      .contains(act.charterSealId);
                                  final selected =
                                      _actIndex == (act.actNumber - 1);
                                  return GestureDetector(
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      setState(
                                          () => _actIndex = act.actNumber - 1);
                                    },
                                    child: AnimatedContainer(
                                      duration:
                                          const Duration(milliseconds: 180),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: selected
                                            ? Color(act.charterSealColor)
                                                .withValues(alpha: 0.28)
                                            : const Color(0xFF0F172A),
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color: selected
                                              ? Color(act.charterSealColor)
                                              : (earned
                                                  ? const Color(0xFF34D399)
                                                  : Colors.white24),
                                          width: selected ? 2.0 : 1.2,
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            earned
                                                ? act.charterSealIcon
                                                : '🔒',
                                            style:
                                                const TextStyle(fontSize: 14),
                                          ),
                                          const SizedBox(width: 5),
                                          Text(
                                            '${act.romanNumeral}: ${act.zoneTitle}',
                                            style: GoogleFonts.outfit(
                                              color: earned || selected
                                                  ? Colors.white
                                                  : Colors.white60,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w800,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Selected Act Preview & Start Button
                        Text(
                          'SELECTED ERA: ${_currentAct.romanNumeral} — ${_currentAct.zoneTitle} (${_currentAct.yearSpan})',
                          style: GoogleFonts.outfit(
                            color: Color(_currentAct.charterSealColor),
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_currentAct.eraSubtitle} • Attire: ${_currentAct.alonAttireName}',
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 11.5,
                          ),
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFFACC15),
                              foregroundColor: const Color(0xFF0F172A),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                            onPressed: () => _startAct(_actIndex),
                            icon: const Icon(Icons.play_arrow_rounded, size: 22),
                            label: Opacity(
                              opacity: pulse,
                              child: Text(
                                'STEP INTO THE CHRONICLE (${_currentAct.romanNumeral})',
                                style: GoogleFonts.outfit(
                                  fontWeight: FontWeight.w900,
                                  fontSize: 14.5,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  2. OVERWORLD SCREEN (16×16 TILEMAP + PIXELFX + GBA DIALOGUE)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildOverworldScreen() {
    final act = _currentAct;
    final allNodesSolved = _areAllActPuzzleNodesSolved(act);
    final totalNodes =
        act.entities.where((e) => e.role == 'puzzle_node').length;
    final solvedNodes = act.entities
        .where((e) =>
            e.role == 'puzzle_node' &&
            _save.activatedPuzzleNodeIds.contains(e.id))
        .length;

    return Column(
      children: [
        // Top GBA Overworld HUD Bar (Goal + Civic Resolve HP + Act Switcher + Saligang Tala)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            border: Border(
              bottom: BorderSide(
                color: Color(act.charterSealColor).withValues(alpha: 0.7),
                width: 1.6,
              ),
            ),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _SmallHudChip(
                  icon: Icons.pause_circle_filled_rounded,
                  label: 'Pause / Acts',
                  color: const Color(0xFF38BDF8),
                  onTap: () =>
                      setState(() => _shellState = _StoryShellState.paused),
                ),
                const SizedBox(width: 6),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Color(act.charterSealColor)),
                  ),
                  child: Text(
                    '${act.charterSealIcon} ${act.romanNumeral}: ${act.zoneTitle} (${act.yearSpan})',
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                // Civic Resolve (HP) Animated Bar
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFF10B981)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('❤️ Resolve ',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w800)),
                      SizedBox(
                        width: 58,
                        height: 8,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: TweenAnimationBuilder<double>(
                            tween: Tween<double>(
                              begin: 1.0,
                              end: (_save.civicResolveHp /
                                      _save.maxCivicResolveHp)
                                  .clamp(0.0, 1.0),
                            ),
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutCubic,
                            builder: (context, val, _) =>
                                LinearProgressIndicator(
                              value: val,
                              backgroundColor: Colors.white12,
                              color: val > 0.35
                                  ? const Color(0xFF10B981)
                                  : const Color(0xFFEF4444),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${_save.civicResolveHp}/${_save.maxCivicResolveHp}',
                        style: GoogleFonts.outfit(
                          color: const Color(0xFF6EE7B7),
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                // Visible Goal on HUD from frame 1 (`craft-game-floors` Playable Loop Floor)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: allNodesSolved
                          ? const Color(0xFFFACC15)
                          : Colors.white24,
                    ),
                  ),
                  child: Text(
                    allNodesSolved
                        ? '🎯 GOAL: Enter North Tribunal Hall (T) & Earn ${act.charterSealName}!'
                        : '🎯 GOAL: Activate ${act.puzzleNodeLabel}s ($solvedNodes/$totalNodes) ➔ Unlock Tribunal',
                    style: GoogleFonts.inter(
                      color: allNodesSolved
                          ? const Color(0xFFFEF08A)
                          : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                _SmallHudChip(
                  icon: Icons.menu_book_rounded,
                  label:
                      '🐒 Saligang Tala (${_save.unlockedSaligangTalaIds.length})',
                  color: const Color(0xFFFACC15),
                  onTap: () => setState(
                      () => _shellState = _StoryShellState.saligangTala),
                ),
              ],
            ),
          ),
        ),

        // Main 16×16 Tilemap Viewport + Controls Overlay
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 16-Bit GBA Tilemap + Alon + Umalo + NPCs + `pixelfx` layer
              LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (d) {
                      _focusNode.requestFocus();
                      if (_dialogueQueue.isNotEmpty) {
                        _advanceDialogue();
                        return;
                      }
                      // Tap tile to step toward it
                      final boardW = constraints.maxWidth;
                      final boardH = constraints.maxHeight;
                      final tileW = boardW / 20.0;
                      final tileH = boardH / 14.0;
                      final tappedCol = (d.localPosition.dx / tileW).floor();
                      final tappedRow = (d.localPosition.dy / tileH).floor();
                      final dx = tappedCol - _alonCol;
                      final dy = tappedRow - _alonRow;
                      if (dx == 0 && dy == 0) {
                        _interactFacingOrNearest();
                      } else if (dx.abs() >= dy.abs()) {
                        _moveAlon(dx.sign, 0, dx > 0 ? 'right' : 'left');
                      } else {
                        _moveAlon(0, dy.sign, dy > 0 ? 'down' : 'up');
                      }
                    },
                    child: CustomPaint(
                      size: Size(constraints.maxWidth, constraints.maxHeight),
                      painter: _SovereignOverworldPainter(
                        act: act,
                        save: _save,
                        alonCol: _alonCol,
                        alonRow: _alonRow,
                        alonFacing: _alonFacing,
                        stepAnimFrame: _stepAnimFrame,
                        idleTime: _idleTime,
                        alertedRivalId: _alertedRivalEntityId,
                        fxFrame: _overworldFxFrame,
                        ambientFx: _ambientFxCtrl,
                        unrestFx: _unrestFxCtrl,
                        burstFx: _overworldBurstFxCtrl,
                      ),
                    ),
                  );
                },
              ),

              // GBA Dialogue Box (when talking to Lolo Amado, NPCs, or Rival Mateo)
              if (_dialogueQueue.isNotEmpty)
                Positioned(
                  left: 14,
                  right: 14,
                  bottom: 14,
                  child: GestureDetector(
                    onTap: _advanceDialogue,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xF50F172A),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                            color: Color(_dialogueColor), width: 2.4),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black87,
                            blurRadius: 16,
                            offset: Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Color(_dialogueColor)
                                      .withValues(alpha: 0.22),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                      color: Color(_dialogueColor)),
                                ),
                                child: Text(
                                  _dialogueSpeaker ?? 'Chronicle',
                                  style: GoogleFonts.outfit(
                                    color: Colors.white,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (_dialogueSubtitle != null)
                                Expanded(
                                  child: Text(
                                    _dialogueSubtitle!,
                                    overflow: TextOverflow.ellipsis,
                                    style: GoogleFonts.inter(
                                      color: Colors.white60,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _dialogueQueue[_dialogueIndex],
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 13.5,
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _dialogueIndex + 1 < _dialogueQueue.length
                                  ? 'TAP OR PRESS [SPACE] FOR NEXT ▾'
                                  : 'TAP OR PRESS [SPACE] TO CONTINUE ▶',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFACC15),
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 0.6,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              // On-Screen GBA D-Pad + A/B Action Buttons (when dialogue is closed)
              if (_dialogueQueue.isEmpty) ...[
                Positioned(
                  left: 14,
                  bottom: 14,
                  child: _GbaDirectionalPad(
                    onDirection: (dc, dr, dir) => _moveAlon(dc, dr, dir),
                  ),
                ),
                Positioned(
                  right: 14,
                  bottom: 14,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // B Button: Next/Prev Act Quick Travel
                      _GbaRoundButton(
                        label: 'ACT',
                        sublabel: 'Switch Era',
                        color: const Color(0xFF0284C7),
                        onTap: () => setState(
                            () => _shellState = _StoryShellState.title),
                      ),
                      const SizedBox(width: 10),
                      // A Button: Interact / Talk / Inspect
                      _GbaRoundButton(
                        label: 'A',
                        sublabel: 'Interact',
                        color: const Color(0xFF10B981),
                        onTap: _interactFacingOrNearest,
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  3. TURN-BASED DEBATE BATTLE SCREEN (GBA LEAFGREEN + `pixelfx`)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildBattleScreen() {
    final opponent = _activeOpponent;
    if (opponent == null) return const SizedBox.shrink();

    final doubtRatio =
        (_opponentDoubtRemaining / opponent.maxDoubt).clamp(0.0, 1.0);
    final resolveRatio =
        (_save.civicResolveHp / _save.maxCivicResolveHp).clamp(0.0, 1.0);
    final shakeDx = math.sin(_idleTime * 65.0) * _battleScreenShake * 6.0;

    return Transform.translate(
      offset: Offset(shakeDx, 0),
      child: Column(
        children: [
          // Top half: GBA Dual-Platform Battle Arena + `pixelfx` VFX Layer
          Expanded(
            flex: 5,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(
                  painter: _SovereignBattleArenaPainter(
                    act: _currentAct,
                    opponent: opponent,
                    alonAttireColor: _currentAct.alonHatOrBadgeColor,
                    idleTime: _idleTime,
                    fxFrame: _battleFxFrame,
                    activeFx: _battleActiveFxCtrl,
                  ),
                ),

                // Top-Left Opponent Doubt Meter Card (GBA LeafGreen Status Box)
                Positioned(
                  top: 12,
                  left: 14,
                  child: Container(
                    width: 245,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xF00F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: Color(opponent.primaryColor),
                        width: 2.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          opponent.name,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          opponent.title,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 10.5,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'DOUBT ',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFFFACC15),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: TweenAnimationBuilder<double>(
                                  tween:
                                      Tween<double>(begin: 1.0, end: doubtRatio),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, val, _) =>
                                      LinearProgressIndicator(
                                    value: val,
                                    minHeight: 8,
                                    backgroundColor: Colors.white12,
                                    color: val > 0.5
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFEF4444),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$_opponentDoubtRemaining/${opponent.maxDoubt}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom-Right Alon & Umalo Civic Resolve Card
                Positioned(
                  bottom: 10,
                  right: 14,
                  child: Container(
                    width: 235,
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: const Color(0xF00F172A),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF10B981),
                        width: 2.0,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Alon & Umalo (${_currentAct.romanNumeral})',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        Text(
                          _currentAct.alonAttireName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            color: const Color(0xFF6EE7B7),
                            fontSize: 10,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              'RESOLVE ',
                              style: GoogleFonts.outfit(
                                color: const Color(0xFF34D399),
                                fontSize: 10,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: TweenAnimationBuilder<double>(
                                  tween: Tween<double>(
                                      begin: 1.0, end: resolveRatio),
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeOutCubic,
                                  builder: (context, val, _) =>
                                      LinearProgressIndicator(
                                    value: val,
                                    minHeight: 8,
                                    backgroundColor: Colors.white12,
                                    color: const Color(0xFF10B981),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '${_save.civicResolveHp}/${_save.maxCivicResolveHp}',
                              style: GoogleFonts.outfit(
                                color: Colors.white,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom half: GBA 4-Move Legal Doctrine Menu OR Constitutional Question Challenge
          Expanded(
            flex: 5,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: Color(0xFF0F172A),
                border: Border(
                  top: BorderSide(color: Color(0xFFFACC15), width: 2.4),
                ),
              ),
              child: _awaitingQuestionAnswer
                  ? _buildBattleQuestionView()
                  : _buildDoctrineMoveMenu(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoctrineMoveMenu() {
    final recId = _currentBattleQuestion.recommendedDoctrineId;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Battle Narrator Log Box
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  _battleLogMessage,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (!_isBossBattle)
                TextButton(
                  onPressed: _battleBusy
                      ? null
                      : () => setState(
                          () => _shellState = _StoryShellState.overworld),
                  child: const Text(
                    'Run ➔',
                    style: TextStyle(
                        color: Color(0xFF94A3B8),
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.count(
            crossAxisCount: 2,
            mainAxisSpacing: 8,
            crossAxisSpacing: 8,
            childAspectRatio: 2.65,
            children: kAlonDoctrineMoves.map((move) {
              final pp = _doctrinePpRemaining[move.id] ?? 0;
              final isBest = move.id == recId;
              final col = Color(move.accentColor);
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: _battleBusy ? null : () => _selectDoctrineMove(move),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isBest ? col : Colors.white24,
                      width: isBest ? 2.0 : 1.2,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              move.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.outfit(
                                color: col,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          if (isBest)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 1),
                              decoration: BoxDecoration(
                                color: col.withValues(alpha: 0.22),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'EFFECTIVE',
                                style: GoogleFonts.outfit(
                                  color: col,
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${move.tagalogSubtitle} • PWR ${move.basePower} • PP $pp/${move.maxPp}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: Colors.white70,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildBattleQuestionView() {
    final q = _currentBattleQuestion;
    final move = _pendingDoctrineMove!;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Color(move.accentColor).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Color(move.accentColor)),
                ),
                child: Text(
                  'DOCTRINE: ${move.name}',
                  style: GoogleFonts.outfit(
                    color: Color(move.accentColor),
                    fontSize: 11,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => setState(() {
                  _awaitingQuestionAnswer = false;
                  _pendingDoctrineMove = null;
                }),
                child: const Text('← Back to Moves',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            q.prompt,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ...List<Widget>.generate(q.choices.length, (idx) {
            final letter = String.fromCharCode(65 + idx);
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => _submitDebateAnswer(idx),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.white24),
                  ),
                  child: Text(
                    '$letter. ${q.choices[idx]}',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  4. SALIGANG TALA (CIVIC POKÉDEX) & REVIEW LOG SCREEN
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildSaligangTalaScreen() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🐒📜', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SALIGANG TALA • THE CIVIC POKÉDEX',
                      style: GoogleFonts.outfit(
                        color: const Color(0xFFFACC15),
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      'Recorded by Umalo the Tarsier • ${_save.unlockedSaligangTalaIds.length}/${kSaligangTalaCatalog.length} Entries Restored • ${_save.earnedSealIds.length}/7 Charter Seals',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                onPressed: () => setState(() {
                  _shellState = _StoryShellState.overworld;
                }),
                icon: const Icon(Icons.play_arrow_rounded, size: 18),
                label: const Text('Resume Map'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: ListView.separated(
              itemCount: kSaligangTalaCatalog.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, idx) {
                final entry = kSaligangTalaCatalog[idx];
                final unlocked =
                    _save.unlockedSaligangTalaIds.contains(entry.id);
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? const Color(0xFF1E293B)
                        : const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: unlocked
                          ? const Color(0xFFFACC15).withValues(alpha: 0.6)
                          : Colors.white12,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: unlocked
                                  ? const Color(0xFF065F46)
                                  : Colors.white10,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              '${entry.numberCode} • ACT ${entry.actNumber}',
                              style: GoogleFonts.outfit(
                                color: unlocked
                                    ? const Color(0xFF6EE7B7)
                                    : Colors.white38,
                                fontSize: 10.5,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              unlocked
                                  ? entry.title
                                  : '??? (Explore Act ${entry.actNumber} to Unlock)',
                              style: GoogleFonts.outfit(
                                color:
                                    unlocked ? Colors.white : Colors.white38,
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          Text(
                            entry.eraLabel,
                            style: GoogleFonts.inter(
                              color: Colors.white54,
                              fontSize: 10.5,
                            ),
                          ),
                        ],
                      ),
                      if (unlocked) ...[
                        const SizedBox(height: 6),
                        Text(
                          entry.summary,
                          style: GoogleFonts.inter(
                            color: Colors.white70,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '⚖️ Constitutional Principle: ${entry.keyPrinciple}',
                          style: GoogleFonts.inter(
                            color: const Color(0xFFFDE047),
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  5. PAUSE & SETTINGS OVERLAY (`craft-game-floors` Game Shell Floor)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildPauseScreen() {
    final isMuted = LobbyAudioService.instance.isMuted;
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 440),
        margin: const EdgeInsets.all(20),
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFF38BDF8), width: 2.0),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'CHRONICLE PAUSED',
              style: GoogleFonts.outfit(
                color: const Color(0xFFFACC15),
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${_currentAct.romanNumeral}: ${_currentAct.zoneTitle} • ${_save.earnedSealIds.length}/7 Charter Seals',
              style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 16),
            ListTile(
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
              tileColor: const Color(0xFF1E293B),
              leading: Icon(
                isMuted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
                color: const Color(0xFF34D399),
              ),
              title: Text(
                isMuted ? 'Sound Effects: Muted' : 'Sound Effects: Active',
                style: GoogleFonts.outfit(
                    color: Colors.white, fontWeight: FontWeight.w700),
              ),
              onTap: () async {
                await LobbyAudioService.instance.toggleMute();
                setState(() {});
              },
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () =>
                    setState(() => _shellState = _StoryShellState.overworld),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Resume Chronicle'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFFACC15),
                  side: const BorderSide(color: Color(0xFFFACC15)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () =>
                    setState(() => _shellState = _StoryShellState.title),
                icon: const Icon(Icons.map_rounded),
                label: const Text('Switch Historical Act (Act I–VII)'),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white70,
                  side: const BorderSide(color: Colors.white24),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.exit_to_app_rounded),
                label: const Text('Return to Virtual School Lobby'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  //  6. ALTAR OF THE SOVEREIGN VICTORY SCREEN (ALL 7 CHARTER SEALS)
  // ─────────────────────────────────────────────────────────────────────────

  Widget _buildAltarVictoryScreen() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 560),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(color: const Color(0xFFFACC15), width: 2.5),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFFACC15).withValues(alpha: 0.35),
                blurRadius: 32,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('👑📜🌟', style: TextStyle(fontSize: 42)),
              const SizedBox(height: 10),
              Text(
                'THE SALIGANG TALA GLOWS GOLD!',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFFFACC15),
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Master Historian Unlocked: "Ang Tagapag-ingat" (${widget.playerNickname})',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  color: const Color(0xFF6EE7B7),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'You placed all seven Charter Seals onto the Altar—uniting the Pre-Colonial Barangay, Intramuros, the 1899 Malolos Republic, the 1935 Commonwealth, the Wartime Second Republic, the struggle against Martial Law, and the 1987 People Power Constitution!',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: Colors.white70,
                  fontSize: 13,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: kSovereignActs
                    .map(
                      (a) => Chip(
                        backgroundColor: const Color(0xFF1E293B),
                        side: BorderSide(color: Color(a.charterSealColor)),
                        label: Text(
                          '${a.charterSealIcon} ${a.charterSealName}',
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFFACC15),
                        side: const BorderSide(color: Color(0xFFFACC15)),
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => setState(
                          () => _shellState = _StoryShellState.saligangTala),
                      icon: const Icon(Icons.menu_book_rounded),
                      label: const Text('Review Log'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFACC15),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 13),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.school_rounded),
                      label: const Text('Return to Lobby'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
//  CUSTOM PAINTERS (16×16 TILEMAP, ALON + UMALO SPRITES, BATTLE & PIXELFX)
// ═══════════════════════════════════════════════════════════════════════════

class _TitleBackdropPainter extends CustomPainter {
  final PixelFxFrame fxFrame;
  final PixelFxController fxController;
  final double time;

  const _TitleBackdropPainter({
    required this.fxFrame,
    required this.fxController,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF070B14), Color(0xFF0F2942), Color(0xFF064E3B)],
        ).createShader(rect),
    );

    clearFrame(fxFrame);
    fxController.draw(fxFrame);
    renderPixelFxFrameToCanvas(canvas, fxFrame, rect, opacity: 0.75);
  }

  @override
  bool shouldRepaint(covariant _TitleBackdropPainter oldDelegate) => true;
}

class _GbaSwirlOverlayPainter extends CustomPainter {
  final PixelFxFrame frame;
  final PixelFxController controller;
  final double progress;

  const _GbaSwirlOverlayPainter({
    required this.frame,
    required this.controller,
    required this.progress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    // Initial double white GBA flash then spiral pixel wipe
    if (progress < 0.22) {
      final flash = (math.sin(progress * math.pi * 9.0)).abs();
      canvas.drawRect(
        rect,
        Paint()..color = Colors.white.withValues(alpha: flash * 0.85),
      );
    }
    final fade = (1.0 - progress).clamp(0.0, 1.0);
    canvas.drawRect(
      rect,
      Paint()..color = const Color(0xFF020617).withValues(alpha: fade * 0.78),
    );
    clearFrame(frame);
    controller.draw(frame);
    renderPixelFxFrameToCanvas(canvas, frame, rect, opacity: fade);
  }

  @override
  bool shouldRepaint(covariant _GbaSwirlOverlayPainter oldDelegate) => true;
}

class _SovereignOverworldPainter extends CustomPainter {
  final SovereignActConfig act;
  final SovereignCampaignSave save;
  final int alonCol;
  final int alonRow;
  final String alonFacing;
  final int stepAnimFrame;
  final double idleTime;
  final String? alertedRivalId;
  final PixelFxFrame fxFrame;
  final PixelFxController ambientFx;
  final PixelFxController unrestFx;
  final PixelFxController? burstFx;

  const _SovereignOverworldPainter({
    required this.act,
    required this.save,
    required this.alonCol,
    required this.alonRow,
    required this.alonFacing,
    required this.stepAnimFrame,
    required this.idleTime,
    required this.alertedRivalId,
    required this.fxFrame,
    required this.ambientFx,
    required this.unrestFx,
    this.burstFx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const cols = 20;
    const rows = 14;
    final tileW = size.width / cols;
    final tileH = size.height / rows;
    final pal = act.palette;

    // 1. Draw 16×16 Tilemap Grid
    for (var r = 0; r < rows; r++) {
      final rowStr = r < act.asciiMap.length ? act.asciiMap[r] : '';
      for (var c = 0; c < cols; c++) {
        final ch = c < rowStr.length ? rowStr[c] : '#';
        final rect = Rect.fromLTWH(c * tileW, r * tileH, tileW + 0.5, tileH + 0.5);
        final checker = (r + c).isEven;

        switch (ch) {
          case '#':
            canvas.drawRect(rect, Paint()..color = Color(pal.wallOrTree));
            // Pixel tree/wall crown bevel
            canvas.drawRect(
              Rect.fromLTWH(
                  rect.left + tileW * 0.15,
                  rect.top + tileH * 0.12,
                  tileW * 0.7,
                  tileH * 0.65),
              Paint()
                ..color = Color.lerp(
                    Color(pal.wallOrTree), Colors.white, checker ? 0.12 : 0.06)!,
            );
            break;
          case '~':
            final wave = 0.5 + 0.5 * math.sin(idleTime * 3.0 + c + r);
            canvas.drawRect(
              rect,
              Paint()
                ..color = Color.lerp(Color(pal.waterOrAccentTile),
                    const Color(0xFF38BDF8), wave * 0.25)!,
            );
            break;
          case '=':
            canvas.drawRect(rect, Paint()..color = Color(pal.roadTile));
            canvas.drawRect(
              Rect.fromLTWH(rect.left + 2, rect.top + 2, tileW - 4, tileH - 4),
              Paint()
                ..color = Colors.black.withValues(alpha: 0.08)
                ..style = PaintingStyle.stroke
                ..strokeWidth = 1.0,
            );
            break;
          case 'U':
            // Unrest Zone (Tall Grass)
            canvas.drawRect(
              rect,
              Paint()
                ..color =
                    Color(checker ? pal.groundPrimary : pal.groundSecondary),
            );
            final sway = math.sin(idleTime * 4.2 + c * 0.9 + r) * 2.0;
            final grassPaint = Paint()..color = Color(pal.unrestGrass);
            canvas.drawRect(
              Rect.fromLTWH(rect.left + tileW * 0.2 + sway,
                  rect.top + tileH * 0.25, 3, tileH * 0.55),
              grassPaint,
            );
            canvas.drawRect(
              Rect.fromLTWH(rect.left + tileW * 0.6 + sway,
                  rect.top + tileH * 0.18, 3, tileH * 0.62),
              grassPaint,
            );
            break;
          case 'B':
            // Bahay-Pulungan (Terracotta PokéCenter Roof)
            canvas.drawRect(rect, Paint()..color = Color(pal.roadTile));
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                    rect.left + 2, rect.top + 2, tileW - 4, tileH - 4),
                const Radius.circular(4),
              ),
              Paint()..color = Color(pal.bahayRoof),
            );
            break;
          case 'T':
            // Tribunal Hall (Gym)
            canvas.drawRect(rect, Paint()..color = Color(pal.roadTile));
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(
                    rect.left + 1, rect.top + 1, tileW - 2, tileH - 2),
                const Radius.circular(4),
              ),
              Paint()..color = Color(pal.tribunalRoof),
            );
            break;
          default:
            canvas.drawRect(
              rect,
              Paint()
                ..color =
                    Color(checker ? pal.groundPrimary : pal.groundSecondary),
            );
            break;
        }
      }
    }

    // 2. Draw Map Entities (Bahay Historians, Puzzle Nodes, Rival Mateo, Bosses)
    for (final e in act.entities) {
      if (e.role == 'rival' && save.defeatedEntityIds.contains(e.id)) {
        continue;
      }
      final cx = (e.col + 0.5) * tileW;
      final cy = (e.row + 0.5) * tileH;
      final isSolvedNode =
          e.role == 'puzzle_node' && save.activatedPuzzleNodeIds.contains(e.id);
      final isDefeatedBoss = save.defeatedEntityIds.contains(e.id);

      _drawPixelCharacterSprite(
        canvas,
        center: Offset(cx, cy),
        tileW: tileW,
        tileH: tileH,
        primaryColor: isSolvedNode || isDefeatedBoss
            ? const Color(0xFF34D399)
            : Color(e.color),
        hatColor: e.role == 'rival'
            ? const Color(0xFFEF4444)
            : const Color(0xFFFACC15),
        idlePhase: idleTime + e.col * 0.5,
        showTarsier: false,
      );

      // Rival `[!]` alert bubble above head
      if (alertedRivalId == e.id) {
        final alertRect = RRect.fromRectAndRadius(
          Rect.fromCenter(
              center: Offset(cx, cy - tileH * 0.95), width: 28, height: 20),
          const Radius.circular(5),
        );
        canvas.drawRRect(alertRect, Paint()..color = const Color(0xFFEF4444));
        final tp = TextPainter(
          text: const TextSpan(
            text: '[!]',
            style: TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tp.paint(canvas,
            Offset(cx - tp.width / 2, cy - tileH * 0.95 - tp.height / 2));
      } else {
        // Compact Overhead Name Tag
        final shortName = e.name.split('(').first.trim();
        final tp = TextPainter(
          text: TextSpan(
            text: isSolvedNode ? '✓ $shortName' : shortName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 8.5,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pill = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(cx, cy - tileH * 0.72),
            width: tp.width + 8,
            height: tp.height + 3,
          ),
          const Radius.circular(5),
        );
        canvas.drawRRect(
          pill,
          Paint()..color = const Color(0xD90F172A),
        );
        tp.paint(canvas,
            Offset(cx - tp.width / 2, cy - tileH * 0.72 - tp.height / 2));
      }
    }

    // 3. Draw Alon ("Ang Tagapag-ingat") + Umalo the Tarsier on Shoulder!
    final alonCx = (alonCol + 0.5) * tileW;
    final alonCy = (alonRow + 0.5) * tileH;
    _drawPixelCharacterSprite(
      canvas,
      center: Offset(alonCx, alonCy),
      tileW: tileW,
      tileH: tileH,
      primaryColor: const Color(0xFF38BDF8),
      hatColor: Color(act.alonHatOrBadgeColor),
      idlePhase: idleTime * 2.0 + stepAnimFrame,
      showTarsier: true,
    );

    // 4. Composite `patch-gg/pixelfx` Procedural Layer (Ambient + Burst VFX)
    clearFrame(fxFrame);
    ambientFx.draw(fxFrame);
    if (burstFx != null) {
      burstFx!.draw(fxFrame);
    }
    renderPixelFxFrameToCanvas(
      canvas,
      fxFrame,
      Offset.zero & size,
      opacity: 0.85,
    );
  }

  void _drawPixelCharacterSprite(
    Canvas canvas, {
    required Offset center,
    required double tileW,
    required double tileH,
    required Color primaryColor,
    required Color hatColor,
    required double idlePhase,
    required bool showTarsier,
  }) {
    final bob = math.sin(idlePhase * 3.2) * 1.6;
    final w = math.min(tileW, tileH) * 0.78;
    final h = w * 1.25;

    // Ground shadow
    canvas.drawOval(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy + h * 0.35),
          width: w * 0.85,
          height: h * 0.25),
      Paint()..color = Colors.black.withValues(alpha: 0.45),
    );

    // Dark pixel outline body
    final bodyRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy + bob),
          width: w * 0.72,
          height: h * 0.62),
      const Radius.circular(3),
    );
    canvas.drawRRect(bodyRect, Paint()..color = primaryColor);
    canvas.drawRRect(
      bodyRect,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6,
    );

    // Head
    final headRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy - h * 0.32 + bob),
          width: w * 0.68,
          height: w * 0.62),
      const Radius.circular(3),
    );
    canvas.drawRRect(headRect, Paint()..color = const Color(0xFFFDE68A));
    canvas.drawRRect(
      headRect,
      Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4,
    );

    // Era Attire Hat / Putong / Sash Band
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(center.dx, center.dy - h * 0.48 + bob),
          width: w * 0.74,
          height: 4.5),
      Paint()..color = hatColor,
    );

    // Umalo the Tarsier + Bamboo Scroll on Alon's right shoulder!
    if (showTarsier) {
      final tx = center.dx + w * 0.44;
      final ty = center.dy - h * 0.16 + bob;
      canvas.drawCircle(
          Offset(tx, ty), 4.2, Paint()..color = const Color(0xFFD97706));
      canvas.drawCircle(
          Offset(tx - 1, ty), 1.4, Paint()..color = const Color(0xFFFEF08A));
    }
  }

  @override
  bool shouldRepaint(covariant _SovereignOverworldPainter oldDelegate) => true;
}

class _SovereignBattleArenaPainter extends CustomPainter {
  final SovereignActConfig act;
  final DebateOpponentSpec opponent;
  final int alonAttireColor;
  final double idleTime;
  final PixelFxFrame fxFrame;
  final PixelFxController? activeFx;

  const _SovereignBattleArenaPainter({
    required this.act,
    required this.opponent,
    required this.alonAttireColor,
    required this.idleTime,
    required this.fxFrame,
    this.activeFx,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final pal = act.palette;

    // 1. GBA Battle Sky & Horizon Gradient
    canvas.drawRect(
      rect,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(pal.shadowTone),
            Color(pal.groundPrimary),
            Color(pal.groundSecondary),
          ],
        ).createShader(rect),
    );

    // 2. Opponent Tribunal Platform (Top-Right)
    final oppCenter = Offset(size.width * 0.73, size.height * 0.44);
    canvas.drawOval(
      Rect.fromCenter(center: oppCenter + const Offset(0, 22), width: 132, height: 36),
      Paint()..color = Color(pal.tribunalRoof).withValues(alpha: 0.75),
    );
    canvas.drawOval(
      Rect.fromCenter(center: oppCenter + const Offset(0, 22), width: 132, height: 36),
      Paint()
        ..color = Color(opponent.primaryColor)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    // Opponent Pixel Sprite
    final oppBob = math.sin(idleTime * 3.0) * 3.0;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: oppCenter + Offset(0, oppBob), width: 38, height: 52),
        const Radius.circular(6),
      ),
      Paint()..color = Color(opponent.primaryColor),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: oppCenter + Offset(0, -24 + oppBob), width: 32, height: 28),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFFDE68A),
    );

    // 3. Alon + Umalo Platform (Bottom-Left)
    final alonCenter = Offset(size.width * 0.27, size.height * 0.74);
    canvas.drawOval(
      Rect.fromCenter(
          center: alonCenter + const Offset(0, 20), width: 138, height: 36),
      Paint()..color = const Color(0xFF065F46).withValues(alpha: 0.8),
    );
    canvas.drawOval(
      Rect.fromCenter(
          center: alonCenter + const Offset(0, 20), width: 138, height: 36),
      Paint()
        ..color = const Color(0xFF34D399)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4,
    );

    final alonBob = math.sin(idleTime * 3.5 + 1.0) * 2.5;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: alonCenter + Offset(0, alonBob), width: 36, height: 48),
        const Radius.circular(6),
      ),
      Paint()..color = const Color(0xFF0284C7),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
            center: alonCenter + Offset(0, -22 + alonBob),
            width: 30,
            height: 26),
        const Radius.circular(5),
      ),
      Paint()..color = const Color(0xFFFDE68A),
    );
    // Alon Era Headband/Putong
    canvas.drawRect(
      Rect.fromCenter(
          center: alonCenter + Offset(0, -30 + alonBob), width: 32, height: 6),
      Paint()..color = Color(alonAttireColor),
    );
    // Umalo the Tarsier on Alon's shoulder
    canvas.drawCircle(
      alonCenter + Offset(22, -10 + alonBob),
      7,
      Paint()..color = const Color(0xFFD97706),
    );

    // 4. Composite `patch-gg/pixelfx` Battle Doctrine Effects (`sanduguanFlame`, `checksAndBalancesScales`, `habeasCorpusShield`, `sovereigntySunburst`)
    if (activeFx != null) {
      clearFrame(fxFrame);
      activeFx!.draw(fxFrame);
      renderPixelFxFrameToCanvas(canvas, fxFrame, rect);
    }
  }

  @override
  bool shouldRepaint(covariant _SovereignBattleArenaPainter oldDelegate) =>
      true;
}

// ═══════════════════════════════════════════════════════════════════════════
//  REUSABLE GBA CONTROLS & BADGE WIDGETS
// ═══════════════════════════════════════════════════════════════════════════

class _CastBadgeChip extends StatelessWidget {
  final String emoji;
  final String name;
  final String role;
  final Color color;

  const _CastBadgeChip({
    required this.emoji,
    required this.name,
    required this.role,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.65)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 6),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                name,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Text(
                role,
                style: GoogleFonts.inter(
                  color: color,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SmallHudChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SmallHudChip({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.7)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 5),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 11.5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GbaDirectionalPad extends StatelessWidget {
  final void Function(int dCol, int dRow, String facing) onDirection;

  const _GbaDirectionalPad({required this.onDirection});

  Widget _dirBtn(IconData icon, int dc, int dr, String facing) {
    return Material(
      color: const Color(0xCC0F172A),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => onDirection(dc, dr, facing),
        child: Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.white30),
          ),
          child: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 118,
      height: 118,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            top: 0,
            child: _dirBtn(Icons.keyboard_arrow_up_rounded, 0, -1, 'up'),
          ),
          Positioned(
            bottom: 0,
            child: _dirBtn(Icons.keyboard_arrow_down_rounded, 0, 1, 'down'),
          ),
          Positioned(
            left: 0,
            child: _dirBtn(Icons.keyboard_arrow_left_rounded, -1, 0, 'left'),
          ),
          Positioned(
            right: 0,
            child: _dirBtn(Icons.keyboard_arrow_right_rounded, 1, 0, 'right'),
          ),
        ],
      ),
    );
  }
}

class _GbaRoundButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final Color color;
  final VoidCallback onTap;

  const _GbaRoundButton({
    required this.label,
    required this.sublabel,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.90),
      borderRadius: BorderRadius.circular(99),
      child: InkWell(
        borderRadius: BorderRadius.circular(99),
        onTap: onTap,
        child: Container(
          width: 58,
          height: 58,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2.0),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.5),
                blurRadius: 12,
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                label,
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w900,
                ),
              ),
              Text(
                sublabel,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 8.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
