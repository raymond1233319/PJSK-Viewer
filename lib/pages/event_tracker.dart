import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/database/card_database.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:pjsk_viewer/utils/database/event_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart';

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
  int _characterId = -1;
  final ValueNotifier<bool> _showAllNotifier = ValueNotifier(false);

  Map<int, Map<String, String>>? _cardInfoMap;
  Map<String, int>? _predictedScoreMap;

  List<Map<String, dynamic>> _worldBlooms = [];
  List<Map<String, dynamic>> _rankings = [];
  List<int> _worldBloomCharacters = [];
  String? _worldBloomUnit;
  List<bool> _isSelected = [];

  Future<void> _loadAssetBundleNames() async {
    _cardInfoMap = await CardDatabase.getRankingInfo();
    setState(() {
      _isLoadingAssetBundleNames = false;
    });
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
      _worldBloomUnit = currentEvent['unit'] as String? ?? '';
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

    // New: delegate all logic to buildGraphCard
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        buildGraphCard(
          context,
          widget.eventId,
          ranking['rank'],
          username,
          _characterId,
        );
      },
      child: Card(
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
              if (widget.eventId == widget.eventIndex?.first['id'] &&
                  _characterId == -1)
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
              // image on left, username and word on right, chart icon on bottom right
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
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                word,
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ),
                            const Icon(
                              Icons.show_chart,
                              size: 22,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Build a graph card for the ranking graph.
  void buildGraphCard(
    BuildContext context,
    int eventId,
    int rank,
    String username,
    int characterId,
  ) async {
    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    try {
      http.Response response;
      if (characterId == -1) {
        response = await http.get(
          Uri.parse(
            'https://api.sekai.best/event/$eventId/rankings/graph?rank=$rank&region=${AppGlobals.region}',
          ),
        );
      } else {
        response = await http.get(
          Uri.parse(
            'https://api.sekai.best/event/$eventId/chapter_rankings/graph?rank=$rank&charaId=$characterId&region=${AppGlobals.region}',
          ),
        );
      }
      Navigator.of(context).pop(); // Remove loading dialog
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> points = data['data']['eventRankings'];
        // Get event info for aggregate time
        final currentEvent = widget.eventIndex?.firstWhere(
          (event) => event['id'] == eventId,
          orElse: () => <String, dynamic>{},
        );
        // Show graph in a modal dialog
        showDialog(
          context: context,
          builder:
              (context) => Dialog(
                child: _buildGraphCardContent(
                  points,
                  username,
                  rank,
                  currentEvent,
                ),
              ),
        );
      } else {
        showDialog(
          context: context,
          builder:
              (context) => AlertDialog(
                title: const Text('Error'),
                content: Text('Failed to fetch graph data.'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('OK'),
                  ),
                ],
              ),
        );
      }
    } catch (e) {
      Navigator.of(context).pop();
      showDialog(
        context: context,
        builder:
            (context) => AlertDialog(
              title: const Text('Error'),
              content: Text('Failed to fetch graph data: $e'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
    }
  }

  /// Build the actual graph card content (line chart)
  Widget _buildGraphCardContent(
    List<dynamic> points,
    String username,
    int rank,
    Map<String, dynamic>? eventInfo,
  ) {
    List<FlSpot> spots = [];
    List<DateTime> timestamps = [];
    for (var p in points) {
      final dt = DateTime.parse(p['timestamp']);
      final timestamp = dt.millisecondsSinceEpoch.toDouble();
      final score = (p['score'] as num).toDouble();
      spots.add(FlSpot(timestamp, score));
      timestamps.add(dt);
    }
    spots.sort((a, b) => a.x.compareTo(b.x));
    timestamps.sort(
      (a, b) => a.millisecondsSinceEpoch.compareTo(b.millisecondsSinceEpoch),
    );

    // Create horizontal prediction line for overall rankings (_characterId == -1)
    List<FlSpot> predictionSpots = [];
    if (_characterId == -1 &&
        _predictedScoreMap != null &&
        eventInfo != null &&
        spots.isNotEmpty) {
      final predictedScore = _predictedScoreMap![rank.toString()];
      if (predictedScore != null) {
        final minX = spots.first.x;
        final maxX = spots.last.x;
        // Create horizontal line across the entire time range
        predictionSpots.add(FlSpot(minX, predictedScore.toDouble()));
        predictionSpots.add(FlSpot(maxX, predictedScore.toDouble()));
      }
    }

    final double labelInterval =
        24 * 60 * 60 * 1000; // 24 hours in milliseconds

    return SizedBox(
      width: 400,
      height: 350,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _characterId != -1
                  ? '${eventInfo!['name']} ${getLocalizedCharacterName(ContentLocalizations.of(context)!, _characterId.toString()).translated} T$rank'
                  : '${eventInfo!['name']} T$rank',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            Text(username, style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY:
                      spots.isNotEmpty
                          ? _roundUpToNiceNumber(
                            [
                              ...spots.map((s) => s.y),
                              ...predictionSpots.map((s) => s.y),
                            ].reduce((a, b) => a > b ? a : b),
                          )
                          : null,
                  lineBarsData: [
                    // Actual data line
                    LineChartBarData(
                      spots: spots,
                      isCurved: true,
                      color: Colors.blue,
                      barWidth: 3,
                      dotData: FlDotData(show: false),
                    ),
                    // Prediction line (dotted)
                    if (predictionSpots.isNotEmpty)
                      LineChartBarData(
                        spots: predictionSpots,
                        isCurved: false,
                        color: Colors.orange,
                        barWidth: 2,
                        dotData: FlDotData(show: false),
                        dashArray: [5, 5], // Creates dotted line
                      ),
                  ],
                  titlesData: FlTitlesData(
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final dt = DateTime.fromMillisecondsSinceEpoch(
                            value.toInt(),
                          );
                          final dateString = DateFormat('MMM d').format(dt);
                          return SideTitleWidget(
                            meta: meta,
                            angle: -math.pi / 4,
                            space: 8.0,
                            child: Text(
                              dateString,
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                        reservedSize: 32,
                        interval: labelInterval,
                      ),
                    ),
                  ),
                  gridData: FlGridData(show: true),
                  borderData: FlBorderData(show: true),
                  lineTouchData: LineTouchData(
                    enabled: true,
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (touchedSpots) {
                        return touchedSpots.map((spot) {
                          final dt = DateTime.fromMillisecondsSinceEpoch(
                            spot.x.toInt(),
                          );
                          final score = spot.y.toInt().toString();
                          // Find the corresponding data point to get the actual username
                          final pointIndex = points.indexWhere(
                            (p) =>
                                DateTime.parse(
                                      p['timestamp'],
                                    ).millisecondsSinceEpoch ==
                                    spot.x.toInt() &&
                                (p['score'] as num).toDouble() == spot.y,
                          );
                          final actualUsername =
                              pointIndex >= 0
                                  ? points[pointIndex]['userName']
                                  : username;

                          // Calculate points per hour from previous data point
                          String pointsPerHourText = '';
                          if (pointIndex > 0) {
                            final prevPoint = points[pointIndex - 1];
                            final prevScore =
                                (prevPoint['score'] as num).toDouble();
                            final prevTime = DateTime.parse(
                              prevPoint['timestamp'],
                            );
                            final currentScore = spot.y;
                            final currentTime = dt;

                            final scoreGain = currentScore - prevScore;
                            final timeDiffInHours =
                                currentTime
                                    .difference(prevTime)
                                    .inMilliseconds /
                                (1000 * 60 * 60);

                            if (timeDiffInHours > 0) {
                              final pointsPerHour =
                                  (scoreGain / timeDiffInHours).round();
                              pointsPerHourText = '($pointsPerHour/h)';
                            }
                          }

                          return LineTooltipItem(
                            '$actualUsername\n${DateFormat('MMM d HH:mm').format(dt)}\n$score P\n$pointsPerHourText',
                            const TextStyle(color: Colors.white, fontSize: 12),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Points per hour statistics
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppGlobals.i18n
                          .translate(
                            'event',
                            'speedTable',
                            innerKey: 'all_time',
                          )
                          .translated,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _calculatePointsPerHour(points, 'all_time', eventInfo),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppGlobals.i18n
                          .translate(
                            'event',
                            'speedTable',
                            innerKey: 'last_24h',
                          )
                          .translated,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _calculatePointsPerHour(
                        points,
                        'last_24_hours',
                        eventInfo,
                      ),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      AppGlobals.i18n
                          .translate('event', 'speedTable', innerKey: 'last_1h')
                          .translated,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      _calculatePointsPerHour(points, 'last_1_hour', eventInfo),
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Helper to round up to nice round numbers for Y-axis
  double _roundUpToNiceNumber(double value) {
    if (value >= 100000000) {
      return ((value / 100000000).ceil() * 100000000)
          .toDouble(); // 100M increments
    } else if (value >= 20000000) {
      return ((value / 20000000).ceil() * 20000000)
          .toDouble(); // 20M increments
    } else if (value >= 1000000) {
      return ((value / 1000000).ceil() * 1000000).toDouble(); // 1M increments
    } else if (value >= 200000) {
      return ((value / 200000).ceil() * 200000).toDouble(); // 200K increments
    } else if (value >= 10000) {
      return ((value / 10000).ceil() * 10000).toDouble(); // 10K increments
    } else if (value >= 1000) {
      return ((value / 1000).ceil() * 1000).toDouble(); // 1K increments
    } else {
      return ((value / 100).ceil() * 100).toDouble(); // 100 increments
    }
  }

  // Helper function to calculate points per hour for different time periods
  String _calculatePointsPerHour(
    List<dynamic> points,
    String period, [
    Map<String, dynamic>? eventInfo,
  ]) {
    if (points.isEmpty) return 'N/A';

    // Determine reference time: use event aggregate time if available and event has ended, otherwise current time
    DateTime referenceTime = DateTime.now();

    // For world link chapter rankings, get aggregate time from _worldBlooms
    if (_characterId != -1) {
      final worldBloom = _worldBlooms.firstWhere(
        (bloom) =>
            bloom['gameCharacterId'] == _characterId &&
            bloom['eventId'] == widget.eventId,
        orElse: () => <String, dynamic>{},
      );
      final chapterAggregateAt = worldBloom['aggregateAt'] as int?;
      if (chapterAggregateAt != null && chapterAggregateAt > 0) {
        referenceTime = DateTime.fromMillisecondsSinceEpoch(chapterAggregateAt);
      }
    } else if (eventInfo != null) {
      // For regular event rankings, use event aggregate time if event has ended
      final aggregateAt = eventInfo['aggregateAt'] as int?;
      if (aggregateAt != null && aggregateAt > 0) {
        referenceTime = DateTime.fromMillisecondsSinceEpoch(aggregateAt);
      }
    }
    if (referenceTime.isAfter(DateTime.now())) {
      referenceTime = DateTime.now();
    }

    List<dynamic> filteredPoints;

    switch (period) {
      case 'last_24_hours':
        final cutoff = referenceTime.subtract(const Duration(hours: 24));
        filteredPoints =
            points
                .where((p) => DateTime.parse(p['timestamp']).isAfter(cutoff))
                .toList();
        break;
      case 'last_1_hour':
        final cutoff = referenceTime.subtract(const Duration(hours: 1));
        filteredPoints =
            points
                .where((p) => DateTime.parse(p['timestamp']).isAfter(cutoff))
                .toList();
        break;
      default: // 'all_time'
        filteredPoints = points;
        break;
    }

    if (filteredPoints.length < 2) return 'N/A';

    // Sort by timestamp
    filteredPoints.sort(
      (a, b) => DateTime.parse(
        a['timestamp'],
      ).compareTo(DateTime.parse(b['timestamp'])),
    );

    final firstPoint = filteredPoints.first;
    final lastPoint = filteredPoints.last;

    final firstScore = (firstPoint['score'] as num).toDouble();
    final lastScore = (lastPoint['score'] as num).toDouble();
    final scoreGain = lastScore - firstScore;

    final firstTime = DateTime.parse(firstPoint['timestamp']);
    final lastTime = DateTime.parse(lastPoint['timestamp']);
    final timeDiffInHours =
        lastTime.difference(firstTime).inMilliseconds / (1000 * 60 * 60);

    if (timeDiffInHours <= 0) return 'N/A';

    final pointsPerHour = scoreGain / timeDiffInHours;

    // Show exact number instead of abbreviated format
    return '${pointsPerHour.round()}';
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
                    _characterId =
                        _isSelected[index] ? _worldBloomCharacters[index] : -1;
                  });
                },
                unit: _worldBloomUnit!,
              ),
            ),
          ),
        FutureBuilder<void>(
          future: fetchEventRanking(widget.eventId, _characterId),
          builder: (ctx, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snap.hasError) {
              return Center(child: Text('Error: ${snap.error}'));
            }
            if (snap.hasData) {
              _rankings = snap.data as List<Map<String, dynamic>>;
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
