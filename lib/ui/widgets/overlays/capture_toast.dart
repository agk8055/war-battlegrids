import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_assets.dart';

/// Tier information for unit captures to decide icons, titles, and colors.
class _CaptureTierInfo {
  final String iconPath;
  final String tierTitle;
  final Color primaryGlow;
  final Color accentColor;

  const _CaptureTierInfo({
    required this.iconPath,
    required this.tierTitle,
    required this.primaryGlow,
    required this.accentColor,
  });

  factory _CaptureTierInfo.fromUnits(int unitsCaptured) {
    if (unitsCaptured >= 4) {
      return const _CaptureTierInfo(
        iconPath: AppAssets.excalibur,
        tierTitle: 'LEGENDARY CAPTURE',
        primaryGlow: Color(0xFFFFD700), // Gold
        accentColor: Color(0xFFFFE082),
      );
    } else if (unitsCaptured >= 2) {
      return const _CaptureTierInfo(
        iconPath: AppAssets.medieval,
        tierTitle: 'MULTI-CAPTURE',
        primaryGlow: Color(0xFFFF9100), // Amber Orange
        accentColor: Color(0xFFFFCC80),
      );
    } else {
      return const _CaptureTierInfo(
        iconPath: AppAssets.swordFight,
        tierTitle: 'UNIT CAPTURED',
        primaryGlow: Color(0xFF00E5FF), // Cyan / Electric Blue
        accentColor: Color(0xFFB3E5FC),
      );
    }
  }
}

/// Centralized Manager for Top Animated Capture Notifications.
class CaptureToast {
  static OverlayEntry? _activeOverlayEntry;
  static Timer? _dismissTimer;

  /// Shows an animated capture notification directly below BattleHudHeader with icon on top and text below.
  static void showCapture({
    required BuildContext context,
    required String capturerName,
    required Color capturerColor,
    required int unitsCaptured,
    required int pointsGained,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    final effectiveUnits = unitsCaptured > 0 ? unitsCaptured : 1;
    final effectivePoints = pointsGained > 0 ? pointsGained : (effectiveUnits * 100);

    _showCustomOverlay(
      context: context,
      duration: duration,
      builder: (onDismiss) => _AnimatedCaptureBanner(
        capturerName: capturerName,
        capturerColor: capturerColor,
        unitsCaptured: effectiveUnits,
        pointsGained: effectivePoints,
        duration: duration,
        onDismiss: onDismiss,
      ),
    );
  }

  /// Shows a general game notification toast below the HUD header.
  static void show(
    BuildContext context,
    String message,
    Color color, {
    Duration duration = const Duration(milliseconds: 2200),
    IconData icon = Icons.shield_outlined,
  }) {
    _showCustomOverlay(
      context: context,
      duration: duration,
      builder: (onDismiss) => _AnimatedStatusBanner(
        message: message,
        color: color,
        icon: icon,
        duration: duration,
        onDismiss: onDismiss,
      ),
    );
  }

  static void _showCustomOverlay({
    required BuildContext context,
    required Duration duration,
    required Widget Function(VoidCallback onDismiss) builder,
  }) {
    _dismissTimer?.cancel();
    if (_activeOverlayEntry != null) {
      if (_activeOverlayEntry!.mounted) {
        _activeOverlayEntry!.remove();
      }
      _activeOverlayEntry = null;
    }

    final overlayState = Overlay.maybeOf(context, rootOverlay: true) ?? Overlay.maybeOf(context);
    if (overlayState == null) return;

    late OverlayEntry entry;
    void removeEntry() {
      if (_activeOverlayEntry == entry) {
        if (entry.mounted) {
          entry.remove();
        }
        _activeOverlayEntry = null;
      }
    }

    entry = OverlayEntry(
      builder: (ctx) => builder(removeEntry),
    );

    _activeOverlayEntry = entry;
    overlayState.insert(entry);
  }
}

/// The Animated Capture Banner shown directly below BattleHudHeader.
/// Displays the icon on top (with transparent bg) and small text below.
class _AnimatedCaptureBanner extends StatefulWidget {
  final String capturerName;
  final Color capturerColor;
  final int unitsCaptured;
  final int pointsGained;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AnimatedCaptureBanner({
    required this.capturerName,
    required this.capturerColor,
    required this.unitsCaptured,
    required this.pointsGained,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_AnimatedCaptureBanner> createState() => _AnimatedCaptureBannerState();
}

class _AnimatedCaptureBannerState extends State<_AnimatedCaptureBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final _CaptureTierInfo _tierInfo;

  @override
  void initState() {
    super.initState();
    _tierInfo = _CaptureTierInfo.fromUnits(widget.unitsCaptured);

    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    // Entrance: 0% -> 18% (0 to 450ms)
    // Display: 18% -> 82% (450ms to 2050ms)
    // Exit: 82% -> 100% (2050ms to 2500ms)
    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -15.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 64,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -12.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 18,
      ),
    ]).animate(_controller);

    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.6, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 64,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.8)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 18,
      ),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 72,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 14,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Sits directly underneath BattleHudHeader (~80px + safe area)
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 78,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Opacity(
                    opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                    child: Center(
                      child: _buildNotificationContent(),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Icon on top
        Image.asset(
          _tierInfo.iconPath,
          width: 54,
          height: 54,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) {
            return const Icon(
              Icons.shield,
              color: Color(0xFFFFD700),
              size: 44,
            );
          },
        ),

        // 2. Text and points displayed plain inside the capture_toast banner ribbon (gap removed)
        Transform.translate(
          offset: const Offset(0, -14),
          child: SizedBox(
            width: 320,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // The banner image
                Image.asset(
                  AppAssets.captureToast,
                  width: 320,
                  height: 64,
                  fit: BoxFit.fill,
                  errorBuilder: (context, error, stackTrace) {
                    return const SizedBox.shrink();
                  },
                ),
                // Content on top of banner
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 46),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          _tierInfo.tierTitle,
                          style: GoogleFonts.sairaStencilOne(
                            fontSize: 12,
                            color: const Color(0xFFFFD700),
                            letterSpacing: 1.4,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '+${widget.pointsGained} PTS',
                        style: GoogleFonts.sairaStencilOne(
                          fontSize: 12,
                          color: const Color(0xFFFFE066),
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The Animated Status Banner for general game alerts directly below BattleHudHeader.
class _AnimatedStatusBanner extends StatefulWidget {
  final String message;
  final Color color;
  final IconData icon;
  final Duration duration;
  final VoidCallback onDismiss;

  const _AnimatedStatusBanner({
    required this.message,
    required this.color,
    required this.icon,
    required this.duration,
    required this.onDismiss,
  });

  @override
  State<_AnimatedStatusBanner> createState() => _AnimatedStatusBannerState();
}

class _AnimatedStatusBannerState extends State<_AnimatedStatusBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    );

    _slideAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: -10.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 18,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(0.0),
        weight: 64,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: -10.0)
            .chain(CurveTween(curve: Curves.easeInCubic)),
        weight: 18,
      ),
    ]).animate(_controller);

    _fadeAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 0.0, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 14,
      ),
      TweenSequenceItem(
        tween: ConstantTween<double>(1.0),
        weight: 72,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 0.0)
            .chain(CurveTween(curve: Curves.easeIn)),
        weight: 14,
      ),
    ]).animate(_controller);

    _controller.forward().then((_) {
      if (mounted) {
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    return Positioned(
      top: topPadding + 78,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Material(
          type: MaterialType.transparency,
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, _slideAnimation.value),
                child: Opacity(
                  opacity: _fadeAnimation.value.clamp(0.0, 1.0),
                  child: Center(
                    child: SizedBox(
                      width: 320,
                      height: 64,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // The banner image
                          Image.asset(
                            AppAssets.captureToast,
                            width: 320,
                            height: 64,
                            fit: BoxFit.fill,
                            errorBuilder: (context, error, stackTrace) {
                              return const SizedBox.shrink();
                            },
                          ),
                          // Content on top of banner
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 46),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  widget.icon,
                                  color: const Color(0xFFFFD700),
                                  size: 15,
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    widget.message,
                                    style: GoogleFonts.sairaStencilOne(
                                      color: const Color(0xFFFFD700),
                                      fontSize: 12,
                                      letterSpacing: 1.3,
                                      fontWeight: FontWeight.bold,
                                      decoration: TextDecoration.none,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
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
              );
            },
          ),
        ),
      ),
    );
  }
}
