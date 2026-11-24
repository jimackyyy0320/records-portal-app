import 'dart:math' as math;
import 'package:flutter/material.dart';

import 'dungeon_models.dart';

/// Event emitted by [DungeonPhysicsEngine] so VFX, SFX, camera shake, and HUD
/// respond within <100ms (`craft-game-floors` Game Feel Floor) without coupling
/// simulation logic to rendering widgets.
enum DungeonPhysicsEventKind {
  jumped,
  doubleJumped,
  wallJumped,
  landed,
  dashed,
  pogoBounced,
  grappleStarted,
  grappleReleased,
  hazardHit,
  crumbleCollapsed,
  lootCollected,
}

class DungeonPhysicsEvent {
  final DungeonPhysicsEventKind kind;
  final double x;
  final double y;
  final double intensity;
  final DungeonLootKind? lootKind;
  final int amount;

  const DungeonPhysicsEvent({
    required this.kind,
    required this.x,
    required this.y,
    this.intensity = 1.0,
    this.lootKind,
    this.amount = 0,
  });
}

/// Centralized exposed physics tunables (`craft-game-floors` + `create-2d-physics`).
class DungeonPhysicsTunables {
  final double fixedSubStep; // 1/120s for zero tunneling
  final double gravity; // px/s²
  final double fallGravityMultiplier; // heavier descent for crisp platforming
  final double maxFallSpeed;
  final double runSpeed;
  final double groundAccel;
  final double groundDecel;
  final double airAccel;
  final double airDecel;
  final double jumpVelocity;
  final double doubleJumpVelocity;
  final double variableJumpCutFactor;
  final double coyoteTimeSec; // 110ms
  final double jumpBufferSec; // 120ms
  final double dropThroughSec; // 220ms
  final double climbSpeed;
  final double wallSlideMaxFall;
  final double wallCoyoteSec; // 100ms
  final double wallJumpVx;
  final double wallJumpVy;
  final double wallJumpLockSec;
  final double dashSpeed;
  final double dashDurationSec; // 180ms
  final double dashInvulnSec; // 220ms
  final double dashCooldownSec; // 450ms
  final double pogoBounceVy;
  final double grappleRangePx;
  final double grappleZipSpeed;
  final double grappleReleasePopVy;
  final double grappleCooldownSec;
  final double cornerCorrectionPx;
  final double crumbleShakeSec;
  final double crumbleRespawnSec;

  const DungeonPhysicsTunables({
    this.fixedSubStep = 1.0 / 120.0,
    this.gravity = 1340.0,
    this.fallGravityMultiplier = 1.28,
    this.maxFallSpeed = 540.0,
    this.runSpeed = 205.0,
    this.groundAccel = 1950.0,
    this.groundDecel = 2250.0,
    this.airAccel = 1350.0,
    this.airDecel = 650.0,
    this.jumpVelocity = -425.0,
    this.doubleJumpVelocity = -385.0,
    this.variableJumpCutFactor = 0.48,
    this.coyoteTimeSec = 0.110,
    this.jumpBufferSec = 0.120,
    this.dropThroughSec = 0.220,
    this.climbSpeed = 128.0,
    this.wallSlideMaxFall = 108.0,
    this.wallCoyoteSec = 0.105,
    this.wallJumpVx = 242.0,
    this.wallJumpVy = -408.0,
    this.wallJumpLockSec = 0.125,
    this.dashSpeed = 470.0,
    this.dashDurationSec = 0.180,
    this.dashInvulnSec = 0.220,
    this.dashCooldownSec = 0.450,
    this.pogoBounceVy = -405.0,
    this.grappleRangePx = 176.0,
    this.grappleZipSpeed = 610.0,
    this.grappleReleasePopVy = -295.0,
    this.grappleCooldownSec = 0.55,
    this.cornerCorrectionPx = 5.0,
    this.crumbleShakeSec = 0.45,
    this.crumbleRespawnSec = 3.0,
  });
}

/// Fixed-timestep Silksong × Terraria 2D Action-Platformer Physics Engine.
class DungeonPhysicsEngine {
  final DungeonPhysicsTunables tunables;
  double _accumulator = 0.0;
  double _afterimageSampleTimer = 0.0;

  DungeonPhysicsEngine({this.tunables = const DungeonPhysicsTunables()});

  void resetAccumulator() {
    _accumulator = 0.0;
    _afterimageSampleTimer = 0.0;
  }

  /// Steps the player, crumble tiles, hazards, and loot drops forward by [dt]
  /// using exact `1/120s` sub-steps. Returns all [DungeonPhysicsEvent]s fired
  /// during this frame.
  List<DungeonPhysicsEvent> step({
    required double dt,
    required DungeonPlayerPhysicsState player,
    required DungeonChamberRuntime chamber,
    required DungeonPlayerInput input,
    bool hasDoubleJumpCharm = false,
    bool hasMagnetCharm = false,
    bool hasStalwartWardCharm = false,
  }) {
    final events = <DungeonPhysicsEvent>[];
    final clampedDt = dt.clamp(0.0, 0.05);
    _accumulator += clampedDt;

    // Edge-triggered button presses are consumed on the first sub-step of the frame
    var pendingInput = input;
    var subSteps = 0;
    while (_accumulator >= tunables.fixedSubStep && subSteps < 8) {
      _stepSingleFixed(
        dt: tunables.fixedSubStep,
        player: player,
        chamber: chamber,
        input: pendingInput,
        events: events,
        hasDoubleJumpCharm: hasDoubleJumpCharm,
        hasMagnetCharm: hasMagnetCharm,
        hasStalwartWardCharm: hasStalwartWardCharm,
      );
      _accumulator -= tunables.fixedSubStep;
      subSteps++;
      // Clear one-shot press flags for remaining sub-steps in this frame
      pendingInput = DungeonPlayerInput(
        moveX: input.moveX,
        moveY: input.moveY,
        jumpHeld: input.jumpHeld,
        healHeld: input.healHeld,
      );
    }

    // If dt was smaller than fixedSubStep (e.g. fast test step) and a one-shot
    // press arrived, process it immediately so input is never dropped.
    if (subSteps == 0 && clampedDt > 0.0) {
      _stepSingleFixed(
        dt: clampedDt,
        player: player,
        chamber: chamber,
        input: pendingInput,
        events: events,
        hasDoubleJumpCharm: hasDoubleJumpCharm,
        hasMagnetCharm: hasMagnetCharm,
        hasStalwartWardCharm: hasStalwartWardCharm,
      );
      _accumulator = 0.0;
    }

    return events;
  }

  void _stepSingleFixed({
    required double dt,
    required DungeonPlayerPhysicsState player,
    required DungeonChamberRuntime chamber,
    required DungeonPlayerInput input,
    required List<DungeonPhysicsEvent> events,
    required bool hasDoubleJumpCharm,
    required bool hasMagnetCharm,
    required bool hasStalwartWardCharm,
  }) {
    // 1. Tick cooldown & forgiveness timers
    player.idleTime += dt;
    player.coyoteTimer = math.max(0.0, player.coyoteTimer - dt);
    player.jumpBufferTimer = math.max(0.0, player.jumpBufferTimer - dt);
    player.dropThroughTimer = math.max(0.0, player.dropThroughTimer - dt);
    player.wallCoyoteTimer = math.max(0.0, player.wallCoyoteTimer - dt);
    player.wallJumpLockTimer = math.max(0.0, player.wallJumpLockTimer - dt);
    player.dashCooldownTimer = math.max(0.0, player.dashCooldownTimer - dt);
    player.grappleCooldownTimer = math.max(0.0, player.grappleCooldownTimer - dt);
    player.invulnTimer = math.max(0.0, player.invulnTimer - dt);
    player.knockbackLockTimer = math.max(0.0, player.knockbackLockTimer - dt);
    player.pogoBounceTimer = math.max(0.0, player.pogoBounceTimer - dt);

    // Recover visual squash & stretch smoothly toward (1.0, 1.0)
    player.squashX += (1.0 - player.squashX) * math.min(1.0, dt * 16.0);
    player.squashY += (1.0 - player.squashY) * math.min(1.0, dt * 16.0);

    // Fade dash ghost afterimages
    for (var i = player.afterimages.length - 1; i >= 0; i--) {
      player.afterimages[i].alpha -= dt * 3.8;
      if (player.afterimages[i].alpha <= 0.02) {
        player.afterimages.removeAt(i);
      }
    }

    // Tick crumble blocks (shake -> collapse -> regenerate)
    _stepCrumbleBlocks(dt, chamber, events);

    // Update facing direction when player actively steers (unless dashing/locked)
    if (!player.isDashing &&
        !player.grappleActive &&
        player.wallJumpLockTimer <= 0.0 &&
        player.knockbackLockTimer <= 0.0) {
      if (input.moveX > 0.15) {
        player.facing = 1;
      } else if (input.moveX < -0.15) {
        player.facing = -1;
      }
    }

    // Buffer jump press (`120ms` Silksong jump buffer)
    if (input.jumpJustPressed) {
      if (input.dropThroughRequested && player.isOnOneWayPlatform) {
        player.dropThroughTimer = tunables.dropThroughSec;
        player.isGrounded = false;
        player.isOnOneWayPlatform = false;
        player.y += 2.0;
        player.vy = math.max(player.vy, 60.0);
      } else {
        player.jumpBufferTimer = tunables.jumpBufferSec;
      }
    }

    // 2. Check Silk-Needle Grapple Initiation
    if (input.grappleJustPressed &&
        !player.grappleActive &&
        player.grappleCooldownTimer <= 0.0) {
      final anchor = findBestGrappleAnchor(player, chamber, input);
      if (anchor != null) {
        player.grappleActive = true;
        player.grappleTargetX = anchor.dx;
        player.grappleTargetY = anchor.dy;
        player.grappleTimer = 0.45;
        player.grappleCooldownTimer = tunables.grappleCooldownSec;
        player.dashTimer = 0.0;
        player.isOnLadder = false;
        player.isGrounded = false;
        player.facing = anchor.dx >= player.centerX ? 1 : -1;
        events.add(
          DungeonPhysicsEvent(
            kind: DungeonPhysicsEventKind.grappleStarted,
            x: anchor.dx,
            y: anchor.dy,
          ),
        );
      }
    }

    // 3. Handle Active Silk-Needle Grapple Zip
    if (player.grappleActive) {
      player.grappleTimer -= dt;
      final dx = player.grappleTargetX - player.centerX;
      final dy = player.grappleTargetY - player.centerY;
      final dist = math.sqrt(dx * dx + dy * dy);
      if (dist <= 10.0 || player.grappleTimer <= 0.0) {
        player.grappleActive = false;
        player.vy = tunables.grappleReleasePopVy;
        player.vx = player.facing * tunables.runSpeed * 0.72;
        player.airDashAvailable = true;
        player.doubleJumpAvailable = hasDoubleJumpCharm;
        player.squashX = 0.80;
        player.squashY = 1.22;
        events.add(
          DungeonPhysicsEvent(
            kind: DungeonPhysicsEventKind.grappleReleased,
            x: player.centerX,
            y: player.centerY,
          ),
        );
      } else {
        final nx = dx / dist;
        final ny = dy / dist;
        player.vx = nx * tunables.grappleZipSpeed;
        player.vy = ny * tunables.grappleZipSpeed;
        _moveAndCollide(dt, player, chamber, events, hasDoubleJumpCharm);
        _stepLootDrops(dt, player, chamber, events, hasMagnetCharm);
        return;
      }
    }

    // 4. Check Silk Dash Initiation (Ground or Air Dash with I-Frames!)
    if (input.dashJustPressed &&
        !player.isDashing &&
        player.dashCooldownTimer <= 0.0 &&
        (player.isGrounded || player.airDashAvailable || player.isWallSliding)) {
      var dashDir = player.facing;
      if (player.isWallSliding && !player.isGrounded) {
        // Silksong feel: dashing off a wall automatically kicks away from the wall
        dashDir = player.isTouchingWallLeft ? 1 : -1;
        player.facing = dashDir;
      } else if (input.moveX.abs() > 0.2) {
        dashDir = input.moveX > 0 ? 1 : -1;
        player.facing = dashDir;
      }

      player.dashDir = dashDir;
      player.dashTimer = tunables.dashDurationSec;
      player.dashCooldownTimer = tunables.dashCooldownSec;
      player.invulnTimer = math.max(player.invulnTimer, tunables.dashInvulnSec);
      if (!player.isGrounded) {
        player.airDashAvailable = false;
      }
      player.isOnLadder = false;
      player.vx = dashDir * tunables.dashSpeed;
      player.vy = 0.0;
      player.squashX = 1.32;
      player.squashY = 0.74;
      _afterimageSampleTimer = 0.0;
      events.add(
        DungeonPhysicsEvent(
          kind: DungeonPhysicsEventKind.dashed,
          x: player.centerX,
          y: player.centerY,
        ),
      );
    }

    // 5. Active Silk Dash Motion (Zero Gravity, Crisp Ghost Trail)
    if (player.isDashing) {
      player.dashTimer = math.max(0.0, player.dashTimer - dt);
      player.vx = player.dashDir * tunables.dashSpeed;
      player.vy = 0.0;
      _afterimageSampleTimer -= dt;
      if (_afterimageSampleTimer <= 0.0) {
        _afterimageSampleTimer = 0.028;
        player.afterimages.add(
          DashAfterimage(x: player.x, y: player.y, facing: player.facing),
        );
        if (player.afterimages.length > 7) {
          player.afterimages.removeAt(0);
        }
      }
      if (player.dashTimer <= 0.0) {
        // Soft momentum carry-over at end of dash
        player.vx = player.dashDir * tunables.runSpeed * 0.85;
      }
      _moveAndCollide(dt, player, chamber, events, hasDoubleJumpCharm);
      _stepLootDrops(dt, player, chamber, events, hasMagnetCharm);
      return;
    }

    // 6. Ladder / Vine Climbing (`H`)
    final overlappingLadder = _isOverlappingClimbable(player, chamber);
    if (overlappingLadder && input.moveY.abs() > 0.35 && player.jumpBufferTimer <= 0.0) {
      player.isOnLadder = true;
      player.isGrounded = false;
      player.airDashAvailable = true;
      player.doubleJumpAvailable = hasDoubleJumpCharm;
    } else if (!overlappingLadder) {
      player.isOnLadder = false;
    }

    if (player.isOnLadder) {
      player.vx = input.moveX * tunables.runSpeed * 0.65;
      player.vy = input.moveY * tunables.climbSpeed;
      if (player.jumpBufferTimer > 0.0) {
        player.isOnLadder = false;
        player.jumpBufferTimer = 0.0;
        player.vy = tunables.jumpVelocity;
        player.squashX = 0.78;
        player.squashY = 1.25;
        events.add(
          DungeonPhysicsEvent(
            kind: DungeonPhysicsEventKind.jumped,
            x: player.centerX,
            y: player.bottom,
          ),
        );
      }
      _moveAndCollide(dt, player, chamber, events, hasDoubleJumpCharm);
      _stepLootDrops(dt, player, chamber, events, hasMagnetCharm);
      return;
    }

    // 7. Horizontal Ground / Air Acceleration
    final agilityMult = hasDoubleJumpCharm ? 1.12 : 1.0;
    final maxRun = tunables.runSpeed * agilityMult;
    if (player.wallJumpLockTimer <= 0.0 && player.knockbackLockTimer <= 0.0) {
      final targetVx = input.moveX.abs() > 0.1 ? input.moveX * maxRun : 0.0;
      final accel = player.isGrounded
          ? (targetVx.abs() > 0.1 ? tunables.groundAccel : tunables.groundDecel)
          : (targetVx.abs() > 0.1 ? tunables.airAccel : tunables.airDecel);
      player.vx = _moveToward(player.vx, targetVx, accel * dt);
    }

    if (player.isGrounded && player.vx.abs() > 14.0) {
      player.runAnimTime += dt * (player.vx.abs() / maxRun) * 10.5;
    } else if (player.isGrounded) {
      player.runAnimTime = 0.0;
    }

    // 8. Jump Execution (Ground + Coyote, Wall-Jump, or Double-Jump)
    if (player.jumpBufferTimer > 0.0) {
      if (player.isGrounded || player.coyoteTimer > 0.0) {
        player.vy = tunables.jumpVelocity;
        player.isGrounded = false;
        player.isOnOneWayPlatform = false;
        player.coyoteTimer = 0.0;
        player.jumpBufferTimer = 0.0;
        player.squashX = 0.76;
        player.squashY = 1.28;
        events.add(
          DungeonPhysicsEvent(
            kind: DungeonPhysicsEventKind.jumped,
            x: player.centerX,
            y: player.bottom,
          ),
        );
      } else if (player.isWallSliding || player.wallCoyoteTimer > 0.0) {
        final wallDir = player.isTouchingWallLeft
            ? -1
            : (player.isTouchingWallRight ? 1 : player.wallCoyoteDir);
        final kickDir = wallDir == 0 ? -player.facing : -wallDir;
        player.vx = kickDir * tunables.wallJumpVx;
        player.vy = tunables.wallJumpVy;
        player.facing = kickDir;
        player.wallJumpLockTimer = tunables.wallJumpLockSec;
        player.wallCoyoteTimer = 0.0;
        player.isWallSliding = false;
        player.jumpBufferTimer = 0.0;
        player.squashX = 0.78;
        player.squashY = 1.24;
        events.add(
          DungeonPhysicsEvent(
            kind: DungeonPhysicsEventKind.wallJumped,
            x: wallDir < 0 ? player.x : player.right,
            y: player.centerY,
          ),
        );
      } else if (player.doubleJumpAvailable) {
        player.vy = tunables.doubleJumpVelocity;
        player.doubleJumpAvailable = false;
        player.jumpBufferTimer = 0.0;
        player.squashX = 0.80;
        player.squashY = 1.22;
        events.add(
          DungeonPhysicsEvent(
            kind: DungeonPhysicsEventKind.doubleJumped,
            x: player.centerX,
            y: player.bottom,
          ),
        );
      }
    }

    // Variable Jump Height Cut when player releases Jump while ascending
    if (input.jumpJustReleased && player.vy < -65.0 && player.pogoBounceTimer <= 0.0) {
      player.vy *= tunables.variableJumpCutFactor;
    }

    // 9. Gravity & Wall-Slide Clamp
    final gravMult = player.vy > 0.0 ? tunables.fallGravityMultiplier : 1.0;
    player.vy = math.min(
      tunables.maxFallSpeed,
      player.vy + tunables.gravity * gravMult * dt,
    );

    final pressingIntoWall = (player.isTouchingWallLeft && input.moveX < -0.15) ||
        (player.isTouchingWallRight && input.moveX > 0.15);
    if (!player.isGrounded && pressingIntoWall && player.vy > 0.0) {
      player.isWallSliding = true;
      player.vy = math.min(player.vy, tunables.wallSlideMaxFall);
      player.wallCoyoteTimer = tunables.wallCoyoteSec;
      player.wallCoyoteDir = player.isTouchingWallLeft ? -1 : 1;
    } else {
      player.isWallSliding = false;
    }

    // 10. Swept Axis-Separated Tile Resolution & Hazard Check
    _moveAndCollide(dt, player, chamber, events, hasDoubleJumpCharm);
    _checkHazards(player, chamber, events, hasStalwartWardCharm);
    _stepLootDrops(dt, player, chamber, events, hasMagnetCharm);
  }

  /// Resolves horizontal then vertical tile collisions with ceiling corner-correction,
  /// one-way bridge landing, crumble block activation, and wall-contact detection.
  void _moveAndCollide(
    double dt,
    DungeonPlayerPhysicsState player,
    DungeonChamberRuntime chamber,
    List<DungeonPhysicsEvent> events,
    bool hasDoubleJumpCharm,
  ) {
    final wasGrounded = player.isGrounded;
    final preLandingVy = player.vy;
    final prevBottom = player.bottom;

    // ── HORIZONTAL AXIS (X) ──
    player.x += player.vx * dt;
    player.isTouchingWallLeft = false;
    player.isTouchingWallRight = false;

    final topRowX = ((player.y + 1.0) / kDungeonTileSize).floor();
    final botRowX = ((player.bottom - 1.0) / kDungeonTileSize).floor();

    if (player.vx > 0.0) {
      final rightCol = (player.right / kDungeonTileSize).floor();
      for (var r = topRowX; r <= botRowX; r++) {
        if (chamber.isSolidAt(rightCol, r)) {
          player.x = rightCol * kDungeonTileSize - player.width - 0.01;
          player.vx = 0.0;
          player.isTouchingWallRight = true;
          break;
        }
      }
    } else if (player.vx < 0.0) {
      final leftCol = (player.x / kDungeonTileSize).floor();
      for (var r = topRowX; r <= botRowX; r++) {
        if (chamber.isSolidAt(leftCol, r)) {
          player.x = (leftCol + 1) * kDungeonTileSize + 0.01;
          player.vx = 0.0;
          player.isTouchingWallLeft = true;
          break;
        }
      }
    }

    // Detect adjacent wall even when horizontal speed is 0 (for wall-slide & wall-jump)
    if (!player.isTouchingWallLeft) {
      final probeLeftCol = ((player.x - 1.0) / kDungeonTileSize).floor();
      for (var r = topRowX; r <= botRowX; r++) {
        if (chamber.isSolidAt(probeLeftCol, r)) {
          player.isTouchingWallLeft = true;
          player.wallCoyoteTimer = tunables.wallCoyoteSec;
          player.wallCoyoteDir = -1;
          break;
        }
      }
    }
    if (!player.isTouchingWallRight) {
      final probeRightCol = ((player.right + 1.0) / kDungeonTileSize).floor();
      for (var r = topRowX; r <= botRowX; r++) {
        if (chamber.isSolidAt(probeRightCol, r)) {
          player.isTouchingWallRight = true;
          player.wallCoyoteTimer = tunables.wallCoyoteSec;
          player.wallCoyoteDir = 1;
          break;
        }
      }
    }

    // ── VERTICAL AXIS (Y) ──
    player.y += player.vy * dt;
    player.isGrounded = false;
    player.isOnOneWayPlatform = false;

    final leftColY = ((player.x + 0.8) / kDungeonTileSize).floor();
    final rightColY = ((player.right - 0.8) / kDungeonTileSize).floor();

    if (player.vy >= 0.0) {
      final footRow = (player.bottom / kDungeonTileSize).floor();
      var stoodOnSafeSolid = false;
      for (var c = leftColY; c <= rightColY; c++) {
        final tile = chamber.effectiveTileAt(c, footRow);
        final tileTop = footRow * kDungeonTileSize;
        if (tile.isFullSolid) {
          player.y = tileTop - player.height;
          player.vy = 0.0;
          player.isGrounded = true;
          if (tile == DungeonTileType.crumbleBlock) {
            _touchCrumbleBlock(c, footRow, chamber);
          } else {
            stoodOnSafeSolid = true;
          }
          break;
        } else if (tile.isOneWay &&
            player.dropThroughTimer <= 0.0 &&
            prevBottom <= tileTop + 2.5) {
          player.y = tileTop - player.height;
          player.vy = 0.0;
          player.isGrounded = true;
          player.isOnOneWayPlatform = true;
          stoodOnSafeSolid = true;
          break;
        }
      }

      if (player.isGrounded) {
        player.coyoteTimer = tunables.coyoteTimeSec;
        player.airDashAvailable = true;
        player.doubleJumpAvailable = hasDoubleJumpCharm;
        if (stoodOnSafeSolid) {
          player.lastSafeGroundX = player.x;
          player.lastSafeGroundY = player.y;
        }
        if (!wasGrounded && preLandingVy > 110.0) {
          // `craft-game-floors` landing squash (y 0.85 for ~0.1s)
          player.squashX = 1.18;
          player.squashY = 0.84;
          events.add(
            DungeonPhysicsEvent(
              kind: DungeonPhysicsEventKind.landed,
              x: player.centerX,
              y: player.bottom,
              intensity: (preLandingVy / tunables.maxFallSpeed).clamp(0.3, 1.0),
            ),
          );
        }
      }
    } else if (player.vy < 0.0) {
      final headRow = (player.y / kDungeonTileSize).floor();
      var hitLeft = false;
      var hitRight = false;
      for (var c = leftColY; c <= rightColY; c++) {
        if (chamber.isSolidAt(c, headRow)) {
          if (c == leftColY) hitLeft = true;
          if (c == rightColY) hitRight = true;
        }
      }

      if (hitLeft || hitRight) {
        // Silksong/Celeste Ceiling Corner-Correction Nudge!
        var nudged = false;
        if (hitLeft && !hitRight) {
          final tileRightEdge = (leftColY + 1) * kDungeonTileSize;
          final overlap = tileRightEdge - player.x;
          if (overlap > 0.0 && overlap <= tunables.cornerCorrectionPx) {
            final candX = tileRightEdge + 0.1;
            if (!_overlapsSolidAt(candX, player.y, player.width, player.height, chamber)) {
              player.x = candX;
              nudged = true;
            }
          }
        } else if (hitRight && !hitLeft) {
          final tileLeftEdge = rightColY * kDungeonTileSize;
          final overlap = player.right - tileLeftEdge;
          if (overlap > 0.0 && overlap <= tunables.cornerCorrectionPx) {
            final candX = tileLeftEdge - player.width - 0.1;
            if (!_overlapsSolidAt(candX, player.y, player.width, player.height, chamber)) {
              player.x = candX;
              nudged = true;
            }
          }
        }

        if (!nudged) {
          player.y = (headRow + 1) * kDungeonTileSize + 0.01;
          player.vy = 0.0;
        }
      }
    }

    // Clamp cleanly to chamber world borders
    player.x = player.x.clamp(0.0, math.max(0.0, chamber.spec.worldWidth - player.width));
    player.y = player.y.clamp(0.0, math.max(0.0, chamber.spec.worldHeight - player.height));
  }

  /// Triggers a Silksong-style **Downward Pogo-Bounce** (invoked by combat when a
  /// downward slash strikes spikes, a pogo-lantern, an enemy, or a boss).
  /// Launches Alon upward and immediately resets Air-Dash & Double-Jump!
  DungeonPhysicsEvent triggerPogoBounce(
    DungeonPlayerPhysicsState player, {
    bool hasDoubleJumpCharm = false,
  }) {
    player.vy = tunables.pogoBounceVy;
    player.isGrounded = false;
    player.airDashAvailable = true;
    player.doubleJumpAvailable = hasDoubleJumpCharm;
    player.pogoBounceTimer = 0.16;
    player.squashX = 0.78;
    player.squashY = 1.26;
    return DungeonPhysicsEvent(
      kind: DungeonPhysicsEventKind.pogoBounced,
      x: player.centerX,
      y: player.bottom,
    );
  }

  /// Finds the nearest valid `grappleRing` (`G`) within [tunables.grappleRangePx]
  /// biased toward Alon's facing direction & aim vector.
  Offset? findBestGrappleAnchor(
    DungeonPlayerPhysicsState player,
    DungeonChamberRuntime chamber,
    DungeonPlayerInput input,
  ) {
    final maxDist = tunables.grappleRangePx;
    final minCol = ((player.centerX - maxDist) / kDungeonTileSize).floor().clamp(0, chamber.spec.cols - 1);
    final maxCol = ((player.centerX + maxDist) / kDungeonTileSize).ceil().clamp(0, chamber.spec.cols - 1);
    final minRow = ((player.centerY - maxDist) / kDungeonTileSize).floor().clamp(0, chamber.spec.rows - 1);
    final maxRow = ((player.centerY + maxDist) / kDungeonTileSize).ceil().clamp(0, chamber.spec.rows - 1);

    Offset? best;
    var bestScore = double.infinity;
    final preferDirX = input.moveX.abs() > 0.2 ? (input.moveX > 0 ? 1.0 : -1.0) : player.facing.toDouble();

    for (var r = minRow; r <= maxRow; r++) {
      for (var c = minCol; c <= maxCol; c++) {
        if (chamber.effectiveTileAt(c, r) != DungeonTileType.grappleRing) continue;
        final ax = (c + 0.5) * kDungeonTileSize;
        final ay = (r + 0.5) * kDungeonTileSize;
        final dx = ax - player.centerX;
        final dy = ay - player.centerY;
        final dist = math.sqrt(dx * dx + dy * dy);
        if (dist < 18.0 || dist > maxDist) continue;
        // Favor anchors in Alon's facing hemisphere
        final dirPenalty = (dx * preferDirX) >= -16.0 ? 1.0 : 1.85;
        final score = dist * dirPenalty;
        if (score < bestScore) {
          bestScore = score;
          best = Offset(ax, ay);
        }
      }
    }
    return best;
  }

  void _touchCrumbleBlock(int col, int row, DungeonChamberRuntime chamber) {
    final st = chamber.crumbleBlocks['${col}_$row'];
    if (st != null && !st.collapsed && st.shakeTimer <= 0.0) {
      st.shakeTimer = tunables.crumbleShakeSec;
    }
  }

  void _stepCrumbleBlocks(
    double dt,
    DungeonChamberRuntime chamber,
    List<DungeonPhysicsEvent> events,
  ) {
    for (final st in chamber.crumbleBlocks.values) {
      if (st.collapsed) {
        st.respawnTimer -= dt;
        if (st.respawnTimer <= 0.0) {
          st.collapsed = false;
          st.respawnTimer = 0.0;
          st.shakeTimer = 0.0;
        }
      } else if (st.shakeTimer > 0.0) {
        st.shakeTimer -= dt;
        if (st.shakeTimer <= 0.0) {
          st.collapsed = true;
          st.respawnTimer = tunables.crumbleRespawnSec;
          events.add(
            DungeonPhysicsEvent(
              kind: DungeonPhysicsEventKind.crumbleCollapsed,
              x: (st.col + 0.5) * kDungeonTileSize,
              y: (st.row + 0.5) * kDungeonTileSize,
            ),
          );
        }
      }
    }
  }

  void _checkHazards(
    DungeonPlayerPhysicsState player,
    DungeonChamberRuntime chamber,
    List<DungeonPhysicsEvent> events,
    bool hasStalwartWardCharm,
  ) {
    if (player.isInvulnerable) return;
    // Slightly inset hurtbox (2px forgiveness) so edge grazing spikes feels fair!
    final inset = player.hitbox.deflate(2.0);
    final c0 = (inset.left / kDungeonTileSize).floor();
    final c1 = (inset.right / kDungeonTileSize).floor();
    final r0 = (inset.top / kDungeonTileSize).floor();
    final r1 = (inset.bottom / kDungeonTileSize).floor();

    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        if (chamber.effectiveTileAt(c, r).isHazard) {
          player.resolveHp = math.max(0, player.resolveHp - 1);
          player.invulnTimer = hasStalwartWardCharm ? 1.55 : 1.0;
          player.dashTimer = 0.0;
          player.grappleActive = false;
          // Hollow Knight / Silksong spike recovery: snap back to last safe ground!
          player.x = player.lastSafeGroundX;
          player.y = player.lastSafeGroundY;
          player.vx = 0.0;
          player.vy = -80.0;
          events.add(
            DungeonPhysicsEvent(
              kind: DungeonPhysicsEventKind.hazardHit,
              x: player.centerX,
              y: player.centerY,
            ),
          );
          return;
        }
      }
    }
  }

  void _stepLootDrops(
    double dt,
    DungeonPlayerPhysicsState player,
    DungeonChamberRuntime chamber,
    List<DungeonPhysicsEvent> events,
    bool hasMagnetCharm,
  ) {
    final magnetRadius = hasMagnetCharm ? 136.0 : 32.0;
    final magnetAccel = hasMagnetCharm ? 680.0 : 340.0;

    for (var i = chamber.lootDrops.length - 1; i >= 0; i--) {
      final drop = chamber.lootDrops[i];
      if (drop.collected) {
        chamber.lootDrops.removeAt(i);
        continue;
      }
      drop.ageSec += dt;
      final dx = player.centerX - drop.x;
      final dy = player.centerY - drop.y;
      final dist = math.sqrt(dx * dx + dy * dy);

      if (dist <= 11.0 && drop.ageSec > 0.14) {
        drop.collected = true;
        if (drop.kind == DungeonLootKind.resolveOrb) {
          player.resolveHp = math.min(
            player.maxResolveHp,
            player.resolveHp + math.max(1, drop.amount),
          );
        } else if (drop.kind == DungeonLootKind.silkMote) {
          player.addSilk(drop.amount.toDouble());
        }
        events.add(
          DungeonPhysicsEvent(
            kind: DungeonPhysicsEventKind.lootCollected,
            x: drop.x,
            y: drop.y,
            lootKind: drop.kind,
            amount: drop.amount,
          ),
        );
        chamber.lootDrops.removeAt(i);
        continue;
      }

      if (dist <= magnetRadius && dist > 1.0 && drop.ageSec > 0.18) {
        drop.vx += (dx / dist) * magnetAccel * dt;
        drop.vy += (dy / dist) * magnetAccel * dt;
        drop.vx = drop.vx.clamp(-240.0, 240.0);
        drop.vy = drop.vy.clamp(-240.0, 240.0);
      } else {
        drop.vy = math.min(280.0, drop.vy + 720.0 * dt);
        drop.vx *= math.pow(0.08, dt).toDouble();
      }

      final nextX = drop.x + drop.vx * dt;
      final nextY = drop.y + drop.vy * dt;
      final colX = (nextX / kDungeonTileSize).floor();
      final rowY = (drop.y / kDungeonTileSize).floor();
      if (!chamber.isSolidAt(colX, rowY)) {
        drop.x = nextX;
      } else {
        drop.vx = -drop.vx * 0.4;
      }
      final colNow = (drop.x / kDungeonTileSize).floor();
      final rowNext = ((nextY + 3.0) / kDungeonTileSize).floor();
      if (!chamber.isSolidAt(colNow, rowNext)) {
        drop.y = nextY;
      } else {
        drop.y = rowNext * kDungeonTileSize - 3.2;
        drop.vy = drop.vy.abs() > 45.0 ? -drop.vy * 0.35 : 0.0;
      }
    }
  }

  bool _isOverlappingClimbable(
    DungeonPlayerPhysicsState player,
    DungeonChamberRuntime chamber,
  ) {
    final c = (player.centerX / kDungeonTileSize).floor();
    final r0 = ((player.y + 2.0) / kDungeonTileSize).floor();
    final r1 = ((player.bottom - 2.0) / kDungeonTileSize).floor();
    for (var r = r0; r <= r1; r++) {
      if (chamber.effectiveTileAt(c, r).isClimbable) return true;
    }
    return false;
  }

  bool _overlapsSolidAt(
    double x,
    double y,
    double w,
    double h,
    DungeonChamberRuntime chamber,
  ) {
    final c0 = ((x + 0.5) / kDungeonTileSize).floor();
    final c1 = ((x + w - 0.5) / kDungeonTileSize).floor();
    final r0 = ((y + 0.5) / kDungeonTileSize).floor();
    final r1 = ((y + h - 0.5) / kDungeonTileSize).floor();
    for (var r = r0; r <= r1; r++) {
      for (var c = c0; c <= c1; c++) {
        if (chamber.isSolidAt(c, r)) return true;
      }
    }
    return false;
  }

  double _moveToward(double current, double target, double maxDelta) {
    if ((target - current).abs() <= maxDelta) return target;
    return current + (target > current ? maxDelta : -maxDelta);
  }
}
