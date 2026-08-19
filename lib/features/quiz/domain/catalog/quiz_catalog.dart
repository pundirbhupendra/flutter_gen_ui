import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:gen_ui/features/quiz/domain/models/quiz_models.dart';
import 'package:gen_ui/features/quiz/presentation/quiz_bloc.dart';

final quizCatalogItem = CatalogItem(
  name: 'QuizQuestion',
  dataSchema: S.object(
    description:
        'A single dynamic quiz question surfaced through the GenUI catalog.',
    properties: {
      'title': S.string(description: 'Quiz title to display.'),
      'question': S.string(description: 'The current quiz question.'),
      'options': S.list(
        items: S.string(),
        description: 'Possible answer choices for the question.',
      ),
      'selectedAnswer': S.string(description: 'The user-selected answer.'),
      'correctAnswer': S.string(
        description: 'The correct answer for the question.',
      ),
      'explanation': S.string(
        description: 'Explanation shown after submission.',
      ),
      'submitted': S.boolean(
        description: 'Whether the answer has been submitted.',
      ),
      'bloc': S.object(description: 'Optional quiz BLoC reference.'),
    },
  ),
  widgetBuilder: (itemContext) {
    final rawData = itemContext.data;
    final data = rawData is Map
        ? Map<String, Object?>.from(rawData)
        : <String, Object?>{};

    final bloc = data['bloc'] is QuizBloc ? data['bloc'] as QuizBloc : null;

    final mappedQuestion = _questionFromMap(data, bloc);
    if (mappedQuestion == null) {
      return const SizedBox.shrink();
    }

    final selectedAnswer = bloc != null
        ? bloc.state.selectedAnswerForCurrentQuestion
        : (data['selectedAnswer'] as String?);
    final submitted = bloc != null
        ? bloc.state.isCurrentQuestionSubmitted
        : data['submitted'] == true;
    final currentQuestion = mappedQuestion;

    return _QuizQuestionCard(
      title: (data['title'] as String?) ?? 'Quiz',
      question: currentQuestion,
      selectedAnswer: selectedAnswer,
      submitted: submitted,
      onSelect: (answer) {
        bloc?.add(SelectAnswer(answer));
      },
      onSubmit: () {
        bloc?.add(const SubmitAnswer());
      },
      onNext: () {
        bloc?.add(const NextQuestion());
      },
    );
  },
);

QuizQuestion? _questionFromMap(Map<String, Object?> data, QuizBloc? bloc) {
  final questionText = data['question'];
  final options = data['options'];
  final correctAnswer = data['correctAnswer'];

  final currentQuestion = bloc?.state.currentQuestion;
  if (currentQuestion != null) {
    return currentQuestion;
  }

  if (questionText is! String || options is! List || correctAnswer is! String) {
    return null;
  }

  final parsedOptions = <String>[];
  for (final option in options) {
    if (option is String) {
      parsedOptions.add(option);
    }
  }

  if (parsedOptions.isEmpty) {
    return null;
  }

  return QuizQuestion(
    id: 'generated-question',
    question: questionText,
    options: parsedOptions,
    correctAnswer: correctAnswer,
    explanation: (data['explanation'] as String?) ?? 'Answer the question.',
  );
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.title,
    required this.question,
    required this.selectedAnswer,
    required this.submitted,
    required this.onSelect,
    required this.onSubmit,
    required this.onNext,
  });

  final String title;
  final QuizQuestion question;
  final String? selectedAnswer;
  final bool submitted;
  final ValueChanged<String> onSelect;
  final VoidCallback onSubmit;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isCorrect = selectedAnswer == question.correctAnswer;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(question.question, style: theme.textTheme.bodyLarge),
            const SizedBox(height: 16),
            ...question.options.map((option) {
              final isSelected = selectedAnswer == option;
              final isCorrectChoice =
                  submitted && option == question.correctAnswer;
              final isIncorrectChoice =
                  submitted && isSelected && option != question.correctAnswer;

              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: isCorrectChoice
                      ? colorScheme.primaryContainer
                      : isIncorrectChoice
                      ? colorScheme.errorContainer
                      : isSelected
                      ? colorScheme.secondaryContainer
                      : colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: submitted ? null : () => onSelect(option),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              option,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          if (submitted && isCorrectChoice)
                            Icon(
                              Icons.check_circle,
                              color: colorScheme.primary,
                            ),
                          if (submitted && isIncorrectChoice)
                            Icon(Icons.close_rounded, color: colorScheme.error),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            if (submitted) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isCorrect
                      ? colorScheme.primaryContainer
                      : colorScheme.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isCorrect
                      ? 'Correct! ${question.explanation}'
                      : 'Incorrect. ${question.explanation}',
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: onNext,
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Next question'),
                ),
              ),
            ] else ...[
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: selectedAnswer == null ? null : onSubmit,
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Submit answer'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
