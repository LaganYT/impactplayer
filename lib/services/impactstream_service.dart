import 'dart:convert';
import 'package:http/http.dart' as http;

class ImpactStreamService {
  static const String baseUrl = 'https://impactstreamapi.vercel.app/api';

  Future<List<dynamic>> search(String query) async {
    final uri = Uri.parse('$baseUrl/search?query=${Uri.encodeComponent(query)}');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data['results'] ?? [];
    } else {
      throw Exception('Failed to search ImpactStream');
    }
  }

  Future<dynamic> getDetails(String type, String id) async {
    final uri = Uri.parse('$baseUrl/$type/$id');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      return json.decode(response.body);
    } else {
      throw Exception('Failed to fetch details');
    }
  }

  Future<List<dynamic>> getStreamingLinks(String type, String id) async {
    final uri = Uri.parse('$baseUrl/stream/$type/$id');
    final response = await http.get(uri);
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      return data is List ? data : (data['links'] ?? []);
    } else {
      throw Exception('Failed to fetch streaming links');
    }
  }
} 