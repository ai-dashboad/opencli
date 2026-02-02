import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import '../models/chat_message.dart';
import '../services/daemon_service.dart';
import '../services/intent_recognizer.dart';
import '../widgets/result_widget.dart';

class ChatPage extends StatefulWidget {
  final DaemonService daemonService;

  const ChatPage({super.key, required this.daemonService});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _speechAvailable = false;

  @override
  void initState() {
    super.initState();
    _initSpeech();
    _listenToUpdates();
    _addWelcomeMessage();
  }

  Future<void> _initSpeech() async {
    // Request microphone permission
    final status = await Permission.microphone.request();

    if (status.isGranted) {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) => setState(() => _isListening = status == 'listening'),
        onError: (error) => _showError('Speech recognition error: $error'),
      );
    } else if (status.isPermanentlyDenied) {
      _showError('Microphone permission permanently denied. Please enable it in settings.');
    } else {
      _showError('Microphone permission denied. Voice commands require microphone access.');
    }
    setState(() {});
  }

  void _addWelcomeMessage() {
    final welcomeMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Hello! I\'m OpenCLI Assistant.\n\nYou can tell me what to do via text or voice, for example:\n\n• "Take a screenshot"\n• "Open Google"\n• "Search Flutter tutorial"\n• "Get system info"',
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
    );
    setState(() => _messages.add(welcomeMsg));
  }

  void _listenToUpdates() {
    widget.daemonService.messages.listen((message) {
      final type = message['type'] as String;

      if (type == 'task_update') {
        final status = message['status'];
        final result = message['result'];
        final error = message['error'];

        // Find and update the last "executing" message
        final executingIndex = _messages.lastIndexWhere(
          (msg) => msg.status == MessageStatus.executing && !msg.isUser,
        );

        if (status == 'completed' && result != null && executingIndex != -1) {
          // Check if this is an AI intent recognition result
          if (result['intent'] != null && result['intent'] != 'unknown') {
            // AI recognition successful, submit the recognized task
            final intent = result['intent'] as String;
            final parameters = result['parameters'] as Map<String, dynamic>? ?? {};

            setState(() {
              _messages[executingIndex] = _messages[executingIndex].copyWith(
                content: '🤖 Recognized intent: $intent',
                status: MessageStatus.completed,
              );
            });

            // Submit the recognized task
            _submitRecognizedTask(intent, parameters);
          } else {
            // Normal task completion - preserve original message taskType
            setState(() {
              _messages[executingIndex] = _messages[executingIndex].copyWith(
                content: '✅ Task completed',
                status: MessageStatus.completed,
                result: result,
                // taskType is already in original message, copyWith preserves it
              );
            });
          }
          _scrollToBottom();
        } else if (status == 'failed' && error != null && executingIndex != -1) {
          // Replace the executing message with error
          setState(() {
            _messages[executingIndex] = _messages[executingIndex].copyWith(
              content: '❌ Task failed: $error',
              status: MessageStatus.failed,
            );
          });
          _scrollToBottom();
        }
      }
    });
  }

  /// Submit AI-recognized task
  Future<void> _submitRecognizedTask(String intent, Map<String, dynamic> parameters, {String? originalInput}) async {
    final processingMsg = _getProcessingMessageForIntent(intent, parameters);
    _addAssistantMessage(processingMsg, status: MessageStatus.executing, taskType: intent);

    try {
      // Add user's original input to task data
      final taskData = Map<String, dynamic>.from(parameters);
      if (originalInput != null) {
        taskData['_user_input'] = originalInput;
      }
      await widget.daemonService.submitTask(intent, taskData);
    } catch (e) {
      _addAssistantMessage('❌ Execution failed: $e', status: MessageStatus.failed);
    }
  }

  String _getProcessingMessageForIntent(String intent, Map<String, dynamic> params) {
    switch (intent) {
      case 'open_app':
        return '🚀 Opening app: ${params['app_name']}...';
      case 'screenshot':
        return '📸 Taking screenshot...';
      case 'system_info':
        return '💻 Getting system info...';
      default:
        return '⏳ Processing...';
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addAssistantMessage(
    String content, {
    MessageStatus status = MessageStatus.delivered,
    Map<String, dynamic>? result,
    String? taskType,
  }) {
    final message = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: content,
      isUser: false,
      timestamp: DateTime.now(),
      status: status,
      result: result,
      taskType: taskType,
    );
    setState(() => _messages.add(message));
    _scrollToBottom();
  }

  Future<void> _handleSubmit(String text) async {
    if (text.trim().isEmpty) return;

    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: text,
      isUser: true,
      timestamp: DateTime.now(),
      status: MessageStatus.sent,
    );

    setState(() {
      _messages.add(userMessage);
      _textController.clear();
    });
    _scrollToBottom();

    // 解析用户意图并执行任务
    await _parseAndExecute(text);
  }

  Future<void> _parseAndExecute(String input) async {
    try {
      // Show AI recognition status
      _addAssistantMessage('🤖 Understanding your command...', status: MessageStatus.executing);

      // Use AI-powered intent recognition engine
      final recognizer = IntentRecognizer(widget.daemonService);
      final result = await recognizer.recognize(input);

      // Remove "recognizing" message
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        setState(() {
          _messages.removeLast();
        });
      }

      // Not recognized or confidence too low
      if (!result.isRecognized) {
        final errorMsg = result.error ?? 'Unable to understand command';
        _addAssistantMessage(
          '🤔 Sorry, I don\'t understand this command yet.\n\nError: $errorMsg\n\nYou can try:\n• "Take a screenshot"\n• "Screenshot the simulator"\n• "Open google.com"\n• "Search Flutter"\n• "Get system info"\n• "Open Chrome"\n• "Run command ls"',
          status: MessageStatus.failed,
        );
        return;
      }

      // Generate processing message
      final processingMessage = _getProcessingMessage(result);
      _addAssistantMessage(
        processingMessage,
        status: MessageStatus.executing,
        taskType: result.taskType, // Pass taskType
      );

      // Submit task (actual result will be received via _listenToUpdates)
      if (result.taskType != null) {
        // Add user's original input to task data
        final taskData = Map<String, dynamic>.from(result.taskData);
        taskData['_user_input'] = input;

        await widget.daemonService.submitTask(
          result.taskType!,
          taskData,
        );
      }
    } catch (e) {
      // Remove any remaining "recognizing" message
      if (_messages.isNotEmpty &&
          !_messages.last.isUser &&
          _messages.last.content.contains('Understanding')) {
        setState(() {
          _messages.removeLast();
        });
      }
      _addAssistantMessage('❌ Execution failed: $e', status: MessageStatus.failed);
    }
  }

  /// Generate processing message based on intent
  String _getProcessingMessage(IntentResult result) {
    switch (result.intent) {
      case 'screenshot':
        return '📸 Taking screenshot...';
      case 'open_url':
        return '🌐 Opening webpage: ${result.taskData['url']}...';
      case 'web_search':
        return '🔍 Searching: ${result.taskData['query']}...';
      case 'system_info':
        return '💻 Getting system info...';
      case 'open_app':
        return '🚀 Opening app: ${result.taskData['app_name']}...';
      case 'close_app':
        return '❌ Closing app: ${result.taskData['app_name']}...';
      case 'open_file':
        return '📁 Opening file...';
      case 'run_command':
        return '⚙️ Executing command...';
      case 'ai_query':
        return '🤖 Thinking...';
      default:
        return '⏳ Processing your request...';
    }
  }

  void _startListening() async {
    if (!_speechAvailable) {
      _showError('Speech recognition unavailable');
      return;
    }

    if (!_isListening) {
      try {
        await _speech.listen(
          onResult: (result) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          },
          localeId: 'en_US',
        );
      } catch (e) {
        _showError('Failed to start speech recognition: $e');
      }
    }
  }

  void _stopListening() {
    _speech.stop();
    setState(() => _isListening = false);

    // Auto-submit if there's recognized text
    if (_textController.text.isNotEmpty) {
      _handleSubmit(_textController.text);
    }
  }

  void _showError(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _MessageBubble(message: _messages[index]);
            },
          ),
        ),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildInputArea() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _textController,
                decoration: InputDecoration(
                  hintText: _isListening ? 'Listening...' : 'Enter command or hold to speak',
                  filled: true,
                  fillColor: Theme.of(context).colorScheme.surfaceVariant,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
                onSubmitted: _handleSubmit,
              ),
            ),
            const SizedBox(width: 8),
            // 语音按钮
            GestureDetector(
              onLongPressStart: (_) => _startListening(),
              onLongPressEnd: (_) => _stopListening(),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: _isListening
                      ? Colors.red
                      : Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _isListening ? Icons.mic : Icons.mic_none,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // 发送按钮
            IconButton(
              onPressed: () => _handleSubmit(_textController.text),
              icon: const Icon(Icons.send),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final ChatMessage message;

  const _MessageBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            message.isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!message.isUser) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: const Icon(Icons.computer, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: message.isUser
                  ? CrossAxisAlignment.end
                  : CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: message.isUser
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context).colorScheme.surfaceVariant,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.content,
                        style: TextStyle(
                          color: message.isUser
                              ? Colors.white
                              : Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      if (message.status == MessageStatus.executing) ...[
                        const SizedBox(height: 8),
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ],
                      if (message.result != null && !message.isUser) ...[
                        const SizedBox(height: 8),
                        // 如果是截图，显示图片
                        if (message.result!['image_base64'] != null) ...[
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  // 点击图片后全屏查看
                                  showDialog(
                                    context: context,
                                    builder: (context) => _ImageViewerDialog(
                                      imageBase64: message.result!['image_base64'],
                                      fileSize: message.result!['size_bytes'],
                                    ),
                                  );
                                },
                                child: Stack(
                                  children: [
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(8),
                                      child: Image.memory(
                                        base64Decode(message.result!['image_base64']),
                                        width: 250,
                                        fit: BoxFit.contain,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            padding: const EdgeInsets.all(8),
                                            decoration: BoxDecoration(
                                              color: Colors.red.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(8),
                                            ),
                                            child: Text(
                                              '❌ Image load failed',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.red,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    // 放大图标提示
                                    Positioned(
                                      right: 8,
                                      bottom: 8,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.black.withOpacity(0.5),
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Icon(
                                          Icons.zoom_in,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  if (message.result!['size_bytes'] != null)
                                    Text(
                                      '📸 ${(message.result!['size_bytes'] / 1024).toStringAsFixed(1)} KB',
                                      style: TextStyle(
                                        fontSize: 10,
                                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Tap to zoom',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context).colorScheme.primary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ] else if (message.result!['path'] != null &&
                            message.result!['path'].toString().contains('screenshot')) ...[
                          // 降级方案：尝试从文件路径加载
                          ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(
                              File(message.result!['path']),
                              width: 250,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withOpacity(0.05),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '📸 Screenshot saved at:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12,
                                          color: Theme.of(context).colorScheme.primary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        message.result!['path'],
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontFamily: 'monospace',
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ] else if (message.taskType != null) ...[
                          // 使用 ResultWidget 智能显示结果
                          ResultWidget(
                            taskType: message.taskType!,
                            result: message.result!,
                          ),
                        ] else ...[
                          // 降级方案：其他结果显示为文本
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '📊 Result:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                ...message.result!.entries.where((entry) {
                                  // 过滤掉 base64 数据，避免显示过长
                                  return entry.key != 'image_base64';
                                }).map((entry) {
                                  return Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 2),
                                    child: Text(
                                      '${entry.key}: ${entry.value}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontFamily: 'monospace',
                                        color: Theme.of(context).colorScheme.onSurface,
                                      ),
                                    ),
                                  );
                                }).toList(),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _formatTime(message.timestamp),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                    ),
                    if (!message.isUser) ...[
                      const SizedBox(width: 4),
                      Icon(
                        _getStatusIcon(message.status),
                        size: 12,
                        color: _getStatusColor(message.status, context),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (message.isUser) ...[
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 16,
              backgroundColor: Theme.of(context).colorScheme.secondary,
              child: const Icon(Icons.person, size: 16, color: Colors.white),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  IconData _getStatusIcon(MessageStatus status) {
    switch (status) {
      case MessageStatus.sending:
        return Icons.access_time;
      case MessageStatus.sent:
        return Icons.done;
      case MessageStatus.delivered:
        return Icons.done_all;
      case MessageStatus.executing:
        return Icons.autorenew;
      case MessageStatus.completed:
        return Icons.check_circle;
      case MessageStatus.failed:
        return Icons.error;
    }
  }

  Color _getStatusColor(MessageStatus status, BuildContext context) {
    switch (status) {
      case MessageStatus.completed:
        return Colors.green;
      case MessageStatus.failed:
        return Colors.red;
      case MessageStatus.executing:
        return Colors.orange;
      default:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }
}

/// 图片全屏查看器，支持缩放
class _ImageViewerDialog extends StatefulWidget {
  final String imageBase64;
  final int? fileSize;

  const _ImageViewerDialog({
    required this.imageBase64,
    this.fileSize,
  });

  @override
  State<_ImageViewerDialog> createState() => _ImageViewerDialogState();
}

class _ImageViewerDialogState extends State<_ImageViewerDialog> {
  final TransformationController _transformationController =
      TransformationController();
  TapDownDetails? _doubleTapDetails;

  void _handleDoubleTapDown(TapDownDetails details) {
    _doubleTapDetails = details;
  }

  void _handleDoubleTap() {
    if (_transformationController.value != Matrix4.identity()) {
      // 如果已放大，重置为原始大小
      _transformationController.value = Matrix4.identity();
    } else {
      // 放大到双击位置
      final position = _doubleTapDetails!.localPosition;
      _transformationController.value = Matrix4.identity()
        ..translate(-position.dx * 2, -position.dy * 2)
        ..scale(3.0);
    }
  }

  @override
  void dispose() {
    _transformationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final imageBytes = base64Decode(widget.imageBase64);

    return Dialog(
      backgroundColor: Colors.black,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // 可缩放的图片
          GestureDetector(
            onDoubleTapDown: _handleDoubleTapDown,
            onDoubleTap: _handleDoubleTap,
            child: InteractiveViewer(
              transformationController: _transformationController,
              minScale: 0.5,
              maxScale: 4.0,
              child: Center(
                child: Image.memory(
                  imageBytes,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
          // 顶部工具栏
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 16,
                right: 16,
                bottom: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  const Spacer(),
                  if (widget.fileSize != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${(widget.fileSize! / 1024).toStringAsFixed(1)} KB',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          // 底部提示
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(context).padding.bottom + 16,
                top: 16,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withOpacity(0.7),
                    Colors.transparent,
                  ],
                ),
              ),
              child: const Center(
                child: Text(
                  'Double tap to zoom • Pinch to scale',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
