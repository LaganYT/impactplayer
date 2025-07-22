import 'package:flutter/material.dart';
import '../services/youtube_service.dart';
import '../services/impactstream_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'player_screen.dart';
import 'package:provider/provider.dart';
import '../providers/video_queue_provider.dart';
import 'dart:io';
import '../models/video_item.dart';

class OnlineScreen extends StatefulWidget {
  const OnlineScreen({super.key});

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  final TextEditingController _searchController = TextEditingController();
  final YouTubeService _youtubeService = YouTubeService();
  final ImpactStreamService _impactService = ImpactStreamService();

  bool _isYouTube = true;
  bool _loading = false;
  String? _error;
  List<dynamic> _results = [];

  Future<void> _search(String query) async {
    setState(() {
      _loading = true;
      _error = null;
      _results = [];
    });
    try {
      if (_isYouTube) {
        final ytResults = await _youtubeService.search(query);
        setState(() {
          _results = ytResults;
        });
      } else {
        final impactResults = await _impactService.search(query);
        setState(() {
          _results = impactResults;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _youtubeService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: _isYouTube ? 'Search YouTube' : 'Search Impact Stream',
                      border: const OutlineInputBorder(),
                      prefixIcon: const Icon(Icons.search),
                    ),
                    onSubmitted: _search,
                  ),
                ),
                const SizedBox(width: 8),
                ToggleButtons(
                  isSelected: [_isYouTube, !_isYouTube],
                  onPressed: (index) {
                    setState(() {
                      _isYouTube = index == 0;
                      _results = [];
                      _error = null;
                    });
                  },
                  children: const [
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('YouTube'),
                    ),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Impact'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text(_error!, style: const TextStyle(color: Colors.red)),
            ),
          Expanded(
            child: _results.isEmpty && !_loading
                ? const Center(child: Text('No results.'))
                : ListView.builder(
                    itemCount: _results.length,
                    itemBuilder: (context, index) {
                      if (_isYouTube) {
                        final video = _results[index] as Video;
                        return ListTile(
                          leading: Image.network(
                            video.thumbnails.standardResUrl,
                            width: 80,
                            height: 45,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => const Icon(Icons.ondemand_video),
                          ),
                          title: Text(video.title, maxLines: 2, overflow: TextOverflow.ellipsis),
                          subtitle: Text(video.author),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) {
                                return SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.play_arrow),
                                        title: const Text('Play Now'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(
                                              builder: (context) => PlayerScreen.web(
                                                streamUrl: 'https://www.youtube.com/watch?v=${video.id.value}',
                                                title: video.title,
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.download),
                                        title: const Text('Download'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          final path = await _youtubeService.downloadVideo(video);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              SnackBar(content: Text(path != null ? 'Downloaded to $path' : 'Download failed.')),
                                            );
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      } else {
                        final item = _results[index];
                        final title = item['title'] ?? item['name'] ?? 'Unknown';
                        final poster = item['poster_path'] != null
                            ? 'https://image.tmdb.org/t/p/w185${item['poster_path']}'
                            : null;
                        final type = item['media_type'] ?? 'unknown';
                        return ListTile(
                          leading: poster != null
                              ? Image.network(poster, width: 50, fit: BoxFit.cover)
                              : const Icon(Icons.movie),
                          title: Text(title),
                          subtitle: Text(type.toUpperCase()),
                          onTap: () {
                            showModalBottomSheet(
                              context: context,
                              builder: (context) {
                                return SafeArea(
                                  child: Wrap(
                                    children: [
                                      ListTile(
                                        leading: const Icon(Icons.play_arrow),
                                        title: const Text('Play Now'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => const Center(child: CircularProgressIndicator()),
                                          );
                                          try {
                                            final links = await _impactService.getStreamingLinks(type, item['id'].toString());
                                            if (context.mounted) Navigator.pop(context);
                                            if (links.isNotEmpty) {
                                              final firstLink = links[0]['embedUrl'] as String;
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => PlayerScreen.web(
                                                    streamUrl: firstLink,
                                                    title: title,
                                                  ),
                                                ),
                                              );
                                            } else {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('No streaming links found.')),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (context.mounted) Navigator.pop(context);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error: $e')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.playlist_add),
                                        title: const Text('Add to Playlist'),
                                        onTap: () {
                                          Navigator.pop(context);
                                          final provider = Provider.of<VideoQueueProvider>(context, listen: false);
                                          final playlists = provider.playlists;
                                          if (playlists.isEmpty) {
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(content: Text('No playlists available. Create one first.')),
                                            );
                                            return;
                                          }
                                          showModalBottomSheet(
                                            context: context,
                                            builder: (context) => ListView.builder(
                                              shrinkWrap: true,
                                              itemCount: playlists.length,
                                              itemBuilder: (context, idx) {
                                                return ListTile(
                                                  title: Text('Playlist ${idx + 1}'),
                                                  onTap: () {
                                                    provider.addToPlaylist(idx, VideoItem(path: 'impactstream:${item['media_type']}:${item['id']}', title: title));
                                                    Navigator.pop(context);
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Added to Playlist ${idx + 1}')),
                                                    );
                                                  },
                                                );
                                              },
                                            ),
                                          );
                                        },
                                      ),
                                      ListTile(
                                        leading: const Icon(Icons.download),
                                        title: const Text('Download'),
                                        onTap: () async {
                                          Navigator.pop(context);
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => const Center(child: CircularProgressIndicator()),
                                          );
                                          try {
                                            final links = await _impactService.getStreamingLinks(type, item['id'].toString());
                                            if (context.mounted) Navigator.pop(context);
                                            if (links.isNotEmpty) {
                                              final firstLink = links[0]['embedUrl'] as String;
                                              // Save the embed URL as a .txt file (stub for real download)
                                              final dir = Directory.systemTemp;
                                              final filePath = '${dir.path}/$title-${item['id']}.m3u8.txt';
                                              final file = File(filePath);
                                              await file.writeAsString(firstLink);
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(content: Text('Download link saved: $filePath')),
                                                );
                                              }
                                            } else {
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('No streaming links found.')),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (context.mounted) Navigator.pop(context);
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(content: Text('Error: $e')),
                                              );
                                            }
                                          }
                                        },
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      }
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 