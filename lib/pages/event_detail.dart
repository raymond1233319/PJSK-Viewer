import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/event_tracker.dart';
import 'package:pjsk_viewer/pages/music_detail.dart';
import 'package:pjsk_viewer/utils/audio_player.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/database/event_database.dart';
import 'package:pjsk_viewer/utils/database/my_sekai_database.dart';
import 'package:pjsk_viewer/utils/database/resource_boxes_database.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:pjsk_viewer/utils/image_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pjsk_viewer/utils/globals.dart';

class EventDetailPage extends StatefulWidget {
  final int eventId;

  const EventDetailPage({required this.eventId, super.key});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _eventData;
  final ValueNotifier<bool> _showTimePointsNotifier = ValueNotifier(false);
  List<Map<String, dynamic>> _worldBlooms = [];
  List<Map<String, dynamic>> _eventExchangeResourceBoxDetails = [];
  Map<int, String> _eventItemAssetMap = {};
  List<Map<String, dynamic>> _mySekaiMaterials = [];
  List<dynamic> _eventMusics = [];

  // --- Helper to format Duration ---
  String _formatDurationFull(Duration d, ContentLocalizations localizations) {
    final days = d.inDays;
    final hours = d.inHours.remainder(24);
    final minutes = d.inMinutes.remainder(60);
    final parts = <String>[];
    if (days > 0) {
      parts.add(
        "$days ${localizations.translate('common', 'countdown', innerKey: 'day')}",
      );
    }
    if (hours > 0) {
      parts.add(
        "$hours ${localizations.translate('common', 'countdown', innerKey: 'hour')}",
      );
    }
    if (minutes > 0) {
      parts.add(
        "$minutes ${localizations.translate('common', 'countdown', innerKey: 'minute')}",
      );
    }
    return parts.isNotEmpty ? parts.join(", ") : "0 minute";
  }

  @override
  void initState() {
    super.initState();
    _fetchEventDetails();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _fetchEventDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    try {
      final Map<String, dynamic>? results =
          await EventDatabase.getEventByEventId(widget.eventId);

      if (results != null) {
        final eventData = Map<String, dynamic>.from(results);

        if (eventData['eventType'] == 'cheerful_carnival') {
          final pref = await SharedPreferences.getInstance();
          eventData['cheerfulCarnivalTeams'] = json.decode(
            pref.getString('cheerfulCarnivalTeams') ?? '[]',
          );
          eventData['cheerfulCarnivalSummaries'] = json.decode(
            pref.getString('cheerfulCarnivalSummaries') ?? '[]',
          );
        }

        if (eventData['eventType'] == 'world_bloom') {
          final pref = await SharedPreferences.getInstance();
          final List<dynamic> worldBlooms = json.decode(
            pref.getString('worldBlooms') ?? '[]',
          );
          _worldBlooms =
              worldBlooms
                  .map((item) => Map<String, dynamic>.from(item))
                  .toList();
        }

        // Fetch resource box details for event exchanges
        final Map<String, dynamic> eventExchangeItems = json.decode(
          eventData['eventExchangeSummaries'] ?? '{}',
        );

        if (eventExchangeItems.containsKey('eventExchanges')) {
          final List<dynamic> exchanges =
              eventExchangeItems['eventExchanges'] as List<dynamic>? ?? [];
          final List<int> resourceBoxIds =
              exchanges
                  .map((exchange) => exchange['resourceBoxId'] as int? ?? 0)
                  .toList();

          if (resourceBoxIds.isNotEmpty) {
            _eventExchangeResourceBoxDetails =
                await ResourceBoxesDatabase.getResourceBoxesByPurpose(
                  'event_exchange',
                  resourceBoxIds,
                );
          }
        }

        _eventItemAssetMap = await EventDatabase.getEventItemAssetbundleMap();
        _mySekaiMaterials = await MySekaiDatabase.getAllMaterials();
        final prefs = await SharedPreferences.getInstance();
        _eventMusics = json.decode(prefs.getString('eventMusics') ?? '[]');
        setState(() {
          _eventData = eventData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // --- Build Remaining Time Row ---
  Widget _buildRemainingTimeRow() {
    final localizations = ContentLocalizations.of(context);
    // Calculate event duration and progress
    final now = DateTime.now().millisecondsSinceEpoch;
    final startTime = _eventData?['startAt'] ?? 0;
    final endTime = _eventData?['aggregateAt'] ?? 0;

    // Skip if start time is invalid or event already ended
    if (endTime <= now || now <= startTime) {
      return const SizedBox.shrink();
    }

    // Use a Stream.periodic to update the timer every minute
    return StreamBuilder<int>(
      stream: Stream.periodic(const Duration(minutes: 1), (i) => i),
      builder: (context, snapshot) {
        final currentTime = DateTime.now().millisecondsSinceEpoch;

        // Calculate remaining time and progress
        final totalDuration = Duration(milliseconds: endTime - startTime);
        final elapsed = Duration(
          milliseconds: (currentTime - startTime).toInt(),
        );
        final remaining = Duration(milliseconds: endTime - currentTime);

        // Skip if remaining time becomes negative while viewing
        if (remaining.isNegative) {
          return const SizedBox.shrink();
        }

        // Calculate progress percentage
        final progressPercent =
            elapsed.inMilliseconds > 0 && totalDuration.inMilliseconds > 0
                ? (elapsed.inMilliseconds / totalDuration.inMilliseconds * 100)
                : 0.0;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 200,
                    child: Text(
                      '${localizations?.translate('event', "remainingTime").translated ?? 'Remaining Time'} (${localizations?.translate('event', "progress").translated ?? 'Progress'}):',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      "${_formatDurationFull(remaining, localizations!)} (${progressPercent.toStringAsFixed(1)}%)",
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            ),
            // progress bar
            Padding(
              padding: const EdgeInsets.only(top: 2.0, bottom: 8.0),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2.0),
                child: LinearProgressIndicator(
                  value: progressPercent / 100,
                  minHeight: 4.0,
                  backgroundColor: Colors.grey[300],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Colors.grey, height: 1.5),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_eventData == null) {
      return Center(
        child: Text(AppLocalizations.of(context).translate('event_not_found')),
      );
    }
    final localizations = ContentLocalizations.of(context);
    final appLocalizations = AppLocalizations.of(context);

    LocalizedText displayEventName = localizations!.translate(
      'event_name',
      _eventData!['id'].toString(),
    );

    // Swap the name if the region is not Japan
    if (AppGlobals.region != 'jp') {
      displayEventName = replaceMainText(displayEventName, _eventData!['name']);
    }

    // Determine image URLs
    final String? assetbundleName = _eventData?['assetbundleName'];
    final logoUrl =
        assetbundleName != null
            ? "${AppGlobals.assetUrl}/event/$assetbundleName/logo/logo.webp"
            : null;
    final bannerUrl =
        assetbundleName != null
            ? "${AppGlobals.assetUrl}/home/banner/$assetbundleName/$assetbundleName.webp"
            : null;
    final backgroundUrl =
        assetbundleName != null
            ? "${AppGlobals.assetUrl}/event/$assetbundleName/screen/bg.webp"
            : null;
    final characterUrl =
        assetbundleName != null
            ? "${AppGlobals.assetUrl}/event/$assetbundleName/screen/character.webp"
            : null;

    final eventType = _eventData?['eventType'] ?? 'none';
    final String bonusAttr = _eventData?['bonusAttr'] ?? 'none';
    final String eventStoryOutline =
        json.decode(_eventData?['eventStory'] ?? '{}')?['outline'] ?? '';
    // get the event cards
    final List<Map<String, dynamic>> eventCards = _eventData?['cards'] ?? [];

    // get the event exchange items
    final Map<String, dynamic> eventExchangeItems = json.decode(
      _eventData?['eventExchangeSummaries'] ?? '{}',
    );

    // get the music
    final int? musicId =
        _eventMusics.firstWhere(
          (e) => e['eventId'] == widget.eventId,
          orElse: () => null,
        )?['musicId'];
    developer.log(musicId.toString());

    // Construct and check audio URL after fetching data
    final audioUrl =
        "${AppGlobals.assetUrl}/event/$assetbundleName/bgm/${assetbundleName}_top.mp3";

    final now = DateTime.now().millisecondsSinceEpoch;
    final startTime = _eventData?['startAt'] ?? 0;
    return Scaffold(
      appBar: DetailBuilder.buildAppBar(context, _eventData!['name']),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailBuilder.buildCard(
              children: [
                MultiImageSelector(
                  options: [
                    MultiImageOption(
                      label: appLocalizations.translate('logo'),
                      imageUrl: logoUrl,
                    ),
                    if (bannerUrl != null)
                      MultiImageOption(
                        label: appLocalizations.translate('banner'),
                        imageUrl: bannerUrl,
                      ),
                    if (backgroundUrl != null)
                      MultiImageOption(
                        label:
                            localizations
                                .translate('event', "tab", innerKey: "title[1]")
                                .translated ??
                            'background',
                        imageUrl: backgroundUrl,
                      ),
                    if (characterUrl != null)
                      MultiImageOption(
                        label:
                            localizations
                                .translate('event', "tab", innerKey: "title[2]")
                                .translated ??
                            'Character',
                        imageUrl: characterUrl,
                      ),
                  ],
                ),
                // Audio Player Section
                AudioPlayerFull(url: audioUrl, title: _eventData!['name'], artUrl: logoUrl,),
              ],
            ),

            // Details Section
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // Story Outline
                    if (eventStoryOutline.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 12.0),
                        padding: const EdgeInsets.all(12.0),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.cyan, width: 1.5),
                          borderRadius: BorderRadius.circular(8.0),
                        ),
                        child: Text(
                          eventStoryOutline,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontSize: 16),
                          textAlign: TextAlign.left,
                        ),
                      ),
                    // Remaining Time
                    _buildRemainingTimeRow(),

                    // Title
                    DetailBuilder.buildLocalizedTextRow(
                      localizations.translate('common', "title").translated,
                      displayEventName,
                    ),
                    // ID
                    DetailBuilder.buildTextRow(
                      localizations.translate('common', "id").translated ??
                          'ID',
                      widget.eventId.toString(),
                    ),

                    //Type
                    DetailBuilder.buildTextRow(
                      localizations.translate('common', "type").translated ??
                          'Type',
                      localizations
                              .translate('event', "type", innerKey: eventType)
                              .translated ??
                          eventType,
                    ),

                    // Unit
                    if (_eventData!['unit'] != "none")
                      DetailBuilder.buildDetailRowWithAsset(
                        localizations.translate('common', "unit").translated ??
                            'Unit',
                        [
                          'assets/${AppGlobals.region}/logol/logo_${_eventData!['unit']}.png',
                        ],
                      ),

                    // Virtual Live
                    if (_eventData!['virtualLiveId'] != null &&
                        _eventData!['virtualLiveId'] != 0)
                      DetailBuilder.buildTextRow(
                        localizations
                                .translate('common', "virtualLive")
                                .translated ??
                            'Virtual Live',
                        _eventData!['virtualLiveId'].toString(),
                      ),

                    // Bonus Info
                    Text(
                      localizations
                              .translate('event', "title", innerKey: 'boost')
                              .translated ??
                          'Boost',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    // Bonus Characters
                    DetailBuilder.buildCharactersWidget(
                      localizations
                              .translate('event', "boostCharacters")
                              .translated ??
                          'Bonus Characters',
                      _eventData!['bonusCharacter'] ?? '[]',
                    ),

                    // Bonus Attribute
                    if (bonusAttr != 'none')
                      DetailBuilder.buildDetailRowWithAsset(
                        localizations
                                .translate('event', "boostAttribute")
                                .translated ??
                            'Boost Attribute',
                        ['assets/icon_attribute_$bonusAttr.png'],
                      ),

                    if (eventCards.isNotEmpty)
                      Text(
                        localizations.translate('common', "card").translated ??
                            'Card',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 12),

                    // Event Cards
                    if (eventCards.isNotEmpty)
                      DetailBuilder.buildCardThumbnailList(
                        context,
                        localizations
                                .translate('event', "eventCards")
                                .translated ??
                            "Event Cards",
                        eventCards,
                      ),

                    // Cheerful Carnival
                    if (eventType == 'cheerful_carnival')
                      DetailBuilder.buildCheerfulCarnivalColumn(
                        context,
                        _eventData!['cheerfulCarnivalTeams'],
                        _eventData!['cheerfulCarnivalSummaries'],
                        assetbundleName!,
                        widget.eventId,
                      ),

                    // World link
                    if (eventType == 'world_bloom')
                      DetailBuilder.buildWorldBloomColumn(
                        context,
                        widget.eventId,
                        _worldBlooms,
                      ),

                    // Time Points
                    ValueListenableBuilder<bool>(
                      valueListenable: _showTimePointsNotifier,
                      builder: (context, isExpanded, _) {
                        return DetailBuilder.buildExpansion(
                          context: context,
                          title:
                              localizations
                                  .translate(
                                    'event',
                                    "title",
                                    innerKey: "timepoint",
                                  )
                                  .translated ??
                              'Time Points',
                          titleStyle: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                          initiallyExpanded: isExpanded,
                          onExpansionChanged:
                              (expanded) =>
                                  _showTimePointsNotifier.value = expanded,
                          children: [
                            DetailBuilder.buildTextRow(
                              localizations
                                      .translate('event', "startAt")
                                      .translated ??
                                  'Event Starts At',
                              formatDate(_eventData!['startAt']),
                            ),
                            DetailBuilder.buildTextRow(
                              localizations
                                      .translate('event', "closeAt")
                                      .translated ??
                                  'Event Closes At',
                              formatDate(_eventData!['aggregateAt']),
                            ),
                            DetailBuilder.buildTextRow(
                              localizations
                                      .translate('event', "endAt")
                                      .translated ??
                                  'Event Entry Available Until',
                              formatDate(_eventData!['closedAt']),
                            ),
                            DetailBuilder.buildTextRow(
                              localizations
                                      .translate('event', "rankingAnnounceAt")
                                      .translated ??
                                  'Ranking Announcement At',
                              formatDate(_eventData!['rankingAnnounceAt']),
                            ),
                            DetailBuilder.buildTextRow(
                              localizations
                                      .translate('event', "distributionStartAt")
                                      .translated ??
                                  'Reward Distribution From',
                              formatDate(_eventData!['distributionStartAt']),
                            ),
                          ],
                        );
                      },
                    ),

                    // Jump to Event Tracker
                    if (now >= startTime)
                      DetailBuilder.buildForwardNavigationButton(
                        context,
                        localizations
                            .translate('common', 'eventTracker')
                            .translated,
                        widget.eventId,
                        (_) => EventTrackerPage(eventId: widget.eventId),
                      ),

                    //music
                    if (musicId != null)
                      DetailBuilder.buildForwardNavigationButton(
                        context,
                        localizations
                            .translate('event', 'newlyWrittenSong')
                            .translated,
                        musicId,
                        (_) => MusicDetailPage(musicId: musicId),
                      ),

                    //Gachas
                    DetailBuilder.buildGachaList(
                      context,
                      localizations.translate('common', "gacha").translated ??
                          'Gacha',
                      _eventData!['gachas'],
                    ),

                    // Event Exchanges
                    DetailBuilder.buildDetailRow(
                      appLocalizations.translate('exchange'),
                      IconButton(
                        icon: const Icon(Icons.arrow_forward),
                        onPressed: () {
                          DetailBuilder.popUpDialog(
                            context,
                            DetailBuilder.buildEventExchangeList(
                              context,
                              eventExchangeItems['eventExchanges']
                                  .cast<Map<String, dynamic>>()
                                  .toList(),
                              _eventExchangeResourceBoxDetails,
                              eventCards,
                              _eventItemAssetMap,
                              _mySekaiMaterials,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
