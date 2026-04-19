import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants.dart';
import '../../providers/game_settings_provider.dart';
import '../../core/enums/game_mode.dart';
import 'overworld_map_screen.dart';
import 'map_selection_screen.dart';

class GameHomeScreen extends ConsumerWidget {
  const GameHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            Text(
              'WAR : BATTLEGRIDS',
              style: GoogleFonts.sairaStencilOne(
                color: kMainThemeColor,
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 4.0,
              ),
            ),
            Expanded(
              child: Center(
                child: Image.asset(
                  'assets/images/home_banner.png',
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
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
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: kMainThemeColor,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(56, 56),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'STORY MODE',
                        style: TextStyle(
                          color: kMainThemeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              settings: const RouteSettings(name: '/map_selection'),
                              builder: (context) => const MapSelectionScreen(),
                            ),
                          );
                        },
                        icon: const Icon(Icons.people_rounded, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: kMainThemeColor,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(56, 56),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'MULTIPLAYER',
                        style: TextStyle(
                          color: kMainThemeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 24),
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: () {
                          // Navigate to Settings
                        },
                        icon: const Icon(Icons.settings_rounded, size: 28),
                        style: IconButton.styleFrom(
                          backgroundColor: kMainThemeColor,
                          foregroundColor: Colors.black,
                          minimumSize: const Size(56, 56),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Text(
                        'SETTINGS',
                        style: TextStyle(
                          color: kMainThemeColor,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.0,
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
    );
  }
}
