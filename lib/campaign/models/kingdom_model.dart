import 'package:flutter/material.dart';
import '../../core/constants/app_assets.dart';

class KingdomModel {
  final String id;
  final String name;
  final String lore;
  final int difficulty;
  final String bannerAsset;
  final String symbolAsset;
  final Color primaryColor;
  final double x; // Coordinate on the map (0.0 to 1.0)
  final double y; // Coordinate on the map (0.0 to 1.0)
  final List<String> unlockedBy; // IDs of kingdoms that must be defeated first

  const KingdomModel({
    required this.id,
    required this.name,
    required this.lore,
    required this.difficulty,
    required this.bannerAsset,
    this.symbolAsset = AppAssets.eagle,
    this.primaryColor = Colors.red,
    required this.x,
    required this.y,
    this.unlockedBy = const [],
  });
}
