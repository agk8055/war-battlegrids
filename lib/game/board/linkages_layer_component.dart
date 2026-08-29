import 'dart:math' as math;
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';
import '../../core/enums/cell_state.dart';
import '../../simulation/board.dart';

/// Flame component responsible for rendering linkages between captured/encircling units,
/// sequential chain-reaction thunder/lightning strike animations, and capture bursts.
class LinkagesLayerComponent extends PositionComponent {
  final double cellSize;
  final Board simulationBoard;
  final Color playerColor;
  final Color opponentColor;

  Sprite? _linkSprite;
  double _globalTime = 0.0;

  // Set of all linkages that have already completed animation or were initialized
  final Set<((int, int), (int, int))> _establishedLinkages = {};

  // Active animated linkages in progress
  final List<_AnimatedLink> _animatedLinks = [];

  // Active captured cell electrical bursts
  final List<_CapturedCellFx> _capturedCellFxs = [];

  // Active spark particles
  final List<_LightningParticle> _particles = [];

  final math.Random _random = math.Random();

  LinkagesLayerComponent({
    required this.cellSize,
    required this.simulationBoard,
    required this.playerColor,
    required this.opponentColor,
  }) {
    priority = 5; // Drawn above base tiles and below unit sigils (priority 10)
    size = Vector2(
      simulationBoard.width * cellSize,
      simulationBoard.height * cellSize,
    );
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    _linkSprite = await AppAssets.loadSpriteSafely(AppAssets.link);
  }

  /// Syncs with the simulation board linkages.
  /// If [newLinkages] are provided or detected, plays the sequential chain-reaction animation.
  void syncLinkages(
    Set<((int, int), (int, int))> currentLinkages, {
    Set<((int, int), (int, int))>? newLinkages,
    (int, int)? lastPlacedCoord,
    List<(int, int)>? capturedCells,
    Color? capturerColor,
  }) {
    final effectiveCapturerColor = capturerColor ?? playerColor;

    // Identify newly added linkages
    final Set<((int, int), (int, int))> toAnimate = {};

    if (newLinkages != null && newLinkages.isNotEmpty) {
      for (final link in newLinkages) {
        final canonical = _canonical(link.$1, link.$2);
        if (!_establishedLinkages.contains(canonical) &&
            !_animatedLinks.any((l) => l.isSamePair(canonical.$1, canonical.$2))) {
          toAnimate.add(canonical);
        }
      }
    } else {
      // Find diff between current and known
      for (final link in currentLinkages) {
        final canonical = _canonical(link.$1, link.$2);
        if (!_establishedLinkages.contains(canonical) &&
            !_animatedLinks.any((l) => l.isSamePair(canonical.$1, canonical.$2))) {
          toAnimate.add(canonical);
        }
      }
    }

    if (toAnimate.isNotEmpty) {
      _startChainReaction(
        linkagesToAnimate: toAnimate,
        startCoord: lastPlacedCoord,
        capturedCells: capturedCells,
        capturerColor: effectiveCapturerColor,
      );
    }

    // Ensure all established linkages that are no longer in board are cleaned up (if any)
    final canonicalCurrent = currentLinkages.map((l) => _canonical(l.$1, l.$2)).toSet();
    _establishedLinkages.removeWhere((l) => !canonicalCurrent.contains(l));
  }

  /// Orders newly formed linkages into a sequential topological chain starting from [startCoord]
  /// and initiates the lightning chain-reaction strike sequence.
  void _startChainReaction({
    required Set<((int, int), (int, int))> linkagesToAnimate,
    (int, int)? startCoord,
    List<(int, int)>? capturedCells,
    required Color capturerColor,
  }) {
    // 1. Build adjacency graph
    final Map<(int, int), List<(int, int)>> graph = {};
    for (final pair in linkagesToAnimate) {
      graph.putIfAbsent(pair.$1, () => []).add(pair.$2);
      graph.putIfAbsent(pair.$2, () => []).add(pair.$1);
    }

    // 2. Determine start node
    (int, int) startNode = linkagesToAnimate.first.$1;
    if (startCoord != null && graph.containsKey(startCoord)) {
      startNode = startCoord;
    } else if (startCoord != null) {
      // Pick node closest to startCoord
      double minDist = double.infinity;
      for (final node in graph.keys) {
        final d = (node.$1 - startCoord.$1) * (node.$1 - startCoord.$1) +
            (node.$2 - startCoord.$2) * (node.$2 - startCoord.$2);
        if (d < minDist) {
          minDist = d.toDouble();
          startNode = node;
        }
      }
    }

    // 3. BFS / perimeter walk to sequence edges in order
    final List<((int, int), (int, int))> sequencedLinks = [];
    final Set<((int, int), (int, int))> visitedEdges = {};
    final List<(int, int)> queue = [startNode];
    final Set<(int, int)> visitedNodes = {startNode};

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      final neighbors = graph[curr] ?? [];

      for (final neighbor in neighbors) {
        final edge = _canonical(curr, neighbor);
        if (!visitedEdges.contains(edge)) {
          visitedEdges.add(edge);
          sequencedLinks.add((curr, neighbor));

          if (!visitedNodes.contains(neighbor)) {
            visitedNodes.add(neighbor);
            queue.add(neighbor);
          }
        }
      }
    }

    // Any disconnected edges in linkagesToAnimate that weren't visited
    for (final edge in linkagesToAnimate) {
      if (!visitedEdges.contains(edge)) {
        visitedEdges.add(edge);
        sequencedLinks.add(edge);
      }
    }

    // 4. Create animated link entries with progressive delay
    const double delayStep = 0.095; // ~95ms between sequential link strikes
    for (int i = 0; i < sequencedLinks.length; i++) {
      final link = sequencedLinks[i];
      final animLink = _AnimatedLink(
        from: link.$1,
        to: link.$2,
        color: capturerColor,
        delay: i * delayStep,
        cellSize: cellSize,
      );
      _animatedLinks.add(animLink);
    }

    // 5. Add captured cells electrocution fx scheduled right after the chain completes
    if (capturedCells != null && capturedCells.isNotEmpty) {
      final double burstDelay = (sequencedLinks.length * delayStep) * 0.85;
      for (final cell in capturedCells) {
        _capturedCellFxs.add(_CapturedCellFx(
          gridX: cell.$1,
          gridY: cell.$2,
          capturerColor: capturerColor,
          delay: burstDelay,
          cellSize: cellSize,
        ));
      }
    }
  }

  static ((int, int), (int, int)) _canonical((int, int) a, (int, int) b) {
    if (a.$1 < b.$1 || (a.$1 == b.$1 && a.$2 < b.$2)) {
      return (a, b);
    }
    return (b, a);
  }

  @override
  void update(double dt) {
    super.update(dt);
    _globalTime += dt;

    // Update active animated links
    for (int i = _animatedLinks.length - 1; i >= 0; i--) {
      final anim = _animatedLinks[i];
      anim.update(dt, _random, _particles);

      if (anim.isCompleted) {
        _establishedLinkages.add(_canonical(anim.from, anim.to));
        _animatedLinks.removeAt(i);
      }
    }

    // Update captured cell FX
    for (int i = _capturedCellFxs.length - 1; i >= 0; i--) {
      final fx = _capturedCellFxs[i];
      fx.update(dt, _random, _particles);
      if (fx.isCompleted) {
        _capturedCellFxs.removeAt(i);
      }
    }

    // Update spark particles
    for (int i = _particles.length - 1; i >= 0; i--) {
      final p = _particles[i];
      p.update(dt);
      if (p.isDead) {
        _particles.removeAt(i);
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    // 1. Render Established Linkages (Static/Ambient)
    for (final link in _establishedLinkages) {
      _renderSingleLink(
        canvas,
        link.$1,
        link.$2,
        _resolveLinkColor(link.$1),
        scaleProgress: 1.0,
        glowIntensity: 0.15 + 0.10 * math.sin(_globalTime * 3.5 + (link.$1.$1 + link.$2.$2)),
        isEstablished: true,
      );
    }

    // 2. Render Active Animating Linkages
    for (final anim in _animatedLinks) {
      if (!anim.hasStarted) continue;

      _renderSingleLink(
        canvas,
        anim.from,
        anim.to,
        anim.color,
        scaleProgress: anim.scaleProgress,
        glowIntensity: anim.glowIntensity,
        isEstablished: false,
      );

      // Render thunder/lightning bolts over the active animating link
      anim.renderLightning(canvas);
    }

    // 3. Render Captured Cell Dissipation / Electrical Bursts
    for (final fx in _capturedCellFxs) {
      if (fx.hasStarted) {
        fx.render(canvas);
      }
    }

    // 4. Render Spark Particles
    for (final p in _particles) {
      p.render(canvas);
    }
  }

  Color _resolveLinkColor((int, int) coord) {
    if (coord.$1 < 0 || coord.$1 >= simulationBoard.width ||
        coord.$2 < 0 || coord.$2 >= simulationBoard.height) {
      return playerColor;
    }
    final cell = simulationBoard.getCell(coord.$1, coord.$2);
    if (cell == CellState.ai || cell == CellState.aiZone) {
      return opponentColor;
    }
    return playerColor;
  }

  /// Renders a single link sprite with mathematical circular end alignment.
  /// Start circular ring is centered at `startPos`, end circular ring is centered at `endPos`.
  void _renderSingleLink(
    Canvas canvas,
    (int, int) from,
    (int, int) to,
    Color color, {
    required double scaleProgress,
    required double glowIntensity,
    required bool isEstablished,
  }) {
    final startPos = Offset((from.$1 + 0.5) * cellSize, (from.$2 + 0.5) * cellSize);
    final endPos = Offset((to.$1 + 0.5) * cellSize, (to.$2 + 0.5) * cellSize);

    final dx = endPos.dx - startPos.dx;
    final dy = endPos.dy - startPos.dy;
    final distance = math.sqrt(dx * dx + dy * dy);
    final targetAngle = math.atan2(dy, dx);

    // Distance between circle centers in 512x512 link.png is 412.95px
    final double baseScale = distance / 412.95;
    final double currentScale = baseScale * scaleProgress;

    if (_linkSprite != null) {
      canvas.save();

      // 1. Move to start unit center
      canvas.translate(startPos.dx, startPos.dy);
      // 2. Rotate to face target unit
      canvas.rotate(targetAngle);
      // 3. Uniformly scale preserving circular aspect ratio & elastic anim scale
      canvas.scale(currentScale, currentScale);
      // 4. Rotate +45 degrees to align diagonal link.png along horizontal axis
      canvas.rotate(math.pi / 4);
      // 5. Translate to place bottom-left circle center (110, 402) precisely at (0, 0)
      canvas.translate(-110.0, -402.0);

      // (a) Optional ambient/strike soft glow backdrop
      if (glowIntensity > 0.05) {
        final glowPaint = Paint()
          ..colorFilter = ColorFilter.mode(
            color.withValues(alpha: glowIntensity.clamp(0.0, 1.0)),
            BlendMode.srcIn,
          )
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6.0);

        _linkSprite!.renderRect(
          canvas,
          const Rect.fromLTWH(0, 0, 512, 512),
          overridePaint: glowPaint,
        );
      }

      // (b) Main link sprite
      final mainPaint = Paint()
        ..colorFilter = ColorFilter.mode(
          color,
          BlendMode.srcIn,
        );

      _linkSprite!.renderRect(
        canvas,
        const Rect.fromLTWH(0, 0, 512, 512),
        overridePaint: mainPaint,
      );

      // (c) White energy flash when energizing during strike
      if (!isEstablished && glowIntensity > 0.6) {
        final flashAlpha = ((glowIntensity - 0.6) / 0.4).clamp(0.0, 0.85);
        final flashPaint = Paint()
          ..colorFilter = ColorFilter.mode(
            Colors.white.withValues(alpha: flashAlpha),
            BlendMode.srcATop,
          );

        _linkSprite!.renderRect(
          canvas,
          const Rect.fromLTWH(0, 0, 512, 512),
          overridePaint: flashPaint,
        );
      }

      canvas.restore();
    } else {
      // Fallback vector linkage line if sprite is still loading
      final linePaint = Paint()
        ..color = color.withValues(alpha: 0.9)
        ..strokeWidth = 4.0 * scaleProgress
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(startPos, endPos, linePaint);

      // Circles at ends
      canvas.drawCircle(startPos, 6.0 * scaleProgress, linePaint);
      canvas.drawCircle(endPos, 6.0 * scaleProgress, linePaint);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Internal Animated Link State & Lightning Generator
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedLink {
  final (int, int) from;
  final (int, int) to;
  final Color color;
  final double delay;
  final double cellSize;

  double timer = 0.0;
  final double strikeDuration = 0.38; // 380ms active thunder strike & energizing

  bool hasStarted = false;
  bool isCompleted = false;

  double scaleProgress = 0.0;
  double glowIntensity = 0.0;

  // Dynamic lightning bolt paths
  List<List<Offset>> lightningBolts = [];
  double _jitterTimer = 0.0;

  _AnimatedLink({
    required this.from,
    required this.to,
    required this.color,
    required this.delay,
    required this.cellSize,
  });

  bool isSamePair((int, int) a, (int, int) b) =>
      (from == a && to == b) || (from == b && to == a);

  Offset get startPos =>
      Offset((from.$1 + 0.5) * cellSize, (from.$2 + 0.5) * cellSize);
  Offset get endPos =>
      Offset((to.$1 + 0.5) * cellSize, (to.$2 + 0.5) * cellSize);

  void update(double dt, math.Random random, List<_LightningParticle> particles) {
    timer += dt;

    if (timer < delay) {
      hasStarted = false;
      return;
    }

    if (!hasStarted) {
      hasStarted = true;
      // Emit shockwave and spark bursts at both node rings upon strike ignition
      _emitNodeSparks(startPos, particles, random);
      _emitNodeSparks(endPos, particles, random);
    }

    final strikeTime = timer - delay;
    final progress = (strikeTime / strikeDuration).clamp(0.0, 1.0);

    // Elastic Overshoot scale animation: 0.0 -> 1.2 -> 1.0
    if (progress < 0.6) {
      final t = progress / 0.6;
      scaleProgress = 1.25 * math.sin(t * (math.pi / 2));
    } else {
      final t = (progress - 0.6) / 0.4;
      scaleProgress = 1.25 - 0.25 * math.sin(t * (math.pi / 2));
    }

    // Glow intensity peaks during early strike
    glowIntensity = math.sin(progress * math.pi);

    // Jitter lightning bolt paths every ~0.032s while striking
    _jitterTimer += dt;
    if (_jitterTimer > 0.032 && progress < 0.85) {
      _jitterTimer = 0.0;
      _generateLightningBolts(random);

      // Emit small spark along bolt path
      if (lightningBolts.isNotEmpty && random.nextDouble() < 0.7) {
        final bolt = lightningBolts[random.nextInt(lightningBolts.length)];
        if (bolt.length > 2) {
          final pt = bolt[random.nextInt(bolt.length)];
          particles.add(_LightningParticle(
            position: pt,
            velocity: Offset((random.nextDouble() - 0.5) * 80, (random.nextDouble() - 0.5) * 80),
            color: Colors.white,
            size: 2.5 + random.nextDouble() * 2.0,
            maxLifetime: 0.22,
          ));
        }
      }
    }

    if (progress >= 1.0) {
      scaleProgress = 1.0;
      glowIntensity = 0.0;
      lightningBolts.clear();
      isCompleted = true;
    }
  }

  void _emitNodeSparks(Offset node, List<_LightningParticle> particles, math.Random random) {
    const int count = 10;
    for (int i = 0; i < count; i++) {
      final angle = (i / count) * 2 * math.pi + (random.nextDouble() - 0.5) * 0.4;
      final speed = 40.0 + random.nextDouble() * 90.0;
      particles.add(_LightningParticle(
        position: node,
        velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
        color: (random.nextBool()) ? Colors.white : color,
        size: 3.0 + random.nextDouble() * 2.5,
        maxLifetime: 0.28 + random.nextDouble() * 0.15,
      ));
    }
  }

  void _generateLightningBolts(math.Random random) {
    lightningBolts.clear();
    final p1 = startPos;
    final p2 = endPos;

    final dist = (p2 - p1).distance;
    final normal = Offset(-(p2.dy - p1.dy) / dist, (p2.dx - p1.dx) / dist);

    // Generate 2 jittered lightning paths
    for (int b = 0; b < 2; b++) {
      final List<Offset> points = [p1];
      const int segments = 5;
      for (int i = 1; i < segments; i++) {
        final t = i / segments;
        final basePt = Offset.lerp(p1, p2, t)!;
        final displacement = (random.nextDouble() - 0.5) * cellSize * 0.45;
        points.add(basePt + normal * displacement);
      }
      points.add(p2);
      lightningBolts.add(points);
    }
  }

  void renderLightning(Canvas canvas) {
    if (lightningBolts.isEmpty) return;

    for (final bolt in lightningBolts) {
      if (bolt.length < 2) continue;

      final path = Path();
      path.moveTo(bolt[0].dx, bolt[0].dy);
      for (int i = 1; i < bolt.length; i++) {
        path.lineTo(bolt[i].dx, bolt[i].dy);
      }

      // 1. Outer cyan/elemental lightning aura
      final outerPaint = Paint()
        ..color = color.withValues(alpha: 0.55 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.5
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, outerPaint);

      // 2. Inner vibrant electric beam
      final midPaint = Paint()
        ..color = color.withValues(alpha: 0.95 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, midPaint);

      // 3. Core white-hot filament
      final corePaint = Paint()
        ..color = Colors.white.withValues(alpha: 0.95 * glowIntensity)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, corePaint);
    }

    // Expanding shockwave flash ring at node joints
    if (glowIntensity > 0.3) {
      final ringRadius = (1.0 - glowIntensity) * cellSize * 0.65;
      final ringPaint = Paint()
        ..color = Colors.white.withValues(alpha: glowIntensity * 0.8)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawCircle(startPos, ringRadius, ringPaint);
      canvas.drawCircle(endPos, ringRadius, ringPaint);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Captured Cell Electrical Burst & Dissipation VFX
// ─────────────────────────────────────────────────────────────────────────────
class _CapturedCellFx {
  final int gridX;
  final int gridY;
  final Color capturerColor;
  final double delay;
  final double cellSize;

  double timer = 0.0;
  final double duration = 0.55;

  bool hasStarted = false;
  bool isCompleted = false;

  _CapturedCellFx({
    required this.gridX,
    required this.gridY,
    required this.capturerColor,
    required this.delay,
    required this.cellSize,
  });

  Offset get center =>
      Offset((gridX + 0.5) * cellSize, (gridY + 0.5) * cellSize);

  void update(double dt, math.Random random, List<_LightningParticle> particles) {
    timer += dt;
    if (timer < delay) {
      hasStarted = false;
      return;
    }

    if (!hasStarted) {
      hasStarted = true;
      // Emit burst particles outwards from captured tile
      const int count = 16;
      for (int i = 0; i < count; i++) {
        final angle = (i / count) * 2 * math.pi + (random.nextDouble() - 0.5) * 0.3;
        final speed = 50.0 + random.nextDouble() * 110.0;
        particles.add(_LightningParticle(
          position: center,
          velocity: Offset(math.cos(angle) * speed, math.sin(angle) * speed),
          color: (i % 2 == 0) ? Colors.white : capturerColor,
          size: 3.5 + random.nextDouble() * 2.5,
          maxLifetime: 0.35 + random.nextDouble() * 0.15,
        ));
      }
    }

    if (timer >= delay + duration) {
      isCompleted = true;
    }
  }

  void render(Canvas canvas) {
    final progress = ((timer - delay) / duration).clamp(0.0, 1.0);
    final intensity = math.sin(progress * math.pi);

    // 1. Radial lightning impact shockwave
    final shockRadius = progress * cellSize * 0.95;
    final shockPaint = Paint()
      ..color = capturerColor.withValues(alpha: 0.85 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0 * (1.0 - progress);
    canvas.drawCircle(center, shockRadius, shockPaint);

    // 2. White energy flash core
    final corePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90 * intensity)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, (1.0 - progress) * cellSize * 0.45, corePaint);

    // 3. Radial cross spark rays
    final rayLen = progress * cellSize * 0.8;
    final rayPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.95 * intensity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawLine(Offset(center.dx - rayLen, center.dy), Offset(center.dx + rayLen, center.dy), rayPaint);
    canvas.drawLine(Offset(center.dx, center.dy - rayLen), Offset(center.dx, center.dy + rayLen), rayPaint);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Lightning Particle System
// ─────────────────────────────────────────────────────────────────────────────
class _LightningParticle {
  Offset position;
  Offset velocity;
  final Color color;
  final double size;
  final double maxLifetime;
  double lifetime = 0.0;

  _LightningParticle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.maxLifetime,
  });

  bool get isDead => lifetime >= maxLifetime;

  void update(double dt) {
    lifetime += dt;
    position += velocity * dt;
    velocity *= 0.90; // Drag
  }

  void render(Canvas canvas) {
    final progress = (lifetime / maxLifetime).clamp(0.0, 1.0);
    final alpha = (1.0 - progress);
    final currentSize = size * (1.0 - progress * 0.5);

    final paint = Paint()
      ..color = color.withValues(alpha: alpha)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(position, currentSize, paint);
  }
}
