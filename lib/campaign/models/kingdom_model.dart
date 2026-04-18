class KingdomModel {
  final String id;
  final String name;
  final String lore;
  final int difficulty;
  final String bannerAsset;
  final double x; // Coordinate on the map (0.0 to 1.0)
  final double y; // Coordinate on the map (0.0 to 1.0)
  final List<String> unlockedBy; // IDs of kingdoms that must be defeated first

  const KingdomModel({
    required this.id,
    required this.name,
    required this.lore,
    required this.difficulty,
    required this.bannerAsset,
    required this.x,
    required this.y,
    this.unlockedBy = const [],
  });
}
