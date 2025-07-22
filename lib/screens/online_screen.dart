import 'package:flutter/material.dart';
import '../services/youtube_service.dart';
import '../services/impactstream_service.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';
import 'player_screen.dart';
import 'package:provider/provider.dart';
import '../providers/video_queue_provider.dart';
import 'dart:io';
import '../models/video_item.dart';
import '../providers/download_provider.dart';
import '../models/download_item.dart';

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
    final rootContext = context; // This context will remain valid
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
                                            rootContext,
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
                                          final downloadProvider = Provider.of<DownloadProvider>(rootContext, listen: false);
                                          final downloadItem = DownloadItem(
                                            title: video.title,
                                            source: 'YouTube',
                                            progress: 0.0,
                                            isCompleted: false,
                                            isError: false,
                                          );
                                          downloadProvider.addDownload(downloadItem);
                                          final downloadIndex = downloadProvider.downloads.length - 1;
                                          // Try muxed download first
                                          final manifest = await _youtubeService.getManifest(video);
                                          if (manifest.muxed.isNotEmpty) {
                                            final path = await _youtubeService.downloadVideo(
                                              video,
                                              onProgress: (progress) {
                                                downloadProvider.updateDownload(
                                                  downloadIndex,
                                                  downloadProvider.downloads[downloadIndex].copyWith(progress: progress),
                                                );
                                              },
                                            );
                                            if (rootContext.mounted) {
                                              if (path != null) {
                                                downloadProvider.updateDownload(
                                                  downloadIndex,
                                                  downloadProvider.downloads[downloadIndex].copyWith(
                                                    filePath: path,
                                                    progress: 1.0,
                                                    isCompleted: true,
                                                  ),
                                                );
                                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                                  SnackBar(content: Text('Downloaded to $path')),
                                                );
                                              } else {
                                                downloadProvider.updateDownload(
                                                  downloadIndex,
                                                  downloadProvider.downloads[downloadIndex].copyWith(
                                                    isError: true,
                                                    errorMessage: 'Download failed.',
                                                  ),
                                                );
                                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                                  const SnackBar(content: Text('Download failed.')),
                                                );
                                              }
                                            }
                                          } else {
                                            // No muxed, prompt for video quality
                                            final qualities = await _youtubeService.getVideoQualities(video);
                                            if (qualities.isEmpty) {
                                              if (rootContext.mounted) {
                                                downloadProvider.updateDownload(
                                                  downloadIndex,
                                                  downloadProvider.downloads[downloadIndex].copyWith(
                                                    isError: true,
                                                    errorMessage: 'No downloadable video streams.',
                                                  ),
                                                );
                                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                                  const SnackBar(content: Text('No downloadable video streams.')),
                                                );
                                              }
                                              return;
                                            }
                                            final selected = await showDialog<VideoStreamInfo>(
                                              context: rootContext,
                                              builder: (context) => SimpleDialog(
                                                title: const Text('Select Video Quality'),
                                                children: qualities.map((q) => SimpleDialogOption(
                                                  onPressed: () => Navigator.pop(context, q),
                                                  child: Text('${q.qualityLabel} (${(q.size.totalMegaBytes).toStringAsFixed(2)} MB)'),
                                                )).toList(),
                                              ),
                                            );
                                            if (selected == null) {
                                              // User cancelled
                                              downloadProvider.updateDownload(
                                                downloadIndex,
                                                downloadProvider.downloads[downloadIndex].copyWith(
                                                  isError: true,
                                                  errorMessage: 'Download cancelled.',
                                                ),
                                              );
                                              return;
                                            }
                                            final path = await _youtubeService.downloadAndMergeVideo(
                                              video,
                                              selected,
                                              onProgress: (progress) {
                                                downloadProvider.updateDownload(
                                                  downloadIndex,
                                                  downloadProvider.downloads[downloadIndex].copyWith(progress: progress),
                                                );
                                              },
                                            );
                                            if (rootContext.mounted) {
                                              if (path != null) {
                                                downloadProvider.updateDownload(
                                                  downloadIndex,
                                                  downloadProvider.downloads[downloadIndex].copyWith(
                                                    filePath: path,
                                                    progress: 1.0,
                                                    isCompleted: true,
                                                  ),
                                                );
                                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                                  SnackBar(content: Text('Downloaded to $path')),
                                                );
                                              } else {
                                                downloadProvider.updateDownload(
                                                  downloadIndex,
                                                  downloadProvider.downloads[downloadIndex].copyWith(
                                                    isError: true,
                                                    errorMessage: 'Download failed.',
                                                  ),
                                                );
                                                ScaffoldMessenger.of(rootContext).showSnackBar(
                                                  const SnackBar(content: Text('Download failed.')),
                                                );
                                              }
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
                                            print('[ImpactStream] Fetching streaming links for type: $type, id: ${item['id']}');
                                            final links = await _impactService.getStreamingLinks(type, item['id'].toString());
                                            print('[ImpactStream] Links returned: ' + links.toString());
                                            if (context.mounted) Navigator.pop(context);
                                            if (links.isNotEmpty) {
                                              var allowedUrls = links
                                                  .map<String?>((l) => l['embedUrl'] as String?)
                                                  .where((u) => u != null && (u.startsWith('http://') || u.startsWith('https://')) && u.trim().isNotEmpty)
                                                  .cast<String>()
                                                  .toList();
                                              // Add vidsrc.net variant if any vidsrc.* domain is present
                                              final netVariants = allowedUrls
                                                .where((url) => url.contains('vidsrc.') && !url.contains('vidsrc.net'))
                                                .map((url) {
                                                  // Replace any vidsrc.<tld> with vidsrc.net
                                                  final netUrl = url.replaceFirst(RegExp(r'vidsrc\.[^/]+'), 'vidsrc.net');
                                                  return (netUrl.startsWith('http://') || netUrl.startsWith('https://')) ? netUrl : null;
                                                })
                                                .where((url) => url != null && !allowedUrls.contains(url))
                                                .cast<String>()
                                                .toList();
                                              allowedUrls.addAll(netVariants);
                                              // Always allow cloudnestra.com
                                              if (!allowedUrls.contains('cloudnestra.com')) {
                                                allowedUrls.add('https://cloudnestra.com');
                                              }
                                              // Always allow cloudnestra.com
                                              if (!allowedUrls.contains('cloudnestra.com')) {
                                                allowedUrls.add('http://cloudnestra.com');
                                              }
                                              final firstLink = allowedUrls.isNotEmpty ? allowedUrls.first : null;
                                              print('[ImpactStream] Final allowedUrls: $allowedUrls');
                                              print('[ImpactStream] Chosen firstLink: $firstLink');
                                              if (firstLink != null) {
                                                try {
                                                  print('[ImpactStream] About to push PlayerScreen.web with firstLink: $firstLink and allowedUrls: $allowedUrls');
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(
                                                      builder: (context) => PlayerScreen.web(
                                                        streamUrl: firstLink,
                                                        title: title,
                                                        allowedUrls: allowedUrls,
                                                      ),
                                                    ),
                                                  );
                                                  print('[ImpactStream] Successfully pushed PlayerScreen.web');
                                                } catch (navErr) {
                                                  print('[ImpactStream] Error during navigation to PlayerScreen.web: $navErr');
                                                  if (context.mounted) {
                                                    ScaffoldMessenger.of(context).showSnackBar(
                                                      SnackBar(content: Text('Navigation error: $navErr')),
                                                    );
                                                  }
                                                }
                                              } else {
                                                print('[ImpactStream] No valid streaming link found after filtering.');
                                                if (context.mounted) {
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Invalid or unavailable streaming link.')),
                                                  );
                                                }
                                              }
                                            } else {
                                              print('[ImpactStream] No streaming links found.');
                                              if (context.mounted) {
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('No streaming links found.')),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            print('[ImpactStream] Error fetching streaming links: $e');
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
                                          final downloadProvider = Provider.of<DownloadProvider>(context, listen: false);
                                          // Add a DownloadItem for Impact Stream
                                          final downloadItem = DownloadItem(
                                            title: title,
                                            source: 'Impact Stream',
                                            progress: 0.0,
                                            isCompleted: false,
                                            isError: false,
                                          );
                                          downloadProvider.addDownload(downloadItem);
                                          final downloadIndex = downloadProvider.downloads.length - 1;
                                          showDialog(
                                            context: context,
                                            barrierDismissible: false,
                                            builder: (context) => const Center(child: CircularProgressIndicator()),
                                          );
                                          try {
                                            final links = await _impactService.getStreamingLinks(type, item['id'].toString());
                                            if (context.mounted) Navigator.pop(context);
                                            if (links.isNotEmpty) {
                                              // Try to find a direct mp4 or m3u8 link
                                              String? directUrl;
                                              for (final link in links) {
                                                final url = link['embedUrl'] as String?;
                                                if (url != null && (url.endsWith('.mp4') || url.endsWith('.m3u8'))) {
                                                  directUrl = url;
                                                  break;
                                                }
                                              }
                                              String? filePath;
                                              if (directUrl != null) {
                                                filePath = await _impactService.downloadDirectVideo(directUrl, title);
                                              } else {
                                                // Fallback: save the first embed URL as a .txt file
                                                final firstLink = links[0]['embedUrl'] as String?;
                                                if (firstLink != null) {
                                                  final dir = Directory.systemTemp;
                                                  final filePathTxt = '${dir.path}/$title-${item['id']}.m3u8.txt';
                                                  final file = File(filePathTxt);
                                                  await file.writeAsString(firstLink);
                                                  filePath = filePathTxt;
                                                }
                                              }
                                              if (context.mounted) {
                                                if (filePath != null) {
                                                  downloadProvider.updateDownload(
                                                    downloadIndex,
                                                    downloadProvider.downloads[downloadIndex].copyWith(
                                                      filePath: filePath,
                                                      progress: 1.0,
                                                      isCompleted: true,
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    SnackBar(content: Text('Downloaded to $filePath')),
                                                  );
                                                } else {
                                                  downloadProvider.updateDownload(
                                                    downloadIndex,
                                                    downloadProvider.downloads[downloadIndex].copyWith(
                                                      isError: true,
                                                      errorMessage: 'Download failed.',
                                                    ),
                                                  );
                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                    const SnackBar(content: Text('Download failed.')),
                                                  );
                                                }
                                              }
                                            } else {
                                              if (context.mounted) {
                                                downloadProvider.updateDownload(
                                                  downloadIndex,
                                                  downloadProvider.downloads[downloadIndex].copyWith(
                                                    isError: true,
                                                    errorMessage: 'No streaming links found.',
                                                  ),
                                                );
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  const SnackBar(content: Text('No streaming links found.')),
                                                );
                                              }
                                            }
                                          } catch (e) {
                                            if (context.mounted) Navigator.pop(context);
                                            if (context.mounted) {
                                              downloadProvider.updateDownload(
                                                downloadIndex,
                                                downloadProvider.downloads[downloadIndex].copyWith(
                                                  isError: true,
                                                  errorMessage: 'Error: $e',
                                                ),
                                              );
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