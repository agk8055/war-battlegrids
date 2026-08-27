import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_assets.dart';
import '../../core/enums/connection_type.dart';
import '../../core/enums/game_mode.dart';
import '../../core/services/audio_service.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../providers/turn_provider.dart';
import 'game_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Decorative Painter – subtle diagonal hatch lines (parchment feel)
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
//  Stone Panel
// ─────────────────────────────────────────────────────────────────────────────
class _StonePanel extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;

  const _StonePanel({
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final ornamentColor = accentColor.withValues(alpha: 0.55);
    final r = BorderRadius.circular(16);
    return Container(
      decoration: BoxDecoration(
        borderRadius: r,
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF1C1610),
            Color(0xFF0D0B08),
          ],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.32), width: 1.4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.65),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 24,
            spreadRadius: 1,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: r,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(
                painter: _HatchPainter(
                  color: Colors.white.withValues(alpha: 0.02),
                ),
              ),
            ),
            ..._corners(ornamentColor),
            Padding(padding: padding, child: child),
          ],
        ),
      ),
    );
  }

  List<Widget> _corners(Color color) {
    const sz = 20.0;
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
            child: AppAssetImage(AppAssets.borderEdge, color: color),
          ),
        ),
      ),
      Positioned(
        top: 0,
        right: 0,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationZ(math.pi),
          child: SizedBox(
            width: sz,
            height: sz,
            child: AppAssetImage(AppAssets.borderEdge, color: color),
          ),
        ),
      ),
      Positioned(
        bottom: 0,
        left: 0,
        child: SizedBox(
          width: sz,
          height: sz,
          child: AppAssetImage(AppAssets.borderEdge, color: color),
        ),
      ),
      Positioned(
        bottom: 0,
        right: 0,
        child: Transform(
          alignment: Alignment.center,
          transform: Matrix4.rotationZ(-math.pi / 2),
          child: SizedBox(
            width: sz,
            height: sz,
            child: AppAssetImage(AppAssets.borderEdge, color: color),
          ),
        ),
      ),
    ];
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Label
// ─────────────────────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  final Widget? trailing;

  const _SectionLabel(this.text, {required this.color, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 14, height: 2, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1.5, color: color.withValues(alpha: 0.3))),
        if (trailing != null) ...[
          const SizedBox(width: 8),
          trailing!,
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Main Screen
// ─────────────────────────────────────────────────────────────────────────────
class MultiplayerSetupScreen extends ConsumerStatefulWidget {
  const MultiplayerSetupScreen({super.key});

  @override
  ConsumerState<MultiplayerSetupScreen> createState() =>
      _MultiplayerSetupScreenState();
}

class _MultiplayerSetupScreenState
    extends ConsumerState<MultiplayerSetupScreen>
    with TickerProviderStateMixin {
  late final TextEditingController _p1Controller;
  late final TextEditingController _p2Controller;
  late final TextEditingController _thresholdController;

  final List<String> _availableSigils = AppAssets.availableSymbols;

  final List<Color> _availableColors = const [
    Color(0xFF1E88E5), // Royal Blue
    Color(0xFFE53935), // Crimson Red
    Color(0xFF43A047), // Emerald Green
    Color(0xFFFB8C00), // Amber Flame
    Color(0xFF8E24AA), // Imperial Purple
    Color(0xFFFDD835), // Solar Gold
    Color(0xFF00ACC1), // Mystic Cyan
    Color(0xFFD81B60), // Rose Valkyrie
  ];

  late String _p1Symbol;
  late String _p2Symbol;
  late Color _p1Color;
  late Color _p2Color;
  int _thresholdValue = 30;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(gameSettingsProvider);

    _p1Controller = TextEditingController(
      text: settings.player1Name.isNotEmpty ? settings.player1Name : 'COMMANDER 1',
    );
    _p2Controller = TextEditingController(
      text: (settings.player2Name.isNotEmpty && settings.player2Name != 'AI')
          ? settings.player2Name
          : 'COMMANDER 2',
    );

    _p1Symbol = _availableSigils.contains(settings.player1Symbol)
        ? settings.player1Symbol
        : _availableSigils.first;

    _p2Symbol = _availableSigils.length > 1
        ? (_availableSigils[1] == _p1Symbol ? _availableSigils.last : _availableSigils[1])
        : AppAssets.tiger;

    _p1Color = _availableColors[0];
    _p2Color = _availableColors[1];

    _thresholdValue = 30;
    _thresholdController = TextEditingController(text: '$_thresholdValue');

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _pulseAnim = Tween<double>(begin: 0.92, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    Future.delayed(const Duration(milliseconds: 80), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    _thresholdController.dispose();
    _fadeController.dispose();
    _slideController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  void _playClickSound() {
    ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
  }

  String _getSigilTitle(String path) {
    final name = path.split('/').last.split('.').first;
    switch (name) {
      case 'fire':
        return 'Flame Sovereign';
      case 'tiger':
        return 'Fierce Vanguard';
      case 'flash':
        return 'Storm Striker';
      case 'hacker':
        return 'Shadow Strategist';
      case 'lion':
        return 'High Monarch';
      case 'wolf':
        return 'Pack Alpha';
      case 'bull':
        return 'Iron Juggernaut';
      case 'shuriken':
        return 'Silent Blade';
      default:
        return 'House Champion';
    }
  }

  void _swapCommanders() {
    _playClickSound();
    setState(() {
      final tempName = _p1Controller.text;
      _p1Controller.text = _p2Controller.text;
      _p2Controller.text = tempName;

      final tempSymbol = _p1Symbol;
      _p1Symbol = _p2Symbol;
      _p2Symbol = tempSymbol;

      final tempColor = _p1Color;
      _p1Color = _p2Color;
      _p2Color = tempColor;
    });
  }

  void _randomizeCommanders() {
    _playClickSound();
    final random = math.Random();
    final availableSigils = List<String>.from(_availableSigils)..shuffle(random);
    final availableColors = List<Color>.from(_availableColors)..shuffle(random);

    setState(() {
      _p1Symbol = availableSigils[0];
      _p2Symbol = availableSigils[1];
      _p1Color = availableColors[0];
      _p2Color = availableColors[1];
    });
  }

  void _setThreshold(int val) {
    _playClickSound();
    final clamped = val.clamp(10, 500);
    setState(() {
      _thresholdValue = clamped;
      _thresholdController.text = '$clamped';
    });
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Build
  // ───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF090704),
      body: Stack(
        children: [
          // Ambient dynamic background glow influenced by both commander colors
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-0.5, -0.6),
                  radius: 1.2,
                  colors: [
                    _p1Color.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0.5, 0.6),
                  radius: 1.2,
                  colors: [
                    _p2Color.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    _buildAppBar(primary),
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(14, 4, 14, 28),
                        child: Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 1000),
                            child: Column(
                              children: [
                                // ALWAYS SIDE BY SIDE CARDS ROW
                                _buildSideBySideCardsRow(primary),
                                const SizedBox(height: 18),
                                _buildSiegeSettingsCard(primary),
                                const SizedBox(height: 24),
                                _buildStartBattleSection(primary),
                                const SizedBox(height: 12),
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

  // ───────────────────────────────────────────────────────────────────────────
  //  App Bar
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildAppBar(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          _AnimatedPressButton(
            onTap: () {
              _playClickSound();
              Navigator.pop(context);
            },
            accentColor: primary,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primary.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Icon(Icons.chevron_left, color: primary, size: 22),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'WAR COUNCIL',
                  style: GoogleFonts.sairaStencilOne(
                    color: primary,
                    fontSize: 19,
                    letterSpacing: 2.5,
                  ),
                ),
                Text(
                  'Local Duel · Pass & Play Setup',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.45),
                    fontSize: 10.5,
                    letterSpacing: 1.1,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          // Randomize button
          _AnimatedPressButton(
            onTap: _randomizeCommanders,
            accentColor: primary,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: primary.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.casino_outlined, color: primary, size: 15),
                  const SizedBox(width: 5),
                  Text(
                    'RANDOMIZE',
                    style: TextStyle(
                      color: primary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Always Side by Side Player Cards Row
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSideBySideCardsRow(Color primary) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 600;
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left Card (Player 1)
            Expanded(
              child: _buildCommanderCard(
                playerNum: 1,
                tag: 'COMMANDER I',
                controller: _p1Controller,
                playerColor: _p1Color,
                currentSigil: _p1Symbol,
                unavailableSigil: _p2Symbol,
                unavailableColor: _p2Color,
                isCompact: isCompact,
                onSigilSelected: (s) {
                  _playClickSound();
                  setState(() => _p1Symbol = s);
                },
                onColorSelected: (c) {
                  _playClickSound();
                  setState(() => _p1Color = c);
                },
                primaryColor: primary,
              ),
            ),
            const SizedBox(width: 8),

            // Center Swap / VS Badge
            _buildCenterVersusPill(primary, isCompact),

            const SizedBox(width: 8),

            // Right Card (Player 2)
            Expanded(
              child: _buildCommanderCard(
                playerNum: 2,
                tag: 'COMMANDER II',
                controller: _p2Controller,
                playerColor: _p2Color,
                currentSigil: _p2Symbol,
                unavailableSigil: _p1Symbol,
                unavailableColor: _p1Color,
                isCompact: isCompact,
                onSigilSelected: (s) {
                  _playClickSound();
                  setState(() => _p2Symbol = s);
                },
                onColorSelected: (c) {
                  _playClickSound();
                  setState(() => _p2Color = c);
                },
                primaryColor: primary,
              ),
            ),
          ],
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Center VS Pill
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCenterVersusPill(Color primary, bool isCompact) {
    return Padding(
      padding: EdgeInsets.only(top: isCompact ? 100 : 120),
      child: _AnimatedPressButton(
        onTap: _swapCommanders,
        accentColor: primary,
        child: Tooltip(
          message: 'Swap Commanders',
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 6 : 10,
              vertical: isCompact ? 12 : 16,
            ),
            decoration: BoxDecoration(
              color: const Color(0xFF18130E),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: primary.withValues(alpha: 0.4),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: primary.withValues(alpha: 0.25),
                  blurRadius: 12,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_horiz_rounded,
                  color: primary.withValues(alpha: 0.9),
                  size: isCompact ? 16 : 20,
                ),
                const SizedBox(height: 4),
                Text(
                  'VS',
                  style: GoogleFonts.sairaStencilOne(
                    color: primary,
                    fontSize: isCompact ? 11 : 13,
                    letterSpacing: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Commander Card Component
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCommanderCard({
    required int playerNum,
    required String tag,
    required TextEditingController controller,
    required Color playerColor,
    required String currentSigil,
    required String unavailableSigil,
    required Color unavailableColor,
    required bool isCompact,
    required Function(String) onSigilSelected,
    required Function(Color) onColorSelected,
    required Color primaryColor,
  }) {
    final titleLore = _getSigilTitle(currentSigil);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOutCubic,
      child: _StonePanel(
        accentColor: playerColor,
        padding: EdgeInsets.all(isCompact ? 10 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Top Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                  decoration: BoxDecoration(
                    color: playerColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(5),
                    border: Border.all(
                      color: playerColor.withValues(alpha: 0.4),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        playerNum == 1 ? Icons.shield : Icons.shield_outlined,
                        color: playerColor,
                        size: 11,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isCompact ? 'P$playerNum' : tag,
                        style: TextStyle(
                          color: playerColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: Text(
                    titleLore.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.45),
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Hero Sigil Crest (Centered & Prominent)
            _buildHeroCrest(
              sigil: currentSigil,
              playerColor: playerColor,
              isCompact: isCompact,
              onTap: () => _showSigilPickerSheet(
                currentSigil: currentSigil,
                unavailableSigil: unavailableSigil,
                onSigilSelected: onSigilSelected,
                accentColor: playerColor,
              ),
            ),

            const SizedBox(height: 12),

            // Commander Name Field
            Text(
              'COMMANDER NAME',
              style: TextStyle(
                color: playerColor.withValues(alpha: 0.8),
                fontSize: 8.5,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 4),
            _buildCommanderTextField(controller, playerColor, isCompact),

            const SizedBox(height: 12),
            Container(height: 1, color: playerColor.withValues(alpha: 0.15)),
            const SizedBox(height: 10),

            // Sigil Row Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SIGIL',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 8.5,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
                GestureDetector(
                  onTap: () => _showSigilPickerSheet(
                    currentSigil: currentSigil,
                    unavailableSigil: unavailableSigil,
                    onSigilSelected: onSigilSelected,
                    accentColor: playerColor,
                  ),
                  child: Text(
                    'ALL',
                    style: TextStyle(
                      color: playerColor,
                      fontSize: 8.5,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _buildSigilQuickBar(
              currentSigil: currentSigil,
              unavailableSigil: unavailableSigil,
              onSigilSelected: onSigilSelected,
              accentColor: playerColor,
              isCompact: isCompact,
            ),

            const SizedBox(height: 12),

            // Banner Color Row Header
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'COLOUR',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontSize: 8.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 6),
            _buildColorQuickBar(
              currentColor: playerColor,
              unavailableColor: unavailableColor,
              onColorSelected: onColorSelected,
              isCompact: isCompact,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Hero Crest Component
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildHeroCrest({
    required String sigil,
    required Color playerColor,
    required bool isCompact,
    required VoidCallback onTap,
  }) {
    final crestSize = isCompact ? 56.0 : 70.0;
    return GestureDetector(
      onTap: () {
        _playClickSound();
        onTap();
      },
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Animated pulsing halo
          AnimatedBuilder(
            animation: _pulseAnim,
            builder: (context, child) {
              return Container(
                width: (crestSize + 8) * _pulseAnim.value,
                height: (crestSize + 8) * _pulseAnim.value,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: playerColor.withValues(alpha: 0.15 * _pulseAnim.value),
                    width: 1.2,
                  ),
                ),
              );
            },
          ),
          // Glow background
          Container(
            width: crestSize + 4,
            height: crestSize + 4,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: playerColor.withValues(alpha: 0.35),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          // Main circle emblem
          Container(
            width: crestSize,
            height: crestSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  playerColor.withValues(alpha: 0.28),
                  const Color(0xFF14100C),
                ],
              ),
              border: Border.all(
                color: playerColor.withValues(alpha: 0.8),
                width: 1.8,
              ),
            ),
            padding: EdgeInsets.all(isCompact ? 9 : 12),
            child: AppAssetImage(
              sigil,
              color: playerColor,
            ),
          ),
          // Tap hint badge
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: isCompact ? 16 : 18,
              height: isCompact ? 16 : 18,
              decoration: BoxDecoration(
                color: playerColor,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF0D0B08), width: 1.2),
              ),
              child: const Icon(Icons.touch_app, size: 9, color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Commander Text Field
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCommanderTextField(
    TextEditingController controller,
    Color accentColor,
    bool isCompact,
  ) {
    return TextField(
      controller: controller,
      maxLength: 14,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      style: GoogleFonts.sairaStencilOne(
        color: Colors.white,
        fontSize: isCompact ? 13 : 15,
        letterSpacing: 1.2,
      ),
      decoration: InputDecoration(
        isDense: true,
        counterText: '',
        contentPadding: EdgeInsets.symmetric(
          horizontal: 6,
          vertical: isCompact ? 6 : 9,
        ),
        filled: true,
        fillColor: accentColor.withValues(alpha: 0.08),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: accentColor.withValues(alpha: 0.35),
            width: 1.2,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(
            color: accentColor,
            width: 1.8,
          ),
        ),
      ),
      onChanged: (val) => setState(() {}),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Sigil Quick Bar
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSigilQuickBar({
    required String currentSigil,
    required String unavailableSigil,
    required Function(String) onSigilSelected,
    required Color accentColor,
    required bool isCompact,
  }) {
    final barHeight = isCompact ? 38.0 : 44.0;
    final itemWidth = isCompact ? 36.0 : 42.0;

    return SizedBox(
      height: barHeight,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableSigils.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final sigil = _availableSigils[index];
          final isSelected = sigil == currentSigil;
          final isUnavailable = sigil == unavailableSigil;

          return GestureDetector(
            onTap: isUnavailable ? null : () => onSigilSelected(sigil),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              width: itemWidth,
              margin: const EdgeInsets.only(right: 6),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.35),
                          accentColor.withValues(alpha: 0.12),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected
                      ? accentColor
                      : isUnavailable
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.12),
                  width: isSelected ? 1.6 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.35),
                          blurRadius: 8,
                          spreadRadius: 1,
                        ),
                      ]
                    : [],
              ),
              padding: EdgeInsets.all(isCompact ? 6 : 7),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 180),
                opacity: isUnavailable ? 0.18 : 1.0,
                child: AppAssetImage(
                  sigil,
                  color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.6),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Color Quick Bar
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildColorQuickBar({
    required Color currentColor,
    required Color unavailableColor,
    required Function(Color) onColorSelected,
    required bool isCompact,
  }) {
    final sz = isCompact ? 22.0 : 26.0;
    return SizedBox(
      height: sz + 4,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableColors.length,
        physics: const BouncingScrollPhysics(),
        itemBuilder: (context, index) {
          final color = _availableColors[index];
          final isSelected = color.toARGB32() == currentColor.toARGB32();
          final isUnavailable = color.toARGB32() == unavailableColor.toARGB32();

          return GestureDetector(
            onTap: isUnavailable ? null : () => onColorSelected(color),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 180),
              opacity: isUnavailable ? 0.18 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOutCubic,
                width: isSelected ? sz + 4 : sz,
                height: isSelected ? sz + 4 : sz,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.2),
                    width: isSelected ? 2.2 : 1,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.7),
                            blurRadius: 10,
                            spreadRadius: 1.5,
                          ),
                        ]
                      : [],
                ),
                child: isSelected
                    ? const Icon(Icons.check, size: 12, color: Colors.white)
                    : null,
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Siege Conditions / Glory Threshold Card (Direct Input)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSiegeSettingsCard(Color primary) {
    return _StonePanel(
      accentColor: primary,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel(
            'SIEGE CONDITIONS',
            color: primary,
            trailing: Icon(Icons.castle_outlined, color: primary.withValues(alpha: 0.7), size: 15),
          ),
          const SizedBox(height: 10),
          Text(
            'Glory points required to breach enemy capital defenses and launch siege attack.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.5),
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 14),

          // Direct Numeric Input & Steppers
          Row(
            children: [
              Text(
                'ATTACK THRESHOLD:',
                style: TextStyle(
                  color: primary.withValues(alpha: 0.85),
                  fontSize: 9.5,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const Spacer(),
              _buildStepperButton(
                icon: Icons.remove,
                onTap: () => _setThreshold(_thresholdValue - 5),
                primary: primary,
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 80,
                child: TextField(
                  controller: _thresholdController,
                  keyboardType: TextInputType.number,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.sairaStencilOne(
                    color: Colors.white,
                    fontSize: 16,
                  ),
                  decoration: InputDecoration(
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 8),
                    filled: true,
                    fillColor: primary.withValues(alpha: 0.08),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primary.withValues(alpha: 0.35)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: primary, width: 1.5),
                    ),
                  ),
                  onChanged: (val) {
                    final n = int.tryParse(val.trim());
                    if (n != null) {
                      setState(() => _thresholdValue = n.clamp(1, 999));
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              _buildStepperButton(
                icon: Icons.add,
                onTap: () => _setThreshold(_thresholdValue + 5),
                primary: primary,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStepperButton({
    required IconData icon,
    required VoidCallback onTap,
    required Color primary,
  }) {
    return _AnimatedPressButton(
      onTap: onTap,
      accentColor: primary,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: primary.withValues(alpha: 0.35), width: 1),
        ),
        child: Icon(icon, color: primary, size: 15),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Start Battle Section
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildStartBattleSection(Color primary) {
    return Center(
      child: _AnimatedPressButton(
        onTap: _onStartBattle,
        accentColor: primary,
        child: Container(
          width: 300,
          height: 58,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.95),
                primary.withValues(alpha: 0.7),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: primary.withValues(alpha: 0.8),
              width: 1.4,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.4),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 5),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: CustomPaint(
                    painter: _HatchPainter(
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.sports_kabaddi,
                    color: Colors.black87,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'MARCH TO BATTLE',
                    style: GoogleFonts.sairaStencilOne(
                      color: Colors.black,
                      fontSize: 15,
                      letterSpacing: 2.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Modal Sigil Picker Sheet
  // ───────────────────────────────────────────────────────────────────────────
  void _showSigilPickerSheet({
    required String currentSigil,
    required String unavailableSigil,
    required Function(String) onSigilSelected,
    required Color accentColor,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
          decoration: BoxDecoration(
            color: const Color(0xFF14100C),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
            border: Border.all(color: accentColor.withValues(alpha: 0.4), width: 1.4),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.15),
                blurRadius: 28,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'SELECT HOUSE SIGIL',
                style: GoogleFonts.sairaStencilOne(
                  color: accentColor,
                  fontSize: 16,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Each sigil represents an ancient warlord lineage',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 10.5,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 18),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: _availableSigils.length,
                itemBuilder: (context, index) {
                  final sigil = _availableSigils[index];
                  final isSelected = sigil == currentSigil;
                  final isUnavailable = sigil == unavailableSigil;

                  return GestureDetector(
                    onTap: isUnavailable
                        ? null
                        : () {
                            onSigilSelected(sigil);
                            Navigator.pop(ctx);
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                                colors: [
                                  accentColor.withValues(alpha: 0.35),
                                  accentColor.withValues(alpha: 0.12),
                                ],
                              )
                            : null,
                        color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected
                              ? accentColor
                              : isUnavailable
                                  ? Colors.transparent
                                  : Colors.white.withValues(alpha: 0.12),
                          width: isSelected ? 1.8 : 1,
                        ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: accentColor.withValues(alpha: 0.35),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ]
                            : [],
                      ),
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: isUnavailable ? 0.18 : 1.0,
                        child: AppAssetImage(
                          sigil,
                          color: isSelected ? accentColor : Colors.white.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Game Start Logic
  // ───────────────────────────────────────────────────────────────────────────
  void _onStartBattle() {
    _playClickSound();

    final notifier = ref.read(gameSettingsProvider.notifier);
    notifier.setMode(GameMode.multiplayer);
    notifier.setPlayerNames(
      _p1Controller.text.trim().isEmpty ? 'COMMANDER 1' : _p1Controller.text.trim().toUpperCase(),
      _p2Controller.text.trim().isEmpty ? 'COMMANDER 2' : _p2Controller.text.trim().toUpperCase(),
    );
    notifier.setPlayerSymbols(_p1Symbol, _p2Symbol);
    notifier.setPlayerColors(_p1Color.toARGB32(), _p2Color.toARGB32());
    final parsedThreshold = int.tryParse(_thresholdController.text.trim()) ?? _thresholdValue;
    notifier.setKingdomAttackThreshold(parsedThreshold > 0 ? parsedThreshold : 30);

    ref.read(connectionTypeProvider.notifier).setConnectionType(ConnectionType.local);
    ref.read(simulationProvider.notifier).reset();

    Navigator.push(
      context,
      PageRouteBuilder(
        settings: const RouteSettings(name: '/game'),
        pageBuilder: (_, animation, __) => const GameScreen(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeIn),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Press-scale button wrapper (tactile feedback)
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;
  final Color accentColor;

  const _AnimatedPressButton({
    required this.child,
    required this.onTap,
    required this.accentColor,
  });

  @override
  State<_AnimatedPressButton> createState() => _AnimatedPressButtonState();
}

class _AnimatedPressButtonState extends State<_AnimatedPressButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
      lowerBound: 0,
      upperBound: 1,
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(scale: _scaleAnim, child: widget.child),
    );
  }
}