import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../spritecast_engine.dart';
import 'dungeon_models.dart';
import 'dungeon_physics.dart';

/// Centralized Hit-Stop freeze manager (`craft-game-floors` Game Feel Floor).
/// Never lets overlapping impacts fight: keeps the longest active unscaled freeze
/// duration and scales simulation delta time to `0.05` during impact frames.
class DungeonHitStopManager {
  double _remainingSec = 0.0;
  double _freezeScale = 0.05;

  bool get isFrozen => _remainingSec > 0.0;
  double get remainingSec => _remainingSec;

  void trigger(double durationSec, {double freezeScale = 0.05}) {
    if (durationSec > _remainingSec) {
      _remainingSec = durationSec;
      _freezeScale = freezeScale.clamp(0.0, 0.25);
    }
  }

  void clear() {
    _remainingSec = 0.0;
  }

  /// Ticks unscaled freeze time and returns the scaled simulation `dt`.
  double applyToDt(double rawDt) {
    if (_remainingSec <= 0.0) return rawDt;
    _remainingSec = math.max(0.0, _remainingSec - rawDt);
    return rawDt * _freezeScale;
  }
}

/// 4-directional melee strike orientation (Silksong / Hollow Knight).
enum DungeonSlashDirection {
  right,
  left,
  up,
  down, // Downward pogo-slash!
}

/// Live melee crescent slash hitbox & visual arc.
class ActiveSlashArc {
  final int id;
  final DungeonSlashDirection direction;
  final int comboStep; // 0, 1, 2 (step 2 = +25% finisher!)
  final int damage;
  final double reachPx;
  final double thicknessPx;
  final Color arcColor;
  final double totalDurationSec;
  double elapsedSec;
  final Set<String> hitTargetIds = <String>{};
  final Set<String> hitTileKeys = <String>{};
  bool triggeredPogo;

  ActiveSlashArc({
    required this.id,
    required this.direction,
    required this.comboStep,
    required this.damage,
    required this.reachPx,
    required this.thicknessPx,
    required this.arcColor,
    this.totalDurationSec = 0.145,
    this.elapsedSec = 0.0,
    this.triggeredPogo = false,
  });

  double get progress => (elapsedSec / totalDurationSec).clamp(0.0, 1.0);
  bool get isFinished => elapsedSec >= totalDurationSec;

  /// Computes the live world-space AABB hitbox anchored to Alon's current body.
  Rect worldHitbox(DungeonPlayerPhysicsState player) {
    final cx = player.centerX;
    final cy = player.centerY;
    switch (direction) {
      case DungeonSlashDirection.right:
        return Rect.fromLTWH(
          cx + 2.0,
          cy - thicknessPx * 0.5,
          reachPx,
          thicknessPx,
        );
      case DungeonSlashDirection.left:
        return Rect.fromLTWH(
          cx - 2.0 - reachPx,
          cy - thicknessPx * 0.5,
          reachPx,
          thicknessPx,
        );
      case DungeonSlashDirection.up:
        return Rect.fromLTWH(
          cx - thicknessPx * 0.52,
          cy - 2.0 - reachPx,
          thicknessPx * 1.04,
          reachPx,
        );
      case DungeonSlashDirection.down:
        return Rect.fromLTWH(
          cx - thicknessPx * 0.52,
          cy + 2.0,
          thicknessPx * 1.04,
          reachPx,
        );
    }
  }
}

/// Active cast of one of Alon's 5 Constitutional Silk Skills.
class ActiveSkillEffect {
  final int id;
  final DungeonSilkSkillId skillId;
  final double x;
  final double y;
  final int facing;
  final int damage;
  final double radiusOrLength;
  final double heightPx;
  final Color color;
  final double durationSec;
  double elapsedSec;
  final Set<String> hitTargetIds = <String>{};

  ActiveSkillEffect({
    required this.id,
    required this.skillId,
    required this.x,
    required this.y,
    required this.facing,
    required this.damage,
    required this.radiusOrLength,
    required this.heightPx,
    required this.color,
    required this.durationSec,
    this.elapsedSec = 0.0,
  });

  double get progress => (elapsedSec / durationSec).clamp(0.0, 1.0);
  bool get isFinished => elapsedSec >= durationSec;

  Rect worldHitbox(DungeonPlayerPhysicsState player) {
    switch (skillId) {
      case DungeonSilkSkillId.sanduguanThread:
        return Rect.fromCenter(
          center: Offset(player.centerX + facing * 10.0, player.centerY),
          width: radiusOrLength,
          height: heightPx,
        );
      case DungeonSilkSkillId.scalesTempest:
        return Rect.fromCenter(
          center: Offset(player.centerX, player.centerY),
          width: radiusOrLength * 2.0,
          height: radiusOrLength * 2.0,
        );
      case DungeonSilkSkillId.habeasAegis:
        return Rect.fromCenter(
          center: Offset(player.centerX, player.centerY),
          width: radiusOrLength * 2.0,
          height: radiusOrLength * 2.0,
        );
      case DungeonSilkSkillId.sovereignSunburst:
        return facing >= 0
            ? Rect.fromLTWH(
                player.centerX + 4.0,
                player.centerY - heightPx * 0.5,
                radiusOrLength,
                heightPx,
              )
            : Rect.fromLTWH(
                player.centerX - 4.0 - radiusOrLength,
                player.centerY - heightPx * 0.5,
                radiusOrLength,
                heightPx,
              );
      case DungeonSilkSkillId.silkBind:
        return Rect.fromCenter(
          center: Offset(player.centerX, player.centerY),
          width: 24.0,
          height: 24.0,
        );
    }
  }
}

/// Physical combat projectile (enemy bolts/decrees OR deflected/player-owned orbs).
class DungeonProjectile {
  final String id;
  bool isPlayerOwned;
  final bool deflectable;
  double x;
  double y;
  double vx;
  double vy;
  final double radius;
  int damage;
  Color color;
  double remainingLifeSec;
  bool expired;

  DungeonProjectile({
    required this.id,
    required this.isPlayerOwned,
    this.deflectable = true,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    this.radius = 4.0,
    required this.damage,
    required this.color,
    this.remainingLifeSec = 3.0,
    this.expired = false,
  });

  Rect get hitbox => Rect.fromCircle(center: Offset(x, y), radius: radius);
}

/// Rising damage/heal/status popup (`craft-game-floors`: rises & fades over 0.65s).
class FloatingCombatNumber {
  final String text;
  final Color color;
  final bool isCritical;
  double x;
  double y;
  double vy;
  double ageSec;
  final double durationSec;

  FloatingCombatNumber({
    required this.text,
    required this.color,
    required this.x,
    required this.y,
    this.isCritical = false,
    this.vy = -34.0,
    this.ageSec = 0.0,
    this.durationSec = 0.65,
  });

  double get opacity => (1.0 - (ageSec / durationSec)).clamp(0.0, 1.0);
  bool get isExpired => ageSec >= durationSec;
}

/// Abstract combat target implemented by all Part 4 enemies, Rival Mateo, and 7 Era Bosses.
abstract class DungeonCombatTarget {
  String get id;
  Rect get hitbox;
  int get hp;
  int get maxHp;
  bool get isAlive;
  bool get isBoss;
  bool get isShieldedFront;
  int get facing; // +1 right, -1 left

  /// Applies incoming damage, knockback impulse, and posture damage; returns actual damage dealt
  /// (`0` if cleanly blocked by a front shield).
  int receiveDamage({
    required int amount,
    required double knockbackVx,
    required double knockbackVy,
    required bool isSkillOrCrit,
    required double attackerCenterX,
    required double attackerCenterY,
  });
}

/// Event stream emitted by [DungeonCombatEngine] for SFX, VFX, screenshake, & cloud saves.
enum DungeonCombatEventKind {
  slashSwung,
  enemyHit,
  enemyBlockedByShield,
  enemyDefeated,
  skillCast,
  parrySuccess,
  bindStarted,
  bindCompleted,
  bindInterrupted,
  projectileDeflected,
  playerDamaged,
  crateBroken,
  crystalMined,
  secretWallBroken,
  gateUnlocked,
  pogoLanternStruck,
}

class DungeonCombatEvent {
  final DungeonCombatEventKind kind;
  final double x;
  final double y;
  final double shakeIntensity;
  final int value;
  final DungeonSilkSkillId? skillId;
  final String? tileKey;
  final String? targetId;

  const DungeonCombatEvent({
    required this.kind,
    required this.x,
    required this.y,
    this.shakeIntensity = 0.0,
    this.value = 0,
    this.skillId,
    this.tileKey,
    this.targetId,
  });
}

/// Silksong × Terraria Action-Combat Engine managing 4-directional combos, 5 Silk Skills,
/// timed Habeas Aegis Parry, Silk Bind healing channel, breakable tiles, projectiles, and Hit-Stop.
class DungeonCombatEngine {
  final DungeonHitStopManager hitStop = DungeonHitStopManager();

  int _nextId = 1;
  double slashCooldownTimer = 0.0;
  double comboResetTimer = 0.0;
  int comboStep = 0;

  final Map<DungeonSilkSkillId, double> skillCooldowns =
      <DungeonSilkSkillId, double>{};

  double parryWindowTimer = 0.0;

  bool isChannelingBind = false;
  double bindElapsedSec = 0.0;
  double bindTargetDurationSec = 0.72;

  final List<ActiveSlashArc> activeSlashes = <ActiveSlashArc>[];
  final List<ActiveSkillEffect> activeSkills = <ActiveSkillEffect>[];
  final List<DungeonProjectile> projectiles = <DungeonProjectile>[];
  final List<FloatingCombatNumber> floatingNumbers = <FloatingCombatNumber>[];

  bool get isParryActive => parryWindowTimer > 0.0;
  double get bindProgress => isChannelingBind
      ? (bindElapsedSec / bindTargetDurationSec).clamp(0.0, 1.0)
      : 0.0;

  void resetRoomCombat() {
    hitStop.clear();
    slashCooldownTimer = 0.0;
    comboResetTimer = 0.0;
    comboStep = 0;
    parryWindowTimer = 0.0;
    isChannelingBind = false;
    bindElapsedSec = 0.0;
    activeSlashes.clear();
    activeSkills.clear();
    projectiles.clear();
    floatingNumbers.clear();
  }

  List<DungeonCombatEvent> step({
    required double dt,
    required DungeonPlayerPhysicsState player,
    required DungeonChamberRuntime chamber,
    required DungeonPlayerInput input,
    required DungeonProgressSave progress,
    required DungeonPhysicsEngine physicsEngine,
    List<DungeonCombatTarget> targets = const <DungeonCombatTarget>[],
  }) {
    final events = <DungeonCombatEvent>[];
    if (dt <= 0.0) return events;

    slashCooldownTimer = math.max(0.0, slashCooldownTimer - dt);
    comboResetTimer = math.max(0.0, comboResetTimer - dt);
    if (comboResetTimer <= 0.0) comboStep = 0;
    parryWindowTimer = math.max(0.0, parryWindowTimer - dt);

    for (final key in skillCooldowns.keys.toList()) {
      final next = math.max(0.0, (skillCooldowns[key] ?? 0.0) - dt);
      if (next <= 0.0) {
        skillCooldowns.remove(key);
      } else {
        skillCooldowns[key] = next;
      }
    }

    for (var i = floatingNumbers.length - 1; i >= 0; i--) {
      final f = floatingNumbers[i];
      f.ageSec += dt;
      f.y += f.vy * dt;
      f.vy *= math.pow(0.25, dt).toDouble();
      if (f.isExpired) {
        floatingNumbers.removeAt(i);
      }
    }

    _stepSilkBindChannel(
      dt: dt,
      player: player,
      input: input,
      progress: progress,
      events: events,
    );

    if (input.slashJustPressed &&
        slashCooldownTimer <= 0.0 &&
        !player.grappleActive) {
      if (isChannelingBind) {
        isChannelingBind = false;
        bindElapsedSec = 0.0;
      }
      _spawnMeleeSlash(
        player: player,
        input: input,
        progress: progress,
        events: events,
      );
    }

    if (input.skillJustPressed && !player.grappleActive) {
      tryCastSilkSkill(
        skillId: progress.activeSkill,
        player: player,
        progress: progress,
        events: events,
      );
    }

    for (var i = activeSlashes.length - 1; i >= 0; i--) {
      final slash = activeSlashes[i];
      slash.elapsedSec += dt;
      final hitbox = slash.worldHitbox(player);

      _resolveSlashAgainstTargets(
        slash: slash,
        hitbox: hitbox,
        player: player,
        progress: progress,
        physicsEngine: physicsEngine,
        targets: targets,
        events: events,
      );
      _resolveSlashAgainstProjectiles(
        slash: slash,
        hitbox: hitbox,
        player: player,
        events: events,
      );
      _resolveSlashAgainstTiles(
        slash: slash,
        hitbox: hitbox,
        player: player,
        chamber: chamber,
        progress: progress,
        physicsEngine: physicsEngine,
        events: events,
      );

      if (slash.isFinished) {
        activeSlashes.removeAt(i);
      }
    }

    for (var i = activeSkills.length - 1; i >= 0; i--) {
      final fx = activeSkills[i];
      fx.elapsedSec += dt;

      if (fx.skillId == DungeonSilkSkillId.sanduguanThread && fx.elapsedSec < 0.20) {
        player.vx = fx.facing * 540.0;
        player.vy = 0.0;
      }

      final hitbox = fx.worldHitbox(player);
      _resolveSkillAgainstTargets(
        fx: fx,
        hitbox: hitbox,
        player: player,
        targets: targets,
        events: events,
      );

      if (fx.skillId == DungeonSilkSkillId.scalesTempest) {
        for (final proj in projectiles) {
          if (proj.expired || proj.isPlayerOwned || !proj.deflectable) continue;
          if (hitbox.overlaps(proj.hitbox)) {
            _deflectProjectile(proj, player, events);
          }
        }
      }

      if (fx.isFinished) {
        activeSkills.removeAt(i);
      }
    }

    _stepProjectiles(
      dt: dt,
      player: player,
      chamber: chamber,
      progress: progress,
      targets: targets,
      events: events,
    );

    return events;
  }

  bool tryCastSilkSkill({
    required DungeonSilkSkillId skillId,
    required DungeonPlayerPhysicsState player,
    required DungeonProgressSave progress,
    required List<DungeonCombatEvent> events,
  }) {
    if (!progress.unlockedSkills.contains(skillId)) return false;
    if ((skillCooldowns[skillId] ?? 0.0) > 0.0) return false;

    final spec = silkSkillSpecFor(skillId);
    if (skillId == DungeonSilkSkillId.silkBind) {
      if (isChannelingBind ||
          player.resolveHp >= player.maxResolveHp ||
          player.civicSilk < spec.silkCost) {
        return false;
      }
      isChannelingBind = true;
      bindElapsedSec = 0.0;
      bindTargetDurationSec =
          progress.hasCharmEquipped('babaylan_bind') ? 0.46 : 0.72;
      events.add(
        DungeonCombatEvent(
          kind: DungeonCombatEventKind.bindStarted,
          x: player.centerX,
          y: player.centerY,
          skillId: skillId,
        ),
      );
      return true;
    }

    if (!player.spendSilk(spec.silkCost.toDouble())) return false;
    skillCooldowns[skillId] = spec.cooldownSec;

    final baseDmg = progress.bladeTier.baseDamage;
    final skillDmg = (baseDmg * spec.damageMultiplier).round();

    switch (skillId) {
      case DungeonSilkSkillId.sanduguanThread:
        player.invulnTimer = math.max(player.invulnTimer, 0.26);
        player.vx = player.facing * 540.0;
        player.vy = 0.0;
        player.squashX = 1.38;
        player.squashY = 0.70;
        activeSkills.add(
          ActiveSkillEffect(
            id: _nextId++,
            skillId: skillId,
            x: player.centerX,
            y: player.centerY,
            facing: player.facing,
            damage: skillDmg,
            radiusOrLength: 42.0,
            heightPx: 20.0,
            color: spec.fxColor,
            durationSec: 0.24,
          ),
        );
        break;

      case DungeonSilkSkillId.scalesTempest:
        activeSkills.add(
          ActiveSkillEffect(
            id: _nextId++,
            skillId: skillId,
            x: player.centerX,
            y: player.centerY,
            facing: player.facing,
            damage: skillDmg,
            radiusOrLength: 44.0,
            heightPx: 44.0,
            color: spec.fxColor,
            durationSec: 0.36,
          ),
        );
        break;

      case DungeonSilkSkillId.habeasAegis:
        parryWindowTimer =
            progress.hasCharmEquipped('iron_parry_crest') ? 0.36 : 0.25;
        break;

      case DungeonSilkSkillId.sovereignSunburst:
        hitStop.trigger(0.055);
        activeSkills.add(
          ActiveSkillEffect(
            id: _nextId++,
            skillId: skillId,
            x: player.centerX,
            y: player.centerY,
            facing: player.facing,
            damage: skillDmg,
            radiusOrLength: 220.0,
            heightPx: 32.0,
            color: spec.fxColor,
            durationSec: 0.42,
          ),
        );
        break;

      case DungeonSilkSkillId.silkBind:
        break;
    }

    events.add(
      DungeonCombatEvent(
        kind: DungeonCombatEventKind.skillCast,
        x: player.centerX,
        y: player.centerY,
        shakeIntensity: skillId == DungeonSilkSkillId.sovereignSunburst ? 5.5 : 2.5,
        skillId: skillId,
      ),
    );
    return true;
  }

  ({bool damaged, bool parried}) resolveIncomingPlayerHit({
    required DungeonPlayerPhysicsState player,
    required DungeonProgressSave progress,
    required int damage,
    required double sourceX,
    required double sourceY,
    List<DungeonCombatTarget> targets = const <DungeonCombatTarget>[],
    required List<DungeonCombatEvent> events,
  }) {
    if (isParryActive) {
      parryWindowTimer = 0.0;
      player.invulnTimer = math.max(player.invulnTimer, 0.55);
      player.addSilk(35.0);
      hitStop.trigger(0.100);

      final crestMult = progress.hasCharmEquipped('iron_parry_crest') ? 1.35 : 1.0;
      final counterDmg = (progress.bladeTier.baseDamage * 3.0 * crestMult).round();
      final counterFx = ActiveSkillEffect(
        id: _nextId++,
        skillId: DungeonSilkSkillId.habeasAegis,
        x: player.centerX,
        y: player.centerY,
        facing: player.facing,
        damage: counterDmg,
        radiusOrLength: 58.0,
        heightPx: 58.0,
        color: SpriteCastPalette.endesga32[11],
        durationSec: 0.28,
      );
      activeSkills.add(counterFx);
      _resolveSkillAgainstTargets(
        fx: counterFx,
        hitbox: counterFx.worldHitbox(player),
        player: player,
        targets: targets,
        events: events,
      );

      floatingNumbers.add(
        FloatingCombatNumber(
          text: 'PARRY!',
          color: SpriteCastPalette.endesga32[11],
          x: player.centerX,
          y: player.y - 8.0,
          isCritical: true,
        ),
      );
      events.add(
        DungeonCombatEvent(
          kind: DungeonCombatEventKind.parrySuccess,
          x: player.centerX,
          y: player.centerY,
          shakeIntensity: 6.0,
          value: counterDmg,
          skillId: DungeonSilkSkillId.habeasAegis,
        ),
      );
      return (damaged: false, parried: true);
    }

    if (player.isInvulnerable) {
      return (damaged: false, parried: false);
    }

    final clampedDmg = math.max(1, damage);
    player.resolveHp = math.max(0, player.resolveHp - clampedDmg);
    final hasWard = progress.hasCharmEquipped('charter_ward');
    player.invulnTimer = hasWard ? 1.55 : 1.0;
    final kbDir = player.centerX >= sourceX ? 1.0 : -1.0;
    final kbMult = hasWard ? 0.55 : 1.0;
    player.vx = kbDir * 195.0 * kbMult;
    player.vy = -175.0 * kbMult;
    player.knockbackLockTimer = 0.16;
    player.dashTimer = 0.0;
    player.grappleActive = false;
    hitStop.trigger(0.070);

    if (isChannelingBind) {
      isChannelingBind = false;
      bindElapsedSec = 0.0;
      events.add(
        DungeonCombatEvent(
          kind: DungeonCombatEventKind.bindInterrupted,
          x: player.centerX,
          y: player.centerY,
          skillId: DungeonSilkSkillId.silkBind,
        ),
      );
    }

    floatingNumbers.add(
      FloatingCombatNumber(
        text: '-$clampedDmg',
        color: SpriteCastPalette.endesga32[8],
        x: player.centerX,
        y: player.y - 6.0,
      ),
    );
    events.add(
      DungeonCombatEvent(
        kind: DungeonCombatEventKind.playerDamaged,
        x: player.centerX,
        y: player.centerY,
        shakeIntensity: 5.0,
        value: clampedDmg,
      ),
    );
    return (damaged: true, parried: false);
  }

  void _stepSilkBindChannel({
    required double dt,
    required DungeonPlayerPhysicsState player,
    required DungeonPlayerInput input,
    required DungeonProgressSave progress,
    required List<DungeonCombatEvent> events,
  }) {
    final bindSpec = silkSkillSpecFor(DungeonSilkSkillId.silkBind);
    final canBind = progress.unlockedSkills.contains(DungeonSilkSkillId.silkBind) &&
        player.resolveHp < player.maxResolveHp &&
        player.civicSilk >= bindSpec.silkCost;

    if (input.healHeld && canBind && !isChannelingBind) {
      isChannelingBind = true;
      bindElapsedSec = 0.0;
      bindTargetDurationSec =
          progress.hasCharmEquipped('babaylan_bind') ? 0.46 : 0.72;
      events.add(
        DungeonCombatEvent(
          kind: DungeonCombatEventKind.bindStarted,
          x: player.centerX,
          y: player.centerY,
          skillId: DungeonSilkSkillId.silkBind,
        ),
      );
    }

    if (isChannelingBind) {
      if (!input.healHeld && bindElapsedSec > 0.08) {
        isChannelingBind = false;
        bindElapsedSec = 0.0;
        return;
      }
      player.vx *= 0.75;
      if (player.vy > 18.0) player.vy = 18.0;
      bindElapsedSec += dt;

      if (bindElapsedSec >= bindTargetDurationSec) {
        isChannelingBind = false;
        bindElapsedSec = 0.0;
        if (player.spendSilk(bindSpec.silkCost.toDouble())) {
          final healMasks =
              progress.hasCharmEquipped('babaylan_bind') ? 3 : 2;
          final before = player.resolveHp;
          player.resolveHp =
              math.min(player.maxResolveHp, player.resolveHp + healMasks);
          final healed = player.resolveHp - before;
          floatingNumbers.add(
            FloatingCombatNumber(
              text: '+$healed HP',
              color: SpriteCastPalette.endesga32[12],
              x: player.centerX,
              y: player.y - 8.0,
              isCritical: true,
            ),
          );
          events.add(
            DungeonCombatEvent(
              kind: DungeonCombatEventKind.bindCompleted,
              x: player.centerX,
              y: player.centerY,
              value: healed,
              skillId: DungeonSilkSkillId.silkBind,
            ),
          );
        }
      }
    }
  }

  void _spawnMeleeSlash({
    required DungeonPlayerPhysicsState player,
    required DungeonPlayerInput input,
    required DungeonProgressSave progress,
    required List<DungeonCombatEvent> events,
  }) {
    DungeonSlashDirection dir;
    if (input.moveY < -0.55) {
      dir = DungeonSlashDirection.up;
    } else if (input.moveY > 0.55 && !player.isGrounded) {
      dir = DungeonSlashDirection.down;
    } else {
      dir = player.facing >= 0
          ? DungeonSlashDirection.right
          : DungeonSlashDirection.left;
    }

    final quickSlash = progress.hasCharmEquipped('quick_slash_bolo');
    final longNeedle = progress.hasCharmEquipped('long_needle');

    slashCooldownTimer = quickSlash ? 0.165 : 0.23;
    final currentStep = comboStep;
    comboStep = (comboStep + 1) % 3;
    comboResetTimer = 0.55;

    final isFinisher = currentStep == 2;
    final baseDmg = progress.bladeTier.baseDamage;
    final dmg = isFinisher ? (baseDmg * 1.25).round() : baseDmg;
    final reach = (24.0 + progress.bladeTier.reachBonusPx) *
        (longNeedle ? 1.30 : 1.0) *
        (isFinisher ? 1.12 : 1.0);
    final thickness = 18.0 * (longNeedle ? 1.18 : 1.0);

    activeSlashes.add(
      ActiveSlashArc(
        id: _nextId++,
        direction: dir,
        comboStep: currentStep,
        damage: dmg,
        reachPx: reach,
        thicknessPx: thickness,
        arcColor: isFinisher
            ? SpriteCastPalette.endesga32[11]
            : progress.bladeTier.slashArcColor,
      ),
    );
    events.add(
      DungeonCombatEvent(
        kind: DungeonCombatEventKind.slashSwung,
        x: player.centerX,
        y: player.centerY,
        value: currentStep,
      ),
    );
  }

  void _resolveSlashAgainstTargets({
    required ActiveSlashArc slash,
    required Rect hitbox,
    required DungeonPlayerPhysicsState player,
    required DungeonProgressSave progress,
    required DungeonPhysicsEngine physicsEngine,
    required List<DungeonCombatTarget> targets,
    required List<DungeonCombatEvent> events,
  }) {
    final silkPerHit =
        progress.hasCharmEquipped('scholars_silk') ? 14.0 : 10.0;

    for (final target in targets) {
      if (!target.isAlive || slash.hitTargetIds.contains(target.id)) continue;
      if (!hitbox.overlaps(target.hitbox)) continue;

      slash.hitTargetIds.add(target.id);
      final kbDirX = slash.direction == DungeonSlashDirection.left
          ? -1.0
          : (slash.direction == DungeonSlashDirection.right
              ? 1.0
              : (target.hitbox.center.dx >= player.centerX ? 1.0 : -1.0));
      final dealt = target.receiveDamage(
        amount: slash.damage,
        knockbackVx: kbDirX * 145.0,
        knockbackVy: slash.direction == DungeonSlashDirection.up ? -140.0 : -75.0,
        isSkillOrCrit: slash.comboStep == 2,
        attackerCenterX: player.centerX,
        attackerCenterY: player.centerY,
      );

      if (slash.direction == DungeonSlashDirection.down && !slash.triggeredPogo) {
        slash.triggeredPogo = true;
        physicsEngine.triggerPogoBounce(
          player,
          hasDoubleJumpCharm: progress.hasCharmEquipped('double_pogo_boots'),
        );
      } else if (slash.direction == DungeonSlashDirection.right) {
        player.vx = math.min(player.vx, -55.0);
      } else if (slash.direction == DungeonSlashDirection.left) {
        player.vx = math.max(player.vx, 55.0);
      }

      if (dealt <= 0) {
        hitStop.trigger(0.035);
        floatingNumbers.add(
          FloatingCombatNumber(
            text: 'CLANG!',
            color: SpriteCastPalette.endesga32[20],
            x: target.hitbox.center.dx,
            y: target.hitbox.top - 4.0,
          ),
        );
        events.add(
          DungeonCombatEvent(
            kind: DungeonCombatEventKind.enemyBlockedByShield,
            x: target.hitbox.center.dx,
            y: target.hitbox.center.dy,
            shakeIntensity: 1.5,
            targetId: target.id,
          ),
        );
        continue;
      }

      player.addSilk(silkPerHit);
      final isCrit = slash.comboStep == 2;
      hitStop.trigger(isCrit ? 0.080 : 0.055);
      floatingNumbers.add(
        FloatingCombatNumber(
          text: isCrit ? '$dealt!' : '$dealt',
          color: isCrit
              ? SpriteCastPalette.endesga32[11]
              : SpriteCastPalette.endesga32[19],
          x: target.hitbox.center.dx,
          y: target.hitbox.top - 4.0,
          isCritical: isCrit,
        ),
      );
      events.add(
        DungeonCombatEvent(
          kind: target.isAlive
              ? DungeonCombatEventKind.enemyHit
              : DungeonCombatEventKind.enemyDefeated,
          x: target.hitbox.center.dx,
          y: target.hitbox.center.dy,
          shakeIntensity: isCrit ? 3.5 : 2.0,
          value: dealt,
          targetId: target.id,
        ),
      );
    }
  }

  void _resolveSkillAgainstTargets({
    required ActiveSkillEffect fx,
    required Rect hitbox,
    required DungeonPlayerPhysicsState player,
    required List<DungeonCombatTarget> targets,
    required List<DungeonCombatEvent> events,
  }) {
    if (fx.damage <= 0) return;
    for (final target in targets) {
      if (!target.isAlive || fx.hitTargetIds.contains(target.id)) continue;
      if (!hitbox.overlaps(target.hitbox)) continue;

      fx.hitTargetIds.add(target.id);
      final kbDirX = target.hitbox.center.dx >= player.centerX ? 1.0 : -1.0;
      final dealt = target.receiveDamage(
        amount: fx.damage,
        knockbackVx: kbDirX * 210.0,
        knockbackVy: -120.0,
        isSkillOrCrit: true,
        attackerCenterX: player.centerX,
        attackerCenterY: player.centerY,
      );
      if (dealt > 0) {
        hitStop.trigger(0.082);
        floatingNumbers.add(
          FloatingCombatNumber(
            text: '$dealt★',
            color: fx.color,
            x: target.hitbox.center.dx,
            y: target.hitbox.top - 6.0,
            isCritical: true,
          ),
        );
        events.add(
          DungeonCombatEvent(
            kind: target.isAlive
                ? DungeonCombatEventKind.enemyHit
                : DungeonCombatEventKind.enemyDefeated,
            x: target.hitbox.center.dx,
            y: target.hitbox.center.dy,
            shakeIntensity: 4.0,
            value: dealt,
            skillId: fx.skillId,
            targetId: target.id,
          ),
        );
      }
    }
  }

  void _resolveSlashAgainstProjectiles({
    required ActiveSlashArc slash,
    required Rect hitbox,
    required DungeonPlayerPhysicsState player,
    required List<DungeonCombatEvent> events,
  }) {
    for (final proj in projectiles) {
      if (proj.expired || proj.isPlayerOwned || !proj.deflectable) continue;
      if (!hitbox.overlaps(proj.hitbox)) continue;
      _deflectProjectile(proj, player, events);
    }
  }

  void _deflectProjectile(
    DungeonProjectile proj,
    DungeonPlayerPhysicsState player,
    List<DungeonCombatEvent> events,
  ) {
    proj.isPlayerOwned = true;
    proj.vx = -proj.vx * 1.45;
    proj.vy = -proj.vy * 1.20;
    proj.damage = math.max(14, proj.damage * 2);
    proj.color = SpriteCastPalette.endesga32[18];
    proj.remainingLifeSec = 2.4;
    player.addSilk(8.0);
    hitStop.trigger(0.045);
    floatingNumbers.add(
      FloatingCombatNumber(
        text: 'DEFLECT!',
        color: SpriteCastPalette.endesga32[18],
        x: proj.x,
        y: proj.y - 6.0,
      ),
    );
    events.add(
      DungeonCombatEvent(
        kind: DungeonCombatEventKind.projectileDeflected,
        x: proj.x,
        y: proj.y,
        shakeIntensity: 2.0,
      ),
    );
  }

  void _resolveSlashAgainstTiles({
    required ActiveSlashArc slash,
    required Rect hitbox,
    required DungeonPlayerPhysicsState player,
    required DungeonChamberRuntime chamber,
    required DungeonProgressSave progress,
    required DungeonPhysicsEngine physicsEngine,
    required List<DungeonCombatEvent> events,
  }) {
    final c0 = (hitbox.left / kDungeonTileSize).floor().clamp(0, chamber.spec.cols - 1);
    final c1 = (hitbox.right / kDungeonTileSize).floor().clamp(0, chamber.spec.cols - 1);
    final r0 = (hitbox.top / kDungeonTileSize).floor().clamp(0, chamber.spec.rows - 1);
    final r1 = (hitbox.bottom / kDungeonTileSize).floor().clamp(0, chamber.spec.rows - 1);

    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        final key = '${c}_$r';
        if (slash.hitTileKeys.contains(key)) continue;
        final tile = chamber.effectiveTileAt(c, r);
        final tx = (c + 0.5) * kDungeonTileSize;
        final ty = (r + 0.5) * kDungeonTileSize;

        if (slash.direction == DungeonSlashDirection.down &&
            tile.isPogoTarget &&
            !slash.triggeredPogo) {
          slash.triggeredPogo = true;
          slash.hitTileKeys.add(key);
          physicsEngine.triggerPogoBounce(
            player,
            hasDoubleJumpCharm: progress.hasCharmEquipped('double_pogo_boots'),
          );
          if (tile == DungeonTileType.pogoLantern) {
            player.addSilk(6.0);
            events.add(
              DungeonCombatEvent(
                kind: DungeonCombatEventKind.pogoLanternStruck,
                x: tx,
                y: ty,
                tileKey: '${chamber.spec.id}:$key',
              ),
            );
          }
          hitStop.trigger(0.032);
          continue;
        }

        final br = chamber.breakables[key];
        if (br == null || br.brokenOrTriggered) continue;
        slash.hitTileKeys.add(key);
        br.hitFlashTimer = 0.14;
        br.hp = math.max(0, br.hp - 1);

        if (br.kind == DungeonTileType.crystalVein) {
          _spawnLootBurst(
            chamber,
            tx,
            ty,
            shardCount: br.hp == 0 ? 4 : 2,
            spawnSilkMote: br.hp == 0,
          );
          if (br.hp == 0) br.brokenOrTriggered = true;
          hitStop.trigger(0.038);
          events.add(
            DungeonCombatEvent(
              kind: DungeonCombatEventKind.crystalMined,
              x: tx,
              y: ty,
              shakeIntensity: br.hp == 0 ? 2.5 : 1.2,
              tileKey: '${chamber.spec.id}:$key',
            ),
          );
        } else if (br.kind == DungeonTileType.breakableCrate && br.hp == 0) {
          br.brokenOrTriggered = true;
          _spawnLootBurst(
            chamber,
            tx,
            ty,
            shardCount: 3,
            spawnResolveOrb: (c + r) % 4 == 0,
            spawnSilkMote: (c + r) % 2 == 1,
          );
          hitStop.trigger(0.035);
          events.add(
            DungeonCombatEvent(
              kind: DungeonCombatEventKind.crateBroken,
              x: tx,
              y: ty,
              shakeIntensity: 1.8,
              tileKey: '${chamber.spec.id}:$key',
            ),
          );
        } else if (br.kind == DungeonTileType.secretWall && br.hp == 0) {
          br.brokenOrTriggered = true;
          hitStop.trigger(0.065);
          floatingNumbers.add(
            FloatingCombatNumber(
              text: 'SECRET!',
              color: SpriteCastPalette.endesga32[11],
              x: tx,
              y: ty - 8.0,
              isCritical: true,
            ),
          );
          events.add(
            DungeonCombatEvent(
              kind: DungeonCombatEventKind.secretWallBroken,
              x: tx,
              y: ty,
              shakeIntensity: 4.0,
              tileKey: '${chamber.spec.id}:$key',
            ),
          );
        } else if (br.kind == DungeonTileType.switchPedestal && br.hp == 0) {
          br.brokenOrTriggered = true;
          chamber.roomGateUnlocked = true;
          hitStop.trigger(0.060);
          floatingNumbers.add(
            FloatingCombatNumber(
              text: 'GATE OPEN!',
              color: SpriteCastPalette.endesga32[18],
              x: tx,
              y: ty - 10.0,
              isCritical: true,
            ),
          );
          events.add(
            DungeonCombatEvent(
              kind: DungeonCombatEventKind.gateUnlocked,
              x: tx,
              y: ty,
              shakeIntensity: 3.5,
              tileKey: '${chamber.spec.id}:$key',
            ),
          );
        }
      }
    }
  }

  void _stepProjectiles({
    required double dt,
    required DungeonPlayerPhysicsState player,
    required DungeonChamberRuntime chamber,
    required DungeonProgressSave progress,
    required List<DungeonCombatTarget> targets,
    required List<DungeonCombatEvent> events,
  }) {
    for (var i = projectiles.length - 1; i >= 0; i--) {
      final p = projectiles[i];
      if (p.expired) {
        projectiles.removeAt(i);
        continue;
      }
      p.remainingLifeSec -= dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;

      final col = (p.x / kDungeonTileSize).floor();
      final row = (p.y / kDungeonTileSize).floor();
      if (p.remainingLifeSec <= 0.0 || chamber.isSolidAt(col, row)) {
        p.expired = true;
        projectiles.removeAt(i);
        continue;
      }

      if (p.isPlayerOwned) {
        for (final t in targets) {
          if (!t.isAlive) continue;
          if (p.hitbox.overlaps(t.hitbox)) {
            final dealt = t.receiveDamage(
              amount: p.damage,
              knockbackVx: p.vx >= 0 ? 130.0 : -130.0,
              knockbackVy: -65.0,
              isSkillOrCrit: true,
              attackerCenterX: p.x,
              attackerCenterY: p.y,
            );
            p.expired = true;
            if (dealt > 0) {
              hitStop.trigger(0.050);
              floatingNumbers.add(
                FloatingCombatNumber(
                  text: '$dealt',
                  color: p.color,
                  x: t.hitbox.center.dx,
                  y: t.hitbox.top - 4.0,
                ),
              );
              events.add(
                DungeonCombatEvent(
                  kind: t.isAlive
                      ? DungeonCombatEventKind.enemyHit
                      : DungeonCombatEventKind.enemyDefeated,
                  x: t.hitbox.center.dx,
                  y: t.hitbox.center.dy,
                  shakeIntensity: 2.2,
                  value: dealt,
                  targetId: t.id,
                ),
              );
            }
            break;
          }
        }
      } else {
        if (p.hitbox.overlaps(player.hitbox)) {
          final outcome = resolveIncomingPlayerHit(
            player: player,
            progress: progress,
            damage: p.damage,
            sourceX: p.x,
            sourceY: p.y,
            targets: targets,
            events: events,
          );
          if (outcome.parried) {
            _deflectProjectile(p, player, events);
          } else {
            p.expired = true;
          }
        }
      }

      if (p.expired) {
        projectiles.removeAt(i);
      }
    }
  }

  void _spawnLootBurst(
    DungeonChamberRuntime chamber,
    double x,
    double y, {
    int shardCount = 3,
    bool spawnResolveOrb = false,
    bool spawnSilkMote = false,
  }) {
    for (var i = 0; i < shardCount; i++) {
      final spread = ((i - (shardCount - 1) * 0.5) * 38.0);
      chamber.lootDrops.add(
        DungeonLootDrop(
          id: 'loot_${_nextId++}',
          kind: DungeonLootKind.archipelagoShard,
          amount: 3,
          x: x,
          y: y - 2.0,
          vx: spread,
          vy: -135.0 - (i % 2) * 35.0,
        ),
      );
    }
    if (spawnResolveOrb) {
      chamber.lootDrops.add(
        DungeonLootDrop(
          id: 'loot_${_nextId++}',
          kind: DungeonLootKind.resolveOrb,
          amount: 1,
          x: x,
          y: y - 4.0,
          vx: -25.0,
          vy: -150.0,
        ),
      );
    }
    if (spawnSilkMote) {
      chamber.lootDrops.add(
        DungeonLootDrop(
          id: 'loot_${_nextId++}',
          kind: DungeonLootKind.silkMote,
          amount: 18,
          x: x,
          y: y - 4.0,
          vx: 25.0,
          vy: -150.0,
        ),
      );
    }
  }
}
