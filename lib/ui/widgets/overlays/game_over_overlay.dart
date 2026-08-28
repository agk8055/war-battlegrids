import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/enums/connection_type.dart';
import '../../../core/enums/game_mode.dart';
import '../../../core/enums/turn.dart';
import '../../../core/services/audio_service.dart';
import '../../../providers/bluetooth_provider.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../providers/online_provider.dart';
import '../../../providers/turn_provider.dart';

/// Cinematic MOBA-style Game Over Overlay (Victory / Defeat)
/// Displays a high-impact 3D beveled hero title with radiant lens flares,
/// light bursts, and particles, before transitioning to the Post Battle Screen.
class GameOverOverlay extends ConsumerStatefulWidget {
  final Turn? winner;
  final GameMode mode;
  final VoidCallback onContinue;
  final VoidCallback? onViewMap;
  final Duration displayDuration;

  const GameOverOverlay({
    super.key,
    required this.winner,
    required this.mode,
    required this.onContinue,
    this.onViewMap,
    this.displayDuration = const Duration(seconds: 15),
  });

  @override
  ConsumerState<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends ConsumerState<GameOverOverlay>
    with TickerProviderStateMixin {
  late AnimationController _entranceController;
  late AnimationController _ambientController;
  late AnimationController _shimmerController;
  late AnimationController _exitController;

  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _hintSlideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _flareExpandAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _hintFadeAnimation;

  Timer? _autoAdvanceTimer;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();

    // 1. Entrance animation (Clean, smooth slide-up from bottom + flare expansion)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.40),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutQuart,
    ));

    _hintSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.60),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOutCubic),
    ));

    _scaleAnimation = Tween<double>(
      begin: 0.88,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutCubic,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _flareExpandAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.15, 0.95, curve: Curves.easeOutQuart),
    );

    _hintFadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.50, 1.0, curve: Curves.easeIn),
    );

    // 2. Continuous ambient pulse / ray rotation / particle drift
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    _pulseAnimation = CurvedAnimation(
      parent: _ambientController,
      curve: Curves.easeInOut,
    );

    // 3. Shimmer reflection passing through metallic letters
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    // 4. Quick exit transition controller
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Start sequence
    _entranceController.forward();

    // Auto advance timer (15s default)
    _autoAdvanceTimer = Timer(widget.displayDuration, () {
      _handleAdvance();
    });
  }

  @override
  void dispose() {
    _autoAdvanceTimer?.cancel();
    _entranceController.dispose();
    _ambientController.dispose();
    _shimmerController.dispose();
    _exitController.dispose();
    super.dispose();
  }

  void _handleAdvance() {
    if (_isTransitioning || !mounted) return;
    _isTransitioning = true;
    _autoAdvanceTimer?.cancel();

    _exitController.forward().then((_) {
      if (mounted) {
        widget.onContinue();
      }
    });
  }

  void _handleViewMap() {
    if (_isTransitioning || !mounted) return;
    _isTransitioning = true;
    _autoAdvanceTimer?.cancel();

    _exitController.forward().then((_) {
      if (mounted) {
        widget.onViewMap?.call();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameSettingsProvider);
    final bluetoothState = ref.watch(bluetoothProvider);
    final onlineState = ref.watch(onlineProvider);
    final connectionType = ref.watch(connectionTypeProvider);

    final isMultiplayer = widget.mode == GameMode.multiplayer;

    // Determine host vs joiner
    bool isHost = true;
    if (connectionType == ConnectionType.bluetooth) {
      isHost = bluetoothState.isHost;
    } else if (connectionType == ConnectionType.online) {
      isHost = onlineState.isHost;
    }

    final isBluetooth = connectionType == ConnectionType.bluetooth;
    final isOnline = connectionType == ConnectionType.online;
    final isSameDevice = isMultiplayer && !isBluetooth && !isOnline;

    final isDraw = widget.winner == null;
    final isLocalPlayerWin = isMultiplayer
        ? (isSameDevice
            ? widget.winner != null
            : (isHost ? widget.winner == Turn.player : widget.winner == Turn.ai))
        : (widget.winner == Turn.player);

    String titleText;
    _ThemePalette palette;

    if (isDraw) {
      titleText = "STALEMATE";
      palette = _ThemePalette.draw();
    } else if (isSameDevice) {
      final winnerName = widget.winner == Turn.player
          ? settings.player1Name
          : settings.player2Name;
      titleText = "${winnerName.toUpperCase()} WINS";
      palette = _ThemePalette.victory(); // Always Yellow/Gold for Victory
    } else {
      if (isLocalPlayerWin) {
        titleText = "VICTORY";
        palette = _ThemePalette.victory(); // Always Yellow/Gold for Victory
      } else {
        titleText = "DEFEAT";
        palette = _ThemePalette.defeat(); // Always Red for Defeat
      }
    }

    return Positioned.fill(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _handleAdvance,
        child: AnimatedBuilder(
          animation: Listenable.merge([
            _entranceController,
            _ambientController,
            _shimmerController,
            _exitController,
          ]),
          builder: (context, child) {
            final exitOpacity = 1.0 - _exitController.value;
            final overallOpacity = _fadeAnimation.value * exitOpacity;

            return Opacity(
              opacity: overallOpacity.clamp(0.0, 1.0),
              child: Stack(
                fit: StackFit.expand,
                alignment: Alignment.center,
                children: [
                  // 1. Minimal Clean Ambient Glow Background
                  _buildBackdrop(palette),

                  // 2. Light Rays & Starburst Lens Flares
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MobaLensflarePainter(
                        palette: palette,
                        expandProgress: _flareExpandAnimation.value,
                        pulseValue: _pulseAnimation.value,
                        time: _shimmerController.value,
                      ),
                    ),
                  ),

                  // 3. Central 3D Chiseled Hero Typography (Slides smoothly from bottom)
                  Center(
                    child: SlideTransition(
                      position: _slideAnimation,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: _ChiseledTitle(
                          text: titleText,
                          palette: palette,
                          shimmerProgress: _shimmerController.value,
                          pulseProgress: _pulseAnimation.value,
                        ),
                      ),
                    ),
                  ),

                  // 4. "Tap the screen to continue" Hint at the bottom
                  Positioned(
                    bottom: 32,
                    left: 0,
                    right: 0,
                    child: SlideTransition(
                      position: _hintSlideAnimation,
                      child: Opacity(
                        opacity: (_hintFadeAnimation.value *
                                (0.45 + 0.5 * _pulseAnimation.value))
                            .clamp(0.0, 1.0),
                        child: _buildContinueHint(palette),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildBackdrop(_ThemePalette palette) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 1.2,
          colors: [
            palette.glowColor.withValues(alpha: 0.12),
            Colors.black.withValues(alpha: 0.20),
            Colors.black.withValues(alpha: 0.40),
          ],
          stops: const [0.0, 0.6, 1.0],
        ),
      ),
    );
  }

  Widget _buildContinueHint(_ThemePalette palette) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
                width: 0.7,
              ),
            ),
            child: Text(
              "Tap the screen to continue",
              textAlign: TextAlign.center,
              style: GoogleFonts.sairaStencilOne(
                fontSize: 11,
                letterSpacing: 1.6,
                color: Colors.white.withValues(alpha: 0.85),
                shadows: [
                  Shadow(
                    color: palette.glowColor.withValues(alpha: 0.6),
                    blurRadius: 8,
                  ),
                ],
              ),
            ),
          ),
          if (widget.onViewMap != null) ...[
            const SizedBox(height: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
                _handleViewMap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF13100C).withValues(alpha: 0.88),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.65),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.25),
                      blurRadius: 10,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined, size: 14, color: Color(0xFF4FC3F7)),
                    const SizedBox(width: 6),
                    Text(
                      "VIEW FINAL MAP",
                      style: GoogleFonts.sairaStencilOne(
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                        color: const Color(0xFF4FC3F7),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  3D Chiseled Metallic Title Widget
// ─────────────────────────────────────────────────────────────────────────────

class _ChiseledTitle extends StatelessWidget {
  final String text;
  final _ThemePalette palette;
  final double shimmerProgress;
  final double pulseProgress;

  const _ChiseledTitle({
    required this.text,
    required this.palette,
    required this.shimmerProgress,
    required this.pulseProgress,
  });

  @override
  Widget build(BuildContext context) {
    final isLongText = text.length > 8;
    final fontSize = isLongText ? 44.0 : 64.0;
    final letterSpacing = isLongText ? 4.0 : 8.0;

    final baseStyle = GoogleFonts.sairaStencilOne(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: letterSpacing,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Layer 1: Ambient Outer Bloom / Glow
            Text(
              text,
              textAlign: TextAlign.center,
              style: baseStyle.copyWith(
                foreground: Paint()
                  ..style = PaintingStyle.fill
                  ..color = palette.glowColor.withValues(alpha: 0.6)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
                shadows: [
                  Shadow(
                    color: palette.glowColor.withValues(alpha: 0.9),
                    blurRadius: 35 + (pulseProgress * 15),
                  ),
                  Shadow(
                    color: palette.lightAccent.withValues(alpha: 0.7),
                    blurRadius: 15,
                  ),
                ],
              ),
            ),

            // Layer 2: Deep 3D Extrusion Shadow (Bottom-Right bevel depth)
            for (double offset = 1.0; offset <= 4.5; offset += 1.0)
              Transform.translate(
                offset: Offset(0, offset),
                child: Text(
                  text,
                  textAlign: TextAlign.center,
                  style: baseStyle.copyWith(
                    color: palette.extrusionColor.withValues(alpha: 0.9),
                  ),
                ),
              ),

            // Layer 3: Outer Bevel Border / Rim Stroke
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.lightAccent,
                    palette.midTone,
                    palette.deepTone,
                  ],
                  stops: const [0.0, 0.45, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: baseStyle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 4.5
                    ..strokeCap = StrokeCap.round
                    ..strokeJoin = StrokeJoin.miter,
                ),
              ),
            ),

            // Layer 4: Metallic Face Gradient (Top highlight -> Rich body -> Base shade)
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.topHighlight,
                    palette.midTone,
                    palette.deepTone,
                    palette.extrusionColor,
                  ],
                  stops: const [0.0, 0.38, 0.75, 1.0],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: baseStyle.copyWith(
                  color: Colors.white,
                ),
              ),
            ),

            // Layer 5: Inner Chiseled Highlight Ridge
            ShaderMask(
              shaderCallback: (bounds) {
                return LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    palette.lightAccent.withValues(alpha: 0.9),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.4],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcIn,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: baseStyle.copyWith(
                  foreground: Paint()
                    ..style = PaintingStyle.stroke
                    ..strokeWidth = 1.2,
                ),
              ),
            ),

            // Layer 6: Animated Metallic Light Sweep (Diagonal glint shimmer)
            ShaderMask(
              shaderCallback: (bounds) {
                final sweepPos = (shimmerProgress * 2.4) - 0.7;
                return LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.transparent,
                    palette.lightAccent.withValues(alpha: 0.65),
                    Colors.white.withValues(alpha: 0.95),
                    palette.lightAccent.withValues(alpha: 0.65),
                    Colors.transparent,
                  ],
                  stops: [
                    (sweepPos - 0.2).clamp(0.0, 1.0),
                    (sweepPos - 0.08).clamp(0.0, 1.0),
                    sweepPos.clamp(0.0, 1.0),
                    (sweepPos + 0.08).clamp(0.0, 1.0),
                    (sweepPos + 0.2).clamp(0.0, 1.0),
                  ],
                ).createShader(bounds);
              },
              blendMode: BlendMode.srcATop,
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: baseStyle.copyWith(
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  MOBA Lens Flare & Radiant Light Painter
// ─────────────────────────────────────────────────────────────────────────────

class _MobaLensflarePainter extends CustomPainter {
  final _ThemePalette palette;
  final double expandProgress;
  final double pulseValue;
  final double time;

  _MobaLensflarePainter({
    required this.palette,
    required this.expandProgress,
    required this.pulseValue,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (expandProgress <= 0.01) return;

    final center = Offset(size.width / 2, size.height / 2);
    final width = size.width;

    // 1. Horizontal razor beam flare (Intense bright streak across screen)
    final beamPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          palette.glowColor.withValues(alpha: 0.3 * expandProgress),
          palette.lightAccent.withValues(alpha: 0.9 * expandProgress),
          Colors.white.withValues(alpha: 1.0 * expandProgress),
          palette.lightAccent.withValues(alpha: 0.9 * expandProgress),
          palette.glowColor.withValues(alpha: 0.3 * expandProgress),
          Colors.transparent,
        ],
        stops: const [0.0, 0.2, 0.44, 0.5, 0.56, 0.8, 1.0],
      ).createShader(Rect.fromLTWH(0, center.dy - 3, width, 6));

    final beamRect = Rect.fromCenter(
      center: center,
      width: width * (0.4 + 0.6 * expandProgress),
      height: 3.5 + 2.0 * pulseValue,
    );
    canvas.drawRect(beamRect, beamPaint);

    // 2. Wide soft horizontal flare aura
    final auraPaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.5,
        colors: [
          palette.lightAccent.withValues(alpha: 0.7 * expandProgress),
          palette.glowColor.withValues(alpha: 0.35 * expandProgress),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCenter(
        center: center,
        width: width * 0.95 * expandProgress,
        height: 60 + 20 * pulseValue,
      ));

    canvas.drawOval(
      Rect.fromCenter(
        center: center,
        width: width * 0.95 * expandProgress,
        height: 55 + 20 * pulseValue,
      ),
      auraPaint,
    );

    // 3. Central Diamond / 4-point Star Flares
    _drawStarFlare(
      canvas: canvas,
      center: center,
      radiusX: (180 + 40 * pulseValue) * expandProgress,
      radiusY: (45 + 15 * pulseValue) * expandProgress,
      color: palette.lightAccent,
      alpha: (0.75 + 0.25 * pulseValue) * expandProgress,
    );

    // Lateral accent starbursts
    final lateralOffset = (width * 0.28) * expandProgress;
    _drawStarFlare(
      canvas: canvas,
      center: Offset(center.dx - lateralOffset, center.dy),
      radiusX: 70 * expandProgress,
      radiusY: 20 * expandProgress,
      color: palette.lightAccent,
      alpha: 0.55 * expandProgress,
    );
    _drawStarFlare(
      canvas: canvas,
      center: Offset(center.dx + lateralOffset, center.dy),
      radiusX: 70 * expandProgress,
      radiusY: 20 * expandProgress,
      color: palette.lightAccent,
      alpha: 0.55 * expandProgress,
    );

    // 4. Subtle Radial God-Rays
    final rayPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rayCount = 14;
    final maxRayLen = (size.height * 0.45) * expandProgress;

    for (int i = 0; i < rayCount; i++) {
      final angle = (i * (2 * math.pi / rayCount)) + (time * 0.15);
      final rayLen = maxRayLen * (0.6 + 0.4 * math.sin(i * 1.7 + pulseValue * 3));
      final rayAlpha = (0.08 + 0.12 * math.cos(i + pulseValue * 2)) * expandProgress;

      rayPaint.shader = LinearGradient(
        begin: Alignment.center,
        end: Alignment.bottomRight,
        colors: [
          palette.glowColor.withValues(alpha: rayAlpha.clamp(0.0, 1.0)),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: center, radius: rayLen));

      final end = Offset(
        center.dx + math.cos(angle) * rayLen * 1.8,
        center.dy + math.sin(angle) * rayLen * 0.5, // Squashed vertically for cinematic flare
      );

      canvas.drawLine(center, end, rayPaint);
    }
  }

  void _drawStarFlare({
    required Canvas canvas,
    required Offset center,
    required double radiusX,
    required double radiusY,
    required Color color,
    required double alpha,
  }) {
    final path = Path();
    // 4-point diamond star
    path.moveTo(center.dx, center.dy - radiusY);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + radiusX, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radiusY);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - radiusX, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radiusY);
    path.close();

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.white.withValues(alpha: alpha.clamp(0.0, 1.0)),
          color.withValues(alpha: (alpha * 0.7).clamp(0.0, 1.0)),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(Rect.fromCenter(
        center: center,
        width: radiusX * 2,
        height: radiusY * 2,
      ));

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_MobaLensflarePainter oldDelegate) {
    return oldDelegate.expandProgress != expandProgress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.time != time;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Theme Palettes (Victory Gold, Defeat Crimson, Draw Azure, Custom)
// ─────────────────────────────────────────────────────────────────────────────

class _ThemePalette {
  final Color topHighlight;
  final Color lightAccent;
  final Color midTone;
  final Color deepTone;
  final Color extrusionColor;
  final Color glowColor;

  const _ThemePalette({
    required this.topHighlight,
    required this.lightAccent,
    required this.midTone,
    required this.deepTone,
    required this.extrusionColor,
    required this.glowColor,
  });

  // Authentic MOBA Radiant Gold / Yellow (League of Legends / Wild Rift)
  factory _ThemePalette.victory() {
    return const _ThemePalette(
      topHighlight: Color(0xFFFFFBE6),
      lightAccent: Color(0xFFFFE082),
      midTone: Color(0xFFFFC107),
      deepTone: Color(0xFFB27B00),
      extrusionColor: Color(0xFF4A3200),
      glowColor: Color(0xFFFFB300),
    );
  }

  // Authentic MOBA Crimson & Molten Obsidian Defeat (Red)
  factory _ThemePalette.defeat() {
    return const _ThemePalette(
      topHighlight: Color(0xFFFFCDD2),
      lightAccent: Color(0xFFFF5252),
      midTone: Color(0xFFD32F2F),
      deepTone: Color(0xFF7F0000),
      extrusionColor: Color(0xFF330000),
      glowColor: Color(0xFFFF1744),
    );
  }

  // Draw / Stalemate (Silver & Sapphire)
  factory _ThemePalette.draw() {
    return const _ThemePalette(
      topHighlight: Color(0xFFE3F2FD),
      lightAccent: Color(0xFF90CAF9),
      midTone: Color(0xFF42A5F5),
      deepTone: Color(0xFF1565C0),
      extrusionColor: Color(0xFF0D2D5E),
      glowColor: Color(0xFF29B6F6),
    );
  }
}
