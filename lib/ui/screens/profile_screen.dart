import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_assets.dart';
import '../../providers/game_settings_provider.dart';
import '../../campaign/campaign_manager.dart';
import '../../campaign/data/kingdoms_data.dart';
import 'splash_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Painters (shared aesthetic from setup screen)
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

// ─────────────────────────────────────────────────────────────────────────────
//  Profile Screen
// ─────────────────────────────────────────────────────────────────────────────
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
    with TickerProviderStateMixin {

  final List<String> _availableSymbols = AppAssets.availableSymbols;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _crestPulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _crestPulse;

  @override
  void initState() {
    super.initState();

    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 650));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 580));
    _crestPulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
      ..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.07), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _crestPulse = Tween<double>(begin: 0.85, end: 1.0)
        .animate(CurvedAnimation(parent: _crestPulseController, curve: Curves.easeInOut));

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
    _crestPulseController.dispose();
    super.dispose();
  }

  // ── Logic (unchanged) ──────────────────────────────────────────────────────
  Future<void> _resetProfile(BuildContext context) async {
    await ref.read(campaignProvider.notifier).resetProgress();
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.remove('is_first_run');
    await prefs.remove('kingdom_name');
    await prefs.remove('kingdom_symbol');
    if (!context.mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const SplashScreen()),
      (route) => false,
    );
  }

  void _showNameDialog(BuildContext context, String currentName) {
    final primary = Theme.of(context).colorScheme.primary;
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (ctx) => _AncientDialog(
        title: 'RENAME THY KINGDOM',
        accentColor: primary,
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white, letterSpacing: 1.5),
          maxLength: 15,
          textCapitalization: TextCapitalization.characters,
          decoration: InputDecoration(
            counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primary.withValues(alpha: 0.4)),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: primary, width: 2),
            ),
            hintText: 'Enter name…',
            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.2), letterSpacing: 1),
          ),
        ),
        actions: [
          _DialogButton(
            label: 'CANCEL',
            color: Colors.white30,
            onTap: () => Navigator.pop(ctx),
          ),
          _DialogButton(
            label: 'PROCLAIM',
            color: primary,
            onTap: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(gameSettingsProvider.notifier)
                    .setPlayer1Name(controller.text.trim().toUpperCase());
              }
              Navigator.pop(ctx);
            },
          ),
        ],
      ),
    );
  }

  void _showSymbolDialog(BuildContext context, String currentSymbol) {
    final primary = Theme.of(context).colorScheme.primary;
    showDialog(
      context: context,
      builder: (ctx) => _AncientDialog(
        title: 'CHOOSE THY HOUSE SIGIL',
        accentColor: primary,
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
            ),
            itemCount: _availableSymbols.length,
            itemBuilder: (context, index) {
              final symbol = _availableSymbols[index];
              final isSelected = symbol == currentSymbol;
              return GestureDetector(
                onTap: () {
                  ref.read(gameSettingsProvider.notifier).setPlayer1Symbol(symbol);
                  Navigator.pop(ctx);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? LinearGradient(colors: [
                            primary.withValues(alpha: 0.25),
                            primary.withValues(alpha: 0.1),
                          ])
                        : null,
                    color: isSelected ? null : Colors.white.withValues(alpha: 0.05),
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
                    color: isSelected ? primary : Colors.white.withValues(alpha: 0.55),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          _DialogButton(
            label: 'DISMISS',
            color: Colors.white30,
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameSettingsProvider);
    final campaign = ref.watch(campaignProvider);
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
                    const SizedBox(height: 16),
                    _buildTopBar(primary),
                    Expanded(
                      child: Center(
                        child: SingleChildScrollView(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 600),
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 8),
                                _buildCrestSection(context, settings, primary),
                                const SizedBox(height: 32),
                                _buildStatsPanel(primary, campaign),
                                const SizedBox(height: 24),
                                _buildDangerZone(context, primary),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
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
                'ROYAL COURT',
                style: TextStyle(
                  color: primary,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 3.5,
                ),
              ),
              Text(
                "Thy kingdom's seal and name",
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
        ],
      ),
    );
  }

  // ── Crest + Name ───────────────────────────────────────────────────────────
  Widget _buildCrestSection(BuildContext context, dynamic settings, Color primary) {
    return Column(
      children: [
        // Sigil crest
        GestureDetector(
          onTap: () => _showSymbolDialog(context, settings.player1Symbol),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer pulsing ring
              AnimatedBuilder(
                animation: _crestPulse,
                builder: (_, __) => Container(
                  width: 120 * _crestPulse.value,
                  height: 120 * _crestPulse.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: primary.withValues(alpha: 0.12 * _crestPulse.value),
                      width: 1,
                    ),
                  ),
                ),
              ),
              // Glow halo
              Container(
                width: 106,
                height: 106,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: primary.withValues(alpha: 0.22), blurRadius: 32, spreadRadius: 4),
                  ],
                ),
              ),
              // Main crest container
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      primary.withValues(alpha: 0.18),
                      const Color(0xFF0F0D0A),
                    ],
                  ),
                  border: Border.all(color: primary.withValues(alpha: 0.6), width: 2),
                ),
                padding: const EdgeInsets.all(18),
                child: AppAssetImage(
                  settings.player1Symbol,
                  color: primary,
                ),
              ),
              // Edit badge
              Positioned(
                right: 14,
                bottom: 14,
                child: Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF0A0804), width: 2),
                    boxShadow: [BoxShadow(color: primary.withValues(alpha: 0.5), blurRadius: 8)],
                  ),
                  child: const Icon(Icons.edit, size: 12, color: Colors.black),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // Kingdom name
        GestureDetector(
          onTap: () => _showNameDialog(context, settings.player1Name),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: primary.withValues(alpha: 0.2), width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: child),
                    child: Text(
                      settings.player1Name.toUpperCase(),
                      key: ValueKey(settings.player1Name),
                      style: GoogleFonts.sairaStencilOne(
                        fontSize: 30,
                        color: primary,
                        letterSpacing: 2,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  padding: const EdgeInsets.all(5),
                  decoration: BoxDecoration(
                    color: primary.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: primary.withValues(alpha: 0.4), width: 1),
                  ),
                  child: Icon(Icons.edit, size: 12, color: primary),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 8),
        Text(
          'THE REIGNING POWER',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.35),
            fontSize: 11,
            letterSpacing: 3.5,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  // ── Stats / Info Panel ─────────────────────────────────────────────────────
  Widget _buildStatsPanel(Color primary, CampaignState campaign) {
    final conqueredCount = campaign.conqueredKingdomIds.length;
    final totalCount = kKingdoms.length;
    final progressPercent = totalCount > 0 ? conqueredCount / totalCount : 0.0;
    
    String title = 'Rising Warlord';
    if (progressPercent >= 1.0) {
      title = 'Eternal Emperor';
    } else if (progressPercent >= 0.75) {
      title = 'Grand Conqueror';
    } else if (progressPercent >= 0.5) {
      title = 'Venerable King';
    } else if (progressPercent >= 0.25) {
      title = 'Noble Duke';
    }

    // Find last conquered kingdom name
    String lastConquest = 'None';
    if (campaign.conqueredKingdomIds.isNotEmpty) {
      for (final k in kKingdoms.reversed) {
        if (campaign.conqueredKingdomIds.contains(k.id)) {
          lastConquest = k.name;
          break;
        }
      }
    }

    return _StonePanel(
      accentColor: primary,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('KINGDOM CHRONICLES', color: primary),
          const SizedBox(height: 18),
          _buildStatRow(
            icon: Icons.military_tech,
            label: 'ROYAL TITLE',
            value: title,
            primary: primary,
          ),
          const SizedBox(height: 14),
          _buildStatRow(
            icon: Icons.castle_outlined,
            label: 'CONQUEST PROGRESS',
            value: '$conqueredCount / $totalCount Kingdoms',
            primary: primary,
          ),
          const SizedBox(height: 14),
          _buildStatRow(
            icon: Icons.star_border_rounded,
            label: 'LATEST VICTORY',
            value: lastConquest,
            primary: primary,
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow({
    required IconData icon,
    required String label,
    required String value,
    required Color primary,
  }) {
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            color: primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: primary.withValues(alpha: 0.2), width: 1),
          ),
          child: Icon(icon, color: primary.withValues(alpha: 0.7), size: 18),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.35),
                  fontSize: 9,
                  letterSpacing: 2.2,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Danger Zone ────────────────────────────────────────────────────────────
  Widget _buildDangerZone(BuildContext context, Color primary) {
    return _StonePanel(
      accentColor: Colors.redAccent,
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('ABDICATION', color: Colors.redAccent),
          const SizedBox(height: 12),
          Text(
            'Dissolve thy kingdom and return to the dawn of time. All records shall be stricken from the annals.',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 12,
              height: 1.6,
              fontStyle: FontStyle.italic,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 20),
          _AnimatedPressButton(
            onTap: () => _showResetConfirm(context, primary),
            accentColor: Colors.redAccent,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.redAccent.withValues(alpha: 0.5), width: 1.2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.refresh_rounded, color: Colors.redAccent.withValues(alpha: 0.85), size: 18),
                  const SizedBox(width: 10),
                  Text(
                    'ABANDON THE THRONE',
                    style: TextStyle(
                      color: Colors.redAccent.withValues(alpha: 0.9),
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
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

  void _showResetConfirm(BuildContext context, Color primary) {
    showDialog(
      context: context,
      builder: (ctx) => _AncientDialog(
        title: 'ABDICATE THE THRONE?',
        accentColor: Colors.redAccent,
        content: Text(
          "This act is irreversible. Thy kingdom's name, sigil, and legacy shall be erased from history.",
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.55),
            fontSize: 13,
            height: 1.6,
            fontStyle: FontStyle.italic,
          ),
        ),
        actions: [
          _DialogButton(label: 'HOLD FAST', color: Colors.white30, onTap: () => Navigator.pop(ctx)),
          _DialogButton(
            label: 'ABDICATE',
            color: Colors.redAccent,
            onTap: () {
              Navigator.pop(ctx);
              _resetProfile(context);
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Ancient-themed Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _AncientDialog extends StatelessWidget {
  final String title;
  final Color accentColor;
  final Widget content;
  final List<Widget> actions;

  const _AncientDialog({
    required this.title,
    required this.accentColor,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 380),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1E1810), Color(0xFF0F0D0A)],
          ),
          border: Border.all(color: accentColor.withValues(alpha: 0.35), width: 1.2),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.7), blurRadius: 30, offset: const Offset(0, 10)),
            BoxShadow(color: accentColor.withValues(alpha: 0.1), blurRadius: 30, spreadRadius: 4),
          ],
        ),
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.015))),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title row
                  Row(
                    children: [
                      Container(width: 14, height: 1.5, color: accentColor.withValues(alpha: 0.5)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          title,
                          style: TextStyle(
                            color: accentColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  content,
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: actions
                        .map((a) => Padding(padding: const EdgeInsets.only(left: 10), child: a))
                        .toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DialogButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _DialogButton({required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
        ),
        child: Text(
          label,
          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 2),
        ),
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
