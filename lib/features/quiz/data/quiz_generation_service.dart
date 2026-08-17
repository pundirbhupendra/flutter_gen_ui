import 'package:gen_ui/features/chat/data/ai_model_service.dart';
import 'package:gen_ui/features/quiz/domain/models/quiz_models.dart';

class QuizGenerationService {
  const QuizGenerationService({required CloudAiService cloudAiService})
    : _cloudAiService = cloudAiService;

  final CloudAiService _cloudAiService;

  Future<Quiz> generateQuiz({
    required String topic,
    required String difficulty,
    required int questionCount,
  }) async {
    final payload = await _cloudAiService.generateStructuredQuiz(
      topic: topic,
      difficulty: difficulty,
      questionCount: questionCount,
    );

    return Quiz.fromJson(payload);
  }
}
