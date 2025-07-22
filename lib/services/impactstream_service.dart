import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

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

  Future<String?> downloadDirectVideo(String url, String title, {String? extension}) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        final dir = await getApplicationDocumentsDirectory();
        final safeTitle = title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
        final ext = extension ?? (url.contains('.mp4') ? 'mp4' : url.contains('.m3u8') ? 'm3u8' : 'mp4');
        final filePath = '${dir.path}/$safeTitle.${ext}';
        final file = File(filePath);
        await file.writeAsBytes(response.bodyBytes);
        return filePath;
      } else {
        print('[ImpactStreamService] Failed to download video: HTTP ${response.statusCode}');
        return null;
      }
    } catch (e, stack) {
      print('[ImpactStreamService] Error downloading video: $e\n$stack');
      return null;
    }
  }
} 