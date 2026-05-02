import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/enums/turn.dart';
import '../../../core/enums/game_mode.dart';
import '../../../providers/game_settings_provider.dart';
import '../../../providers/bluetooth_provider.dart';

class GameOverOverlay extends ConsumerStatefulWidget {
  final Turn winner;
  final GameMode mode;
  final VoidCallback onReturnToMap;

  const GameOverOverlay({
    super.key,
    required this.winner,
    required this.mode,
    required this.onReturnToMap,
  });

  @override
  ConsumerState<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends ConsumerState<GameOverOverlay>
    with TickerProviderStateMixin {
  late AnimationController _fadeController;
  late AnimationController _titleController;
  late AnimationController _panelController;
  late AnimationController _buttonController;

  late Animation<double> _bgFade;
  late Animation<double> _titleScale;
  late Animation<double> _titleFade;
  late Animation<Offset> _panelSlide;
  late Animation<double> _panelFade;
  late Animation<double> _buttonFade;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _titleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _panelController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _buttonController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );

    _bgFade = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);

    _titleScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(parent: _titleController, curve: Curves.easeOutCubic),
    );
    _titleFade = CurvedAnimation(parent: _titleController, curve: Curves.easeIn);

    _panelSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _panelController, curve: Curves.easeOutCubic));
    _panelFade = CurvedAnimation(parent: _panelController, curve: Curves.easeIn);

    _buttonFade = CurvedAnimation(parent: _buttonController, curve: Curves.easeIn);

    // Staggered entrance
    _fadeController.forward();
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _titleController.forward();
    });
    Future.delayed(const Duration(milliseconds: 450), () {
      if (mounted) _panelController.forward();
    });
    Future.delayed(const Duration(milliseconds: 750), () {
      if (mounted) _buttonController.forward();
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _titleController.dispose();
    _panelController.dispose();
    _buttonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameSettingsProvider);
    final bluetoothState = ref.watch(bluetoothProvider);
    final isMultiplayer = widget.mode == GameMode.multiplayer;
    final isBluetooth = bluetoothState.status == BluetoothStatus.connected;
    final isHost = bluetoothState.isHost;

    final isSameDevice = isMultiplayer && !isBluetooth;

    final isLocalPlayerWin = isMultiplayer
        ? (isHost ? widget.winner == Turn.player : widget.winner == Turn.ai)
        : (widget.winner == Turn.player);

    String title;
    String subtitle;
    Color accentColor;

    if (isSameDevice) {
      final winnerName = widget.winner == Turn.player
          ? settings.player1Name
          : settings.player2Name;
      title = "${winnerName.toUpperCase()} WINS";
      subtitle = widget.winner == Turn.player
          ? "The realm of ${settings.player1Name} has triumphed."
          : "The realm of ${settings.player2Name} has triumphed.";
      accentColor = widget.winner == Turn.player
          ? Color(settings.player1Color)
          : Color(settings.player2Color);
    } else {
      title = isLocalPlayerWin ? "VICTORY" : "DEFEAT";
      accentColor = isLocalPlayerWin
          ? Color(settings.player1Color)
          : Color(settings.player2Color);

      if (isMultiplayer) {
        subtitle = isLocalPlayerWin
            ? "You have claimed dominance over the battlefield."
            : "Your kingdom's siege defenses have been breached.";
      } else {
        subtitle = isLocalPlayerWin
            ? "The enemy kingdom has fallen to your blockade."
            : "Your kingdom's siege defenses have been breached.";
      }
    }

    final glowColor = accentColor.withValues(alpha: 0.45);
    final dimAccent = accentColor.withValues(alpha: 0.15);
    final buttonLabel =
        isMultiplayer ? "RETURN TO MENU" : "RETURN TO MAP";

    return Positioned.fill(
      child: FadeTransition(
        opacity: _bgFade,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 4.0, sigmaY: 4.0),
          child: Container(
            // Darkened battlefield background
            color: Colors.black.withValues(alpha: 0.72),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── TOP BANNER ORNAMENT ──────────────────────────────
                  _BannerOrnament(color: accentColor),

                  const SizedBox(height: 20),

                  // ── TITLE ────────────────────────────────────────────
                  ScaleTransition(
                    scale: _titleScale,
                    child: FadeTransition(
                      opacity: _titleFade,
                      child: _TitleBanner(
                        title: title,
                        accentColor: accentColor,
                        glowColor: glowColor,
                        dimAccent: dimAccent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ── SUBTITLE PANEL ───────────────────────────────────
                  SlideTransition(
                    position: _panelSlide,
                    child: FadeTransition(
                      opacity: _panelFade,
                      child: _SubtitlePanel(
                        subtitle: subtitle,
                        accentColor: accentColor,
                        dimAccent: dimAccent,
                      ),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // ── ACTION BUTTON ────────────────────────────────────
                  FadeTransition(
                    opacity: _buttonFade,
                    child: _ForgedButton(
                      label: buttonLabel,
                      onPressed: widget.onReturnToMap,
                      accentColor: accentColor,
                      glowColor: glowColor,
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── BOTTOM ORNAMENT ──────────────────────────────────
                  FadeTransition(
                    opacity: _panelFade,
                    child: _BannerOrnament(color: accentColor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TITLE BANNER — carved stone aesthetic with engraved border
// ─────────────────────────────────────────────────────────────────────────────
class _TitleBanner extends StatelessWidget {
  final String title;
  final Color accentColor;
  final Color glowColor;
  final Color dimAccent;

  const _TitleBanner({
    required this.title,
    required this.accentColor,
    required this.glowColor,
    required this.dimAccent,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _BevelBorderPainter(
        color: accentColor,
        strokeWidth: 2.0,
        bevelSize: 16,
      ),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 32),
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
        // Inner stone fill
        decoration: BoxDecoration(
          color: const Color(0xFF0D0D0D),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              const Color(0xFF1A1A1A),
              const Color(0xFF0A0A0A),
            ],
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Thin top rule
            _EngravedRule(color: accentColor),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 58,
                fontWeight: FontWeight.w900,
                color: accentColor,
                letterSpacing: 10.0,
                shadows: [
                  Shadow(color: glowColor, blurRadius: 24),
                  Shadow(color: glowColor, blurRadius: 48),
                  // Hard directional shadow (torch-light from top-left)
                  Shadow(
                    color: Colors.black.withValues(alpha: 0.9),
                    offset: const Offset(3, 4),
                    blurRadius: 0,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            _EngravedRule(color: accentColor),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SUBTITLE PANEL — wooden plaque feel
// ─────────────────────────────────────────────────────────────────────────────
class _SubtitlePanel extends StatelessWidget {
  final String subtitle;
  final Color accentColor;
  final Color dimAccent;

  const _SubtitlePanel({
    required this.subtitle,
    required this.accentColor,
    required this.dimAccent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 48),
      decoration: BoxDecoration(
        // Subtle warm gradient to mimic aged parchment/wood
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1C1608),
            const Color(0xFF120F06),
          ],
        ),
        border: Border(
          left: BorderSide(color: accentColor.withValues(alpha: 0.6), width: 3),
          right: BorderSide(color: accentColor.withValues(alpha: 0.6), width: 3),
          top: BorderSide(color: accentColor.withValues(alpha: 0.25), width: 1),
          bottom: BorderSide(color: accentColor.withValues(alpha: 0.25), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Left decorative mark
          _CrossMark(color: accentColor),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFFCCBB99),
                fontStyle: FontStyle.italic,
                letterSpacing: 0.5,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(width: 16),
          _CrossMark(color: accentColor),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FORGED BUTTON — iron-plate aesthetic with cut corners
// ─────────────────────────────────────────────────────────────────────────────
class _ForgedButton extends StatefulWidget {
  final String label;
  final VoidCallback onPressed;
  final Color accentColor;
  final Color glowColor;

  const _ForgedButton({
    required this.label,
    required this.onPressed,
    required this.accentColor,
    required this.glowColor,
  });

  @override
  State<_ForgedButton> createState() => _ForgedButtonState();
}

class _ForgedButtonState extends State<_ForgedButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onPressed();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        transform: Matrix4.identity()
          ..translate(0.0, _pressed ? 3.0 : 0.0),
        child: CustomPaint(
          painter: _BevelBorderPainter(
            color: widget.accentColor,
            strokeWidth: 2.5,
            bevelSize: 12,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 52, vertical: 16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: _pressed
                    ? [
                        widget.accentColor.withValues(alpha: 0.25),
                        widget.accentColor.withValues(alpha: 0.10),
                      ]
                    : [
                        widget.accentColor.withValues(alpha: 0.18),
                        widget.accentColor.withValues(alpha: 0.06),
                      ],
              ),
            ),
            child: Text(
              widget.label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: _pressed ? widget.accentColor : Colors.white,
                letterSpacing: 4.0,
                shadows: _pressed
                    ? [Shadow(color: widget.glowColor, blurRadius: 12)]
                    : [],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// BANNER ORNAMENT — horizontal divider with emblematic center mark
// ─────────────────────────────────────────────────────────────────────────────
class _BannerOrnament extends StatelessWidget {
  final Color color;
  const _BannerOrnament({required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 48),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    color.withValues(alpha: 0.7),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _DiamondMark(color: color, size: 10),
          ),
          // Center crown icon
          Icon(Icons.shield, color: color.withValues(alpha: 0.85), size: 22),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _DiamondMark(color: color, size: 10),
          ),
          Expanded(
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    color.withValues(alpha: 0.7),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HELPER WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

/// A thin horizontal rule with a fade effect — like an engraved line on stone.
class _EngravedRule extends StatelessWidget {
  final Color color;
  const _EngravedRule({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            color.withValues(alpha: 0.5),
            color.withValues(alpha: 0.8),
            color.withValues(alpha: 0.5),
            Colors.transparent,
          ],
        ),
      ),
    );
  }
}

/// Small ✦ diamond decorative mark.
class _DiamondMark extends StatelessWidget {
  final Color color;
  final double size;
  const _DiamondMark({required this.color, required this.size});

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: 0.785398, // 45°
      child: Container(
        width: size,
        height: size,
        color: color.withValues(alpha: 0.75),
      ),
    );
  }
}

/// Small + cross decorative mark for panel flanks.
class _CrossMark extends StatelessWidget {
  final Color color;
  const _CrossMark({required this.color});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 12,
      height: 12,
      child: CustomPaint(painter: _CrossPainter(color: color)),
    );
  }
}

class _CrossPainter extends CustomPainter {
  final Color color;
  _CrossPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withValues(alpha: 0.7)
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.square;
    canvas.drawLine(Offset(size.width / 2, 0), Offset(size.width / 2, size.height), paint);
    canvas.drawLine(Offset(0, size.height / 2), Offset(size.width, size.height / 2), paint);
  }

  @override
  bool shouldRepaint(_CrossPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
// BEVEL BORDER PAINTER — cut/notched corners instead of rounded
// ─────────────────────────────────────────────────────────────────────────────
class _BevelBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double bevelSize;

  _BevelBorderPainter({
    required this.color,
    required this.strokeWidth,
    required this.bevelSize,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.miter;

    final b = bevelSize;
    final w = size.width;
    final h = size.height;

    // Outer bevel path (cut corners)
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

    // Small corner accent marks (forged rivets / bracket feel)
    final accentPaint = Paint()
      ..color = color.withValues(alpha: 0.4)
      ..strokeWidth = strokeWidth * 0.6
      ..style = PaintingStyle.stroke;

    final accentLen = b * 0.55;
    _drawCornerAccent(canvas, accentPaint, Offset(b, 0), accentLen, 1, 1);
    _drawCornerAccent(canvas, accentPaint, Offset(w - b, 0), accentLen, -1, 1);
    _drawCornerAccent(canvas, accentPaint, Offset(0, b), accentLen, 1, 1, vertical: true);
    _drawCornerAccent(canvas, accentPaint, Offset(w, b), accentLen, -1, 1, vertical: true);
    _drawCornerAccent(canvas, accentPaint, Offset(b, h), accentLen, 1, -1);
    _drawCornerAccent(canvas, accentPaint, Offset(w - b, h), accentLen, -1, -1);
    _drawCornerAccent(canvas, accentPaint, Offset(0, h - b), accentLen, 1, -1, vertical: true);
    _drawCornerAccent(canvas, accentPaint, Offset(w, h - b), accentLen, -1, -1, vertical: true);
  }

  void _drawCornerAccent(
    Canvas canvas,
    Paint paint,
    Offset origin,
    double len,
    double dx,
    double dy, {
    bool vertical = false,
  }) {
    if (!vertical) {
      canvas.drawLine(origin, origin + Offset(dx * len, 0), paint);
    } else {
      canvas.drawLine(origin, origin + Offset(0, dy * len), paint);
    }
  }

  @override
  bool shouldRepaint(_BevelBorderPainter old) =>
      old.color != color ||
      old.strokeWidth != strokeWidth ||
      old.bevelSize != bevelSize;
}