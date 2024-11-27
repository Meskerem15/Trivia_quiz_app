import 'package:flutter/material.dart';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() => runApp(QuizApp());

class QuizApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: QuizSetupScreen(),
    );
  }
}

class QuizSetupScreen extends StatefulWidget {
  @override
  _QuizSetupScreenState createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  List categories = [];
  String? selectedCategory;
  String? selectedDifficulty = 'easy';
  String? selectedType = 'multiple';
  int numberOfQuestions = 5;

  @override
  void initState() {
    super.initState();
    fetchCategories();
  }

  Future<void> fetchCategories() async {
    final response =
        await http.get(Uri.parse('https://opentdb.com/api_category.php'));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        categories = data['trivia_categories'];
      });
    }
  }

  void startQuiz() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => QuizScreen(
          category: selectedCategory,
          difficulty: selectedDifficulty,
          type: selectedType,
          numberOfQuestions: numberOfQuestions,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quiz Setup')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Select Number of Questions:'),
            Slider(
              value: numberOfQuestions.toDouble(),
              min: 5,
              max: 15,
              divisions: 2,
              label: numberOfQuestions.toString(),
              onChanged: (value) {
                setState(() {
                  numberOfQuestions = value.toInt();
                });
              },
            ),
            SizedBox(height: 10),
            Text('Select Category:'),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedCategory,
              hint: Text('Choose a category'),
              items: categories
                  .map((category) => DropdownMenuItem<String>(
                        value: category['id'].toString(),
                        child: Text(category['name']),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedCategory = value;
                });
              },
            ),
            SizedBox(height: 10),
            Text('Select Difficulty:'),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedDifficulty,
              items: ['easy', 'medium', 'hard']
                  .map((difficulty) => DropdownMenuItem<String>(
                        value: difficulty,
                        child: Text(difficulty),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedDifficulty = value;
                });
              },
            ),
            SizedBox(height: 10),
            Text('Select Question Type:'),
            DropdownButton<String>(
              isExpanded: true,
              value: selectedType,
              items: ['multiple', 'boolean']
                  .map((type) => DropdownMenuItem<String>(
                        value: type,
                        child: Text(type == 'multiple'
                            ? 'Multiple Choice'
                            : 'True/False'),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  selectedType = value;
                });
              },
            ),
            Spacer(),
            Center(
              child: ElevatedButton(
                onPressed: startQuiz,
                child: Text('Start Quiz'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuizScreen extends StatefulWidget {
  final String? category;
  final String? difficulty;
  final String? type;
  final int numberOfQuestions;

  QuizScreen({
    required this.category,
    required this.difficulty,
    required this.type,
    required this.numberOfQuestions,
  });

  @override
  _QuizScreenState createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  List questions = [];
  int currentIndex = 0;
  int score = 0;
  bool answered = false;
  String? selectedAnswer;
  int _timeLeft = 15;
  Timer? _timer;
  List<Map<String, dynamic>> answerHistory = [];

  @override
  void initState() {
    super.initState();
    fetchQuestions();
  }

  Future<void> fetchQuestions() async {
    String url =
        'https://opentdb.com/api.php?amount=${widget.numberOfQuestions}';
    if (widget.category != null) url += '&category=${widget.category}';
    if (widget.difficulty != null) url += '&difficulty=${widget.difficulty}';
    if (widget.type != null) url += '&type=${widget.type}';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      setState(() {
        questions = data['results'];
      });
      startTimer();
    }
  }

  void startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeLeft > 0) {
          _timeLeft--;
        } else {
          timer.cancel();
          handleTimeout();
        }
      });
    });
  }

  void handleTimeout() {
    if (!answered) {
      setState(() {
        answered = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Time's up!")),
      );
      nextQuestion();
    }
  }

  void answerQuestion(bool isCorrect) {
    if (!answered) {
      setState(() {
        answered = true;
        if (isCorrect) score++;
      });
      answerHistory.add({
        'question': questions[currentIndex]['question'],
        'correct_answer': questions[currentIndex]['correct_answer'],
        'user_answer': selectedAnswer,
        'is_correct': isCorrect,
      });
      if (!isCorrect) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(
                  'Correct Answer: ${questions[currentIndex]['correct_answer']}')),
        );
      }
      nextQuestion();
    }
  }

  void nextQuestion() {
    _timer?.cancel();
    if (currentIndex + 1 < questions.length) {
      setState(() {
        currentIndex++;
        answered = false;
        _timeLeft = 15;
      });
      startTimer();
    } else {
      endQuiz();
    }
  }

  void endQuiz() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (context) => QuizSummaryScreen(
          score: score,
          totalQuestions: questions.length,
          answerHistory: answerHistory,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (questions.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Quiz')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final question = questions[currentIndex];
    final answers = List<String>.from(question['incorrect_answers'])
      ..add(question['correct_answer']);
  
    return Scaffold(
      appBar: AppBar(
        title: Text('Question ${currentIndex + 1}'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: (currentIndex + 1) / questions.length,
            ),
            SizedBox(height: 10),
            Text(question['question']),
            Spacer(),
            ...answers.map((answer) {
              return ElevatedButton(
                onPressed: answered
                    ? null
                    : () {
                        setState(() {
                          selectedAnswer = answer;
                        });
                        answerQuestion(answer == question['correct_answer']);
                      },
                child: Text(answer),
              );
            }),
            Spacer(),
            Text('Time left: $_timeLeft seconds'),
          ],
        ),
      ),
    );
  }
}

class QuizSummaryScreen extends StatelessWidget {
  final int score;
  final int totalQuestions;
  final List<Map<String, dynamic>> answerHistory;

  QuizSummaryScreen({
    required this.score,
    required this.totalQuestions,
    required this.answerHistory,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Quiz Summary')),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Total Score: $score/$totalQuestions',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            for (var history in answerHistory)
              Text(
                '${history['question']}\nYour Answer: ${history['user_answer']}\nCorrect Answer: ${history['correct_answer']}\n\n',
              ),
            Spacer(),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizSetupScreen(),
                  ),
                );
              },
              child: Text('Return to home Screen'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => QuizScreen(
                      category: null,
                      difficulty: 'easy',
                      type: 'multiple',
                      numberOfQuestions: 5,
                    ),
                  ),
                );
              },
              child: Text('Retake Quiz'),
            ),
          ],
        ),
      ),
    );
  }
}
