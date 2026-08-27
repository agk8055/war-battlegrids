import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_assets.dart';
import '../../providers/game_settings_provider.dart';
import '../../core/enums/game_mode.dart';
import 'overworld_map_screen.dart';
import 'map_selection_screen.dart';
import 'multiplayer_mode_selection_screen.dart';
import 'settings_screen.dart';
import 'profile_screen.dart';

class GameHomeScreen extends ConsumerWidget {
  const GameHomeScreen({super.key});

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
            padding: const EdgeInsets.only(bottom: 16.0),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(width: 24),
                  _buildMenuButton(
                    context,
                    label: 'CAMPAIGN',
                    iconAsset: AppAssets.storyModeIcon,
                    onPressed: () {
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
                  const SizedBox(width: 24),
                  _buildMenuButton(
                    context,
                    label: 'MULTIPLAYER',
                    iconAsset: AppAssets.multiplayerIcon,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          settings: const RouteSettings(name: '/multiplayer_mode'),
                          builder: (context) => const MultiplayerModeSelectionScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildMenuButton(
                    context,
                    label: 'PROFILE',
                    iconData: Icons.person_rounded,
                    onPressed: () {
                      ref.read(gameSettingsProvider.notifier).restoreCampaignSettings();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfileScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                  _buildMenuButton(
                    context,
                    label: 'SETTINGS',
                    iconAsset: AppAssets.settingsIcon,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(width: 24),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context, {
    required String label,
    String? iconAsset,
    IconData? iconData,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: onPressed,
          icon: iconAsset != null
              ? AppAssetImage(iconAsset, width: 55, height: 55)
              : Icon(iconData, size: 45, color: Colors.black),
          style: IconButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Colors.black,
            minimumSize: const Size(100, 70),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
          ),
        ),
      ],
    );
  }
}
