import 'dart:convert';
import 'dart:developer' as developer;
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
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _fetchMusicDetails();
    _pageController.addListener(() {
      final newPage = _pageController.page?.round() ?? 0;
      if (_currentPage != newPage) {
        setState(() => _currentPage = newPage);
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchMusicDetails() async {
    setState(() => _isLoading = true);
    try {
      _musicDetails = await MusicDatabase.getMusicById(widget.musicId);
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
      return const Center(child: CircularProgressIndicator());
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
      (e) => e['musicId'] == widget.musicId,
      orElse: () => null,
    );
    final int? eventId =
        _eventMusics.firstWhere(
          (e) => e['musicId'] == widget.musicId,
          orElse: () => null,
        )?['eventId'];
    final Map<String, dynamic> event = _eventList.firstWhere(
      (e) => e['id'] == eventId,
      orElse: () => {},
    );

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: DetailBuilder.buildAppBar(context, _musicDetails?['title']),
        body: Stack(
          children: [
            PageView(
              scrollDirection: Axis.vertical, // Change to vertical scrolling
              physics: const VerticalPageFlipPhysics(),
              controller: _pageController,
              children: [
                // PLAYER PAGE
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MusicPlayer(
                        vocals: _vocals,
                        outsideCharacterNames: _outsideCharacterNames,
                        musicDetails: _musicDetails,
                      ),
                    ],
                  ),
                ),

                // DETAILS PAGE
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DetailBuilder.buildCard(
                        children: [
                          // Title and Category
                          DetailBuilder.buildTextRow(
                            localizations!
                                .translate('common', 'title')
                                .translated,
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
                              localizations
                                  .translate('music', 'category')
                                  .translated,
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
                            localizations
                                .translate('music', 'composer')
                                .translated,
                            _musicDetails?['composer'] ?? '-',
                          ),
                          DetailBuilder.buildTextRow(
                            localizations
                                .translate('music', 'arranger')
                                .translated,
                            _musicDetails?['arranger'] ?? '-',
                          ),
                          DetailBuilder.buildTextRow(
                            localizations
                                .translate('music', 'lyricist')
                                .translated,
                            _musicDetails?['lyricist'] ?? '-',
                          ),
                          if (_musicDetails?['publishedAt'] != null)
                            DetailBuilder.buildTextRow(
                              localizations
                                      ?.translate('common', 'startAt')
                                      .translated ??
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
                                  final url = Uri.tryParse(
                                    original['videoLink'],
                                  );
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
                                  style:
                                      Theme.of(context).textTheme.titleMedium,
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
              ],
            ),
            // Floating section title
            AnimatedBuilder(
              animation: _pageController,
              builder: (context, child) {
                // Calculate position based on page scroll
                final pageOffset =
                    _pageController.hasClients ? _pageController.page ?? 0 : 0;
                final screenHeight = MediaQuery.of(context).size.height;

                // Position from AppBar height + safeArea
                final appBarHeight =
                    Scaffold.of(context).appBarMaxHeight ?? 56.0;
                final topSafeArea = MediaQuery.of(context).padding.top;
                final titleHeight = 80.0;

                // Calculate opacity - fade out as we approach page 1
                final opacity = 1.0 - (pageOffset * 2).clamp(0.0, 1.0);

                // If fully transparent, don't render at all
                if (opacity <= 0.01) return const SizedBox.shrink();

                double topPosition = 0;
                if (pageOffset <= 0.1) {
                  // At the beginning of page 0, title stays at bottom
                  topPosition = screenHeight - appBarHeight - titleHeight;
                } else if (pageOffset >= 0.8) {
                  topPosition = 0;
                } else {
                  // During transition (0.1-0.8), animate from bottom to top
                  final normalizedOffset = (pageOffset - 0.1) / 0.7;
                  final startPos =
                      screenHeight - appBarHeight - titleHeight - 16;
                  final endPos = topSafeArea + appBarHeight + 8;
                  topPosition =
                      startPos - (normalizedOffset * (startPos - endPos));
                }

                return Positioned(
                  left: 0,
                  right: 0,
                  top: topPosition,
                  child: GestureDetector(
                    onTap: () {
                      // Animate to detail page (page index 1) when title is clicked
                      _pageController.animateToPage(
                        1,
                        duration: const Duration(milliseconds: 500),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    child: Opacity(
                      opacity: opacity,
                      child: Container(
                        color: Colors.transparent,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            DetailBuilder.buildSectionTitle(
                              context,
                              'common',
                              'musicMeta',
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class VerticalPageFlipPhysics extends ScrollPhysics {
  const VerticalPageFlipPhysics({super.parent});

  @override
  VerticalPageFlipPhysics applyTo(ScrollPhysics? ancestor) {
    return VerticalPageFlipPhysics(parent: buildParent(ancestor));
  }

  @override
  SpringDescription get spring =>
      const SpringDescription(mass: 80, stiffness: 120, damping: 0.9);

  @override
  bool get allowImplicitScrolling => false;

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    // If we're out of range and not moving fast enough to fling in range
    if ((velocity <= 0.0 && position.pixels <= position.minScrollExtent) ||
        (velocity >= 0.0 && position.pixels >= position.maxScrollExtent)) {
      return super.createBallisticSimulation(position, velocity);
    }

    if (velocity.abs() < 600) {
      // Page settled on the middle of a page but need to go to next page
      return ScrollSpringSimulation(
        spring,
        position.pixels,
        position.pixels.round().toDouble(),
        0.0,
        tolerance: Tolerance.defaultTolerance,
      );
    }

    // Page is flinging to next or previous page
    final target =
        velocity > 0.0 ? position.pixels.ceil() : position.pixels.floor();

    return ScrollSpringSimulation(
      spring,
      position.pixels,
      target.toDouble(),
      velocity,
      tolerance: Tolerance.defaultTolerance,
    );
  }
}

class MusicPlayer extends StatefulWidget {
  final List<Map<String, dynamic>> vocals;
  final List<String> outsideCharacterNames;
  final Map<String, dynamic>? musicDetails;

  const MusicPlayer({
    super.key,
    required this.vocals,
    required this.outsideCharacterNames,
    required this.musicDetails,
  });

  @override
  State<MusicPlayer> createState() => _MusicPlayerState();
}

class _MusicPlayerState extends State<MusicPlayer> {
  int? _selectedVocalIndex;
  bool _showMv = false;
  String? _videoUrl;
  String? _vocalUrl;
  String? _vocalName;
  bool _isLoading = true;
  bool _isLoadingVocal = true;
  String _logoUrl = '';

  @override
  void initState() {
    super.initState();
    if (widget.vocals.isNotEmpty) {
      _selectedVocalIndex = 0;
      _loadSelectedVocal();
    }
    _fetchVideoUrl();
  }

  Future<void> _fetchVideoUrl() async {
    try {
      final id = widget.musicDetails?['id']?.toString() ?? '0000';
      final paddedId = id.padLeft(4, '0');
      final listingUrl = Uri.parse(
        '${AppGlobals.assetUrl}/?delimiter=%2F&list-type=2&max-keys=500&prefix=live%2F2dmode%2Fsekai_mv%2F$paddedId%2F',
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
          developer.log('Found video URL: $mp4Key');
          _videoUrl = '${AppGlobals.assetUrl}/$mp4Key';
        } else {
          throw Exception();
        }
      } else {
        throw Exception();
      }
    } catch (_) {
      final id = widget.musicDetails?['id'].toString() ?? '0000';
      _videoUrl =
          '${AppGlobals.assetUrl}/live/2dmode/sekai_mv/${id.padLeft(4, '0')}/${id.padLeft(4, '0')}.mp4';
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _loadSelectedVocal() async {
    final vocal = widget.vocals[_selectedVocalIndex!];
    final bundle = vocal['assetbundleName'] as String;
    final url = '${AppGlobals.assetUrl}/music/long/$bundle/$bundle.mp3';
    final assetbundleName =
        widget.musicDetails?['assetbundleName'] as String? ?? '';
    _logoUrl =
        assetbundleName.isNotEmpty
            ? '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/$assetbundleName.webp'
            : '';
    final prefs = await SharedPreferences.getInstance();
    final List<Map<String, dynamic>>? musicAssetVariants =
        json
            .decode(prefs.getString('musicAssetVariants') ?? '[]')
            .cast<Map<String, dynamic>>();

    final Map<String, dynamic>? musicVariant = musicAssetVariants?.firstWhere(
      (e) => e['musicVocalId'] == vocal['id'],
      orElse: () => <String, dynamic>{},
    );
    if (musicVariant != null && musicVariant.isNotEmpty) {
      if (musicVariant['musicAssetType'] == 'jacket') {
        _logoUrl =
            '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/${musicVariant['assetbundleName']}.webp';
      }
    }
    setState(() {
      _vocalUrl = url;
      _vocalName = MusicDatabase.buildVocalName(
        context,
        vocal,
        widget.outsideCharacterNames,
      );
      _isLoadingVocal = false;
    });
  }

  // Update the MV toggle function
  void _toggleMv() {
    setState(() {
      _showMv = !_showMv;
    });
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isLoadingVocal) {
      return const Center(child: CircularProgressIndicator());
    }

    // Check if categories contains 2D MV
    final bool hasMv =
        widget.musicDetails?['categories'] != null &&
        json.decode(widget.musicDetails!['categories']).contains('mv_2d');
    return DetailBuilder.buildCard(
      children: [
        if (hasMv) ...[
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
        // Show either video player or image
        if (!_showMv) buildHeroImageViewer(context, _logoUrl),

        // Vocal selector
        if (widget.vocals.isNotEmpty && !_showMv) ...[
          SizedBox(
            width: double.infinity,
            child: DropdownButton<int>(
              isExpanded: true,
              value: _selectedVocalIndex,
              itemHeight: null,
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
              onChanged: (idx) {
                setState(() {
                  _selectedVocalIndex = idx;
                  _loadSelectedVocal();
                });
              },
            ),
          ),
        ],
        const SizedBox(height: 16),
        _showMv
            ? MVPlayer(
              videoUrl: _videoUrl!,
              skipSeconds: widget.musicDetails?["fillerSec"].toInt() ?? 0,
            )
            : AudioPlayerFull(
              url: _vocalUrl!,
              title: widget.musicDetails?['title'],
              artUrl: _logoUrl,
              skipSeconds: widget.musicDetails?["fillerSec"] ?? 0,
              artist: _vocalName,
            ),
      ],
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 16.0),
    );
  }
}
