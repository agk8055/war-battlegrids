import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flutter/material.dart';
import '../../core/enums/cell_state.dart';
import '../kingdom_game.dart';

class CellComponent extends PositionComponent with TapCallbacks, HasGameRef<KingdomGame> {
  final int gridX;
  final int gridY;
  final CellState initialState;
  final void Function(int x, int y) onTapCell;
  final String playerSymbol;
  final String opponentSymbol;
  final Color playerColor;
  final Color opponentColor;

  late CellState _currentState;
  Sprite? _playerSprite;
  Sprite? _opponentSprite;

  CellComponent({
    required this.gridX,
    required this.gridY,
    required this.initialState,
    required this.onTapCell,
    required this.playerSymbol,
    required this.opponentSymbol,
    required this.playerColor,
    required this.opponentColor,
    required Vector2 size,
    required Vector2 position,
  }) : super(size: size, position: position) {
    _currentState = initialState;
  }

  @override
  Future<void> onLoad() async {
    super.onLoad();
    _playerSprite = await Sprite.load(playerSymbol);
    _opponentSprite = await Sprite.load(opponentSymbol);
  }

  void updateState(CellState newState) {
    _currentState = newState;
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    Paint paint = Paint()..style = PaintingStyle.fill;
    
    // Draw base tile
    switch (_currentState) {
      case CellState.empty:
        paint.color = Colors.transparent;
        break;
      case CellState.playerZone:
        paint.color = playerColor.withValues(alpha: 0.2);
        break;
      case CellState.aiZone:
        paint.color = opponentColor.withValues(alpha: 0.2);
        break;
      case CellState.player:
        paint.color = playerColor.withValues(alpha: 0.4); 
        break;
      case CellState.ai:
        paint.color = opponentColor.withValues(alpha: 0.4);
        break;
      case CellState.capturedGrid:
        paint.color = Colors.black.withValues(alpha: 0.5);
        break;
      case CellState.obstacle:
        paint.color = Colors.orange.withValues(alpha: 0.1);
        break;
      default:
        paint.color = Colors.transparent;
        break;
    }

    // Draw the tile slightly smaller than size to create grid lines
    canvas.drawRect(
      Rect.fromLTWH(1, 1, size.x - 2, size.y - 2),
      paint,
    );

    // If there is a unit on this tile, draw the symbol (sigil)
    if (_currentState == CellState.player && _playerSprite != null) {
      _playerSprite!.render(
        canvas,
        position: Vector2(size.x * 0.15, size.y * 0.15),
        size: Vector2(size.x * 0.7, size.y * 0.7),
        overridePaint: Paint()..colorFilter = ColorFilter.mode(playerColor, BlendMode.srcIn),
      );
    } else if (_currentState == CellState.ai && _opponentSprite != null) {
      _opponentSprite!.render(
        canvas,
        position: Vector2(size.x * 0.15, size.y * 0.15),
        size: Vector2(size.x * 0.7, size.y * 0.7),
        overridePaint: Paint()..colorFilter = ColorFilter.mode(opponentColor, BlendMode.srcIn),
      );
    }
  }

  @override
  void onTapUp(TapUpEvent event) {
    onTapCell(gridX, gridY);
  }
}
