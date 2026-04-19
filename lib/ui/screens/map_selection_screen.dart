import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../core/enums/game_mode.dart';
import 'multiplayer_setup_screen.dart';
import '../../constants.dart';

class MapSelectionScreen extends ConsumerWidget {
  const MapSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Currently only one map available as requested
    final List<Map<String, String>> availableMaps = [
      {
        'name': 'Standard 25x25',
        'path': '25x25_map.tmx',
        'description': 'A balanced 25x25 grid for local warfare.',
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SELECT BATTLEFIELD', style: TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        foregroundColor: kMainThemeColor,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'MULTIPLAYER MODE',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                itemCount: availableMaps.length,
                itemBuilder: (context, index) {
                  final map = availableMaps[index];
                  return GestureDetector(
                    onTap: () {
                      // 1. Update Game Settings
                      ref.read(gameSettingsProvider.notifier).setMode(GameMode.multiplayer);
                      ref.read(gameSettingsProvider.notifier).setSelectedMap(map['path']!);
                      
                      // 2. Navigate to Setup
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const MultiplayerSetupScreen(),
                        ),
                      );
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: kMainThemeColor.withOpacity(0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            Positioned.fill(
                              child: Opacity(
                                opacity: 0.1,
                                child: Icon(Icons.grid_4x4, size: 80, color: kMainThemeColor),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.landscape_rounded, color: kMainThemeColor, size: 36),
                                  const SizedBox(height: 8),
                                  Text(
                                    map['name']!.toUpperCase(),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                      letterSpacing: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "CLICK TO SELECT",
                                    style: TextStyle(
                                      color: kMainThemeColor.withOpacity(0.7),
                                      fontSize: 9,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                            ),
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
    );
  }
}
