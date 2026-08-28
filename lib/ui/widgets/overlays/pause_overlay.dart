import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/enums/game_mode.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../providers/simulation_provider.dart';

class PauseOverlay extends ConsumerStatefulWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;
  final VoidCallback onSettings;

  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onQuit,
    required this.onSettings,
  });

  @override
  ConsumerState<PauseOverlay> createState() => _PauseOverlayState();
}

class _PauseOverlayState extends ConsumerState<PauseOverlay>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(
        parent: _animController,
        curve: Curves.easeOutBack,
      ),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getSubtitleText(WidgetRef ref) {
    final settings = ref.watch(gameSettingsProvider);
    final sim = ref.watch(simulationProvider);

    if (settings.mode == GameMode.story) {
      final totalMoves = sim.playerMoves + sim.aiMoves;
      return totalMoves > 0 ? "TOTAL MOVES: $totalMoves" : "CAMPAIGN BATTLE";
    } else if (settings.mode == GameMode.multiplayer) {
      return "MULTIPLAYER MATCH";
    }
    return "TACTICAL GRID FROZEN";
  }

  @override
  Widget build(BuildContext context) {
    final subtitle = _getSubtitleText(ref);

    return FadeTransition(
      opacity: _fadeAnim,
      child: Material(
        color: Colors.transparent,
        child: Stack(
          children: [
            // Dark vignette backdrop
            Positioned.fill(
              child: GestureDetector(
                onTap: widget.onResume,
                behavior: HitTestBehavior.opaque,
                child: Container(
                  color: Colors.black.withValues(alpha: 0.78),
                ),
              ),
            ),

            // Center Pause Slate / Card
            Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 360,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: CustomPaint(
                    painter: const _HadesCardPainter(),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(28, 16, 28, 14),
                      child: SingleChildScrollView(
                        physics: const ClampingScrollPhysics(),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Crimson PAUSE Title
                            Text(
                              "PAUSE",
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sairaStencilOne(
                                fontSize: 32,
                                fontWeight: FontWeight.w900,
                                color: const Color(0xFFE52538),
                                letterSpacing: 5.0,
                                height: 1.0,
                                shadows: const [
                                  Shadow(
                                    color: Color(0x99E52538),
                                    blurRadius: 16,
                                  ),
                                  Shadow(
                                    color: Color(0x66000000),
                                    offset: Offset(0, 2),
                                    blurRadius: 3,
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 3),

                            // Subtitle / Status
                            Text(
                              subtitle,
                              textAlign: TextAlign.center,
                              style: GoogleFonts.sairaStencilOne(
                                fontSize: 10.5,
                                color: const Color(0xFFC4B59D).withValues(alpha: 0.75),
                                letterSpacing: 2.0,
                              ),
                            ),

                            const SizedBox(height: 8),

                            // Ornamental Divider with Diamond Star
                            const SizedBox(
                              width: double.infinity,
                              height: 12,
                              child: CustomPaint(
                                painter: _OrnamentDividerPainter(
                                  color: Color(0xFF8C7343),
                                ),
                              ),
                            ),

                            const SizedBox(height: 12),

                            // Menu Items List (Big & Uniform Size)
                            _HadesMenuItem(
                              label: "Resume",
                              onTap: widget.onResume,
                            ),

                            const SizedBox(height: 8),

                            _HadesMenuItem(
                              label: "Settings",
                              onTap: widget.onSettings,
                            ),

                            const SizedBox(height: 8),

                            _HadesMenuItem(
                              label: "Abandon Battle",
                              isDanger: true,
                              onTap: widget.onQuit,
                            ),

                            const SizedBox(height: 12),

                            // Bottom Ruby Spark Accent
                            const SizedBox(
                              width: 20,
                              height: 20,
                              child: CustomPaint(
                                painter: _RubySparkPainter(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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
//  Hades Menu Item with interactive hover & tap feedback
// ─────────────────────────────────────────────────────────────────────────────

class _HadesMenuItem extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDanger;

  const _HadesMenuItem({
    required this.label,
    required this.onTap,
    this.isDanger = false,
  });

  @override
  State<_HadesMenuItem> createState() => _HadesMenuItemState();
}

class _HadesMenuItemState extends State<_HadesMenuItem> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = _isHovered || _isPressed;

    final Color textColor;
    if (widget.isDanger) {
      textColor = active
          ? const Color(0xFFFF5252)
          : const Color(0xFFC07676).withValues(alpha: 0.85);
    } else {
      textColor = active
          ? const Color(0xFFFFFFFF)
          : const Color(0xFFEBE0CD);
    }

    const double fontSize = 21.0;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTapDown: (_) => setState(() => _isPressed = true),
        onTapUp: (_) {
          setState(() => _isPressed = false);
          widget.onTap();
        },
        onTapCancel: () => setState(() => _isPressed = false),
        child: AnimatedScale(
          scale: _isPressed ? 0.95 : (_isHovered ? 1.05 : 1.0),
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOutCubic,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 20),
            decoration: BoxDecoration(
              color: active
                  ? (widget.isDanger
                      ? const Color(0xFFE52538).withValues(alpha: 0.12)
                      : const Color(0xFFD4AF37).withValues(alpha: 0.10))
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Left diamond indicator on active
                AnimatedOpacity(
                  opacity: active ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 140),
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: _buildDiamondBullet(
                      widget.isDanger
                          ? const Color(0xFFFF5252)
                          : const Color(0xFFFFD56B),
                    ),
                  ),
                ),

                // Item Text (Big uniform size)
                Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sairaStencilOne(
                    fontSize: fontSize,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 2.2,
                    shadows: active
                        ? [
                            Shadow(
                              color: textColor.withValues(alpha: 0.5),
                              blurRadius: 12,
                            ),
                          ]
                        : null,
                  ),
                ),

                // Right diamond indicator on active
                AnimatedOpacity(
                  opacity: active ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 140),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 12),
                    child: _buildDiamondBullet(
                      widget.isDanger
                          ? const Color(0xFFFF5252)
                          : const Color(0xFFFFD56B),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiamondBullet(Color color) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: 9,
        height: 9,
        decoration: BoxDecoration(
          color: color,
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.8),
              blurRadius: 7,
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom Slate Frame Painter (Hades-styled dark parchment slate + brass trim)
// ─────────────────────────────────────────────────────────────────────────────

class _HadesCardPainter extends CustomPainter {
  const _HadesCardPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    // 1. Base dark background fill (charcoal obsidian)
    final bgPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color(0xFF191410),
          Color(0xFF100D0A),
          Color(0xFF0D0B08),
        ],
      ).createShader(rect);

    canvas.drawRect(rect, bgPaint);

    // 2. Stylized jagged angular dark shade accents on the left & right sides (Hades aesthetic)
    final shadePaint = Paint()
      ..color = const Color(0xFF080604).withValues(alpha: 0.85)
      ..style = PaintingStyle.fill;

    // Left dark angular torn silhouette
    final leftShadePath = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width * 0.30, 0)
      ..lineTo(size.width * 0.12, size.height * 0.22)
      ..lineTo(size.width * 0.04, size.height * 0.40)
      ..lineTo(0, size.height * 0.50)
      ..close();
    canvas.drawPath(leftShadePath, shadePaint);

    // Right dark angular torn silhouette
    final rightShadePath = Path()
      ..moveTo(size.width, size.height * 0.45)
      ..lineTo(size.width * 0.85, size.height * 0.65)
      ..lineTo(size.width * 0.72, size.height * 0.82)
      ..lineTo(size.width * 0.82, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(rightShadePath, shadePaint);

    // 3. Inner border vignette & subtle warm ambient glow
    final innerVignettePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..color = const Color(0xFFD4AF37).withValues(alpha: 0.12);
    canvas.drawRect(rect.deflate(5.0), innerVignettePaint);

    // 4. Antique Brass/Gold Main Outer Frame
    final framePaint = Paint()
      ..color = const Color(0xFF7A5F2D)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.4;

    canvas.drawRect(rect, framePaint);

    // Corner brass notches & ornamental marks
    final cornerMarkPaint = Paint()
      ..color = const Color(0xFFC49A45)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    const notch = 12.0;
    // Top-left notch
    canvas.drawLine(const Offset(0, notch), const Offset(0, 0), cornerMarkPaint);
    canvas.drawLine(const Offset(0, 0), const Offset(notch, 0), cornerMarkPaint);
    // Top-right notch
    canvas.drawLine(Offset(size.width - notch, 0), Offset(size.width, 0), cornerMarkPaint);
    canvas.drawLine(Offset(size.width, 0), Offset(size.width, notch), cornerMarkPaint);
    // Bottom-left notch
    canvas.drawLine(Offset(0, size.height - notch), Offset(0, size.height), cornerMarkPaint);
    canvas.drawLine(Offset(0, size.height), Offset(notch, size.height), cornerMarkPaint);
    // Bottom-right notch
    canvas.drawLine(Offset(size.width - notch, size.height), Offset(size.width, size.height), cornerMarkPaint);
    canvas.drawLine(Offset(size.width, size.height - notch), Offset(size.width, size.height), cornerMarkPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ornamental Horizontal Divider Painter (Tapered line + central diamond star)
// ─────────────────────────────────────────────────────────────────────────────

class _OrnamentDividerPainter extends CustomPainter {
  final Color color;

  const _OrnamentDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final w = size.width;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke;

    // Draw horizontal line
    canvas.drawLine(Offset(12, cy), Offset(w - 12, cy), linePaint);

    // Draw Left and Right End Diamond Stars (Hades style)
    _drawStar(canvas, Offset(8, cy), 6, color);
    _drawStar(canvas, Offset(w - 8, cy), 6, color);
  }

  void _drawStar(Canvas canvas, Offset center, double radius, Color starColor) {
    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();

    final paint = Paint()
      ..color = starColor
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _OrnamentDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ruby Spark Painter (The 4-pointed radiant crimson star at bottom)
// ─────────────────────────────────────────────────────────────────────────────

class _RubySparkPainter extends CustomPainter {
  const _RubySparkPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 10.0;
    const innerRadius = 2.2;

    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();

    // Outer glow
    final glowPaint = Paint()
      ..color = const Color(0xFFE52538).withValues(alpha: 0.5)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawPath(path, glowPaint);

    // Inner filled star
    final starPaint = Paint()
      ..color = const Color(0xFFE52538)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, starPaint);

    // Core bright highlight
    final corePaint = Paint()
      ..color = const Color(0xFFFF8A80)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, innerRadius, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

