import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/pages/event_detail.dart';
import 'package:pjsk_viewer/pages/index.dart';
import 'package:pjsk_viewer/pages/music_detail.dart';
import 'package:pjsk_viewer/utils/audio_player.dart';
import 'package:pjsk_viewer/utils/cache_manager.dart';
import 'package:pjsk_viewer/utils/database/music_database.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:pjsk_viewer/utils/lazy_load.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A page that allows users to create and play music playlists with shuffle functionality
class MusicShufflePage extends StatefulWidget {
  const MusicShufflePage({super.key});

  @override
  State<MusicShufflePage> createState() => _MusicShufflePageState();
}

class _MusicShufflePageState extends State<MusicShufflePage> {
  List<Map<String, dynamic>> _allMusicItems = [];
  List<Map<String, dynamic>> _playlistItems = [];
  List<int> _playedTrackIndices = List.generate(2000, (i) => i);

  bool _shuffleMode = false;
  bool _isLoading = true;

  final Random _random = Random();

  List<Map<String, dynamic>> _savedPlaylists = [];
  String _currentPlaylistName =
      AppGlobals.i18n
          .translate('app', 'music_shuffle_defaultPlaylist')
          .translated;
  final TextEditingController _playlistNameController = TextEditingController(
    text: '',
  );
  List<String> _outsideCharacterNames = [];

  // Lazy loading
  final ScrollController _scrollController = ScrollController();
  late LazyLoadUtility<Map<String, dynamic>> _lazyLoad;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  // Filter
  List<FilterConfig<Map<String, dynamic>>> _filters = [];
  List<Map<String, String>> _characterOptions = [];
  List<Map<String, String>> _lyricistOptions = [];
  List<Map<String, String>> _composerOptions = [];
  List<Map<String, String>> _arrangerOptions = [];
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Initialize the LazyLoadUtility with empty lists
    _lazyLoad = LazyLoadUtility<Map<String, dynamic>>(
      pageSize: 20,
      scrollController: _scrollController,
      allItems: [],
      filteredItems: [],
      onLoadMoreStarted: () => setState(() {}),
      onLoadMoreFinished: () => setState(() {}),
    );
    _loadMusicData();
  }

  @override
  void dispose() {
    _playlistNameController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _scrollController.dispose();
    _lazyLoad.dispose();
    super.dispose();
  }

  /// State Management ----------------------------------------
  Future<void> _saveEphemeralState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'music_shuffle_state',
      json.encode({
        'shuffleMode': _shuffleMode,
        'currentPlaylistName': _currentPlaylistName,
        'playedTrackIndices': _playedTrackIndices,
        'playlist': _playlistItems,
      }),
    );
  }

  Future<void> _loadEphemeralState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateJson = prefs.getString('music_shuffle_state');
    if (stateJson != null) {
      try {
        final state = json.decode(stateJson);
        setState(() {
          _shuffleMode = state['shuffleMode'] ?? false;
          _currentPlaylistName =
              state['currentPlaylistName'] ??
              AppGlobals.i18n
                  .translate('app', 'music_shuffle_defaultPlaylist')
                  .translated;
          _playedTrackIndices = List<int>.from(
            state['playedTrackIndices'] ?? List.generate(2000, (i) => i),
          );
          _playlistItems = List<Map<String, dynamic>>.from(
            state['playlist'] ?? [],
          );
        });
      } catch (_) {}
    }
  }

  /// Music Data Loading ---------------------------------

  /// Load music data and saved playlists
  Future<void> _loadMusicData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load all music items
      _allMusicItems = await MusicDatabase.getMusicIndex();

      // Initialize the LazyLoadUtility with the loaded items
      final sortedItems = List<Map<String, dynamic>>.from(_allMusicItems)
        ..sort((a, b) {
          final aTitle = a['title'] as String? ?? '';
          final bTitle = b['title'] as String? ?? '';
          return aTitle.compareTo(bTitle);
        });

      _lazyLoad = LazyLoadUtility<Map<String, dynamic>>(
        pageSize: 20,
        scrollController: _scrollController,
        allItems: sortedItems,
        filteredItems: sortedItems,
        onLoadMoreStarted: () => setState(() {}),
        onLoadMoreFinished: () => setState(() {}),
      );

      // Load outside character names for vocal display
      _outsideCharacterNames = await MusicDatabase.getOutsideCharacterNames();

      // Load character options for filtering
      final gameCharacterOptions = List.generate(26, (i) {
        final id = i + 1;
        final idStr = id.toString();
        final first =
            AppGlobals.i18n
                .translate('character_name', idStr, innerKey: 'firstName')
                .translated;
        final last =
            AppGlobals.i18n
                .translate('character_name', idStr, innerKey: 'givenName')
                .translated;
        return {
          'display': '$first $last'.trim(),
          'value': 'game_character:$id',
        };
      });

      final outsideCharacterOptions =
          _outsideCharacterNames
              .asMap()
              .entries
              .where((entry) => entry.value.isNotEmpty)
              .map(
                (entry) => {
                  'display': entry.value,
                  'value': 'outside_character:${entry.key + 1}',
                },
              )
              .toList()
              .cast<Map<String, String>>();

      _characterOptions = [...gameCharacterOptions, ...outsideCharacterOptions];

      // Load contributor options
      final futures = [
        _getContributorOptions('lyricist'),
        _getContributorOptions('composer'),
        _getContributorOptions('arranger'),
      ];
      final resultsLists = await Future.wait(futures);
      _lyricistOptions = resultsLists[0];
      _composerOptions = resultsLists[1];
      _arrangerOptions = resultsLists[2];

      // Set up filters
      _setupFilters();
      applyFilters();
      // Load saved playlists
      final prefs = await SharedPreferences.getInstance();
      final savedPlaylistsJson = prefs.getString('saved_playlists') ?? '[]';
      _savedPlaylists = List<Map<String, dynamic>>.from(
        json
            .decode(savedPlaylistsJson)
            .map((item) => Map<String, dynamic>.from(item)),
      );
      // load ephemeral state
      await _loadEphemeralState();
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${AppGlobals.i18n.translate('app', 'music_shuffle_errorLoadingMusicData').translated}: $e',
          ),
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  /// Set up filters based on loaded data
  void _setupFilters() {
    final localizations = ContentLocalizations.of(context);
    FilterOptions filterOptions = FilterOptions(context);

    _filters = [
      FilterConfig<Map<String, dynamic>>(
        header:
            localizations
                ?.translate('filter', 'music_tag', innerKey: 'caption')
                .translated ??
            "Song tag",
        options: filterOptions.songTags,
        filterFunc: (music, selected) {
          final tagList = jsonDecode(music['tags'] ?? '[]');
          for (final tag in tagList) {
            if (selected.contains(tag['musicTag'])) return true;
          }
          return false;
        },
      ),
      FilterConfig<Map<String, dynamic>>(
        header:
            localizations?.translate('common', 'character').translated ??
            'Character',
        options: _characterOptions,
        isDropdown: true,
        filterFunc: (music, selected) {
          final vocals = jsonDecode(music['vocals'] ?? '[]');
          for (final vocal in vocals) {
            final characters = vocal['characters'];

            for (final character in characters) {
              final key =
                  '${character['characterType']}:${character['characterId']}';
              if (selected.contains(key)) return true;
            }
          }
          return false;
        },
      ),
      FilterConfig<Map<String, dynamic>>(
        header:
            localizations?.translate('music', 'composer').translated ??
            "Composer",
        options: _composerOptions,
        isDropdown: true,
        filterFunc: (music, selected) {
          if (selected.contains('composer:${music['composer']}')) {
            return true;
          }
          return false;
        },
      ),
      FilterConfig<Map<String, dynamic>>(
        header:
            localizations?.translate('music', 'arranger').translated ??
            "Arranger",
        options: _arrangerOptions,
        isDropdown: true,
        filterFunc: (music, selected) {
          if (selected.contains('arranger:${music['arranger']}')) {
            return true;
          }
          return false;
        },
      ),
      FilterConfig<Map<String, dynamic>>(
        header:
            localizations?.translate('music', 'lyricist').translated ??
            "Lyricist",
        options: _lyricistOptions,
        isDropdown: true,
        filterFunc: (music, selected) {
          if (selected.contains('lyricist:${music['lyricist']}')) {
            return true;
          }
          return false;
        },
      ),
    ];
  }

  /// Apply filters to the music list
  void applyFilters() {
    // Start from full list
    var filtered =
        _allMusicItems.where((item) {
          // Apply search filter
          if (_searchQuery.isNotEmpty &&
              !(item['title'] as String).toLowerCase().contains(
                _searchQuery.toLowerCase(),
              )) {
            return false;
          }

          // Apply each filter
          for (var filter in _filters) {
            if (filter.selectedValues.isNotEmpty &&
                !filter.filterFunc(item, filter.selectedValues)) {
              return false;
            }
          }
          return true;
        }).toList();
    developer.log(
      'Filtered items: ${filtered.length}',
      name: 'MusicShufflePage',
    );
    setState(() {
      _lazyLoad.updateFilteredItems(filtered);
      // Scroll back to top
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(0);
      }
    });
  }

  /// PlayList ------------------------------------------------------

  /// Start playing the playlist
  Future<void> _startPlaylist({int? startIndex}) async {
    if (_playlistItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppGlobals.i18n
                .translate('app', 'music_shuffle_playlistEmpty')
                .translated,
          ),
        ),
      );
      return;
    }

    // Create list of indices (0, 1, 2, ...) representing original track order
    List<int> originalIndices = List.generate(_playlistItems.length, (i) => i);

    // Clear the played track indices map
    _playedTrackIndices = [];

    // If shuffle mode is on, shuffle the order of indices
    if (_shuffleMode) {
      // Shuffle the indices, not the actual playlist items
      originalIndices.shuffle(_random);

      // Build the mapping from play order to original indices
      _playedTrackIndices = List.from(originalIndices);
    } else {
      _playedTrackIndices = originalIndices;
    }

    List<MediaItem> mediaItems = [];
    for (int i = 0; i < _playedTrackIndices.length; i++) {
      // Get the original index for this position in the shuffled order
      final originalIndex = _playedTrackIndices[i];

      final Map<String, dynamic> item = _playlistItems[originalIndex];
      final int vocalIndex = item['selectedVocalIndex'] ?? 0;
      final mediaItem = buildMediaItemFromTrack(
        track: item,
        vocalIndex: vocalIndex,
        context: context,
      );
      mediaItems.add(mediaItem);
    }
    // Update the audio handler with the new queue
    await AppGlobals.audioHandler.updateQueue(mediaItems);

    final playIndex =
        startIndex == null ? 0 : _playedTrackIndices.indexOf(startIndex);

    // Start playback from the selected index
    await AppGlobals.audioHandler.skipToQueueItem(playIndex);
    await _saveEphemeralState();
  }

  /// Save the current playlist
  Future<void> _saveCurrentPlaylist() async {
    // Check if playlist has items
    if (_playlistItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppGlobals.i18n
                .translate('app', 'music_shuffle_cannotSaveEmptyPlaylist')
                .translated,
          ),
        ),
      );
      return;
    }

    // Create playlist object
    final playlist = {
      'name': _currentPlaylistName,
      'date': DateTime.now().toIso8601String(),
      'tracks':
          _playlistItems
              .map(
                (item) => {
                  'id': item['id'],
                  'vocalIndex': item['selectedVocalIndex'] ?? 0,
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
    await prefs.setString('saved_playlists', json.encode(_savedPlaylists));

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppGlobals.i18n
              .translate('app', 'music_shuffle_playlistSaved')
              .translated
              .replaceAll('%s', _currentPlaylistName),
        ),
      ),
    );
  }

  /// Load a saved playlist
  void _loadPlaylist(Map<String, dynamic> playlist) {
    developer.log(
      'Loading playlist: ${playlist.toString()}',
      name: 'MusicShufflePage',
    );
    // Extract track IDs from the playlist
    final trackIds =
        List<dynamic>.from(playlist['tracks']).map((t) => t['id']).toList();
    final vocalIndices =
        List<dynamic>.from(
          playlist['tracks'],
        ).map((t) => t['vocalIndex']).toList();
    // Find the corresponding music items
    // Find corresponding music items and set the vocal indices
    _playlistItems = [];
    for (int i = 0; i < trackIds.length; i++) {
      final trackId = trackIds[i];
      final vocalIndex = vocalIndices[i];

      // Find the music item with matching ID
      final musicItem = _allMusicItems.firstWhere(
        (music) => music['id'] == trackId,
        orElse: () => {},
      );

      if (musicItem.isNotEmpty) {
        // Create a copy with the selected vocal index
        final trackWithVocal = Map<String, dynamic>.from(musicItem);
        trackWithVocal['selectedVocalIndex'] = vocalIndex;
        _playlistItems.add(trackWithVocal);
      }
    }

    // Update the current playlist name
    _currentPlaylistName = playlist['name'];
    _saveEphemeralState();
    setState(() {});
  }

  /// Show a dialog for the user to select which vocal version to add to the playlist
  void _showVocalSelectionForTrack(Map<String, dynamic> track) {
    // Parse the vocals data from JSON
    final vocals = jsonDecode(track['vocals'] ?? '[]');

    // If there's only one vocal version, add it directly
    if (vocals.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppGlobals.i18n
                .translate('app', 'music_shuffle_noVocalsAvailable')
                .translated,
          ),
        ),
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
                        AppGlobals.i18n
                            .translate(
                              'app',
                              'music_shuffle_selectVocalForTrack',
                            )
                            .translated
                            .replaceAll('%s', track['title']),
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
            AppGlobals.i18n
                .translate('app', 'music_shuffle_trackVersionAlreadyInPlaylist')
                .translated
                .replaceAll('%s', track['title']),
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
    _saveEphemeralState();

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
        content: Text(
          AppGlobals.i18n
              .translate('app', 'music_shuffle_addedTrackToPlaylist')
              .translated
              .replaceAll('%s1', track['title'])
              .replaceAll('%s2', vocalDescription),
        ),
      ),
    );
  }

  /// Remove a track from the playlist
  void _removeTrackFromPlaylist(int index) {
    final removedTrack = _playlistItems[index];
    setState(() {
      _playlistItems.removeAt(index);
    });
    _saveEphemeralState();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          AppGlobals.i18n
              .translate('app', 'music_shuffle_removedTrackFromPlaylist')
              .translated
              .replaceAll('%s', removedTrack['title']),
        ),
      ),
    );
  }

  /// Show dialog to create a new playlist
  void _showCreatePlaylistDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            AppGlobals.i18n
                .translate('app', 'music_shuffle_createNewPlaylist')
                .translated,
          ),
          content: TextField(
            controller: _playlistNameController,
            decoration: InputDecoration(
              labelText:
                  AppGlobals.i18n
                      .translate('app', 'music_shuffle_playlistName')
                      .translated,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppGlobals.i18n
                    .translate('app', 'music_shuffle_cancel')
                    .translated,
              ),
            ),
            TextButton(
              onPressed: () {
                // Check empty playlist name
                if (_playlistNameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppGlobals.i18n
                            .translate(
                              'app',
                              'music_shuffle_playlistNameCannotBeEmpty',
                            )
                            .translated,
                      ),
                    ),
                  );
                  return;
                }
                // Check if a playlist with this name already exists
                final existingPlaylist =
                    _savedPlaylists
                        .where(
                          (p) =>
                              p['name'] == _playlistNameController.text.trim(),
                        )
                        .toList();

                if (existingPlaylist.isNotEmpty) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        AppGlobals.i18n
                            .translate(
                              'app',
                              'music_shuffle_playlistNameExists',
                            )
                            .translated,
                      ),
                    ),
                  );
                  return;
                }

                // Proceed with creating the playlist
                setState(() {
                  // Clear current playlist and set new name
                  _playlistItems = [];
                  _currentPlaylistName = _playlistNameController.text;
                  _playlistNameController.clear();
                });
                Navigator.of(context).pop();
              },
              child: Text(
                AppGlobals.i18n
                    .translate('app', 'music_shuffle_create')
                    .translated,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Show dialog to load a saved playlist
  void _showLoadPlaylistDialog() {
    if (_savedPlaylists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppGlobals.i18n
                .translate('app', 'music_shuffle_noSavedPlaylists')
                .translated,
          ),
        ),
      );
      return;
    }
    final screenHeight = MediaQuery.of(context).size.height;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            AppGlobals.i18n
                .translate('app', 'music_shuffle_loadPlaylist')
                .translated,
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: screenHeight * 0.5,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _savedPlaylists.length,
              itemBuilder: (context, index) {
                final playlist = _savedPlaylists[index];
                return Column(
                  children: [
                    ListTile(
                      dense: true,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                      ),
                      title: Text(
                        playlist['name'],
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      subtitle: Text(
                        AppGlobals.i18n
                            .translate('app', 'music_shuffle_numTracks')
                            .translated
                            .replaceAll(
                              '%s',
                              (playlist['tracks'] as List).length.toString(),
                            ),
                      ),
                      onTap: () {
                        _loadPlaylist(playlist);
                        _saveEphemeralState();
                        Navigator.of(context).pop();
                      },
                    ),
                    const Divider(),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                AppGlobals.i18n
                    .translate('app', 'music_shuffle_cancel')
                    .translated,
              ),
            ),
          ],
        );
      },
    );
  }

  /// Add all currently filtered tracks to the playlist, preferring Sekai versions
  void _addAllFilteredTracksToPlaylist({
    String vocalType = 'sekai',
    String vocalType2 = 'placeholder',
  }) {
    // Get the current filtered tracks
    final filteredTracks = _lazyLoad.filteredItems;

    if (filteredTracks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppGlobals.i18n
                .translate('app', 'music_shuffle_noTracksFoundToAdd')
                .translated,
          ),
        ),
      );
      return;
    }

    int addedCount = 0;

    // Add each track to the playlist
    for (final track in filteredTracks) {
      // Parse vocals data
      final vocals = json.decode(track['vocals'] ?? '[]');
      if (vocals.isEmpty) {
        continue;
      }
      // Try to find the Sekai version (game original version)
      for (int i = 0; i < vocals.length; i++) {
        final vocal = vocals[i];
        final musicVocalType = vocal['musicVocalType'] as String? ?? '';

        // Check if this is a Sekai version
        if (musicVocalType != vocalType && musicVocalType != vocalType2) {
          continue;
        }
        developer.log('Vocal Type: $musicVocalType, $vocalType, $vocalType2');
        // Check if this track+vocal is already in the playlist
        final existingIndex = _playlistItems.indexWhere(
          (item) =>
              item['id'] == track['id'] && item['selectedVocalIndex'] == i,
        );

        // Only add if not already in playlist
        if (existingIndex < 0) {
          final trackWithVocal = Map<String, dynamic>.from(track);
          trackWithVocal['selectedVocalIndex'] = i;

          setState(() {
            _playlistItems.add(trackWithVocal);
          });

          addedCount++;
        }
      }
    }

    // Show confirmation
    if (addedCount > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppGlobals.i18n
                .translate('app', 'music_shuffle_addedNTracksToPlaylist')
                .translated
                .replaceAll('%s', addedCount.toString()),
          ),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppGlobals.i18n
                .translate('app', 'music_shuffle_noNewTracksAdded')
                .translated,
          ),
        ),
      );
    }
  }

  /// Audio Player Control --------------------------------

  Stream<PlayerState> getPlayerStateStream() {
    return AppGlobals.audioHandler.playerStateStream;
  }

  void onPlay() async {
    if (AppGlobals.audioHandler.currentTrackTitleNotifier.value.isEmpty) {
      await _startPlaylist();
    }
    AppGlobals.audioHandler.play();
  }

  void onPause() {
    AppGlobals.audioHandler.pause();
  }

  void onReplay() {
    AppGlobals.audioHandler.seek(Duration.zero);
  }

  void onPrevious() async {
    await AppGlobals.audioHandler.skipToPrevious();
  }

  void onNext() async {
    await AppGlobals.audioHandler.skipToNext();
  }

  /// Toggle shuffle mode
  void _toggleShuffleMode() {
    setState(() {
      _shuffleMode = !_shuffleMode;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _shuffleMode
              ? AppGlobals.i18n
                  .translate('app', 'music_shuffle_shuffleEnabled')
                  .translated
              : AppGlobals.i18n
                  .translate('app', 'music_shuffle_shuffleDisabled')
                  .translated,
        ),
      ),
    );
    _startPlaylist(
      startIndex:
          _playedTrackIndices[AppGlobals.audioHandler.currentTrackIndex],
    );
  }

  /// Page Building ------------------------------------------------

  Widget buildPlayList() {
    return Column(
      children: [
        // Playlist section
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Track count information
              Text(
                AppGlobals.i18n
                    .translate('app', 'music_shuffle_numTracks')
                    .translated
                    .replaceAll('%s', _playlistItems.length.toString()),
                style: Theme.of(context).textTheme.bodyMedium,
              ),

              // Play button
              TextButton.icon(
                icon: const Icon(Icons.play_arrow),
                label: Text(
                  AppGlobals.i18n
                      .translate('app', 'music_shuffle_play')
                      .translated,
                ),
                onPressed:
                    _playlistItems.isEmpty
                        ? null
                        : () async {
                          _startPlaylist(startIndex: 0);
                          AppGlobals.audioHandler.play();
                        },
              ),

              // Shuffle button - starts the playlist in shuffle mode
              TextButton.icon(
                icon: Icon(Icons.shuffle),
                label: Text(
                  _shuffleMode
                      ? AppGlobals.i18n
                          .translate('app', 'music_shuffle_shuffleOn')
                          .translated
                      : AppGlobals.i18n
                          .translate('app', 'music_shuffle_shuffle')
                          .translated,
                ),
                onPressed: () => _toggleShuffleMode(),
              ),

              // Clear button - removes all tracks from the playlist
              TextButton.icon(
                icon: const Icon(Icons.clear_all),
                label: Text(
                  AppGlobals.i18n
                      .translate('app', 'music_shuffle_clear')
                      .translated,
                ),
                onPressed:
                    _playlistItems.isEmpty
                        ? null
                        : () {
                          setState(() {
                            _playlistItems.clear();
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                AppGlobals.i18n
                                    .translate(
                                      'app',
                                      'music_shuffle_playlistCleared',
                                    )
                                    .translated,
                              ),
                            ),
                          );
                        },
              ),
            ],
          ),
        ),
        Expanded(
          child:
              _playlistItems.isEmpty
                  ? Center(
                    child: Text(
                      AppGlobals.i18n
                          .translate('app', 'music_shuffle_playlistEmptyHelper')
                          .translated,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                  : ListView.builder(
                    itemCount: _playlistItems.length,
                    itemBuilder: (context, index) {
                      final track = _playlistItems[index];
                      final assetbundleName = track['assetbundleName'] ?? '';
                      final logoUrl =
                          assetbundleName.isNotEmpty
                              ? '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/$assetbundleName.webp'
                              : '';
                      final vocalIndex = track['selectedVocalIndex'] ?? 0;
                      final vocals = json.decode(track['vocals']);
                      final String vocalName = MusicDatabase.buildVocalName(
                        context,
                        vocals[vocalIndex],
                        _outsideCharacterNames,
                      );

                      return ValueListenableBuilder(
                        valueListenable:
                            AppGlobals.audioHandler.currentTrackIndexNotifier,
                        builder: (context, value, child) {
                          bool playMode =
                              AppGlobals
                                  .audioHandler
                                  .currentMediaItem
                                  ?.extras?['playerMode'] ??
                              false;
                          return ListTile(
                            leading:
                                logoUrl.isNotEmpty
                                    ? ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: SizedBox(
                                        width: 60,
                                        height: 60,
                                        child: CachedNetworkImage(
                                          cacheManager:
                                              PJSKImageCacheManager.instance,
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
                                    : const SizedBox(width: 60, height: 60),
                            title: Text(
                              track['title'] ??
                                  AppGlobals.i18n
                                      .translate(
                                        'app',
                                        'music_shuffle_unknownTitle',
                                      )
                                      .translated,
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // First line: Vocal name
                                Text(
                                  vocalName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                // Second line: Track credits (composer, lyricist, etc.)
                                Text(
                                  _getTrackSubtitle(track),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.remove_circle_outline),
                              onPressed: () => _removeTrackFromPlaylist(index),
                            ),
                            selected:
                                playMode &&
                                index ==
                                    _playedTrackIndices[AppGlobals
                                        .audioHandler
                                        .currentTrackIndex],
                            onTap: () async {
                              await _startPlaylist(startIndex: index);
                              AppGlobals.audioHandler.play();
                            },
                          );
                        },
                      );
                    },
                  ),
        ),
      ],
    );
  }

  Widget buildMusicIndex() {
    return Column(
      children: [
        // Search and Filter Bar
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            children: [
              // Search Field
              Expanded(
                child: TextField(
                  controller: _searchController,
                  focusNode: _searchFocusNode,
                  onChanged: (q) {
                    _searchQuery = q;
                    applyFilters();
                  },
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    hintText:
                        AppGlobals.i18n.translate('common', 'title').translated,
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Add All Button
              PopupMenuButton<String>(
                icon: const Icon(Icons.playlist_add),
                tooltip:
                    AppGlobals.i18n
                        .translate('app', 'music_shuffle_addAllFilteredTracks')
                        .translated,
                onSelected: (String vocalType) {
                  // Call the add method with the selected vocal type
                  if (vocalType == 'sekai') {
                    _addAllFilteredTracksToPlaylist(vocalType: 'sekai');
                  } else if (vocalType == 'original_song') {
                    _addAllFilteredTracksToPlaylist(
                      vocalType: 'original_song',
                      vocalType2: 'virtual_singer',
                    );
                  } else {
                    _addAllFilteredTracksToPlaylist(vocalType: 'another_vocal');
                  }
                },
                itemBuilder:
                    (BuildContext context) => <PopupMenuEntry<String>>[
                      PopupMenuItem<String>(
                        value: 'sekai',
                        child: Text(
                          AppGlobals.i18n
                              .translate('app', 'music_shuffle_sekaiVersion')
                              .translated,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'original_song',
                        child: Text(
                          AppGlobals.i18n
                              .translate(
                                'app',
                                'music_shuffle_virtualSingerVersion',
                              )
                              .translated,
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: 'another_vocal',
                        child: Text(
                          AppGlobals.i18n
                              .translate(
                                'app',
                                'music_shuffle_anotherVocalVersion',
                              )
                              .translated,
                        ),
                      ),
                    ],
              ),
              const SizedBox(width: 8),

              // Filter Button
              IconButton(
                icon: const Icon(Icons.filter_list),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    builder:
                        (modalContext) => SizedBox(
                          height: MediaQuery.of(modalContext).size.height * 0.7,
                          child: FilterBottomSheet<Map<String, dynamic>>(
                            filters: _filters,
                            onApply: () {
                              applyFilters();
                              Navigator.pop(modalContext);
                            },
                          ),
                        ),
                  );
                },
              ),
            ],
          ),
        ),

        // Music List
        Expanded(
          child:
              _lazyLoad.filteredItems.isEmpty
                  ? Center(
                    child: Text(
                      AppGlobals.i18n
                          .translate('app', 'no_items_found')
                          .translated,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                  )
                  : ListView.builder(
                    controller: _scrollController,
                    itemCount: _lazyLoad.itemCount,
                    itemBuilder: (context, index) {
                      // Check if this is the loading indicator
                      if (_lazyLoad.isLoadingIndicator(index)) {
                        return const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }

                      // Get the track at this index
                      final track = _lazyLoad.filteredItems[index];
                      final assetbundleName = track['assetbundleName'] ?? '';
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
                                      cacheManager:
                                          PJSKImageCacheManager.instance,
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
                        title: Text(
                          track['title'] ??
                              AppGlobals.i18n
                                  .translate(
                                    'app',
                                    'music_shuffle_unknownTitle',
                                  )
                                  .translated,
                        ),
                        subtitle: Text(_getTrackSubtitle(track)),
                        trailing: IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          onPressed: () => _showVocalSelectionForTrack(track),
                        ),
                        onTap: () => _showVocalSelectionForTrack(track),
                      );
                    },
                  ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
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
            tooltip:
                AppGlobals.i18n
                    .translate('app', 'music_shuffle_savePlaylist')
                    .translated,
            onPressed: _saveCurrentPlaylist,
          ),
          // Load playlist button
          IconButton(
            icon: const Icon(Icons.folder_open),
            tooltip:
                AppGlobals.i18n
                    .translate('app', 'music_shuffle_loadPlaylistTooltip')
                    .translated,
            onPressed: _showLoadPlaylistDialog,
          ),
          // New playlist button
          IconButton(
            icon: const Icon(Icons.playlist_add),
            tooltip:
                AppGlobals.i18n
                    .translate('app', 'music_shuffle_newPlaylistTooltip')
                    .translated,
            onPressed: _showCreatePlaylistDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Player controls
          GestureDetector(
            onTap: () {
              MediaItem? item = AppGlobals.audioHandler.currentMediaItem;

              if (item == null) return;
              if (item.extras!['type'] == 'music') {
                navigateToDetailPage<int>(
                  context: context,
                  id: item.extras?['trackId'] as int,
                  pageBuilder: (id) => MusicDetailPage(musicId: id),
                );
              } else if (item.extras!['type'] == 'event') {
                navigateToDetailPage<int>(
                  context: context,
                  id: item.extras?['eventId'] as int,
                  pageBuilder: (id) => EventDetailPage(eventId: id),
                );
              }
            },
            child: Card(
              margin: const EdgeInsets.all(8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Current track info
                    ValueListenableBuilder<String>(
                      valueListenable:
                          AppGlobals.audioHandler.currentTrackTitleNotifier,
                      builder:
                          (context, title, _) => Text(
                            title.isEmpty
                                ? AppGlobals.i18n
                                    .translate(
                                      'app',
                                      'music_shuffle_noTrackIsPlaying',
                                    )
                                    .translated
                                : title,
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                    ),
                    ValueListenableBuilder<String>(
                      valueListenable:
                          AppGlobals.audioHandler.currentTrackArtistNotifier,
                      builder: (context, artist, _) {
                        if (artist.isNotEmpty) {
                          return Text(
                            artist,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                    const SizedBox(height: 8),

                    // Player controls
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        previousButton(onPrevious),
                        playButton(
                          getPlayerStateStream(),
                          onPlay,
                          onPause,
                          onReplay,
                        ),
                        nextButton(onNext),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),

          Expanded(
            child: DefaultTabController(
              length: 2,
              child: Column(
                children: [
                  // Tab bar
                  TabBar(
                    tabs: [
                      Tab(
                        text:
                            AppGlobals.i18n
                                .translate('app', 'music_shuffle_playlistTab')
                                .translated,
                      ),
                      Tab(
                        text:
                            AppGlobals.i18n
                                .translate('app', 'music_shuffle_allMusicTab')
                                .translated,
                      ),
                    ],
                  ),

                  Expanded(
                    child: TabBarView(
                      children: [
                        // Playlist
                        buildPlayList(),

                        // All music
                        buildMusicIndex(),
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

  /// Helper ----------------------------------------------------------

  /// Get subtitle for a track (composer, lyricist, etc.)
  String _getTrackSubtitle(Map<String, dynamic> track) {
    final List<String> creditParts = [];
    if (track['composer'] != null && track['composer'].toString().isNotEmpty) {
      creditParts.add(track['composer'].toString());
    }
    if (track['lyricist'] != null && track['lyricist'].toString().isNotEmpty) {
      creditParts.add(track['lyricist'].toString());
    }
    if (track['arranger'] != null && track['arranger'].toString().isNotEmpty) {
      creditParts.add(track['arranger'].toString());
    }

    if (creditParts.isEmpty) {
      return AppGlobals.i18n
          .translate('app', 'music_shuffle_unknownCredits')
          .translated;
    }

    return creditParts.toSet().join(' / ');
  }

  /// Creates a MediaItem from a track and vocal information
  MediaItem buildMediaItemFromTrack({
    required Map<String, dynamic> track,
    required int vocalIndex,
    required BuildContext context,
  }) {
    // Get vocal data
    final vocals = jsonDecode(track['vocals'] ?? '[]');
    final vocal = vocals[vocalIndex];
    final bundle = vocal['assetbundleName'];
    final url = '${AppGlobals.assetUrl}/music/long/$bundle/$bundle.mp3';

    // Get album art
    final assetbundleName = track['assetbundleName'] ?? '';
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

    // Create extras map with useful information
    final Map<String, dynamic> extras = {
      'trackId': track['id'],
      'vocalIndex': vocalIndex,
      'skipSeconds': track['fillerSec'] ?? 0,
      'vocalCaption': vocal['caption'] ?? '',
      'type': 'music',
      'playerMode': true,
    };

    // Use the existing buildMediaItem method to create the MediaItem
    return MediaItem(
      id: url,
      title: track['title'],
      artist: vocalName,
      artUri: Uri.parse(logoUrl),
      extras: extras,
    );
  }

  /// build contributor options for a given role
  Future<List<Map<String, String>>> _getContributorOptions(String role) async {
    final names =
        _allMusicItems
            .where((m) => m[role] != null)
            .map((m) => m[role] as String)
            .where((s) => s.isNotEmpty)
            .toSet();
    return names
        .map((name) => {'display': name, 'value': '$role:$name'})
        .toList();
  }
}
