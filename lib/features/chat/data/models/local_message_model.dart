enum LocalMessageStatus { completed, loading, failed }

class LocalMessageModel {
  LocalMessageModel({
    required this.sender,
    required this.isUser,
    this.text = '',
    Set<String>? surfaceIds,
    this.status = LocalMessageStatus.completed,
    this.errorMessage,
    this.canRetry = true,
  }) : surfaceIds = surfaceIds ?? <String>{};

  final String sender;
  final bool isUser;

  String text;
  final Set<String> surfaceIds;

  LocalMessageStatus status;
  String? errorMessage;
  bool canRetry;

  bool get isLoading => status == LocalMessageStatus.loading;

  bool get hasFailed => status == LocalMessageStatus.failed;

  bool get hasSurfaces => surfaceIds.isNotEmpty;

  void addSurfaceId(String surfaceId) {
    final id = surfaceId.trim();

    if (id.isEmpty) {
      return;
    }

    surfaceIds.add(id);
  }
}
