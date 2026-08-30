import 'package:flame/cache.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';

/// Centralized registry of all asset paths, symbols, images, icons, audio files, and maps.
/// Contains fallback helpers so that even if assets are missing from the build,
/// the application continues to run without throwing unhandled exceptions.
class AppAssets {
  AppAssets._();

  static final Images _flameImages = Images(prefix: '');

  // --- IMAGES ---
  static const String bgImage = 'assets/images/bg_image.jpg';
  static const String homeBanner = 'assets/images/home_banner.png';
  static const String warSplashScreen = 'assets/images/war_splash_screen.png';
  static const String overworldMap = 'assets/images/overworld_map.png';
  static const String cloud = 'assets/images/cloud.png';
  static const String northernForest = 'assets/images/northern_forest.png';
  static const String grasslandArmy = 'assets/images/grassland_army.png';
  static const String ottoman = 'assets/images/ottoman.png';
  static const String pyramid = 'assets/images/pyramid.png';
  static const String roman = 'assets/images/roman.png';
  static const String costalFort = 'assets/images/costal_fort.png';
  static const String tibet = 'assets/images/tibet.png';
  static const String winterCastle = 'assets/images/winter_castle.png';
  static const String sangaNagaram = 'assets/images/sanga_nagaram.png';
  static const String warAppIcon = 'assets/images/war_app_icon.png';
  static const String plainBlack = 'assets/images/plain_black.png';
  static const String onDevice = 'assets/images/on_device.png';
  static const String bluetooth = 'assets/images/bluetooth.png';
  static const String online = 'assets/images/online.png';
  static const String profile = 'assets/images/profile.png';
  static const String captureToast = 'assets/images/capture_toast.png';
  static const String pauseBg = 'assets/images/pause_bg.png';
  static const String welcomeBg = 'assets/images/welcome_bg.png';
  static const String settingsBg = 'assets/images/settings_bg.png';
  static const String tutorialPoster = 'assets/images/tutorial_poster.png';
  static const String parchmentTexture = 'assets/images/parchment_texture.png';

  // --- ICONS (UI Elements) ---
  static const String borderEdge = 'assets/icons/border-edge.png';
  static const String excalibur = 'assets/icons/excalibur.png';
  static const String link = 'assets/icons/link.png';
  static const String medieval = 'assets/icons/medieval.png';
  static const String multiplayerIcon = 'assets/icons/multiplayer_icon.png';
  static const String settingsIcon = 'assets/icons/settings_icon.png';
  static const String shieldSword = 'assets/icons/shield_sword.png';
  static const String storyModeIcon = 'assets/icons/story_mode_icon.png';
  static const String swordFight = 'assets/icons/sword-fight.png';
  static const String throne = 'assets/icons/throne.png';

  // --- SYMBOLS (Kingdom & Player Sigils) ---
  static const String bull = 'assets/symbols/bull.png';
  static const String deer = 'assets/symbols/deer.png';
  static const String dragon = 'assets/symbols/dragon.png';
  static const String eagle = 'assets/symbols/eagle.png';
  static const String fire = 'assets/symbols/fire.png';
  static const String flash = 'assets/symbols/flash.png';
  static const String hacker = 'assets/symbols/hacker.png';
  static const String lion = 'assets/symbols/lion.png';
  static const String ottomanSigil = 'assets/symbols/ottoman_sigil.png';
  static const String pharaoh = 'assets/symbols/pharaoh.png';
  static const String risingSun = 'assets/symbols/rising_sun.png';
  static const String romanHelmet = 'assets/symbols/roman_helmet.png';
  static const String shuriken = 'assets/symbols/shuriken.png';
  static const String tiger = 'assets/symbols/tiger.png';
  static const String vikingHelmet = 'assets/symbols/viking_helmet.png';
  static const String wolf = 'assets/symbols/wolf.png';

  /// List of customizable player symbols available in profile/lobby
  static const List<String> availableSymbols = [
    fire,
    tiger,
    flash,
    hacker,
    lion,
    wolf,
    bull,
    shuriken,
  ];

  // --- AUDIO ---
  static const String mainTheme = 'Crown_of_the_Morning_Sky.mp3';
  static const String mainThemePath = 'audio/Crown_of_the_Morning_Sky.mp3';
  static const String sfxCapture = 'audio/sfx/capture.mp3';
  static const String sfxClick = 'audio/sfx/click.mp3';

  static const List<String> defaultSfxList = [
    sfxCapture,
    sfxClick,
  ];

  // --- MAPS ---
  static const String northernForestMap = '15x15_northern_forest_map.tmx';
  static const String desertMap = '19X19_desert_map.tmx';
  static const String defaultMap = '25x25_map.tmx';
  static const String icelandsMap = '30x30_icelands.tmx';

  // --- FALLBACK HELPERS ---

  /// Builds a fallback widget for Flutter UI when an asset fails to load.
  static Widget defaultErrorBuilder(
    BuildContext context,
    Object error,
    StackTrace? stackTrace, {
    double? width,
    double? height,
    Color? color,
  }) {
    return Container(
      width: width,
      height: height,
      color: Colors.black26,
      alignment: Alignment.center,
      child: Icon(
        Icons.image_not_supported_outlined,
        color: color?.withValues(alpha: 0.5) ?? Colors.white38,
        size: (width != null && height != null) ? (width < height ? width * 0.4 : height * 0.4) : 24.0,
      ),
    );
  }

  /// Safe Flame Sprite loader that handles missing assets gracefully.
  static Future<Sprite?> loadSpriteSafely(String path) async {
    try {
      String cleanPath = path.trim();
      if (!cleanPath.startsWith('assets/')) {
        cleanPath = 'assets/$cleanPath';
      }
      final image = await _flameImages.load(cleanPath);
      return Sprite(image);
    } catch (e) {
      try {
        final fallbackImage = await _flameImages.load(path.trim());
        return Sprite(fallbackImage);
      } catch (e2) {
        debugPrint('AppAssets Warning: Failed to load sprite "$path": $e2');
        return null;
      }
    }
  }
}

/// A wrapper widget around Image.asset that safely falls back to a placeholder widget
/// if the specified asset is missing, corrupted, or unavailable.
class AppAssetImage extends StatelessWidget {
  final String assetName;
  final double? width;
  final double? height;
  final BoxFit? fit;
  final Color? color;
  final BlendMode? colorBlendMode;
  final AlignmentGeometry alignment;
  final WidgetBuilder? fallbackBuilder;

  const AppAssetImage(
    this.assetName, {
    super.key,
    this.width,
    this.height,
    this.fit,
    this.color,
    this.colorBlendMode,
    this.alignment = Alignment.center,
    this.fallbackBuilder,
  });

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      assetName,
      width: width,
      height: height,
      fit: fit,
      color: color,
      colorBlendMode: colorBlendMode,
      alignment: alignment,
      errorBuilder: (context, error, stackTrace) {
        if (fallbackBuilder != null) {
          return fallbackBuilder!(context);
        }
        return AppAssets.defaultErrorBuilder(
          context,
          error,
          stackTrace,
          width: width,
          height: height,
          color: color,
        );
      },
    );
  }
}
