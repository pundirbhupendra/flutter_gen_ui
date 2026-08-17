class QuizPrompts {
  const QuizPrompts._();

  static String buildPrompt({
    required String topic,
    required String difficulty,
    required int questionCount,
  }) {
    final safeTopic = topic.trim();
    final safeDifficulty = difficulty.trim();
    final safeQuestionCount = questionCount > 0 ? questionCount : 1;

    return '''
You are generating a quiz for a Flutter app.

Generate a valid JSON object only.
No Markdown, no code fences, no explanatory text, no commentary.

Requirements:
- topic: "$safeTopic"
- difficulty: "$safeDifficulty"
- number of questions: $safeQuestionCount
- The output must match this structure exactly:
{
  "title": "<quiz title>",
  "topic": "<same as topic>",
  "difficulty": "<same as difficulty>",
  "questions": [
    {
      "id": "q1",
      "question": "<question text>",
      "options": ["<option 1>", "<option 2>", "<option 3>", "<option 4>"],
      "correctAnswer": "<exactly one option>",
      "explanation": "<brief explanation of why the answer is correct>"
    }
  ]
}

Rules:
- Use a quiz title that matches the topic and difficulty.
- Use exactly $safeQuestionCount questions.
- Each question must have exactly 4 options.
- The correctAnswer must match one of the provided options exactly.
- Keep the explanation concise and factual.
- Use only valid JSON with double quotes around keys and string values.
- Do not include trailing commas.
- Ensure the entire response is JSON parseable.
''';
  }
}
