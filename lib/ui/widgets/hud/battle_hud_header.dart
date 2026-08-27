import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import '../../../core/constants/app_assets.dart';
import '../../../core/enums/game_mode.dart';
import '../../../core/enums/turn.dart';
import '../../../providers/simulation_provider.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../providers/bluetooth_provider.dart';
import '../../../providers/online_provider.dart';
import '../../../providers/turn_provider.dart';
import '../../../core/enums/connection_type.dart';
import '../../../campaign/campaign_manager.dart';
import '../../../campaign/data/kingdoms_data.dart';
import 'score_panel.dart';

class BattleHudHeader extends ConsumerWidget {
  final VoidCallback onPausePressed;

  const BattleHudHeader({
    super.key,
    required this.onPausePressed,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final simulationState = ref.watch(simulationProvider);
    final settings = ref.watch(gameSettingsProvider);
    final campaignState = ref.watch(campaignProvider);
    final bluetoothState = ref.watch(bluetoothProvider);
    final onlineState = ref.watch(onlineProvider);
    final connectionType = ref.watch(connectionTypeProvider);
    final aiState = ref.watch(aiStateProvider);

    final isMultiplayer = settings.mode == GameMode.multiplayer;
    
    // Determine if we are 'host' for visual mapping purposes
    bool effectiveIsHost = true;
    if (connectionType == ConnectionType.bluetooth) {
      effectiveIsHost = bluetoothState.isHost;
    } else if (connectionType == ConnectionType.online) {
      effectiveIsHost = onlineState.isHost;
    }

    final selectedKingdom = campaignState.selectedKingdomId != null
        ? kKingdoms.firstWhere((k) => k.id == campaignState.selectedKingdomId)
        : null;

    final String p1Name;
    final String p1Symbol;
    final int p1ColorVal;

    final String p2Name;
    final String p2Symbol;
    final int p2ColorVal;

    if (isMultiplayer) {
      if (effectiveIsHost) {
        p1Name = settings.player1Name;
        p1Symbol = settings.player1Symbol;
        p1ColorVal = settings.player1Color;

        p2Name = settings.player2Name;
        p2Symbol = settings.player2Symbol;
        p2ColorVal = settings.player2Color;
      } else {
        // Joiner: Host goes Left, Joiner goes Right
        p1Name = settings.player2Name;
        p1Symbol = settings.player2Symbol;
        p1ColorVal = settings.player2Color;

        p2Name = settings.player1Name;
        p2Symbol = settings.player1Symbol;
        p2ColorVal = settings.player1Color;
      }
    } else {
      p1Name = settings.player1Name;
      p1Symbol = settings.player1Symbol;
      p1ColorVal = settings.player1Color;

      p2Name = selectedKingdom?.name ?? "AI";
      p2Symbol = selectedKingdom?.symbolAsset ?? AppAssets.eagle;
      p2ColorVal =
          selectedKingdom?.primaryColor.toARGB32() ?? Colors.red.toARGB32();
    }

    final p1Color = Color(p1ColorVal);
    final p2Color = Color(p2ColorVal);

    final p1IsActive = simulationState.currentTurn == Turn.player;
    final p1Score = simulationState.playerScore;
    final p1KingdomAttackUnlocked = simulationState.playerKingdomAttackUnlocked;
    final p1ActiveWinCondition = simulationState.playerActiveWinCondition;

    final p2IsActive = simulationState.currentTurn == Turn.ai;
    final p2Score = simulationState.aiScore;
    final p2KingdomAttackUnlocked = simulationState.aiKingdomAttackUnlocked;
    final p2ActiveWinCondition = simulationState.aiActiveWinCondition;

    // Check if opponent / AI is currently taking their turn
    bool isOpponentWaiting = false;
    if (settings.mode == GameMode.multiplayer &&
        (connectionType == ConnectionType.bluetooth ||
            connectionType == ConnectionType.online)) {
      final myTurn = effectiveIsHost ? Turn.player : Turn.ai;
      isOpponentWaiting = simulationState.currentTurn != myTurn;
    }

    final showAiThinking = (settings.mode == GameMode.story &&
        aiState == AIState.thinking &&
        simulationState.currentTurn == Turn.ai);

    final isThinkingActive = showAiThinking || isOpponentWaiting;
    final thinkingLabel = showAiThinking
        ? "$p2Name IS THINKING"
        : (isMultiplayer ? "$p2Name IS PLANNING" : "OPPONENT IS PLANNING");
    final thinkingColor = p2Color;

    return SafeArea(
      bottom: false,
      left: false,
      right: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
            child: CustomPaint(
              painter: _HudFramePainter(
                p1Color: p1Color,
                p2Color: p2Color,
                p1IsActive: p1IsActive,
              ),
              child: Container(
                // Stone-dark HUD background with subtle warm depth
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF161410),
                      Color(0xFF0C0B09),
                    ],
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // ── LEFT KINGDOM PANEL ────────────────────────────────
                    Expanded(
                      flex: 3,
                      child: ScorePanel(
                        title: p1Name,
                        symbolAsset: p1Symbol,
                        points: p1Score,
                        color: p1Color,
                        kingdomAttackUnlocked: p1KingdomAttackUnlocked,
                        activeWinCondition: p1ActiveWinCondition,
                        isActiveTurn: p1IsActive,
                      ),
                    ),

                    // ── CENTER COMMAND SEAL ───────────────────────────────
                    _CenterCommandSeal(
                      onPausePressed: onPausePressed,
                      p1IsActive: p1IsActive,
                      p1Color: p1Color,
                      p2Color: p2Color,
                    ),

                    // ── RIGHT KINGDOM PANEL ───────────────────────────────
                    Expanded(
                      flex: 3,
                      child: ScorePanel(
                        title: p2Name,
                        symbolAsset: p2Symbol,
                        points: p2Score,
                        color: p2Color,
                        kingdomAttackUnlocked: p2KingdomAttackUnlocked,
                        activeWinCondition: p2ActiveWinCondition,
                        alignment: CrossAxisAlignment.end,
                        isActiveTurn: p2IsActive,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── THINKING / OPPONENT LOADING BANNER ────────────────────────
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isThinkingActive
                ? _ThinkingBanner(
                    label: thinkingLabel,
                    color: thinkingColor,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CENTER COMMAND SEAL — pause button styled as a war seal / command crest
// ─────────────────────────────────────────────────────────────────────────────
class _CenterCommandSeal extends StatefulWidget {
  final VoidCallback onPausePressed;
  final bool p1IsActive;
  final Color p1Color;
  final Color p2Color;

  const _CenterCommandSeal({
    required this.onPausePressed,
    required this.p1IsActive,
    required this.p1Color,
    required this.p2Color,
  });

  @override
  State<_CenterCommandSeal> createState() => _CenterCommandSealState();
}

class _CenterCommandSealState extends State<_CenterCommandSeal> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Active faction color leaks into the center divider
    final activeFactionColor =
        widget.p1IsActive ? widget.p1Color : widget.p2Color;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPausePressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0.0, _pressed ? 2.0 : 0.0, 0.0),
        width: 44,
        height: 44,
        child: CustomPaint(
          painter: _SealPainter(
            color: activeFactionColor,
            isPressed: _pressed,
          ),
          child: Center(
            child: Icon(
              Icons.pause,
              color: _pressed
                  ? activeFactionColor
                  : const Color(0xFFAA9977),
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _SealPainter extends CustomPainter {
  final Color color;
  final bool isPressed;

  _SealPainter({required this.color, required this.isPressed});

  @override
  void paint(Canvas canvas, Size size) {
    const b = 10.0;
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(b, 0)
      ..lineTo(w - b, 0)
      ..lineTo(w, b)
      ..lineTo(w, h - b)
      ..lineTo(w - b, h)
      ..lineTo(b, h)
      ..lineTo(0, h - b)
      ..lineTo(0, b)
      ..close();

    // Background fill
    canvas.drawPath(
      path,
      Paint()
        ..color = isPressed
            ? color.withValues(alpha: 0.20)
            : const Color(0xFF1A1710),
    );

    // Border
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: isPressed ? 0.9 : 0.45)
        ..strokeWidth = isPressed ? 2.0 : 1.5
        ..style = PaintingStyle.stroke,
    );

    // Inner accent line (double-engraved border)
    const inset = 3.5;
    final innerPath = Path()
      ..moveTo(b + inset, inset)
      ..lineTo(w - b - inset, inset)
      ..lineTo(w - inset, b + inset)
      ..lineTo(w - inset, h - b - inset)
      ..lineTo(w - b - inset, h - inset)
      ..lineTo(b + inset, h - inset)
      ..lineTo(inset, h - b - inset)
      ..lineTo(inset, b + inset)
      ..close();

    canvas.drawPath(
      innerPath,
      Paint()
        ..color = color.withValues(alpha: isPressed ? 0.35 : 0.12)
        ..strokeWidth = 0.7
        ..style = PaintingStyle.stroke,
    );

    // Hard torch-light shadow (bottom-right edge offset line)
    if (!isPressed) {
      canvas.drawPath(
        path,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.6)
          ..strokeWidth = 1.0
          ..style = PaintingStyle.stroke
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
    }
  }

  @override
  bool shouldRepaint(_SealPainter old) =>
      old.color != color || old.isPressed != isPressed;
}

// ─────────────────────────────────────────────────────────────────────────────
// HUD FRAME PAINTER — outer engraved frame for the entire header bar
// Uses bevel-cut corners; colored stripe on each side matches faction color
// ─────────────────────────────────────────────────────────────────────────────
class _HudFramePainter extends CustomPainter {
  final Color p1Color;
  final Color p2Color;
  final bool p1IsActive;

  _HudFramePainter({
    required this.p1Color,
    required this.p2Color,
    required this.p1IsActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const b = 10.0; // bevel size
    final w = size.width;
    final h = size.height;

    // Full outer bevel path
    final outerPath = Path()
      ..moveTo(b, 0)
      ..lineTo(w - b, 0)
      ..lineTo(w, b)
      ..lineTo(w, h - b)
      ..lineTo(w - b, h)
      ..lineTo(b, h)
      ..lineTo(0, h - b)
      ..lineTo(0, b)
      ..close();

    // Dark base shadow (depth)
    canvas.drawPath(
      outerPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Top edge — neutral stone color
    canvas.drawLine(
      const Offset(b, 0),
      Offset(w - b, 0),
      Paint()
        ..color = const Color(0xFF3A3328)
        ..strokeWidth = 1.0,
    );

    // Bottom edge — darker groove
    canvas.drawLine(
      Offset(b, h),
      Offset(w - b, h),
      Paint()
        ..color = const Color(0xFF1A1610)
        ..strokeWidth = 1.0,
    );

    // Left faction stripe — P1 color
    final p1Active = p1IsActive;
    canvas.drawLine(
      Offset(0, b),
      Offset(0, h - b),
      Paint()
        ..color = p1Color.withValues(alpha: p1Active ? 0.85 : 0.30)
        ..strokeWidth = p1Active ? 2.5 : 1.5,
    );

    // Right faction stripe — P2 color
    canvas.drawLine(
      Offset(w, b),
      Offset(w, h - b),
      Paint()
        ..color = p2Color.withValues(alpha: !p1Active ? 0.85 : 0.30)
        ..strokeWidth = !p1Active ? 2.5 : 1.5,
    );

    // Bevel corner marks — engraved bracket dots
    _drawBevelCorners(canvas, size, b);
  }

  void _drawBevelCorners(Canvas canvas, Size size, double b) {
    final w = size.width;
    final h = size.height;
    final paint = Paint()
      ..color = const Color(0xFF4A4030)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    // Top-left
    canvas.drawLine(Offset(0, b), Offset(b, 0), paint);
    // Top-right
    canvas.drawLine(Offset(w - b, 0), Offset(w, b), paint);
    // Bottom-left
    canvas.drawLine(Offset(0, h - b), Offset(b, h), paint);
    // Bottom-right
    canvas.drawLine(Offset(w - b, h), Offset(w, h - b), paint);
  }

  @override
  bool shouldRepaint(_HudFramePainter old) =>
      old.p1Color != p1Color ||
      old.p2Color != p2Color ||
      old.p1IsActive != p1IsActive;
}

// ─────────────────────────────────────────────────────────────────────────────
// THINKING / OPPONENT LOADING BANNER
// Sits compactly right below the BattleHudHeader without obstructing the battlefield
// ─────────────────────────────────────────────────────────────────────────────
class _ThinkingBanner extends StatefulWidget {
  final String label;
  final Color color;

  const _ThinkingBanner({
    required this.label,
    required this.color,
  });

  @override
  State<_ThinkingBanner> createState() => _ThinkingBannerState();
}

class _ThinkingBannerState extends State<_ThinkingBanner>
    with TickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final AnimationController _dotController;
  late final AnimationController _rotateController;

  late final Animation<double> _pulseAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.2, end: 0.8).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat();

    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    _rotateAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _dotController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4.0),
      child: AnimatedBuilder(
        animation: _pulseAnim,
        builder: (context, child) {
          final glow = _pulseAnim.value;
          return CustomPaint(
            painter: _ThinkingPillPainter(
              color: widget.color,
              glowAlpha: glow,
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color.lerp(
                      const Color(0xFF14120E),
                      widget.color.withValues(alpha: 0.25),
                      glow * 0.4,
                    )!,
                    const Color(0xFF0A0907),
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.color.withValues(alpha: 0.15 * glow),
                    blurRadius: 12,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: child,
            ),
          );
        },
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Rotating mini arc spinner
            _buildSpinner(),
            const SizedBox(width: 8),
            // Text label
            Text(
              widget.label.toUpperCase(),
              style: GoogleFonts.sairaStencilOne(
                color: Colors.white.withValues(alpha: 0.95),
                fontSize: 10,
                letterSpacing: 1.5,
                fontWeight: FontWeight.bold,
                shadows: [
                  Shadow(
                    color: widget.color.withValues(alpha: 0.6),
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            // Animated cycling dots
            _buildDots(),
          ],
        ),
      ),
    );
  }

  Widget _buildSpinner() {
    return AnimatedBuilder(
      animation: _rotateAnim,
      builder: (context, _) {
        return SizedBox(
          width: 14,
          height: 14,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer faint circle
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.25),
                    width: 1.5,
                  ),
                ),
              ),
              // Rotating arc
              Transform.rotate(
                angle: _rotateAnim.value,
                child: CustomPaint(
                  size: const Size(14, 14),
                  painter: _MiniArcPainter(color: widget.color),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final phase = ((_dotController.value - (i * 0.3)) % 1.0);
            final opacity = phase < 0.5
                ? (phase / 0.5)
                : ((1.0 - phase) / 0.5);
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 3.5,
                height: 3.5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(
                    alpha: (0.2 + 0.8 * opacity).clamp(0.2, 1.0),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class _ThinkingPillPainter extends CustomPainter {
  final Color color;
  final double glowAlpha;

  _ThinkingPillPainter({
    required this.color,
    required this.glowAlpha,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const b = 6.0; // corner bevel
    final w = size.width;
    final h = size.height;

    final path = Path()
      ..moveTo(b, 0)
      ..lineTo(w - b, 0)
      ..lineTo(w, b)
      ..lineTo(w, h - b)
      ..lineTo(w - b, h)
      ..lineTo(b, h)
      ..lineTo(0, h - b)
      ..lineTo(0, b)
      ..close();

    // Border stroke with glow
    final borderPaint = Paint()
      ..color = color.withValues(alpha: 0.4 + 0.45 * glowAlpha)
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    canvas.drawPath(path, borderPaint);

    // Inner subtle notch lines
    final notchPaint = Paint()
      ..color = color.withValues(alpha: 0.3 * glowAlpha)
      ..strokeWidth = 0.8
      ..style = PaintingStyle.stroke;

    canvas.drawLine(const Offset(b + 2, 2), Offset(w - b - 2, 2), notchPaint);
  }

  @override
  bool shouldRepaint(_ThinkingPillPainter old) =>
      old.color != color || old.glowAlpha != glowAlpha;
}

class _MiniArcPainter extends CustomPainter {
  final Color color;
  const _MiniArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(1, 1, size.width - 2, size.height - 2);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        colors: [
          color.withValues(alpha: 0.0),
          color,
        ],
        startAngle: 0,
        endAngle: 2 * math.pi,
      ).createShader(rect);

    canvas.drawArc(rect, 0, 3.8, false, paint);
  }

  @override
  bool shouldRepaint(_MiniArcPainter old) => old.color != color;
}

