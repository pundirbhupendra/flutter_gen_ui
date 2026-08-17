class Quiz {
  const Quiz({
    required this.title,
    required this.topic,
    required this.difficulty,
    required this.questions,
  });

  final String title;
  final String topic;
  final String difficulty;
  final List<QuizQuestion> questions;

  factory Quiz.fromJson(Map<String, dynamic> json) {
    final title = json['title'];
    final topic = json['topic'];
    final difficulty = json['difficulty'];
    final rawQuestions = json['questions'];

    if (title is! String || title.trim().isEmpty) {
      throw const FormatException('Quiz title is required.');
    }

    if (topic is! String || topic.trim().isEmpty) {
      throw const FormatException('Quiz topic is required.');
    }

    if (difficulty is! String || difficulty.trim().isEmpty) {
      throw const FormatException('Quiz difficulty is required.');
    }

    if (rawQuestions is! List || rawQuestions.isEmpty) {
      throw const FormatException('Quiz must contain at least one question.');
    }

    final questions = <QuizQuestion>[];
    for (final question in rawQuestions) {
      if (question is! Map) {
        throw const FormatException('Each quiz question must be an object.');
      }
      questions.add(QuizQuestion.fromJson(Map<String, dynamic>.from(question)));
    }

    return Quiz(
      title: title.trim(),
      topic: topic.trim(),
      difficulty: difficulty.trim(),
      questions: questions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'topic': topic,
      'difficulty': difficulty,
      'questions': questions.map((question) => question.toJson()).toList(),
    };
  }

  QuizResult get result {
    return QuizResult(
      totalQuestions: questions.length,
      correctAnswers: 0,
      incorrectAnswers: 0,
      percentage: 0,
    );
  }
}

class QuizQuestion {
  const QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswer,
    required this.explanation,
  });

  final String id;
  final String question;
  final List<String> options;
  final String correctAnswer;
  final String explanation;

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final question = json['question'];
    final options = json['options'];
    final correctAnswer = json['correctAnswer'];
    final explanation = json['explanation'];

    if (id is! String || id.trim().isEmpty) {
      throw const FormatException('Quiz question id is required.');
    }

    if (question is! String || question.trim().isEmpty) {
      throw const FormatException('Quiz question text is required.');
    }

    if (options is! List || options.isEmpty) {
      throw const FormatException('Quiz question options are required.');
    }

    final parsedOptions = <String>[];
    for (final option in options) {
      if (option is! String || option.trim().isEmpty) {
        throw const FormatException('Each quiz option must be a non-empty string.');
      }
      parsedOptions.add(option.trim());
    }

    if (correctAnswer is! String || correctAnswer.trim().isEmpty) {
      throw const FormatException('Quiz correctAnswer is required.');
    }

    final normalizedCorrectAnswer = correctAnswer.trim();
    if (!parsedOptions.contains(normalizedCorrectAnswer)) {
      throw const FormatException(
        'Quiz correctAnswer must match one of the provided options.',
      );
    }

    if (explanation is! String || explanation.trim().isEmpty) {
      throw const FormatException('Quiz explanation is required.');
    }

    return QuizQuestion(
      id: id.trim(),
      question: question.trim(),
      options: parsedOptions,
      correctAnswer: normalizedCorrectAnswer,
      explanation: explanation.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswer': correctAnswer,
      'explanation': explanation,
    };
  }
}

class QuizResult {
  const QuizResult({
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.percentage,
  });

  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final int percentage;

  factory QuizResult.fromAnswers({
    required int totalQuestions,
    required int correctAnswers,
  }) {
    final total = totalQuestions > 0 ? totalQuestions : 0;
    final correct = correctAnswers.clamp(0, total);
    final incorrect = total - correct;
    final percentage = total == 0 ? 0 : ((correct / total) * 100).round();

    return QuizResult(
      totalQuestions: total,
      correctAnswers: correct,
      incorrectAnswers: incorrect,
      percentage: percentage,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'incorrectAnswers': incorrectAnswers,
      'percentage': percentage,
    };
  }
}
