import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

/// ConfettiOverlay — shared celebration widget.
///
/// Colors are injected by the host app (client-config-driven, Law 3) so
/// `core_ui` stays app-agnostic. The default palette is a neutral fallback
/// used only when the caller does not supply client colors.
class ConfettiOverlay {
  static void show(
    BuildContext context, {
    Duration duration = const Duration(seconds: 1),
    List<Color> colors = const [
      Color(0xFFE63946),
      Color(0xFF1D3557),
      Color(0xFFF4A261),
      Color(0xFF2A9D8F),
    ],
  }) {
    final controller = ConfettiController(duration: duration);

    // Insert an overlay entry that shoots confetti
    final overlay = Overlay.of(context);
    late OverlayEntry overlayEntry;

    overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned(
          top: 0,
          left: MediaQuery.of(context).size.width / 2,
          child: ConfettiWidget(
            confettiController: controller,
            blastDirection: 3.14159 / 2, // Straight down
            emissionFrequency: 0.05,
            numberOfParticles: 20,
            maxBlastForce: 20,
            minBlastForce: 5,
            gravity: 0.3,
            colors: colors,
          ),
        );
      },
    );

    overlay.insert(overlayEntry);
    controller.play();

    // Clean up automatically when animation ends
    Future.delayed(duration + const Duration(seconds: 2), () {
      overlayEntry.remove();
      controller.dispose();
    });
  }
}
