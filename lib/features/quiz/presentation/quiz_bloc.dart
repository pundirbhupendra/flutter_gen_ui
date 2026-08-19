import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gen_ui/features/quiz/data/quiz_generation_service.dart';
import 'package:gen_ui/features/quiz/domain/models/quiz_models.dart';

sealed class QuizEvent {
  const QuizEvent();
}

final class GenerateQuiz extends QuizEvent {
  const GenerateQuiz({
    required this.topic,
    required this.difficulty,
    required this.questionCount,
  });
  final String topic;
  final String difficulty;
  final int questionCount;
}

final class SelectAnswer extends QuizEvent {
  const SelectAnswer(this.answer);
  final String answer;
}

final class SubmitAnswer extends QuizEvent {
  const SubmitAnswer();
}

final class NextQuestion extends QuizEvent {
  const NextQuestion();
}

final class RetryQuiz extends QuizEvent {
  const RetryQuiz();
}

final class ResetQuiz extends QuizEvent {
  const ResetQuiz();
}

class QuizState {
  const QuizState({
    this.quiz,
    this.isGenerating = false,
    this.isSubmitting = false,
    this.errorMessage,
    this.currentQuestionIndex = 0,
    this.selectedAnswers = const <String, String>{},
    this.submittedAnswers = const <String, String>{},
  });

  final Quiz? quiz;
  final bool isGenerating;
  final bool isSubmitting;
  final String? errorMessage;
  final int currentQuestionIndex;
  final Map<String, String> selectedAnswers;
  final Map<String, String> submittedAnswers;

  bool get hasQuiz => quiz != null;

  QuizQuestion? get currentQuestion {
    final questions = quiz?.questions;
    if (questions == null || currentQuestionIndex >= questions.length) {
      return null;
    }
    return questions[currentQuestionIndex];
  }

  String? get selectedAnswerForCurrentQuestion {
    final question = currentQuestion;
    return question == null ? null : selectedAnswers[question.id];
  }

  bool get isCurrentQuestionSubmitted {
    final question = currentQuestion;
    return question != null && submittedAnswers.containsKey(question.id);
  }

  bool get isResultVisible {
    final questions = quiz?.questions;
    return questions != null &&
        questions.isNotEmpty &&
        submittedAnswers.containsKey(questions.last.id);
  }

  QuizResult get result {
    final currentQuiz = quiz;
    if (currentQuiz == null) {
      return const QuizResult(
        totalQuestions: 0,
        correctAnswers: 0,
        incorrectAnswers: 0,
        percentage: 0,
      );
    }
    final correctAnswers = currentQuiz.questions
        .where(
          (question) => submittedAnswers[question.id] == question.correctAnswer,
        )
        .length;
    return QuizResult.fromAnswers(
      totalQuestions: currentQuiz.questions.length,
      correctAnswers: correctAnswers,
    );
  }

  QuizState copyWith({
    Quiz? quiz,
    bool? isGenerating,
    bool? isSubmitting,
    String? errorMessage,
    int? currentQuestionIndex,
    Map<String, String>? selectedAnswers,
    Map<String, String>? submittedAnswers,
  }) {
    return QuizState(
      quiz: quiz ?? this.quiz,
      isGenerating: isGenerating ?? this.isGenerating,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: errorMessage,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      selectedAnswers: selectedAnswers ?? this.selectedAnswers,
      submittedAnswers: submittedAnswers ?? this.submittedAnswers,
    );
  }
}

class QuizBloc extends Bloc<QuizEvent, QuizState> {
  QuizBloc({required QuizGenerationService generationService})
    : _generationService = generationService,
      super(const QuizState()) {
    on<GenerateQuiz>(_generateQuiz);
    on<SelectAnswer>(_selectAnswer);
    on<SubmitAnswer>(_submitAnswer);
    on<NextQuestion>(_nextQuestion);
    on<RetryQuiz>(_retryQuiz);
    on<ResetQuiz>(_resetQuiz);
  }

  final QuizGenerationService _generationService;

  Future<void> _generateQuiz(
    GenerateQuiz event,
    Emitter<QuizState> emit,
  ) async {
    emit(state.copyWith(isGenerating: true, errorMessage: null));
    try {
      final quiz = await _generationService.generateQuiz(
        topic: event.topic,
        difficulty: event.difficulty,
        questionCount: event.questionCount,
      );
      emit(QuizState(quiz: quiz));
    } on FormatException catch (error) {
      debugPrint('Quiz generation format error: $error');
      emit(
        state.copyWith(
          isGenerating: false,
          errorMessage: 'The quiz could not be generated. Please try again.',
        ),
      );
    } catch (error) {
      debugPrint('Quiz generation error: $error');
      emit(
        state.copyWith(
          isGenerating: false,
          errorMessage: 'Something went wrong while generating the quiz.',
        ),
      );
    }
  }

  void _selectAnswer(SelectAnswer event, Emitter<QuizState> emit) {
    final question = state.currentQuestion;
    if (question == null || !question.options.contains(event.answer)) return;
    emit(
      state.copyWith(
        selectedAnswers: {...state.selectedAnswers, question.id: event.answer},
      ),
    );
  }

  void _submitAnswer(SubmitAnswer event, Emitter<QuizState> emit) {
    final question = state.currentQuestion;
    final answer = state.selectedAnswerForCurrentQuestion;
    if (question == null || answer == null || answer.isEmpty) return;
    emit(
      state.copyWith(
        submittedAnswers: {...state.submittedAnswers, question.id: answer},
      ),
    );
  }

  void _nextQuestion(NextQuestion event, Emitter<QuizState> emit) {
    final quiz = state.quiz;
    if (quiz == null) return;
    emit(
      state.copyWith(
        currentQuestionIndex: (state.currentQuestionIndex + 1).clamp(
          0,
          quiz.questions.length - 1,
        ),
      ),
    );
  }

  void _retryQuiz(RetryQuiz event, Emitter<QuizState> emit) =>
      emit(QuizState(quiz: state.quiz));

  void _resetQuiz(ResetQuiz event, Emitter<QuizState> emit) =>
      emit(const QuizState());
}
