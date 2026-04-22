import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import '../../core/enums/game_mode.dart';
import 'multiplayer_setup_screen.dart';

class MapSelectionScreen extends ConsumerWidget {
  final bool isBluetoothMode;
  const MapSelectionScreen({super.key, this.isBluetoothMode = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Currently only one map available as requested
    final List<Map<String, String>> availableMaps = [
      {
        'name': 'Northern Forest',
        'path': '15x15_northern_forest_map.tmx',
        'description': 'A dense 15x15 forest environment.',
      },
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
        foregroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(40, 16, 16, 16),
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
                      
                      if (isBluetoothMode) {
                        Navigator.pop(context, map);
                      } else {
                        // 2. Navigate to Setup
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MultiplayerSetupScreen(),
                          ),
                        );
                      }
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[900],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.4),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
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
                                child: Icon(Icons.grid_4x4, size: 80, color: Theme.of(context).colorScheme.primary),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.landscape_rounded, color: Theme.of(context).colorScheme.primary, size: 36),
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
                                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.7),
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
