import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_assets.dart';
import '../../core/services/audio_service.dart';
import '../../providers/game_settings_provider.dart';
import '../../core/enums/game_mode.dart';
import 'overworld_map_screen.dart';
import 'multiplayer_mode_selection_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class GameHomeScreen extends ConsumerWidget {
  const GameHomeScreen({super.key});

  void _playClick(WidgetRef ref) {
    try {
      ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          const SizedBox(height: 50),
          Text(
            'WAR : BATTLEGRIDS',
            style: GoogleFonts.sairaStencilOne(
              color: Theme.of(context).colorScheme.primary,
              fontSize: 35,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
            ),
          ),
          Expanded(
            child: Center(
              child: AppAssetImage(
                AppAssets.homeBanner,
                fit: BoxFit.contain,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 24.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 20),
                  _ParchmentMenuButton(
                    label: 'CAMPAIGN',
                    iconAsset: AppAssets.storyModeIcon,
                    textureAlignment: const Alignment(-0.95, 0.85),
                    textureScale: 2.2,
                    onPressed: () {
                      _playClick(ref);
                      ref.read(gameSettingsProvider.notifier).setMode(GameMode.story);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/overworld'),
                          builder: (context) => const OverworldMapScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  _ParchmentMenuButton(
                    label: 'MULTIPLAYER',
                    iconAsset: AppAssets.multiplayerIcon,
                    textureAlignment: const Alignment(-0.25, -0.75),
                    textureScale: 2.1,
                    onPressed: () {
                      _playClick(ref);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/multiplayer_mode'),
                          builder: (context) => const MultiplayerModeSelectionScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  _ParchmentMenuButton(
                    label: 'PROFILE',
                    iconData: Icons.person_rounded,
                    textureAlignment: const Alignment(0.4, 0.65),
                    textureScale: 2.3,
                    onPressed: () {
                      _playClick(ref);
                      ref.read(gameSettingsProvider.notifier).restoreCampaignSettings();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                  _ParchmentMenuButton(
                    label: 'SETTINGS',
                    iconAsset: AppAssets.settingsIcon,
                    textureAlignment: const Alignment(0.95, -0.85),
                    textureScale: 2.2,
                    onPressed: () {
                      _playClick(ref);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 20),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Parchment-textured medieval button for the main navigation menu
class _ParchmentMenuButton extends StatefulWidget {
  final String label;
  final String? iconAsset;
  final IconData? iconData;
  final Alignment textureAlignment;
  final double textureScale;
  final VoidCallback onPressed;

  const _ParchmentMenuButton({
    required this.label,
    this.iconAsset,
    this.iconData,
    this.textureAlignment = Alignment.center,
    this.textureScale = 2.0,
    required this.onPressed,
  });

  @override
  State<_ParchmentMenuButton> createState() => _ParchmentMenuButtonState();
}

class _ParchmentMenuButtonState extends State<_ParchmentMenuButton> {
  bool _isPressed = false;
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: GestureDetector(
            onTapDown: (_) => setState(() => _isPressed = true),
            onTapUp: (_) {
              setState(() => _isPressed = false);
              widget.onPressed();
            },
            onTapCancel: () => setState(() => _isPressed = false),
            child: AnimatedScale(
              scale: _isPressed ? 0.92 : (_isHovered ? 1.05 : 1.0),
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeInOut,
              child: Container(
                width: 104,
                height: 74,
                decoration: BoxDecoration(
                  color: const Color(0xFFFCB103),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: _isHovered
                        ? Colors.white70
                        : const Color(0xFFD49200),
                    width: 2.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _isHovered
                          ? const Color(0x80FCB103)
                          : Colors.black.withValues(alpha: 0.55),
                      blurRadius: _isHovered ? 14 : 8,
                      offset: _isPressed ? const Offset(0, 2) : const Offset(0, 5),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(11.8),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // 1. Parchment Texture Layer (Clearly visible & crisp)
                      Positioned.fill(
                        child: Transform.scale(
                          scale: widget.textureScale,
                          alignment: widget.textureAlignment,
                          child: const AppAssetImage(
                            AppAssets.parchmentTexture,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      // 2. Bright Golden Yellow Overlay (#FCB103)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                const Color(0xFFFFE082).withValues(alpha: 0.38),
                                const Color(0xFFFCB103).withValues(alpha: 0.28),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // 3. Luminous Top-Light Highlight
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                Colors.white.withValues(alpha: 0.22),
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.12),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // Fine inner engraved border
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.all(3.0),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: const Color(0xFF7A4F00).withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                        ),
                      ),
                      // Black Vector Icon
                      Center(
                        child: widget.iconAsset != null
                            ? AppAssetImage(
                                widget.iconAsset!,
                                width: 48,
                                height: 48,
                                color: Colors.black,
                                colorBlendMode: BlendMode.srcIn,
                              )
                            : Icon(
                                widget.iconData,
                                size: 42,
                                color: Colors.black,
                              ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.label,
          style: GoogleFonts.sairaStencilOne(
            color: const Color(0xFFFCB103),
            fontSize: 14,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
            shadows: const [
              Shadow(
                color: Colors.black,
                blurRadius: 6,
                offset: Offset(0, 2),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

