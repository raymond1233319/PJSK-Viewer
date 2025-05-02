import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/database/card_database.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:pjsk_viewer/utils/database/event_database.dart';

class EventTrackerPage extends StatefulWidget {
  final int? eventId;
  const EventTrackerPage({this.eventId, super.key});

  @override
  State<EventTrackerPage> createState() => _EventTrackerPageState();
}

class _EventTrackerPageState extends State<EventTrackerPage> {
  List<Map<String, dynamic>>? _rankingsData;
  List<Map<String, dynamic>>? _eventIndex;
  bool _isFetchEventRanking = true;
  bool _isLoadingEventIndex = true;
  bool _isLoadingAssetBundleNames = true;
  bool _isFetchingPredictions = true;
  String? _errorMessage;
  Map<int, Map<String, String>>? _cardInfoMap;
  Map<String, int>? _predictedScoreMap;
  bool _showAllRanking = false;
  late int eventId;

  @override
  void initState() {
    super.initState();
    eventId = widget.eventId ?? 0;
    _loadEventIndex();
    _loadAssetBundleNames();
    _fetchPredictions();
    _fetchEventRanking();
  }

  /// Load the list of events from the database.
  Future<void> _loadEventIndex() async {
    _eventIndex = await EventDatabase.getEventIndex();
    setState(() {
      _isLoadingEventIndex = false;
    });
  }

  Future<void> _loadAssetBundleNames() async {
    _cardInfoMap = await CardDatabase.getRankingInfo();
    setState(() {
      _isLoadingAssetBundleNames = false;
    });
  }

  Future<void> _fetchEventRanking() async {
    try {
      http.Response respone;
      if (eventId == 0) {
        respone = await http.get(
          Uri.parse('https://api.sekai.best/event/live?region=jp'),
        );
      } else {
        // fetch available timeframes
        final timeResp = await http.get(
          Uri.parse(
            'https://api.sekai.best/event/$eventId/rankings/time?region=jp',
          ),
        );
        if (timeResp.statusCode != 200) {
          throw Exception('Error fetching timeframes: ${timeResp.statusCode}');
        }
        final timeJson = json.decode(timeResp.body) as Map<String, dynamic>;
        final times = timeJson['data'] as List;
        // find the latest timeframe by highest id
        final latestTs = times.last as String;
        // fetch rankings for that timestamp
        respone = await http.get(
          Uri.parse(
            'https://api.sekai.best/event/$eventId/rankings?region=jp&timestamp=$latestTs',
          ),
        );
      }
      if (respone.statusCode == 200) {
        final jsonMap = json.decode(respone.body) as Map<String, dynamic>;
        _rankingsData =
            (jsonMap['data']['eventRankings'] as List)
                .map((e) => e as Map<String, dynamic>)
                .toList();

        setState(() {
          _isFetchEventRanking = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Error: ${respone.statusCode}';
          _isFetchEventRanking = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isFetchEventRanking = false;
      });
    }
  }

  Future<void> _fetchPredictions() async {
    try {
      final respone = await http.get(
        Uri.parse(
          'https://storage.sekai.best/sekai-best-assets/sekai-event-predict.json',
        ),
      );
      if (respone.statusCode == 200) {
        final data =
            (json.decode(respone.body) as Map<String, dynamic>)['data']
                as Map<String, dynamic>;
        _predictedScoreMap = data.map((k, v) => MapEntry(k, v as int));
      }
    } catch (_) {
    } finally {
      setState(() {
        _isFetchingPredictions = false;
      });
    }
  }

  /// Build a widget for a single ranking entry.
  Widget buildSingleRanking(Map<String, dynamic> ranking) {
    final localizations = ContentLocalizations.of(context);
    final String score = ranking['score'].toString();
    final String word =
        (ranking['userProfile'] as Map<String, dynamic>?)?['word'] ?? '';
    final String username = ranking['userName'];
    final String rank = ranking['rank'].toString();
    // get the user's card asset bundle name
    final cardId =
        (ranking['userCard'] as Map<String, dynamic>?)?['cardId'] as int? ?? 0;
    final assetbundleName = _cardInfoMap?[cardId]?['assetbundleName'] ?? '';
    final rarity = _cardInfoMap?[cardId]?['rarity'] ?? '';
    final attribute = _cardInfoMap?[cardId]?['attribute'] ?? '';
    bool isTrained =
        (ranking['userCard']
            as Map<String, dynamic>?)?['specialTrainingStatus'] ==
        'done';
    final String predictedScore =
        (_predictedScoreMap?[rank] ?? 'N/A').toString();

    Widget thumbnail = DetailBuilder.buildCardThumbnail(
      context: context,
      assetbundleName: assetbundleName,
      rarity: rarity,
      attribute: attribute,
      isTrainedImage: isTrained,
      cardId: cardId,
      isJumpToCardPage: true,
    );
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // rank and score
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '# $rank',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text('$score P'),
              ],
            ),

            // predicted score
            if (eventId == _eventIndex?.first['id'])
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    localizations
                            ?.translate(
                              'event',
                              'rankingTable',
                              innerKey: 'prediction',
                            )
                            .translated ??
                        'Prediction',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text('$predictedScore P'),
                ],
              ),
            const SizedBox(height: 8),
            // image on left, username and word on right
            Row(
              children: [
                thumbnail,
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        username,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(word, style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRankingList() {
    if (_rankingsData == null) return [];
    // determine data subset
    final thresholds = {1, 2, 3, 10, 100, 1000, 5000, 10000, 50000, 100000};
    final list =
        _showAllRanking
            ? List<Map<String, dynamic>>.from(_rankingsData!)
            : _rankingsData!
                .where(
                  (rank) => thresholds.contains(rank['rank'] as int? ?? -1),
                )
                .toList();
    // sort by rank
    list.sort((a, b) {
      final ra = a['rank'] as int? ?? 0;
      final rb = b['rank'] as int? ?? 0;
      return ra.compareTo(rb);
    });
    // build and return widgets
    return list.map((rank) => buildSingleRanking(rank)).toList();
  }

  @override
  Widget build(BuildContext context) {
    if (_isFetchEventRanking ||
        _isLoadingEventIndex ||
        _isLoadingAssetBundleNames ||
        _isFetchingPredictions) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }
    if (_rankingsData == null || _rankingsData!.isEmpty) {
      Center(child: Text(AppLocalizations.of(context).translate('no_data')));
    }
    if (eventId == 0) {
      eventId = _eventIndex?.first['id'] as int;
    }
    final localizations = ContentLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          localizations?.translate('common', 'eventTracker').translated ??
              'Event Tracker',
        ),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(14.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // event selector dropdown
                      if (_eventIndex != null && _eventIndex!.isNotEmpty)
                        DropdownButton<int>(
                          value: eventId,
                          items:
                              _eventIndex!
                                  .map(
                                    (event) => DropdownMenuItem<int>(
                                      value: event['id'] as int,
                                      child: Text(
                                        localizations
                                                ?.translate(
                                                  'event_name',
                                                  (event['id'] as int)
                                                      .toString(),
                                                )
                                                .japanese ??
                                            event['name'] as String,
                                      ),
                                    ),
                                  )
                                  .toList(),
                          onChanged: (v) {
                            if (v != null) {
                              setState(() {
                                eventId = v;
                                _isFetchEventRanking = true;
                                _fetchEventRanking();
                              });
                            }
                          },
                        ),
                      const SizedBox(height: 12),

                      // real‑time timestamp
                      Text(
                        "${localizations?.translate('event', 'realtime').translated}: "
                        "${formatDate(DateTime.parse(_rankingsData![0]['timestamp']).millisecondsSinceEpoch)}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),

                      // show last prediction timestamp
                      if (_predictedScoreMap != null &&
                          _predictedScoreMap!['ts'] != null &&
                          eventId == _eventIndex?.first['id'])
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Text(
                            "${localizations?.translate('event', 'tracker', innerKey: 'pred_at').translated}: "
                            "${formatDate(_predictedScoreMap!['ts'])}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              // switch to filter thresholds
              Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.symmetric(vertical: 8.0),
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SwitchListTile(
                    title: Text(
                      localizations
                              ?.translate(
                                'event',
                                'tracker',
                                innerKey: 'show_all_rank',
                              )
                              .translated ??
                          'Show all rankings',
                    ),
                    value: _showAllRanking,
                    onChanged: (v) => setState(() => _showAllRanking = v),
                  ),
                ),
              ),
              if (_rankingsData != null) ..._buildRankingList(),
            ],
          ),
        ),
      ),
    );
  }
}
