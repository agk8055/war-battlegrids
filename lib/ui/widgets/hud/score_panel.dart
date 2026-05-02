import 'package:flutter/material.dart';
import '../../../core/enums/win_condition_type.dart';

class ScorePanel extends StatefulWidget {
  final String title;
  final int points;
  final Color color;
  final String symbolAsset;
  final bool kingdomAttackUnlocked;
  final WinConditionType activeWinCondition;
  final bool isActiveTurn;
  final CrossAxisAlignment alignment;

  const ScorePanel({
    super.key,
    required this.title,
    required this.points,
    required this.color,
    required this.symbolAsset,
    required this.kingdomAttackUnlocked,
    required this.activeWinCondition,
    this.isActiveTurn = false,
    this.alignment = CrossAxisAlignment.start,
  });

  @override
  State<ScorePanel> createState() => _ScorePanelState();
}

class _ScorePanelState extends State<ScorePanel>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.55, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isRight = widget.alignment == CrossAxisAlignment.end;
    final color = widget.color;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 5),
      decoration: BoxDecoration(
        // Stone-dark base, slightly warmer when active
        gradient: LinearGradient(
          begin: isRight ? Alignment.centerRight : Alignment.centerLeft,
          end: isRight ? Alignment.centerLeft : Alignment.centerRight,
          colors: widget.isActiveTurn
              ? [
                  color.withValues(alpha: 0.18),
                  const Color(0xFF111008),
                ]
              : [
                  const Color(0xFF0E0E0E),
                  const Color(0xFF0A0A0A),
                ],
        ),
      ),
      child: CustomPaint(
        // Engraved side-border: only the active-side edge is accented
        painter: _SideBorderPainter(
          color: widget.isActiveTurn ? color : color.withValues(alpha: 0.25),
          isRight: isRight,
          isActive: widget.isActiveTurn,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            left: isRight ? 0 : 4,
            right: isRight ? 4 : 0,
          ),
          child: Row(
            mainAxisAlignment:
                isRight ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: isRight
                ? [
                    _buildTextContent(color, isRight),
                    const SizedBox(width: 8),
                    _buildEmblem(color),
                  ]
                : [
                    _buildEmblem(color),
                    const SizedBox(width: 8),
                    _buildTextContent(color, isRight),
                  ],
          ),
        ),
      ),
    );
  }

  /// Kingdom emblem — shield-shaped container with the symbol icon.
  Widget _buildEmblem(Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: widget.isActiveTurn ? 0.28 : 0.12),
            color.withValues(alpha: widget.isActiveTurn ? 0.10 : 0.04),
          ],
        ),
        boxShadow: widget.isActiveTurn
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.35),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 2),
                ),
              ]
            : [],
      ),
      child: CustomPaint(
        painter: _ShieldBorderPainter(
          color: color,
          isActive: widget.isActiveTurn,
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Opacity(
                opacity: widget.isActiveTurn ? _pulseAnim.value : 0.55,
                child: child,
              );
            },
            child: Image.asset(
              widget.symbolAsset,
              width: 20,
              height: 20,
              color: color,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent(Color color, bool isRight) {
    return Column(
      crossAxisAlignment: widget.alignment,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Kingdom name — like a banner inscription
        Text(
          widget.title.toUpperCase(),
          textAlign: isRight ? TextAlign.right : TextAlign.left,
          style: TextStyle(
            color: widget.isActiveTurn ? color : color.withValues(alpha: 0.65),
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            fontSize: 11,
            shadows: widget.isActiveTurn
                ? [
                    Shadow(
                      color: color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                    // Hard directional shadow (torch-light)
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.85),
                      offset: const Offset(1, 1),
                      blurRadius: 0,
                    ),
                  ]
                : [],
          ),
        ),
        const SizedBox(height: 1),
        // Points row — label + value separated
        Row(
          mainAxisSize: MainAxisSize.min,
          children: isRight
              ? [
                  _PointsValue(points: widget.points, color: color),
                  const SizedBox(width: 3),
                  _PointsLabel(isRight: isRight),
                ]
              : [
                  _PointsLabel(isRight: isRight),
                  const SizedBox(width: 3),
                  _PointsValue(points: widget.points, color: color),
                ],
        ),
        // Kingdom Attack unlock banner
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: widget.kingdomAttackUnlocked
              ? Padding(
                  key: const ValueKey('ka_unlocked'),
                  padding: const EdgeInsets.only(top: 3.0),
                  child: _KingdomAttackBadge(isRight: isRight),
                )
              : const SizedBox.shrink(key: ValueKey('ka_none')),
        ),
      ],
    );
  }
}

// ── POINTS LABEL ──────────────────────────────────────────────────────────────
class _PointsLabel extends StatelessWidget {
  final bool isRight;
  const _PointsLabel({required this.isRight});

  @override
  Widget build(BuildContext context) {
    return Text(
      "PTS",
      style: const TextStyle(
        color: Color(0xFF7A7060),
        fontSize: 7,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
      ),
    );
  }
}

// ── POINTS VALUE ──────────────────────────────────────────────────────────────
class _PointsValue extends StatelessWidget {
  final int points;
  final Color color;
  const _PointsValue({required this.points, required this.color});

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, -0.4),
            end: Offset.zero,
          ).animate(anim),
          child: child,
        ),
      ),
      child: Text(
        '$points',
        key: ValueKey(points),
        style: TextStyle(
          color: color.withValues(alpha: 0.9),
          fontSize: 13,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

// ── KINGDOM ATTACK BADGE ──────────────────────────────────────────────────────
class _KingdomAttackBadge extends StatelessWidget {
  final bool isRight;
  const _KingdomAttackBadge({required this.isRight});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1200),
        border: Border(
          left: isRight
              ? BorderSide.none
              : const BorderSide(color: Colors.amber, width: 1.5),
          right: isRight
              ? const BorderSide(color: Colors.amber, width: 1.5)
              : BorderSide.none,
          top: const BorderSide(
              color: Color(0x55FFC107), width: 0.5),
          bottom: const BorderSide(
              color: Color(0x55FFC107), width: 0.5),
        ),
      ),
      child: const Text(
        "⚔ SIEGE READY",
        style: TextStyle(
          color: Colors.amber,
          fontSize: 7,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.0,
          shadows: [Shadow(color: Colors.orange, blurRadius: 6)],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SIDE BORDER PAINTER — single vertical accent stripe, engraved look
// ─────────────────────────────────────────────────────────────────────────────
class _SideBorderPainter extends CustomPainter {
  final Color color;
  final bool isRight;
  final bool isActive;

  _SideBorderPainter({
    required this.color,
    required this.isRight,
    required this.isActive,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final x = isRight ? size.width : 0.0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = isActive ? 2.5 : 1.0
      ..style = PaintingStyle.stroke;

    // Main vertical stripe
    canvas.drawLine(Offset(x, 6), Offset(x, size.height - 6), paint);

    // Top and bottom notch ticks (engraved bracket feel)
    final tickLen = 5.0;
    final tickPaint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.0;
    final dir = isRight ? -1.0 : 1.0;
    canvas.drawLine(Offset(x, 6), Offset(x + dir * tickLen, 6), tickPaint);
    canvas.drawLine(Offset(x, size.height - 6),
        Offset(x + dir * tickLen, size.height - 6), tickPaint);
  }

  @override
  bool shouldRepaint(_SideBorderPainter old) =>
      old.color != color || old.isActive != isActive;
}

// ─────────────────────────────────────────────────────────────────────────────
// SHIELD BORDER PAINTER — cut-corner square (no rounding)
// ─────────────────────────────────────────────────────────────────────────────
class _ShieldBorderPainter extends CustomPainter {
  final Color color;
  final bool isActive;

  _ShieldBorderPainter({required this.color, required this.isActive});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: isActive ? 0.8 : 0.35)
      ..strokeWidth = isActive ? 1.5 : 1.0
      ..style = PaintingStyle.stroke;

    const b = 6.0; // bevel size
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

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ShieldBorderPainter old) =>
      old.color != color || old.isActive != isActive;
}