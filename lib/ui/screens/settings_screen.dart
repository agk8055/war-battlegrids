import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/game_settings_provider.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Painters (shared aesthetic from profile screen)
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

class _CornerOrnamentPainter extends CustomPainter {
  final Color color;
  const _CornerOrnamentPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final s = size.width;
    canvas.drawLine(Offset(0, s * 0.4), Offset(0, 0), paint);
    canvas.drawLine(Offset(0, 0), Offset(s * 0.4, 0), paint);
    canvas.drawLine(Offset(0, s * 0.18), Offset(s * 0.18, 0.18 * s), paint);
    canvas.drawCircle(Offset(s * 0.06, s * 0.06), 1.5, paint..style = PaintingStyle.fill);
  }

  @override
  bool shouldRepaint(_CornerOrnamentPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  _StonePanel
// ─────────────────────────────────────────────────────────────────────────────
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
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: accentColor.withValues(alpha: 0.28), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: accentColor.withValues(alpha: 0.06), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.018))),
            ),
            ..._corners(ornamentColor),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners(Color color) {
    const sz = 28.0;
    return [
      Positioned(top: 6, left: 6,
        child: SizedBox(width: sz, height: sz, child: CustomPaint(painter: _CornerOrnamentPainter(color: color)))),
      Positioned(top: 6, right: 6,
        child: Transform(alignment: Alignment.center, transform: Matrix4.rotationY(math.pi),
          child: SizedBox(width: sz, height: sz, child: CustomPaint(painter: _CornerOrnamentPainter(color: color))))),
      Positioned(bottom: 6, left: 6,
        child: Transform(alignment: Alignment.center, transform: Matrix4.rotationX(math.pi),
          child: SizedBox(width: sz, height: sz, child: CustomPaint(painter: _CornerOrnamentPainter(color: color))))),
      Positioned(bottom: 6, right: 6,
        child: Transform(alignment: Alignment.center, transform: Matrix4.rotationZ(math.pi),
          child: SizedBox(width: sz, height: sz, child: CustomPaint(painter: _CornerOrnamentPainter(color: color))))),
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

// ─────────────────────────────────────────────────────────────────────────────
//  Settings Screen
// ─────────────────────────────────────────────────────────────────────────────
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 580));

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameSettingsProvider);
    final settingsNotifier = ref.read(gameSettingsProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0804),
      body: Stack(
        children: [
          // Ambient radial glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 0.9,
                  colors: [primary.withValues(alpha: 0.07), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      child: _buildTopBar(primary),
                    ),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Column(
                              children: [
                                _StonePanel(
                                  accentColor: primary,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionLabel('AUDIO SANCTUM', color: primary),
                                      const SizedBox(height: 20),
                                      _buildSettingTile(
                                        context,
                                        title: 'MUSIC',
                                        subtitle: 'Background soundtrack',
                                        trailing: Switch(
                                          value: settings.musicEnabled,
                                          onChanged: (value) => settingsNotifier.setMusicEnabled(value),
                                          activeTrackColor: primary.withValues(alpha: 0.5),
                                          activeThumbColor: primary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildVolumeSlider(
                                        context,
                                        title: 'MUSIC VOLUME',
                                        value: settings.musicVolume,
                                        enabled: settings.musicEnabled,
                                        onChanged: (v) => settingsNotifier.setMusicVolume(v),
                                        primary: primary,
                                      ),
                                      const SizedBox(height: 24),
                                      Divider(color: primary.withValues(alpha: 0.1), height: 1),
                                      const SizedBox(height: 24),
                                      _buildSettingTile(
                                        context,
                                        title: 'SFX',
                                        subtitle: 'Sound effects',
                                        trailing: Switch(
                                          value: settings.sfxEnabled,
                                          onChanged: (value) => settingsNotifier.setSfxEnabled(value),
                                          activeTrackColor: primary.withValues(alpha: 0.5),
                                          activeThumbColor: primary,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      _buildVolumeSlider(
                                        context,
                                        title: 'SFX VOLUME',
                                        value: settings.sfxVolume,
                                        enabled: settings.sfxEnabled,
                                        onChanged: (v) => settingsNotifier.setSfxVolume(v),
                                        primary: primary,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 48),
                                _buildFooter(primary),
                                const SizedBox(height: 40),
                              ],
                            ),
                          ),
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
    );
  }

  Widget _buildTopBar(Color primary) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
            ),
            child: Icon(Icons.chevron_left, color: primary, size: 22),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'COMMAND CENTER',
                style: TextStyle(
                  color: primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3.5,
                ),
              ),
              Text(
                "Configure thy realm's ambiance",
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: primary.withValues(alpha: 0.25), width: 1),
          ),
          child: Icon(Icons.tune_rounded, color: primary.withValues(alpha: 0.7), size: 18),
        ),
      ],
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildVolumeSlider(
    BuildContext context, {
    required String title,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
    required Color primary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.3),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: enabled ? primary : Colors.white.withValues(alpha: 0.2),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14),
            activeTrackColor: primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.05),
            thumbColor: primary,
            overlayColor: primary.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(Color primary) {
    return Column(
      children: [
        Icon(
          Icons.settings_suggest_rounded,
          size: 40,
          color: primary.withValues(alpha: 0.15),
        ),
        const SizedBox(height: 16),
        Text(
          'ANCIENT PROTOCOL v1.0.4',
          style: TextStyle(
            color: primary.withValues(alpha: 0.3),
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.5,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ERECTED IN THE YEAR OF THE WOLF',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.1),
            fontSize: 8,
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}