import 'package:flutter/foundation.dart';
import 'package:gen_ui/features/quiz/data/quiz_generation_service.dart';
import 'package:gen_ui/features/quiz/domain/models/quiz_models.dart';

class QuizController extends ChangeNotifier {
  QuizController({required QuizGenerationService generationService})
    : _generationService = generationService;

  final QuizGenerationService _generationService;

  Quiz? _quiz;
  bool _isGenerating = false;
  bool _isSubmitting = false;
  String? _errorMessage;
  int _currentQuestionIndex = 0;
  final Map<String, String> _selectedAnswers = <String, String>{};
  final Map<String, String> _submittedAnswers = <String, String>{};

  Quiz? get quiz => _quiz;
  bool get isGenerating => _isGenerating;
  bool get isSubmitting => _isSubmitting;
  String? get errorMessage => _errorMessage;
  int get currentQuestionIndex => _currentQuestionIndex;
  int get totalQuestions => _quiz?.questions.length ?? 0;
  bool get hasQuiz => _quiz != null;

  QuizQuestion? get currentQuestion {
    final quiz = _quiz;
    if (quiz == null || currentQuestionIndex < 0) {
      return null;
    }

    if (currentQuestionIndex >= quiz.questions.length) {
      return null;
    }

    return quiz.questions[currentQuestionIndex];
  }

  String? get selectedAnswerForCurrentQuestion {
    final question = currentQuestion;
    if (question == null) {
      return null;
    }
    return _selectedAnswers[question.id];
  }

  bool get isCurrentQuestionSubmitted {
    final question = currentQuestion;
    if (question == null) {
      return false;
    }
    return _submittedAnswers.containsKey(question.id);
  }

  bool get isQuizComplete {
    final quiz = _quiz;
    if (quiz == null) {
      return false;
    }
    return _currentQuestionIndex >= quiz.questions.length - 1 &&
        isCurrentQuestionSubmitted;
  }

  bool get isResultVisible {
    final quiz = _quiz;
    if (quiz == null || quiz.questions.isEmpty) {
      return false;
    }

    final lastQuestion = quiz.questions.last;
    return _submittedAnswers.containsKey(lastQuestion.id);
  }

  int get correctAnswers {
    if (_quiz == null) {
      return 0;
    }

    var count = 0;
    for (final question in _quiz!.questions) {
      final answer = _submittedAnswers[question.id];
      if (answer == question.correctAnswer) {
        count += 1;
      }
    }
    return count;
  }

  QuizResult calculateResult() {
    final quiz = _quiz;
    if (quiz == null) {
      return const QuizResult(
        totalQuestions: 0,
        correctAnswers: 0,
        incorrectAnswers: 0,
        percentage: 0,
      );
    }

    return QuizResult.fromAnswers(
      totalQuestions: quiz.questions.length,
      correctAnswers: correctAnswers,
    );
  }

  Future<void> generateQuiz({
    required String topic,
    required String difficulty,
    required int questionCount,
  }) async {
    _isGenerating = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final generatedQuiz = await _generationService.generateQuiz(
        topic: topic,
        difficulty: difficulty,
        questionCount: questionCount,
      );

      _quiz = generatedQuiz;
      _currentQuestionIndex = 0;
      _selectedAnswers.clear();
      _submittedAnswers.clear();
      _isGenerating = false;
      notifyListeners();
    } on FormatException catch (error) {
      _errorMessage = 'The quiz could not be generated. Please try again.';
      _isGenerating = false;
      notifyListeners();
      debugPrint('Quiz generation format error: $error');
    } catch (error) {
      _errorMessage = 'Something went wrong while generating the quiz.';
      _isGenerating = false;
      notifyListeners();
      debugPrint('Quiz generation error: $error');
    }
  }

  void selectAnswer(String answer) {
    final question = currentQuestion;
    if (question == null || question.options.contains(answer) == false) {
      return;
    }

    _selectedAnswers[question.id] = answer;
    notifyListeners();
  }

  void submitAnswer() {
    final question = currentQuestion;
    if (question == null) {
      return;
    }

    final selectedAnswer = _selectedAnswers[question.id];
    if (selectedAnswer == null || selectedAnswer.isEmpty) {
      return;
    }

    _isSubmitting = true;
    notifyListeners();

    _submittedAnswers[question.id] = selectedAnswer;
    _isSubmitting = false;
    notifyListeners();
  }

  void nextQuestion() {
    final quiz = _quiz;
    if (quiz == null) {
      return;
    }

    if (_currentQuestionIndex < quiz.questions.length - 1) {
      _currentQuestionIndex += 1;
      notifyListeners();
      return;
    }

    _currentQuestionIndex = quiz.questions.length - 1;
    notifyListeners();
  }

  void retryQuiz() {
    _currentQuestionIndex = 0;
    _selectedAnswers.clear();
    _submittedAnswers.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void resetQuiz() {
    _quiz = null;
    _currentQuestionIndex = 0;
    _selectedAnswers.clear();
    _submittedAnswers.clear();
    _errorMessage = null;
    notifyListeners();
  }

  void handleAction(String action, {String? answer}) {
    switch (action) {
      case 'select_answer':
        if (answer != null) {
          selectAnswer(answer);
        }
        break;
      case 'submit_answer':
        submitAnswer();
        break;
      case 'next_question':
        nextQuestion();
        break;
      case 'review_answers':
        break;
      case 'retry_quiz':
        retryQuiz();
        break;
      case 'new_quiz':
        resetQuiz();
        break;
    }
  }
}
