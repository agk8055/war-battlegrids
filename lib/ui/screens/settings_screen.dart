import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/constants/app_assets.dart';
import '../../core/services/audio_service.dart';
import '../../providers/game_settings_provider.dart';
import 'tutorial_screen.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Settings Navigation Tabs
// ─────────────────────────────────────────────────────────────────────────────
enum SettingsSection {
  audio,
  tutorial,
}

// ─────────────────────────────────────────────────────────────────────────────
//  Settings Screen (Medieval Tome / Codex Theme)
// ─────────────────────────────────────────────────────────────────────────────
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
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 350),
    );
    _slideController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );

    _fadeAnim = CurvedAnimation(parent: _fadeController, curve: Curves.easeIn);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.easeOutCubic));

    _fadeController.forward();
    _slideController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    _slideController.dispose();
    super.dispose();
  }

  void _playClickSfx() {
    ref.read(audioServiceProvider).playSfx(AppAssets.sfxClick);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(gameSettingsProvider);
    final settingsNotifier = ref.read(gameSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: const Color(0xFF0C0908),
      body: Stack(
        children: [
          // ── 1. Parchment Book Background Image ───────────────────────────
          Positioned.fill(
            child: AppAssetImage(
              AppAssets.settingsBg,
              fit: BoxFit.fill,
            ),
          ),

          // ── 2. Subtle Vignette Depth Overlay ─────────────────────────────
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.3,
                  colors: [
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.22),
                  ],
                ),
              ),
            ),
          ),

          // ── 3. Top-Left Back Button (Moved further left) ────────────────
          Positioned(
            top: 10,
            left: 8,
            child: SafeArea(
              child: _buildBackButton(),
            ),
          ),

          // ── 4. Main Grimoire Book Content (Proportional to settings_bg) ───
          Positioned.fill(
            child: SafeArea(
              child: FadeTransition(
                opacity: _fadeAnim,
                child: SlideTransition(
                  position: _slideAnim,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final w = constraints.maxWidth;
                      final h = constraints.maxHeight;

                      return Padding(
                        padding: EdgeInsets.fromLTRB(
                          w * 0.05, // Aligns with left parchment edge
                          h * 0.09, // Clears top frame and back button
                          w * 0.05, // Aligns with right parchment edge
                          h * 0.07, // Clears bottom wood frame
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // ── Left Page: Exactly 29% (Left Parchment) ────
                            Expanded(
                              flex: 29,
                              child: _buildLeftPage(),
                            ),

                            // ── Center Tome Spine (Ring Bindings): 6% ──────
                            const Expanded(
                              flex: 6,
                              child: SizedBox.shrink(),
                            ),

                            // ── Right Page: Exactly 65% (Right Parchment) ───
                            Expanded(
                              flex: 65,
                              child: _buildRightPage(
                                settings: settings,
                                settingsNotifier: settingsNotifier,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Back Button (Matching Profile Screen size 40x40)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildBackButton() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _playClickSfx();
          Navigator.pop(context);
        },
        borderRadius: BorderRadius.circular(10),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF26140B).withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFFE5B869),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.chevron_left,
            color: Color(0xFFE5B869),
            size: 22,
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Left Page: Navigation Tabs & Tome Stamp (Scrollable)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildLeftPage() {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(top: 18, right: 4, bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Page Header
          Padding(
            padding: const EdgeInsets.only(top: 2, bottom: 8, left: 2),
            child: Row(
              children: [
                Container(
                  width: 3,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B2500),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  'CHAPTERS',
                  style: GoogleFonts.sairaStencilOne(
                    color: const Color(0xFF422817),
                    fontSize: 11,
                    letterSpacing: 2,
                  ),
                ),
              ],
            ),
          ),

          // Navigation Items
          _buildChapterItem(
            section: SettingsSection.audio,
            title: 'AUDIO & SOUNDS',
            subtitle: 'War anthems & SFX',
            icon: Icons.volume_up_rounded,
          ),
          const SizedBox(height: 7),
          _buildChapterItem(
            section: SettingsSection.tutorial,
            title: 'COMBAT DRILLS',
            subtitle: 'Tactics & drills',
            icon: Icons.shield_rounded,
          ),

          const SizedBox(height: 18),

          // Codex Footer Seal
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF381F10).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: const Color(0xFF5A3416).withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B2500).withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFF8B2500).withValues(alpha: 0.35),
                    ),
                  ),
                  child: const Icon(
                    Icons.military_tech_rounded,
                    size: 13,
                    color: Color(0xFF8B2500),
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REALM ARCHIVES',
                        style: GoogleFonts.sairaStencilOne(
                          color: const Color(0xFF422817),
                          fontSize: 9.5,
                          letterSpacing: 0.8,
                        ),
                      ),
                      Text(
                        'Codex v1.0',
                        style: TextStyle(
                          color: const Color(0xFF6B482E).withValues(alpha: 0.85),
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChapterItem({
    required SettingsSection section,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final isSelected = _selectedSection == section;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          _playClickSfx();
          if (_selectedSection != section) {
            setState(() {
              _selectedSection = section;
            });
          }
        },
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: isSelected
                ? const Color(0xFF2C160B)
                : const Color(0xFF4A2A14).withValues(alpha: 0.06),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFFC48825)
                  : const Color(0xFF5A3416).withValues(alpha: 0.15),
              width: isSelected ? 1.5 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: const Color(0xFF2C160B).withValues(alpha: 0.35),
                      blurRadius: 5,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  color: isSelected
                      ? const Color(0xFF3E2010)
                      : const Color(0xFF381F10).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(
                  icon,
                  size: 15,
                  color: isSelected
                      ? const Color(0xFFE5B869)
                      : const Color(0xFF5A3416),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.sairaStencilOne(
                        color: isSelected
                            ? const Color(0xFFFFF6E5)
                            : const Color(0xFF3B2012),
                        fontSize: 11,
                        letterSpacing: 0.8,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: isSelected
                            ? const Color(0xFFE5B869).withValues(alpha: 0.85)
                            : const Color(0xFF7A5538),
                        fontSize: 9.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Container(
                  width: 5,
                  height: 5,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE5B869),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Right Page: Content (Audio / Tutorial)
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildRightPage({
    required dynamic settings,
    required dynamic settingsNotifier,
  }) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: _selectedSection == SettingsSection.audio
          ? _buildAudioPage(
              key: const ValueKey('audio_page'),
              settings: settings,
              settingsNotifier: settingsNotifier,
            )
          : _buildTutorialPage(
              key: const ValueKey('tutorial_page'),
            ),
    );
  }

  // ── Audio Settings Page ───────────────────────────────────────────────────
  Widget _buildAudioPage({
    required Key key,
    required dynamic settings,
    required dynamic settingsNotifier,
  }) {
    return SingleChildScrollView(
      key: key,
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 2, right: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Title
          _buildParchmentSectionHeader(
            title: 'ACOUSTIC ORDINANCES',
            subtitle: 'Soundtrack, heraldic melodies, and battlefield feedback',
          ),
          const SizedBox(height: 10),

          // Music Controls Card
          _buildParchmentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildToggleRow(
                  icon: Icons.music_note_rounded,
                  title: 'Battle Anthems & BGM',
                  subtitle: 'Grand royal soundtrack and atmospheric themes',
                  value: settings.musicEnabled,
                  onChanged: (val) {
                    _playClickSfx();
                    settingsNotifier.setMusicEnabled(val);
                  },
                ),
                const SizedBox(height: 8),
                _buildParchmentVolumeSlider(
                  title: 'ANTHEM VOLUME',
                  value: settings.musicVolume,
                  enabled: settings.musicEnabled,
                  onChanged: (v) => settingsNotifier.setMusicVolume(v),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // SFX Controls Card
          _buildParchmentCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildToggleRow(
                  icon: Icons.campaign_rounded,
                  title: 'Combat Sound Effects',
                  subtitle: 'Sword clashes, troop orders, and capture fanfares',
                  value: settings.sfxEnabled,
                  onChanged: (val) {
                    _playClickSfx();
                    settingsNotifier.setSfxEnabled(val);
                  },
                ),
                const SizedBox(height: 8),
                _buildParchmentVolumeSlider(
                  title: 'COMBAT SFX VOLUME',
                  value: settings.sfxVolume,
                  enabled: settings.sfxEnabled,
                  onChanged: (v) => settingsNotifier.setSfxVolume(v),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tutorial Section Page ─────────────────────────────────────────────────
  Widget _buildTutorialPage({
    required Key key,
  }) {
    return SingleChildScrollView(
      key: key,
      primary: false,
      physics: const AlwaysScrollableScrollPhysics(
        parent: BouncingScrollPhysics(),
      ),
      padding: const EdgeInsets.only(top: 28, right: 8, bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildParchmentSectionHeader(
            title: 'ROYAL COMBAT DOCTRINE',
            subtitle: 'Master territorial tactics, flanking maneuvers, and sieges',
          ),
          const SizedBox(height: 10),

          // Interactive Battle Drill Decree Card
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF381F10).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: const Color(0xFFC48825).withValues(alpha: 0.45),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B2500),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: const Color(0xFFE5B869),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.sports_kabaddi_rounded,
                    color: Color(0xFFFFF6E5),
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Interactive Battle Drill',
                        style: GoogleFonts.sairaStencilOne(
                          color: const Color(0xFF2E190E),
                          fontSize: 12.5,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Replay the step-by-step battlefield drill on the Northern Forest front to sharpen your command instincts.',
                        style: TextStyle(
                          color: const Color(0xFF5A3822).withValues(alpha: 0.9),
                          fontSize: 10.5,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B2500),
                    foregroundColor: const Color(0xFFFFF6E5),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(6),
                      side: const BorderSide(
                        color: Color(0xFFE5B869),
                        width: 1.2,
                      ),
                    ),
                  ),
                  onPressed: () {
                    _playClickSfx();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const TutorialScreen(),
                      ),
                    );
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 17, color: Color(0xFFE5B869)),
                  label: Text(
                    'PLAY DRILL',
                    style: GoogleFonts.sairaStencilOne(
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                      color: const Color(0xFFFFF6E5),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // Topics Overview
          Row(
            children: [
              Container(
                width: 3,
                height: 11,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B2500),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 7),
              Text(
                'TACTICAL MANUAL TOPICS',
                style: GoogleFonts.sairaStencilOne(
                  color: const Color(0xFF422817),
                  fontSize: 10.5,
                  letterSpacing: 1.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),

          _buildParchmentTopic(
            number: 'I',
            title: 'Deployment & Grid Superiority',
            description: 'Place champions strategically to lock down choke points and vital tiles.',
            icon: Icons.grid_4x4_rounded,
          ),
          const SizedBox(height: 5),
          _buildParchmentTopic(
            number: 'II',
            title: 'Flanking & Hostile Capture',
            description: 'Encircle hostile soldiers between friendly lines to capture their banners.',
            icon: Icons.shield_outlined,
          ),
          const SizedBox(height: 5),
          _buildParchmentTopic(
            number: 'III',
            title: 'Siege & Crown Dominion',
            description: 'Shatter opponent strongholds to assert absolute control over the realm.',
            icon: Icons.military_tech_outlined,
          ),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────────────────────────────────────
  //  Parchment UI Helpers & Components
  // ───────────────────────────────────────────────────────────────────────────
  Widget _buildParchmentSectionHeader({
    required String title,
    required String subtitle,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 3,
              height: 13,
              decoration: BoxDecoration(
                color: const Color(0xFF8B2500),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 7),
            Text(
              title,
              style: GoogleFonts.sairaStencilOne(
                color: const Color(0xFF381F10),
                fontSize: 12.5,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        const SizedBox(height: 1),
        Padding(
          padding: const EdgeInsets.only(left: 10),
          child: Text(
            subtitle,
            style: TextStyle(
              color: const Color(0xFF6B482E).withValues(alpha: 0.85),
              fontSize: 10,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildParchmentCard({required Widget child}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF381F10).withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF5A3416).withValues(alpha: 0.22),
          width: 1,
        ),
      ),
      child: child,
    );
  }

  Widget _buildToggleRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: const Color(0xFF381F10).withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(
              color: const Color(0xFF5A3416).withValues(alpha: 0.2),
            ),
          ),
          child: Icon(
            icon,
            size: 16,
            color: const Color(0xFF381F10),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.sairaStencilOne(
                  color: const Color(0xFF2E190E),
                  fontSize: 11.5,
                  letterSpacing: 0.8,
                ),
              ),
              Text(
                subtitle,
                style: TextStyle(
                  color: const Color(0xFF6B482E).withValues(alpha: 0.9),
                  fontSize: 9.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        // ── Custom Antique High-Contrast Switch ──
        _AntiqueToggleSwitch(
          value: value,
          onChanged: onChanged,
        ),
      ],
    );
  }

  Widget _buildParchmentVolumeSlider({
    required String title,
    required double value,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    final int percent = (value * 100).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.sairaStencilOne(
                color: enabled
                    ? const Color(0xFF5A3416)
                    : const Color(0xFF5A3416).withValues(alpha: 0.4),
                fontSize: 9.5,
                letterSpacing: 1,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: enabled
                    ? const Color(0xFF2C160B)
                    : const Color(0xFF4A2A14).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
                border: Border.all(
                  color: enabled
                      ? const Color(0xFFC48825)
                      : Colors.transparent,
                  width: 1,
                ),
              ),
              child: Text(
                '$percent%',
                style: GoogleFonts.sairaStencilOne(
                  color: enabled
                      ? const Color(0xFFE5B869)
                      : const Color(0xFF7A5538),
                  fontSize: 9.5,
                  letterSpacing: 1,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: const Color(0xFF8B2500),
            inactiveTrackColor: const Color(0xFF4A2A14).withValues(alpha: 0.25),
            thumbColor: const Color(0xFFC48825),
            overlayColor: const Color(0xFFC48825).withValues(alpha: 0.15),
          ),
          child: Slider(
            value: value,
            onChanged: enabled ? onChanged : null,
          ),
        ),
      ],
    );
  }

  Widget _buildParchmentTopic({
    required String number,
    required String title,
    required String description,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF381F10).withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: const Color(0xFF5A3416).withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: const Color(0xFF8B2500).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: const Color(0xFF8B2500).withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              number,
              style: GoogleFonts.sairaStencilOne(
                color: const Color(0xFF8B2500),
                fontSize: 9.5,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Icon(icon, size: 14, color: const Color(0xFF5A3416)),
          const SizedBox(width: 7),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.sairaStencilOne(
                    color: const Color(0xFF2E190E),
                    fontSize: 10.5,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    color: const Color(0xFF6B482E).withValues(alpha: 0.85),
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Custom Antique High-Contrast Toggle Switch
// ─────────────────────────────────────────────────────────────────────────────
class _AntiqueToggleSwitch extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _AntiqueToggleSwitch({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onChanged(!value),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 52,
        height: 26,
        padding: const EdgeInsets.all(2.5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: value
              ? const Color(0xFF2C160B)
              : const Color(0xFF1E1A17),
          border: Border.all(
            color: value
                ? const Color(0xFFE5B869)
                : const Color(0xFF6B5342),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: value
                  ? const Color(0xFFE5B869).withValues(alpha: 0.3)
                  : Colors.black.withValues(alpha: 0.3),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background State Text / Indicator
            Row(
              mainAxisAlignment:
                  value ? MainAxisAlignment.start : MainAxisAlignment.end,
              children: [
                Padding(
                  padding: EdgeInsets.only(
                    left: value ? 6 : 0,
                    right: value ? 0 : 6,
                  ),
                  child: Text(
                    value ? 'ON' : 'OFF',
                    style: GoogleFonts.sairaStencilOne(
                      color: value
                          ? const Color(0xFFE5B869)
                          : const Color(0xFF7A685B),
                      fontSize: 8.5,
                      letterSpacing: 0.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            // Moving Thumb Knob
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment:
                  value ? Alignment.centerRight : Alignment.centerLeft,
              child: Container(
                width: 19,
                height: 19,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: value
                        ? [
                            const Color(0xFFF7D58B),
                            const Color(0xFFC48825),
                            const Color(0xFF8B2500),
                          ]
                        : [
                            const Color(0xFF8A776A),
                            const Color(0xFF554438),
                            const Color(0xFF2E241E),
                          ],
                  ),
                  border: Border.all(
                    color: value
                        ? const Color(0xFFFFF6E5)
                        : const Color(0xFF9E8B7D),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 3,
                      offset: const Offset(0, 1.5),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: value
                          ? const Color(0xFFFFF6E5)
                          : const Color(0xFF1E1A17),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}