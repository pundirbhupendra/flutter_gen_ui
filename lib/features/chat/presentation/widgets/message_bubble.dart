import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:genui/genui.dart';
import 'package:gen_ui/features/chat/data/models/local_message_model.dart';

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    required this.message,
    required this.host,
    this.onRetry,
    super.key,
  });

  final LocalMessageModel message;
  final SurfaceHost host;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final bubbleColor = _getBubbleColor(colorScheme);
    final foregroundColor = _getForegroundColor(colorScheme);
    final borderColor = _getBorderColor(colorScheme);

    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.8,
        ),
        decoration: BoxDecoration(
          color: bubbleColor,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(message.isUser ? 16 : 4),
            bottomRight: Radius.circular(message.isUser ? 4 : 16),
          ),
          border: Border.all(color: borderColor),
        ),
        child: DefaultTextStyle.merge(
          style: TextStyle(color: foregroundColor),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.sender,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: message.isUser
                      ? colorScheme.onPrimaryContainer.withValues(alpha: 0.7)
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              _buildContent(context, foregroundColor: foregroundColor),
            ],
          ),
        ),
      ),
    );
  }

  Color _getBubbleColor(ColorScheme colorScheme) {
    if (message.hasFailed) {
      return colorScheme.errorContainer;
    }

    if (message.isUser) {
      return colorScheme.primaryContainer;
    }

    return colorScheme.surfaceContainerHigh;
  }

  Color _getForegroundColor(ColorScheme colorScheme) {
    if (message.hasFailed) {
      return colorScheme.onErrorContainer;
    }

    if (message.isUser) {
      return colorScheme.onPrimaryContainer;
    }

    return colorScheme.onSurface;
  }

  Color _getBorderColor(ColorScheme colorScheme) {
    if (message.hasFailed) {
      return colorScheme.error.withValues(alpha: 0.35);
    }

    if (message.isUser) {
      return colorScheme.primary.withValues(alpha: 0.2);
    }

    return colorScheme.outlineVariant;
  }

  Widget _buildContent(BuildContext context, {required Color foregroundColor}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (message.isLoading) {
      return Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 36,
          child: SpinKitThreeBounce(
            color: colorScheme.onSurfaceVariant,
            size: 20,
          ),
        ),
      );
    }

    if (message.hasFailed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.error_outline, size: 20, color: colorScheme.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  message.errorMessage ?? 'The request failed.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          if (message.canRetry && onRetry != null) ...[
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(foregroundColor: colorScheme.error),
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ],
      );
    }

    if (message.isUser) {
      return Text(
        message.text,
        style: theme.textTheme.bodyMedium?.copyWith(color: foregroundColor),
      );
    }

    final surfaceIds = message.surfaceIds;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (message.text.trim().isNotEmpty)
          MarkdownBody(
            data: message.text,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
              p: theme.textTheme.bodyMedium?.copyWith(
                color: foregroundColor,
                height: 1.4,
              ),
              h1: theme.textTheme.headlineMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
              ),
              h2: theme.textTheme.headlineSmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
              ),
              h3: theme.textTheme.titleLarge?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
              ),
              strong: TextStyle(
                color: foregroundColor,
                fontWeight: FontWeight.bold,
              ),
              em: TextStyle(
                color: foregroundColor,
                fontStyle: FontStyle.italic,
              ),
              code: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                backgroundColor: colorScheme.surfaceContainerHighest,
                fontFamily: 'monospace',
              ),
              blockquote: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              blockquoteDecoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(8),
                border: BorderDirectional(
                  start: BorderSide(color: colorScheme.primary, width: 3),
                ),
              ),
              a: TextStyle(
                color: colorScheme.primary,
                decoration: TextDecoration.underline,
                decorationColor: colorScheme.primary,
              ),
              listBullet: TextStyle(color: foregroundColor),
            ),
          ),
        for (final surfaceId in surfaceIds)
          Padding(
            padding: const EdgeInsetsDirectional.only(top: 12),
            child: Surface(
              key: ValueKey<String>(surfaceId),
              surfaceContext: host.contextFor(surfaceId),
              actionDelegate: DefaultActionDelegate(),
            ),
          ),
      ],
    );
  }
}
