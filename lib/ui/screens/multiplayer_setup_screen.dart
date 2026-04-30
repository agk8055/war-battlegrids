import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_settings_provider.dart';
import '../../providers/simulation_provider.dart';
import 'game_screen.dart';

class MultiplayerSetupScreen extends ConsumerStatefulWidget {
  const MultiplayerSetupScreen({super.key});

  @override
  ConsumerState<MultiplayerSetupScreen> createState() => _MultiplayerSetupScreenState();
}

class _MultiplayerSetupScreenState extends ConsumerState<MultiplayerSetupScreen> {
  final TextEditingController _p1Controller = TextEditingController(text: 'PLAYER 1');
  final TextEditingController _p2Controller = TextEditingController(text: 'PLAYER 2');
  final TextEditingController _thresholdController = TextEditingController(text: '100');

  final List<String> _availableSigils = [
    'assets/symbols/fire.png',
    'assets/symbols/tiger.png',
    'assets/symbols/flash.png',
    'assets/icons/hacker.png',
    'assets/icons/lion.png',
    'assets/icons/wolf.png',
    'assets/icons/bull.png',
    'assets/icons/shuriken.png',
  ];

  final List<Color> _availableColors = [
    Colors.blue,
    Colors.red,
    Colors.green,
    Colors.orange,
    Colors.purple,
    Colors.yellow,
    Colors.cyan,
    Colors.pink,
  ];

  late String _p1Symbol;
  late String _p2Symbol;
  late Color _p1Color;
  late Color _p2Color;

  @override
  void initState() {
    super.initState();
    final settings = ref.read(gameSettingsProvider);
    _p1Symbol = settings.player1Symbol;
    _p2Symbol = settings.player2Symbol;
    _p1Color = Color(settings.player1Color);
    _p2Color = Color(settings.player2Color);

    // Ensure symbols are in available list or pick defaults
    if (!_availableSigils.contains(_p1Symbol)) _p1Symbol = _availableSigils[0];
    if (!_availableSigils.contains(_p2Symbol)) _p2Symbol = _availableSigils[1];
  }

  @override
  void dispose() {
    _p1Controller.dispose();
    _p2Controller.dispose();
    _thresholdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('MATCH SETUP', style: TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        foregroundColor: theme.colorScheme.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('COMMANDER NAMES'),
            const SizedBox(height: 16),
            _buildTextField(_p1Controller, 'PLAYER 1', _p1Color),
            const SizedBox(height: 24),
            _buildSigilSelector(
              label: 'PLAYER 1 SIGIL',
              currentSigil: _p1Symbol,
              unavailableSigil: _p2Symbol,
              onSigilSelected: (sigil) => setState(() => _p1Symbol = sigil),
            ),
            const SizedBox(height: 12),
            _buildColorSelector(
              currentColor: _p1Color,
              unavailableColor: _p2Color,
              onColorSelected: (color) => setState(() => _p1Color = color),
            ),
            const SizedBox(height: 32),
            _buildTextField(_p2Controller, 'PLAYER 2', _p2Color),
            const SizedBox(height: 24),
            _buildSigilSelector(
              label: 'PLAYER 2 SIGIL',
              currentSigil: _p2Symbol,
              unavailableSigil: _p1Symbol,
              onSigilSelected: (sigil) => setState(() => _p2Symbol = sigil),
            ),
            const SizedBox(height: 12),
            _buildColorSelector(
              currentColor: _p2Color,
              unavailableColor: _p1Color,
              onColorSelected: (color) => setState(() => _p2Color = color),
            ),
            const SizedBox(height: 48),
            _buildSectionTitle('KINGDOM ATTACK THRESHOLD'),
            const SizedBox(height: 8),
            Text(
              'Points required to unlock direct kingdom assault.',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 12),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 150,
              child: _buildTextField(
                _thresholdController, 
                'THRESHOLD', 
                theme.colorScheme.primary,
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
                  
                  notifier.setPlayerSymbols(_p1Symbol, _p2Symbol);
                  notifier.setPlayerColors(_p1Color.toARGB32(), _p2Color.toARGB32());
                  
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

  Widget _buildSigilSelector({
    required String label,
    required String currentSigil,
    required String unavailableSigil,
    required Function(String) onSigilSelected,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 11, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableSigils.length,
            itemBuilder: (context, index) {
              final sigil = _availableSigils[index];
              final isSelected = sigil == currentSigil;
              final isUnavailable = sigil == unavailableSigil;
              return GestureDetector(
                onTap: isUnavailable ? null : () => onSigilSelected(sigil),
                child: Opacity(
                  opacity: isUnavailable ? 0.2 : 1.0,
                  child: Container(
                    width: 50,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.2) : Colors.black26,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: isSelected ? Theme.of(context).colorScheme.primary : (isUnavailable ? Colors.transparent : Colors.white12)),
                    ),
                    padding: const EdgeInsets.all(8),
                    child: Image.asset(sigil, color: isSelected ? null : Colors.white54),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildColorSelector({
    required Color currentColor,
    required Color unavailableColor,
    required Function(Color) onColorSelected,
  }) {
    return SizedBox(
      height: 30,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _availableColors.length,
        itemBuilder: (context, index) {
          final color = _availableColors[index];
          final isSelected = color.toARGB32() == currentColor.toARGB32();
          final isUnavailable = color.toARGB32() == unavailableColor.toARGB32();
          return GestureDetector(
            onTap: isUnavailable ? null : () => onColorSelected(color),
            child: Opacity(
              opacity: isUnavailable ? 0.2 : 1.0,
              child: Container(
                width: 30,
                margin: const EdgeInsets.only(right: 12),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? Colors.white : Colors.transparent,
                    width: 2,
                  ),
                  boxShadow: isSelected ? [
                    BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 8, spreadRadius: 1)
                  ] : [],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: TextStyle(
        color: Theme.of(context).colorScheme.primary,
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
          borderSide: BorderSide(color: accentColor.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(12),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: accentColor),
          borderRadius: BorderRadius.circular(12),
        ),
        filled: true,
        fillColor: Colors.white.withValues(alpha: 0.05),
      ),
    );
  }
}
