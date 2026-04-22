import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_settings_provider.dart';
import 'main_menu_screen.dart';

class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen> {
  final TextEditingController _nameController = TextEditingController();
  String _selectedSymbol = 'assets/symbols/fire.png';
  final List<String> _symbols = [
    'assets/symbols/fire.png',
    'assets/symbols/tiger.png',
    'assets/symbols/flash.png',
    'assets/icons/hacker.png',
    'assets/icons/lion.png',
    'assets/icons/wolf.png',
    'assets/icons/bull.png',
    'assets/icons/shuriken.png',
  ];

  Future<void> _saveAndContinue() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Kingdom name')),
      );
      return;
    }

    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setString('kingdom_name', name);
    await prefs.setString('kingdom_symbol', _selectedSymbol);
    await prefs.setBool('is_first_run', false);

    // Update the provider so the rest of the app sees the changes immediately
    ref.read(gameSettingsProvider.notifier).setPlayerNames(name, 'AI');
    ref.read(gameSettingsProvider.notifier).setPlayerSymbols(_selectedSymbol, 'assets/icons/eagle.png');

    if (!mounted) return;

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const GameHomeScreen()),
    );
  }

  String _getSigilDescription(String path) {
    final name = path.split('/').last.split('.').first;
    switch (name) {
      case 'fire':
        return 'The FIRE sigil represents unyielding passion and destruction.';
      case 'tiger':
        return 'The TIGER sigil represents fierce independence and raw strength.';
      case 'flash':
        return 'The FLASH sigil represents lightning speed and overwhelming energy.';
      case 'hacker':
        return 'The HACKER sigil represents superior intellect and tactical subversion.';
      case 'lion':
        return 'The LION sigil represents noble leadership and courageous heart.';
      case 'wolf':
        return 'The WOLF sigil represents sharp instincts and the strength of the pack.';
      case 'bull':
        return 'The BULL sigil represents stubborn resilience and unstoppable force.';
      case 'shuriken':
        return 'The SHURIKEN sigil represents silent lethality and perfect precision.';
      default:
        return 'The ${name.toUpperCase()} sigil represents your chosen path.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'WELCOME, COMMANDER',
                style: GoogleFonts.sairaStencilOne(
                  color: Theme.of(context).colorScheme.primary,
                  fontSize: 35,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 3.0,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                'ESTABLISH YOUR KINGDOM',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                ),
              ),
              const SizedBox(height: 30),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'KINGDOM NAME',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _nameController,
                          style: const TextStyle(color: Colors.white, fontSize: 18),
                          decoration: InputDecoration(
                            filled: true,
                            fillColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                            hintText: 'Enter name...',
                            hintStyle: TextStyle(color: Colors.white.withValues(alpha: 0.3)),
                            enabledBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: Theme.of(context).colorScheme.primary, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderSide: const BorderSide(color: Colors.white, width: 2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            prefixIcon: Icon(Icons.fort_rounded, color: Theme.of(context).colorScheme.primary),
                          ),
                        ),
                        const SizedBox(height: 30),
                        ElevatedButton(
                          onPressed: _saveAndContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.primary,
                            foregroundColor: Colors.black,
                            minimumSize: const Size(double.infinity, 55),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'BEGIN REIGN',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, letterSpacing: 1.5),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 40),
                  Expanded(
                    flex: 1,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'CHOOSE YOUR SIGIL',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.white10, width: 1),
                            borderRadius: BorderRadius.circular(16),
                            color: Colors.white.withValues(alpha: 0.03),
                          ),
                          child: Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            alignment: WrapAlignment.center,
                            children: _symbols.map((symbol) {
                              final isSelected = _selectedSymbol == symbol;
                              return GestureDetector(
                                onTap: () {
                                  setState(() {
                                    _selectedSymbol = symbol;
                                  });
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: isSelected ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15) : Colors.transparent,
                                    border: Border.all(
                                      color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white10,
                                      width: 2.5,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                                        blurRadius: 10,
                                        spreadRadius: 1,
                                      )
                                    ] : [],
                                  ),
                                  child: Image.asset(
                                    symbol,
                                    width: 45,
                                    height: 45,
                                    fit: BoxFit.contain,
                                    color: isSelected ? Theme.of(context).colorScheme.primary : Colors.white70,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                        const SizedBox(height: 15),
                        Center(
                          child: Text(
                            _getSigilDescription(_selectedSymbol),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
