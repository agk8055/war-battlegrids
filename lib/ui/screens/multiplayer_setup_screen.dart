import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import 'game_screen.dart';
import '../../constants.dart';

class MultiplayerSetupScreen extends ConsumerStatefulWidget {
  const MultiplayerSetupScreen({super.key});

  @override
  ConsumerState<MultiplayerSetupScreen> createState() => _MultiplayerSetupScreenState();
}

class _MultiplayerSetupScreenState extends ConsumerState<MultiplayerSetupScreen> {
  final TextEditingController _p1Controller = TextEditingController(text: 'PLAYER 1');
  final TextEditingController _p2Controller = TextEditingController(text: 'PLAYER 2');
  final TextEditingController _thresholdController = TextEditingController(text: '100');

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('MATCH SETUP', style: TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        foregroundColor: kMainThemeColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('COMMANDER NAMES'),
            const SizedBox(height: 16),
            _buildTextField(_p1Controller, 'PLAYER 1', Colors.blueAccent),
            const SizedBox(height: 16),
            _buildTextField(_p2Controller, 'PLAYER 2', Colors.redAccent),
            const SizedBox(height: 40),
            _buildSectionTitle('KINGDOM ATTACK THRESHOLD'),
            const SizedBox(height: 8),
            Text(
              'Points required to unlock direct kingdom assault.',
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 150,
              child: _buildTextField(
                _thresholdController, 
                'THRESHOLD', 
                kMainThemeColor,
                isNumeric: true,
              ),
            ),
            const SizedBox(height: 60),
            Center(
              child: ElevatedButton(
                onPressed: () {
                  // 1. Save settings
                  final notifier = ref.read(gameSettingsProvider.notifier);
                  notifier.setPlayerNames(
                    _p1Controller.text.trim().isEmpty ? 'PLAYER 1' : _p1Controller.text.trim(),
                    _p2Controller.text.trim().isEmpty ? 'PLAYER 2' : _p2Controller.text.trim(),
                  );
                  
                  final int threshold = int.tryParse(_thresholdController.text) ?? 100;
                  notifier.setKingdomAttackThreshold(threshold);

                  // 2. Reset simulation with new config
                  ref.read(simulationProvider.notifier).reset();

                  // 3. Start Game
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      settings: const RouteSettings(name: '/game'),
                      builder: (context) => const GameScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(250, 60),
                ),
                child: const Text('START BATTLE'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        color: kMainThemeColor,
        fontSize: 14,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.5,
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String label, 
    Color accentColor, 
    {bool isNumeric = false}
  ) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.white),
      keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: accentColor),
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor.withOpacity(0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withOpacity(0.05),
      ),
    );
  }
}
