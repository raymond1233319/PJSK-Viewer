import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/event_detail.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/pages/index.dart';
import 'package:pjsk_viewer/utils/database/event_database.dart';
import 'package:pjsk_viewer/utils/globals.dart';

class EventPage extends StatefulWidget {
  const EventPage({super.key});

  @override
  State<EventPage> createState() => _EventPageState();
}

class _EventPageState extends State<EventPage> {
  bool _isLoading = true;

  List<Map<String, dynamic>> _allEvents = [];

  // filter option
  final ScrollController _scrollController = ScrollController();

  final _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadEvents();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final events = await EventDatabase.getEventIndex();
      setState(() {
        _allEvents = events;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Widget buildEventItem(BuildContext context, Map<String, dynamic> event) {
    final localizations = ContentLocalizations.of(context);
    final eventId = event['id'] as int?;
    final originalName =
        event['name'] ??
        AppLocalizations.of(context).translate('unknown_event');

    LocalizedText? title = localizations?.translate(
      'event_name',
      eventId!.toString(),
    );
    final tranlatedName =
        AppGlobals.region == 'jp' ? title?.translated : title?.japanese;

    final assetbundleName = event['assetbundleName'] ?? '';
    final logoUrl =
        (assetbundleName != null && assetbundleName.isNotEmpty)
            ? "${AppGlobals.assetUrl}/event/$assetbundleName/logo/logo.webp"
            : null;
    final DateFormat formatter = DateFormat("dd/MM/yyyy HH:mm:ss");

    final String startDateStr = formatter.format(
      DateTime.fromMillisecondsSinceEpoch(event['startAt'] ?? 0).toLocal(),
    );
    final String endDateStr = formatter.format(
      DateTime.fromMillisecondsSinceEpoch(event['aggregateAt'] ?? 0).toLocal(),
    );

    String eventType = event['eventType'].toString();
    String eventTypeDisplay =
        localizations
            ?.translate('event', "type", innerKey: eventType)
            .translated ??
        eventType;

    final subTitleText =
        originalName != tranlatedName
            ? "${title!.translated}\n$eventTypeDisplay\n$startDateStr ~ \n$endDateStr"
            : "$eventTypeDisplay\n$startDateStr ~ \n$endDateStr\n";

    final Widget top = Stack(
      children: [
        logoUrl != null
            ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder:
                  (context, url) =>
                      const Center(child: CircularProgressIndicator()),
              errorWidget:
                  (context, url, error) => const Center(
                    child: Icon(Icons.broken_image, color: Colors.grey),
                  ),
            )
            : const Center(
              child: Icon(Icons.event, size: 50, color: Colors.grey),
            ),
        Positioned(
          top: 8,
          right: 8,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (event['unit'] != null && event['unit'] != 'none')
                Image.asset(
                  'assets/common/logo_mini/unit_ts_${event['unit']}.png',
                  width: 24,
                  height: 24,
                ),
              if (event['bonusAttr'] != null && event['bonusAttr'] != 'none')
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Image.asset(
                    'assets/icon_attribute_${event['bonusAttr']}.png',
                    width: 24,
                    height: 24,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
    return buildIndexItem<int>(
      context: context,
      id: eventId!,
      top: top,
      title: originalName,
      subtitle: subTitleText,
      pageBuilder: (id) => EventDetailPage(eventId: id),
      searchFocusNode: _searchFocusNode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);
    final title =
        localizations?.translate('common', "event").translated ?? 'Event';
    FilterOptions filterOptions = FilterOptions(context);
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : IndexPage<Map<String, dynamic>>(
          title: title,
          allItems: _allEvents,
          // enable the search bar
          showSearch: true,
          searchPredicate:
              (event, query) => (event['name'] as String)
                  .toLowerCase()
                  .contains(query.toLowerCase()),

          // two dropdown filters: unit and eventType
          filters: [
            FilterConfig<Map<String, dynamic>>(
              header:
                  localizations?.translate('common', 'unit').translated ??
                  'Unit',
              options: filterOptions.unitOptions,
              filterFunc: (event, selected) {
                return selected.contains(event['unit']);
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header:
                  localizations?.translate('common', 'type').translated ??
                  'Type',
              options: filterOptions.eventTypeOptions,
              filterFunc: (event, selected) {
                return selected.contains(event['eventType']);
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header:
                  localizations?.translate('common', 'attribute').translated ??
                  'Attribute',
              options: filterOptions.attributeOptions,
              filterFunc: (event, selected) {
                return selected.contains(event['bonusAttr']);
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header:
                  localizations?.translate('common', 'character').translated ??
                  'Character',
              options: filterOptions.characterOptions,
              filterFunc: (event, selected) {
                final characters =
                    (json.decode(event['bonusCharacter'] ?? '[]')
                        as List<dynamic>);
                return characters.any(
                  (character) => selected.contains(character.toString()),
                );
              },
            ),
          ],

          pageSize: 10,
          scrollController: _scrollController,

          // build each row
          itemBuilder: (context, event) => buildEventItem(context, event),

          searchFocusNode: _searchFocusNode,
        );
  }
}
