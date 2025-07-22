import 'package:flutter/material.dart';
import '../models/download_item.dart';

class DownloadProvider extends ChangeNotifier {
  final List<DownloadItem> _downloads = [];

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);

  void addDownload(DownloadItem item) {
    _downloads.add(item);
    notifyListeners();
  }

  void updateDownload(int index, DownloadItem item) {
    if (index >= 0 && index < _downloads.length) {
      _downloads[index] = item;
      notifyListeners();
    }
  }

  void removeDownload(int index) {
    if (index >= 0 && index < _downloads.length) {
      _downloads.removeAt(index);
      notifyListeners();
    }
  }

  void clearCompleted() {
    _downloads.removeWhere((d) => d.isCompleted || d.isError);
    notifyListeners();
  }
} 