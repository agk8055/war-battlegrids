import 'package:flutter/material.dart';
import '../../constants.dart';
import 'overworld_map_screen.dart';

class GameHomeScreen extends StatelessWidget {
  const GameHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 20),
            const Text(
              'WAR : BATTLEGRIDS',
              style: TextStyle(
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
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const StoryModeScreen(),
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
                          // Navigate to Multiplayer
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
