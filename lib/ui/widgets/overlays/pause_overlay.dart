import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class PauseOverlay extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.85),
        child: Stack(
          children: [
            // Subtle hatch background across the whole overlay
            Positioned.fill(
              child: CustomPaint(
                painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.015)),
              ),
            ),
            Center(
              child: SingleChildScrollView(
                child: Container(
                  width: 420,
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _StonePanel(
                    accentColor: primaryColor,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _SectionLabel("SYSTEM SUSPENDED", color: primaryColor),
                        const SizedBox(height: 16),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            "BATTLE PAUSED",
                            textAlign: TextAlign.center,
                            style: GoogleFonts.sairaStencilOne(
                              fontSize: 34,
                              fontWeight: FontWeight.bold,
                              color: primaryColor,
                              letterSpacing: 4.0,
                              shadows: [
                                BoxShadow(
                                  color: primaryColor.withValues(alpha: 0.3),
                                  blurRadius: 12,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "THE TACTICAL GRID IS TEMPORARILY FROZEN",
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.3),
                            fontSize: 9,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 36),
                        _buildMenuButton(
                          label: "RESUME BATTLE",
                          icon: Icons.play_arrow_rounded,
                          onPressed: onResume,
                          color: primaryColor,
                        ),
                        const SizedBox(height: 14),
                        _buildMenuButton(
                          label: "SETTINGS",
                          icon: Icons.settings_outlined,
                          onPressed: onSettings,
                          color: Colors.white.withValues(alpha: 0.7),
                        ),
                        const SizedBox(height: 14),
                        _buildMenuButton(
                          label: "ABANDON BATTLE",
                          icon: Icons.close_rounded,
                          onPressed: onQuit,
                          color: Colors.redAccent,
                        ),
                      ],
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

  Widget _buildMenuButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
  }) {
    return _AnimatedPressButton(
      onTap: onPressed,
      accentColor: color,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35), width: 1.2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color.withValues(alpha: 0.8), size: 22),
            const SizedBox(width: 14),
            Text(
              label,
              style: GoogleFonts.sairaStencilOne(
                color: color.withValues(alpha: 0.9),
                fontSize: 16,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Shared Aesthetic Components (Ported from ProfileScreen pattern)
// ─────────────────────────────────────────────────────────────────────────────

class _HatchPainter extends CustomPainter {
  final Color color;
  const _HatchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const spacing = 22.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

class _StonePanel extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;

  const _StonePanel({
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final ornamentColor = accentColor.withValues(alpha: 0.5);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1510), Color(0xFF0F0D0A)],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.28), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: accentColor.withValues(alpha: 0.06), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.018))),
          ),
          ..._corners(ornamentColor),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  List<Widget> _corners(Color color) {
    const sz = 24.0;
    return [
      Positioned(
          top: 0,
          left: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi / 2),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: Image.asset('assets/icons/border-edge.png', color: color)))),
      Positioned(
          top: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: Image.asset('assets/icons/border-edge.png', color: color)))),
      Positioned(
          bottom: 0,
          left: 0,
          child: SizedBox(
              width: sz,
              height: sz,
              child: Image.asset('assets/icons/border-edge.png', color: color))),
      Positioned(
          bottom: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(-math.pi / 2),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: Image.asset('assets/icons/border-edge.png', color: color)))),
    ];
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 18, height: 1.5, color: color.withValues(alpha: 0.5)),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2.8)),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1.5, color: color.withValues(alpha: 0.5))),
      ],
    );
  }
}

class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;

  const _AnimatedPressButton({required this.child, required this.onTap, required this.accentColor});

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.96)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) { _ctrl.reverse(); widget.onTap(); },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
