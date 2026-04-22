import 'package:flutter/material.dart';
import 'map_selection_screen.dart';

class MultiplayerModeSelectionScreen extends StatelessWidget {
  const MultiplayerModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> modes = [
      {
        'title': 'ON-DEVICE',
        'subtitle': 'Local same-screen play',
        'icon': Icons.phonelink_setup_rounded,
        'enabled': true,
        'onTap': () {
          Navigator.push(
            context,
            MaterialPageRoute(
              settings: const RouteSettings(name: '/map_selection'),
              builder: (context) => const MapSelectionScreen(),
            ),
          );
        },
      },
      {
        'title': 'BLUETOOTH',
        'subtitle': 'Nearby connection',
        'icon': Icons.bluetooth_audio_rounded,
        'enabled': false,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Bluetooth Multiplayer coming soon!')),
          );
        },
      },
      {
        'title': 'ONLINE',
        'subtitle': 'Global battlefield',
        'icon': Icons.public_rounded,
        'enabled': false,
        'onTap': () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Online Multiplayer coming soon!')),
          );
        },
      },
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('MULTIPLAYER MODES', style: TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CHOOSE YOUR BATTLEFRONT',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: modes.map((mode) {
                  final bool isEnabled = mode['enabled'];
                  
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: GestureDetector(
                      onTap: mode['onTap'],
                      child: Container(
                        width: 160, // Reduced fixed width for vertical rectangle look
                        decoration: BoxDecoration(
                          color: isEnabled ? Colors.grey[900] : Colors.grey[900]!.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isEnabled 
                                ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.5)
                                : Colors.white10,
                            width: 2,
                          ),
                          boxShadow: isEnabled ? [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                              blurRadius: 15,
                              spreadRadius: 2,
                            )
                          ] : null,
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              mode['icon'],
                              size: 50, // Slightly smaller icon
                              color: isEnabled 
                                  ? Theme.of(context).colorScheme.primary 
                                  : Colors.grey[700],
                            ),
                            const SizedBox(height: 20),
                            Text(
                              mode['title'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: isEnabled ? Colors.white : Colors.grey[600],
                                fontSize: 14, // Slightly smaller font
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12.0),
                              child: Text(
                                mode['subtitle'],
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: isEnabled ? Colors.white54 : Colors.grey[800],
                                  fontSize: 10,
                                ),
                              ),
                            ),
                            if (!isEnabled) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.white10,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'SOON',
                                  style: TextStyle(
                                    color: Colors.white24,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
