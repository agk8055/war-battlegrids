import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../campaign/campaign_manager.dart';
import '../../campaign/data/kingdoms_data.dart';
import '../../campaign/models/kingdom_model.dart';
import 'pre_battle_screen.dart';

class OverworldMapScreen extends ConsumerStatefulWidget {
  const OverworldMapScreen({super.key});

  @override
  ConsumerState<OverworldMapScreen> createState() => _OverworldMapScreenState();
}

class _OverworldMapScreenState extends ConsumerState<OverworldMapScreen> {
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    // Start with a zoomed out view to show it's a map
    _transformationController.value = Matrix4.identity()..scale(0.5, 0.5, 1.0);
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final campaignState = ref.watch(campaignProvider);

    // Image dimensions
    const double mapWidth = 1970;
    const double mapHeight = 3188;

    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Calculate min scale to prevent showing too much black space
          // We want the map to at least fill the screen width or height
          final double minScale = (constraints.maxWidth / mapWidth > constraints.maxHeight / mapHeight)
              ? constraints.maxWidth / mapWidth
              : constraints.maxHeight / mapHeight;

          return Stack(
            children: [
              // Background Map with InteractiveViewer for panning/zooming
              Positioned.fill(
                child: InteractiveViewer(
                  transformationController: _transformationController,
                  maxScale: 2.0,
                  minScale: minScale,
                  constrained: false,
                  boundaryMargin: EdgeInsets.zero, // Restrict to map edges
                  child: SizedBox(
                    width: mapWidth,
                    height: mapHeight,
                    child: Stack(
                      children: [
                        Image.asset(
                          'assets/images/overworld_map.png',
                          width: mapWidth,
                          height: mapHeight,
                          fit: BoxFit.none,
                        ),
                        
                        // Paths between kingdoms
                        CustomPaint(
                          size: const Size(mapWidth, mapHeight),
                          painter: PathPainter(kingdoms: kKingdoms, state: campaignState),
                        ),
        
                        // Kingdom Nodes
                        ...kKingdoms.map((kingdom) {
                          return _buildKingdomNode(context, ref, kingdom, campaignState, mapWidth, mapHeight);
                        }),
                      ],
                    ),
                  ),
                ),
              ),
          
              // HUD / Back Button
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

  Widget _buildKingdomNode(
    BuildContext context, 
    WidgetRef ref, 
    KingdomModel kingdom, 
    CampaignState state, 
    double mapWidth, 
    double mapHeight
  ) {
    final bool isConquered = state.isConquered(kingdom.id);
    final bool isUnlocked = state.isUnlocked(kingdom.id, kingdom.unlockedBy);
    
    // Coordinates are percentage (0..1)
    final double left = kingdom.x * mapWidth;
    final double top = kingdom.y * mapHeight;

    return Positioned(
      left: left - 30, // Offset to center the 60x60 node
      top: top - 30,
      child: GestureDetector(
        onTap: isUnlocked ? () {
          ref.read(campaignProvider.notifier).selectKingdom(kingdom.id);
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => PreBattleScreen(kingdom: kingdom)),
          );
        } : null,
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: isConquered ? Colors.blueAccent : (isUnlocked ? Colors.redAccent : Colors.grey[800]),
                shape: BoxShape.circle,
                border: Border.all(
                  color: isUnlocked ? Colors.white : Colors.white24, 
                  width: 3,
                ),
                boxShadow: [
                  if (isUnlocked) BoxShadow(
                    color: (isConquered ? Colors.blueAccent : Colors.redAccent).withValues(alpha: 0.5),
                    blurRadius: 15,
                    spreadRadius: 2,
                  ),
                  const BoxShadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 4)),
                ],
              ),
              child: Icon(
                isConquered ? Icons.check_circle : (isUnlocked ? Icons.shield : Icons.lock),
                color: isUnlocked ? Colors.white : Colors.white24,
                size: 30,
              ),
            ),
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
      ..color = Colors.blueAccent.withValues(alpha: 0.4)
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
