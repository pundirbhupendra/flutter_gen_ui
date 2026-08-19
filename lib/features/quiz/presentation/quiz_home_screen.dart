import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gen_ui/features/chat/data/ai_model_service.dart';
import 'package:gen_ui/features/chat/data/open_router_model_store.dart';
import 'package:gen_ui/features/quiz/data/quiz_generation_service.dart';
import 'package:gen_ui/features/quiz/domain/models/quiz_models.dart';
import 'package:gen_ui/features/quiz/presentation/quiz_bloc.dart';

class QuizHomeScreen extends StatefulWidget {
  const QuizHomeScreen({super.key});

  @override
  State<QuizHomeScreen> createState() => _QuizHomeScreenState();
}

class _QuizHomeScreenState extends State<QuizHomeScreen> {
  final OpenRouterModelStore _modelStore = OpenRouterModelStore();
  late final CloudAiService _cloudAiService;
  late final QuizBloc _bloc;

  final TextEditingController _topicController = TextEditingController(
    text: 'Flutter',
  );

  String _difficulty = 'Intermediate';
  int _questionCount = 5;

  @override
  void initState() {
    super.initState();
    _cloudAiService = CloudAiService(modelStore: _modelStore);
    _bloc = QuizBloc(
      generationService: QuizGenerationService(cloudAiService: _cloudAiService),
    );
  }

  @override
  void dispose() {
    _bloc.close();
    _cloudAiService.dispose();
    _topicController.dispose();
    super.dispose();
  }

  Future<void> _startQuiz() async {
    final topic = _topicController.text.trim();
    if (topic.isEmpty) {
      return;
    }

    _bloc.add(
      GenerateQuiz(
        topic: topic,
        difficulty: _difficulty,
        questionCount: _questionCount,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        appBar: AppBar(title: const Text('AI Quiz')),
        body: BlocBuilder<QuizBloc, QuizState>(
          builder: (context, state) {
            if (state.isGenerating) {
              return const _QuizLoadingState();
            }

            if (state.errorMessage != null && !state.hasQuiz) {
              return _QuizErrorState(
                message: state.errorMessage!,
                onRetry: _startQuiz,
              );
            }

            if (state.hasQuiz) {
              final resultVisible = state.isResultVisible;
              if (resultVisible) {
                return _QuizResultState(
                  result: state.result,
                  onRetry: () => _bloc.add(const RetryQuiz()),
                  onNewQuiz: () => _bloc.add(const ResetQuiz()),
                );
              }

              final question = state.currentQuestion;
              if (question == null) {
                return _QuizResultState(
                  result: state.result,
                  onRetry: () => _bloc.add(const RetryQuiz()),
                  onNewQuiz: () => _bloc.add(const ResetQuiz()),
                );
              }

              return _QuestionState(
                quiz: state.quiz!,
                question: question,
                questionIndex: state.currentQuestionIndex,
                selectedAnswer: state.selectedAnswerForCurrentQuestion,
                isSubmitted: state.isCurrentQuestionSubmitted,
                onSelect: (answer) => _bloc.add(SelectAnswer(answer)),
                onSubmit: () => _bloc.add(const SubmitAnswer()),
                onNext: () => _bloc.add(const NextQuestion()),
              );
            }

            return _SetupState(
              topicController: _topicController,
              difficulty: _difficulty,
              questionCount: _questionCount,
              onDifficultyChanged: (value) {
                setState(() {
                  _difficulty = value;
                });
              },
              onQuestionCountChanged: (value) {
                setState(() {
                  _questionCount = value;
                });
              },
              onStart: _startQuiz,
            );
          },
        ),
      ),
    );
  }
}

class _QuizLoadingState extends StatelessWidget {
  const _QuizLoadingState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text('Generating your quiz...', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}

class _QuizErrorState extends StatelessWidget {
  const _QuizErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

class _SetupState extends StatelessWidget {
  const _SetupState({
    required this.topicController,
    required this.difficulty,
    required this.questionCount,
    required this.onDifficultyChanged,
    required this.onQuestionCountChanged,
    required this.onStart,
  });

  final TextEditingController topicController;
  final String difficulty;
  final int questionCount;
  final ValueChanged<String> onDifficultyChanged;
  final ValueChanged<int> onQuestionCountChanged;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Quiz Setup',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Generate a structured quiz using the existing OpenRouter integration.',
                style: theme.textTheme.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: topicController,
                decoration: const InputDecoration(
                  labelText: 'Topic',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<String>(
                initialValue: difficulty,
                decoration: const InputDecoration(
                  labelText: 'Difficulty',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'Beginner', child: Text('Beginner')),
                  DropdownMenuItem(
                    value: 'Intermediate',
                    child: Text('Intermediate'),
                  ),
                  DropdownMenuItem(value: 'Advanced', child: Text('Advanced')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onDifficultyChanged(value);
                  }
                },
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<int>(
                initialValue: questionCount,
                decoration: const InputDecoration(
                  labelText: 'Number of questions',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 3, child: Text('3')),
                  DropdownMenuItem(value: 5, child: Text('5')),
                  DropdownMenuItem(value: 8, child: Text('8')),
                  DropdownMenuItem(value: 10, child: Text('10')),
                ],
                onChanged: (value) {
                  if (value != null) {
                    onQuestionCountChanged(value);
                  }
                },
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onStart,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Start Quiz'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuestionState extends StatelessWidget {
  const _QuestionState({
    required this.quiz,
    required this.question,
    required this.questionIndex,
    required this.selectedAnswer,
    required this.isSubmitted,
    required this.onSelect,
    required this.onSubmit,
    required this.onNext,
  });

  final Quiz quiz;
  final QuizQuestion question;
  final int questionIndex;
  final String? selectedAnswer;
  final bool isSubmitted;
  final ValueChanged<String> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${quiz.title} • ${quiz.difficulty}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Question ${questionIndex + 1} of ${quiz.questions.length}',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(question.question, style: theme.textTheme.headlineSmall),
                  const SizedBox(height: 20),
                  ...question.options.map((option) {
                    final isSelected = option == selectedAnswer;
                    final isCorrectAnswer = option == question.correctAnswer;
                    final showCorrect = isSubmitted && isCorrectAnswer;
                    final showWrong =
                        isSubmitted && isSelected && !isCorrectAnswer;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Material(
                        color: showCorrect
                            ? colorScheme.primaryContainer
                            : showWrong
                            ? colorScheme.errorContainer
                            : isSelected
                            ? colorScheme.secondaryContainer
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: isSubmitted ? null : () => onSelect(option),
                          borderRadius: BorderRadius.circular(14),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    option,
                                    style: theme.textTheme.bodyLarge,
                                  ),
                                ),
                                if (showCorrect)
                                  const Icon(Icons.check_circle_rounded),
                                if (showWrong) const Icon(Icons.close_rounded),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 24),
                  if (isSubmitted) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: selectedAnswer == question.correctAnswer
                            ? colorScheme.primaryContainer
                            : colorScheme.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        selectedAnswer == question.correctAnswer
                            ? 'Correct! ${question.explanation}'
                            : 'Incorrect. ${question.explanation}',
                        style: theme.textTheme.bodyMedium,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: onNext,
                        icon: const Icon(Icons.arrow_forward_rounded),
                        label: Text(
                          questionIndex == quiz.questions.length - 1
                              ? 'See Results'
                              : 'Next Question',
                        ),
                      ),
                    ),
                  ] else ...[
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.icon(
                        onPressed: selectedAnswer == null ? null : onSubmit,
                        icon: const Icon(Icons.check_rounded),
                        label: const Text('Submit Answer'),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _QuizResultState extends StatelessWidget {
  const _QuizResultState({
    required this.result,
    required this.onRetry,
    required this.onNewQuiz,
  });

  final QuizResult result;
  final VoidCallback onRetry;
  final VoidCallback onNewQuiz;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final performanceMessage = switch (result.percentage) {
      >= 90 => 'Excellent!',
      >= 70 => 'Great job!',
      >= 50 => 'Keep practicing!',
      _ => "Let's practice more!",
    };

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Card(
          margin: const EdgeInsets.all(24),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Quiz Complete',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  '${result.correctAnswers} / ${result.totalQuestions}',
                  style: theme.textTheme.displaySmall,
                ),
                Text(
                  '${result.percentage}%',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(performanceMessage, style: theme.textTheme.titleMedium),
                const SizedBox(height: 16),
                Text(
                  'Correct: ${result.correctAnswers}\nIncorrect: ${result.incorrectAnswers}',
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: onRetry,
                        icon: const Icon(Icons.refresh_rounded),
                        label: const Text('Try Again'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: onNewQuiz,
                        icon: const Icon(Icons.home_rounded),
                        label: const Text('New Quiz'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
