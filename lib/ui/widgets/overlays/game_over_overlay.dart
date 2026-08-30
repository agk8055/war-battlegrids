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

/// Cinematic AAA FPS / MOBA-style Game Over Overlay (Victory / Defeat / Stalemate).
/// Features a high-impact top-aligned 3D beveled hero title, glowing tactical
/// apex insignia, radiant lens flares, anamorphic light bursts, and dynamic
/// floating square HUD sparks and rising ember particles inspired by Call of Duty: Mobile.
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
  late AnimationController _particleController;
  late AnimationController _exitController;

  late Animation<Offset> _slideAnimation;
  late Animation<Offset> _hintSlideAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _flareExpandAnimation;
  late Animation<double> _pulseAnimation;
  late Animation<double> _hintFadeAnimation;

  final List<_SparkParticle> _particles = [];
  Timer? _autoAdvanceTimer;
  bool _isTransitioning = false;

  @override
  void initState() {
    super.initState();

    // Play victory / game over theme
    ref.read(audioServiceProvider).playGameOverTheme();

    // 1. Entrance animation (Hero elements slide into top position + flare burst)
    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 950),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.30),
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
      begin: 0.82,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _entranceController,
      curve: Curves.easeOutBack,
    ));

    _fadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );

    _flareExpandAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.12, 0.95, curve: Curves.easeOutQuart),
    );

    _hintFadeAnimation = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.50, 1.0, curve: Curves.easeIn),
    );

    // 2. Continuous ambient pulse
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
      duration: const Duration(milliseconds: 2400),
    )..repeat();

    // 4. Continuous particle simulation controller
    _particleController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // Initialize floating square HUD motes and ember sparks
    final rand = math.Random();
    for (int i = 0; i < 48; i++) {
      _particles.add(_SparkParticle.random(rand));
    }

    // 5. Exit transition controller
    _exitController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );

    // Start sequence
    _entranceController.forward();

    // Auto advance timer
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
    _particleController.dispose();
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
    String subtitleText;
    _ThemePalette palette;

    if (isDraw) {
      titleText = "STALEMATE";
      subtitleText = "CEASEFIRE DECLARED • DRAW";
      palette = _ThemePalette.draw();
    } else if (isSameDevice) {
      final winnerName = widget.winner == Turn.player
          ? settings.player1Name
          : settings.player2Name;
      titleText = "${winnerName.toUpperCase()} WINS";
      subtitleText = "MATCH CONCLUDED • VICTORY";
      palette = _ThemePalette.victory();
    } else {
      if (isLocalPlayerWin) {
        titleText = "VICTORY";
        subtitleText = "TACTICAL OBJECTIVE SECURED";
        palette = _ThemePalette.victory();
      } else {
        titleText = "DEFEAT";
        subtitleText = "FALLEN IN COMBAT • MISSION FAILED";
        palette = _ThemePalette.defeat();
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
            _particleController,
            _exitController,
          ]),
          builder: (context, child) {
            final exitOpacity = 1.0 - _exitController.value;
            final overallOpacity = _fadeAnimation.value * exitOpacity;

            return Opacity(
              opacity: overallOpacity.clamp(0.0, 1.0),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  // Anchor position for the top hero banner (e.g. 24% from top)
                  final topAnchorY = math.min(180.0, constraints.maxHeight * 0.26);

                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      // 1. Ambient Dark Vignette Background with Radial Tone
                      _buildBackdrop(palette),

                      // 2. Light Rays & Starburst Lens Flares (Centered on top banner anchor)
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _TopLensflarePainter(
                            palette: palette,
                            anchorY: topAnchorY,
                            expandProgress: _flareExpandAnimation.value,
                            pulseValue: _pulseAnimation.value,
                            time: _shimmerController.value,
                          ),
                        ),
                      ),

                      // 3. COD Mobile-style Floating Square HUD Sparks & Embers
                      Positioned.fill(
                        child: CustomPaint(
                          painter: _SparksPainter(
                            particles: _particles,
                            palette: palette,
                            progress: _particleController.value,
                            pulse: _pulseAnimation.value,
                            anchorY: topAnchorY,
                          ),
                        ),
                      ),

                      // 4. TOP HERO SECTION: Apex Insignia + Chiseled Title + Subtitle Badge
                      Positioned(
                        top: math.max(16.0, topAnchorY - 100),
                        left: 16,
                        right: 16,
                        child: SlideTransition(
                          position: _slideAnimation,
                          child: Transform.scale(
                            scale: _scaleAnimation.value,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Tactical Glowing Apex Chevron / Delta Emblem
                                _TacticalApexEmblem(
                                  palette: palette,
                                  pulse: _pulseAnimation.value,
                                  shimmer: _shimmerController.value,
                                ),

                                const SizedBox(height: 2),

                                // 3D Chiseled Hero Title
                                _ChiseledTitle(
                                  text: titleText,
                                  palette: palette,
                                  shimmerProgress: _shimmerController.value,
                                  pulseProgress: _pulseAnimation.value,
                                ),

                                const SizedBox(height: 10),

                                // Sleek Subtitle Banner (Call of Duty weapon upgrade / objective bar style)
                                _TacticalSubtitleBanner(
                                  text: subtitleText,
                                  palette: palette,
                                  pulse: _pulseAnimation.value,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),

                      // 5. "Tap the screen to continue" / View Map Hint at Bottom
                      Positioned(
                        bottom: 30,
                        left: 0,
                        right: 0,
                        child: SlideTransition(
                          position: _hintSlideAnimation,
                          child: Opacity(
                            opacity: (_hintFadeAnimation.value *
                                    (0.50 + 0.5 * _pulseAnimation.value))
                                .clamp(0.0, 1.0),
                            child: _buildContinueHint(palette),
                          ),
                        ),
                      ),
                    ],
                  );
                },
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
          center: const Alignment(0, -0.45),
          radius: 1.1,
          colors: [
            palette.glowColor.withValues(alpha: 0.22),
            Colors.black.withValues(alpha: 0.45),
            Colors.black.withValues(alpha: 0.82),
          ],
          stops: const [0.0, 0.55, 1.0],
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
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.18),
                width: 0.8,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 12,
                ),
              ],
            ),
            child: Text(
              "TAP ANYWHERE TO CONTINUE",
              textAlign: TextAlign.center,
              style: GoogleFonts.sairaStencilOne(
                fontSize: 11.5,
                letterSpacing: 2.0,
                color: Colors.white.withValues(alpha: 0.9),
                shadows: [
                  Shadow(
                    color: palette.glowColor.withValues(alpha: 0.7),
                    blurRadius: 10,
                  ),
                ],
              ),
            ),
          ),
          if (widget.onViewMap != null) ...[
            const SizedBox(height: 12),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
                _handleViewMap();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFF0F151B).withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFF4FC3F7).withValues(alpha: 0.75),
                    width: 1.1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4FC3F7).withValues(alpha: 0.3),
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.map_outlined, size: 15, color: Color(0xFF4FC3F7)),
                    const SizedBox(width: 7),
                    Text(
                      "VIEW FINAL MAP",
                      style: GoogleFonts.sairaStencilOne(
                        fontSize: 11,
                        letterSpacing: 1.4,
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
//  Tactical Apex Chevron / Delta Emblem (Inspired by COD Mobile Victory Insignia)
// ─────────────────────────────────────────────────────────────────────────────

class _TacticalApexEmblem extends StatelessWidget {
  final _ThemePalette palette;
  final double pulse;
  final double shimmer;

  const _TacticalApexEmblem({
    required this.palette,
    required this.pulse,
    required this.shimmer,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 140,
      height: 72,
      child: CustomPaint(
        painter: _ApexEmblemPainter(
          palette: palette,
          pulse: pulse,
          shimmer: shimmer,
        ),
      ),
    );
  }
}

class _ApexEmblemPainter extends CustomPainter {
  final _ThemePalette palette;
  final double pulse;
  final double shimmer;

  _ApexEmblemPainter({
    required this.palette,
    required this.pulse,
    required this.shimmer,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // 1. Layered Chevron / Delta Triangles
    final outerPath = Path()
      ..moveTo(cx, 4)
      ..lineTo(cx + 46, size.height - 8)
      ..lineTo(cx + 34, size.height - 8)
      ..lineTo(cx, 20)
      ..lineTo(cx - 34, size.height - 8)
      ..lineTo(cx - 46, size.height - 8)
      ..close();

    final innerPath = Path()
      ..moveTo(cx, 16)
      ..lineTo(cx + 28, size.height - 18)
      ..lineTo(cx + 18, size.height - 18)
      ..lineTo(cx, 30)
      ..lineTo(cx - 18, size.height - 18)
      ..lineTo(cx - 28, size.height - 18)
      ..close();

    // Emblem Glow Shadow
    final glowPaint = Paint()
      ..color = palette.glowColor.withValues(alpha: 0.55 + 0.25 * pulse)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 16);
    canvas.drawPath(outerPath, glowPaint);

    // Outer Chevron Stroke & Gradient Fill
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.topHighlight,
          palette.midTone,
          palette.deepTone,
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          palette.lightAccent.withValues(alpha: 0.45),
          palette.midTone.withValues(alpha: 0.25),
          palette.deepTone.withValues(alpha: 0.05),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(outerPath, fillPaint);
    canvas.drawPath(outerPath, strokePaint);

    // Inner Chevron
    final innerStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = palette.lightAccent.withValues(alpha: 0.85);
    canvas.drawPath(innerPath, innerStroke);

    // Star / Diamond at Apex
    final starPath = Path()
      ..moveTo(cx, 10)
      ..lineTo(cx + 5, 17)
      ..lineTo(cx, 24)
      ..lineTo(cx - 5, 17)
      ..close();

    final starPaint = Paint()
      ..color = Colors.white
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);
    canvas.drawPath(starPath, starPaint);

    // Horizontal Wing Accents
    final wingPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          palette.lightAccent,
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, cy, size.width, 2));

    canvas.drawLine(Offset(cx - 65, cy + 10), Offset(cx - 30, cy + 10), wingPaint);
    canvas.drawLine(Offset(cx + 30, cy + 10), Offset(cx + 65, cy + 10), wingPaint);
  }

  @override
  bool shouldRepaint(_ApexEmblemPainter oldDelegate) {
    return oldDelegate.pulse != pulse ||
        oldDelegate.shimmer != shimmer ||
        oldDelegate.palette != palette;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tactical Subtitle Banner (COD Weapon Upgrade / Mission Bar)
// ─────────────────────────────────────────────────────────────────────────────

class _TacticalSubtitleBanner extends StatelessWidget {
  final String text;
  final _ThemePalette palette;
  final double pulse;

  const _TacticalSubtitleBanner({
    required this.text,
    required this.palette,
    required this.pulse,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 5),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: [
            Colors.transparent,
            Colors.black.withValues(alpha: 0.75),
            palette.glowColor.withValues(alpha: 0.25 + 0.15 * pulse),
            Colors.black.withValues(alpha: 0.75),
            Colors.transparent,
          ],
          stops: const [0.0, 0.2, 0.5, 0.8, 1.0],
        ),
        border: Border(
          top: BorderSide(
            color: palette.lightAccent.withValues(alpha: 0.6),
            width: 1.2,
          ),
          bottom: BorderSide(
            color: palette.lightAccent.withValues(alpha: 0.6),
            width: 1.2,
          ),
        ),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.sairaStencilOne(
          fontSize: 12.5,
          letterSpacing: 3.2,
          fontWeight: FontWeight.bold,
          color: palette.lightAccent.withValues(alpha: 0.95),
          shadows: [
            Shadow(
              color: palette.glowColor,
              blurRadius: 10,
            ),
          ],
        ),
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
    final fontSize = isLongText ? 42.0 : 62.0;
    final letterSpacing = isLongText ? 4.0 : 8.0;

    final baseStyle = GoogleFonts.sairaStencilOne(
      fontSize: fontSize,
      fontWeight: FontWeight.bold,
      letterSpacing: letterSpacing,
    );

    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 12),
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
                  ..color = palette.glowColor.withValues(alpha: 0.65)
                  ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 28),
                shadows: [
                  Shadow(
                    color: palette.glowColor.withValues(alpha: 0.95),
                    blurRadius: 35 + (pulseProgress * 15),
                  ),
                  Shadow(
                    color: palette.lightAccent.withValues(alpha: 0.8),
                    blurRadius: 16,
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
                    color: palette.extrusionColor.withValues(alpha: 0.95),
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

            // Layer 4: Metallic Face Gradient
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
                    palette.lightAccent.withValues(alpha: 0.95),
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
                    palette.lightAccent.withValues(alpha: 0.75),
                    Colors.white.withValues(alpha: 0.95),
                    palette.lightAccent.withValues(alpha: 0.75),
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
//  COD Mobile Style Sparks & Glowing HUD Motes Particle System
// ─────────────────────────────────────────────────────────────────────────────

enum _ParticleType { squareHUD, risingEmber, streakFlare }

class _SparkParticle {
  double x; // 0.0 to 1.0 (relative screen width)
  double y; // 0.0 to 1.0 (relative screen height)
  double size;
  double speedX;
  double speedY;
  double alpha;
  double phase;
  double rotSpeed;
  _ParticleType type;

  _SparkParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speedX,
    required this.speedY,
    required this.alpha,
    required this.phase,
    required this.rotSpeed,
    required this.type,
  });

  factory _SparkParticle.random(math.Random rand) {
    final typeRoll = rand.nextDouble();
    _ParticleType type;
    double size;

    if (typeRoll < 0.45) {
      // Square glowing HUD bokeh (COD signature)
      type = _ParticleType.squareHUD;
      size = rand.nextDouble() * 14 + 6;
    } else if (typeRoll < 0.85) {
      // Tiny rising sparks / embers
      type = _ParticleType.risingEmber;
      size = rand.nextDouble() * 4 + 2;
    } else {
      // Horizontal glint spark
      type = _ParticleType.streakFlare;
      size = rand.nextDouble() * 22 + 10;
    }

    return _SparkParticle(
      x: rand.nextDouble(),
      // Concentrate more particles in upper 60% of the screen around the title
      y: rand.nextDouble() * 0.7 + 0.05,
      size: size,
      speedX: (rand.nextDouble() - 0.5) * 0.04,
      speedY: -(rand.nextDouble() * 0.06 + 0.015), // Drifts upwards
      alpha: rand.nextDouble() * 0.7 + 0.3,
      phase: rand.nextDouble() * math.pi * 2,
      rotSpeed: (rand.nextDouble() - 0.5) * 1.5,
      type: type,
    );
  }
}

class _SparksPainter extends CustomPainter {
  final List<_SparkParticle> particles;
  final _ThemePalette palette;
  final double progress;
  final double pulse;
  final double anchorY;

  _SparksPainter({
    required this.particles,
    required this.palette,
    required this.progress,
    required this.pulse,
    required this.anchorY,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    for (final p in particles) {
      // Calculate dynamic position with time progress
      final curX = (p.x + p.speedX * progress * 5) % 1.0;
      // Drifts upwards and wraps
      final curY = ((p.y + p.speedY * progress * 5) % 1.0 + 1.0) % 1.0;

      final px = curX * w;
      final py = curY * h;

      // Distance factor from anchorY (sparks glow brighter near top banner)
      final distY = (py - anchorY).abs();
      final proximityBonus = math.max(0.3, 1.0 - (distY / (h * 0.45)));

      // Sine wave twinkle
      final twinkle = 0.5 + 0.5 * math.sin(progress * 12 + p.phase);
      final finalAlpha = (p.alpha * twinkle * proximityBonus * (0.8 + 0.2 * pulse))
          .clamp(0.0, 1.0);

      if (finalAlpha <= 0.01) continue;

      switch (p.type) {
        case _ParticleType.squareHUD:
          _drawSquareBokeh(canvas, px, py, p.size, finalAlpha, palette);
          break;
        case _ParticleType.risingEmber:
          _drawEmberSpark(canvas, px, py, p.size, finalAlpha, palette);
          break;
        case _ParticleType.streakFlare:
          _drawStreakFlare(canvas, px, py, p.size, finalAlpha, palette);
          break;
      }
    }
  }

  void _drawSquareBokeh(Canvas canvas, double cx, double cy, double size,
      double alpha, _ThemePalette palette) {
    // 1. Soft glowing square aura
    final glowPaint = Paint()
      ..color = palette.glowColor.withValues(alpha: alpha * 0.45)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 0.75);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: size * 1.5, height: size * 1.5),
      glowPaint,
    );

    // 2. Hollow square HUD border (tactical COD style)
    final borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4
      ..color = palette.lightAccent.withValues(alpha: alpha * 0.9);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: size, height: size),
      borderPaint,
    );

    // 3. Inner faint fill
    final fillPaint = Paint()
      ..color = palette.topHighlight.withValues(alpha: alpha * 0.3);
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: size * 0.7, height: size * 0.7),
      fillPaint,
    );

    // 4. Subtle horizontal anamorphic streak through the square
    final streakPaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          palette.lightAccent.withValues(alpha: alpha * 0.75),
          Colors.white.withValues(alpha: alpha * 0.9),
          palette.lightAccent.withValues(alpha: 0.75),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCenter(center: Offset(cx, cy), width: size * 4.5, height: 1.5),
      );
    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: size * 4.5, height: 1.2),
      streakPaint,
    );
  }

  void _drawEmberSpark(Canvas canvas, double cx, double cy, double size,
      double alpha, _ThemePalette palette) {
    final sparkPaint = Paint()
      ..color = Colors.white.withValues(alpha: alpha)
      ..maskFilter = const MaskFilter.blur(BlurStyle.solid, 2);

    final auraPaint = Paint()
      ..color = palette.glowColor.withValues(alpha: alpha * 0.6)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, size * 2.5);

    canvas.drawCircle(Offset(cx, cy), size * 2.0, auraPaint);
    canvas.drawCircle(Offset(cx, cy), size * 0.7, sparkPaint);
  }

  void _drawStreakFlare(Canvas canvas, double cx, double cy, double length,
      double alpha, _ThemePalette palette) {
    final flarePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          palette.lightAccent.withValues(alpha: alpha * 0.6),
          Colors.white.withValues(alpha: alpha * 0.9),
          palette.lightAccent.withValues(alpha: alpha * 0.6),
          Colors.transparent,
        ],
      ).createShader(
        Rect.fromCenter(center: Offset(cx, cy), width: length, height: 2),
      );

    canvas.drawRect(
      Rect.fromCenter(center: Offset(cx, cy), width: length, height: 1.8),
      flarePaint,
    );
  }

  @override
  bool shouldRepaint(_SparksPainter oldDelegate) {
    return true; // Continuously animates with particleController
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Top-Anchored Lens Flare & Radiant Light Painter
// ─────────────────────────────────────────────────────────────────────────────

class _TopLensflarePainter extends CustomPainter {
  final _ThemePalette palette;
  final double anchorY;
  final double expandProgress;
  final double pulseValue;
  final double time;

  _TopLensflarePainter({
    required this.palette,
    required this.anchorY,
    required this.expandProgress,
    required this.pulseValue,
    required this.time,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (expandProgress <= 0.01) return;

    final center = Offset(size.width / 2, anchorY);
    final width = size.width;

    // 1. Horizontal razor beam flare (Intense bright streak across screen at top)
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
      width: width * (0.5 + 0.5 * expandProgress),
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

    // 4. Radial God-Rays around top center
    final rayPaint = Paint()
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    final rayCount = 14;
    final maxRayLen = (size.height * 0.5) * expandProgress;

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
        center.dy + math.sin(angle) * rayLen * 0.6,
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
  bool shouldRepaint(_TopLensflarePainter oldDelegate) {
    return oldDelegate.expandProgress != expandProgress ||
        oldDelegate.pulseValue != pulseValue ||
        oldDelegate.time != time ||
        oldDelegate.anchorY != anchorY;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Theme Palettes (Victory Gold, Defeat Crimson, Draw Azure)
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

  // Authentic AAA Radiant Gold / Amber (Call of Duty / MOBA Victory)
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

  // Molten Crimson & Dark Obsidian Defeat (Red / Orange)
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

  // Draw / Stalemate (Silver & Sapphire Azure)
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
