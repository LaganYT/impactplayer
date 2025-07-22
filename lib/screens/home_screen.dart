import 'package:flutter/material.dart';
import 'library_screen.dart';
import 'online_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../providers/download_provider.dart';
import '../models/download_item.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  static final List<Widget> _screens = <Widget>[
    const LibraryScreen(),
    const OnlineScreen(),
    const SettingsScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _screens[_selectedIndex],
          const Positioned(
            left: 0,
            right: 0,
            bottom: 56, // height of BottomNavigationBar
            child: DownloadBar(),
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.video_library),
            label: 'Library',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.cloud_download),
            label: 'Online',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}

class DownloadBar extends StatelessWidget {
  const DownloadBar({super.key});

  @override
  Widget build(BuildContext context) {
    final downloads = context.watch<DownloadProvider>().downloads;
    if (downloads.isEmpty) return SizedBox.shrink();
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SizedBox(
        height: 72,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          itemCount: downloads.length,
          separatorBuilder: (_, __) => const SizedBox(width: 12),
          itemBuilder: (context, index) {
            final item = downloads[index];
            return _DownloadBarItem(item: item);
          },
        ),
      ),
    );
  }
}

class _DownloadBarItem extends StatelessWidget {
  final DownloadItem item;
  const _DownloadBarItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.colorScheme.primary, width: 1),
      ),
      child: Row(
        children: [
          Icon(
            item.isCompleted
                ? Icons.check_circle
                : item.isError
                    ? Icons.error
                    : Icons.downloading,
            color: item.isCompleted
                ? Colors.green
                : item.isError
                    ? Colors.red
                    : theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                Text(
                  item.isCompleted
                      ? 'Completed'
                      : item.isError
                          ? (item.errorMessage ?? 'Error')
                          : 'Downloading... ${(item.progress * 100).toStringAsFixed(0)}%',
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (!item.isCompleted && !item.isError)
                  Padding(
                    padding: const EdgeInsets.only(top: 2.0),
                    child: LinearProgressIndicator(
                      value: item.progress,
                      minHeight: 3,
                      backgroundColor: theme.colorScheme.surfaceVariant,
                      color: theme.colorScheme.primary,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 