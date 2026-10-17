import 'dart:convert';
import 'package:http/http.dart' as http;

/// Cliente del servidor BATMAN que corre en tu PC (pc_server/bat_pc_server.py).
class PcClient {
  final String baseUrl;
  final String token;
  const PcClient(this.baseUrl, this.token);

  Uri _uri(String path) => Uri.parse(baseUrl.replaceAll(RegExp(r'/+$'), '') + path);
  Map<String, String> get _headers => {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};

  void _check(http.Response r) {
    if (r.statusCode == 401) throw Exception('token incorrecto');
    if (r.statusCode != 200) throw Exception('el PC respondió ${r.statusCode}');
  }

  Future<Map<String, dynamic>> status() async {
    final r = await http.get(_uri('/status'), headers: _headers).timeout(const Duration(seconds: 8));
    _check(r);
    return Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
  }

  Future<List<Map<String, dynamic>>> tasks() async {
    final r = await http.get(_uri('/tasks'), headers: _headers).timeout(const Duration(seconds: 8));
    _check(r);
    final list = jsonDecode(utf8.decode(r.bodyBytes)) as List;
    return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<String> run(String taskId) async {
    final r = await http
        .post(_uri('/run'), headers: _headers, body: jsonEncode({'task': taskId}))
        .timeout(const Duration(seconds: 130));
    _check(r);
    final data = Map<String, dynamic>.from(jsonDecode(utf8.decode(r.bodyBytes)) as Map);
    return (data['message'] ?? 'Listo.').toString();
  }
}
