import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/database/my_sekai_database.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/image_selector.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pjsk_viewer/utils/globals.dart';

class MysekaiFixtureDetailPage extends StatefulWidget {
  final int fixtureId;
  const MysekaiFixtureDetailPage({super.key, required this.fixtureId});

  @override
  State<MysekaiFixtureDetailPage> createState() =>
      _MysekaiFixtureDetailPageState();
}

class _MysekaiFixtureDetailPageState extends State<MysekaiFixtureDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _fixture;
  List<Map<String, dynamic>>? _genres;
  List<Map<String, dynamic>>? _subGenres;
  List<Map<String, dynamic>> _materials = [];
  List<Map<String, dynamic>>? _tags;

  @override
  void initState() {
    super.initState();
    _loadFixture();
  }

  Future<void> _loadFixture() async {
    try {
      _fixture = await MySekaiDatabase.getFixtureById(widget.fixtureId);
      final pref = await SharedPreferences.getInstance();
      _genres =
          json
              .decode(pref.getString('mysekaiFixtureMainGenres') ?? '[]')
              .cast<Map<String, dynamic>>();
      _subGenres =
          json
              .decode(pref.getString('mysekaiFixtureSubGenres') ?? '[]')
              .cast<Map<String, dynamic>>();
      _materials = await MySekaiDatabase.getAllMaterials();
      _tags =
          json
              .decode(pref.getString('mysekaiFixtureTags') ?? '[]')
              .cast<Map<String, dynamic>>();
      setState(() => _isLoading = false);
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_fixture == null) {
      return Center(
        child: Text(AppLocalizations.of(context).translate('error_loading')),
      );
    }

    final appLocalizations = AppLocalizations.of(context);
    final localizations = ContentLocalizations.of(context)!;
    final fixtureId = _fixture!['id'];
    final localizedName = _fixture!['name'];
    final String fixtureAssetName =
        _fixture!['assetbundleName'] as String? ?? '';
    final String type = _fixture!['mysekaiFixtureType'];
    final String layoutType = _fixture!['mysekaiSettableLayoutType'];
    final String assetBaseUrl = '${AppGlobals.assetUrl}/mysekai/thumbnail';
    final thumbnailUrl =
        type != 'surface_appearance'
            ? '$assetBaseUrl/fixture/${fixtureAssetName}_1.webp'
            : '$assetBaseUrl/surface_appearance/$fixtureAssetName/tex_${fixtureAssetName}_${layoutType}_1.png';
    final Map<String, int> gridSize =
        json.decode(_fixture!['gridSize']).cast<String, int>();

    final String? genre =
        _genres?.firstWhere(
              (genre) => genre['id'] == _fixture!['mysekaiFixtureMainGenreId'],
              orElse: () => {'name': ''},
            )['name']
            as String?;

    final String? subGenre =
        _subGenres?.firstWhere(
              (genre) => genre['id'] == _fixture!['mysekaiFixtureSubGenreId'],
              orElse: () => {'name': ''},
            )['name']
            as String?;

    final Map<String, dynamic> tagList = json.decode(
      _fixture!['mysekaiFixtureTagGroup'] ?? '{}',
    );
    List<String> tagNameList = [];
    for (final tag in _tags ?? []) {
      for (final tagId in tagList.entries) {
        if (tagId.key == 'id') continue;
        if (tagId.value == tag['id']) {
          tagNameList.add(tag['name']);
        }
      }
    }

    return Scaffold(
      appBar: DetailBuilder.buildAppBar(context, localizedName),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Image Section
            MultiImageSelector(
              options: [
                MultiImageOption(
                  label: localizations.translate('common', 'thumb').translated,
                  imageUrl: thumbnailUrl,
                ),
              ],
            ),

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
                    // Title
                    DetailBuilder.buildTextRow(
                      localizations.translate('common', "title").translated,
                      localizedName,
                    ),
                    // ID
                    DetailBuilder.buildTextRow(
                      localizations.translate('common', "id").translated,
                      fixtureId.toString(),
                    ),

                    //Size
                    DetailBuilder.buildTextRow(
                      appLocalizations.translate('size'),
                      '${gridSize['width']} x ${gridSize['depth']}',
                    ),

                    // Genre
                    DetailBuilder.buildTextRow(
                      appLocalizations.translate('genre'),
                      genre ?? '',
                    ),

                    if (subGenre != '')
                      DetailBuilder.buildTextRow(
                        appLocalizations.translate('sub_genre'),
                        subGenre ?? '',
                      ),
                    if (_fixture?['materialCost'] != null)
                      DetailBuilder.buildDetailRowWithWidgets(
                        appLocalizations.translate("cost"),
                        (json.decode(_fixture!['materialCost']) as List)
                            .map<Widget>(
                              (cost) => DetailBuilder.buildResourceIcon(
                                context: context,
                                resourceType: 'mysekai_material',
                                resourceId: cost['mysekaiMaterialId'],
                                mySekaiMaterials: _materials,
                                quantity: cost['quantity'],
                              ),
                            )
                            .toList(),
                      ),

                    DetailBuilder.buildCharactersWidget(
                      localizations.translate('common', 'character').translated,
                      _fixture!['characters'] ?? '[]',
                    ),

                    DetailBuilder.buildTextList(
                      appLocalizations.translate("tag"),
                      tagNameList,
                    ),

                    DetailBuilder.buildBoolRow(
                      appLocalizations.translate('is_enable_sketch'),
                      _fixture!['isEnableSketch'] == 1,
                    ),

                    DetailBuilder.buildBoolRow(
                      appLocalizations.translate('is_obtained_by_convert'),
                      _fixture!['isObtainedByConvert'] == 1,
                    ),

                    DetailBuilder.buildBoolRow(
                      appLocalizations.translate('is_asssembled'),
                      _fixture!['isAssembled'] == 1,
                    ),

                    DetailBuilder.buildBoolRow(
                      appLocalizations.translate('is_disassembled'),
                      _fixture!['isDisassembled'] == 1,
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
