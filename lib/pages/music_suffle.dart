import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/database/music_database.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A page that allows users to create and play music playlists with shuffle functionality
class MusicShufflePage extends StatefulWidget {
  const MusicShufflePage({super.key});

  @override
  State<MusicShufflePage> createState() => _MusicShufflePageState();
}

class _MusicShufflePageState extends State<MusicShufflePage> {
  // List of all music items
  List<Map<String, dynamic>> _allMusicItems = [];
  // Currently selected music items for the playlist
  List<Map<String, dynamic>> _playlistItems = [];
  // Currently playing track index
  int _currentTrackIndex = -1;
  // Whether shuffle mode is active
  bool _shuffleMode = false;
  // Random number generator for shuffle
  final Random _random = Random();
  // Loading state
  bool _isLoading = true;
  // List of saved playlists
  List<Map<String, dynamic>> _savedPlaylists = [];
  // Current playlist name
  String _currentPlaylistName = 'New Playlist';
  // Text editing controller for the playlist name
  final TextEditingController _playlistNameController = TextEditingController(
    text: 'New Playlist',
  );
  // List of outside character names for vocal identification
  List<String> _outsideCharacterNames = [];

  @override
  void initState() {
    super.initState();
    _loadMusicData();
  }

  /// Load music data and saved playlists
  Future<void> _loadMusicData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all music items
      _allMusicItems = await MusicDatabase.getMusicIndex();

      // Load outside character names for vocal display
      _outsideCharacterNames = await MusicDatabase.getOutsideCharacterNames();

      // Load saved playlists
      final prefs = await SharedPreferences.getInstance();
      final savedPlaylistsJson = prefs.getString('saved_playlists') ?? '[]';
      _savedPlaylists = List<Map<String, dynamic>>.from(
        jsonDecode(
          savedPlaylistsJson,
        ).map((item) => Map<String, dynamic>.from(item)),
      );
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error loading music data: $e')));
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Save the current playlist
  Future<void> _saveCurrentPlaylist() async {
    // Check if playlist has items
    if (_playlistItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot save empty playlist')),
      );
      return;
    }

    setState(() {
      _currentPlaylistName = _playlistNameController.text;
    });

    // Create playlist object
    final playlist = {
      'name': _currentPlaylistName,
      'date': DateTime.now().toIso8601String(),
      'tracks':
          _playlistItems
              .map(
                (item) => {
                  'id': item['id'],
                  'vocalIndex': 0, // Default to first vocal
                },
              )
              .toList(),
    };

    // Check if we're updating an existing playlist
    int existingIndex = _savedPlaylists.indexWhere(
      (p) => p['name'] == _currentPlaylistName,
    );

    if (existingIndex >= 0) {
      // Update existing playlist
      _savedPlaylists[existingIndex] = playlist;
    } else {
      // Add new playlist
      _savedPlaylists.add(playlist);
    }

    // Save to shared preferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_playlists', jsonEncode(_savedPlaylists));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Playlist "$_currentPlaylistName" saved')),
    );
  }

  /// Load a saved playlist
  void _loadPlaylist(Map<String, dynamic> playlist) {
    // Extract track IDs from the playlist
    final trackIds =
        List<dynamic>.from(playlist['tracks']).map((t) => t['id']).toList();

    // Find the corresponding music items
    _playlistItems =
        _allMusicItems
            .where((music) => trackIds.contains(music['id']))
            .toList();

    // Update the current playlist name
    _currentPlaylistName = playlist['name'];
    _playlistNameController.text = _currentPlaylistName;

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Loaded playlist "${playlist['name']}"')),
    );
  }

  /// Play the current track
  void _playCurrentTrack() {
    if (_currentTrackIndex < 0 || _currentTrackIndex >= _playlistItems.length) {
      return;
    }

    final currentTrack = _playlistItems[_currentTrackIndex];

    // Get vocal data
    final vocals = jsonDecode(currentTrack['vocals'] ?? '[]');
    if (vocals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vocals available for this track')),
      );
      return;
    }

    // Use the selected vocal index if available, otherwise default to 0
    final vocalIndex = currentTrack['selectedVocalIndex'] ?? 0;

    // Ensure vocal index is valid
    if (vocalIndex >= vocals.length) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected vocal version no longer available'),
        ),
      );
      return;
    }

    final vocal = vocals[vocalIndex];
    final bundle = vocal['assetbundleName'];
    final url = '${AppGlobals.assetUrl}/music/long/$bundle/$bundle.mp3';

    // Get album art
    final assetbundleName = currentTrack['assetbundleName'] ?? '';
    final logoUrl =
        assetbundleName.isNotEmpty
            ? '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/$assetbundleName.webp'
            : '';

    // Get vocal name
    final vocalName = MusicDatabase.buildVocalName(
      context,
      vocal,
      _outsideCharacterNames,
    );

    // Play the track using the global audio handler
    AppGlobals.audioHandler.loadAudioSource(
      url: url,
      title: currentTrack['title'],
      artist: vocalName,
      artUrl: logoUrl,
      skipSeconds: currentTrack['fillerSec'] ?? 0,
    );

    AppGlobals.audioHandler.play();
  }

  /// Play the next track
  void _playNextTrack() {
    if (_playlistItems.isEmpty) return;

    setState(() {
      if (_shuffleMode) {
        // In shuffle mode, pick a random track
        _currentTrackIndex = _random.nextInt(_playlistItems.length);
      } else {
        // In sequential mode, go to the next track or loop back to the first
        _currentTrackIndex = (_currentTrackIndex + 1) % _playlistItems.length;
      }
    });

    _playCurrentTrack();
  }

  /// Play the previous track
  void _playPreviousTrack() {
    if (_playlistItems.isEmpty) return;

    setState(() {
      if (_shuffleMode) {
        // In shuffle mode, pick a random track
        _currentTrackIndex = _random.nextInt(_playlistItems.length);
      } else {
        // In sequential mode, go to the previous track or loop to the last
        _currentTrackIndex =
            (_currentTrackIndex - 1 + _playlistItems.length) %
            _playlistItems.length;
      }
    });

    _playCurrentTrack();
  }

  /// Toggle shuffle mode
  void _toggleShuffleMode() {
    setState(() {
      _shuffleMode = !_shuffleMode;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Shuffle mode ${_shuffleMode ? 'enabled' : 'disabled'}'),
      ),
    );
  }

  /// Start playing the playlist
  void _startPlaylist() {
    if (_playlistItems.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Playlist is empty')));
      return;
    }

    setState(() {
      if (_shuffleMode) {
        _currentTrackIndex = _random.nextInt(_playlistItems.length);
      } else {
        _currentTrackIndex = 0;
      }
    });

    _playCurrentTrack();
  }

  /// Show a dialog for the user to select which vocal version to add to the playlist
  void _showVocalSelectionForTrack(Map<String, dynamic> track) {
    // Parse the vocals data from JSON
    final vocals = jsonDecode(track['vocals'] ?? '[]');

    // If there's only one vocal version, add it directly
    if (vocals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No vocals available for this track')),
      );
      return;
    } else if (vocals.length == 1) {
      // If there's only one vocal, add it without showing selection
      _addTrackToPlaylistWithVocal(track, 0);
      return;
    }

    // Show bottom sheet with vocal options
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 16,
                  horizontal: 16,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Select Vocal for ${track['title']}',
                        style: Theme.of(context).textTheme.titleMedium,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.5,
                ),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: vocals.length,
                  itemBuilder: (context, index) {
                    final vocal = vocals[index];
                    final caption = vocal['caption'] as String? ?? '';
                    final name = MusicDatabase.buildVocalName(
                      context,
                      vocal,
                      _outsideCharacterNames,
                    );

                    return ListTile(
                      title: Text(caption),
                      subtitle: Text(name),
                      onTap: () {
                        Navigator.pop(context);
                        _addTrackToPlaylistWithVocal(track, index);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  /// Add a track to the playlist with the specified vocal index
  void _addTrackToPlaylistWithVocal(
    Map<String, dynamic> track,
    int vocalIndex,
  ) {
    // Check if track is already in playlist
    final existingIndex = _playlistItems.indexWhere(
      (item) =>
          item['id'] == track['id'] && item['selectedVocalIndex'] == vocalIndex,
    );

    if (existingIndex >= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'This version of ${track['title']} is already in the playlist',
          ),
        ),
      );
      return;
    }

    // Create a copy of the track with the selected vocal index
    final trackWithVocal = Map<String, dynamic>.from(track);
    trackWithVocal['selectedVocalIndex'] = vocalIndex;

    setState(() {
      _playlistItems.add(trackWithVocal);
    });

    // Get the vocal name for the confirmation message
    final vocals = jsonDecode(track['vocals'] ?? '[]');
    String vocalDescription = '';

    if (vocals.isNotEmpty && vocalIndex < vocals.length) {
      final vocal = vocals[vocalIndex];
      final caption = vocal['caption'] as String? ?? '';
      vocalDescription = ' ($caption)';
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Added ${track['title']}$vocalDescription to playlist'),
      ),
    );
  }

  /// Remove a track from the playlist
  void _removeTrackFromPlaylist(int index) {
    final removedTrack = _playlistItems[index];

    setState(() {
      _playlistItems.removeAt(index);

      // If we removed the current track, update the current index
      if (_currentTrackIndex == index) {
        if (_playlistItems.isEmpty) {
          _currentTrackIndex = -1;
        } else {
          _currentTrackIndex = _currentTrackIndex % _playlistItems.length;
        }
      } else if (_currentTrackIndex > index) {
        // If we removed a track before the current one, adjust the index
        _currentTrackIndex--;
      }
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Removed ${removedTrack['title']} from playlist')),
    );
  }

  /// Show dialog to create a new playlist
  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create New Playlist'),
          content: TextField(
            controller: _playlistNameController,
            decoration: const InputDecoration(labelText: 'Playlist Name'),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  // Clear current playlist and set new name
                  _playlistItems = [];
                  _currentPlaylistName = _playlistNameController.text;
                  _currentTrackIndex = -1;
                });
                Navigator.of(context).pop();
              },
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog to load a saved playlist
  void _showLoadPlaylistDialog() {
    if (_savedPlaylists.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No saved playlists')));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Load Playlist'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _savedPlaylists.length,
              itemBuilder: (context, index) {
                final playlist = _savedPlaylists[index];
                return ListTile(
                  title: Text(playlist['name']),
                  subtitle: Text(
                    '${(playlist['tracks'] as List).length} tracks',
                  ),
                  onTap: () {
                    _loadPlaylist(playlist);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);

    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_currentPlaylistName),
        actions: [
          // Save playlist button
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save Playlist',
            onPressed: _saveCurrentPlaylist,
          ),
          // Load playlist button
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip: 'Load Playlist',
            onPressed: _showLoadPlaylistDialog,
          ),
          // New playlist button
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip: 'New Playlist',
            onPressed: _showCreatePlaylistDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Player controls
          Card(
            margin: const EdgeInsets.all(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Current track info
                  if (_currentTrackIndex >= 0 &&
                      _currentTrackIndex < _playlistItems.length) ...[
                    Text(
                      _playlistItems[_currentTrackIndex]['title'],
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Player controls
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Previous track button
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        tooltip: 'Previous Track',
                        onPressed:
                            _playlistItems.isNotEmpty
                                ? _playPreviousTrack
                                : null,
                      ),
                      // Play button
                      IconButton(
                        icon: const Icon(Icons.play_arrow),
                        tooltip: 'Play',
                        onPressed:
                            _playlistItems.isNotEmpty ? _startPlaylist : null,
                      ),
                      // Next track button
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        tooltip: 'Next Track',
                        onPressed:
                            _playlistItems.isNotEmpty ? _playNextTrack : null,
                      ),
                      // Shuffle toggle button
                      IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color:
                              _shuffleMode
                                  ? Theme.of(context).colorScheme.primary
                                  : null,
                        ),
                        tooltip: 'Toggle Shuffle',
                        onPressed: _toggleShuffleMode,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Playlist section
          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Tab bar
                  TabBar(
                    tabs: const [Tab(text: 'Playlist'), Tab(text: 'All Music')],
                    labelColor: Theme.of(context).colorScheme.primary,
                  ),

                  // Tab content
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Current playlist
                        _playlistItems.isEmpty
                            ? Center(
                              child: Text(
                                'Playlist is empty.\nAdd songs from the All Music tab.',
                                textAlign: TextAlign.center,
                                style: Theme.of(context).textTheme.bodyLarge,
                              ),
                            )
                            : ListView.builder(
                              itemCount: _playlistItems.length,
                              itemBuilder: (context, index) {
                                final track = _playlistItems[index];
                                final assetbundleName =
                                    track['assetbundleName'] ?? '';
                                final logoUrl =
                                    assetbundleName.isNotEmpty
                                        ? '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/$assetbundleName.webp'
                                        : '';

                                return ListTile(
                                  leading:
                                      logoUrl.isNotEmpty
                                          ? ClipRRect(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            child: SizedBox(
                                              width: 50,
                                              height: 50,
                                              child: CachedNetworkImage(
                                                imageUrl: logoUrl,
                                                fit: BoxFit.cover,
                                                placeholder:
                                                    (context, url) =>
                                                        const CircularProgressIndicator(),
                                                errorWidget:
                                                    (context, url, error) =>
                                                        const Icon(Icons.error),
                                              ),
                                            ),
                                          )
                                          : const SizedBox(
                                            width: 50,
                                            height: 50,
                                          ),
                                  title: Text(
                                    track['title'] ?? 'Unknown Title',
                                  ),
                                  subtitle: Text(_getTrackSubtitle(track)),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                    onPressed:
                                        () => _removeTrackFromPlaylist(index),
                                  ),
                                  selected: index == _currentTrackIndex,
                                  onTap: () {
                                    setState(() {
                                      _currentTrackIndex = index;
                                    });
                                    _playCurrentTrack();
                                  },
                                );
                              },
                            ),

                        // All music
                        ListView.builder(
                          itemCount: _allMusicItems.length,
                          itemBuilder: (context, index) {
                            final track = _allMusicItems[index];
                            final assetbundleName =
                                track['assetbundleName'] ?? '';
                            final logoUrl =
                                assetbundleName.isNotEmpty
                                    ? '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/$assetbundleName.webp'
                                    : '';

                            return ListTile(
                              leading:
                                  logoUrl.isNotEmpty
                                      ? ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: SizedBox(
                                          width: 50,
                                          height: 50,
                                          child: CachedNetworkImage(
                                            imageUrl: logoUrl,
                                            fit: BoxFit.cover,
                                            placeholder:
                                                (context, url) =>
                                                    const CircularProgressIndicator(),
                                            errorWidget:
                                                (context, url, error) =>
                                                    const Icon(Icons.error),
                                          ),
                                        ),
                                      )
                                      : const SizedBox(width: 50, height: 50),
                              title: Text(track['title'] ?? 'Unknown Title'),
                              subtitle: Text(_getTrackSubtitle(track)),
                              trailing: IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed:
                                    () => _showVocalSelectionForTrack(track),
                              ),
                              onTap: () => _showVocalSelectionForTrack(track),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Get subtitle for a track (composer, lyricist, etc.)
  String _getTrackSubtitle(Map<String, dynamic> track) {
    final List<String> parts = [];

    if (track['composer'] != null && track['composer'].toString().isNotEmpty) {
      parts.add(track['composer'].toString());
    }

    if (track['lyricist'] != null && track['lyricist'].toString().isNotEmpty) {
      parts.add(track['lyricist'].toString());
    }

    return parts.join(' / ');
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    super.dispose();
  }
}
