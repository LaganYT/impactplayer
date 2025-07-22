import 'package:flutter/material.dart';
import '../models/video_item.dart';
import '../models/playlist.dart';

class VideoQueueProvider with ChangeNotifier {
  final List<VideoItem> _queue = [];
  final List<Playlist> _playlists = [];

  List<VideoItem> get queue => List.unmodifiable(_queue);
  List<Playlist> get playlists => List.unmodifiable(_playlists);

  void addToQueue(VideoItem item) {
    _queue.add(item);
    notifyListeners();
  }

  void removeFromQueue(VideoItem item) {
    _queue.remove(item);
    notifyListeners();
  }

  void clearQueue() {
    _queue.clear();
    notifyListeners();
  }

  void addPlaylist(String name) {
    _playlists.add(Playlist(name: name, items: []));
    notifyListeners();
  }

  void removePlaylist(int index) {
    if (index >= 0 && index < _playlists.length) {
      _playlists.removeAt(index);
      notifyListeners();
    }
  }

  void addToPlaylist(int playlistIndex, VideoItem item) {
    if (playlistIndex >= 0 && playlistIndex < _playlists.length) {
      _playlists[playlistIndex].items.add(item);
      notifyListeners();
    }
  }

  void removeFromPlaylist(int playlistIndex, int videoIndex) {
    if (playlistIndex >= 0 && playlistIndex < _playlists.length) {
      _playlists[playlistIndex].removeAt(videoIndex);
      notifyListeners();
    }
  }
} 