import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../providers/game_settings_provider.dart';
import 'tutorial_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Minimal Panel Container
// ─────────────────────────────────────────────────────────────────────────────
class _Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _Panel({
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF141416),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      padding: padding,
      child: child,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;

  const _SectionLabel(this.text, {required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 3,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 2,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Settings Screen
// ─────────────────────────────────────────────────────────────────────────────
enum SettingsSection {
  audio,
  tutorial,
}

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
    with TickerProviderStateMixin {
  SettingsSection _selectedSection = SettingsSection.audio;

  late AnimationController _fadeController;
  late AnimationController _slideController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _slideController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
        .animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    Future.delayed(const Duration(milliseconds: 50), () {
      if (mounted) {
        _fadeController.forward();
        _slideController.forward();
      }
    });
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameSettingsProvider);
    final settingsNotifier = ref.read(gameSettingsProvider.notifier);
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0C0C0E),
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: SlideTransition(
            position: _slideAnim,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                children: [
                  _buildTopBar(primary),
                  const SizedBox(height: 12),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // ── Left Minimal Sidebar ─────────────────────────────
                        SizedBox(
                          width: 220,
                          child: _Panel(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                                  child: _SectionLabel('SECTIONS', color: primary),
                                ),
                                const SizedBox(height: 12),
                                _buildSidebarItem(
                                  section: SettingsSection.audio,
                                  title: 'AUDIO',
                                  subtitle: 'Volume & sounds',
                                  icon: Icons.volume_up_outlined,
                                  primary: primary,
                                ),
                                const SizedBox(height: 6),
                                _buildSidebarItem(
                                  section: SettingsSection.tutorial,
                                  title: 'TUTORIAL',
                                  subtitle: 'Drills & mechanics',
                                  icon: Icons.school_outlined,
                                  primary: primary,
                                ),
                              
                                
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),

                        // ── Right Content Area ───────────────────────────────
                        Expanded(
                          child: _Panel(
                            padding: const EdgeInsets.all(20),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _selectedSection == SettingsSection.audio
                                  ? _buildAudioSection(
                                      key: const ValueKey('audio_section'),
                                      settings: settings,
                                      settingsNotifier: settingsNotifier,
                                      primary: primary,
                                    )
                                  : _buildTutorialSection(
                                      key: const ValueKey('tutorial_section'),
                                      primary: primary,
                                    ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(Color primary) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
            ),
            child: const Icon(Icons.chevron_left, color: Colors.white70, size: 20),
          ),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'SETTINGS',
              style: GoogleFonts.sairaStencilOne(
                color: Colors.white,
                fontSize: 16,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Audio preferences and combat tutorial',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 11,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSidebarItem({
    required SettingsSection section,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color primary,
  }) {
    final isSelected = _selectedSection == section;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          if (_selectedSection != section) {
            setState(() {
              _selectedSection = section;
            });
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? primary.withValues(alpha: 0.12)
                : Colors.transparent,
            border: Border.all(
              color: isSelected
                  ? primary.withValues(alpha: 0.4)
                  : Colors.transparent,
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? primary : Colors.white54,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontSize: 12,
                        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.3),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  

  Widget _buildAudioSection({
    required Key key,
    required dynamic settings,
    required dynamic settingsNotifier,
    required Color primary,
  }) {
    return SingleChildScrollView(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('AUDIO SETTINGS', color: primary),
          const SizedBox(height: 20),
          _buildSettingTile(
            title: 'Music',
            subtitle: 'Soundtrack and background themes',
            trailing: Switch(
              value: settings.musicEnabled,
              onChanged: (value) => settingsNotifier.setMusicEnabled(value),
              activeTrackColor: primary.withValues(alpha: 0.4),
              activeThumbColor: primary,
            ),
          ),
          const SizedBox(height: 10),
          _buildVolumeSlider(
            title: 'Music Volume',
            value: settings.musicVolume,
            enabled: settings.musicEnabled,
            onChanged: (v) => settingsNotifier.setMusicVolume(v),
            primary: primary,
          ),
          const SizedBox(height: 20),
          Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
          const SizedBox(height: 20),
          _buildSettingTile(
            title: 'Sound Effects',
            subtitle: 'Combat actions and UI feedback sounds',
            trailing: Switch(
              value: settings.sfxEnabled,
              onChanged: (value) => settingsNotifier.setSfxEnabled(value),
              activeTrackColor: primary.withValues(alpha: 0.4),
              activeThumbColor: primary,
            ),
          ),
          const SizedBox(height: 10),
          _buildVolumeSlider(
            title: 'SFX Volume',
            value: settings.sfxVolume,
            enabled: settings.sfxEnabled,
            onChanged: (v) => settingsNotifier.setSfxVolume(v),
            primary: primary,
          ),
        ],
      ),
    );
  }

  Widget _buildTutorialSection({
    required Key key,
    required Color primary,
  }) {
    return SingleChildScrollView(
      key: key,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionLabel('COMBAT DRILL', color: primary),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF19191C),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Interactive Battle Drill',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Replay the step-by-step combat drill on the Northern Forest front to review mechanics.',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.45),
                          fontSize: 12,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primary,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TutorialScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 18),
                  label: const Text(
                    'PLAY DRILL',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionLabel('TOPICS COVERED', color: Colors.white70),
          const SizedBox(height: 12),
          _buildDrillTopic(
            icon: Icons.grid_4x4_rounded,
            title: '1. Deployment & Tile Control',
            description: 'Learn how to strategically deploy troops and claim vital strategic tiles.',
          ),
          const SizedBox(height: 8),
          _buildDrillTopic(
            icon: Icons.shield_outlined,
            title: '2. Flanking & Capture Mechanics',
            description: 'Trap opposing hostile units by surrounding their ranks with coordinated strikes.',
          ),
          const SizedBox(height: 8),
          _buildDrillTopic(
            icon: Icons.military_tech_outlined,
            title: '3. Siege & Victory Conditions',
            description: 'Breach the stronghold core and declare dominion over the territory.',
          ),
        ],
      ),
    );
  }

  Widget _buildDrillTopic({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF19191C),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.white54),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
        trailing,
      ],
    );
  }

  Widget _buildVolumeSlider({
    required String title,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
    required Color primary,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.35),
                fontSize: 10,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            Text(
              '${(value * 100).toInt()}%',
              style: TextStyle(
                color: enabled ? primary : Colors.white.withValues(alpha: 0.2),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: primary,
            inactiveTrackColor: Colors.white.withValues(alpha: 0.08),
            thumbColor: primary,
            overlayColor: primary.withValues(alpha: 0.1),
          ),
          child: Slider(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }
}