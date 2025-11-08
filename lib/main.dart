import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flame Character Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const GameScreen(),
    );
  }
}

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  final _game = CharacterGame();
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _game.pauseEngine();
    super.dispose();
  }

  void _onRawKey(RawKeyEvent event) {
    if (event is RawKeyDownEvent) {
      final key = event.logicalKey;
      if (key == LogicalKeyboardKey.arrowLeft) {
        _game.moveLeft();
      } else if (key == LogicalKeyboardKey.arrowRight) {
        _game.moveRight();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _onRawKey,
        child: Stack(
          children: [
            GameWidget(game: _game),
            Positioned(
              left: 16,
              bottom: 24,
              child: FloatingActionButton.small(
                heroTag: 'leftBtn',
                onPressed: _game.moveLeft,
                child: const Icon(Icons.arrow_left),
              ),
            ),
            Positioned(
              right: 16,
              bottom: 24,
              child: FloatingActionButton.small(
                heroTag: 'rightBtn',
                onPressed: _game.moveRight,
                child: const Icon(Icons.arrow_right),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class CharacterGame extends FlameGame {
  SpriteComponent? character;

  int _posIndex = 1; // 0 = Left, 1 = Center, 2 = Right
  late double _leftX;
  late double _centerX;
  late double _rightX;

  double _targetX = 0.0;
  final double _moveSpeed = 900.0;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final image = await images.load('character.png');
    final sprite = Sprite(image);

    character = SpriteComponent(
      sprite: sprite,
      size: Vector2(100, 100),
      anchor: Anchor.bottomCenter,
    );

    add(character!);

    if (size.x > 0 && size.y > 0) {
      _targetX = _xForIndex(_posIndex);
      character!.position = Vector2(_targetX, size.y - 16);
    }
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);

    _leftX = canvasSize.x * 0.20;
    _centerX = canvasSize.x * 0.50;
    _rightX = canvasSize.x * 0.80;

    _targetX = _xForIndex(_posIndex);

    if (character != null) {
      character!.position = Vector2(_targetX, canvasSize.y - 16);
    }
  }

  double _xForIndex(int index) {
    switch (index) {
      case 0:
        return _leftX;
      case 2:
        return _rightX;
      case 1:
      default:
        return _centerX;
    }
  }

  void moveLeft() {
    final newIndex = (_posIndex - 1).clamp(0, 2);
    _moveToIndex(newIndex);
  }

  void moveRight() {
    final newIndex = (_posIndex + 1).clamp(0, 2);
    _moveToIndex(newIndex);
  }

  void _moveToIndex(int newIndex) {
    if (newIndex == _posIndex) return;
    _posIndex = newIndex;
    _targetX = _xForIndex(newIndex);
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (character == null) return;

    final pos = character!.position;
    final dx = _targetX - pos.x;

    if (dx.abs() < 0.5) {
      character!.position = Vector2(_targetX, pos.y);
      return;
    }

    final step = _moveSpeed * dt;
    double newX;
    if (dx.abs() <= step) {
      newX = _targetX;
    } else {
      newX = pos.x + (dx.sign * step);
    }

    character!.position = Vector2(newX, pos.y);
  }
}
