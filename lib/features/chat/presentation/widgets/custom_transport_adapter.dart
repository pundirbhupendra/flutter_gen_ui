// Copyright 2025 The Flutter Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart' as core;
import 'package:genui/genui.dart';

/// A manual sender callback.
typedef ManualSendCallback = Future<void> Function(ChatMessage message);

/// The primary high-level API for typical Flutter application development.
///
/// It wraps the [A2uiParserTransformer] to provide an imperative, push-based
/// interface that is easier to integrate into imperative loops.
///
/// Use [addChunk] to feed text chunks from an LLM.
/// Use [addMessage] to feed raw A2UI messages.
class CustomTransportAdapter implements Transport {
  /// Creates a [CustomTransportAdapter].
  ///
  /// The [onSend] callback is required if [sendRequest] will be called.
  CustomTransportAdapter({this.onSend}) {
    _pipeline = _inputStream.stream
        .transform(const A2uiParserTransformer())
        .asBroadcastStream();
  }

  /// The callback to invoke when [sendRequest] is called.
  final ManualSendCallback? onSend;

  final StreamController<String> _inputStream = StreamController();
  final StreamController<core.A2uiMessage> _messageStream =
      StreamController.broadcast();
  late final Stream<GenerationEvent> _pipeline;
  StreamSubscription<GenerationEvent>? _pipelineSubscription;

  /// Feeds a chunk of text from the LLM to the controller.
  ///
  /// The controller buffers and parses this internally using the transformer.
  void addChunk(String text) {
    _pipelineSubscription ??= _pipeline.listen((event) {
      if (event is A2uiMessageEvent) {
        final message = _ensureVersionField(event.message);
        _messageStream.add(message);
      }
    });
    _inputStream.add(text);
  }

  /// Feeds a raw A2UI message (e.g. from a tool output or separate channel).
  void addMessage(core.A2uiMessage message) {
    final messageWithVersion = _ensureVersionField(message);
    _messageStream.add(messageWithVersion);
  }

  /// A stream of sanitizer text for the chat UI.
  @override
  Stream<String> get incomingText => _pipeline
      .where((e) => e is TextEvent)
      .cast<TextEvent>()
      .map((e) => e.text)
      .where((text) => text.isNotEmpty);

  /// A stream of A2UI messages parsed from the input.
  @override
  Stream<core.A2uiMessage> get incomingMessages => _messageStream.stream;

  @override
  Future<void> sendRequest(ChatMessage message) async {
    if (onSend == null) {
      throw StateError(
        'A2uiTransportAdapter.onSend must be provided to use sendRequest.',
      );
    }
    await onSend!(message);
  }

  Future<void> flush() async {
    await _inputStream.close();
    await _pipelineSubscription?.asFuture<void>();
  }

  /// Closes the controller and cleans up resources.
  @override
  void dispose() {
    _inputStream.close();
    _messageStream.close();
    _pipelineSubscription?.cancel();
  }

  /// Ensures the A2UI message has a version field.
  /// Adds version "v0.9" if missing.
  core.A2uiMessage _ensureVersionField(core.A2uiMessage message) {
    final json = message.toJson();
    
    // If version is already present, return as-is
    if (json.containsKey('version') && json['version'] == 'v0.9') {
      return message;
    }
    
    // Add/ensure version field and reconstruct
    final updatedJson = <String, dynamic>{
      'version': 'v0.9',
      ...json,
    };
    
    return core.A2uiMessage.fromJson(updatedJson);
  }
}
