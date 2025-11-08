import 'dart:convert';
import 'dart:math';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/sprite.dart';
import 'package:flame/flame.dart'; // FIX: Add the main Flame import for asset access
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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

// --- Hardcoded MCQ Data (from mcq.json) ---
const String _mcqJson = '''
[
  {
    "id": 1,
    "sentence": "Having more than one meaning; unclear",
    "options": {
      "A": "Ambiguous",
      "B": "Benevolent",
      "C": "Meticulous"
    },
    "answer": "A"
  },
  {
    "id": 2,
    "sentence": "Kind and generous",
    "options": {
      "A": "Superfluous",
      "B": "Benevolent",
      "C": "Frivolous"
    },
    "answer": "B"
  },
  {
    "id": 3,
    "sentence": "Honest and straightforward",
    "options": {
      "A": "Candid",
      "B": "Pragmatic",
      "C": "Impartial"
    },
    "answer": "A"
  },
  {
    "id": 4,
    "sentence": "To agree",
    "options": {
      "A": "Concur",
      "B": "Frivolous",
      "C": "Ambiguous"
    },
    "answer": "A"
  },
  {
    "id": 5,
    "sentence": "Hardworking and careful",
    "options": {
      "A": "Meticulous",
      "B": "Diligent",
      "C": "Superfluous"
    },
    "answer": "B"
  },
  {
    "id": 6,
    "sentence": "Not serious or important; silly",
    "options": {
      "A": "Frivolous",
      "B": "Pragmatic",
      "C": "Candid"
    },
    "answer": "A"
  },
  {
    "id": 7,
    "sentence": "Fair and not biased",
    "options": {
      "A": "Benevolent",
      "B": "Impartial",
      "C": "Pragmatic"
    },
    "answer": "B"
  },
  {
    "id": 8,
    "sentence": "Very careful and precise",
    "options": {
      "A": "Ambiguous",
      "B": "Diligent",
      "C": "Meticulous"
    },
    "answer": "C"
  },
  {
    "id": 9,
    "sentence": "Dealing with things realistically; practical",
    "options": {
      "A": "Pragmatic",
      "B": "Frivolous",
      "C": "Impartial"
    },
    "answer": "A"
  },
  {
    "id": 10,
    "sentence": "Unnecessary; more than needed",
    "options": {
      "A": "Superfluous",
      "B": "Candid",
      "C": "Ambiguous"
    },
    "answer": "A"
  }
]
''';

List<Question> parseQuestions() {
  final List<dynamic> jsonList = jsonDecode(_mcqJson);
  return jsonList.map((json) => Question.fromJson(json)).toList();
}


// --- Main Application and GameScreen ---
void main() {
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
  int _score = 0;
  String _currentQuestionSentence = "";
  List<String> _currentOptionLabels = ["A", "B", "C"]; // Labels for display

  // Constants that mirror the lane X-positions in CharacterGame
  static const double _leftXRatio = 0.15;
  static const double _centerXRatio = 0.50;
  static const double _rightXRatio = 0.87;

  @override
  void initState() {
    super.initState();
    final questions = parseQuestions();
    _game = CharacterGame(
      questions: questions,
      onGameOver: _showGameOver,
      onNextQuestion: _updateUI,
      onScoreChange: (score) {
        setState(() => _score = score);
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNode.requestFocus();
      _updateUI(_game.currentQuestion, 0); // Initial UI update
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
    // Resume engine briefly for screen effect before showing dialog
    _game.resumeEngine();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Game Over! 💥'),
        content: Text('You scored: $_score out of ${_game.questions.length}.\n'
            'You collided with the **WRONG** answer.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              setState(() {
                final questions = parseQuestions();
                _game = CharacterGame(
                  questions: questions,
                  onGameOver: _showGameOver,
                  onNextQuestion: _updateUI,
                  onScoreChange: (score) {
                    setState(() => _score = score);
                  },
                );
                _score = 0;
                _updateUI(_game.currentQuestion, 0);
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
    final double screenWidth = MediaQuery.of(context).size.width;
    // Assuming the GameWidget occupies the width determined by the AspectRatio
    final double gameWidth = screenWidth > 0 ? screenWidth : 10;

    // We use Align widgets with a fractional width to center the labels relative
    // to their respective lane X positions within the game container.
    final double leftAlignment = _leftXRatio * 2 - 1; // 0.4 - 1 = -0.6 (Left side)
    final double centerAlignment = _centerXRatio * 2 - 1; // 1.0 - 1 = 0.0 (Center)
    final double rightAlignment = _rightXRatio * 2 - 1; // 1.6 - 1 = 0.6 (Right side)

    // Fixed vertical position for the options
    const double optionsTopPosition = 120;

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
                          Text('Score: $_score/${_game.questions.length}',
                              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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

                  // MODIFIED: Option Label A (Left Lane)
                  Positioned(
                    top: optionsTopPosition,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(leftAlignment, 0),
                      child: _OptionLabel(label: "A", text: _currentOptionLabels[0]),
                    ),
                  ),

                  // MODIFIED: Option Label B (Center Lane)
                  Positioned(
                    top: optionsTopPosition,
                    left: 0,
                    right: 0,
                    child: Align(
                      alignment: Alignment(centerAlignment, 0),
                      child: _OptionLabel(label: "B", text: _currentOptionLabels[1]),
                    ),
                  ),

                  // MODIFIED: Option Label C (Right Lane)
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


// --- NEW Character Component for Animation ---
class Character extends SpriteAnimationGroupComponent<CharacterState> with HasGameRef<CharacterGame> {
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
// --- Flame Game Classes (Updated) ---
// ----------------------------------

class CharacterGame extends FlameGame {
  final List<Question> questions;
  final VoidCallback onGameOver;
  final Function(Question question, int laneIndex) onNextQuestion;
  final Function(int score) onScoreChange;

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

  int _currentQuestionIndex = 0;
  int _score = 0;
  int _correctLaneIndex = 0;

  Question get currentQuestion => questions[_currentQuestionIndex];

  static const Map<int, String> _laneIndexToKey = {
    0: 'A',
    1: 'B',
    2: 'C',
  };

  @override
  Future<void> onLoad() async {
    await super.onLoad();

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
    final bushImage = await Flame.images.load('bush.png');
    final bushSprite = Sprite(bushImage);
    for (int i = 0; i < 3; i++) {
      final bush = _ObstacleBush(
        sprite: bushSprite,
        size: Vector2(150, 100),
        bushIndex: i, // 0=Left, 1=Center, 2=Right
      );
      bushes.add(bush);
      add(bush);
    }

    // Trees (Decorative)
    for (int i = 1; i <= 6; i++) {
      final img = await Flame.images.load('tree$i.png'); // FIX: Use Flame.images
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
    _setupNextQuestion();
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
    return obj1.toRect().overlaps(obj2.toRect());
  }

  void _setupNextQuestion() {
    if (_currentQuestionIndex >= questions.length) {
      // Game finished all questions
      _isGameOver = true;
      pauseEngine();
      onGameOver(); // Re-use game over dialog for completion message
      return;
    }

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

      // Reset bush position to the top of the screen
      bush.position.y = -bush.size.y;
      bush.hasPassed = false; // Reset pass tracker
    }
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
        // Ensure character returns to walking animation once movement is complete
        if(character?.current != CharacterState.walk) {
          character?.returnToWalk();
        }
      }
    }

    // Bushes
    for (final bush in bushes) {
      bush.position.y += _bushSpeed * dt;

      // 1. Collision Check (Only check when the bush is near the character)
      if (character != null &&
          bush.position.y > character!.position.y - character!.size.y &&
          bush.position.y < character!.position.y + character!.size.y / 2) {

        if (_checkCollision(character!, bush)) {
          // Collision logic: Collision with WRONG option -> Game Over
          if (!bush.isCorrectOption) {
            _isGameOver = true;
            pauseEngine();
            onGameOver();
            return;
          }
        }
      }

      // 2. Pass Through Check (Check if the bush has passed the character's line)
      if (character != null && bush.position.y > character!.position.y) {
        // Bush has passed the character line.

        // If the correct option bush passes, it means the player successfully avoided it.
        if (bush.isCorrectOption && !bush.hasPassed) {
          bush.hasPassed = true; // Mark as passed to prevent multiple scoring

          // Check if ALL bushes have passed, then move to the next question.
          if (bushes.every((b) => b.hasPassed || !b.isCorrectOption)) {
            // Successful: All wrong options avoided (checked by collision), correct option passed through.
            _score++;
            onScoreChange(_score);
            _currentQuestionIndex++;
            _setupNextQuestion();
            return;
          }
        }
      }

      // 3. Off-Screen Reset (Bushes reset off-screen top once they are completely below the screen)
      if (bush.position.y > _canvasHeight + 100) {
        // If a wrong bush goes off-screen, it means the player successfully avoided it.
        // This bush is now irrelevant until the next question is set.
        bush.position.y = -_canvasHeight; // Keep it out of sight until next question setup
        bush.hasPassed = false;
      }
    }
  }
}

/// Obstacle/Option Component
class _ObstacleBush extends SpriteComponent {
  final int bushIndex; // 0, 1, or 2 (Lane Index)
  bool isCorrectOption = false;
  bool hasPassed = false; // To track if the correct bush has passed the character line

  _ObstacleBush({
    required Sprite sprite,
    required Vector2 size,
    required this.bushIndex,
  }) : super(sprite: sprite, size: size, anchor: Anchor.bottomCenter);

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    // Draw visual feedback borders for debugging/visual aid
    if (isCorrectOption) {
      final Paint correctPaint = Paint()
        ..color = Colors.redAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5.0;
      canvas.drawRect(toRect(), correctPaint);
    } else {
      final Paint wrongPaint = Paint()
        ..color = Colors.green
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