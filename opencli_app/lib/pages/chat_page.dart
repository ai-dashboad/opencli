import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../services/chat_storage_service.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
// import 'package:permission_handler/permission_handler.dart';  // Disabled - speech_to_text handles permissions internally
import 'package:image_picker/image_picker.dart';
import '../models/chat_message.dart';
import '../services/daemon_service.dart';
import '../services/intent_recognizer.dart';
import '../services/domain_patterns.dart';
import '../widgets/result_widget.dart';
import '../widgets/ai_video_options.dart';

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
  late final IntentRecognizer _intentRecognizer;

  bool _isListening = false;
  bool _speechAvailable = false;
  final ImagePicker _imagePicker = ImagePicker();
  Uint8List? _selectedImageBytes;
  String? _selectedImageName;



  @override
  void initState() {
    super.initState();
    _intentRecognizer = IntentRecognizer(widget.daemonService);
    _intentRecognizer.registerDomainPatterns(buildDomainPatterns());
    _initSpeech();
    _listenToUpdates();
    _loadMessages();
  }

  Future<void> _initSpeech() async {
    // speech_to_text package handles microphone permissions internally
    try {
      _speechAvailable = await _speech.initialize(
        onStatus: (status) => setState(() => _isListening = status == 'listening'),
        onError: (error) => _showError('Speech recognition error: $error'),
      );

      if (!_speechAvailable) {
        _showError('Speech recognition not available. Please check microphone permissions.');
      }
    } catch (e) {
      _showError('Microphone permission denied. Voice commands require microphone access.');
    }
    setState(() {});
  }

  void _addWelcomeMessage() {
    final welcomeMsg = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      content: 'Hello! I\'m OpenCLI Assistant.\n\nI can automate your Mac. Try:\n\n📱 Apps: "open chrome" / "close safari"\n🌐 Web: "open youtube" / "search flutter"\n💻 System: "system info" / "disk space" / "battery"\n⏱ Timer: "set timer for 25 minutes" / "pomodoro"\n🎵 Music: "play music" / "next song" / "now playing"\n📅 Calendar: "my schedule today" / "schedule meeting"\n✅ Reminders: "remind me to buy groceries"\n🌤 Weather: "weather" / "forecast"\n🧮 Calculator: "calculate 15% of 234"\n📝 Notes: "create note about ideas"\n🌍 Translation: "translate hello to Spanish"',
      isUser: false,
      timestamp: DateTime.now(),
      status: MessageStatus.delivered,
    );
    setState(() => _messages.add(welcomeMsg));
  }

  final _chatStorage = ChatStorageService();

  Future<void> _loadMessages() async {
    try {
      final loaded = await _chatStorage.loadMessages();
      if (loaded.isNotEmpty) {
        setState(() {
          _messages.clear();
          _messages.addAll(loaded);
        });
        _scrollToBottom();
        return;
      }
    } catch (_) {
      // Fall through to welcome message
    }
    _addWelcomeMessage();
  }

  Future<void> _saveMessages() async {
    // Save only the last message (incremental save)
    final toSave = _messages
        .where((m) =>
            m.status != MessageStatus.executing &&
            m.status != MessageStatus.sending)
        .toList();
    if (toSave.isNotEmpty) {
      await _chatStorage.saveMessage(toSave.last);
    }
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

        // Handle intermediate progress updates for long-running tasks
        if (status == 'running' && result != null && executingIndex != -1) {
          final progress = result['progress'] as num?;
          final statusMessage = result['status_message'] as String?;
          if (progress != null || statusMessage != null) {
            final pct = progress != null ? '${(progress * 100).toInt()}%' : '';
            final msg = statusMessage ?? 'Processing...';
            setState(() {
              _messages[executingIndex] = _messages[executingIndex].copyWith(
                content: '✨ $msg ${pct.isNotEmpty ? "($pct)" : ""}',
              );
            });
            _scrollToBottom();
          }
          return;
        }

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
            _saveMessages();
          } else {
            // Normal task completion - check if result indicates failure
            final isSuccess = result['success'] != false;
            setState(() {
              _messages[executingIndex] = _messages[executingIndex].copyWith(
                content: isSuccess ? '✅ Task completed' : '❌ ${result['error'] ?? 'Task failed'}',
                status: isSuccess ? MessageStatus.completed : MessageStatus.failed,
                result: result,
                // taskType is already in original message, copyWith preserves it
              );
            });
            _saveMessages();
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
          _saveMessages();
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
        return '🚀 Opening: ${params['app_name']}...';
      case 'close_app':
        return '🛑 Closing: ${params['app_name']}...';
      case 'screenshot':
        return '📸 Taking screenshot...';
      case 'system_info':
        return '💻 Getting system info...';
      case 'open_url':
        return '🌐 Opening: ${params['url'] ?? 'webpage'}...';
      case 'web_search':
        return '🔍 Searching: ${params['query']}...';
      case 'run_command':
        final cmd = params['command'] ?? '';
        if (cmd == 'bash') return '📜 Running script...';
        if (cmd == 'osascript') return '🍎 Running AppleScript...';
        return '⚙️ Running: $cmd...';
      case 'ai_query':
        return '🤖 Thinking...';
      case 'check_process':
        return '🔎 Checking: ${params['process_name']}...';
      case 'file_operation':
        return '📂 ${params['operation'] ?? 'Processing'} files...';
      case 'media_animate_photo':
        return '🎬 Creating animation from photo...';
      case 'media_create_slideshow':
        return '🎬 Creating slideshow...';
      case 'media_ai_generate_video':
        return '✨ Generating AI video...';
      default:
        return '⏳ Processing...';
    }
  }

  void _showAIVideoOptions() {
    if (_selectedImageBytes == null) {
      _showError('Please attach a photo first');
      return;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, controller) => AIVideoOptionsSheet(
          onGenerate: ({
            required provider,
            required style,
            customPrompt,
            scenario,
            aspectRatio,
            inputText,
            productName,
            duration,
            mode,
            effect,
          }) {
            _submitAIVideoGeneration(
              provider, style, customPrompt,
              effect: effect,
              duration: duration,
              mode: mode,
              inputText: inputText,
              scenario: scenario,
              aspectRatio: aspectRatio,
              productName: productName,
            );
          },
        ),
      ),
    );
  }

  Future<void> _submitAIVideoGeneration(
    String provider, String style, String? customPrompt, {
    String? effect, int? duration, String? mode, String? inputText,
    String? scenario, String? aspectRatio, String? productName,
  }) async {
    if (_selectedImageBytes == null) return;

    final imageBase64 = base64Encode(_selectedImageBytes!);
    setState(() {
      _selectedImageBytes = null;
      _selectedImageName = null;
    });

    // Choose task type: novel scenario with no image → text-to-video, otherwise image-based
    final taskType = provider == 'local' ? 'media_animate_photo' : 'media_ai_generate_video';
    final effectName = effect ?? 'ken_burns';
    final providerLabel = provider == 'local' ? 'FFmpeg/$effectName' : provider;
    final scenarioLabel = scenario != null && scenario != 'custom' ? ' [$scenario]' : '';
    final modeLabel = mode == 'production' ? ' [PRO]' : '';

    _addAssistantMessage(
      '✨ Generating ${provider == "local" ? "local" : "AI"} video ($providerLabel)$scenarioLabel$modeLabel...',
      status: MessageStatus.executing,
      taskType: taskType,
    );

    try {
      final taskData = <String, dynamic>{
        'image_base64': imageBase64,
        'style': style,
        if (provider != 'local') 'provider': provider,
        if (customPrompt != null && customPrompt.isNotEmpty) 'custom_prompt': customPrompt,
        if (provider == 'local') 'effect': effectName,
        if (duration != null) 'duration': duration,
        if (mode != null) 'mode': mode,
        if (inputText != null) 'input_text': inputText,
        if (scenario != null) 'scenario': scenario,
        if (aspectRatio != null) 'aspect_ratio': aspectRatio,
        if (productName != null) 'product_name': productName,
      };
      await widget.daemonService.submitTask(taskType, taskData);
    } catch (e) {
      _addAssistantMessage('❌ Video generation failed: $e', status: MessageStatus.failed);
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

    // DEBUG: Test AI video flow without photo picker (bypasses iOS simulator limitations)
    if (text.trim().toLowerCase().startsWith('test ai video')) {
      _textController.clear();
      // 256x256 test pattern PNG — verified to produce visible Ken Burns in <1s
      const testPng = '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';
      setState(() {
        _selectedImageBytes = base64Decode(testPng);
        _selectedImageName = 'test_photo.png';
      });
      final lower = text.trim().toLowerCase();
      // Quick shortcuts for direct testing
      if (lower == 'test ai video quick') {
        _submitAIVideoGeneration('replicate', 'cinematic', null);
      } else if (lower == 'test ai video local') {
        _submitAIVideoGeneration('local', 'ken_burns', null);
      }
      // All 6 FFmpeg effects
      else if (lower == 'test ai video zoom') {
        _submitAIVideoGeneration('local', 'zoom_in', null, effect: 'zoom_in');
      } else if (lower == 'test ai video zoomout') {
        _submitAIVideoGeneration('local', 'zoom_out', null, effect: 'zoom_out');
      } else if (lower == 'test ai video pan') {
        _submitAIVideoGeneration('local', 'pan_left', null, effect: 'pan_left');
      } else if (lower == 'test ai video panr') {
        _submitAIVideoGeneration('local', 'pan_right', null, effect: 'pan_right');
      } else if (lower == 'test ai video pulse') {
        _submitAIVideoGeneration('local', 'pulse', null, effect: 'pulse');
      }
      // Extended duration tests (8s videos)
      else if (lower == 'test ai video long') {
        _submitAIVideoGeneration('local', 'ken_burns', null, effect: 'ken_burns', duration: 8);
      } else if (lower == 'test ai video longzoom') {
        _submitAIVideoGeneration('local', 'zoom_in', null, effect: 'zoom_in', duration: 8);
      }
      // All effects burst — generate 3 videos in sequence
      else if (lower == 'test ai video burst') {
        _submitAIVideoGeneration('local', 'ken_burns', null, effect: 'ken_burns');
        await Future.delayed(const Duration(milliseconds: 500));
        // Re-set the test image for next generation
        setState(() {
          _selectedImageBytes = base64Decode(testPng);
          _selectedImageName = 'test_photo.png';
        });
        _submitAIVideoGeneration('local', 'zoom_in', null, effect: 'zoom_in');
        await Future.delayed(const Duration(milliseconds: 500));
        setState(() {
          _selectedImageBytes = base64Decode(testPng);
          _selectedImageName = 'test_photo.png';
        });
        _submitAIVideoGeneration('local', 'pulse', null, effect: 'pulse');
      }
      // Cloud AI provider tests (will show error if no API key)
      else if (lower == 'test ai video replicate') {
        _submitAIVideoGeneration('replicate', 'cinematic', null);
      } else if (lower == 'test ai video runway') {
        _submitAIVideoGeneration('runway', 'epic', null);
      } else if (lower == 'test ai video kling') {
        _submitAIVideoGeneration('kling', 'adPromo', null);
      } else if (lower == 'test ai video luma') {
        _submitAIVideoGeneration('luma', 'mysterious', null);
      }
      // Production prompt tests
      else if (lower == 'test ai video production') {
        setState(() {
          _selectedImageBytes = base64Decode(testPng);
          _selectedImageName = 'test_photo.png';
        });
        _submitAIVideoGeneration('local', 'cinematic', null,
            mode: 'production', inputText: 'A serene mountain landscape at golden hour');
      } else if (lower == 'test ai video prod epic') {
        setState(() {
          _selectedImageBytes = base64Decode(testPng);
          _selectedImageName = 'test_photo.png';
        });
        _submitAIVideoGeneration('local', 'epic', null,
            mode: 'production', inputText: 'A lone hero standing on a cliff overlooking a vast ocean');
      } else if (lower == 'test ai video prod abstract') {
        setState(() {
          _selectedImageBytes = base64Decode(testPng);
          _selectedImageName = 'test_photo.png';
        });
        _submitAIVideoGeneration('local', 'mysterious', null,
            mode: 'production', inputText: 'Innovation and creativity');
      } else if (lower == 'test ai video prod cloud') {
        setState(() {
          _selectedImageBytes = base64Decode(testPng);
          _selectedImageName = 'test_photo.png';
        });
        _submitAIVideoGeneration('replicate', 'cinematic', null,
            mode: 'production', inputText: 'A golden retriever playing in a park');
      }
      // Aspect ratio quality tests (1080p verification)
      else if (lower == 'test ai video tiktok') {
        _submitAIVideoGeneration('local', 'ken_burns', null,
            effect: 'ken_burns', aspectRatio: '9:16');
      } else if (lower == 'test ai video instagram') {
        _submitAIVideoGeneration('local', 'ken_burns', null,
            effect: 'ken_burns', aspectRatio: '1:1');
      } else if (lower == 'test ai video youtube') {
        _submitAIVideoGeneration('local', 'ken_burns', null,
            effect: 'ken_burns', aspectRatio: '16:9');
      }
      // Default: open bottom sheet
      else {
        _showAIVideoOptions();
      }
      return;
    }

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
    _saveMessages();
    _scrollToBottom();

    // 解析用户意图并执行任务
    await _parseAndExecute(text);
  }

  Future<void> _parseAndExecute(String input) async {
    try {
      // Show AI recognition status
      _addAssistantMessage('🤖 Understanding your command...', status: MessageStatus.executing);

      // Use AI-powered intent recognition engine
      final result = await _intentRecognizer.recognize(input);

      // Remove "recognizing" message
      if (_messages.isNotEmpty && !_messages.last.isUser) {
        setState(() {
          _messages.removeLast();
        });
      }

      // Not recognized or confidence too low (should rarely happen with auto-fallback)
      if (!result.isRecognized) {
        final errorMsg = result.error ?? 'Unable to understand command';
        _addAssistantMessage(
          '🤔 Having trouble understanding. Error: $errorMsg\n\nTry:\n• "open youtube" / "dark mode" / "system info"\n• "kill port 3000" / "show largest files"\n• "create note about shopping"\n• "git status" / "compress downloads"',
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

        // Attach image if selected (for media_creation tasks)
        if (_selectedImageBytes != null) {
          taskData['image_base64'] = base64Encode(_selectedImageBytes!);
          setState(() {
            _selectedImageBytes = null;
            _selectedImageName = null;
          });
        }

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
        return '🌐 Opening: ${result.taskData['url'] ?? 'webpage'}...';
      case 'web_search':
        return '🔍 Searching: ${result.taskData['query']}...';
      case 'system_info':
        return '💻 Getting system info...';
      case 'open_app':
        return '🚀 Opening: ${result.taskData['app_name']}...';
      case 'close_app':
        return '🛑 Closing: ${result.taskData['app_name']}...';
      case 'open_file':
        return '📁 Opening file...';
      case 'run_command':
        final cmd = result.taskData['command'] ?? '';
        if (cmd == 'bash') return '📜 Running script...';
        if (cmd == 'osascript') return '🍎 Running AppleScript...';
        return '⚙️ Running: $cmd...';
      case 'ai_query':
        return '🤖 Thinking...';
      case 'check_process':
        return '🔎 Checking process: ${result.taskData['process_name']}...';
      case 'list_processes':
        return '📋 Listing processes...';
      case 'file_operation':
        return '📂 ${result.taskData['operation'] ?? 'Processing'} files...';
      case 'create_file':
        return '📝 Creating file...';
      case 'delete_file':
        return '🗑️ Deleting file...';
      case 'read_file':
        return '📖 Reading file...';
      case 'list_apps':
        return '📱 Listing apps...';
      case 'media_animate_photo':
        return '🎬 Creating animation from photo...';
      case 'media_create_slideshow':
        return '🎬 Creating slideshow...';
      case 'media_ai_generate_video':
        return '✨ Generating AI video...';
      default:
        return '⏳ Processing your request...';
    }
  }

  void _toggleListening() {
    if (_isListening) {
      _stopListening();
    } else {
      _startListening();
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

  Future<void> _pickImage() async {
    showModalBottomSheet(
      context: context,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.pop(context);
                _pickFrom(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.pop(context);
                _pickFrom(ImageSource.gallery);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickFrom(ImageSource source) async {
    try {
      final picked = await _imagePicker.pickImage(
        source: source,
        maxWidth: 1920,
        maxHeight: 1080,
        imageQuality: 85,
      );
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedImageBytes = bytes;
          _selectedImageName = picked.name;
        });
      }
    } catch (e) {
      _showError('Failed to pick image: $e');
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
            key: const ValueKey('message_list'),
            controller: _scrollController,
            padding: const EdgeInsets.all(16),
            itemCount: _messages.length,
            itemBuilder: (context, index) {
              return _MessageBubble(message: _messages[index]);
            },
          ),
        ),
        if (_selectedImageBytes != null) _buildImagePreviewChip(),
        _buildInputArea(),
      ],
    );
  }

  Widget _buildImagePreviewChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      margin: const EdgeInsets.only(bottom: 2),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: Image.memory(_selectedImageBytes!, width: 40, height: 40, fit: BoxFit.cover),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              _selectedImageName ?? 'Photo attached',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.auto_awesome, size: 18),
            onPressed: _showAIVideoOptions,
            tooltip: 'Create video from photo',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
            color: const Color(0xFF7C4DFF),
          ),
          const SizedBox(width: 4),
          IconButton(
            icon: const Icon(Icons.close, size: 16),
            onPressed: () => setState(() {
              _selectedImageBytes = null;
              _selectedImageName = null;
            }),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
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
                key: const ValueKey('chat_text_field'),
                controller: _textController,
                decoration: InputDecoration(
                  hintText: _isListening ? 'Listening...' : 'Enter command or tap mic',
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
            const SizedBox(width: 4),
            // Photo attach button
            IconButton(
              key: const ValueKey('photo_button'),
              icon: Icon(
                _selectedImageBytes != null ? Icons.image : Icons.add_photo_alternate,
                color: _selectedImageBytes != null
                    ? const Color(0xFF7C4DFF)
                    : Colors.grey[600],
              ),
              onPressed: _pickImage,
              tooltip: 'Attach photo',
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
            const SizedBox(width: 4),
            // Voice button
            GestureDetector(
              key: const ValueKey('mic_button'),
              onTap: _toggleListening,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: _isListening ? 52 : 48,
                height: _isListening ? 52 : 48,
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
            Tooltip(
              message: 'Send',
              child: IconButton(
                key: const ValueKey('send_button'),
                onPressed: () => _handleSubmit(_textController.text),
                icon: const Icon(Icons.send),
                color: Theme.of(context).colorScheme.primary,
              ),
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
