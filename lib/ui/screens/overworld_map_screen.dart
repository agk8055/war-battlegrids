import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
import '../../core/constants/app_assets.dart';
import '../../campaign/campaign_manager.dart';
import '../../campaign/data/battle_configs.dart';
import '../../campaign/data/kingdoms_data.dart';
import '../../campaign/models/kingdom_model.dart';
import '../../providers/game_settings_provider.dart';
import '../widgets/pre_battle_sidebar.dart';
import 'pre_battle_screen.dart';

class OverworldMapScreen extends ConsumerStatefulWidget {
  const OverworldMapScreen({super.key});

  @override
  ConsumerState<OverworldMapScreen> createState() => _OverworldMapScreenState();
}

class _OverworldMapScreenState extends ConsumerState<OverworldMapScreen> with TickerProviderStateMixin {
  final TransformationController _transformationController = TransformationController();
  static const double _mapWidth = 1970.0;
  static const double _mapHeight = 3188.0;
  late AnimationController _zoomController;
  Animation<Matrix4>? _zoomAnimation;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      if (mounted) {
        ref.read(gameSettingsProvider.notifier).restoreCampaignSettings();
      }
    });
    _zoomController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _zoomController.addListener(() {
      if (_zoomAnimation != null) {
        _transformationController.value = _zoomAnimation!.value;
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMapOnScreen();
    });
  }

  void _centerMapOnScreen() {
    final Size screenSize = MediaQuery.of(context).size;
    final double scaleX = screenSize.width / _mapWidth;
    final double scaleY = screenSize.height / _mapHeight;
    final double initialScale = math.max(scaleX, scaleY);

    final double translateX = (screenSize.width - (_mapWidth * initialScale)) / 2;
    final double translateY = (screenSize.height - (_mapHeight * initialScale)) / 2;

    _transformationController.value = Matrix4.identity()
      ..translate(translateX, translateY)
      ..scale(initialScale);
  }

  void _zoomToKingdom(KingdomModel kingdom, BoxConstraints constraints, double minScale) {
    final double targetScale = 1.6;

    final double kingdomPixelX = kingdom.x * _mapWidth;
    final double kingdomPixelY = kingdom.y * _mapHeight;

    final double screenCenterX = constraints.maxWidth / 2;
    final double screenCenterY = constraints.maxHeight / 2;

    double targetX = screenCenterX - (kingdomPixelX * targetScale);
    double targetY = screenCenterY - (kingdomPixelY * targetScale);

    final double minX = constraints.maxWidth - (_mapWidth * targetScale);
    final double minY = constraints.maxHeight - (_mapHeight * targetScale);

    targetX = targetX.clamp(minX, 0.0);
    targetY = targetY.clamp(minY, 0.0);

    final Matrix4 endMatrix = Matrix4.identity()
      ..translate(targetX, targetY)
      ..scale(targetScale);

    _zoomAnimation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _zoomController,
      curve: Curves.easeInOutCubic,
    ));

    _zoomController.forward(from: 0);
  }

  @override
  void dispose() {
    _zoomController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final campaignState = ref.watch(campaignProvider);
    final selectedKingdomId = campaignState.selectedKingdomId;
    final selectedKingdom = selectedKingdomId != null 
        ? kKingdoms.firstWhere((k) => k.id == selectedKingdomId)
        : null;
    final primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0B09),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final double scaleX = constraints.maxWidth / _mapWidth;
          final double scaleY = constraints.maxHeight / _mapHeight;
          final double minScale = math.max(scaleX, scaleY);

          return Stack(
            children: [
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  maxScale: 2.5,
                  minScale: minScale * 0.5,
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(600),
                  child: SizedBox(
                    width: _mapWidth,
                    height: _mapHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        AppAssetImage(
                          AppAssets.overworldMap,
                          width: _mapWidth,
                          height: _mapHeight,
                          fit: BoxFit.contain,
                        ),
                        
                        ..._buildMapDecorations(),
          
                        CustomPaint(
                          size: const Size(_mapWidth, _mapHeight),
                          painter: PathPainter(kingdoms: kKingdoms, state: campaignState),
                        ),
          
                        ...kKingdoms.map((kingdom) {
                          return _buildKingdomNode(
                            context, 
                            ref, 
                            kingdom, 
                            campaignState, 
                            _mapWidth, 
                            _mapHeight,
                            isSelected: kingdom.id == selectedKingdomId,
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),

              // Ambient radial glow overlay
              Positioned.fill(
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, 0),
                        radius: 1.0,
                        colors: [primary.withValues(alpha: 0.05), Colors.transparent],
                      ),
                    ),
                  ),
                ),
              ),

              // Sidebar Overlay
              if (selectedKingdom != null) ...[
                // Darken the area NOT covered by the sidebar slightly? 
                // Or just the whole map is already visible. 
                // Let's add a subtle gradient to push focus to the center.
                Positioned.fill(
                  child: IgnorePointer(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                          colors: [
                            Colors.black.withValues(alpha: 0.0),
                            const Color(0xFF0A0804).withValues(alpha: 0.8),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),
                ),

                // Sidebar
                Positioned(
                  right: 0,
                  top: 0,
                  bottom: 0,
                  child: PreBattleSidebar(
                    kingdom: selectedKingdom,
                    onEnterBattle: () {
                      ref.read(gameSettingsProvider.notifier).restoreCampaignSettings();
                      final battleConfig = kBattleConfigs[selectedKingdom.id];
                      if (battleConfig != null) {
                        ref.read(gameSettingsProvider.notifier).setSelectedMap(battleConfig.mapPath);
                      }
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => PreBattleScreen(kingdom: selectedKingdom)),
                      );
                    },
                    onWithdraw: () {
                      ref.read(campaignProvider.notifier).selectKingdom(null);
                    },
                  ),
                ),
              ],
          
              // HUD / Back Button
              if (selectedKingdom == null)
                Positioned(
                  top: MediaQuery.of(context).padding.top + 16,
                  left: 16,
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
                      ),
                      child: Icon(Icons.chevron_left, color: primary, size: 22),
                    ),
                  ),
                ),
              
              // Campaign Info Overlay
              if (selectedKingdom == null)
                Positioned(
                  bottom: 24,
                  left: 24,
                  right: 24,
                  child: _StonePanel(
                    accentColor: primary,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text("CAMPAIGN PROGRESS", style: TextStyle(color: primary.withValues(alpha: 0.7), fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                            const SizedBox(height: 4),
                            Text(
                              "${campaignState.conqueredKingdomIds.length} / ${kKingdoms.length} KINGDOMS CONQUERED",
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold, letterSpacing: 1.0),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24.0),
                            child: Container(
                              height: 8,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(color: primary.withValues(alpha: 0.3), width: 1),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(3),
                                child: LinearProgressIndicator(
                                  value: kKingdoms.isEmpty ? 0 : campaignState.conqueredKingdomIds.length / kKingdoms.length,
                                  backgroundColor: Colors.transparent,
                                  color: primary,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildMapDecorations() {
    return [
      _buildCloud(-350, 200, 0.9, 3.2, rotation: 1),
      _buildCloud(-300, 1000, 0.8, 2.8, rotation: 1),
      _buildCloud(-300, 1800, 0.9, 3.5, rotation: 1),
      _buildCloud(-300, 2600, 0.8, 3.0, rotation: 1),
      _buildCloud(_mapWidth - 50, 300, 0.9, 3.2, rotation: 3),
      _buildCloud(_mapWidth - 50, 1100, 0.8, 2.8, rotation: 3),
      _buildCloud(_mapWidth- 1, 1900, 0.9, 3.5, rotation: 3),
      _buildCloud(_mapWidth - 1, 2700, 0.8, 3.0, rotation: 3),
      _buildCloud(250, -250, 0.9, 3.2),
      _buildCloud(1000, -200, 0.8, 2.7),
      _buildCloud(1800, -300, 0.9, 3.0),
      _buildCloud(100, _mapHeight - 250, 0.9, 3.4),
      _buildCloud(900, _mapHeight - 100, 0.8, 2.8),
      _buildCloud(1700, _mapHeight - 50, 0.9, 3.1),
    ];
  }

  Widget _buildCloud(double x, double y, double opacity, double scale, {int rotation = 0}) {
    return Positioned(
      left: x,
      top: y,
      child: IgnorePointer(
        child: Transform.scale(
          scale: scale,
          child: Opacity(
            opacity: opacity,
            child: RotatedBox(
              quarterTurns: rotation,
              child: AppAssetImage(AppAssets.cloud, width: 600),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildKingdomNode(
    BuildContext context, 
    WidgetRef ref, 
    KingdomModel kingdom, 
    CampaignState state, 
    double mapWidth, 
    double mapHeight,
    {bool isSelected = false}
  ) {
    final bool isConquered = state.isConquered(kingdom.id);
    final bool isUnlocked = state.isUnlocked(kingdom.id, kingdom.unlockedBy);
    
    final double left = kingdom.x * mapWidth;
    final double top = kingdom.y * mapHeight;

    return Positioned(
      left: left - (isSelected ? 45 : 30),
      top: top - (isSelected ? 45 : 30),
      child: GestureDetector(
        onTap: isUnlocked ? () {
          ref.read(campaignProvider.notifier).selectKingdom(kingdom.id);
        } : null,
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              width: isSelected ? 90 : 60,
              height: isSelected ? 90 : 60,
              decoration: BoxDecoration(
                color: isConquered ? const Color(0xFFFCB103) : (isUnlocked ? Colors.redAccent : Colors.grey[800]),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected ? const Color(0xFFFCB103) : (isConquered ? Colors.black : (isUnlocked ? Colors.white : Colors.white24)), 
                  width: isSelected ? 4 : 3,
                ),
                boxShadow: [
                  if (isUnlocked || isSelected) BoxShadow(
                    color: (isSelected ? const Color(0xFFFCB103) : (isConquered ? const Color(0xFFFCB103) : Colors.redAccent)).withValues(alpha: 0.5),
                    blurRadius: isSelected ? 25 : 15,
                    spreadRadius: isSelected ? 5 : 2,
                  ),
                  const BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 4)),
                ],
              ),
              child: isConquered
                  ? AppAssetImage(
                      AppAssets.throne,
                      width: isSelected ? 45 : 30,
                      height: isSelected ? 45 : 30,
                      color: Colors.black,
                    )
                  : (isUnlocked
                      ? AppAssetImage(
                          AppAssets.shieldSword,
                          width: isSelected ? 45 : 30,
                          height: isSelected ? 45 : 30,
                          color: Colors.white,
                        )
                      : Icon(
                          Icons.lock,
                          color: Colors.white24,
                          size: isSelected ? 45 : 30,
                        )),
            ),
            if (!isSelected) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1510).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3), width: 1),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 4, offset: const Offset(0, 2)),
                  ],
                ),
                child: Text(
                  kingdom.name.toUpperCase(),
                  style: TextStyle(
                    color: isUnlocked ? Colors.white : Colors.white38, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class PathPainter extends CustomPainter {
  final List<KingdomModel> kingdoms;
  final CampaignState state;

  PathPainter({required this.kingdoms, required this.state});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final conqueredPaint = Paint()
      ..color = const Color(0xFFFCB103).withValues(alpha: 0.4)
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final double mapWidth = size.width;
    final double mapHeight = size.height;

    for (var k in kingdoms) {
      for (var unlockedId in k.unlockedBy) {
        final parent = kingdoms.firstWhere((element) => element.id == unlockedId);
        
        final p1 = Offset(parent.x * mapWidth, parent.y * mapHeight);
        final p2 = Offset(k.x * mapWidth, k.y * mapHeight);
        
        final isPathConquered = state.isConquered(parent.id) && state.isConquered(k.id);
        
        canvas.drawLine(p1, p2, isPathConquered ? conqueredPaint : paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _HatchPainter extends CustomPainter {
  final Color color;
  const _HatchPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 0.6;
    const spacing = 22.0;
    for (double i = -size.height; i < size.width + size.height; i += spacing) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height, size.height), paint);
    }
  }

  @override
  bool shouldRepaint(_HatchPainter old) => old.color != color;
}

class _StonePanel extends StatelessWidget {
  final Widget child;
  final Color accentColor;
  final EdgeInsetsGeometry padding;

  const _StonePanel({
    required this.child,
    required this.accentColor,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    final ornamentColor = accentColor.withValues(alpha: 0.5);
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1510), Color(0xFF0F0D0A)],
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.28), width: 1.2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.55), blurRadius: 18, offset: const Offset(0, 6)),
          BoxShadow(color: accentColor.withValues(alpha: 0.06), blurRadius: 24, spreadRadius: 2),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _HatchPainter(color: Colors.white.withValues(alpha: 0.018))),
          ),
          ..._corners(ornamentColor),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }

  List<Widget> _corners(Color color) {
    const sz = 24.0;
    return [
      Positioned(
          top: 0,
          left: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi / 2),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: AppAssetImage(AppAssets.borderEdge, color: color)))),
      Positioned(
          top: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(math.pi),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: AppAssetImage(AppAssets.borderEdge, color: color)))),
      Positioned(
          bottom: 0,
          left: 0,
          child: SizedBox(
              width: sz,
              height: sz,
              child: AppAssetImage(AppAssets.borderEdge, color: color))),
      Positioned(
          bottom: 0,
          right: 0,
          child: Transform(
              alignment: Alignment.center,
              transform: Matrix4.rotationZ(-math.pi / 2),
              child: SizedBox(
                  width: sz,
                  height: sz,
                  child: AppAssetImage(AppAssets.borderEdge, color: color)))),
    ];
  }
}
