import 'dart:io';
import 'package:path_provider/path_provider.dart';

class LocalService {
  static const videoExtensions = [
    '.mp4', '.mkv', '.mov', '.avi', '.webm', '.flv', '.wmv', '.m4v'
  ];

  Future<List<FileSystemEntity>> scanForVideos(String folderPath) async {
    final dir = Directory(folderPath);
    final files = await dir.list().toList();
    return files.where((f) {
      final ext = f.path.toLowerCase();
      return videoExtensions.any((e) => ext.endsWith(e));
    }).toList();
  }

  Future<List<FileSystemEntity>> scanDownloads() async {
    final dir = await getApplicationDocumentsDirectory();
    return scanForVideos(dir.path);
  }
} 