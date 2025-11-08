import 'dart:math';
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
  List<SpriteComponent> bushes = [];
  List<_Tree> trees = [];

  _ScrollingBackground? bg;

  int _posIndex = 1; // 0 = Left, 1 = Center, 2 = Right
  late double _leftX;
  late double _centerX;
  late double _rightX;

  double _targetX = 0.0;
  final double _moveSpeed = 900.0;
  final double _bushSpeed = 200.0;
  double _canvasHeight = 0.0;

  bool _isGameOver = false;
  final Random _random = Random();

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // ✅ Background uses same speed as bushes
    bg = _ScrollingBackground(speedProvider: () => _bushSpeed);
    add(bg!);

    // Character
    final image = await images.load('character.png');
    character = SpriteComponent(
      sprite: Sprite(image),
      size: Vector2(100, 100),
      anchor: Anchor.bottomCenter,
    );
    add(character!);

    // Bushes
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

    // Trees
    for (int i = 1; i <= 6; i++) {
      final img = await images.load('tree$i.png');
      final treeSprite = Sprite(img);
      final bool leftSide = _random.nextBool();
      final double xPos = leftSide ? size.x * 0.05 : size.x * 0.95;
      final double yPos = -_random.nextDouble() * size.y;

      final tree = _Tree(
        sprite: treeSprite,
        position: Vector2(xPos, yPos),
        size: Vector2(100, 150),
        speedProvider: () => _bushSpeed,
        canvasHeight: size.y,
        isLeft: leftSide,
      );
      trees.add(tree);
      add(tree);
    }

    // Drawing order
    if (bg != null) bg!.priority = -2;
    for (final tree in trees) {
      tree.priority = 0;
    }
    for (final bush in bushes) {
      bush.priority = 1;
    }
    character!.priority = 2;

    if (size.x > 0 && size.y > 0) {
      _updatePositions(size);
    }
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    if (canvasSize.x <= 0 || canvasSize.y <= 0) return;

    _updatePositions(canvasSize);
    _canvasHeight = canvasSize.y;
    bg?.resizeToCanvas(canvasSize);

    for (final tree in trees) {
      tree.canvasHeight = canvasSize.y;
    }
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

    // Character lane movement
    if (character != null) {
      final pos = character!.position;
      final dx = _targetX - pos.x;
      if (dx.abs() >= 0.5) {
        final step = _moveSpeed * dt;
        final newX = (dx.abs() <= step) ? _targetX : pos.x + (dx.sign * step);
        character!.position = Vector2(newX, pos.y);
      } else {
        character!.position = Vector2(_targetX, pos.y);
      }
    }

    // Bushes
    for (int i = 0; i < bushes.length; i++) {
      final bush = bushes[i];
      bush.position.y += _bushSpeed * dt;

      if (character != null && (i == 1 || i == 2)) {
        if (_checkCollision(character!, bush)) {
          _isGameOver = true;
          pauseEngine();
          onGameOver();
          return;
        }
      }

      if (bush.position.y > _canvasHeight + 100) {
        bush.position.y = -100;
      }
    }
  }
}

/// ✅ Background now syncs with bush/tree speed using a function reference
class _ScrollingBackground extends Component with HasGameRef<CharacterGame> {
  late Sprite bgSprite;
  SpriteComponent? bg1;
  SpriteComponent? bg2;
  final double Function() speedProvider;
  double canvasHeight = 0.0;

  _ScrollingBackground({required this.speedProvider});

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final bgImage = await gameRef.images.load('bg3.png');
    bgSprite = Sprite(bgImage);

    final size = gameRef.size;
    bg1 = SpriteComponent(sprite: bgSprite, size: size, anchor: Anchor.topLeft, position: Vector2(0, 0));
    bg2 = SpriteComponent(sprite: bgSprite, size: size, anchor: Anchor.topLeft, position: Vector2(0, -size.y));

    addAll([bg1!, bg2!]);
    canvasHeight = size.y;
  }

  void resizeToCanvas(Vector2 size) {
    bg1!
      ..size = size
      ..position = Vector2(0, 0);
    bg2!
      ..size = size
      ..position = Vector2(0, -size.y);
    canvasHeight = size.y;
  }

  @override
  void update(double dt) {
    super.update(dt);
    final speed = speedProvider(); // dynamically match bush/tree speed

    bg1!.position.y += speed * dt;
    bg2!.position.y += speed * dt;

    if (bg1!.position.y >= canvasHeight) {
      bg1!.position.y = bg2!.position.y - canvasHeight;
    }
    if (bg2!.position.y >= canvasHeight) {
      bg2!.position.y = bg1!.position.y - canvasHeight;
    }
  }
}

/// ✅ Tree also syncs dynamically to main bush speed
class _Tree extends SpriteComponent with HasGameRef<CharacterGame> {
  final double Function() speedProvider;
  final bool isLeft;
  double canvasHeight;
  final Random _random = Random();

  _Tree({
    required Sprite sprite,
    required Vector2 position,
    required Vector2 size,
    required this.speedProvider,
    required this.canvasHeight,
    required this.isLeft,
  }) : super(sprite: sprite, position: position, size: size, anchor: Anchor.bottomCenter);

  @override
  void update(double dt) {
    super.update(dt);
    final speed = speedProvider();
    position.y += speed * dt;

    if (position.y > canvasHeight + 200) {
      position.y = -_random.nextDouble() * canvasHeight;
      final bool newLeft = _random.nextBool();
      final double canvasWidth = gameRef.size.x > 0 ? gameRef.size.x : 1.0;
      position.x = newLeft ? canvasWidth * 0.05 : canvasWidth * 0.95;
    }
  }
}
