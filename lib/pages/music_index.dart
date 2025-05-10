import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/index.dart';
import 'package:pjsk_viewer/pages/music_detail.dart';
import 'package:pjsk_viewer/utils/database/music_database.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/globals.dart';
class MusicIndexPage extends StatefulWidget {
  const MusicIndexPage({super.key});

  @override
  State<MusicIndexPage> createState() => _MusicIndexPageState();
}

class _MusicIndexPageState extends State<MusicIndexPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _musicItems = [];
  final ScrollController _scrollController = ScrollController();
  List<String> _outsideCharacterNames = [];
  List<Map<String, String>> _outsideCharacterOptions = [];
  List<Map<String, String>> _gameCharacterOptions = [];
  List<Map<String, String>> _characterOptions = [];
  List<Map<String, String>> _lyricistOptions = [];
  List<Map<String, String>> _composerOptions = [];
  List<Map<String, String>> _arrangerOptions = [];

  @override
  void initState() {
    super.initState();
    _loadMusicItems();
  }

  /// helper: build contributor options for a given role
  Future<List<Map<String, String>>> _getContributorOptions(String role) async {
    final names =
        _musicItems
            .where((m) => m[role] != null)
            .map((m) => m[role] as String)
            .where((s) => s.isNotEmpty)
            .toSet();
    return names
        .map((name) => {'display': name, 'value': '$role:$name'})
        .toList();
  }

  Future<void> _loadMusicItems() async {
    setState(() => _isLoading = true);
    try {
      _musicItems = await MusicDatabase.getMusicIndex();
      _outsideCharacterNames = await MusicDatabase.getOutsideCharacterNames();
      _outsideCharacterOptions =
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

      final localizations = ContentLocalizations.of(context);

      // build 26 game_character options
      _gameCharacterOptions = List.generate(26, (i) {
        final id = i + 1;
        final idStr = id.toString();
        final first =
            localizations
                ?.translate('character_name', idStr, innerKey: 'firstName')
                .translated ??
            '';
        final last =
            localizations
                ?.translate('character_name', idStr, innerKey: 'givenName')
                .translated ??
            '';
        return {
          'display': '$first $last'.trim(),
          'value': 'game_character:$id',
        };
      });

      _characterOptions = [
        ..._gameCharacterOptions,
        ..._outsideCharacterOptions,
      ];

      final futures = [
        _getContributorOptions('lyricist'),
        _getContributorOptions('composer'),
        _getContributorOptions('arranger'),
      ];
      final resultsLists = await Future.wait(futures);
      _lyricistOptions = resultsLists[0];
      _composerOptions = resultsLists[1];
      _arrangerOptions = resultsLists[2];
    } catch (e) {
      _musicItems = [];
      developer.log('Failed to load music items: $e', name: 'MusicIndexPage');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildMusicItem(BuildContext context, Map<String, dynamic> musicData) {
    final musicId = musicData['id']!;
    final title =
        musicData['title'] as String? ??
        AppLocalizations.of(context).translate('unknown_music');
    final subTitleText = '';
    final assetbundleName = musicData['assetbundleName'] as String? ?? '';
    final logoUrl =
        assetbundleName.isNotEmpty
            ? '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/$assetbundleName.webp'
            : '';
    final top = CachedNetworkImage(
      imageUrl: logoUrl,
      fit: BoxFit.cover,
      placeholder:
          (context, url) => const Center(child: CircularProgressIndicator()),
      errorWidget:
          (context, url, error) =>
              const Center(child: Icon(Icons.broken_image, color: Colors.grey)),
    );

    return buildIndexItem<int>(
      context: context,
      id: musicId,
      top: top,
      title: title,
      pageBuilder: (id) => MusicDetailPage(musicId: id),
      aspectRatio: 4 / 3,
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        ContentLocalizations.of(
          context,
        )?.translate('common', 'music').translated ??
        'Music';

    final localizations = ContentLocalizations.of(context);

    FilterOptions filterOptions = FilterOptions(context);

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : IndexPage<Map<String, dynamic>>(
          title: title,
          allItems: _musicItems,
          showSearch: true,
          searchPredicate:
              (musicData, query) => (musicData['title'] as String)
                  .toLowerCase()
                  .contains(query.toLowerCase()),
          filters: [
            FilterConfig<Map<String, dynamic>>(
              header:
                  localizations
                      ?.translate('filter', 'music_tag', innerKey: 'caption')
                      .translated ??
                  "Song tag",
              options: filterOptions.songTags,
              filterFunc: (music, selected) {
                final tagList = json.decode(music['tags'] ?? '[]');
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
                final vocals = json.decode(music['vocals'] ?? '[]');
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
                  localizations
                      ?.translate('filter', 'music_mv', innerKey: 'caption')
                      .translated ??
                  "MV Type",
              options: filterOptions.mvTypeOptions,
              isDropdown: false,
              filterFunc: (music, selected) {
                final mvTypes = json.decode(music['categories'] ?? '[]');
                for (final mvType in mvTypes) {
                  if (selected.contains(mvType)) return true;
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
          ],
          pageSize: 10,
          scrollController: _scrollController,
          itemBuilder: _buildMusicItem,
        );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
