import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/flame.dart';
import 'package:flame_audio/flame_audio.dart'; // Import for audio
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

// Global variable to hold the loaded questions
List<Question> _loadedQuestions = [];

// --- Data Structure for Quiz Questions (mcq.json) ---
class Question {
  final int id;
  final String sentence;
  final Map<String, String> options;
  final String answerKey; // "A", "B", or "C"

  Question({
    required this.id,
    required this.sentence,
    required this.options,
    required this.answerKey,
  });

  factory Question.fromJson(Map<String, dynamic> json) {
    return Question(
      id: json['id'] as int,
      sentence: json['sentence'] as String,
      options: Map<String, String>.from(json['options'] as Map),
      answerKey: json['answer'] as String,
    );
  }

  // Get the correct answer string (e.g., "Ambiguous")
  String get correctAnswer => options[answerKey] ?? 'Unknown';

  // Get the option string for a given key (e.g., options["A"])
  String optionForLane(String key) => options[key] ?? 'Error';
}

// MODIFIED: Function to asynchronously load and parse questions from the asset file
Future<List<Question>> loadQuestions() async {
  try {
    // 1. Load the JSON string from assets/vocab.json
    // NOTE: This assumes you have 'assets/vocab.json' in your project's assets folder
    final String jsonString = await rootBundle.loadString('assets/vocab.json');

    // 2. Decode the JSON string
    final List<dynamic> jsonList = jsonDecode(jsonString);

    // 3. Convert the list of JSON objects to a List<Question>
    return jsonList.map((json) => Question.fromJson(json)).toList();
  } catch (e) {
    // Handle error during loading (e.g., file not found, bad format)
    print("Error loading vocabulary questions: $e");
    return []; // Return an empty list on failure
  }
}


// --- Main Application and GameScreen ---
Future<void> main() async {
  // Ensure the Flutter binding is initialized for rootBundle to work
  WidgetsFlutterBinding.ensureInitialized();

  // Load the questions data before running the app
  _loadedQuestions = await loadQuestions();

  // Initialize Flame engine settings
  Flame.device.fullScreen();
  // Ensure landscape mode is appropriate for the game layout
  // Flame.device.setLandscape();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flame Vocabulary Quiz',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: Colors.black, // Dark background
        cardColor: Colors.grey[900], // Darker card background
      ),
      // Pass the globally loaded questions list to GameScreen
      home: GameScreen(questions: _loadedQuestions),
    );
  }
}

class GameScreen extends StatefulWidget {
  final List<Question> questions; // Accept questions as a parameter
  const GameScreen({super.key, required this.questions});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> {
  late CharacterGame _game;
  final FocusNode _focusNode = FocusNode();
  int _score = 0;
  String _currentQuestionSentence = "";
  List<String> _currentOptionLabels = ["A", "B", "C"]; // Labels for display

  // Constants that mirror the lane X-positions in CharacterGame
  static const double _leftXRatio = 0.15;
  static const double _centerXRatio = 0.50;
  static const double _rightXRatio = 0.87;

  // NEW: Coin score calculation
  int get _coinScore => _score * 50;


  @override
  void initState() {
    super.initState();
    // Use widget.questions
    _game = CharacterGame(
      questions: widget.questions,
      onGameOver: _showGameOver,
      onNextQuestion: _updateUI,
      onScoreChange: (score) {
        setState(() => _score = score);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
      if (_game.questions.isNotEmpty) {
        _updateUI(_game.currentQuestion, 0); // Initial UI update
      }
    });
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _game.pauseEngine();
    // FIX: Replaced FlameAudio.stop() with FlameAudio.bgm.stop()
    FlameAudio.bgm.stop(); // Ensure music stops when the widget is disposed
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
    } else if (event is RawKeyUpEvent) {
      // Stop moving animation when key is released
    }
  }

  void _updateUI(Question question, int laneIndex) {
    // 0 = Left (A), 1 = Center (B), 2 = Right (C)
    final optionsKeys = ['A', 'B', 'C'];
    final labels = optionsKeys.map((key) => question.optionForLane(key)).toList();

    setState(() {
      _currentQuestionSentence = "Q${question.id}: ${question.sentence}";
      _currentOptionLabels = labels;
    });
  }

  void _showGameOver() {
    // Music is already stopped within CharacterGame before calling this.

    // Resume engine briefly for screen effect before showing dialog
    _game.resumeEngine();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Assuming 'assets/images/character_snake.png' is correctly configured in pubspec.yaml
            Image.asset('assets/images/character_snake.png', height: 100),
            const SizedBox(height: 10),
            // MODIFIED: Show final score and coin score
            Text('Final Correct Answers: $_score\n'
                'Final Coin Score: $_coinScore\n'
                'You collided with the Snake'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                // Use widget.questions for restart
                _game = CharacterGame(
                  questions: widget.questions,
                  onGameOver: _showGameOver,
                  onNextQuestion: _updateUI,
                  onScoreChange: (score) {
                    setState(() => _score = score);
                  },
                );
                _score = 0;
                // Re-setup is handled within the game's onLoad/setup, but we need
                // to explicitly request the initial UI update after creating the new game instance.
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (_game.questions.isNotEmpty) {
                    _updateUI(_game.currentQuestion, 0);
                  }
                });
                // FIX: Start the background music again after pressing restart
                FlameAudio.bgm.play('BG.mp3');
              });
              _focusNode.requestFocus();
            },
            child: const Text('Restart'),
          ),
        ],
      ),
    );
    _game.pauseEngine(); // Re-pause engine after showing dialog
  }

  @override
  Widget build(BuildContext context) {
    // Determine the actual X positions based on the AspectRatio and screen width
    // ... (unchanged)
    // final double screenWidth = MediaQuery.of(context).size.width;

    // We use Align widgets with a fractional width to center the labels relative
    // to their respective lane X positions within the game container.
    final double leftAlignment = _leftXRatio * 2 - 1; // 0.4 - 1 = -0.6 (Left side)
    final double centerAlignment = _centerXRatio * 2 - 1; // 1.0 - 1 = 0.0 (Center)
    final double rightAlignment = _rightXRatio * 2 - 1; // 1.6 - 1 = 0.6 (Right side)

    // Fixed vertical position for the options
    const double optionsTopPosition = 120;

    // Add a check to handle the case where questions failed to load
    if (widget.questions.isEmpty) {
      return const Scaffold(
        body: Center(
          child: Text('Error: Could not load quiz questions.',
              style: TextStyle(color: Colors.red)),
        ),
      );
    }

    return Scaffold(
      body: RawKeyboardListener(
        focusNode: _focusNode,
        autofocus: true,
        onKey: _onRawKey,
        child: Center(
          child: AspectRatio(
            aspectRatio: 10 / 16,
            child: Container(
              color: Colors.black,
              child: Stack(
                children: [
                  GameWidget(game: _game),

                  // Score and Question Display (Positioned at Top)
                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // NEW: Score and Coin Score Row
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('Correct: $_score',
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                              const SizedBox(width: 30),
                              // Coin Animation and Score
                              SizedBox(
                                width: 30, // Adjust size for coin image
                                height: 30,
                                // Use a Container to host the Coin Animation from Flame
                                child: GameWidget(
                                  game: _game.coinAnimationGame, // Pass the small CoinGame instance
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text('$_coinScore', // Display the coin score
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.yellowAccent)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Card(
                            color: Colors.grey[850],
                            elevation: 5,
                            child: Padding(
                              padding: const EdgeInsets.all(12.0),
                              child: Text(
                                _currentQuestionSentence,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontSize: 16, color: Colors.lightGreenAccent),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Option Label A (Left Lane)
                  Positioned(
                    top: optionsTopPosition,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(leftAlignment, 0),
                      child: _OptionLabel(label: "A", text: _currentOptionLabels[0]),
                    ),
                  ),

                  // Option Label B (Center Lane)
                  Positioned(
                    top: optionsTopPosition,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(centerAlignment, 0),
                      child: _OptionLabel(label: "B", text: _currentOptionLabels[1]),
                    ),
                  ),

                  // Option Label C (Right Lane)
                  Positioned(
                    top: optionsTopPosition,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(rightAlignment, 0),
                      child: _OptionLabel(label: "C", text: _currentOptionLabels[2]),
                    ),
                  ),


                  // Movement Buttons (for mobile/touch)
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
      ),
    );
  }
}

class _OptionLabel extends StatelessWidget {
  final String label;
  final String text;
  const _OptionLabel({required this.label, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 100), // Limit width
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.blueGrey.withOpacity(0.9),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white, width: 1),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.yellowAccent)),
          const SizedBox(height: 2),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 10, color: Colors.white),
            overflow: TextOverflow.ellipsis, // Prevent long text from breaking layout
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}


// --- NEW: Coin Animation Component ---

/// Component to display the spinning coin animation.
class CoinAnimationComponent extends SpriteAnimationComponent {
  CoinAnimationComponent() : super(size: Vector2.all(30));

  // MODIFICATION START: Set paint with BlendMode to attempt transparency
  @override
  final paint = Paint()
    ..filterQuality = FilterQuality.high
  // Using BlendMode.modulate or BlendMode.srcOver often works for sprites
  // with solid black backgrounds that should be transparent.
    ..blendMode = BlendMode.srcOver;
  // MODIFICATION END

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    final images = Flame.images;

    // Load coin sprites from coin1.png to coin5.png
    final List<Sprite> coinSprites = [];
    for (int i = 1; i <= 5; i++) {
      // NOTE: Assumes you have coin1.png, coin2.png, ... coin5.png
      coinSprites.add(Sprite(await images.load('coin$i.png')));
    }
    // To complete the loop back to coin1, we use 5 frames
    // If you have coin6.png, you can load it here. Assuming only 5 based on the prompt's list:
    // "coin1.png, coin2.png, coin3.png, coin4.png, coin5.png"

    animation = SpriteAnimation.spriteList(
      coinSprites,
      stepTime: 0.1, // Time between frames
      loop: true,
    );
  }
}

/// A mini-game container for the CoinAnimationComponent,
/// allowing it to be used within the Flutter Widget tree.
class CoinAnimationGame extends FlameGame {
  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // The component is sized in the Widget tree, so we use a small default size here
    add(CoinAnimationComponent());
  }
}

// --- Character Component for Animation (Unchanged) ---
class Character extends SpriteAnimationGroupComponent<CharacterState> with HasGameRef<CharacterGame> {
  // ... (Character class implementation remains the same)
  final double speed;
  CharacterState _currentState = CharacterState.walk;
  double _animationTimeLeft = 0.0;
  final double _turnDuration = 0.15; // Time to display the turn frame

  Character({
    required Vector2 size,
    required Vector2 position,
    required this.speed,
  }) : super(
    size: size,
    position: position,
    anchor: Anchor.bottomCenter,
  );

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // Load Sprites using gameRef.images or Flame.images
    final images = Flame.images; // Access global ImageCache

    final walk1 = await images.load('character_walking_right1.png');
    final walk2 = await images.load('character_walking_right2.png');
    final leftTurn = await images.load('LEFT.png');
    final rightTurn = await images.load('RIGHT.png');

    // Create Animations
    final walkAnimation = SpriteAnimation.spriteList(
      [Sprite(walk1), Sprite(walk2)],
      stepTime: 0.15, // Time between frames for walking
      loop: true,
    );

    final leftTurnAnimation = SpriteAnimation.fromFrameData(
      leftTurn,
      SpriteAnimationData.sequenced(
        amount: 1,
        stepTime: _turnDuration,
        textureSize: Vector2.all(leftTurn.width.toDouble()), // Assuming square frames
        loop: false,
      ),
    );

    final rightTurnAnimation = SpriteAnimation.fromFrameData(
      rightTurn,
      SpriteAnimationData.sequenced(
        amount: 1,
        stepTime: _turnDuration,
        textureSize: Vector2.all(rightTurn.width.toDouble()), // Assuming square frames
        loop: false,
      ),
    );

    // Set all available animations
    animations = {
      CharacterState.walk: walkAnimation,
      CharacterState.left: leftTurnAnimation,
      CharacterState.right: rightTurnAnimation,
    };

    current = CharacterState.walk;
  }

  void turnLeft() {
    if (current == CharacterState.left) return; // Prevent restart if already turning left
    current = CharacterState.left;
    _animationTimeLeft = _turnDuration;
  }

  void turnRight() {
    if (current == CharacterState.right) return; // Prevent restart if already turning right
    current = CharacterState.right;
    _animationTimeLeft = _turnDuration;
  }

  void returnToWalk() {
    if (current != CharacterState.walk) {
      current = CharacterState.walk;
      _animationTimeLeft = 0.0;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    if (_animationTimeLeft > 0) {
      _animationTimeLeft -= dt;
      if (_animationTimeLeft <= 0) {
        returnToWalk();
      }
    }
  }
}

enum CharacterState {
  walk,
  left,
  right,
}


// ----------------------------------
// --- Flame Game Classes (MODIFIED for Coin Game and Audio) ---
// ----------------------------------

class CharacterGame extends FlameGame {
  final List<Question> questions;
  final VoidCallback onGameOver;
  final Function(Question question, int laneIndex) onNextQuestion;
  final Function(int score) onScoreChange;

  // NEW: Game instance for the Coin Animation widget
  final CoinAnimationGame coinAnimationGame = CoinAnimationGame();

  CharacterGame({
    required this.questions,
    required this.onGameOver,
    required this.onNextQuestion,
    required this.onScoreChange,
  });

  Character? character;
  final List<_ObstacleBush> bushes = [];
  List<_Tree> trees = [];

  _ScrollingBackground? bg;

  int _posIndex = 1; // 0 = Left, 1 = Center, 2 = Right
  late double _leftX;
  late double _centerX;
  late double _rightX;

  double _targetX = 0.0;
  final double _moveSpeed = 900.0;
  final double _bushSpeed = 150.0;
  double _canvasHeight = 0.0;

  bool _isGameOver = false;
  final Random _random = Random();

  // MODIFIED: _currentQuestionIndex will now loop
  int _currentQuestionIndex = 0;
  int _score = 0;
  int _correctLaneIndex = 0;

  // NEW: Sprites for the bushes
  late Sprite _normalBushSprite;
  late Sprite _snakeBushSprite;

  // NEW: Character collision window for sprite change
  // Transformation starts when bush is this far *above* the character's feet
  static const double _bushTransformStartOffset = 50.0;
  // Transformation ends when bush is this far *below* the character's feet
  static const double _bushTransformEndOffset = 0.0;


  Question get currentQuestion => questions[_currentQuestionIndex];

  static const Map<int, String> _laneIndexToKey = {
    0: 'A',
    1: 'B',
    2: 'C',
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // NEW: Initialize the BGM manager
    await FlameAudio.bgm.initialize();

    // NEW: Load the music asset for pre-caching
    await FlameAudio.audioCache.loadAll(['BG.mp3', 'Kill_sound.mp3']);

    // Ensure the CoinAnimationGame also loads its assets
    await coinAnimationGame.onLoad();

    // Load Image Assets
    final images = Flame.images;
    // NOTE: Ensure 'assets/images/bush.png' and 'assets/images/bush_snake.png' exist
    _normalBushSprite = Sprite(await images.load('bush.png'));
    _snakeBushSprite = Sprite(await images.load('bush_snake.png'));

    bg = _ScrollingBackground(speedProvider: () => _bushSpeed);
    add(bg!);

    // Character
    character = Character(
      size: Vector2(100, 100),
      position: Vector2(0, 0), // Will be set correctly in _updatePositions
      speed: _moveSpeed,
    );
    add(character!);

    // Bushes (Obstacles)
    for (int i = 0; i < 3; i++) {
      final bush = _ObstacleBush(
        normalSprite: _normalBushSprite,
        snakeSprite: _snakeBushSprite, // Pass the snake sprite
        size: Vector2(120, 100),
        bushIndex: i, // 0=Left, 1=Center, 2=Right
      );
      bushes.add(bush);
      add(bush);
    }

    // Trees (Decorative)
    for (int i = 1; i <= 6; i++) {
      // NOTE: Ensure 'assets/images/treeX.png' exist (X=1 to 6)
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

    // Initial Question setup and bush repositioning
    if (questions.isNotEmpty) {
      _setupNextQuestion();
    }

    // FIX: Start the background music loop using the BGM manager
    FlameAudio.bgm.play('BG.mp3');
  }

  @override
  void onGameResize(Vector2 canvasSize) {
    super.onGameResize(canvasSize);
    // Also resize the coin game container, though it's less critical as it's small.
    coinAnimationGame.onGameResize(Vector2.all(30));

    if (canvasSize.x <= 0 || canvasSize.y <= 0) return;

    _updatePositions(canvasSize);
    _canvasHeight = canvasSize.y;
    bg?.resizeToCanvas(canvasSize);

    for (final tree in trees) {
      tree.canvasHeight = canvasSize.y;
    }
  }

  void _updatePositions(Vector2 canvasSize) {
    // These positions are relative to the ASPECT RATIO container
    _leftX = canvasSize.x * 0.20;
    _centerX = canvasSize.x * 0.50;
    _rightX = canvasSize.x * 0.80;
    _canvasHeight = canvasSize.y;
    _targetX = _xForIndex(_posIndex);

    if (character != null) {
      // Position character slightly above the very bottom
      character!.position = Vector2(_targetX, canvasSize.y - 16);
    }

    if (bushes.length == 3) {
      // Set the initial/reset Y positions for the bushes just off-screen top
      bushes[0].position = Vector2(_leftX, -bushes[0].size.y);
      bushes[1].position = Vector2(_centerX, -bushes[1].size.y);
      bushes[2].position = Vector2(_rightX, -bushes[2].size.y);
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
    if (newIndex != _posIndex) {
      character?.turnLeft(); // Trigger the left turn animation
    }
    _moveToIndex(newIndex);
  }

  void moveRight() {
    if (_isGameOver) return;
    final newIndex = (_posIndex + 1).clamp(0, 2);
    if (newIndex != _posIndex) {
      character?.turnRight(); // Trigger the right turn animation
    }
    _moveToIndex(newIndex);
  }

  void _moveToIndex(int newIndex) {
    if (newIndex == _posIndex) return;
    _posIndex = newIndex;
    _targetX = _xForIndex(newIndex);
  }

  bool _checkCollision(PositionComponent obj1, PositionComponent obj2) {
    // Check collision based on the Rects
    return obj1.toRect().overlaps(obj2.toRect());
  }

  // MODIFIED: Implements the infinite loop by using the modulus operator (%)
  void _setupNextQuestion() {
    if (questions.isEmpty) {
      _isGameOver = true;
      pauseEngine();
      onGameOver();
      return;
    }

    // MODIFIED: Use the modulus operator to cycle the index indefinitely
    _currentQuestionIndex = (_currentQuestionIndex) % questions.length;

    final question = currentQuestion;
    final answerKey = question.answerKey;

    // Determine the lane index (0, 1, or 2) of the correct answer
    _correctLaneIndex = _laneIndexToKey.entries.firstWhere((entry) => entry.value == answerKey).key;

    onNextQuestion(question, _correctLaneIndex);

    // Reset bushes for the next question
    for (int i = 0; i < bushes.length; i++) {
      final bush = bushes[i];

      // Determine if this bush is the CORRECT or WRONG option
      bush.isCorrectOption = (i == _correctLaneIndex);

      // Reset bush state and position to the top of the screen
      bush.resetState();
      bush.position.y = -bush.size.y;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (_isGameOver) return;

    // Also update the coin game, though its internal logic is just animation
    coinAnimationGame.update(dt);

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
        // Ensure character returns to walking animation once movement is complete
        if(character?.current != CharacterState.walk) {
          character?.returnToWalk();
        }
      }
    }

    // Bushes
    for (final bush in bushes) {
      bush.position.y += _bushSpeed * dt;

      if (character != null) {
        // Character's 'foot' position (bottom-center anchor)
        final charY = character!.position.y;
        final charHeight = character!.size.y;
        final bushY = bush.position.y;
        final bushHeight = bush.size.y;

        // Check for sprite transformation window
        final isNearCharacter = bushY >= charY - _bushTransformStartOffset &&
            bushY <= charY - _bushTransformEndOffset;

        if (isNearCharacter) {
          // Logic for sprite change
          if (!bush.isCorrectOption && !bush.isSnake) {
            bush.turnToSnake();
          }
        } else if (bushY > charY) {
          // If the bush has passed the character, reset snake state (if it was a wrong option)
          if (bush.isSnake) {
            bush.turnToNormal();
          }
        }

        // 1. Collision Check (Trigger when bush is near the character's feet)
        const double collisionWindowOffset = 10.0;
        if (bushY >= charY - collisionWindowOffset && bushY - bushHeight < charY) {
          if (_checkCollision(character!, bush)) {
            // Collision logic: Collision with WRONG option -> Game Over
            if (!bush.isCorrectOption) {
              _isGameOver = true;
              pauseEngine();
              // FIX: Stop the background music on game over
              FlameAudio.bgm.stop();

              // NEW: Play the kill sound
              FlameAudio.play('Kill_sound.mp3');

              onGameOver();
              return;
            }
            // Collision with correct option is OK
          }
        }

        // 2. Pass Through Check (Check if the bush has passed the character's line)
        if (bushY > charY && !bush.hasPassed) {
          // Bush has passed the character's y-position (bottom anchor).

          // If the *correct* option bush passes, it means the player successfully landed in its lane.
          if (bush.isCorrectOption) {
            bush.hasPassed = true; // Mark as passed to prevent multiple scoring

            // If the correct bush passes, it's a win for the question.
            _score++;
            onScoreChange(_score);

            // MODIFIED: Increment the index to get the next question in the loop
            _currentQuestionIndex++;
            _setupNextQuestion();
            return;
          } else {
            // Wrong bushes also pass.
            bush.hasPassed = true;
          }
        }
      }

      // 3. Off-Screen Reset (Bushes reset off-screen top once they are completely below the screen)
      // This is a safety reset; the question logic usually handles repositioning.
      if (bush.position.y > _canvasHeight + 100) {
        bush.position.y = -_canvasHeight;
        bush.resetState();
      }
    }
  }
}

/// Obstacle/Option Component
class _ObstacleBush extends SpriteComponent {
  final int bushIndex; // 0, 1, or 2 (Lane Index)
  final Sprite normalSprite;
  final Sprite snakeSprite;

  bool isCorrectOption = false;
  bool hasPassed = false;
  bool isSnake = false; // Track if the sprite has changed

  _ObstacleBush({
    required this.normalSprite,
    required this.snakeSprite,
    required Vector2 size,
    required this.bushIndex,
  }) : super(sprite: normalSprite, size: size, anchor: Anchor.bottomCenter);

  // Change the sprite to the snake bush
  void turnToSnake() {
    if (!isSnake) {
      sprite = snakeSprite;
      isSnake = true;
    }
  }

  // Change the sprite back to the normal bush
  void turnToNormal() {
    if (isSnake) {
      sprite = normalSprite;
      isSnake = false;
    }
  }

  // Reset the state for the next question
  void resetState() {
    turnToNormal(); // Ensure it's the normal bush initially
    hasPassed = false;
    // isCorrectOption is set externally by CharacterGame
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw visual feedback borders for debugging/visual aid (OPTIONAL, can be removed)
    if (isCorrectOption) {
      final Paint correctPaint = Paint()
        ..color = Colors.green.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      canvas.drawRect(toRect(), correctPaint);
    } else {
      final Paint wrongPaint = Paint()
        ..color = Colors.red.withOpacity(0.5)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;
      canvas.drawRect(toRect(), wrongPaint);
    }
  }
}


/// Scrolling Background Component
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
    // Use gameRef.images or Flame.images
    // NOTE: Ensure 'assets/images/bg3.png' exists
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
    final speed = speedProvider();

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

/// Decorative Tree Component
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