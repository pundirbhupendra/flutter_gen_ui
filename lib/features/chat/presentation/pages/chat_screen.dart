import 'dart:async';

import 'package:flutter/material.dart';
import 'package:genui/genui.dart';
import 'package:gen_ui/features/chat/data/ai_model_service.dart';
import 'package:gen_ui/features/chat/data/exceptions/cloud_ai_exceptions.dart';
import 'package:gen_ui/features/chat/data/models/local_message_model.dart';
import 'package:gen_ui/features/chat/data/open_router_model_store.dart';
import 'package:gen_ui/features/quiz/domain/catalog/quiz_catalog.dart';
import 'package:gen_ui/features/chat/presentation/widgets/custom_transport_adapter.dart';
import 'package:gen_ui/features/chat/presentation/widgets/message_bubble.dart';

class ChatScreen extends StatefulWidget {
  const ChatScreen({super.key});

  @override
  State<ChatScreen> createState() {
    return _ChatScreenState();
  }
}

class _ChatScreenState extends State<ChatScreen> with WidgetsBindingObserver {
  static const double _bottomTolerance = 2;
  static const int _maxScrollAttempts = 5;
  static const double _nearBottomThreshold = 200;

  late final SurfaceController _surfaceController;
  late final CustomTransportAdapter _transport;
  late final Conversation _conversation;
  late final CloudAiService _cloudAiService;
  late final Catalog _catalog;

  final TextEditingController _textController = TextEditingController();

  final ScrollController _scrollController = ScrollController();

  final OpenRouterModelStore _modelStore = OpenRouterModelStore();

  final List<LocalMessageModel> _chatItems = [];

  final Set<String> _displayedSurfaceIds = <String>{};

  late final StreamSubscription<ConversationEvent> _conversationSubscription;

  bool _scrollScheduled = false;
  bool _scrollInProgress = false;

  int _scrollRequestVersion = 0;
  bool _requestInProgress = false;

  bool _shouldAutoScroll = true;

  ChatMessage? _lastSentRequest;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _scrollController.addListener(_handleScrollPosition);

    _cloudAiService = CloudAiService(modelStore: _modelStore);

    _catalog = Catalog([
      quizCatalogItem,
    ], catalogId: 'ActiveWidgetsCatalog');

    _surfaceController = SurfaceController(catalogs: [_catalog]);

    _transport = CustomTransportAdapter(
      onSend: (ChatMessage message) {
        return _cloudAiService.sendToCloud(message, _transport, _catalog);
      },
    );

    _conversation = Conversation(
      controller: _surfaceController,
      transport: _transport,
    );

    _conversationSubscription = _conversation.events.listen((event) {
      if (!mounted) {
        return;
      }

      switch (event) {
        case ConversationContentReceived():
          _handleContentReceived(event);

        case ConversationSurfaceAdded():
          debugPrint(
            'Surface added: ${event.surfaceId}, '
            'components: '
            '${event.definition.components.length}, '
            'catalog: ${event.definition.catalogId}',
          );

          _addSurfaceWhenReady(
            surfaceId: event.surfaceId,
            definition: event.definition,
          );

        case ConversationComponentsUpdated():
          debugPrint(
            'Surface updated: ${event.surfaceId}, '
            'components: '
            '${event.definition.components.length}, '
            'catalog: ${event.definition.catalogId}',
          );

          _addSurfaceWhenReady(
            surfaceId: event.surfaceId,
            definition: event.definition,
          );

        case ConversationError():
          if (_lastSentRequest != null && !_requestInProgress) {
            _handleRequestFailure(event.error);
          }

        default:
          break;
      }
    });
  }

  @override
  void didChangeMetrics() {
    super.didChangeMetrics();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      final keyboardIsVisible = MediaQuery.viewInsetsOf(context).bottom > 0;

      if (keyboardIsVisible) {
        _scrollToBottom();
      }
    });
  }

  void _removeCurrentAssistantResponse() {
    final lastUserIndex = _chatItems.lastIndexWhere(
      (message) => message.isUser,
    );

    if (lastUserIndex == -1 || lastUserIndex == _chatItems.length - 1) {
      return;
    }

    final assistantItems = _chatItems.sublist(lastUserIndex + 1);

    for (final item in assistantItems) {
      if (item.surfaceIds.isNotEmpty) {
        _displayedSurfaceIds.removeAll(item.surfaceIds);
      }
    }

    _chatItems.removeRange(lastUserIndex + 1, _chatItems.length);
  }

  void _handleContentReceived(ConversationContentReceived event) {
    setState(() {
      _removeLoadingMessage();

      if (_chatItems.isNotEmpty && !_chatItems.last.isUser) {
        _chatItems.last.text += event.text;
      } else {
        _chatItems.add(
          LocalMessageModel(
            sender: 'AI Assistant',
            isUser: false,
            text: event.text,
          ),
        );
      }
    });

    _scrollToBottom();
  }

  void _addSurfaceWhenReady({
    required String surfaceId,
    required SurfaceDefinition definition,
  }) {
    if (definition.components.isEmpty) {
      return;
    }

    if (_displayedSurfaceIds.contains(surfaceId)) {
      setState(() {
        _removeLoadingMessage();
      });

      _scrollToBottom();
      return;
    }

    setState(() {
      _removeLoadingMessage();
      _displayedSurfaceIds.add(surfaceId);

      if (_chatItems.isEmpty || _chatItems.last.isUser) {
        _chatItems.add(
          LocalMessageModel(
            sender: 'AI Assistant',
            isUser: false,
            surfaceIds: {surfaceId},
          ),
        );
      } else {
        _chatItems.last.addSurfaceId(surfaceId);
      }
    });

    _scrollToBottom();
  }

  void _sendMessage() {
    final text = _textController.text.trim();

    if (text.isEmpty || _requestInProgress) {
      return;
    }

    final request = ChatMessage.user(text);

    FocusManager.instance.primaryFocus?.unfocus();

    setState(() {
      _requestInProgress = true;
      _lastSentRequest = request;

      _chatItems
        ..add(LocalMessageModel(sender: 'You', isUser: true, text: text))
        ..add(
          LocalMessageModel(
            sender: 'AI Assistant',
            isUser: false,
            status: LocalMessageStatus.loading,
          ),
        );
    });

    _textController.clear();
    _scrollToBottom();

    unawaited(_sendRequest(request));
  }

  Future<void> _sendRequest(ChatMessage request) async {
    try {
      await _conversation.sendRequest(request);

      if (!mounted) {
        return;
      }

      setState(() {
        _requestInProgress = false;
        _removeLoadingMessage();
      });
    } catch (error, stackTrace) {
      debugPrint(
        'Conversation request failed:\n'
        '$error\n'
        '$stackTrace',
      );

      // ConversationError updates the failure UI.
    }
  }

  void _handleRequestFailure(Object error) {
    final failure = error is CloudAiException
        ? error
        : CloudAiException(
            message: error.toString(),
            userMessage: 'Something went wrong. Please try again.',
          );

    setState(() {
      _requestInProgress = false;

      final loadingIndex = _chatItems.lastIndexWhere(
        (message) => message.isLoading,
      );

      final failedMessage = LocalMessageModel(
        sender: 'AI Assistant',
        isUser: false,
        status: LocalMessageStatus.failed,
        errorMessage: failure.userMessage,
        canRetry: failure.canRetry,
      );

      if (loadingIndex == -1) {
        _chatItems.add(failedMessage);
      } else {
        _chatItems[loadingIndex] = failedMessage;
      }
    });

    _scrollToBottom();
  }

  void _retryLastRequest() {
    final request = _lastSentRequest;

    if (request == null || _requestInProgress) {
      return;
    }

    setState(() {
      _requestInProgress = true;

      _removeCurrentAssistantResponse();

      _chatItems.add(
        LocalMessageModel(
          sender: 'AI Assistant',
          isUser: false,
          status: LocalMessageStatus.loading,
        ),
      );
    });

    _scrollToBottom();

    unawaited(_sendRequest(request));
  }

  void _removeLoadingMessage() {
    final loadingIndex = _chatItems.lastIndexWhere((item) => item.isLoading);

    if (loadingIndex != -1) {
      _chatItems.removeAt(loadingIndex);
    }
  }

  void _scrollToBottom() {
    if (!_shouldAutoScroll) {
      return;
    }
    _scrollRequestVersion++;

    _scheduleScrollToBottom(attempt: 0);
  }

  void _scheduleScrollToBottom({required int attempt}) {
    if (_scrollScheduled || _scrollInProgress) {
      return;
    }

    _scrollScheduled = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;

      if (!mounted) {
        return;
      }

      unawaited(_performScrollToBottom(attempt: attempt));
    });
  }

  Future<void> _performScrollToBottom({required int attempt}) async {
    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    final position = _scrollController.position;

    if (!position.hasContentDimensions) {
      _retryScrollToBottom(attempt);
      return;
    }

    final handledRequestVersion = _scrollRequestVersion;

    final distanceFromBottom = position.maxScrollExtent - position.pixels;

    if (distanceFromBottom > _bottomTolerance) {
      _scrollInProgress = true;

      try {
        await _scrollController.animateTo(
          position.maxScrollExtent,
          duration: Duration(milliseconds: attempt == 0 ? 250 : 120),
          curve: Curves.easeOutQuad,
        );
      } finally {
        _scrollInProgress = false;
      }
    }

    if (!mounted || !_scrollController.hasClients) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scrollController.hasClients) {
        return;
      }

      final currentPosition = _scrollController.position;

      final remainingDistance =
          currentPosition.maxScrollExtent - currentPosition.pixels;

      final anotherRequestArrived =
          _scrollRequestVersion != handledRequestVersion;

      final isNotAtBottom = remainingDistance > _bottomTolerance;

      if ((anotherRequestArrived || isNotAtBottom) &&
          attempt < _maxScrollAttempts) {
        _scheduleScrollToBottom(attempt: attempt + 1);
      }
    });
  }

  void _retryScrollToBottom(int attempt) {
    if (attempt >= _maxScrollAttempts) {
      return;
    }

    _scheduleScrollToBottom(attempt: attempt + 1);
  }

  void _handleScrollPosition() {
    if (!_scrollController.hasClients) {
      return;
    }

    final distanceFromBottom = _scrollController.position.extentAfter;

    _shouldAutoScroll = distanceFromBottom <= _nearBottomThreshold;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollController.removeListener(_handleScrollPosition);
    _conversationSubscription.cancel();
    _textController.dispose();
    _scrollController.dispose();
    _conversation.dispose();
    _transport.dispose();
    _surfaceController.dispose();
    _cloudAiService.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 1,
        title: Text(
          'AI Quiz',
          style: theme.textTheme.titleLarge?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: const [
          SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _chatItems.isEmpty
                ? const _EmptyChatState()
                : ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
                    itemCount: _chatItems.length,
                    itemBuilder: (context, index) {
                      final item = _chatItems[index];

                      return MessageBubble(
                        message: item,
                        host: _surfaceController,
                        onRetry: item.hasFailed ? _retryLastRequest : null,
                      );
                    },
                  ),
          ),
          _ChatComposer(
            controller: _textController,
            requestInProgress: _requestInProgress,
            onSend: _sendMessage,
          ),
        ],
      ),
    );
  }
}

class _EmptyChatState extends StatelessWidget {
  const _EmptyChatState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.auto_awesome_outlined,
                  size: 34,
                  color: colorScheme.onPrimaryContainer,
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Start a quiz',
                textAlign: TextAlign.center,
                style: theme.textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Ask the assistant to generate a quiz, '
                'assessment, or another supported interactive prompt.',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChatComposer extends StatelessWidget {
  const _ChatComposer({
    required this.controller,
    required this.requestInProgress,
    required this.onSend,
  });

  final TextEditingController controller;
  final bool requestInProgress;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      enabled: !requestInProgress,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                      ),
                      decoration: InputDecoration(
                        hintText: requestInProgress
                            ? 'Waiting for a response...'
                            : 'Ask for a quiz idea...',
                        hintStyle: theme.textTheme.bodyLarge?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        filled: true,
                        fillColor: colorScheme.surfaceContainerHighest,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.primary,
                            width: 2,
                          ),
                        ),
                        disabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(18),
                          borderSide: BorderSide(
                            color: colorScheme.outlineVariant,
                          ),
                        ),
                      ),
                      onTapOutside: (_) {
                        FocusManager.instance.primaryFocus?.unfocus();
                      },
                      onSubmitted: requestInProgress ? null : (_) => onSend(),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox.square(
                    dimension: 50,
                    child: IconButton.filled(
                      tooltip: 'Send message',
                      onPressed: requestInProgress ? null : onSend,
                      style: IconButton.styleFrom(
                        foregroundColor: colorScheme.onPrimary,
                        backgroundColor: colorScheme.primary,
                        disabledForegroundColor: colorScheme.onSurfaceVariant
                            .withValues(alpha: 0.45),
                        disabledBackgroundColor:
                            colorScheme.surfaceContainerHighest,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: requestInProgress
                          ? SizedBox.square(
                              dimension: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            )
                          : const Icon(Icons.arrow_upward_rounded),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
