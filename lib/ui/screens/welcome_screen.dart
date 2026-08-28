import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_assets.dart';
import '../../providers/game_settings_provider.dart';
import 'main_menu_screen.dart';
import 'tutorial_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Painters (shared aesthetic)
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
                  child: AppAssetImage(AppAssets.borderEdge, color: color)))),
      Positioned(
          top: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: AppAssetImage(AppAssets.borderEdge, color: color)))),
      Positioned(
          bottom: 0,
          left: 0,
          child: SizedBox(
              width: sz,
              height: sz,
              child: AppAssetImage(AppAssets.borderEdge, color: color))),
      Positioned(
          bottom: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(-math.pi / 2),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: AppAssetImage(AppAssets.borderEdge, color: color)))),
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

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController();
  String _selectedSymbol = AppAssets.fire;
  final List<String> _symbols = AppAssets.availableSymbols;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  Future<void> _saveAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter your Kingdom name'),
          backgroundColor: Colors.orangeAccent,
        ),
      );
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('kingdom_name', name);
    await prefs.setString('kingdom_symbol', _selectedSymbol);
    await prefs.setBool('is_first_run', false);

    ref.read(gameSettingsProvider.notifier).setPlayerNames(name, 'AI');
    ref.read(gameSettingsProvider.notifier).setPlayerSymbols(_selectedSymbol, AppAssets.eagle);

    if (!mounted) return;

    final bool hasCompletedTutorial = prefs.getBool('has_completed_tutorial') ?? false;
    final Widget nextScreen = hasCompletedTutorial
        ? const GameHomeScreen()
        : const TutorialScreen();

    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  String _getSigilDescription(String path) {
    final name = path.split('/').last.split('.').first;
    switch (name) {
      case 'fire':
        return 'UNYIELDING PASSION & DESTRUCTION';
      case 'tiger':
        return 'FIERCE INDEPENDENCE & RAW STRENGTH';
      case 'flash':
        return 'LIGHTNING SPEED & OVERWHELMING ENERGY';
      case 'hacker':
        return 'SUPERIOR INTELLECT & TACTICAL SUBVERSION';
      case 'lion':
        return 'NOBLE LEADERSHIP & COURAGEOUS HEART';
      case 'wolf':
        return 'SHARP INSTINCTS & THE STRENGTH OF THE PACK';
      case 'bull':
        return 'STUBBORN RESILIENCE & UNSTOPPABLE FORCE';
      case 'shuriken':
        return 'SILENT LETHALITY & PERFECT PRECISION';
      default:
        return 'YOUR CHOSEN PATH TO GLORY';
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  radius: 1.1,
                  colors: [primary.withValues(alpha: 0.1), Colors.transparent],
                ),
              ),
            ),
          ),
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
                  child: Column(
                    children: [
                      Text(
                        'WELCOME, COMMANDER',
                        style: GoogleFonts.sairaStencilOne(
                          color: primary,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4.0,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ESTABLISH THY ROYAL DOMINION',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.35),
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 3.5,
                        ),
                      ),
                      const SizedBox(height: 60),

                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Column: Name and Button
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                _StonePanel(
                                  accentColor: primary,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionLabel('KINGDOM NAME', color: primary),
                                      const SizedBox(height: 24),
                                      TextField(
                                        controller: _nameController,
                                        textCapitalization: TextCapitalization.characters,
                                        maxLength: 15,
                                        style: GoogleFonts.sairaStencilOne(
                                          color: Colors.white,
                                          fontSize: 18,
                                          letterSpacing: 1.5,
                                        ),
                                        decoration: InputDecoration(
                                          isDense: true,
                                          contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                                          hintText: 'ENTER NAME...',
                                          hintStyle: TextStyle(
                                            color: Colors.white.withValues(alpha: 0.15),
                                            fontSize: 14,
                                            letterSpacing: 2,
                                          ),
                                          counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2)),
                                          filled: true,
                                          fillColor: primary.withValues(alpha: 0.03),
                                          enabledBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: primary.withValues(alpha: 0.3)),
                                          ),
                                          focusedBorder: UnderlineInputBorder(
                                            borderSide: BorderSide(color: primary, width: 2),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 32),
                                _AnimatedPressButton(
                                  onTap: _saveAndContinue,
                                  accentColor: primary,
                                  child: Container(
                                    width: double.infinity,
                                    height: 56,
                                    decoration: BoxDecoration(
                                      gradient: LinearGradient(
                                        colors: [primary.withValues(alpha: 0.9), primary.withValues(alpha: 0.6)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: primary.withValues(alpha: 0.4),
                                          blurRadius: 20,
                                          offset: const Offset(0, 8),
                                        ),
                                      ],
                                    ),
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Positioned.fill(
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(12),
                                            child: CustomPaint(
                                              painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.08)),
                                            ),
                                          ),
                                        ),
                                        Text(
                                          'BEGIN THY REIGN',
                                          style: GoogleFonts.sairaStencilOne(
                                            color: Colors.black,
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 2.5,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 40),
                          // Right Column: Sigil Grid
                          Expanded(
                            flex: 1,
                            child: Column(
                              children: [
                                _StonePanel(
                                  accentColor: primary,
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _SectionLabel('CHOOSE THY HOUSE SIGIL', color: primary),
                                      const SizedBox(height: 24),
                                      Wrap(
                                        spacing: 12,
                                        runSpacing: 12,
                                        alignment: WrapAlignment.center,
                                        children: _symbols.map((symbol) {
                                          final isSelected = _selectedSymbol == symbol;
                                          return _AnimatedPressButton(
                                            onTap: () => setState(() => _selectedSymbol = symbol),
                                            accentColor: primary,
                                            child: AnimatedContainer(
                                              duration: const Duration(milliseconds: 250),
                                              width: 54,
                                              height: 54,
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                gradient: isSelected
                                                    ? LinearGradient(colors: [
                                                        primary.withValues(alpha: 0.25),
                                                        primary.withValues(alpha: 0.1),
                                                      ])
                                                    : null,
                                                color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(
                                                  color: isSelected ? primary : Colors.white.withValues(alpha: 0.1),
                                                  width: isSelected ? 1.5 : 1,
                                                ),
                                                boxShadow: isSelected
                                                    ? [BoxShadow(color: primary.withValues(alpha: 0.3), blurRadius: 10)]
                                                    : [],
                                              ),
                                              child: AppAssetImage(
                                                symbol,
                                                color: isSelected ? null : Colors.white.withValues(alpha: 0.4),
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      const SizedBox(height: 20),
                                      Center(
                                        child: Text(
                                          _getSigilDescription(_selectedSymbol),
                                          textAlign: TextAlign.center,
                                          style: TextStyle(
                                            color: primary.withValues(alpha: 0.6),
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
                                            fontStyle: FontStyle.italic,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
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
//  Press-scale button wrapper
// ─────────────────────────────────────────────────────────────────────────────
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
