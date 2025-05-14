import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:audio_service/audio_service.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:pjsk_viewer/pages/image_view.dart';
import 'package:pjsk_viewer/utils/audio_player.dart';
import 'package:pjsk_viewer/utils/database/event_database.dart';
import 'package:pjsk_viewer/utils/database/music_database.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:xml/xml.dart' as xml;

class MusicDetailPage extends StatefulWidget {
  final int musicId;
  const MusicDetailPage({required this.musicId, super.key});

  @override
  State<MusicDetailPage> createState() => _MusicDetailPageState();
}

class _MusicDetailPageState extends State<MusicDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _musicDetails;
  String? _errorMessage;
  List<Map<String, dynamic>> _vocals = [];
  List<String> _outsideCharacterNames = [];
  List<dynamic> _musicOriginals = [];
  List<dynamic> _eventMusics = [];
  List<Map<String, dynamic>> _eventList = [];
  int _musicId = 0;
  bool _playerMode = false;
  StreamSubscription<int>? _trackIndexSubscription;

  @override
  void initState() {
    super.initState();
    _musicId = widget.musicId;
    setPlayerMode();
    _fetchMusicDetails();
  }

  @override
  void dispose() {
    _trackIndexSubscription?.cancel();
    super.dispose();
  }

  void setPlayerMode() {
    setState(() {
      _playerMode =
          AppGlobals.audioHandler.isPlayerMode &&
          widget.musicId ==
              AppGlobals.audioHandler.currentMediaItem?.extras?['trackId'];
      if (_playerMode) {
        _setupTrackChangeListener();
      }
    });
  }

  // Method to listen for track changes
  void _setupTrackChangeListener() {
    _trackIndexSubscription = Stream.periodic(const Duration(seconds: 3))
        .asyncMap(
          (_) => AppGlobals.audioHandler.currentTrackIndexNotifier.value,
        )
        .distinct()
        .listen((_) async {
          developer.log(
            'Current Track Index: ${AppGlobals.audioHandler.currentMediaItem?.extras?['trackId']}',
          );
          if (_musicId ==
              AppGlobals.audioHandler.currentMediaItem?.extras?['trackId']) {
            return;
          }
          _musicId =
              AppGlobals.audioHandler.currentMediaItem?.extras?['trackId'];
          await _fetchMusicDetails();
        });
  }

  Future<void> _fetchMusicDetails() async {
    setState(() => _isLoading = true);
    try {
      _musicDetails = await MusicDatabase.getMusicById(_musicId);
      _vocals =
          json.decode(_musicDetails?['vocals']).cast<Map<String, dynamic>>();
      _outsideCharacterNames = await MusicDatabase.getOutsideCharacterNames();
      final prefs = await SharedPreferences.getInstance();
      _musicOriginals = json.decode(prefs.getString('musicOriginals') ?? '[]');
      _eventMusics = json.decode(prefs.getString('eventMusics') ?? '[]');
      _eventList = await EventDatabase.getEventIndex();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper method to build difficulty widgets
  List<Widget> _buildDifficultyWidgets(BuildContext context, difficulties) {
    final widgets = <Widget>[];

    final difficultyColors = {
      'easy': Colors.green,
      'normal': Colors.blue,
      'hard': Colors.orange,
      'expert': Colors.red,
      'master': Colors.purple,
      'append': Colors.purpleAccent,
    };

    for (final difficulty in difficulties) {
      final level = difficulty['playLevel'];
      final type = difficulty['musicDifficulty'].toString().toLowerCase();
      final noteCount = difficulty['totalNoteCount'];
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              // Difficulty icon
              Container(
                width: 80,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: difficultyColors[type] ?? Colors.grey,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  type.toUpperCase(),
                  textAlign: TextAlign.center, // Center the text
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Lv.$level',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Row(
                children: [
                  const SizedBox(width: 4),
                  Text(
                    '$noteCount ${ContentLocalizations.of(context)!.translate('music', 'noteCount').translated}',
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }
    return widgets;
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);

    if (_isLoading) {
      return Scaffold(
        appBar: DetailBuilder.buildAppBar(context, _musicDetails?['title']),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_errorMessage != null) {
      return Center(
        child: Text(
          'Error: $_errorMessage',
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final original = _musicOriginals.firstWhere(
      (e) => e['musicId'] == _musicId,
      orElse: () => null,
    );
    final int? eventId =
        _eventMusics.firstWhere(
          (e) => e['musicId'] == _musicId,
          orElse: () => null,
        )?['eventId'];
    final Map<String, dynamic> event = _eventList.firstWhere(
      (e) => e['id'] == eventId,
      orElse: () => {},
    );
    developer.log(_playerMode.toString());
    return Scaffold(
      appBar: DetailBuilder.buildAppBar(context, _musicDetails?['title']),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MusicPlayer(
              vocals: _vocals,
              outsideCharacterNames: _outsideCharacterNames,
              musicDetails: _musicDetails,
              playerMode: _playerMode,
            ),
            DetailBuilder.buildSectionTitle(context, 'common', 'musicMeta'),
            DetailBuilder.buildCard(
              children: [
                // Title and Category
                DetailBuilder.buildTextRow(
                  localizations!.translate('common', 'title').translated,
                  _musicDetails?['title'],
                ),
                // ID
                DetailBuilder.buildTextRow(
                  localizations.translate('common', "id").translated,
                  _musicDetails?['id']?.toString() ?? '-',
                ),
                // Categories
                if (_musicDetails?['categories'] != null)
                  DetailBuilder.buildTextRow(
                    localizations.translate('music', 'category').translated,
                    json
                        .decode(_musicDetails!['categories'])
                        .map(
                          (cat) =>
                              localizations
                                  .translate(
                                    "music",
                                    "categoryType",
                                    innerKey: cat,
                                  )
                                  .translated,
                        )
                        .join(", "),
                  ),
                // Creator information
                DetailBuilder.buildTextRow(
                  localizations.translate('music', 'composer').translated,
                  _musicDetails?['composer'] ?? '-',
                ),
                DetailBuilder.buildTextRow(
                  localizations.translate('music', 'arranger').translated,
                  _musicDetails?['arranger'] ?? '-',
                ),
                DetailBuilder.buildTextRow(
                  localizations.translate('music', 'lyricist').translated,
                  _musicDetails?['lyricist'] ?? '-',
                ),
                if (_musicDetails?['publishedAt'] != null)
                  DetailBuilder.buildTextRow(
                    localizations?.translate('common', 'startAt').translated ??
                        'Available From',
                    formatDate(_musicDetails!['publishedAt']),
                  ),
                // Is Newly Written Music
                if (_musicDetails?['isNewlyWrittenMusic'] != null)
                  DetailBuilder.buildBoolRow(
                    localizations
                        .translate('event', 'newlyWrittenSong')
                        .translated,
                    _musicDetails!['isNewlyWrittenMusic'] == 1,
                  ),
                if (eventId != null)
                  DetailBuilder.buildEventThumbnail(
                    context,
                    eventId,
                    event['assetbundleName'],
                  ),
                if (original != null)
                  DetailBuilder.buildDetailRow(
                    "Original video",
                    InkWell(
                      onTap: () async {
                        final url = Uri.tryParse(original['videoLink']);
                        if (url != null) {
                          await launchUrl(url);
                        }
                      },
                      child: const Icon(
                        Icons.open_in_new,
                        color: Colors.black,
                        size: 24,
                      ),
                    ),
                  ),
              ],
              padding: const EdgeInsets.symmetric(
                vertical: 8.0,
                horizontal: 16.0,
              ),
            ),

            // Difficulties Section
            if (_musicDetails?['difficulties'] != null) ...[
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localizations!
                            .translate('music', 'difficulty_plural')
                            .translated,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      ..._buildDifficultyWidgets(
                        context,
                        json.decode(_musicDetails!['difficulties']),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class MusicPlayer extends StatefulWidget {
  final List<Map<String, dynamic>> vocals;
  final List<String> outsideCharacterNames;
  final Map<String, dynamic>? musicDetails;
  final bool playerMode;
  const MusicPlayer({
    super.key,
    required this.vocals,
    required this.outsideCharacterNames,
    required this.musicDetails,
    this.playerMode = false,
  });

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  int? _selectedVocalIndex;
  bool _showMv = false;
  String? _videoUrl;
  bool _isLoading = false;
  bool _isLoadingVocal = true;
  final List<AudioPlayerFull> _audioPlayers = [];
  final List<String> _logoUrls = [];
  MVPlayer? _mvPlayer;

  @override
  void initState() {
    super.initState();
    if (widget.vocals.isNotEmpty) {
      _selectedVocalIndex = 0;
      _loadAllVocals();
    }
    _fetchVideoUrl();
  }

  Future<void> _fetchVideoUrl() async {
    try {
      final mvTypes =
          json
              .decode(widget.musicDetails?['categories'] ?? '[]')
              .cast<String>();
      final String mvType = mvTypes.firstWhere(
        (type) => type.startsWith('mv_2d') || type.startsWith('original'),
        orElse: () => '',
      );
      // Determine the correct folder based on MV type
      String mvFolder = '';
      if (mvType.startsWith('mv_2d')) {
        mvFolder = 'sekai_mv';
      } else if (mvType.startsWith('original')) {
        mvFolder = 'original_mv';
      } else {
        return;
      }

      final id = widget.musicDetails?['id']?.toString() ?? '0000';
      final paddedId = id.padLeft(4, '0');
      final listingUrl = Uri.parse(
        '${AppGlobals.assetUrl}/?delimiter=%2F&list-type=2&max-keys=500&prefix=live%2F2dmode%2F$mvFolder%2F$paddedId%2F',
      );
      final response = await http.get(listingUrl);
      if (response.statusCode == 200) {
        final document = xml.XmlDocument.parse(utf8.decode(response.bodyBytes));

        final contents = document.findAllElements('Contents');
        String? mp4Key;

        for (final content in contents) {
          final keyElement = content.findElements('Key').firstOrNull;
          if (keyElement != null) {
            final String keyText = keyElement.innerText;
            if (keyText.endsWith('.mp4')) {
              mp4Key = keyText;
              break;
            }
          }
        }
        if (mp4Key != null) {
          setState(() {
            _videoUrl = '${AppGlobals.assetUrl}/$mp4Key';
          });
        }
      }
    } catch (_) {}
  }

  // Helper method to get jacket URL for a vocal
  String _getJacketUrl(
    Map<String, dynamic> vocal,
    String assetbundleName,
    List<Map<String, dynamic>>? musicAssetVariants,
  ) {
    // Default jacket URL
    String jacketUrl =
        assetbundleName.isNotEmpty
            ? '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/$assetbundleName.webp'
            : '';

    // Check for custom jacket
    if (musicAssetVariants != null) {
      final Map<String, dynamic> musicVariant = musicAssetVariants.firstWhere(
        (e) => e['musicVocalId'] == vocal['id'],
        orElse: () => <String, dynamic>{},
      );

      if (musicVariant.isNotEmpty) {
        if (musicVariant['musicAssetType'] == 'jacket') {
          jacketUrl =
              '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/${musicVariant['assetbundleName']}.webp';
        }
      }
    }

    return jacketUrl;
  }

  // load all vocals at once
  void _loadAllVocals({MVPlayer? mvPlayer}) async {
    setState(() {
      _isLoadingVocal = true;
    });

    // Get the base asset bundle name for jacket images
    final assetbundleName =
        widget.musicDetails?['assetbundleName'] as String? ?? '';

    // Get music asset variants from shared preferences
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>>? musicAssetVariants =
        json
            .decode(prefs.getString('musicAssetVariants') ?? '[]')
            .cast<Map<String, dynamic>>();
    _audioPlayers.clear();
    // Process each vocal
    for (int i = 0; i < widget.vocals.length; i++) {
      final vocal = widget.vocals[i];
      final bundle = vocal['assetbundleName'] as String;
      final url = '${AppGlobals.assetUrl}/music/long/$bundle/$bundle.mp3';

      if (await AppGlobals.audioHandler.isCurrentSource(url)) {
        _selectedVocalIndex = i;
      }
      // Get jacket URL for this vocal
      final jacketUrl = _getJacketUrl(
        vocal,
        assetbundleName,
        musicAssetVariants,
      );

      // Build vocal name
      final vocalName = MusicDatabase.buildVocalName(
        context,
        vocal,
        widget.outsideCharacterNames,
      );

      // Create MediaItem for this vocal
      final mediaItem = MediaItem(
        id: url,
        title: widget.musicDetails?['title'],
        artUri: Uri.parse(jacketUrl),
        extras: {'skipSeconds': widget.musicDetails?["fillerSec"] ?? 0},
        artist: vocalName,
      );

      // Set the logo URL
      _logoUrls.add(jacketUrl);

      // Create an AudioPlayerFull instance for this vocal
      if (mvPlayer != null) {
        _audioPlayers.add(
          AudioPlayerWithMv(
            mediaItem: mediaItem,
            mvPlayer: mvPlayer,
            playerMode: widget.playerMode,
          ),
        );
      }
      // If no MV player, create a normal AudioPlayerFull instance
      else {
        _audioPlayers.add(
          AudioPlayerFull(mediaItem: mediaItem, playerMode: widget.playerMode),
        );
      }
    }
    setState(() {
      _isLoadingVocal = false;
    });
  }

  // Update the MV toggle function
  void _toggleMv() async {
    setState(() {
      _isLoading = true;
    });
    _mvPlayer ??= await MVPlayer.create(videoUrl: _videoUrl!);
    Duration startPosition =
        await _audioPlayers[_selectedVocalIndex ?? 0].getCurrentPosition();
    _mvPlayer!.onSeek(startPosition);
    _loadAllVocals(mvPlayer: _mvPlayer);
    if (_audioPlayers[_selectedVocalIndex ?? 0].isPlaying) {
      _mvPlayer!.onPlay();
    } else {
      _mvPlayer!.onPause();
    }

    setState(() {
      _showMv = !_showMv;
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _mvPlayer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingVocal || _isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return DetailBuilder.buildCard(
      children: [
        if (_videoUrl != null) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                icon: Icon(
                  _showMv ? Icons.videocam : Icons.videocam_off,
                  size: 18,
                ),
                label: Text(
                  _showMv ? 'MV ON' : 'MV OFF',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _showMv
                          ? Theme.of(context).colorScheme.primary
                          : Colors.grey.shade300,
                  foregroundColor: _showMv ? Colors.white : Colors.black87,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: _toggleMv,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],

        if (!_showMv)
          buildHeroImageViewer(context, _logoUrls[_selectedVocalIndex ?? 0]),
        if (_showMv && _mvPlayer != null) _mvPlayer!,

        // Vocal selector
        if (widget.vocals.isNotEmpty) ...[
          SizedBox(
            width: double.infinity,
            child: DropdownButton<int>(
              isExpanded: true,
              itemHeight: null,
              value: _selectedVocalIndex,
              items:
                  widget.vocals.asMap().entries.map((e) {
                    final caption = e.value['caption'] as String? ?? '';
                    final name = MusicDatabase.buildVocalName(
                      context,
                      e.value,
                      widget.outsideCharacterNames,
                    );
                    return DropdownMenuItem<int>(
                      value: e.key,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: 8.0,
                          horizontal: 4.0,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              caption,
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
              onChanged: (idx) async {
                Duration currentPosition =
                    await _audioPlayers[_selectedVocalIndex ?? 0]
                        .getCurrentPosition();
                await _audioPlayers[idx!].loadAudio(
                  startPosition: currentPosition,
                );
                setState(() {
                  _selectedVocalIndex = idx;
                });
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        _audioPlayers[_selectedVocalIndex ?? 0],
      ],
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    );
  }
}
