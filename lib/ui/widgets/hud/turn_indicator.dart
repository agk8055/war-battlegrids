import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/turn.dart';
import '../../../core/enums/game_mode.dart';
import '../../../providers/game_settings_provider.dart';

class TurnIndicator extends ConsumerStatefulWidget {
  final Turn currentTurn;
  final GameMode mode;

  const TurnIndicator({
    super.key,
    required this.currentTurn,
    required this.mode,
  });

  @override
  ConsumerState<TurnIndicator> createState() => _TurnIndicatorState();
}

class _TurnIndicatorState extends ConsumerState<TurnIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _breathController;
  late Animation<double> _breathAnim;

  // Track previous turn to trigger transition animation
  Turn? _previousTurn;

  @override
  void initState() {
    super.initState();
    _previousTurn = widget.currentTurn;

    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat(reverse: true);

    _breathAnim = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _breathController, curve: Curves.easeInOut),
    );
  }

  @override
  void didUpdateWidget(TurnIndicator old) {
    super.didUpdateWidget(old);
    if (old.currentTurn != widget.currentTurn) {
      _previousTurn = old.currentTurn;
      // Reset breath pulse on turn change
      _breathController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _breathController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameSettingsProvider);
    final isPlayer = widget.currentTurn == Turn.player;
    final isMultiplayer = widget.mode == GameMode.multiplayer;

    final String turnName;
    if (isMultiplayer) {
      turnName = isPlayer ? settings.player1Name : settings.player2Name;
    } else {
      turnName = isPlayer ? 'PLAYER' : 'AI';
    }

    // Use the player's faction color from settings
    final Color factionColor = isPlayer
        ? Color(settings.player1Color)
        : Color(settings.player2Color);

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 400),
      switchInCurve: Curves.easeOut,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.3),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: _TurnBadge(
        key: ValueKey(widget.currentTurn),
        turnName: turnName,
        factionColor: factionColor,
        breathAnim: _breathAnim,
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TURN BADGE — forged iron plaque with bevel corners
// ─────────────────────────────────────────────────────────────────────────────
class _TurnBadge extends StatelessWidget {
  final String turnName;
  final Color factionColor;
  final Animation<double> breathAnim;

  const _TurnBadge({
    super.key,
    required this.turnName,
    required this.factionColor,
    required this.breathAnim,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: breathAnim,
      builder: (context, child) {
        return CustomPaint(
          painter: _TurnBevelPainter(
            color: factionColor,
            glowAlpha: breathAnim.value,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  factionColor.withValues(alpha: 0.14 * breathAnim.value),
                  const Color(0xFF0A0A06),
                ],
              ),
            ),
            child: child,
          ),
        );
      },
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left sword icon — turn marker
          _SwordMark(color: factionColor),
          const SizedBox(width: 7),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "COMMAND",
                style: TextStyle(
                  color: factionColor.withValues(alpha: 0.55),
                  fontSize: 6.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2.5,
                ),
              ),
              Text(
                turnName.toUpperCase(),
                style: TextStyle(
                  color: factionColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  shadows: [
                    Shadow(
                      color: factionColor.withValues(alpha: 0.55),
                      blurRadius: 8,
                    ),
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.9),
                      offset: const Offset(1, 1),
                      blurRadius: 0,
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(width: 7),
          _SwordMark(color: factionColor),
        ],
      ),
    );
  }
}

// ── SWORD MARK — small decorative flanking icon ───────────────────────────────
class _SwordMark extends StatelessWidget {
  final Color color;
  const _SwordMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 10,
      height: 18,
      child: CustomPaint(painter: _SwordPainter(color: color)),
    );
  }
}

class _SwordPainter extends CustomPainter {
  final Color color;
  _SwordPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;

    final cx = size.width / 2;
    // Blade: vertical line
    canvas.drawLine(Offset(cx, 0), Offset(cx, size.height * 0.72), paint);
    // Guard: horizontal crossbar
    canvas.drawLine(
        Offset(cx - size.width * 0.45, size.height * 0.72),
        Offset(cx + size.width * 0.45, size.height * 0.72),
        paint);
    // Pommel: small square dot
    canvas.drawRect(
      Rect.fromCenter(
        center: Offset(cx, size.height * 0.90),
        width: 3,
        height: 3,
      ),
      Paint()..color = color.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_SwordPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// TURN BEVEL PAINTER — cut-corner border with breathing glow
// ─────────────────────────────────────────────────────────────────────────────
class _TurnBevelPainter extends CustomPainter {
  final Color color;
  final double glowAlpha;

  _TurnBevelPainter({required this.color, required this.glowAlpha});

  @override
  void paint(Canvas canvas, Size size) {
    const b = 8.0; // bevel
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

    // Glow fill layer
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.06 * glowAlpha)
        ..style = PaintingStyle.fill,
    );

    // Main border
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.5 + 0.5 * glowAlpha)
        ..strokeWidth = 1.5
        ..style = PaintingStyle.stroke,
    );

    // Inner inset border (engraved double-line effect)
    const inset = 3.0;
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
        ..color = color.withValues(alpha: 0.15 * glowAlpha)
        ..strokeWidth = 0.8
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(_TurnBevelPainter old) =>
      old.color != color || old.glowAlpha != glowAlpha;
}