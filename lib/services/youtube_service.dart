import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<List<Video>> search(String query) async {
    final results = await _yt.search.search(query);
    return results.whereType<Video>().toList();
  }

  Future<Video> getVideo(String videoId) async {
    return await _yt.videos.get(videoId);
  }

  Future<String?> downloadVideo(Video video) async {
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    if (manifest.muxed.isEmpty) return null;
    final streamInfo = manifest.muxed.withHighestBitrate();
    final stream = _yt.videos.streamsClient.get(streamInfo);
    final dir = await getApplicationDocumentsDirectory();
    final filePath = '${dir.path}/${video.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${video.id.value}.mp4';
    final file = File(filePath);
    final output = file.openWrite();
    await for (final data in stream) {
      output.add(data);
    }
    await output.close();
    return filePath;
  }

  void dispose() {
    _yt.close();
  }
} 