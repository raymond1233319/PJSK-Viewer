import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/index.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/pages/mysekai_fixture_detail.dart';
import 'package:pjsk_viewer/utils/cache_manager.dart';
import 'package:pjsk_viewer/utils/database/my_sekai_database.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pjsk_viewer/utils/globals.dart';

class MySekaiIndexPage extends StatefulWidget {
  const MySekaiIndexPage({super.key});

  @override
  State<MySekaiIndexPage> createState() => _MySekaiIndexPageState();
}

class _MySekaiIndexPageState extends State<MySekaiIndexPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allFixtures = [];
  List<Map<String, dynamic>>? _genres;
  List<Map<String, dynamic>>? _subGenres;
  List<Map<String, dynamic>>? _tags;

  final ScrollController _scrollController = ScrollController();
  final FocusNode _searchFocusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _loadFixtures();
  }

  Future<void> _loadFixtures() async {
    setState(() => _isLoading = true);
    try {
      _allFixtures = await MySekaiDatabase.getFixtureIndex();
      final pref = await SharedPreferences.getInstance();
      _genres =
          json
              .decode(pref.getString('mysekaiFixtureMainGenres') ?? '[]')
              .cast<Map<String, dynamic>>();
      _subGenres =
          json
              .decode(pref.getString('mysekaiFixtureSubGenres') ?? '[]')
              .cast<Map<String, dynamic>>();
      _tags =
          json
              .decode(pref.getString('mysekaiFixtureTags') ?? '[]')
              .cast<Map<String, dynamic>>();
    } catch (_) {
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildFixtureItem(BuildContext context, Map<String, dynamic> fixture) {
    final fixtureId = fixture['id']!;
    final localizedName = fixture['name'];
    final String fixtureAssetName = fixture['assetbundleName'] as String? ?? '';
    final String type = fixture['mysekaiFixtureType'];
    final String layoutType = fixture['mysekaiSettableLayoutType'];
    final String assetBaseUrl = '${AppGlobals.assetUrl}/mysekai/thumbnail';
    final thumbnailUrl =
        type != 'surface_appearance'
            ? '$assetBaseUrl/fixture/${fixtureAssetName}_1.webp'
            : '$assetBaseUrl/surface_appearance/$fixtureAssetName/tex_${fixtureAssetName}_${layoutType}_1.png';

    final String? genre =
        _genres?.firstWhere(
              (genre) => genre['id'] == fixture['mysekaiFixtureMainGenreId'],
              orElse: () => {'name': ''},
            )['name']
            as String?;

    final subTitleText = genre;
    final Widget top = CachedNetworkImage(
      cacheManager: PJSKImageCacheManager.instance,
      imageUrl: thumbnailUrl,
      fit: BoxFit.cover,
      placeholder: (_, __) => const Center(child: CircularProgressIndicator()),
      errorWidget: (_, __, ___) {
        return const Center(child: Icon(Icons.broken_image));
      },
    );
    return buildIndexItem<int>(
      context: context,
      id: fixtureId,
      top: top,
      title: localizedName,
      subtitle: subTitleText ?? '',
      pageBuilder: (id) => MysekaiFixtureDetailPage(fixtureId: id),
      searchFocusNode: _searchFocusNode,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    final title = AppLocalizations.of(context).translate('mysekai_fixture');

    final localizations = ContentLocalizations.of(context);
    final appLocalizations = AppLocalizations.of(context);

    final genreOptions =
        (_genres ?? [])
            .where(
              (g) => _allFixtures.any(
                (f) => f['mysekaiFixtureMainGenreId'] == g['id'],
              ),
            )
            .map(
              (g) => {
                'value': 'genre:${g['id']}',
                'display': g['name'].toString(),
              },
            )
            .toList()
            .cast<Map<String, String>>();

    final subGenreOptions =
        (_subGenres ?? [])
            .where(
              (g) => _allFixtures.any(
                (f) => f['mysekaiFixtureSubGenreId'] == g['id'],
              ),
            )
            .map(
              (g) => {
                'value': 'subgenre:${g['id']}',
                'display': g['name'].toString(),
              },
            )
            .toList()
            .cast<Map<String, String>>();

    final tagOptions =
        (_tags ?? [])
            .map(
              (g) => {
                'value': 'tag:${g['id']}',
                'display': g['name'].toString(),
              },
            )
            .toList()
            .cast<Map<String, String>>();

    FilterOptions filterOptions = FilterOptions(context);

    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : IndexPage<Map<String, dynamic>>(
          title: AppGlobals.i18n.translate('app', 'my_sekai').translated,
          allItems: _allFixtures,
          showSearch: true,
          searchPredicate:
              (fixture, query) => (fixture['name'] as String)
                  .toLowerCase()
                  .contains(query.toLowerCase()),
          filters: [
            FilterConfig<Map<String, dynamic>>(
              header: appLocalizations.translate('genre'),
              options: genreOptions,
              filterFunc: (fixture, selected) {
                final id = 'genre:${fixture['mysekaiFixtureMainGenreId']}';
                return selected.contains(id);
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header: appLocalizations.translate('sub_genre'),
              options: subGenreOptions,
              filterFunc: (fixture, selected) {
                final id = 'subgenre:${fixture['mysekaiFixtureSubGenreId']}';
                return selected.contains(id);
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header: appLocalizations.translate("tag"),
              options: tagOptions,
              filterFunc: (fixture, selected) {
                final Map<String, dynamic> tagList = json.decode(
                  fixture['mysekaiFixtureTagGroup'] ?? '{}',
                );
                for (final tag in tagList.entries) {
                  if (tag.key == 'id') continue;
                  final id = 'tag:${tag.value}';
                  if (selected.contains(id)) {
                    return true;
                  }
                }
                return false;
              },
              isDropdown: true,
            ),
            FilterConfig<Map<String, dynamic>>(
              header:
                  localizations?.translate('common', 'character').translated ??
                  'Character',
              options: filterOptions.characterOptions,
              filterFunc: (event, selected) {
                final characters =
                    (json.decode(event['characters'] ?? '[]') as List<dynamic>);
                return characters.any(
                  (character) => selected.contains(character.toString()),
                );
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header: appLocalizations.translate('is_enable_sketch'),
              options: [
                {
                  'value': 'sketch:true',
                  'display': appLocalizations.translate('yes'),
                },
                {
                  'value': 'sketch:false',
                  'display': appLocalizations.translate('no'),
                },
              ],
              filterFunc: (fixture, selected) {
                bool fixtureValue = fixture['isEnableSketch'] == 1;
                if (selected.contains('sketch:true')) return fixtureValue;
                if (selected.contains('sketch:false')) return !fixtureValue;
                return true; // Should not be reached if selected is not empty
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header: appLocalizations.translate('is_obtained_by_convert'),
              options: [
                {
                  'value': 'convert:true',
                  'display': appLocalizations.translate('yes'),
                },
                {
                  'value': 'convert:false',
                  'display': appLocalizations.translate('no'),
                },
              ],
              filterFunc: (fixture, selected) {
                bool fixtureValue = fixture['isObtainedByConvert'] == 1;
                if (selected.contains('convert:true')) return fixtureValue;
                if (selected.contains('convert:false')) return !fixtureValue;
                return true;
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header: appLocalizations.translate(
                'is_asssembled',
              ), // Note: "assembled" has two 's'
              options: [
                {
                  'value': 'asssemble:true',
                  'display': appLocalizations.translate('yes'),
                },
                {
                  'value': 'asssemble:false',
                  'display': appLocalizations.translate('no'),
                },
              ],
              filterFunc: (fixture, selected) {
                bool fixtureValue = fixture['isAssembled'] == 1;
                if (selected.contains('asssemble:true')) return fixtureValue;
                if (selected.contains('asssemble:false')) return !fixtureValue;
                return true;
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header: appLocalizations.translate('is_disassembled'),
              options: [
                {
                  'value': 'disassemble:true',
                  'display': appLocalizations.translate('yes'),
                },
                {
                  'value': 'disassemble:false',
                  'display': appLocalizations.translate('no'),
                },
              ],
              filterFunc: (fixture, selected) {
                bool fixtureValue = fixture['isDisassembled'] == 1;
                if (selected.contains('disassemble:true')) return fixtureValue;
                if (selected.contains('disassemble:false'))
                  return !fixtureValue;
                return true;
              },
            ),
          ],
          pageSize: 10,
          scrollController: _scrollController,
          itemBuilder: _buildFixtureItem,
          itemsPerRow: 2,
          searchFocusNode: _searchFocusNode,
        );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
