import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_assets.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
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
//  Reusable Widgets
// ─────────────────────────────────────────────────────────────────────────────

/// A stone-panel card with corner ornaments and optional title banner.
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
    final ornamentColor = accentColor.withValues(alpha: 0.55);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF1A1510),
            const Color(0xFF0F0D0A),
          ],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.28), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.55),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: accentColor.withValues(alpha: 0.06),
            blurRadius: 24,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Parchment hatch texture
          Positioned.fill(
            child: CustomPaint(
              painter: _HatchPainter(
                color: Colors.white.withValues(alpha: 0.018),
              ),
            ),
          ),
          // Corner ornaments
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

/// Section label styled like a carved stone inscription.
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
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.8,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: Container(height: 1.5, color: color.withValues(alpha: 0.5))),
      ],
    );
  }
}

/// Divider styled as a decorative horizontal rule.
class _RoyalDivider extends StatelessWidget {
  final Color color;
  const _RoyalDivider({required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.15))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.brightness_1, color: color.withValues(alpha: 0.3), size: 5),
        ),
        Expanded(child: Container(height: 1, color: color.withValues(alpha: 0.15))),
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
  final TextEditingController _p1Controller =
      TextEditingController(text: 'PLAYER 1');
  final TextEditingController _p2Controller =
      TextEditingController(text: 'PLAYER 2');
  final TextEditingController _thresholdController =
      TextEditingController(text: '10');

  final List<String> _availableSigils = AppAssets.availableSymbols;

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.yellow,
    Colors.cyan,
    Colors.pink,
  ];

  late String _p1Symbol;
  late String _p2Symbol;
  late Color _p1Color;
  late Color _p2Color;

  // Animation controllers
  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _p1Symbol = _availableSigils.isNotEmpty ? _availableSigils[0] : AppAssets.fire;
    _p2Symbol = _availableSigils.length > 1 ? _availableSigils[1] : AppAssets.eagle;
    _p1Color = _availableColors[0];
    _p2Color = _availableColors[1];

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    // Stagger intro animations
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
    super.dispose();
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Build
  // ───────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0A0804),
      body: Stack(
        children: [
          // Ambient background gradient
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.6),
                  radius: 1.1,
                  colors: [
                    primary.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: CustomScrollView(
                  slivers: [
                    _buildAppBar(primary),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                      sliver: SliverList(
                        delegate: SliverChildListDelegate([
                          _buildCommanderPanel(
                            playerLabel: 'COMMANDER I',
                            controller: _p1Controller,
                            playerColor: _p1Color,
                            currentSigil: _p1Symbol,
                            unavailableSigil: _p2Symbol,
                            unavailableColor: _p2Color,
                            onSigilSelected: (s) =>
                                setState(() => _p1Symbol = s),
                            onColorSelected: (c) =>
                                setState(() => _p1Color = c),
                            primaryColor: primary,
                          ),
                          const SizedBox(height: 16),
                          _buildVersusRow(primary),
                          const SizedBox(height: 16),
                          _buildCommanderPanel(
                            playerLabel: 'COMMANDER II',
                            controller: _p2Controller,
                            playerColor: _p2Color,
                            currentSigil: _p2Symbol,
                            unavailableSigil: _p1Symbol,
                            unavailableColor: _p1Color,
                            onSigilSelected: (s) =>
                                setState(() => _p2Symbol = s),
                            onColorSelected: (c) =>
                                setState(() => _p2Color = c),
                            primaryColor: primary,
                          ),
                          const SizedBox(height: 24),
                          _buildThresholdPanel(primary),
                          const SizedBox(height: 40),
                          _buildStartButton(primary),
                        ]),
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
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
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
                    'WAR COUNCIL',
                    style: TextStyle(
                      color: primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 3.5,
                    ),
                  ),
                  Text(
                    'Forge thy alliance · Choose thy sigil',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.38),
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            // Decorative crossed-swords icon area
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primary.withValues(alpha: 0.25),
                  width: 1,
                ),
              ),
              child: Icon(Icons.shield, color: primary.withValues(alpha: 0.7), size: 20),
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Commander Panel (Player card)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildCommanderPanel({
    required String playerLabel,
    required TextEditingController controller,
    required Color playerColor,
    required String currentSigil,
    required String unavailableSigil,
    required Color unavailableColor,
    required Function(String) onSigilSelected,
    required Function(Color) onColorSelected,
    required Color primaryColor,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      decoration: BoxDecoration(
        boxShadow: [
          BoxShadow(
            color: playerColor.withValues(alpha: 0.12),
            blurRadius: 30,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: _StonePanel(
        accentColor: playerColor,
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(playerLabel, color: playerColor),
            const SizedBox(height: 18),

            // Name Field
            _buildTextField(controller, 'COMMANDER NAME', playerColor),
            const SizedBox(height: 22),

            _RoyalDivider(color: playerColor),
            const SizedBox(height: 18),

            // Sigil label
            Text(
              'HOUSE SIGIL',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildSigilSelector(
              currentSigil: currentSigil,
              unavailableSigil: unavailableSigil,
              onSigilSelected: onSigilSelected,
              accentColor: playerColor,
            ),
            const SizedBox(height: 18),

            // Banner color
            Text(
              'BANNER COLOUR',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.2,
              ),
            ),
            const SizedBox(height: 12),
            _buildColorSelector(
              currentColor: playerColor,
              unavailableColor: unavailableColor,
              onColorSelected: onColorSelected,
            ),
          ],
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  VS Divider Row
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildVersusRow(Color primary) {
    return Row(
      children: [
        Expanded(child: Container(height: 1, color: _p1Color.withValues(alpha: 0.3))),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF1A1510),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
            boxShadow: [
              BoxShadow(color: primary.withValues(alpha: 0.15), blurRadius: 12),
            ],
          ),
          child: Text(
            'VS',
            style: TextStyle(
              color: primary,
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 3,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(child: Container(height: 1, color: _p2Color.withValues(alpha: 0.3))),
      ],
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Threshold Panel
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildThresholdPanel(Color primary) {
    return _StonePanel(
      accentColor: primary,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('SIEGE CONDITIONS', color: primary),
          const SizedBox(height: 14),
          Text(
            'Glory required to breach the capital gates and launch a direct assault upon the enemy kingdom.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 12,
              height: 1.6,
              letterSpacing: 0.4,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Icon(Icons.castle_outlined,
                  color: primary.withValues(alpha: 0.6), size: 18),
              const SizedBox(width: 10),
              Text(
                'KINGDOM ATTACK THRESHOLD',
                style: TextStyle(
                  color: primary.withValues(alpha: 0.8),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.8,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 160,
            child: _buildTextField(
              _thresholdController,
              'GLORY POINTS',
              primary,
              isNumeric: true,
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Start Battle Button
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildStartButton(Color primary) {
    return Center(
      child: _AnimatedPressButton(
        onTap: _onStartBattle,
        accentColor: primary,
        child: Container(
          width: 280,
          height: 62,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                primary.withValues(alpha: 0.85),
                primary.withValues(alpha: 0.6),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: primary.withValues(alpha: 0.6),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.35),
                blurRadius: 24,
                spreadRadius: 1,
                offset: const Offset(0, 6),
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
              // Subtle hatch on button
              Positioned.fill(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CustomPaint(
                    painter: _HatchPainter(
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.sports_kabaddi,
                      color: Colors.white.withValues(alpha: 0.9), size: 20),
                  const SizedBox(width: 12),
                  Text(
                    'MARCH TO BATTLE',
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.95),
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2.5,
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
  //  Sigil Selector
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildSigilSelector({
    required String currentSigil,
    required String unavailableSigil,
    required Function(String) onSigilSelected,
    required Color accentColor,
  }) {
    return SizedBox(
      height: 56,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableSigils.length,
        itemBuilder: (context, index) {
          final sigil = _availableSigils[index];
          final isSelected = sigil == currentSigil;
          final isUnavailable = sigil == unavailableSigil;

          return GestureDetector(
            onTap: isUnavailable ? null : () => onSigilSelected(sigil),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOutCubic,
              width: 52,
              margin: const EdgeInsets.only(right: 10),
              decoration: BoxDecoration(
                gradient: isSelected
                    ? LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.25),
                          accentColor.withValues(alpha: 0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                color: isSelected ? null : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected
                      ? accentColor.withValues(alpha: 0.75)
                      : isUnavailable
                          ? Colors.transparent
                          : Colors.white.withValues(alpha: 0.1),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 1,
                        )
                      ]
                    : [],
              ),
              padding: const EdgeInsets.all(9),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 200),
                opacity: isUnavailable ? 0.18 : 1.0,
                child: AppAssetImage(
                  sigil,
                  color: isSelected ? null : Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Color Selector
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildColorSelector({
    required Color currentColor,
    required Color unavailableColor,
    required Function(Color) onColorSelected,
  }) {
    return SizedBox(
      height: 34,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableColors.length,
        itemBuilder: (context, index) {
          final color = _availableColors[index];
          final isSelected = color.toARGB32() == currentColor.toARGB32();
          final isUnavailable = color.toARGB32() == unavailableColor.toARGB32();

          return GestureDetector(
            onTap: isUnavailable ? null : () => onColorSelected(color),
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 200),
              opacity: isUnavailable ? 0.18 : 1.0,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                width: isSelected ? 34 : 30,
                height: isSelected ? 34 : 30,
                margin: EdgeInsets.only(
                  right: 12,
                  top: isSelected ? 0 : 2,
                ),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? Colors.white.withValues(alpha: 0.9)
                        : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: color.withValues(alpha: 0.65),
                            blurRadius: 14,
                            spreadRadius: 2,
                          )
                        ]
                      : [],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Text Field
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildTextField(
    TextEditingController controller,
    String label,
    Color accentColor, {
    bool isNumeric = false,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 14,
        letterSpacing: 1.2,
      ),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(
          color: accentColor.withValues(alpha: 0.7),
          fontSize: 11,
          letterSpacing: 2,
          fontWeight: FontWeight.bold,
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.35), width: 1.2),
          borderRadius: BorderRadius.circular(10),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        filled: true,
        fillColor: accentColor.withValues(alpha: 0.06),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Game Start Logic (unchanged)
  // ───────────────────────────────────────────────────────────────────────────
  void _onStartBattle() {
    final notifier = ref.read(gameSettingsProvider.notifier);
    notifier.setPlayerNames(
      _p1Controller.text.trim().isEmpty ? 'PLAYER 1' : _p1Controller.text.trim(),
      _p2Controller.text.trim().isEmpty ? 'PLAYER 2' : _p2Controller.text.trim(),
    );
    notifier.setPlayerSymbols(_p1Symbol, _p2Symbol);
    notifier.setPlayerColors(_p1Color.toARGB32(), _p2Color.toARGB32());
    final int threshold = int.tryParse(_thresholdController.text) ?? 100;
    notifier.setKingdomAttackThreshold(threshold);

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
//  Press-scale button wrapper (subtle tactile feedback)
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
      duration: const Duration(milliseconds: 110),
      reverseDuration: const Duration(milliseconds: 180),
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