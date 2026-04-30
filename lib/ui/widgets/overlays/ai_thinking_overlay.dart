import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AiThinkingOverlay extends StatelessWidget {
  final Color color;

  const AiThinkingOverlay({super.key, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: double.infinity,
      color: Colors.black.withValues(alpha: 0.7), // Full screen black overlay
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(color: color, strokeWidth: 2.5),
            ),
            const SizedBox(height: 16),
            Text(
              "OPPONENT IS PLANNING...",
              style: GoogleFonts.sairaStencilOne(
                color: Colors.white,
                fontSize: 12, // Small but readable size
                letterSpacing: 2.0,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
