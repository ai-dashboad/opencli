import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:opencli_daemon/ai/model_adapter.dart';

class ClaudeAdapter implements ModelAdapter {
  final String apiKey;
  final String model;
  final http.Client _client;

  static const String _baseUrl = 'https://api.anthropic.com/v1';
  static const String _apiVersion = '2023-06-01';

  ClaudeAdapter({
    required this.apiKey,
    this.model = 'claude-sonnet-4-20250514',
  }) : _client = http.Client();

  @override
  String get name => 'claude';

  @override
  String get provider => 'anthropic';

  @override
  bool get isAvailable => apiKey.isNotEmpty;

  @override
  Future<void> initialize() async {
    // Test API key with a minimal request
    try {
      await _makeRequest('/messages', {
        'model': model,
        'max_tokens': 1,
        'messages': [
          {'role': 'user', 'content': 'Hi'}
        ],
      });
    } catch (e) {
      throw Exception('Failed to initialize Claude: $e');
    }
  }

  @override
  Future<ChatResponse> chat(ChatRequest request) async {
    final messages = <Map<String, dynamic>>[];

    // Add history
    for (final msg in request.history) {
      messages.add(msg.toJson());
    }

    // Add current message
    messages.add({
      'role': 'user',
      'content': request.message,
    });

    final body = {
      'model': model,
      'messages': messages,
      'max_tokens': request.maxTokens ?? 8192,
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.systemPrompt != null) 'system': request.systemPrompt,
      if (request.stopSequences != null)
        'stop_sequences': request.stopSequences,
    };

    final response = await _makeRequest('/messages', body);

    final content = response['content'][0]['text'] as String;
    final usage = response['usage'];

    return ChatResponse(
      content: content,
      inputTokens: usage['input_tokens'],
      outputTokens: usage['output_tokens'],
      cost: estimateCost(usage['input_tokens'], usage['output_tokens']),
      metadata: {
        'model': model,
        'stop_reason': response['stop_reason'],
      },
    );
  }

  @override
  Future<String> complete(String prompt, {int? maxTokens}) async {
    final response = await chat(ChatRequest(
      message: prompt,
      maxTokens: maxTokens,
    ));

    return response.content;
  }

  @override
  Future<List<double>> embed(String text) async {
    // Claude doesn't provide embeddings directly
    // TODO: Use a dedicated embedding model
    throw UnimplementedError('Claude does not support embeddings');
  }

  @override
  Stream<String> chatStream(ChatRequest request) async* {
    final messages = request.history.map((m) => m.toJson()).toList();
    messages.add({'role': 'user', 'content': request.message});

    final body = {
      'model': model,
      'messages': messages,
      'max_tokens': request.maxTokens ?? 8192,
      'stream': true,
      if (request.temperature != null) 'temperature': request.temperature,
      if (request.systemPrompt != null) 'system': request.systemPrompt,
    };

    final requestObject = http.Request('POST', Uri.parse('$_baseUrl/messages'));
    requestObject.headers.addAll({
      'x-api-key': apiKey,
      'anthropic-version': _apiVersion,
      'content-type': 'application/json',
    });
    requestObject.body = jsonEncode(body);

    final streamedResponse = await _client.send(requestObject);

    await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
      // Parse SSE format
      for (final line in chunk.split('\n')) {
        if (line.startsWith('data: ')) {
          final data = line.substring(6);
          if (data == '[DONE]') break;

          try {
            final json = jsonDecode(data);
            if (json['type'] == 'content_block_delta') {
              yield json['delta']['text'] as String;
            }
          } catch (e) {
            // Skip invalid JSON
          }
        }
      }
    }
  }

  @override
  double estimateCost(int inputTokens, int outputTokens) {
    // Claude Sonnet 4 pricing (as of 2025)
    // Input: $3 per million tokens
    // Output: $15 per million tokens
    const inputCostPer1M = 3.0;
    const outputCostPer1M = 15.0;

    final inputCost = (inputTokens / 1000000) * inputCostPer1M;
    final outputCost = (outputTokens / 1000000) * outputCostPer1M;

    return inputCost + outputCost;
  }

  @override
  bool supports(String feature) {
    switch (feature) {
      case 'chat':
      case 'streaming':
      case 'vision':
      case 'function_calling':
        return true;
      case 'embeddings':
        return false;
      default:
        return false;
    }
  }

  Future<Map<String, dynamic>> _makeRequest(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final response = await _client.post(
      Uri.parse('$_baseUrl$endpoint'),
      headers: {
        'x-api-key': apiKey,
        'anthropic-version': _apiVersion,
        'content-type': 'application/json',
      },
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      throw Exception(
          'API request failed: ${response.statusCode} ${response.body}');
    }

    return jsonDecode(response.body);
  }

  @override
  Future<void> dispose() async {
    _client.close();
  }
}
