import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/constants/app_assets.dart';
import '../../providers/game_settings_provider.dart';
import '../../core/enums/game_mode.dart';
import '../../core/services/audio_service.dart';
import 'multiplayer_setup_screen.dart';

class MapSelectionScreen extends ConsumerStatefulWidget {
  final bool isBluetoothMode;
  const MapSelectionScreen({super.key, this.isBluetoothMode = false});

  @override
  ConsumerState<MapSelectionScreen> createState() => _MapSelectionScreenState();
}

class _MapSelectionScreenState extends ConsumerState<MapSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;
  late Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _fadeAnim = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOutCubic,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final currentSelectedMap = ref.watch(gameSettingsProvider).selectedMapPath;

    final List<Map<String, dynamic>> availableMaps = [
      {
        'name': 'ShadowWoods',
        'dimension': '15 × 15',
        'scale': 'SMALL',
        'category': 'SKIRMISH',
        'icon': Icons.forest_rounded,
        'path': AppAssets.northernForestMap,
        'description': 'Dense forest canopy with narrow tactical chokepoints.',
        'image': AppAssets.northernForest,
        'accentColor': const Color(0xFF66BB6A),
      },
      {
        'name': 'Hellfire',
        'dimension': '19 × 19',
        'scale': 'MEDIUM',
        'category': 'DESERT DUEL',
        'icon': Icons.local_fire_department_rounded,
        'path': AppAssets.desertMap,
        'description': 'Arid scorching dunes primed for fierce flanking maneuvers.',
        'image': AppAssets.pyramid,
        'accentColor': const Color(0xFFFF9800),
      },
      {
        'name': 'Arcadia',
        'dimension': '25 × 25',
        'scale': 'BALANCED',
        'category': 'EXPEDITION',
        'icon': Icons.shield_rounded,
        'path': AppAssets.defaultMap,
        'description': 'Classic highland plains tailored for multi-front warfare.',
        'image': AppAssets.grasslandArmy,
        'accentColor': primary,
      },
      {
        'name': 'Hardhome',
        'dimension': '30 × 30',
        'scale': 'COLOSSUS',
        'category': 'EPIC SIEGE',
        'icon': Icons.ac_unit_rounded,
        'path': AppAssets.icelandsMap,
        'description': 'Frozen glacial realm demanding endurance siege warfare.',
        'image': AppAssets.winterCastle,
        'accentColor': const Color(0xFF4FC3F7),
      },
    ];

    return Scaffold(
      backgroundColor: const Color(0xFF0A0804),
      body: Stack(
        children: [
          // Ambient Radial Glow
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.35),
                  radius: 1.2,
                  colors: [
                    primary.withValues(alpha: 0.12),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Tactical Grid Hatch Pattern
          Positioned.fill(
            child: CustomPaint(
              painter: _HatchPainter(
                color: Colors.white.withValues(alpha: 0.015),
              ),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnim,
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _buildTopBar(primary),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: _SectionHeader(
                      title: 'SELECT BATTLEFIELD THEATRE',
                      subtitle: 'CHOOSE YOUR STRATEGIC COMBAT GRID',
                      accentColor: primary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 860),
                        child: GridView.builder(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 24),
                          physics: const BouncingScrollPhysics(
                            parent: AlwaysScrollableScrollPhysics(),
                          ),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 14,
                            mainAxisSpacing: 12,
                            childAspectRatio: 2.55,
                          ),
                          itemCount: availableMaps.length,
                          itemBuilder: (context, index) {
                            final map = availableMaps[index];
                            final isSelected = currentSelectedMap == map['path'];
                            return _MapCard(
                              map: map,
                              primary: primary,
                              isSelected: isSelected,
                              onTap: () {
                                ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
                                _handleMapSelection(map);
                              },
                            );
                          },
                        ),
                      ),
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

  Widget _buildTopBar(Color primary) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          // Back Button
          _AnimatedPressButton(
            onTap: () {
              ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
              Navigator.pop(context);
            },
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: const Color(0xFF16120C),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: primary.withValues(alpha: 0.35),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(Icons.chevron_left_rounded, color: primary, size: 22),
            ),
          ),
          const SizedBox(width: 14),

          // Titles
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'WAR ROOM',
                  style: GoogleFonts.sairaStencilOne(
                    color: primary,
                    fontSize: 16,
                    letterSpacing: 2.5,
                  ),
                ),
                Text(
                  "Designate battlefield for supreme realm conquest",
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.4),
                    fontSize: 9.5,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _handleMapSelection(Map<String, dynamic> map) {
    final mapPath = map['path'] as String;
    ref.read(gameSettingsProvider.notifier).setMode(GameMode.multiplayer);
    ref.read(gameSettingsProvider.notifier).setSelectedMap(mapPath);

    final selectedMapData = {
      'name': map['name'] as String,
      'path': mapPath,
      'description': map['description'] as String,
      'image': map['image'] as String,
    };

    if (widget.isBluetoothMode) {
      Navigator.pop(context, selectedMapData);
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          settings: const RouteSettings(name: '/multiplayer_setup'),
          builder: (context) => const MultiplayerSetupScreen(),
        ),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Horizontal Rectangle Map Card (Full-Bleed Image Coverage + Rounded Corners)
// ─────────────────────────────────────────────────────────────────────────────
class _MapCard extends StatelessWidget {
  final Map<String, dynamic> map;
  final Color primary;
  final bool isSelected;
  final VoidCallback onTap;

  const _MapCard({
    required this.map,
    required this.primary,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color mapAccent = (map['accentColor'] as Color?) ?? primary;
    const borderRadius = BorderRadius.all(Radius.circular(16));

    return _AnimatedPressButton(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: isSelected ? primary : primary.withValues(alpha: 0.35),
            width: isSelected ? 1.8 : 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.7),
              blurRadius: 14,
              offset: const Offset(0, 5),
            ),
            if (isSelected)
              BoxShadow(
                color: primary.withValues(alpha: 0.28),
                blurRadius: 18,
                spreadRadius: 1.5,
              ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(14.5)),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // 1. Full Tile Covered Background Image
              AppAssetImage(
                map['image']!,
                fit: BoxFit.cover,
                alignment: Alignment.center,
              ),

              // 2. Dark Scrim & Atmospheric Gradient for Legibility
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.0, 0.35, 0.7, 1.0],
                    colors: [
                      Colors.black.withValues(alpha: 0.7),
                      Colors.black.withValues(alpha: 0.45),
                      Colors.black.withValues(alpha: 0.78),
                      const Color(0xFF0A0804).withValues(alpha: 0.96),
                    ],
                  ),
                ),
              ),

              // 3. Subtle Hatch Grid Pattern
              Positioned.fill(
                child: CustomPaint(
                  painter: _HatchPainter(
                    color: Colors.white.withValues(alpha: 0.015),
                  ),
                ),
              ),

              // 4. Content Overlay
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Top Row: Only Grid Size & Active status on Top Right
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        if (isSelected) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 7,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: primary.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: primary,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 10,
                                  color: primary,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'ACTIVE',
                                  style: TextStyle(
                                    color: primary,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.8,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 6),
                        ],
                        // Grid Size Badge
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected
                                  ? primary.withValues(alpha: 0.7)
                                  : Colors.white24,
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.grid_4x4_rounded,
                                size: 11,
                                color: isSelected ? primary : Colors.white70,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                map['dimension']!,
                                style: GoogleFonts.outfit(
                                  color: Colors.white,
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // Left Bottom: Name & Details
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Name & Category Badge
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              (map['name']! as String).toUpperCase(),
                              style: GoogleFonts.sairaStencilOne(
                                color: isSelected ? primary : Colors.white,
                                fontSize: 14.5,
                                letterSpacing: 1.2,
                                shadows: const [
                                  Shadow(
                                    color: Colors.black,
                                    blurRadius: 8,
                                    offset: Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: mapAccent.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(
                                  color: mapAccent.withValues(alpha: 0.5),
                                  width: 0.8,
                                ),
                              ),
                              child: Text(
                                map['category']!,
                                style: TextStyle(
                                  color: mapAccent,
                                  fontSize: 8,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 3),

                        // Details / Description
                        Text(
                          map['description']!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.8),
                            fontSize: 9,
                            height: 1.25,
                            letterSpacing: 0.2,
                            shadows: const [
                              Shadow(
                                color: Colors.black,
                                blurRadius: 6,
                                offset: Offset(0, 1),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Section Header with Tactical Accents
// ─────────────────────────────────────────────────────────────────────────────
class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final Color accentColor;

  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 18,
          height: 1.5,
          color: accentColor.withValues(alpha: 0.6),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            color: accentColor,
            fontSize: 10.5,
            fontWeight: FontWeight.bold,
            letterSpacing: 2.2,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            height: 1.5,
            color: accentColor.withValues(alpha: 0.35),
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Tactical Grid Background Hatch Painter
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
      canvas.drawLine(
        Offset(i, 0),
        Offset(i + size.height, size.height),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

// ─────────────────────────────────────────────────────────────────────────────
//  Press-scale button wrapper
// ─────────────────────────────────────────────────────────────────────────────
class _AnimatedPressButton extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const _AnimatedPressButton({
    required this.child,
    required this.onTap,
  });

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
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 160),
    );
    _scale = Tween<double>(
      begin: 1.0,
      end: 0.96,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
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
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}
