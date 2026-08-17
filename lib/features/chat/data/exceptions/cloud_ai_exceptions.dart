class CloudAiException implements Exception {
  const CloudAiException({
    required this.message,
    required this.userMessage,
    this.statusCode,
    this.canRetry = true,
  });

  final String message;
  final String userMessage;
  final int? statusCode;
  final bool canRetry;

  @override
  String toString() => message;
}
