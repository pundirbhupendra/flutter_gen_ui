import 'package:flutter_test/flutter_test.dart';
import 'package:gen_ui/features/quiz/domain/models/quiz_models.dart';

void main() {
  group('Quiz model parsing', () {
    test('parses a valid quiz payload into typed data', () {
      const json = {
        'title': 'Flutter Intermediate Quiz',
        'topic': 'Flutter',
        'difficulty': 'Intermediate',
        'questions': [
          {
            'id': 'q1',
            'question': 'What is the purpose of RepaintBoundary?',
            'options': [
              'Manage state',
              'Limit repaint propagation',
              'Create an isolate',
              'Persist data',
            ],
            'correctAnswer': 'Limit repaint propagation',
            'explanation': 'RepaintBoundary isolates repainting for a subtree.',
          },
        ],
      };

      final quiz = Quiz.fromJson(json);

      expect(quiz.title, 'Flutter Intermediate Quiz');
      expect(quiz.questions.length, 1);
      expect(quiz.questions.first.options.length, 4);
      expect(quiz.result.correctAnswers, 0);
    });

    test('rejects malformed quiz payloads', () {
      const json = {
        'title': 'Broken Quiz',
        'topic': 'Flutter',
        'difficulty': 'Easy',
        'questions': [
          {
            'id': 'q1',
            'question': 'Example?',
            'options': ['A', 'B'],
          },
        ],
      };

      expect(() => Quiz.fromJson(json), throwsA(isA<FormatException>()));
    });
  });
}
