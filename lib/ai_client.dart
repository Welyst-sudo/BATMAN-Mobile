import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente mínimo de OpenRouter (compatible con modelos gratuitos).
class AiClient {
  final String apiKey;
  final String model;
  const AiClient(this.apiKey, this.model);

  Future<String> chat(List<Map<String, String>> messages) async {
    final response = await http
        .post(
          Uri.parse('https://openrouter.ai/api/v1/chat/completions'),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
            'X-Title': 'BATMAN Mobile',
          },
          body: jsonEncode({'model': model, 'messages': messages}),
        )
        .timeout(const Duration(seconds: 60));
    final dynamic data = jsonDecode(utf8.decode(response.bodyBytes));
    if (response.statusCode != 200) {
      var detail = 'código ${response.statusCode}';
      if (data is Map && data['error'] is Map) {
        final dynamic message = data['error']['message'];
        if (message != null) detail = message.toString();
      }
      throw Exception(detail);
    }
    final dynamic content = data['choices'][0]['message']['content'];
    final text = (content ?? '').toString().trim();
    if (text.isEmpty) throw Exception('el modelo devolvió una respuesta vacía');
    return text;
  }
}
