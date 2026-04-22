import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_settings_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(gameSettingsProvider);
    final settingsNotifier = ref.read(gameSettingsProvider.notifier);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('SETTINGS', style: TextStyle(letterSpacing: 2)),
        backgroundColor: Colors.transparent,
        foregroundColor: Theme.of(context).colorScheme.primary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionHeader(context, 'GENERAL'),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              title: 'KINGDOM NAME',
              subtitle: settings.player1Name,
              trailing: IconButton(
                icon: Icon(Icons.edit_rounded, color: Theme.of(context).colorScheme.primary),
                onPressed: () => _showNameDialog(context, ref, settings.player1Name),
              ),
            ),
            const SizedBox(height: 32),
            _buildSectionHeader(context, 'AUDIO'),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              title: 'MUSIC',
              subtitle: 'Background soundtrack',
              trailing: Switch(
                value: settings.musicEnabled,
                onChanged: (value) => settingsNotifier.setMusicEnabled(value),
                activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildSettingTile(
              context,
              title: 'MUSIC VOLUME',
              subtitle: '${(settings.musicVolume * 100).toInt()}%',
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: settings.musicVolume,
                  onChanged: settings.musicEnabled 
                      ? (value) => settingsNotifier.setMusicVolume(value)
                      : null,
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Colors.white12,
                ),
              ),
            ),
            const SizedBox(height: 16),
            _buildSettingTile(
              context,
              title: 'SFX',
              subtitle: 'Sound effects',
              trailing: Switch(
                value: settings.sfxEnabled,
                onChanged: (value) => settingsNotifier.setSfxEnabled(value),
                activeTrackColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                activeThumbColor: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 8),
            _buildSettingTile(
              context,
              title: 'SFX VOLUME',
              subtitle: '${(settings.sfxVolume * 100).toInt()}%',
              trailing: SizedBox(
                width: 150,
                child: Slider(
                  value: settings.sfxVolume,
                  onChanged: settings.sfxEnabled 
                      ? (value) => settingsNotifier.setSfxVolume(value)
                      : null,
                  activeColor: Theme.of(context).colorScheme.primary,
                  inactiveColor: Colors.white12,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Center(
              child: Column(
                children: [
                  Icon(
                    Icons.settings_suggest_rounded,
                    size: 60,
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'COMMAND CENTER v1.0.0',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.5),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Container(
      padding: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
      ),
      child: Text(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.primary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
          letterSpacing: 2,
        ),
      ),
    );
  }

  Widget _buildSettingTile(
    BuildContext context, {
    required String title,
    required String subtitle,
    required Widget trailing,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12).copyWith(left: 16),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          trailing,
        ],
      ),
    );
  }

  void _showNameDialog(BuildContext context, WidgetRef ref, String currentName) {
    final controller = TextEditingController(text: currentName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text('EDIT KINGDOM NAME', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontSize: 16)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Theme.of(context).colorScheme.primary)),
          ),
          maxLength: 15,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white38)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                ref.read(gameSettingsProvider.notifier).setPlayer1Name(controller.text.trim());
              }
              Navigator.pop(context);
            },
            child: Text('SAVE', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
          ),
        ],
      ),
    );
  }
}
