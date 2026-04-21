import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

class PauseOverlay extends ConsumerWidget {
  final VoidCallback onResume;
  final VoidCallback onQuit;
  final VoidCallback onSettings;

  const PauseOverlay({
    super.key,
    required this.onResume,
    required this.onQuit,
    required this.onSettings,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Positioned.fill(
      child: Container(
        color: Colors.black.withValues(alpha: 0.9), // Solid dark overlay
        child: Center(
          child: SingleChildScrollView(
            child: Container(
              width: 400,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: double.infinity,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        "BATTLE PAUSED",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.sairaStencilOne(
                          fontSize: 42,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                          letterSpacing: 6.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    height: 2,
                    width: 40,
                    color: primaryColor.withValues(alpha: 0.4),
                  ),
                  const SizedBox(height: 48),
                  _buildPremiumButton(
                    context,
                    label: "RESUME BATTLE",
                    icon: Icons.play_arrow_rounded,
                    onPressed: onResume,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 24),
                  _buildPremiumButton(
                    context,
                    label: "SETTINGS",
                    icon: Icons.settings_outlined,
                    onPressed: onSettings,
                    primaryColor: primaryColor,
                  ),
                  const SizedBox(height: 24),
                  _buildPremiumButton(
                    context,
                    label: "ABANDON BATTLE",
                    icon: Icons.close_rounded,
                    onPressed: onQuit,
                    primaryColor: primaryColor,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPremiumButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color primaryColor,
  }) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black,
        minimumSize: const Size(double.infinity, 64),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 28),
          const SizedBox(width: 16),
          Text(
            label,
            style: GoogleFonts.sairaStencilOne(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }
}
