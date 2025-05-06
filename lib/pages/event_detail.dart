import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/event_tracker.dart';
import 'package:pjsk_viewer/utils/audio_service.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/database/event_database.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:pjsk_viewer/utils/image_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventDetailPage extends StatefulWidget {
  final int eventId;

  const EventDetailPage({required this.eventId, super.key});

  @override
  State<EventDetailPage> createState() => _EventDetailPageState();
}

class _EventDetailPageState extends State<EventDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _eventData;
  final AudioService _audioService = AudioService();
  final ValueNotifier<bool> _showTimePointsNotifier = ValueNotifier(false);

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
    _audioService.dispose();
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
        // Construct and check audio URL after fetching data
        final assetbundleName = eventData['assetbundleName'];
        final audioUrl =
            "https://storage.sekai.best/sekai-jp-assets/event/$assetbundleName/bgm/${assetbundleName}_top.mp3";
        _audioService.loadAudio(audioUrl);
        if (eventData['eventType'] == 'cheerful_carnival') {
          final pref = await SharedPreferences.getInstance();
          eventData['cheerfulCarnivalTeams'] = json.decode(
            pref.getString('cheerfulCarnivalTeams') ?? '[]',
          );
          eventData['cheerfulCarnivalSummaries'] = json.decode(
            pref.getString('cheerfulCarnivalSummaries') ?? '[]',
          );
        }

        setState(() {
          _eventData = eventData;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
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

    // Skip if end time is invalid or event already ended
    if (endTime <= now || endTime <= startTime) {
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
    final localizations = ContentLocalizations.of(context);
    final appLocalizations = AppLocalizations.of(context);
    // Determine event name using localizations
    LocalizedText displayEventName = localizations!.translate(
      'common',
      "loading",
    );

    if (_eventData != null) {
      displayEventName = localizations.translate(
        'event_name',
        _eventData!['id'].toString(),
      );
    }

    // Determine image URLs
    final String? assetbundleName = _eventData?['assetbundleName'];
    final logoUrl =
        assetbundleName != null
            ? "https://storage.sekai.best/sekai-jp-assets/event/$assetbundleName/logo/logo.webp"
            : null;
    final bannerUrl =
        assetbundleName != null
            ? "https://storage.sekai.best/sekai-jp-assets/home/banner/$assetbundleName/$assetbundleName.webp"
            : null;
    final backgroundUrl =
        assetbundleName != null
            ? "https://storage.sekai.best/sekai-jp-assets/event/$assetbundleName/screen/bg.webp"
            : null;
    final characterUrl =
        assetbundleName != null
            ? "https://storage.sekai.best/sekai-jp-assets/event/$assetbundleName/screen/character.webp"
            : null;

    final eventType = _eventData?['eventType'] ?? 'none';
    final String bonusAttr = _eventData?['bonusAttr'] ?? 'none';
    final String eventStoryOutline =
        json.decode(_eventData?['eventStory'] ?? '{}')?['outline'] ?? '';
    // get the event cards
    final List<Map<String, dynamic>> eventCards = _eventData?['cards'] ?? [];

    return Scaffold(
      appBar: DetailBuilder.buildAppBar(context, displayEventName.translated),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _eventData == null
              ? Center(
                child: Text(appLocalizations.translate('event_not_found')),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Section
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
                                    .translate(
                                      'event',
                                      "tab",
                                      innerKey: "title[1]",
                                    )
                                    .translated ??
                                'background',
                            imageUrl: backgroundUrl,
                          ),
                        if (characterUrl != null)
                          MultiImageOption(
                            label:
                                localizations
                                    .translate(
                                      'event',
                                      "tab",
                                      innerKey: "title[2]",
                                    )
                                    .translated ??
                                'Character',
                            imageUrl: characterUrl,
                          ),
                      ],
                    ),
                    // Audio Player Section
                    AudioPlayerFull(audioService: _audioService),

                    // Story Outline
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
                            // Remaining Time
                            _buildRemainingTimeRow(),

                            // Title
                            DetailBuilder.buildLocalizedTextRow(
                              localizations
                                  .translate('common', "title")
                                  .translated,
                              displayEventName,
                            ),
                            // ID
                            DetailBuilder.buildTextRow(
                              localizations
                                      .translate('common', "id")
                                      .translated ??
                                  'ID',
                              widget.eventId.toString(),
                            ),

                            //Type
                            DetailBuilder.buildTextRow(
                              localizations
                                      .translate('common', "type")
                                      .translated ??
                                  'Type',
                              localizations
                                      .translate(
                                        'event',
                                        "type",
                                        innerKey: eventType,
                                      )
                                      .translated ??
                                  eventType,
                            ),

                            // Unit
                            if (_eventData!['unit'] != "none")
                              DetailBuilder.buildDetailRowWithAsset(
                                localizations
                                        .translate('common', "unit")
                                        .translated ??
                                    'Unit',
                                [
                                  'assets/jp/logol/logo_${_eventData!['unit']}.png',
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
                                      .translate(
                                        'event',
                                        "title",
                                        innerKey: 'boost',
                                      )
                                      .translated ??
                                  'Boost',
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.bold),
                            ),

                            // Bonus Characters
                            const SizedBox(height: 12),
                            DetailBuilder.buildBonusCharacterWidget(
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
                                localizations
                                        .translate('common', "card")
                                        .translated ??
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
                                  titleStyle: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(fontWeight: FontWeight.bold),
                                  initiallyExpanded: isExpanded,
                                  onExpansionChanged:
                                      (expanded) =>
                                          _showTimePointsNotifier.value =
                                              expanded,
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
                                              .translate(
                                                'event',
                                                "rankingAnnounceAt",
                                              )
                                              .translated ??
                                          'Ranking Announcement At',
                                      formatDate(
                                        _eventData!['rankingAnnounceAt'],
                                      ),
                                    ),
                                    DetailBuilder.buildTextRow(
                                      localizations
                                              .translate(
                                                'event',
                                                "distributionStartAt",
                                              )
                                              .translated ??
                                          'Reward Distribution From',
                                      formatDate(
                                        _eventData!['distributionStartAt'],
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),
                            // Jump to Event Tracker
                            DetailBuilder.buildDetailRow(
                              localizations
                                  .translate('common', 'eventTracker')
                                  .translated,
                              IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => EventTrackerPage(
                                            eventId: widget.eventId,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            //Gachas
                            DetailBuilder.buildGachaList(
                              context,
                              localizations
                                      .translate('common', "gacha")
                                      .translated ??
                                  'Gacha',
                              _eventData!['gachas'],
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
