import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:genui/genui.dart';
import 'package:http/http.dart' as http;
import 'package:gen_ui/core/constants/api_constants.dart';
import 'package:gen_ui/features/chat/data/exceptions/cloud_ai_exceptions.dart';
import 'package:gen_ui/features/chat/data/open_router_model_store.dart';
import 'package:gen_ui/features/chat/presentation/widgets/custom_transport_adapter.dart';
import 'package:gen_ui/features/quiz/domain/prompts/quiz_prompts.dart';

class CloudAiService {
  CloudAiService({
    required OpenRouterModelStore modelStore,
    http.Client? client,
  }) : _modelStore = modelStore,
       _client = client ?? http.Client();

  final http.Client _client;

  final List<Map<String, String>> _history = [];

  final OpenRouterModelStore _modelStore;

  static const int _maxHistoryMessages = 50;

  Future<Map<String, dynamic>> generateStructuredQuiz({
    required String topic,
    required String difficulty,
    required int questionCount,
  }) async {
    final modelName = await _modelStore.getModel();
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final prompt = QuizPrompts.buildPrompt(
      topic: topic,
      difficulty: difficulty,
      questionCount: questionCount,
    );

    final requestBody = <String, Object?>{
      'model': modelName,
      'messages': <Map<String, String>>[
        {'role': 'system', 'content': prompt},
        {
          'role': 'user',
          'content':
              'Generate the quiz JSON for topic "$topic" with difficulty "$difficulty" and $questionCount questions.',
        },
      ],
      'stream': false,
      'temperature': 0.0,
    };

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer ${ApiConstants.openRouterKey}'
      ..body = jsonEncode(requestBody);

    try {
      final response = await _client.send(request).timeout(
        const Duration(seconds: 30),
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final responseBody = await response.stream.bytesToString();
        throw _createHttpException(
          statusCode: response.statusCode,
          responseBody: responseBody,
        );
      }

      final responseBody = await response.stream.bytesToString();
      final jsonResponse = _decodeStructuredQuizResponse(responseBody);
      return jsonResponse;
    } on CloudAiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw CloudAiException(
        message: 'The quiz generation request timed out: $error',
        userMessage: 'The quiz request took too long. Please try again.',
      );
    } on SocketException catch (error) {
      throw CloudAiException(
        message: 'Network connection failed: $error',
        userMessage:
            'Could not connect to the AI service. Check your internet connection and try again.',
      );
    } on http.ClientException catch (error) {
      throw CloudAiException(
        message: 'HTTP client failed: $error',
        userMessage: 'A network error occurred. Please try again.',
      );
    } on FormatException catch (error) {
      throw CloudAiException(
        message: 'Could not parse the quiz response: $error',
        userMessage: 'The AI returned an invalid quiz format. Please try again.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Unexpected quiz generation error:\n'
        '$error\n'
        '$stackTrace',
      );
      throw CloudAiException(
        message: 'Unexpected quiz generation error: $error',
        userMessage: 'Something went wrong while generating the quiz.',
      );
    }
  }

  Future<void> sendToCloud(
    ChatMessage message,
    CustomTransportAdapter transport,
    Catalog catalog,
  ) async {
    final modelName = await _modelStore.getModel();
    final url = Uri.parse('https://openrouter.ai/api/v1/chat/completions');

    final promptBuilder = PromptBuilder.chat(
      catalog: catalog,
      systemPromptFragments: [
        PromptFragments.uiGenerationRestriction(),
      ],
    );

    final currentMessage = _toOpenRouterMessage(message);

    final requestBody = <String, Object?>{
      'model': modelName,
      'messages': <Map<String, String>>[
        {'role': 'system', 'content': promptBuilder.systemPromptJoined()},
        ..._history,
        currentMessage,
      ],
      'stream': true,
      'temperature': 0.0,
    };

    final request = http.Request('POST', url)
      ..headers['Content-Type'] = 'application/json'
      ..headers['Authorization'] = 'Bearer ${ApiConstants.openRouterKey}'
      ..body = jsonEncode(requestBody);

    final fullResponseBuffer = StringBuffer();

    try {
      final response = await _client
          .send(request)
          .timeout(const Duration(seconds: 30));

      debugPrint(
        'OpenRouter response: '
        '${response.statusCode} ${response.reasonPhrase}',
      );

      if (response.statusCode < 200 || response.statusCode >= 300) {
        final responseBody = await response.stream.bytesToString();

        throw _createHttpException(
          statusCode: response.statusCode,
          responseBody: responseBody,
        );
      }

      await for (final line
          in response.stream
              .transform(utf8.decoder)
              .transform(const LineSplitter())
              .timeout(const Duration(minutes: 2))) {
        if (line.isEmpty || line.startsWith(':')) {
          continue;
        }

        if (!line.startsWith('data:')) {
          continue;
        }

        final rawData = line.substring(5).trimLeft();

        if (rawData == '[DONE]') {
          break;
        }

        final decoded = _decodeStreamEvent(rawData);

        final streamError = decoded['error'];

        if (streamError != null) {
          throw _createStreamException(streamError);
        }

        final choices = decoded['choices'];

        if (choices is! List || choices.isEmpty) {
          continue;
        }

        final firstChoice = choices.first;

        if (firstChoice is! Map) {
          continue;
        }

        final choice = Map<String, dynamic>.from(firstChoice);

        if (choice['finish_reason'] == 'error') {
          throw const CloudAiException(
            message: 'The provider ended the stream with an error.',
            userMessage: 'The response was interrupted. Please try again.',
          );
        }

        final delta = choice['delta'];

        if (delta is! Map) {
          continue;
        }

        final content = delta['content'];

        if (content is String && content.isNotEmpty) {
          fullResponseBuffer.write(content);
          transport.addChunk(content);
        }
      }

      final completeResponse = fullResponseBuffer.toString();

      if (completeResponse.trim().isEmpty) {
        throw const CloudAiException(
          message: 'The model returned an empty response.',
          userMessage: 'The AI did not return a response. Please try again.',
        );
      }

      // Only save history after the response completes successfully.
      _history
        ..add(currentMessage)
        ..add({'role': 'assistant', 'content': completeResponse});

      _trimHistory();
    } on CloudAiException {
      rethrow;
    } on TimeoutException catch (error) {
      throw CloudAiException(
        message: 'The AI request timed out: $error',
        userMessage: 'The request took too long. Please try again.',
      );
    } on SocketException catch (error) {
      throw CloudAiException(
        message: 'Network connection failed: $error',
        userMessage:
            'Could not connect to the AI service. Check your internet connection and try again.',
      );
    } on http.ClientException catch (error) {
      throw CloudAiException(
        message: 'HTTP client failed: $error',
        userMessage: 'A network error occurred. Please try again.',
      );
    } on FormatException catch (error) {
      throw CloudAiException(
        message: 'Could not parse the API response: $error',
        userMessage: 'The AI returned an invalid response. Please try again.',
      );
    } catch (error, stackTrace) {
      debugPrint(
        'Unexpected CloudAiService error:\n'
        '$error\n'
        '$stackTrace',
      );

      throw CloudAiException(
        message: 'Unexpected AI error: $error',
        userMessage: 'Something went wrong. Please try again.',
      );
    }
  }

  Map<String, dynamic> _decodeStructuredQuizResponse(String responseBody) {
    final decoded = jsonDecode(responseBody);

    if (decoded is! Map) {
      throw const FormatException('The quiz response was not a JSON object.');
    }

    final root = Map<String, dynamic>.from(decoded);
    final choices = root['choices'];

    if (choices is List && choices.isNotEmpty) {
      final firstChoice = choices.first;
      if (firstChoice is Map) {
        final firstChoiceMap = Map<String, dynamic>.from(firstChoice);
        final message = firstChoiceMap['message'];
        if (message is Map) {
          final content = message['content'];
          if (content is String) {
            final nested = jsonDecode(content);
            if (nested is Map) {
              return Map<String, dynamic>.from(nested);
            }
          }
        }
      }
    }

    final content = root['content'];
    if (content is String) {
      final nested = jsonDecode(content);
      if (nested is Map) {
        return Map<String, dynamic>.from(nested);
      }
    }

    throw const FormatException('The quiz response did not include a parsable JSON payload.');
  }

  Map<String, dynamic> _decodeStreamEvent(String rawData) {
    final decoded = jsonDecode(rawData);

    if (decoded is! Map) {
      throw const FormatException('The streamed event was not a JSON object.');
    }

    return Map<String, dynamic>.from(decoded);
  }

  CloudAiException _createHttpException({
    required int statusCode,
    required String responseBody,
  }) {
    final serverMessage = _extractServerErrorMessage(responseBody);

    return switch (statusCode) {
      401 || 403 => CloudAiException(
        message: serverMessage,
        userMessage: 'The AI service could not authenticate the request.',
        statusCode: statusCode,
        canRetry: false,
      ),
      402 => CloudAiException(
        message: serverMessage,
        userMessage: 'The AI service has insufficient credits.',
        statusCode: statusCode,
        canRetry: false,
      ),
      429 => CloudAiException(
        message: serverMessage,
        userMessage:
            'The AI service is receiving too many requests. Wait a moment and try again.',
        statusCode: statusCode,
      ),
      >= 500 => CloudAiException(
        message: serverMessage,
        userMessage:
            'The AI service is temporarily unavailable. Please try again.',
        statusCode: statusCode,
      ),
      _ => CloudAiException(
        message: serverMessage,
        userMessage: 'The request failed. Please try again.',
        statusCode: statusCode,
      ),
    };
  }

  CloudAiException _createStreamException(Object streamError) {
    String message = 'The stream failed.';

    if (streamError is Map) {
      final errorMap = Map<String, dynamic>.from(streamError);

      final errorMessage = errorMap['message'];

      if (errorMessage is String && errorMessage.isNotEmpty) {
        message = errorMessage;
      }
    }

    return CloudAiException(
      message: message,
      userMessage: 'The response was interrupted. Please try again.',
    );
  }

  String _extractServerErrorMessage(String responseBody) {
    if (responseBody.trim().isEmpty) {
      return 'The AI request failed.';
    }

    try {
      final decoded = jsonDecode(responseBody);

      if (decoded is Map) {
        final error = decoded['error'];

        if (error is Map && error['message'] is String) {
          return error['message'] as String;
        }
      }
    } on FormatException {
      // Use the raw response below.
    }

    return responseBody;
  }

  Map<String, String> _toOpenRouterMessage(ChatMessage message) {
    return {'role': _roleFor(message.role), 'content': _contentFor(message)};
  }

  String _roleFor(ChatMessageRole role) {
    return switch (role) {
      ChatMessageRole.system => 'system',
      ChatMessageRole.user => 'user',
      ChatMessageRole.model => 'assistant',
    };
  }

  String _contentFor(ChatMessage message) {
    final text = message.text;

    final isPlainTextMessage =
        text.isNotEmpty &&
        message.parts.length == 1 &&
        message.metadata.isEmpty &&
        !message.hasToolCalls &&
        !message.hasToolResults;

    if (isPlainTextMessage) {
      return text;
    }

    return jsonEncode(message.toJson());
  }

  void _trimHistory() {
    while (_history.length > _maxHistoryMessages) {
      _history.removeAt(0);

      if (_history.isNotEmpty) {
        _history.removeAt(0);
      }
    }
  }

  void clearHistory() {
    _history.clear();
  }

  void dispose() {
    _client.close();
  }
}
