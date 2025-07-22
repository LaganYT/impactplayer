import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:typed_data';
import '../services/local_service.dart';
import '../services/gallery_service.dart';
import '../providers/video_queue_provider.dart';
import 'player_screen.dart';
import 'package:photo_manager/photo_manager.dart';
import '../models/playlist.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Library'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Local'),
            Tab(text: 'Gallery'),
            Tab(text: 'Playlists'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          LocalTab(),
          GalleryTab(),
          PlaylistsTab(),
        ],
      ),
    );
  }
}

class LocalTab extends StatefulWidget {
  const LocalTab({super.key});
  @override
  State<LocalTab> createState() => _LocalTabState();
}

class _LocalTabState extends State<LocalTab> {
  String? _folderPath;
  List<FileSystemEntity> _videoFiles = [];
  bool _showDownloads = false;
  String? _permissionError;
  final LocalService _localService = LocalService();

  Future<bool> _ensureStoragePermission() async {
    final status = await Permission.storage.request();
    if (status.isGranted) {
      return true;
    } else {
      setState(() {
        _permissionError = 'Storage permission is required to access local files.';
      });
      return false;
    }
  }

  Future<void> _pickFolder() async {
    if (!await _ensureStoragePermission()) return;
    String? selectedDirectory = await FilePicker.platform.getDirectoryPath();
    if (selectedDirectory != null) {
      setState(() {
        _folderPath = selectedDirectory;
        _showDownloads = false;
        _permissionError = null;
      });
      _scanForVideos(selectedDirectory);
    }
  }

  Future<void> _scanForVideos(String folderPath) async {
    if (!await _ensureStoragePermission()) return;
    final videos = await _localService.scanForVideos(folderPath);
    setState(() {
      _videoFiles = videos;
      _permissionError = null;
    });
  }

  Future<void> _scanDownloads() async {
    if (!await _ensureStoragePermission()) return;
    final videos = await _localService.scanDownloads();
    setState(() {
      _videoFiles = videos;
      _showDownloads = true;
      _folderPath = null;
      _permissionError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              ElevatedButton.icon(
                onPressed: _pickFolder,
                icon: const Icon(Icons.folder_open),
                label: const Text('Pick Folder'),
                style: ElevatedButton.styleFrom(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                onPressed: _scanDownloads,
                icon: const Icon(Icons.download),
                label: const Text('Downloads'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _showDownloads ? theme.colorScheme.primary : null,
                  foregroundColor: _showDownloads ? Colors.white : null,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
              if (_folderPath != null)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: 16.0),
                    child: Text(
                      _folderPath!,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ),
              if (_showDownloads)
                const Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(left: 16.0),
                    child: Text('Downloads'),
                  ),
                ),
            ],
          ),
        ),
        if (_permissionError != null)
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              _permissionError!,
              style: const TextStyle(color: Colors.red),
              textAlign: TextAlign.center,
            ),
          ),
        Expanded(
          child: _videoFiles.isEmpty
              ? const Center(child: Text('No videos found.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _videoFiles.length,
                  itemBuilder: (context, index) {
                    final file = _videoFiles[index];
                    return GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlayerScreen.local(filePath: file.path),
                          ),
                        );
                      },
                      child: Card(
                        color: theme.cardColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 4,
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.videocam, size: 40),
                              Padding(
                                padding: const EdgeInsets.all(4.0),
                                child: Text(
                                  file.path.split('/').last,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class GalleryTab extends StatefulWidget {
  const GalleryTab({super.key});
  @override
  State<GalleryTab> createState() => _GalleryTabState();
}

class _GalleryTabState extends State<GalleryTab> {
  final GalleryService _galleryService = GalleryService();
  List<AssetPathEntity> _albums = [];
  AssetPathEntity? _selectedAlbum;
  List<AssetEntity> _videos = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _fetchAlbums();
  }

  Future<void> _fetchAlbums() async {
    setState(() { _loading = true; });
    final albums = await _galleryService.fetchAlbums();
    setState(() {
      _albums = albums;
      _selectedAlbum = albums.isNotEmpty ? albums[0] : null;
      _loading = false;
    });
    if (_selectedAlbum != null) {
      _fetchVideos(_selectedAlbum!);
    }
  }

  Future<void> _fetchVideos(AssetPathEntity album) async {
    setState(() { _loading = true; });
    final videos = await _galleryService.fetchVideos(album);
    setState(() {
      _videos = videos;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_albums.isEmpty) {
      return const Center(child: Text('No video albums found or permission denied.'));
    }
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<AssetPathEntity>(
            value: _selectedAlbum,
            items: _albums.map((album) {
              return DropdownMenuItem(
                value: album,
                child: Text(album.name),
              );
            }).toList(),
            onChanged: (album) {
              if (album != null) {
                setState(() { _selectedAlbum = album; });
                _fetchVideos(album);
              }
            },
          ),
        ),
        Expanded(
          child: _videos.isEmpty
              ? const Center(child: Text('No videos in this album.'))
              : GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                    childAspectRatio: 0.8,
                  ),
                  itemCount: _videos.length,
                  itemBuilder: (context, index) {
                    final video = _videos[index];
                    return FutureBuilder<Uint8List?>(
                      future: video.thumbnailDataWithSize(const ThumbnailSize(200, 200)),
                      builder: (context, snapshot) {
                        final thumb = snapshot.data;
                        return GestureDetector(
                          onTap: () async {
                            final file = await video.file;
                            if (file != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlayerScreen.local(filePath: file.path),
                                ),
                              );
                            }
                          },
                          child: Card(
                            color: theme.cardColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            child: thumb != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(16),
                                    child: Image.memory(thumb, fit: BoxFit.cover, width: double.infinity, height: double.infinity),
                                  )
                                : const Center(child: Icon(Icons.videocam, size: 40)),
                          ),
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class PlaylistsTab extends StatefulWidget {
  const PlaylistsTab({super.key});
  @override
  State<PlaylistsTab> createState() => _PlaylistsTabState();
}

class _PlaylistsTabState extends State<PlaylistsTab> {
  final TextEditingController _playlistNameController = TextEditingController();

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<VideoQueueProvider>();
    final playlists = provider.playlists;
    final theme = Theme.of(context);
    return Scaffold(
      body: playlists.isEmpty
          ? const Center(child: Text('No playlists yet.'))
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: playlists.length,
              itemBuilder: (context, index) {
                final playlist = playlists[index];
                return Card(
                  color: theme.cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  child: ListTile(
                    title: Text(playlist.name),
                    subtitle: Text('${playlist.items.length} videos'),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () {
                        provider.removePlaylist(index);
                      },
                    ),
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (context) => PlaylistDetailSheet(
                          playlist: playlist,
                          playlistIndex: index,
                        ),
                      );
                    },
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('New Playlist'),
              content: TextField(
                controller: _playlistNameController,
                decoration: const InputDecoration(hintText: 'Playlist name'),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _playlistNameController.clear();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    final name = _playlistNameController.text.trim();
                    if (name.isNotEmpty) {
                      provider.addPlaylist(name);
                    }
                    Navigator.pop(context);
                    _playlistNameController.clear();
                  },
                  child: const Text('Create'),
                ),
              ],
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

class PlaylistDetailSheet extends StatelessWidget {
  final Playlist playlist;
  final int playlistIndex;
  const PlaylistDetailSheet({super.key, required this.playlist, required this.playlistIndex});

  @override
  Widget build(BuildContext context) {
    final provider = context.read<VideoQueueProvider>();
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(playlist.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              ElevatedButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: const Text('Play All'),
                onPressed: playlist.items.isEmpty
                    ? null
                    : () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => PlayerScreen.local(filePath: playlist.items[0].path),
                          ),
                        );
                        provider.clearQueue();
                        for (final item in playlist.items) {
                          provider.addToQueue(item);
                        }
                      },
              ),
            ],
          ),
          const SizedBox(height: 12),
          playlist.items.isEmpty
              ? const Text('No videos in this playlist.')
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: playlist.items.length,
                  itemBuilder: (context, index) {
                    final item = playlist.items[index];
                    return Card(
                      color: theme.cardColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 2,
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const Icon(Icons.videocam),
                        title: Text(item.title),
                        trailing: IconButton(
                          icon: const Icon(Icons.remove_circle),
                          onPressed: () {
                            provider.removeFromPlaylist(playlistIndex, index);
                            Navigator.pop(context);
                          },
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PlayerScreen.local(filePath: item.path),
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }
} 