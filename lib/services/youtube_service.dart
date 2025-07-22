import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'dart:io';
import 'package:downloads_path_provider_28/downloads_path_provider_28.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

class YouTubeService {
  final YoutubeExplode _yt = YoutubeExplode();

  Future<Directory?> _getDownloadsDirectory() async {
    if (Platform.isAndroid) {
      try {
        return await DownloadsPathProvider.downloadsDirectory;
      } catch (e) {
        print('[YouTubeService] Error getting downloads directory: $e');
        return null;
      }
    } else {
      // iOS and others: use app documents directory
      return await getApplicationDocumentsDirectory();
    }
  }

  Future<bool> _requestStoragePermission() async {
    // Request storage permission
    final storageStatus = await Permission.storage.request();
    bool granted = storageStatus.isGranted;

    // For Android 11+ (API 30+), request manage external storage
    if (Platform.isAndroid) {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      if (androidInfo.version.sdkInt >= 30) {
        final manageStatus = await Permission.manageExternalStorage.request();
        granted = granted && manageStatus.isGranted;
      }
    }
    return granted;
  }

  Future<List<Video>> search(String query) async {
    final results = await _yt.search.search(query);
    return results.whereType<Video>().toList();
  }

  Future<Video> getVideo(String videoId) async {
    return await _yt.videos.get(videoId);
  }

  Future<String?> downloadVideo(Video video, {void Function(double progress)? onProgress}) async {
    try {
      // Request storage permission (Android)
      if (!await _requestStoragePermission()) {
        print('[YouTubeService] Storage permission denied.');
        return null;
      }
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      print('[YouTubeService] Manifest: muxed=${manifest.muxed.length}, audioOnly=${manifest.audioOnly.length}, videoOnly=${manifest.videoOnly.length}');
      if (manifest.muxed.isEmpty) {
        print('[YouTubeService] No muxed streams available.');
        return null;
      }
      final streamInfo = manifest.muxed.withHighestBitrate();
      print('[YouTubeService] streamInfo: ${streamInfo.toString()}');
      final stream = _yt.videos.streamsClient.get(streamInfo);
      final dir = await _getDownloadsDirectory();
      if (dir == null) {
        print('[YouTubeService] Could not get downloads directory.');
        return null;
      }
      final filePath = '${dir.path}/${video.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}_${video.id.value}.mp4';
      final file = File(filePath);
      final output = file.openWrite();
      int downloaded = 0;
      final total = streamInfo.size.totalBytes;
      print('[YouTubeService] Download started: total bytes = $total');
      bool enteredLoop = false;
      try {
        await for (final data in stream) {
          if (!enteredLoop) {
            print('[YouTubeService] Entered download loop.');
            enteredLoop = true;
          }
          output.add(data);
          downloaded += data.length;
          print('[YouTubeService] Downloaded: $downloaded / $total');
          if (onProgress != null && total > 0) {
            onProgress(downloaded / total);
          }
        }
      } catch (e) {
        print('[YouTubeService] Error in download loop: $e');
        rethrow;
      }
      await output.close();
      print('[YouTubeService] Download complete: $filePath');
      return filePath;
    } catch (e, stack) {
      print('[YouTubeService] Error downloading video: $e\n$stack');
      return null;
    }
  }

  Future<List<VideoStreamInfo>> getVideoQualities(Video video) async {
    final manifest = await _yt.videos.streamsClient.getManifest(video.id);
    return manifest.videoOnly.toList();
  }

  String? getFFmpegLibPath() {
    if (Platform.isMacOS) {
      // Try common Homebrew and MacPorts locations
      if (File('/opt/homebrew/lib/libffmpeg.7.dylib').existsSync()) {
        return '/opt/homebrew/lib/libffmpeg.7.dylib';
      } else if (File('/usr/local/lib/libffmpeg.7.dylib').existsSync()) {
        return '/usr/local/lib/libffmpeg.7.dylib';
      }
    } else if (Platform.isLinux) {
      if (File('/usr/lib/x86_64-linux-gnu/libavformat.so').existsSync()) {
        return '/usr/lib/x86_64-linux-gnu/libavformat.so';
      }
    } else if (Platform.isWindows) {
      // You must provide the path to your FFmpeg DLL
      return null;
    }
    // Not supported on mobile
    return null;
  }

  Future<String?> downloadAndMergeVideo(
    Video video,
    VideoStreamInfo videoStream, {
    void Function(double progress)? onProgress,
  }) async {
    try {
      if (!await _requestStoragePermission()) {
        print('[YouTubeService] Storage permission denied.');
        return null;
      }
      final manifest = await _yt.videos.streamsClient.getManifest(video.id);
      final audioStream = manifest.audioOnly.withHighestBitrate();
      final videoStreamData = _yt.videos.streamsClient.get(videoStream);
      final audioStreamData = _yt.videos.streamsClient.get(audioStream);

      final dir = await _getDownloadsDirectory();
      if (dir == null) {
        print('[YouTubeService] Could not get downloads directory.');
        return null;
      }
      final safeTitle = video.title.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final videoPath = '${dir.path}/$safeTitle-video.${videoStream.container.name}';
      final audioPath = '${dir.path}/$safeTitle-audio.${audioStream.container.name}';
      final outputPath = '${dir.path}/$safeTitle-merged.mp4';

      // Download video
      final videoFile = File(videoPath);
      final videoOutput = videoFile.openWrite();
      int videoDownloaded = 0;
      final videoTotal = videoStream.size.totalBytes;
      print('[YouTubeService] Video download started: total bytes = $videoTotal');
      await for (final data in videoStreamData) {
        videoOutput.add(data);
        videoDownloaded += data.length;
        print('[YouTubeService] Video downloaded: $videoDownloaded / $videoTotal');
        if (onProgress != null && videoTotal > 0) {
          onProgress(videoDownloaded / (videoTotal * 2)); // 0-0.5
        }
      }
      await videoOutput.close();

      // Download audio
      final audioFile = File(audioPath);
      final audioOutput = audioFile.openWrite();
      int audioDownloaded = 0;
      final audioTotal = audioStream.size.totalBytes;
      print('[YouTubeService] Audio download started: total bytes = $audioTotal');
      await for (final data in audioStreamData) {
        audioOutput.add(data);
        audioDownloaded += data.length;
        print('[YouTubeService] Audio downloaded: $audioDownloaded / $audioTotal');
        if (onProgress != null && audioTotal > 0) {
          onProgress(0.5 + (audioDownloaded / (audioTotal * 2))); // 0.5-1.0
        }
      }
      await audioOutput.close();

      // Merge video and audio using ffmpeg_kit_flutter_new
      final command = '-i "$videoPath" -i "$audioPath" -c:v copy -c:a aac -strict experimental "$outputPath"';
      final session = await FFmpegKit.execute(command);
      final returnCode = await session.getReturnCode();
      if (returnCode != null && returnCode.isValueSuccess()) {
        print('[YouTubeService] FFmpegKit merge complete: $outputPath');
        await videoFile.delete();
        await audioFile.delete();
        final location = await getDownloadLocationSetting();
        if (location == 'gallery') {
          final result = await ImageGallerySaverPlus.saveFile(outputPath, isReturnPathOfIOS: true);
          print('[YouTubeService] Saved merged video to gallery: $result');
        }
        return outputPath;
      } else {
        print('[YouTubeService] FFmpegKit failed: $returnCode');
        return null;
      }
    } catch (e, stack) {
      print('[YouTubeService] Error downloading/merging video: $e\n$stack');
      return null;
    }
  }

  Future<StreamManifest> getManifest(Video video) async {
    return await _yt.videos.streamsClient.getManifest(video.id);
  }

  void dispose() {
    _yt.close();
  }
}

Future<String> getDownloadLocationSetting() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getString('download_location') ?? 'app_folder'; // 'app_folder' or 'gallery'
}

Future<void> setDownloadLocationSetting(String location) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString('download_location', location);
}