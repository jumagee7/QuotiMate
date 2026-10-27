// groq_service.dart — Groq AI integration for text formatting

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'app_env.dart';

class GroqService {
  static final GroqService _instance = GroqService._();
  factory GroqService() => _instance;
  GroqService._();

  static const String _apiKey = AppEnv.groqApiKey;
  static const String _baseUrl = 'https://api.groq.com/openai/v1/chat/completions';

  bool get isConfigured => AppEnv.hasGroqKey;

  Future<String> formatQuoteText(String rawText) async {
    if (!isConfigured) return rawText;
    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': 'groq/compound-mini',
          'messages': [
            {
              'role': 'system',
              'content': '''You are a data formatter for a quote/invoice application. Your task is to extract line items from unstructured text and format them in a specific way.

Extract items with: item name, quantity, unit (e.g., pcs, bundles, pkts, rolls, sq ft, etc), and unit price.

Output ONLY the formatted lines, one per line, in this exact format:
Item Name, Quantity, Unit, Price

Rules:
- If quantity is not specified, default to 1
- If unit is not specified, try to infer from context (pcs, bundles, pkts, rolls, sq ft, etc) or use "pcs"
- Price should be numeric only (no currency symbols)
- Do not include any explanations or extra text
- Handle variations like "x", "*", "qty", "quantity", "amount"'''
            },
            {
              'role': 'user',
              'content': 'Format this text:\n\n$rawText'
            }
          ],
          'temperature': 0.3,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final content = data['choices'][0]['message']['content'];
        return content?.trim() ?? rawText;
      } else {
        print('Groq API Error: ${response.statusCode} - ${response.body}');
        return rawText;
      }
    } catch (e) {
      print('Groq API Error: $e');
      return rawText;
    }
  }
}
