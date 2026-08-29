import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_assets.dart';
import '../../providers/game_settings_provider.dart';
import '../../campaign/campaign_manager.dart';
import '../../campaign/data/kingdoms_data.dart';
import 'splash_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Modern Frosted Glass Panel
// ─────────────────────────────────────────────────────────────────────────────
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF0F1218).withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.12),
              width: 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
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
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(gameSettingsProvider.notifier).restoreCampaignSettings();
      }
    });

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.05), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 60), () {
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

  // ── Logic Handlers ─────────────────────────────────────────────────────────
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
      builder: (ctx) => _ModernDialog(
        title: 'RENAME REALM',
        subtitle: 'Enter a moniker for thy sovereign dominion',
        accentColor: primary,
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              autofocus: true,
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                letterSpacing: 1.5,
                fontFamily: GoogleFonts.sairaStencilOne().fontFamily,
              ),
              maxLength: 15,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.06),
                counterStyle: TextStyle(color: Colors.white.withValues(alpha: 0.4), fontSize: 11),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: primary, width: 1.5),
                ),
                hintText: 'e.g. VALORIA',
                hintStyle: TextStyle(
                  color: Colors.white.withValues(alpha: 0.25),
                  fontFamily: null,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        actions: [
          _ModernDialogButton(
            label: 'CANCEL',
            isPrimary: false,
            onTap: () => Navigator.pop(ctx),
          ),
          _ModernDialogButton(
            label: 'SAVE NAME',
            isPrimary: true,
            accentColor: primary,
            onTap: () {
              final trimmed = controller.text.trim();
              if (trimmed.isNotEmpty) {
                ref.read(gameSettingsProvider.notifier).setPlayer1Name(trimmed.toUpperCase());
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
      builder: (ctx) => _ModernDialog(
        title: 'HOUSE EMBLEM',
        subtitle: 'Select the sigil to lead thy banners into war',
        accentColor: primary,
        content: SizedBox(
          width: 360,
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.0,
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
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primary.withValues(alpha: 0.18)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? primary : Colors.white.withValues(alpha: 0.1),
                      width: isSelected ? 2 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: primary.withValues(alpha: 0.35),
                              blurRadius: 12,
                              spreadRadius: 1,
                            )
                          ]
                        : null,
                  ),
                  child: AppAssetImage(
                    symbol,
                    color: isSelected ? primary : Colors.white.withValues(alpha: 0.6),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          _ModernDialogButton(
            label: 'DISMISS',
            isPrimary: false,
            onTap: () => Navigator.pop(ctx),
          ),
        ],
      ),
    );
  }

  void _showResetConfirm(BuildContext context, Color primary) {
    showDialog(
      context: context,
      builder: (ctx) => _ModernDialog(
        title: 'ABDICATE THE THRONE?',
        subtitle: 'Irreversible Campaign Reset',
        accentColor: Colors.redAccent,
        content: Text(
          'All conquered realms, campaign progress, and sovereign identity records will be permanently erased.',
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 13,
            height: 1.5,
          ),
        ),
        actions: [
          _ModernDialogButton(
            label: 'KEEP THRONE',
            isPrimary: false,
            onTap: () => Navigator.pop(ctx),
          ),
          _ModernDialogButton(
            label: 'ABDICATE',
            isPrimary: true,
            accentColor: Colors.redAccent,
            onTap: () {
              Navigator.pop(ctx);
              _resetProfile(context);
            },
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
      backgroundColor: const Color(0xFF07090D),
      body: Stack(
        children: [
          // Background Image with Scenic Landscape
          Positioned.fill(
            child: AppAssetImage(
              AppAssets.profile,
              fit: BoxFit.cover,
              alignment: Alignment.center,
            ),
          ),

          // Modern Dark Atmospheric Scrim / Vignette Overlay
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF080B10).withValues(alpha: 0.75),
                    const Color(0xFF080B10).withValues(alpha: 0.85),
                    const Color(0xFF05070A).withValues(alpha: 0.95),
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),

          // Subtle Radial Accent Glow
          Positioned(
            top: -100,
            left: 0,
            right: 0,
            height: 380,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -0.3),
                    radius: 0.85,
                    colors: [
                      primary.withValues(alpha: 0.12),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Foreground Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: SlideTransition(
                position: _slideAnim,
                child: Column(
                  children: [
                    _buildHeader(primary),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final isWide = constraints.maxWidth >= 700;
                          return Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(maxWidth: 880),
                                child: isWide
                                    ? Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Left Hero Card (Sigil & Name)
                                          Expanded(
                                            flex: 5,
                                            child: _buildHeroCard(context, settings, primary),
                                          ),
                                          const SizedBox(width: 20),
                                          // Right Stats & Danger Zone
                                          Expanded(
                                            flex: 6,
                                            child: Column(
                                              children: [
                                                _buildStatsPanel(primary, campaign),
                                                const SizedBox(height: 16),
                                                _buildDangerZone(context, primary),
                                              ],
                                            ),
                                          ),
                                        ],
                                      )
                                    : Column(
                                        children: [
                                          _buildHeroCard(context, settings, primary),
                                          const SizedBox(height: 16),
                                          _buildStatsPanel(primary, campaign),
                                          const SizedBox(height: 16),
                                          _buildDangerZone(context, primary),
                                          const SizedBox(height: 20),
                                        ],
                                      ),
                              ),
                            ),
                          );
                        },
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

  // ── Top Navigation Bar ─────────────────────────────────────────────────────
  Widget _buildHeader(Color primary) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
      child: Row(
        children: [
          _ModernIconButton(
            icon: Icons.chevron_left,
            color: primary,
            onTap: () => Navigator.pop(context),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    'WARLORD PROFILE',
                    style: TextStyle(
                      color: primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 3,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: primary.withValues(alpha: 0.3), width: 0.8),
                    ),
                    child: Text(
                      'STATUS: SOVEREIGN',
                      style: TextStyle(
                        color: primary,
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Thy Royal Sigil, Moniker & Military Standing',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.45),
                  fontSize: 11,
                  letterSpacing: 0.8,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Left Card: Hero Crest & Name ───────────────────────────────────────────
  Widget _buildHeroCard(BuildContext context, dynamic settings, Color primary) {
    return _GlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      borderColor: primary.withValues(alpha: 0.25),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sigil Avatar with glowing aura and edit badge
          GestureDetector(
            onTap: () => _showSymbolDialog(context, settings.player1Symbol),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  // Ambient Radial Glow
                  Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: primary.withValues(alpha: 0.25),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),

                  // Core Sigil Orb
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          const Color(0xFF1C222D),
                          const Color(0xFF0E1218),
                        ],
                      ),
                      border: Border.all(
                        color: primary.withValues(alpha: 0.7),
                        width: 2,
                      ),
                    ),
                    padding: const EdgeInsets.all(20),
                    child: AppAssetImage(
                      settings.player1Symbol,
                      color: primary,
                    ),
                  ),

                  // Edit Badge
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: primary,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF0F1218), width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.5),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        size: 13,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Realm Name Pill
          GestureDetector(
            onTap: () => _showNameDialog(context, settings.player1Name),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        settings.player1Name.toUpperCase(),
                        style: GoogleFonts.sairaStencilOne(
                          fontSize: 22,
                          color: primary,
                          letterSpacing: 2,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.edit_note_rounded,
                      size: 18,
                      color: primary.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 8),

          Text(
            'SUPREME RULER',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.4),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 2.5,
            ),
          ),

          const SizedBox(height: 18),
          Divider(color: Colors.white.withValues(alpha: 0.08), height: 1),
          const SizedBox(height: 14),

          // Quick Action buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ModernOutlineButton(
                icon: Icons.shield_outlined,
                label: 'Change Sigil',
                onTap: () => _showSymbolDialog(context, settings.player1Symbol),
              ),
              const SizedBox(width: 10),
              _ModernOutlineButton(
                icon: Icons.edit_outlined,
                label: 'Rename',
                onTap: () => _showNameDialog(context, settings.player1Name),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ── Right Card: Chronicles & Stats ─────────────────────────────────────────
  Widget _buildStatsPanel(Color primary, CampaignState campaign) {
    final conqueredCount = campaign.conqueredKingdomIds.length;
    final totalCount = kKingdoms.length;
    final progressPercent = totalCount > 0 ? (conqueredCount / totalCount).clamp(0.0, 1.0) : 0.0;

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

    String lastConquest = 'None Yet';
    if (campaign.conqueredKingdomIds.isNotEmpty) {
      for (final k in kKingdoms.reversed) {
        if (campaign.conqueredKingdomIds.contains(k.id)) {
          lastConquest = k.name;
          break;
        }
      }
    }

    return _GlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section Title
          Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'KINGDOM CHRONICLES',
                style: TextStyle(
                  color: primary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Conquest Progress Bar
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'CONQUEST CAMPAIGN',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.5),
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.5,
                      ),
                    ),
                    Text(
                      '$conqueredCount / $totalCount Realms (${(progressPercent * 100).toInt()}%)',
                      style: TextStyle(
                        color: primary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progressPercent,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: AlwaysStoppedAnimation<Color>(primary),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Stat items in a clean grid
          Row(
            children: [
              Expanded(
                child: _buildStatTile(
                  icon: Icons.military_tech_rounded,
                  label: 'ROYAL TITLE',
                  value: title,
                  accentColor: primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _buildStatTile(
                  icon: Icons.flag_rounded,
                  label: 'LAST VICTORY',
                  value: lastConquest,
                  accentColor: primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile({
    required IconData icon,
    required String label,
    required String value,
    required Color accentColor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: accentColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Danger Zone ────────────────────────────────────────────────────────────
  Widget _buildDangerZone(BuildContext context, Color primary) {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      borderColor: Colors.redAccent.withValues(alpha: 0.25),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.restart_alt_rounded,
              color: Colors.redAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'RESET CAMPAIGN & IDENTITY',
                  style: TextStyle(
                    color: Colors.redAccent,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Wipe kingdom records & start afresh',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _ModernPressButton(
            onTap: () => _showResetConfirm(context, primary),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.redAccent.withValues(alpha: 0.5),
                  width: 1,
                ),
              ),
              child: const Text(
                'ABDICATE',
                style: TextStyle(
                  color: Colors.redAccent,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
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
//  Modern Minimal Dialog
// ─────────────────────────────────────────────────────────────────────────────
class _ModernDialog extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Color accentColor;
  final Widget content;
  final List<Widget> actions;

  const _ModernDialog({
    required this.title,
    this.subtitle,
    required this.accentColor,
    required this.content,
    required this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF0F1218).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.3),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.7),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
                BoxShadow(
                  color: accentColor.withValues(alpha: 0.1),
                  blurRadius: 20,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 3,
                      height: 16,
                      decoration: BoxDecoration(
                        color: accentColor,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          color: accentColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                    ),
                  ],
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Padding(
                    padding: const EdgeInsets.only(left: 11),
                    child: Text(
                      subtitle!,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.45),
                        fontSize: 11,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                content,
                const SizedBox(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions
                      .map((a) => Padding(padding: const EdgeInsets.only(left: 8), child: a))
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernDialogButton extends StatelessWidget {
  final String label;
  final bool isPrimary;
  final Color? accentColor;
  final VoidCallback onTap;

  const _ModernDialogButton({
    required this.label,
    required this.isPrimary,
    this.accentColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? Theme.of(context).colorScheme.primary;
    return _ModernPressButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isPrimary ? color : Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isPrimary ? color : Colors.white.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isPrimary ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Modern Buttons & Components
// ─────────────────────────────────────────────────────────────────────────────
class _ModernIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;

  const _ModernIconButton({
    required this.icon,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final primary = color ?? Theme.of(context).colorScheme.primary;
    return _ModernPressButton(
      onTap: onTap,
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
        child: Icon(icon, color: primary, size: 22),
      ),
    );
  }
}

class _ModernOutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ModernOutlineButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return _ModernPressButton(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.12),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: Colors.white70),
            const SizedBox(width: 6),
            Text(
              label,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _ModernPressButton({required this.child, required this.onTap});

  @override
  State<_ModernPressButton> createState() => _ModernPressButtonState();
}

class _ModernPressButtonState extends State<_ModernPressButton>
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
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
