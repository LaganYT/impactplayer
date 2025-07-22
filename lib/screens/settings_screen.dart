import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _downloadLocation = 'app_folder';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDownloadLocation();
  }

  Future<void> _loadDownloadLocation() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _downloadLocation = prefs.getString('download_location') ?? 'app_folder';
      _loading = false;
    });
  }

  Future<void> _setDownloadLocation(String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('download_location', value);
    setState(() {
      _downloadLocation = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.themeMode == ThemeMode.dark;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(isDark ? Icons.dark_mode : Icons.light_mode),
            title: const Text('Dark Mode'),
            trailing: Switch(
              value: isDark,
              onChanged: (val) => themeProvider.toggleTheme(),
            ),
            subtitle: Text(isDark ? 'Dark' : 'Light'),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.folder),
            title: const Text('Download Location'),
            subtitle: _loading
                ? const Text('Loading...')
                : Text(_downloadLocation == 'gallery' ? 'Gallery' : 'App Folder'),
            trailing: _loading
                ? null
                : DropdownButton<String>(
                    value: _downloadLocation,
                    items: const [
                      DropdownMenuItem(
                        value: 'app_folder',
                        child: Text('App Folder'),
                      ),
                      DropdownMenuItem(
                        value: 'gallery',
                        child: Text('Gallery'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) _setDownloadLocation(val);
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 