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
  late CharacterGame _game;
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _game = CharacterGame(onGameOver: _showGameOver);
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

  void _showGameOver() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: const Text('You collided with a bush!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                _game = CharacterGame(onGameOver: _showGameOver);
              });
              _focusNode.requestFocus();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _onRawKey,
        child: Center(
          child: AspectRatio(
            aspectRatio: 10 / 16,
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
        ),
      ),
    );
  }
}

class CharacterGame extends FlameGame {
  final VoidCallback onGameOver;

  CharacterGame({required this.onGameOver});

  SpriteComponent? character;
  SpriteComponent? background;
  List<SpriteComponent> bushes = [];

  int _posIndex = 1; // 0 = Left, 1 = Center, 2 = Right
  late double _leftX;
  late double _centerX;
  late double _rightX;

  double _targetX = 0.0;
  final double _moveSpeed = 900.0;

  // Bush movement properties
  final double _bushSpeed = 200.0;
  double _canvasHeight = 0.0;

  // Game state
  bool _isGameOver = false;

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load background image
    final bgImage = await images.load('bg3.png');
    background = SpriteComponent(
      sprite: Sprite(bgImage),
      size: size, // Fit to full screen
      anchor: Anchor.topLeft,
    );
    add(background!);

    // Load character sprite
    final image = await images.load('character.png');
    final sprite = Sprite(image);

    character = SpriteComponent(
      sprite: sprite,
      size: Vector2(100, 100),
      anchor: Anchor.bottomCenter,
    );
    add(character!);

    // Load bush sprite and create 3 bushes (one for each lane)
    final bushImage = await images.load('bush.png');
    final bushSprite = Sprite(bushImage);

    for (int i = 0; i < 3; i++) {
      final bush = SpriteComponent(
        sprite: bushSprite,
        size: Vector2(150, 100),
        anchor: Anchor.bottomCenter,
      );
      bushes.add(bush);
      add(bush);
    }

    // Ensure background stays at back
    background!.priority = -1;
    character!.priority = 1;
    for (final bush in bushes) {
      bush.priority = 2;
    }

    // Set initial positions when size is known
    if (size.x > 0 && size.y > 0) {
      _updatePositions(size);
    }
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);

    // Resize background to fit screen
    if (background != null) {
      background!.size = canvasSize;
    }

    _updatePositions(canvasSize);
  }

  void _updatePositions(Vector2 canvasSize) {
    _leftX = canvasSize.x * 0.20;
    _centerX = canvasSize.x * 0.50;
    _rightX = canvasSize.x * 0.80;
    _canvasHeight = canvasSize.y;

    _targetX = _xForIndex(_posIndex);

    if (character != null) {
      character!.position = Vector2(_targetX, canvasSize.y - 16);
    }

    // Position bushes initially
    if (bushes.length == 3) {
      bushes[0].position = Vector2(_leftX, 0);
      bushes[1].position = Vector2(_centerX, 0);
      bushes[2].position = Vector2(_rightX, 0);
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
    if (_isGameOver) return;
    final newIndex = (_posIndex - 1).clamp(0, 2);
    _moveToIndex(newIndex);
  }

  void moveRight() {
    if (_isGameOver) return;
    final newIndex = (_posIndex + 1).clamp(0, 2);
    _moveToIndex(newIndex);
  }

  void _moveToIndex(int newIndex) {
    if (newIndex == _posIndex) return;
    _posIndex = newIndex;
    _targetX = _xForIndex(newIndex);
  }

  bool _checkCollision(SpriteComponent obj1, SpriteComponent obj2) {
    final rect1 = obj1.toRect();
    final rect2 = obj2.toRect();
    return rect1.overlaps(rect2);
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_isGameOver) return;

    // Update character movement
    if (character != null) {
      final pos = character!.position;
      final dx = _targetX - pos.x;

      if (dx.abs() >= 0.5) {
        final step = _moveSpeed * dt;
        double newX;
        if (dx.abs() <= step) {
          newX = _targetX;
        } else {
          newX = pos.x + (dx.sign * step);
        }
        character!.position = Vector2(newX, pos.y);
      } else {
        character!.position = Vector2(_targetX, pos.y);
      }
    }

    // Update bush positions - move them down together
    for (int i = 0; i < bushes.length; i++) {
      final bush = bushes[i];
      bush.position.y += _bushSpeed * dt;

      // Check collision ONLY for center (index 1) and right (index 2) bushes
      if (character != null && (i == 1 || i == 2)) {
        if (_checkCollision(character!, bush)) {
          _isGameOver = true;
          pauseEngine();
          onGameOver();
          return;
        }
      }

      // Reset bush to top when it goes off screen
      if (bush.position.y > _canvasHeight + 100) {
        bush.position.y = -100;
      }
    }
  }
}
