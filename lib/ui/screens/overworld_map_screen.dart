import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:vector_math/vector_math_64.dart' hide Colors;
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
  late AnimationController _animationController;
  Animation<Matrix4>? _animation;

  // Image dimensions
  static const double _mapWidth = 1970;
  static const double _mapHeight = 3188;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
        if (_animation != null) {
          _transformationController.value = _animation!.value;
        }
      });
  }

  @override
  void dispose() {
    _transformationController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  bool _initialScaleSet = false;
  String? _lastSelectedKingdomId;

  void _zoomToKingdom(KingdomModel kingdom, BoxConstraints constraints, double minScale) {
    // Zoom in a bit more than minScale
    final double targetScale = (minScale * 1.8).clamp(minScale, 2.0);
    
    // If sidebar is on the right (takes 35%), the visible "center" for the map 
    // is at 32.5% of the total screen width.
    final double viewportCenterX = constraints.maxWidth * 0.325;
    final double viewportCenterY = constraints.maxHeight / 2;

    final double kingdomX = kingdom.x * _mapWidth;
    final double kingdomY = kingdom.y * _mapHeight;

    // The transformation that puts (kingdomX, kingdomY) at (viewportCenterX, viewportCenterY)
    final Matrix4 endMatrix = Matrix4.identity()
      ..translateByVector3(Vector3(viewportCenterX, viewportCenterY, 0.0))
      ..scaleByVector3(Vector3(targetScale, targetScale, 1.0))
      ..translateByVector3(Vector3(-kingdomX, -kingdomY, 0.0));

    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: endMatrix,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    ));

    _animationController.forward(from: 0);
  }

  void _resetZoom(double minScale) {
    _animation = Matrix4Tween(
      begin: _transformationController.value,
      end: Matrix4.identity()..scaleByVector3(Vector3(minScale, minScale, 1.0)),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.fastOutSlowIn,
    ));
    _animationController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final campaignState = ref.watch(campaignProvider);
    final selectedKingdomId = campaignState.selectedKingdomId;
    final selectedKingdom = selectedKingdomId != null 
        ? kKingdoms.firstWhere((k) => k.id == selectedKingdomId)
        : null;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate min scale
          final double screenRatioW = constraints.maxWidth / _mapWidth;
          final double screenRatioH = constraints.maxHeight / _mapHeight;
          final double minScale = (screenRatioW > screenRatioH ? screenRatioW : screenRatioH) * 1.2;

          if (!_initialScaleSet) {
            _transformationController.value = Matrix4.identity()..scaleByVector3(Vector3(minScale, minScale, 1.0));
            _initialScaleSet = true;
          }

          // Trigger animation if selection changed
          if (selectedKingdomId != _lastSelectedKingdomId) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (selectedKingdom != null) {
                _zoomToKingdom(selectedKingdom, constraints, minScale);
              } else if (_lastSelectedKingdomId != null) {
                _resetZoom(minScale);
              }
              _lastSelectedKingdomId = selectedKingdomId;
            });
          }

          return Stack(
            children: [
              // Background Map
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  maxScale: 2.5,
                  minScale: minScale * 0.5, // Allow zooming out slightly during transitions
                  constrained: false,
                  boundaryMargin: const EdgeInsets.all(600), // Large margin for free movement
                  child: SizedBox(
                    width: _mapWidth,
                    height: _mapHeight,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Image.asset(
                          'assets/images/overworld_map.png',
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
                            Colors.black.withValues(alpha: 0.4),
                          ],
                          stops: const [0.65, 1.0],
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
                  top: 40,
                  left: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ),
                ),
              
              // Campaign Info Overlay
              if (selectedKingdom == null)
                Positioned(
                  bottom: 20,
                  left: 20,
                  right: 20,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text("CAMPAIGN PROGRESS", style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
                            Text(
                              "${campaignState.conqueredKingdomIds.length} / ${kKingdoms.length} KINGDOMS CONQUERED",
                              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.only(left: 24.0),
                            child: LinearProgressIndicator(
                              value: kKingdoms.isEmpty ? 0 : campaignState.conqueredKingdomIds.length / kKingdoms.length,
                              backgroundColor: Colors.white12,
                              color: Colors.blueAccent,
                              minHeight: 8,
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
              child: Image.asset('assets/images/cloud.png', width: 600),
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
                  ? Image.asset(
                      'assets/icons/throne.png',
                      width: isSelected ? 45 : 30,
                      height: isSelected ? 45 : 30,
                      color: Colors.black,
                    )
                  : (isUnlocked
                      ? Image.asset(
                          'assets/icons/shield_sword.png',
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
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.white24, width: 1),
                ),
                child: Text(
                  kingdom.name.toUpperCase(),
                  style: TextStyle(
                    color: isUnlocked ? Colors.white : Colors.white38, 
                    fontSize: 10, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
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

    const double mapWidth = 1970;
    const double mapHeight = 3188;

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
