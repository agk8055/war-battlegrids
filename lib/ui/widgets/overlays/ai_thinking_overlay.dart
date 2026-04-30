import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class AiThinkingOverlay extends StatefulWidget {
  final Color color;

  const AiThinkingOverlay({super.key, required this.color});

  @override
  State<AiThinkingOverlay> createState() => _AiThinkingOverlayState();
}

class _AiThinkingOverlayState extends State<AiThinkingOverlay>
    with TickerProviderStateMixin {
  late final AnimationController _fadeController;
  late final AnimationController _pulseController;
  late final AnimationController _dotController;
  late final AnimationController _rotateController;

  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _pulseAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();

    // Fade + scale in on mount
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    )..forward();

    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );

    _scaleAnim = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeOutBack),
    );

    // Subtle pulse glow on the card
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);

    _pulseAnim = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Dot animation controller (3 dots cycling)
    _dotController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();

    // Spinner rotation
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _rotateAnim = Tween<double>(begin: 0.0, end: 2 * math.pi).animate(
      CurvedAnimation(parent: _rotateController, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _pulseController.dispose();
    _dotController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fadeAnim,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        // Layered backdrop: deep black with subtle color tint
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.82),
              Colors.black.withValues(alpha: 0.72),
            ],
          ),
        ),
        child: Center(
          child: ScaleTransition(
            scale: _scaleAnim,
            child: _buildCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildCard() {
    return AnimatedBuilder(
      animation: _pulseAnim,
      builder: (context, child) {
        final glowOpacity = 0.12 + (_pulseAnim.value * 0.14);
        return Container(
          width: 220,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
          decoration: BoxDecoration(
            color: const Color(0xFF141414),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.color.withValues(alpha: 0.18),
              width: 1.2,
            ),
            boxShadow: [
              // Ambient glow that pulses
              BoxShadow(
                color: widget.color.withValues(alpha: glowOpacity),
                blurRadius: 36,
                spreadRadius: 4,
              ),
              // Base depth shadow
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.55),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSpinner(),
          const SizedBox(height: 24),
          _buildLabel(),
          const SizedBox(height: 14),
          _buildDots(),
        ],
      ),
    );
  }

  Widget _buildSpinner() {
    return AnimatedBuilder(
      animation: _rotateAnim,
      builder: (context, _) {
        return SizedBox(
          width: 48,
          height: 48,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer track ring
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: widget.color.withValues(alpha: 0.12),
                    width: 2.5,
                  ),
                ),
              ),
              // Rotating arc
              Transform.rotate(
                angle: _rotateAnim.value,
                child: CustomPaint(
                  size: const Size(48, 48),
                  painter: _ArcPainter(color: widget.color),
                ),
              ),
              // Center dot
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withValues(alpha: 0.85),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.5),
                      blurRadius: 6,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLabel() {
    return Text(
      "OPPONENT IS PLANNING",
      style: GoogleFonts.sairaStencilOne(
        color: Colors.white.withValues(alpha: 0.92),
        fontSize: 12,
        letterSpacing: 2.0,
        height: 1.3,
        decoration: TextDecoration.none,
      ),
      textAlign: TextAlign.center,
    );
  }

  Widget _buildDots() {
    return AnimatedBuilder(
      animation: _dotController,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            // Each dot activates in sequence across the 0–1 range
            final phase = ((_dotController.value - (i * 0.28)) % 1.0);
            final opacity = phase < 0.4
                ? (phase / 0.4).clamp(0.0, 1.0)
                : phase < 0.7
                    ? 1.0
                    : ((1.0 - phase) / 0.3).clamp(0.0, 1.0);
            final scale = 0.6 + (opacity * 0.4);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3.5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.color.withValues(alpha: opacity.clamp(0.2, 1.0)),
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

/// Draws a ~220° arc for the custom spinner
class _ArcPainter extends CustomPainter {
  final Color color;
  const _ArcPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(2, 2, size.width - 4, size.height - 4);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
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
  bool shouldRepaint(_ArcPainter old) => old.color != color;
}