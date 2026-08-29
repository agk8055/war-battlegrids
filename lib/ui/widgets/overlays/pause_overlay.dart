import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/enums/game_mode.dart';
import '../../../core/services/audio_service.dart';
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
      duration: const Duration(milliseconds: 280),
    );
    _fadeAnim = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOutCubic,
    );
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
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

  void _playClickSfx() {
    ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
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
            // 1. Dark vignette backdrop with blur feel
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _playClickSfx();
                  widget.onResume();
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: RadialGradient(
                      center: Alignment.center,
                      radius: 1.1,
                      colors: [
                        Colors.black.withValues(alpha: 0.65),
                        Colors.black.withValues(alpha: 0.85),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // 2. Center Parchment Pause Slate
            Center(
              child: ScaleTransition(
                scale: _scaleAnim,
                child: Container(
                  width: 380,
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Parchment Background Image
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.7),
                                blurRadius: 24,
                                spreadRadius: 4,
                                offset: const Offset(0, 10),
                              ),
                              BoxShadow(
                                color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
                                blurRadius: 30,
                                spreadRadius: 0,
                              ),
                            ],
                          ),
                          child: Image.asset(
                            AppAssets.pauseBg,
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF231B15),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF8C7343),
                                    width: 3,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),

                      // Content inside parchment (padding keeps clear of carved side borders)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(44, 24, 44, 26),
                        child: SingleChildScrollView(
                          physics: const ClampingScrollPhysics(),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Top Parchment PAUSE Title
                              Text(
                                "PAUSE",
                                textAlign: TextAlign.center,
                                style: GoogleFonts.sairaStencilOne(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w900,
                                  color: const Color(0xFF2C160E),
                                  letterSpacing: 4.5,
                                  height: 1.0,
                                  shadows: [
                                    Shadow(
                                      color: const Color(0xFFE8D4B0).withValues(alpha: 0.9),
                                      offset: const Offset(0, 1.2),
                                      blurRadius: 1,
                                    ),
                                    Shadow(
                                      color: const Color(0xFF5A3118).withValues(alpha: 0.4),
                                      offset: const Offset(0, 2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 3),

                              // Subtitle / Battle Status Badge
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF422817).withValues(alpha: 0.08),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  subtitle,
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.sairaStencilOne(
                                    fontSize: 10.5,
                                    color: const Color(0xFF6B482A),
                                    letterSpacing: 2.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 10),

                              // Ornamental Filigree Divider
                              const SizedBox(
                                width: double.infinity,
                                height: 12,
                                child: CustomPaint(
                                  painter: _ScrollDividerPainter(
                                    color: Color(0xFF7A5833),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 14),

                              // Resume Button
                              _ScrollMenuButton(
                                label: "RESUME",
                                icon: Icons.play_arrow_rounded,
                                isPrimary: true,
                                onTap: () {
                                  _playClickSfx();
                                  widget.onResume();
                                },
                              ),

                              const SizedBox(height: 9),

                              // Settings Button
                              _ScrollMenuButton(
                                label: "SETTINGS",
                                icon: Icons.tune_rounded,
                                onTap: () {
                                  _playClickSfx();
                                  widget.onSettings();
                                },
                              ),

                              const SizedBox(height: 9),

                              // Abandon Battle Button
                              _ScrollMenuButton(
                                label: "ABANDON BATTLE",
                                icon: Icons.flag_outlined,
                                isDanger: true,
                                onTap: () {
                                  _playClickSfx();
                                  widget.onQuit();
                                },
                              ),

                              const SizedBox(height: 12),

                              // Bottom Antique Rune Accent
                              const SizedBox(
                                width: 22,
                                height: 16,
                                child: CustomPaint(
                                  painter: _ParchmentSealPainter(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
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
//  Parchment Carved Plaque Button with interactive feedback & audio
// ─────────────────────────────────────────────────────────────────────────────

class _ScrollMenuButton extends StatefulWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isDanger;

  const _ScrollMenuButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isDanger = false,
  });

  @override
  State<_ScrollMenuButton> createState() => _ScrollMenuButtonState();
}

class _ScrollMenuButtonState extends State<_ScrollMenuButton> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final bool active = _isHovered || _isPressed;

    // Palette tuned for ancient parchment look
    final Color baseBg;
    final Color borderColor;
    final Color textColor;
    final Color iconColor;

    if (widget.isDanger) {
      baseBg = active ? const Color(0xFF4A1418) : const Color(0xFF3B1619);
      borderColor = active ? const Color(0xFFE53935) : const Color(0xFF7A2E33);
      textColor = active ? const Color(0xFFFFEBEE) : const Color(0xFFEF9A9A);
      iconColor = active ? const Color(0xFFFF5252) : const Color(0xFFE57373);
    } else if (widget.isPrimary) {
      baseBg = active ? const Color(0xFF382613) : const Color(0xFF2C1D0E);
      borderColor = active ? const Color(0xFFFFD54F) : const Color(0xFFC59B3F);
      textColor = active ? const Color(0xFFFFFDE7) : const Color(0xFFFFE082);
      iconColor = active ? const Color(0xFFFFD54F) : const Color(0xFFFFCA28);
    } else {
      baseBg = active ? const Color(0xFF2C2219) : const Color(0xFF241B13);
      borderColor = active ? const Color(0xFFC4A46C) : const Color(0xFF6B5336);
      textColor = active ? const Color(0xFFFFF8E7) : const Color(0xFFD7CCC8);
      iconColor = active ? const Color(0xFFD7CCC8) : const Color(0xFFA1887F);
    }

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
          scale: _isPressed ? 0.96 : (_isHovered ? 1.02 : 1.0),
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 230,
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
              decoration: BoxDecoration(
                color: baseBg,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: borderColor,
                  width: active ? 1.8 : 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    offset: const Offset(0, 3),
                    blurRadius: 5,
                  ),
                  if (active)
                    BoxShadow(
                      color: borderColor.withValues(alpha: 0.3),
                      blurRadius: 10,
                      spreadRadius: 1,
                    ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.max,
                children: [
                  // Left diamond accent
                  _buildDiamondBullet(
                    borderColor.withValues(alpha: active ? 1.0 : 0.4),
                    size: active ? 6.5 : 5,
                  ),
                  const SizedBox(width: 8),

                  // Icon
                  Icon(
                    widget.icon,
                    size: 15,
                    color: iconColor,
                  ),
                  const SizedBox(width: 6),

                  // Button Text
                  Flexible(
                    child: Text(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.sairaStencilOne(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w700,
                        color: textColor,
                        letterSpacing: 1.5,
                        shadows: active
                            ? [
                                Shadow(
                                  color: borderColor.withValues(alpha: 0.6),
                                  blurRadius: 8,
                                ),
                              ]
                            : null,
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),
                  // Right diamond accent
                  _buildDiamondBullet(
                    borderColor.withValues(alpha: active ? 1.0 : 0.4),
                    size: active ? 6.5 : 5,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDiamondBullet(Color color, {double size = 6}) {
    return Transform.rotate(
      angle: math.pi / 4,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: color,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ornamental Scroll Divider (Tapered antique line + central diamond knot)
// ─────────────────────────────────────────────────────────────────────────────

class _ScrollDividerPainter extends CustomPainter {
  final Color color;

  const _ScrollDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final cy = size.height / 2;
    final w = size.width;

    final linePaint = Paint()
      ..color = color.withValues(alpha: 0.65)
      ..strokeWidth = 1.3
      ..style = PaintingStyle.stroke;

    // Center break for diamond knot
    const knotWidth = 18.0;
    final midLeft = (w / 2) - knotWidth;
    final midRight = (w / 2) + knotWidth;

    // Draw horizontal lines left & right
    canvas.drawLine(Offset(10, cy), Offset(midLeft, cy), linePaint);
    canvas.drawLine(Offset(midRight, cy), Offset(w - 10, cy), linePaint);

    // End dots
    final dotPaint = Paint()
      ..color = color.withValues(alpha: 0.8)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(8, cy), 1.8, dotPaint);
    canvas.drawCircle(Offset(w - 8, cy), 1.8, dotPaint);

    // Central Diamond Star
    _drawStar(canvas, Offset(w / 2, cy), 6, color);
    _drawStar(canvas, Offset(w / 2 - 10, cy), 3.2, color.withValues(alpha: 0.7));
    _drawStar(canvas, Offset(w / 2 + 10, cy), 3.2, color.withValues(alpha: 0.7));
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
  bool shouldRepaint(covariant _ScrollDividerPainter oldDelegate) =>
      oldDelegate.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Parchment Seal Painter (Antique brass/bronze rune knot at bottom)
// ─────────────────────────────────────────────────────────────────────────────

class _ParchmentSealPainter extends CustomPainter {
  const _ParchmentSealPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    const radius = 7.0;

    final path = Path()
      ..moveTo(center.dx, center.dy - radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius)
      ..quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy)
      ..quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius)
      ..close();

    final paint = Paint()
      ..color = const Color(0xFF8C6239)
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, paint);

    final corePaint = Paint()
      ..color = const Color(0xFFDEB887)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, 1.8, corePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
