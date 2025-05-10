import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/about.dart';
import 'package:pjsk_viewer/pages/card_index.dart';
import 'package:pjsk_viewer/pages/event_tracker.dart';
import 'package:pjsk_viewer/pages/music_index.dart';
import 'package:pjsk_viewer/pages/mysekai_fixture_index.dart';
import 'package:pjsk_viewer/pages/setting.dart';
import 'package:pjsk_viewer/utils/database/database.dart';
import 'package:pjsk_viewer/utils/database/event_database.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:marquee/marquee.dart';
import 'package:flutter_timer_countdown/flutter_timer_countdown.dart';
import 'package:pjsk_viewer/pages/event_index.dart';
import 'package:pjsk_viewer/pages/event_detail.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/pages/gacha_index.dart';
import 'package:url_launcher/url_launcher.dart';

int? currentEventId;

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Widget _buildMenuItem(
    BuildContext context,
    IconData icon,
    String key,
    Widget page, {
    String? innerKey,
  }) {
    final halfWidth = MediaQuery.of(context).size.width / 2;
    final localizations = ContentLocalizations.of(context);
    final appLocalizations = AppLocalizations.of(context);
    String title =
        innerKey != null
            ? localizations
                    ?.translate('common', key, innerKey: innerKey)
                    .translated ??
                key
            : localizations?.translate('common', key).translated ?? key;
    if (title == '') {
      title = appLocalizations.translate(key);
    }
    return SizedBox(
      width: halfWidth,
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        onTap: () {
          Navigator.of(context).pop();
          Navigator.push(context, MaterialPageRoute(builder: (_) => page));
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 30.0),
              CurrentEvent(),
              NewsWidget(),
              VersionInfo(),
            ],
          ),
        ),
      ),
      // Menu button
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: Builder(
        builder:
            (context) => FloatingActionButton(
              backgroundColor: Colors.grey.shade200,
              child: const Icon(Icons.menu),
              onPressed: () {
                showModalBottomSheet(
                  context: context,
                  builder: (_) {
                    return Wrap(
                      children: [
                        _buildMenuItem(
                          context,
                          Icons.event,
                          'event',
                          const EventPage(),
                        ),
                        _buildMenuItem(
                          context,
                          Icons.rectangle_outlined,
                          'card',
                          const CardIndexPage(),
                        ),
                        _buildMenuItem(
                          context,
                          Icons.casino_outlined,
                          'gacha',
                          const GachaIndexPage(),
                        ),
                        _buildMenuItem(
                          context,
                          Icons.album,
                          'music',
                          const MusicIndexPage(),
                        ),
                        _buildMenuItem(
                          context,
                          Icons.show_chart,
                          'eventTracker',
                          const EventTrackerPage(),
                        ),
                        if (AppGlobals.region == 'jp')
                          _buildMenuItem(
                            context,
                            Icons.home,
                            'my_sekai',
                            const MySekaiIndexPage(),
                          ),
                        _buildMenuItem(
                          context,
                          Icons.settings,
                          'settings',
                          const SettingsPage(),
                          innerKey: 'title',
                        ),
                        _buildMenuItem(
                          context,
                          Icons.info_outline,
                          'about',
                          const AboutPage(),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
      ),
      bottomNavigationBar: SizedBox(
        height: 48.0,
        child: BottomAppBar(
          color: Colors.blueGrey,
          shape: const CircularNotchedRectangle(),
          notchMargin: 4.0,
        ),
      ),
    );
  }
}

/// CurrentEvent widget to display the current event
class CurrentEvent extends StatelessWidget {
  const CurrentEvent({super.key});

  Future<Map<String, dynamic>?> fetchCurrentEvent() async {
    try {
      return EventDatabase.getCurrentEvent();
    } catch (e) {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      final sharedEventJson = prefs.getString("current_event");
      if (sharedEventJson != null) {
        return json.decode(sharedEventJson) as Map<String, dynamic>;
      } else {
        throw Exception("Failed to load current event: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);
    return FutureBuilder<Map<String, dynamic>?>(
      future: fetchCurrentEvent(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        } else if (snapshot.hasError) {
          return Text("Error: ${snapshot.error}");
        } else if (snapshot.data == null) {
          return Text(
            localizations?.translate('event', 'alreadyEnded').translated ??
                "Event has ended",
            style: const TextStyle(fontSize: 20),
          );
        } else {
          final eventData = snapshot.data;
          final int eventId = eventData?['id'];
          final int endAt = eventData?['aggregateAt'];
          final eventName =
              eventData?['name'] ??
              AppLocalizations.of(context).translate('unknown_event');
          String localizedEventName =
              ContentLocalizations.of(
                context,
              )?.translate('event_name', eventId.toString()).combined ??
              eventName;
          final assetbundleName = eventData?['assetbundleName'] ?? '';
          final bannerUrl =
              "${AppGlobals.assetUrl}/home/banner/$assetbundleName/$assetbundleName.webp";

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Title
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
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            localizations
                                    ?.translate('common', 'ongoing_event')
                                    .translated ??
                                "Ongoing Event",
                            style: const TextStyle(fontSize: 20),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: SizedBox(
                              height: 24,
                              child: Marquee(
                                text: localizedEventName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                scrollAxis: Axis.horizontal,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                blankSpace: 20.0,
                                velocity: 50.0,
                                pauseAfterRound: const Duration(seconds: 1),
                                startPadding: 10.0,
                                accelerationDuration: const Duration(
                                  seconds: 1,
                                ),
                                accelerationCurve: Curves.linear,
                                decelerationDuration: const Duration(
                                  milliseconds: 500,
                                ),
                                decelerationCurve: Curves.easeOut,
                              ),
                            ),
                          ),
                        ],
                      ),
                      //  Banner
                      const SizedBox(height: 8),
                      if (assetbundleName.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (context) =>
                                        EventDetailPage(eventId: eventId),
                              ),
                            );
                          },
                          child: CachedNetworkImage(
                            imageUrl: bannerUrl,
                            placeholder:
                                (context, url) =>
                                    const CircularProgressIndicator(),
                            errorWidget:
                                (context, url, error) => const Icon(
                                  Icons.broken_image,
                                  size: 60,
                                  color: Colors.grey,
                                ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),

              // Timer
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
                      Text(
                        localizations!
                            .translate('event', "remainingTime")
                            .translated,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Divider(),
                      Center(
                        child: Transform.scale(
                          scale: 1.2,
                          child: TimerCountdown(
                            format:
                                CountDownTimerFormat.daysHoursMinutesSeconds,
                            endTime: DateTime.fromMillisecondsSinceEpoch(endAt),
                            onEnd:
                                () => Text(
                                  AppLocalizations.of(
                                    context,
                                  ).translate('event_has_ended'),
                                ),
                            daysDescription:
                                localizations
                                    .translate(
                                      'common',
                                      'countdown',
                                      innerKey: 'day',
                                    )
                                    .translated ??
                                'd',
                            hoursDescription:
                                localizations
                                    .translate(
                                      'common',
                                      'countdown',
                                      innerKey: 'hour',
                                    )
                                    .translated ??
                                'h',
                            minutesDescription:
                                localizations
                                    .translate(
                                      'common',
                                      'countdown',
                                      innerKey: 'minute',
                                    )
                                    .translated ??
                                'm',
                            secondsDescription:
                                localizations
                                    .translate(
                                      'common',
                                      'countdown',
                                      innerKey: 'second',
                                    )
                                    .translated ??
                                's',
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Live Ranking
              if (AppGlobals.region != 'cn')
                LiveRankingSelector(eventData: eventData),
            ],
          );
        }
      },
    );
  }
}

class LiveRankingSelector extends StatefulWidget {
  final Map<String, dynamic>? eventData;
  const LiveRankingSelector({super.key, required this.eventData});
  @override
  _LiveRankingSelectorState createState() => _LiveRankingSelectorState();
}

class _LiveRankingSelectorState extends State<LiveRankingSelector> {
  late Future<List<Map<String, dynamic>>> _ranking;
  TextEditingController? _controller;
  Map<String, dynamic>? _matchedEntry;
  int _chapterId = -1;

  @override
  void initState() {
    super.initState();
    _ranking = _fetchLiveRanking();
    _ranking.then((ranking) async {
      final prefs = await SharedPreferences.getInstance();
      final int stored = prefs.getInt('live_ranking_rank') ?? 1000;
      final nearest = ranking.reduce((a, b) {
        return (((a['rank'] as int) - stored).abs() <
                ((b['rank'] as int) - stored).abs())
            ? a
            : b;
      });
      _controller = TextEditingController(text: stored.toString());
      setState(() => _matchedEntry = nearest);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchLiveRanking() async {
    if (widget.eventData?['eventType'] == "world_bloom" &&
        AppGlobals.region == 'jp') {
      final pref = await SharedPreferences.getInstance();
      List<dynamic> worldBlooms = json.decode(
        pref.getString('worldBlooms') ?? '[]',
      );
      for (var bloom in worldBlooms) {
        final startAt = bloom['chapterStartAt'] as int;
        final endAt = bloom['chapterEndAt'] as int;
        final now = DateTime.now().millisecondsSinceEpoch;

        if (now >= startAt && now <= endAt) {
          _chapterId = bloom['gameCharacterId'] as int;
          break;
        }
      }
    }
    return fetchEventRanking(widget.eventData?['id'], _chapterId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ranking,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snap.hasError) {
          return SizedBox.shrink();
        }
        final ranking = snap.data ?? [];
        if (ranking.isEmpty) {
          return const Text('No live ranking data.');
        }
        final localizations = ContentLocalizations.of(context);
        return Card(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.start,
                    children: [
                      Text(
                        localizations!
                            .translate('common', "eventTracker")
                            .translated,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (_chapterId != -1)
                        Padding(
                          padding: const EdgeInsets.only(left: 8.0),
                          child: DetailBuilder.buildSingleCharacterDisplay(
                            _chapterId,
                          ),
                        ),
                      Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        onPressed: () async {
                          setState(() {
                            _ranking = _fetchLiveRanking();
                          });
                        },
                      ),
                    ],
                  ),

                  const Divider(),

                  // Input row with leading '#'
                  Row(
                    children: [
                      const Text('#', style: TextStyle(fontSize: 16)),
                      const SizedBox(width: 4),
                      Expanded(
                        child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onSubmitted: (val) async {
                            final desired = int.tryParse(val);
                            if (desired != null) {
                              final nearest = ranking.reduce((a, b) {
                                return (((a['rank'] as int) - desired).abs() <
                                        ((b['rank'] as int) - desired).abs())
                                    ? a
                                    : b;
                              });
                              setState(() {
                                _controller?.text =
                                    (nearest['rank'] as int).toString();
                                _matchedEntry = nearest;
                              });
                              final prefs =
                                  await SharedPreferences.getInstance();
                              await prefs.setInt(
                                'live_ranking_rank',
                                nearest['rank'] as int,
                              );
                            }
                          },
                        ),
                      ),
                      if (_matchedEntry != null) ...[
                        const SizedBox(width: 12),
                        Text(
                          '${_matchedEntry!['score']} P',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_matchedEntry != null) ...[
                    Text(
                      "${ContentLocalizations.of(context)?.translate('event', 'realtime').translated}: "
                      "${formatDate(DateTime.parse(_matchedEntry!['timestamp']).millisecondsSinceEpoch)}",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// VersionInfo widget to display version information
class VersionInfo extends StatefulWidget {
  const VersionInfo({super.key});

  @override
  State<VersionInfo> createState() => _VersionInfoState();
}

class _VersionInfoState extends State<VersionInfo> {
  Map<String, dynamic>? _versionData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadVersionInfo();
  }

  Future<void> _loadVersionInfo() async {
    try {
      final response = await http.get(
        Uri.parse("${AppGlobals.databaseUrl}/versions.json"),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        setState(() {
          _versionData = data;
          _isLoading = false;
        });
        final prefs = await SharedPreferences.getInstance();
        final storedVersion = prefs.getString('data_version');
        final newVersion = data['dataVersion']?.toString() ?? '';
        if (storedVersion != null && storedVersion != newVersion) {
          // prompt user to update
          WidgetsBinding.instance.addPostFrameCallback((_) {
            showDialog(
              context: context,
              builder:
                  (context) => AlertDialog(
                    title: Text(
                      AppLocalizations.of(
                        context,
                      ).translate('update_available'),
                    ),
                    content: Text(
                      AppLocalizations.of(
                        context,
                      ).translate('update_available_content'),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          AppLocalizations.of(context).translate('later'),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                          updateDatabase(context);
                        },
                        child: Text(
                          AppLocalizations.of(context).translate('update_now'),
                        ),
                      ),
                    ],
                  ),
            );
          });
        }
      } else {
        _loadFallbackVersionInfo();
      }
    } catch (e) {
      _loadFallbackVersionInfo();
    }
  }

  Future<void> _loadFallbackVersionInfo() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    final storedData = prefs.getString("version_info");

    if (storedData != null) {
      setState(() {
        _versionData = json.decode(storedData);
        _isLoading = false;
      });
    } else {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget _buildVersionRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Text(value),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const CircularProgressIndicator();
    }
    final localizations = ContentLocalizations.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations
                      ?.translate('home', "versionInfo", innerKey: "caption")
                      .translated ??
                  'Version Info',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            _buildVersionRow(
              localizations
                      ?.translate(
                        'home',
                        "versionInfo",
                        innerKey: "gameClientVer",
                      )
                      .translated ??
                  'Game Client Version',
              _versionData?['appVersion'] ?? '',
            ),
            _buildVersionRow(
              localizations
                      ?.translate('home', "versionInfo", innerKey: "dataVer")
                      .translated ??
                  'Data Version',
              _versionData?['dataVersion'] ?? '',
            ),
            _buildVersionRow(
              localizations
                      ?.translate('home', "versionInfo", innerKey: "assetVer")
                      .translated ??
                  'Asset Version',
              _versionData?['assetVersion'] ?? '',
            ),
            _buildVersionRow(
              localizations
                      ?.translate(
                        'home',
                        "versionInfo",
                        innerKey: "multiPlayerVer",
                      )
                      .translated ??
                  'Multiplayer Version',
              _versionData?['multiPlayVersion'] ?? '',
            ),
          ],
        ),
      ),
    );
  }
}

// --- News Widget ---
class NewsWidget extends StatefulWidget {
  const NewsWidget({super.key});

  @override
  State<NewsWidget> createState() => _NewsWidgetState();
}

class _NewsWidgetState extends State<NewsWidget> {
  List<Map<String, dynamic>> _newsItems = [];
  bool _isLoading = true;
  String? _errorMessage;
  int _displayCount = 5; // Current number of items to show
  final int _displayIncrement = 5; // Number of items to add per click

  @override
  void initState() {
    super.initState();
    _fetchNews();
  }

  Future<void> _fetchNews() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      final response = await http.get(
        Uri.parse('${AppGlobals.databaseUrl}/userInformations.json'),
      );
      if (response.statusCode == 200) {
        final List<dynamic> decodedData = json.decode(response.body);
        _newsItems =
            decodedData
                .where(
                  (item) =>
                      item is Map<String, dynamic> &&
                      item['title'] != null &&
                      item['title'].isNotEmpty,
                )
                .map((item) => item as Map<String, dynamic>)
                .toList()
              ..sort((a, b) {
                // rank purely by displayOrder (higher first)
                final orderA = a['displayOrder'] as int? ?? 0;
                final orderB = b['displayOrder'] as int? ?? 0;
                return orderB.compareTo(orderA);
              });
      } else {
        throw Exception('Failed to load news (${response.statusCode})');
      }
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // Helper to format the subtitle string
  String _formatSubtitle(localizations, Map<String, dynamic> item) {
    final tag = item['informationTag'] as String? ?? 'unknown';
    final startAt = item['startAt'] as int?;
    final endAt = item['endAt'] as int?;

    String dateString = startAt != null ? formatDate(startAt) : 'N/A';

    if (endAt != null) {
      // Only show end date if it's different from start date (ignoring time part for simplicity here)
      final startDate = DateTime.fromMillisecondsSinceEpoch(startAt ?? 0);
      final endDate = DateTime.fromMillisecondsSinceEpoch(endAt);
      if (endDate.year != startDate.year ||
          endDate.month != startDate.month ||
          endDate.day != startDate.day) {
        dateString += ' - ${formatDate(endAt)}';
      }
    }
    return '${localizations?.translate('common', tag).translated}\n$dateString';
  }

  // Function to handle tapping on a news item
  Future<void> _launchNewsUrl(String path, String browseType) async {
    Uri? uri;
    // Handle truly external links
    if (browseType == 'external') {
      uri = Uri.tryParse(path);
    } else {
      uri = Uri.tryParse('${AppGlobals.newsUrl}$path');
    }
    developer.log('Launching URL: $uri');
    if (uri != null) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);
    final count = min(_newsItems.length, _displayCount);
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations!
                  .translate('home', 'game-news', innerKey: 'title')
                  .translated,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Divider(),
            if (_isLoading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_errorMessage != null)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Error: $_errorMessage',
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              )
            else
              Column(
                children: List.generate(count, (index) {
                  final item = _newsItems[index];
                  return Column(
                    children: [
                      ListTile(
                        title: Text(
                          item['title'] as String? ?? 'No Title',
                          maxLines: 5,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(_formatSubtitle(localizations, item)),
                        dense: true,
                        onTap:
                            () => _launchNewsUrl(
                              item['path'] ?? '',
                              item['browseType'] ?? '',
                            ),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      ),
                      if (index < count - 1) const Divider(height: 1),
                    ],
                  );
                }),
              ),

            // "More" and "Less" buttons
            Align(
              alignment: Alignment.centerRight,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_displayCount > _displayIncrement)
                    IconButton(
                      icon: const Icon(Icons.expand_less),
                      onPressed: () {
                        setState(() {
                          // decrement by _displayIncrement, down to at least _displayIncrement
                          _displayCount =
                              (_displayCount - _displayIncrement) <
                                      _displayIncrement
                                  ? _displayIncrement
                                  : (_displayCount - _displayIncrement);
                        });
                      },
                    ),
                  if (_newsItems.length > _displayIncrement)
                    IconButton(
                      icon: const Icon(Icons.expand_more),
                      onPressed: () {
                        setState(() {
                          // extend by _displayIncrement, up to total
                          _displayCount = (_displayCount + _displayIncrement)
                              .clamp(0, _newsItems.length);
                        });
                      },
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
