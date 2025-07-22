import 'video_item.dart';

class Playlist {
  final String name;
  final List<VideoItem> items;
  Playlist({required this.name, required this.items});

  void removeAt(int index) {
    items.removeAt(index);
  }
} 