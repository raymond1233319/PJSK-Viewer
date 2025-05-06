import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/database/card_database.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:pjsk_viewer/utils/database/event_database.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventTrackerPage extends StatefulWidget {
  final int? eventId;
  const EventTrackerPage({this.eventId, super.key});

  @override
  State<EventTrackerPage> createState() => _EventTrackerPageState();
}

class _EventTrackerPageState extends State<EventTrackerPage> {
  List<Map<String, dynamic>>? _eventIndex;
  bool _isLoadingEventIndex = true;
  String? _errorMessage;
  late int eventId;

  @override
  void initState() {
    super.initState();
    _loadEventIndex();
  }

  /// Load the list of events from the database.
  Future<void> _loadEventIndex() async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final allEvents = await EventDatabase.getEventIndex();
    _eventIndex =
        allEvents.where((e) => (e['startAt'] as int? ?? 0) <= now).toList();
    eventId = widget.eventId ?? _eventIndex!.first['id'] as int;
    setState(() {
      _isLoadingEventIndex = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);
    if (_isLoadingEventIndex) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            localizations?.translate('common', 'eventTracker').translated ??
                'Event Tracker',
          ),
        ),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

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
                  padding: const EdgeInsets.all(8.0),
                  child: DropdownButton<int>(
                    isExpanded: true,
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
                                            (event['id'] as int).toString(),
                                          )
                                          .japanese ??
                                      event['name'] as String,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() {
                          eventId = v;
                        });
                      }
                    },
                  ),
                ),
              ),
              RankingTable(
                key: ValueKey(eventId),
                eventId: eventId,
                eventIndex: _eventIndex,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RankingTable extends StatefulWidget {
  final int eventId;
  final List<Map<String, dynamic>>? eventIndex;
  const RankingTable({
    super.key,
    required this.eventId,
    required this.eventIndex,
  });

  @override
  State<RankingTable> createState() => _RankingTableState();
}

class _RankingTableState extends State<RankingTable> {
  bool _isLoadingAssetBundleNames = true;
  bool _isFetchingPredictions = true;
  bool _isLoadingWorldBlooms = true;
  String? _errorMessage;
  int characterId = -1;
  final ValueNotifier<bool> _showAllNotifier = ValueNotifier(false);

  Map<int, Map<String, String>>? _cardInfoMap;
  Map<String, int>? _predictedScoreMap;

  List<Map<String, dynamic>> _worldBlooms = [];
  List<Map<String, dynamic>> _rankings = [];
  List<int> _worldBloomCharacters = [];
  List<bool> _isSelected = [];

  Future<void> _loadAssetBundleNames() async {
    _cardInfoMap = await CardDatabase.getRankingInfo();
    setState(() {
      _isLoadingAssetBundleNames = false;
    });
  }

  Future<void> _fetchEventRanking(int eventId, int characterId) async {
    final uri =
        (characterId != -1)
            ? await () async {
              final timeResp = await http.get(
                Uri.parse(
                  'https://api.sekai.best/event/$eventId/chapter_rankings/time?charaId=$characterId&region=jp',
                ),
              );
              final times =
                  (json.decode(timeResp.body) as Map<String, dynamic>)['data']
                      as List;
              final ts = times.last as String;
              return Uri.parse(
                'https://api.sekai.best/event/$eventId/chapter_rankings?charaId=$characterId&region=jp&timestamp=$ts',
              );
            }()
            : await () async {
              final timeResp = await http.get(
                Uri.parse(
                  'https://api.sekai.best/event/$eventId/rankings/time?region=jp',
                ),
              );
              final times =
                  (json.decode(timeResp.body) as Map<String, dynamic>)['data']
                      as List;
              final ts = times.last as String;
              return Uri.parse(
                'https://api.sekai.best/event/$eventId/rankings?region=jp&timestamp=$ts',
              );
            }();
    developer.log('Fetching event ranking from $uri');
    final respone = await http.get(uri);

    if (respone.statusCode == 200) {
      final jsonMap = json.decode(respone.body) as Map<String, dynamic>;
      _rankings =
          (jsonMap['data']['eventRankings'] as List)
              .map((e) => e as Map<String, dynamic>)
              .toList();
    } else {
      developer.log('Fetching event ranking from $uri');
      throw Exception('Error: ${respone.statusCode}');
    }
  }

  Future<void> _loadWorldBlooms() async {
    // Get the event type from the eventIndex
    final currentEvent = widget.eventIndex?.firstWhere(
      (event) => event['id'] == widget.eventId,
      orElse: () => <String, dynamic>{},
    );
    if (currentEvent!['eventType'] != 'world_bloom') {
      setState(() {
        _isLoadingWorldBlooms = false;
      });
      return;
    }

    final pref = await SharedPreferences.getInstance();
    final List<dynamic> worldBlooms = json.decode(
      pref.getString('worldBlooms') ?? '[]',
    );
    _worldBlooms =
        worldBlooms.map((item) => Map<String, dynamic>.from(item)).toList();
    List<Map<String, dynamic>> filteredWorldBlooms =
        _worldBlooms.where((b) => b['eventId'] == widget.eventId).toList();

    List<int> worldBloomCharacters =
        filteredWorldBlooms.map((b) => b['gameCharacterId'] as int).toList();
    worldBloomCharacters.insert(0, -1);
    developer.log(
      'World Bloom characters: $worldBloomCharacters',
      name: 'EventTrackerPage',
    );
    // local selection state
    List<bool> isSelected = List<bool>.filled(
      worldBloomCharacters.length,
      false,
    );

    setState(() {
      _isLoadingWorldBlooms = false;
      _worldBloomCharacters = worldBloomCharacters;
      _isSelected = isSelected;
      _isSelected[0] = true;
    });
  }

  Future<void> _fetchPredictions() async {
    final currentEvent = widget.eventIndex?.firstWhere(
      (event) => event['id'] == widget.eventId,
      orElse: () => <String, dynamic>{},
    );
    final int aggregateAt = currentEvent?['aggregateAt'] as int? ?? 0;
    if (aggregateAt <= DateTime.now().millisecondsSinceEpoch) {
      setState(() {
        _isFetchingPredictions = false;
      });
      return;
    }
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

  @override
  void initState() {
    super.initState();
    _loadWorldBlooms();
    _loadAssetBundleNames();
    _fetchPredictions();
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
            if (widget.eventId == widget.eventIndex?.first['id'])
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

  List<Widget> _buildRankingList(bool showAll) {
    // determine data subset
    final thresholds = {1, 2, 3, 10, 100, 1000, 5000, 10000, 50000, 100000};
    final list =
        showAll
            ? _rankings.where((rank) {
              final r = rank['rank'] as int? ?? -1;
              if (r >= 51 && r <= 99) return false;
              if (r >= 10 && r <= 50) {
                return r % 10 != 0 ? false : true;
              }
              return true;
            }).toList()
            : _rankings
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
    final localizations = ContentLocalizations.of(context);
    if (_isLoadingAssetBundleNames ||
        _isFetchingPredictions ||
        _isLoadingWorldBlooms) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(child: Text(_errorMessage!));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // switch to filter thresholds
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: ValueListenableBuilder<bool>(
              valueListenable: _showAllNotifier,
              builder: (_, showAll, __) {
                return SwitchListTile(
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
                  value: showAll,
                  onChanged: (v) => _showAllNotifier.value = v,
                );
              },
            ),
          ),
        ),
        // world link chapter selection
        if (_worldBloomCharacters.isNotEmpty)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.symmetric(vertical: 8.0),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: DetailBuilder.buildCharacterToggleButtons(
                characterIds: _worldBloomCharacters,
                isSelected: _isSelected,
                onPressed: (index) {
                  setState(() {
                    for (var i = 0; i < _isSelected.length; i++) {
                      _isSelected[i] = (i == index) ? !_isSelected[i] : false;
                    }
                    characterId =
                        _isSelected[index] ? _worldBloomCharacters[index] : -1;
                  });
                },
              ),
            ),
          ),
        FutureBuilder<void>(
          future: _fetchEventRanking(widget.eventId, characterId),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            // once data is fetched, build the ranking list
            return Column(
              children: [
                const SizedBox(height: 12),

                // real‑time timestamp
                Text(
                  "${localizations?.translate('event', 'realtime').translated}: "
                  "${formatDate(DateTime.parse(_rankings[0]['timestamp']).millisecondsSinceEpoch)}",
                  style: Theme.of(context).textTheme.bodySmall,
                ),

                // show last prediction timestamp
                if (_predictedScoreMap != null &&
                    _predictedScoreMap!['ts'] != null &&
                    widget.eventId == widget.eventIndex?.first['id'])
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Text(
                      "${localizations?.translate('event', 'tracker', innerKey: 'pred_at').translated}: "
                      "${formatDate(_predictedScoreMap!['ts'])}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),

                ValueListenableBuilder<bool>(
                  valueListenable: _showAllNotifier,
                  builder: (_, showAll, __) {
                    return Column(children: _buildRankingList(showAll));
                  },
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
