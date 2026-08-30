import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_assets.dart';
import '../../core/services/audio_service.dart';
import '../../providers/game_settings_provider.dart';
import 'main_menu_screen.dart';
import 'tutorial_screen.dart';

/// House Sigil Metadata model for rich medieval lore
class _SigilInfo {
  final String path;
  final String houseName;
  final String title;
  final List<String> virtues;
  final String lore;
  final Color heraldicColor;

  const _SigilInfo({
    required this.path,
    required this.houseName,
    required this.title,
    required this.virtues,
    required this.lore,
    required this.heraldicColor,
  });
}

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> with TickerProviderStateMixin {
  final TextEditingController _nameController = TextEditingController(text: 'ELDORIA');
  String _selectedSymbol = AppAssets.fire;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;
  late Animation<double> _pulseAnim;

  final Map<String, _SigilInfo> _sigilData = {
    AppAssets.fire: const _SigilInfo(
      path: AppAssets.fire,
      houseName: 'HOUSE PYRE',
      title: 'The Eternal Flame',
      virtues: ['FEROCITY', 'DESTRUCTION', 'ZEAL'],
      lore: 'Forged in primordial furnace, their vanguard burns through hostile lines with unyielding fury.',
      heraldicColor: Color(0xFFD35400),
    ),
    AppAssets.tiger: const _SigilInfo(
      path: AppAssets.tiger,
      houseName: 'HOUSE STRYPE',
      title: 'The Apex Stalker',
      virtues: ['SAVAGE MIGHT', 'INSTINCT', 'AMBUSH'],
      lore: 'Hunters of the dense primeval wilds whose pounces are swift, crushing, and decisive.',
      heraldicColor: Color(0xFFE67E22),
    ),
    AppAssets.flash: const _SigilInfo(
      path: AppAssets.flash,
      houseName: 'HOUSE TEMPEST',
      title: 'The Storm Sovereign',
      virtues: ['VELOCITY', 'SHOCK', 'MOMENTUM'],
      lore: 'Wielders of celestial lightning who strike before the thunder of war can even sound.',
      heraldicColor: Color(0xFFF1C40F),
    ),
    AppAssets.hacker: const _SigilInfo(
      path: AppAssets.hacker,
      houseName: 'HOUSE CIPHER',
      title: 'The Grand Strategist',
      virtues: ['INTELLECT', 'SUBVERSION', 'INSIGHT'],
      lore: 'Master tacticians who see through fog of war and dissect opposing battle lines with ease.',
      heraldicColor: Color(0xFF16A085),
    ),
    AppAssets.lion: const _SigilInfo(
      path: AppAssets.lion,
      houseName: 'HOUSE REGALIS',
      title: 'The Golden Monarch',
      virtues: ['SOVEREIGNTY', 'COURAGE', 'DOMINION'],
      lore: 'Ancient bloodline of emperors commanding supreme battlefield authority and resolute spirit.',
      heraldicColor: Color(0xFFC89B3C),
    ),
    AppAssets.wolf: const _SigilInfo(
      path: AppAssets.wolf,
      houseName: 'HOUSE FROSTFANG',
      title: 'The Winter Pack',
      virtues: ['LOYALTY', 'PURSUIT', 'HARMONY'],
      lore: 'Bound by brotherhood, hunting in unbreakable unison across freezing expanses.',
      heraldicColor: Color(0xFF5DADE2),
    ),
    AppAssets.bull: const _SigilInfo(
      path: AppAssets.bull,
      houseName: 'HOUSE IRONHORN',
      title: 'The Unyielding Wall',
      virtues: ['RESILIENCE', 'BULWARK', 'FORCE'],
      lore: 'Stalwart defenders forged in stone who withstand endless siege and shatter enemy barricades.',
      heraldicColor: Color(0xFF8E44AD),
    ),
    AppAssets.shuriken: const _SigilInfo(
      path: AppAssets.shuriken,
      houseName: 'HOUSE SHADOWBLADE',
      title: 'The Silent Lotus',
      virtues: ['PRECISION', 'STEALTH', 'LETHALITY'],
      lore: 'Ghosts of the shadows who slip through defenses and neutralize threats in silent perfection.',
      heraldicColor: Color(0xFF2C3E50),
    ),
  };

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    _pulseController = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))..repeat(reverse: true);

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));
    _pulseAnim = Tween<double>(begin: 0.96, end: 1.04)
        .animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));

    Future.delayed(const Duration(milliseconds: 150), () {
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
    _pulseController.dispose();
    super.dispose();
  }

  void _playClickSound() {
    try {
      ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
    } catch (_) {}
  }

  Future<void> _saveAndContinue() async {
    _playClickSound();
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'PLEASE ENTER THY KINGDOM NAME',
            style: GoogleFonts.sairaStencilOne(fontWeight: FontWeight.bold, letterSpacing: 1.5),
          ),
          backgroundColor: const Color(0xFF8B1E1E),
          behavior: SnackBarBehavior.floating,
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
        transitionDuration: const Duration(milliseconds: 700),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeSigil = _sigilData[_selectedSymbol] ?? _sigilData[AppAssets.fire]!;

    return Scaffold(
      backgroundColor: const Color(0xFF0F0C0A),
      body: Stack(
        children: [
          // 1. Antique Parchment Background Image
          Positioned.fill(
            child: AppAssetImage(
              AppAssets.welcomeBg,
              fit: BoxFit.cover,
            ),
          ),

          // 2. Subtle Vignette Overlay for Depth & Readability
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.25,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                ),
              ),
            ),
          ),

          // 3. Screen Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Center(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1100),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // --- Screen Header ---
                          _buildHeader(),
                          const SizedBox(height: 16),

                          // --- Main Two-Column Layout ---
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Left Column: Royal Charter & Kingdom Creation
                              Expanded(
                                flex: 5,
                                child: _buildLeftCharterPanel(activeSigil),
                              ),

                              const SizedBox(width: 24),

                              // Right Column: Heraldic Sigils & Lore Selector
                              Expanded(
                                flex: 6,
                                child: _buildRightHeraldryPanel(activeSigil),
                              ),
                            ],
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
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildOrnateDivider(isLeft: true),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'ROYAL CHARTER OF DOMINION',
                style: GoogleFonts.sairaStencilOne(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2C1E14),
                  letterSpacing: 4.5,
                  shadows: [
                    Shadow(
                      color: const Color(0xFFD4AF37).withValues(alpha: 0.7),
                      offset: const Offset(0, 1),
                      blurRadius: 3,
                    ),
                  ],
                ),
              ),
            ),
            _buildOrnateDivider(isLeft: false),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'INSCRIBE THY REIGN • CHOOSE THY HOUSE HERALDRY • CONQUER THE REALM',
          style: GoogleFonts.sairaStencilOne(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: const Color(0xFF6B4E38),
            letterSpacing: 2.5,
          ),
        ),
      ],
    );
  }

  Widget _buildOrnateDivider({required bool isLeft}) {
    return SizedBox(
      width: 60,
      child: Row(
        children: [
          if (!isLeft) const SizedBox(width: 4),
          Expanded(
            child: Container(
              height: 1.5,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isLeft
                      ? [Colors.transparent, const Color(0xFF8A6240)]
                      : [const Color(0xFF8A6240), Colors.transparent],
                ),
              ),
            ),
          ),
          Container(
            width: 5,
            height: 5,
            transform: Matrix4.rotationZ(math.pi / 4),
            decoration: const BoxDecoration(color: Color(0xFF8A6240)),
          ),
          if (isLeft) const SizedBox(width: 4),
        ],
      ),
    );
  }

  Widget _buildLeftCharterPanel(_SigilInfo activeSigil) {
    return _ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          _buildParchmentSectionHeader(
            icon: Icons.castle_rounded,
            title: 'SOVEREIGN IDENTITY',
            subtitle: 'Name of thy royal realm',
          ),
          const SizedBox(height: 10),

          // Kingdom Name Input Field
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF7F1E1).withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFB38F53).withValues(alpha: 0.6),
                width: 1.5,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2C1E14).withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                const Icon(
                  Icons.edit_note_rounded,
                  color: Color(0xFF7A5736),
                  size: 24,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 15,
                    style: GoogleFonts.sairaStencilOne(
                      color: const Color(0xFF26180F),
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 2.0,
                    ),
                    cursorColor: const Color(0xFF8B1E1E),
                    decoration: InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: 'ENTER REALM NAME...',
                      hintStyle: GoogleFonts.sairaStencilOne(
                        color: const Color(0xFF8A7563).withValues(alpha: 0.7),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1.5,
                      ),
                      counterText: '',
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Active House Sigil Crest Preview
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE8DCC2).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: const Color(0xFFB89865).withValues(alpha: 0.5),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                // Glowing Crest Seal
                ScaleTransition(
                  scale: _pulseAnim,
                  child: Container(
                    width: 54,
                    height: 54,
                    padding: const EdgeInsets.all(9),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: const RadialGradient(
                        colors: [
                          Color(0xFFFFF9E6),
                          Color(0xFFE2C98A),
                          Color(0xFF9E7B34),
                        ],
                      ),
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 2.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD4AF37).withValues(alpha: 0.5),
                          blurRadius: 10,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: AppAssetImage(
                      activeSigil.path,
                      color: const Color(0xFF26180F),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                // Crest Meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        activeSigil.houseName,
                        style: GoogleFonts.sairaStencilOne(
                          color: const Color(0xFF2C1E14),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.6,
                        ),
                      ),
                      Text(
                        activeSigil.title,
                        style: GoogleFonts.sairaStencilOne(
                          color: const Color(0xFF8B1E1E),
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        activeSigil.lore,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Color(0xFF5C4736),
                          fontSize: 9.5,
                          height: 1.2,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Primary Decree Button
          _AnimatedPressButton(
            onTap: _saveAndContinue,
            child: Container(
              width: double.infinity,
              height: 48,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF9E2323),
                    Color(0xFF6B1515),
                    Color(0xFF420D0D),
                  ],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFFF1C40F).withValues(alpha: 0.8),
                  width: 1.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFF8B1E1E).withValues(alpha: 0.5),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Subtle hatch pattern
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: CustomPaint(
                        painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.military_tech_rounded,
                        color: Color(0xFFF7DC6F),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'SEAL DECREE & BEGIN REIGN',
                        style: GoogleFonts.sairaStencilOne(
                          color: const Color(0xFFFFF9E6),
                          fontSize: 13.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2.0,
                          shadows: [
                            const Shadow(
                              color: Color(0xCC000000),
                              offset: Offset(0, 1.5),
                              blurRadius: 2,
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
        ],
      ),
    );
  }

  Widget _buildRightHeraldryPanel(_SigilInfo activeSigil) {
    return _ParchmentCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          _buildParchmentSectionHeader(
            icon: Icons.shield_rounded,
            title: 'HERALDIC HOUSE SIGILS',
            subtitle: 'Select the crest of thy royal lineage',
          ),
          const SizedBox(height: 10),

          // 8 Sigil Grid (2 rows x 4 cols)
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.0,
            ),
            itemCount: AppAssets.availableSymbols.length,
            itemBuilder: (context, index) {
              final symbol = AppAssets.availableSymbols[index];
              final isSelected = _selectedSymbol == symbol;
              final info = _sigilData[symbol];

              return _AnimatedPressButton(
                onTap: () {
                  _playClickSound();
                  setState(() => _selectedSymbol = symbol);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOutCubic,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? const Color(0xFFFFF9E6)
                        : const Color(0xFFE5D5BA).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected
                          ? const Color(0xFF8B1E1E)
                          : const Color(0xFF9E8569).withValues(alpha: 0.5),
                      width: isSelected ? 2.2 : 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: const Color(0xFFD4AF37).withValues(alpha: 0.6),
                              blurRadius: 10,
                              spreadRadius: 1,
                            ),
                            BoxShadow(
                              color: const Color(0xFF8B1E1E).withValues(alpha: 0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Active gold corner ribbon
                      if (isSelected)
                        Positioned(
                          top: 3,
                          right: 3,
                          child: Container(
                            width: 7,
                            height: 7,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: Color(0xFF8B1E1E),
                            ),
                          ),
                        ),

                      Padding(
                        padding: const EdgeInsets.all(8),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Expanded(
                              child: AppAssetImage(
                                symbol,
                                color: isSelected
                                    ? const Color(0xFF1E140C)
                                    : const Color(0xFF5C4736).withValues(alpha: 0.8),
                              ),
                            ),
                            const SizedBox(height: 2),
                            FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                info?.houseName.replaceFirst('HOUSE ', '') ?? '',
                                maxLines: 1,
                                style: GoogleFonts.sairaStencilOne(
                                  color: isSelected
                                      ? const Color(0xFF8B1E1E)
                                      : const Color(0xFF6B4E38),
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          const SizedBox(height: 10),

          // Selected Sigil Virtues & Lore Pill Badges
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              color: const Color(0xFFE2D3B8).withValues(alpha: 0.55),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFFC0A678).withValues(alpha: 0.6),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Text(
                  'VIRTUES:',
                  style: GoogleFonts.sairaStencilOne(
                    fontSize: 9.5,
                    fontWeight: FontWeight.w900,
                    color: const Color(0xFF8B1E1E),
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: activeSigil.virtues.map((v) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2C1E14).withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: const Color(0xFF8A6240).withValues(alpha: 0.4),
                            width: 0.8,
                          ),
                        ),
                        child: Text(
                          v,
                          style: GoogleFonts.sairaStencilOne(
                            fontSize: 8.5,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF2C1E14),
                            letterSpacing: 0.8,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParchmentSectionHeader({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(5),
          decoration: BoxDecoration(
            color: const Color(0xFF8B1E1E).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF8B1E1E).withValues(alpha: 0.35),
              width: 1,
            ),
          ),
          child: Icon(
            icon,
            color: const Color(0xFF8B1E1E),
            size: 16,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.sairaStencilOne(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w900,
                  color: const Color(0xFF2C1E14),
                  letterSpacing: 1.8,
                ),
              ),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 9.5,
                  color: Color(0xFF6B4E38),
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _ParchmentCard (Translucent parchment-tinted container matching background)
// ─────────────────────────────────────────────────────────────────────────────
class _ParchmentCard extends StatelessWidget {
  final Widget child;

  const _ParchmentCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF3E8D0).withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFBFA06B).withValues(alpha: 0.7),
          width: 1.4,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF26180F).withValues(alpha: 0.18),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
          BoxShadow(
            color: const Color(0xFFFFF7E2).withValues(alpha: 0.5),
            blurRadius: 1,
            offset: const Offset(0, -1),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  _HatchPainter (Subtle medieval diagonal hatch texture)
// ─────────────────────────────────────────────────────────────────────────────
class _HatchPainter extends CustomPainter {
  final Color color;
  const _HatchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.8;
    const spacing = 14.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Press-scale button wrapper with tactile feedback
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedPressButton({required this.child, required this.onTap});

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
      duration: const Duration(milliseconds: 90),
      reverseDuration: const Duration(milliseconds: 140),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.95)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTapDown: (_) => _ctrl.forward(),
        onTapUp: (_) {
          _ctrl.reverse();
          widget.onTap();
        },
        onTapCancel: () => _ctrl.reverse(),
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
