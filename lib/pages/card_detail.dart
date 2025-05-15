import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/utils/database/card_database.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/image_selector.dart';
import 'package:pjsk_viewer/utils/audio_player.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

class CardDetailPage extends StatefulWidget {
  final int cardId;
  final bool showTrainedImage;

  const CardDetailPage({
    required this.cardId,
    this.showTrainedImage = false,
    super.key,
  });

  @override
  State<CardDetailPage> createState() => _CardDetailPageState();
}

class _CardDetailPageState extends State<CardDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _cardData;
  String? _errorMessage;
  final BasicAudioService _audioService = BasicAudioService();
  String? _audioUrl; // Store the audio URL
  List<Map<String, dynamic>>? _skillsDetail;
  final ValueNotifier<int> _skillLevel = ValueNotifier<int>(1);
  final ValueNotifier<int> _characterRank = ValueNotifier<int>(1);

  Future<void> _fetchCardDetails() async {
    if (!mounted) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      Map<String, dynamic>? results = await CardDatabase.getCardById(
        widget.cardId,
      );

      if (!mounted) return; // Check again before setting state
      final assetbundleName = results?['assetbundleName'] ?? '';
      final audioUrl =
          "${AppGlobals.jpAssetUrl}/sound/gacha/get_voice/$assetbundleName/$assetbundleName.mp3";
      if (results != null) {
        setState(() {
          _audioUrl = audioUrl;
          _cardData = results;
          _isLoading = false;
        });
      }
    } catch (e) {
      _errorMessage = 'Error fetching card details: $e';
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchSkillsDetail() async {
    final prefs = await SharedPreferences.getInstance();
    final skillsJson = prefs.getString('skills');
    if (skillsJson == null) {
      // no data in prefs
      return;
    }
    final List<dynamic> decoded = json.decode(skillsJson);
    setState(() {
      _skillsDetail = decoded.cast<Map<String, dynamic>>();
    });
  }

  @override
  void initState() {
    super.initState();
    _fetchCardDetails();
    _fetchSkillsDetail();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);
    final appLocalizations = AppLocalizations.of(context);
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(
            _errorMessage!,
            style: const TextStyle(color: Colors.red),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    if (_cardData == null) {
      return Center(
        child: Text(appLocalizations.translate('card_data_unavailable')),
      );
    }

    LocalizedText? displayCardName;
    LocalizedText gachaPhrase;
    String id = widget.cardId.toString();
    String normalUrl = '';
    String trainedUrl = '';
    String? cardRarity;
    String? characterId;
    LocalizedText? characterName;
    List<String>? costumesUrls;
    List<dynamic>? episodes;

    bool isNotJP = AppGlobals.region != 'jp';
    displayCardName = localizations?.translate('card_prefix', id);
    gachaPhrase = localizations!.translate('card_gacha_phrase', id);
    if (isNotJP) {
      displayCardName = replaceMainText(displayCardName!, _cardData!['prefix']);
      gachaPhrase = replaceMainText(gachaPhrase, _cardData!['gachaPhrase']);
    }

    // Determine image URLs
    final String assetbundleName = _cardData!['assetbundleName'];
    normalUrl =
        "${AppGlobals.jpAssetUrl}/character/member/$assetbundleName/card_normal.webp";
    trainedUrl =
        "${AppGlobals.jpAssetUrl}/character/member/$assetbundleName/card_after_training.webp";
    cardRarity = _cardData!['cardRarityType'];
    characterId = _cardData!['characterId'].toString();
    characterName = getLocalizedCharacterName(localizations!, characterId);
    if (_cardData?['costumes'] != null) {
      final List<dynamic> decoded =
          json.decode(_cardData!['costumes']) as List<dynamic>;
      final Map<String, int> counts = {};
      costumesUrls =
          decoded.map<String>((name) {
            final strName = name.toString();
            counts[strName] = (counts[strName] ?? 0) + 1;
            var adjustedName = strName;
            if (strName.endsWith('_head') && counts[strName]! > 1) {
              adjustedName = strName.replaceFirst('_head', '_unique_head');
            }
            if (strName.endsWith('_unique_head') && counts[strName]! > 1) {
              adjustedName = strName.replaceFirst('_head', '_head');
            }
            return '${AppGlobals.jpAssetUrl}/thumbnail/costume/$adjustedName.webp';
          }).toList();
    }
    episodes = json.decode(_cardData?['cardEpisodes'] ?? "[]") as List<dynamic>;
    int skillId = _cardData?['skillId'] ?? 0;
    final String? descriptionTemplate =
        localizations?.translate('skill_desc', skillId.toString()).translated;

    LocalizedText skillName = localizations!.translate('card_skill_name', id);
    if (isNotJP) {
      skillName = replaceMainText(skillName, _cardData!['cardSkillName']);
    }
    return Scaffold(
      appBar: DetailBuilder.buildAppBar(context, displayCardName?.japanese),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DetailBuilder.buildCard(
              children: [
                Column(
                  children: [
                    MultiImageSelector(
                      options: [
                        if (_cardData!['initialSpecialTrainingStatus'] !=
                            'done')
                          MultiImageOption(
                            label:
                                localizations
                                    ?.translate(
                                      'card',
                                      "tab",
                                      innerKey: "title[0]",
                                    )
                                    .translated ??
                                'Normal image',
                            imageUrl: normalUrl,
                          ),
                        if (_cardData!['specialTrainingCosts'] != '[]' ||
                            _cardData!['initialSpecialTrainingStatus'] ==
                                'done')
                          MultiImageOption(
                            label:
                                localizations
                                    ?.translate(
                                      'card',
                                      "tab",
                                      innerKey: "title[2]",
                                    )
                                    .translated ??
                                'After training image',
                            imageUrl: trainedUrl,
                          ),
                      ],
                      startPosition: widget.showTrainedImage ? 1 : 0,
                    ),
                  ],
                ),

                //Gacha Phrase
                if (gachaPhrase.japanese.isNotEmpty &&
                    gachaPhrase.japanese != '-')
                  DetailBuilder.buildGachaPhase(gachaPhrase, _audioUrl ?? ''),
              ],
            ),

            // Image Selector
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
                    //Id
                    DetailBuilder.buildTextRow(
                      localizations?.translate('common', 'id').translated ??
                          'ID',
                      widget.cardId.toString(),
                    ),

                    // title
                    DetailBuilder.buildLocalizedTextRow(
                      localizations?.translate('common', 'title').translated ??
                          'Title',
                      displayCardName!,
                    ),

                    // Character
                    if (characterId != null)
                      DetailBuilder.buildLocalizedTextRow(
                        localizations
                                ?.translate('common', 'character')
                                .translated ??
                            'Character',
                        characterName!,
                        trailing: DetailBuilder.buildCharacterIcon(characterId),
                        isSwaped: isNotJP,
                      ),

                    // Unit
                    DetailBuilder.buildDetailRowWithAsset(
                      localizations?.translate('common', 'unit').translated ??
                          'Unit',
                      [
                        'assets/${AppGlobals.region}/logol/logo_${_cardData!['unit']}.png',
                      ],
                    ),

                    // Support Unit
                    if (_cardData!['supportUnit'] != 'none')
                      DetailBuilder.buildDetailRowWithAsset(
                        localizations
                                ?.translate('common', 'support_unit')
                                .translated ??
                            'Support Unit',
                        [
                          'assets/${AppGlobals.region}/logol/logo_${_cardData!['supportUnit']}.png',
                        ],
                      ),

                    // Attribute
                    DetailBuilder.buildDetailRowWithAsset(
                      localizations
                              ?.translate('common', 'attribute')
                              .translated ??
                          'Attribute',
                      ['assets/icon_attribute_${_cardData!['attr']}.png'],
                    ),

                    // Event
                    if (_cardData!['event'] != null)
                      DetailBuilder.buildEventThumbnail(
                        context,
                        _cardData!['eventId'],
                        _cardData!['event']['assetbundleName'],
                      ),

                    // Release Date
                    DetailBuilder.buildTextRow(
                      localizations
                              ?.translate('common', 'startAt')
                              .translated ??
                          'Available From',
                      formatDate(_cardData!['releaseAt']),
                    ),

                    // Rarity
                    DetailBuilder.buildDetailRowWithAsset(
                      localizations?.translate('card', 'rarity').translated ??
                          'Rarity',
                      ['assets/$cardRarity.png'],
                    ),

                    // Training cost
                    if (_cardData!['specialTrainingCosts'] != '[]')
                      DetailBuilder.buildDetailRow(
                        AppLocalizations.of(context).translate('train_cost'),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children:
                              json
                                  .decode(_cardData!['specialTrainingCosts'])
                                  .map<Widget>(
                                    (entry) => DetailBuilder.buildResourceItem(
                                      entry['cost'],
                                    ),
                                  )
                                  .toList(),
                        ),
                      ),

                    // Type
                    if (_cardData?['gachaType'] != null)
                      DetailBuilder.buildTextRow(
                        localizations?.translate('common', 'type').translated ??
                            'Type',
                        appLocalizations.translate(_cardData?['gachaType']),
                      ),

                    // Thumbnail
                    DetailBuilder.buildCardThumbnailRow(
                      context,
                      localizations?.translate('common', 'thumb').translated ??
                          'Thumbnail',
                      _cardData,
                    ),

                    // Skill
                    Text(
                      localizations?.translate('card', "skill").translated ??
                          'Skill',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Toggle bar for skillLevel
                        ValueListenableBuilder<int>(
                          valueListenable: _skillLevel,
                          builder: (context, level, _) {
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  localizations
                                          ?.translate('card', 'skillLevel')
                                          .translated ??
                                      'Skill Level',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ToggleButtons(
                                  isSelected: List.generate(
                                    4,
                                    (index) => level == index + 1,
                                  ),
                                  onPressed:
                                      (index) => _skillLevel.value = index + 1,
                                  children: List.generate(
                                    4,
                                    (i) => Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      child: Text('${i + 1}'),
                                    ),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 8),
                        const Divider(height: 5, thickness: 1),

                        // Character Rank input
                        if (skillId == 23)
                          ValueListenableBuilder<int>(
                            valueListenable: _characterRank,
                            builder: (context, rank, _) {
                              return Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    localizations
                                            ?.translate(
                                              'common',
                                              'characterRank',
                                            )
                                            .translated ??
                                        'Character Rank',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 80,
                                    child: TextFormField(
                                      initialValue: '$rank',
                                      keyboardType: TextInputType.number,
                                      decoration: const InputDecoration(
                                        border: OutlineInputBorder(),
                                        isDense: true,
                                        contentPadding: EdgeInsets.symmetric(
                                          vertical: 8,
                                          horizontal: 8,
                                        ),
                                      ),
                                      onChanged: (value) {
                                        final v = int.tryParse(value) ?? rank;
                                        if (v >= 1 && v <= 100) {
                                          _characterRank.value = v;
                                        }
                                      },
                                    ),
                                  ),
                                ],
                              );
                            },
                          ),
                        if (skillId == 23)
                          const Divider(height: 5, thickness: 1),

                        // Skill Name
                        DetailBuilder.buildLocalizedTextRow(
                          localizations
                                  ?.translate('card', 'skillName')
                                  .translated ??
                              'Skill Name',
                          skillName,
                        ),

                        // Skill Description (reacts to _skillLevel.value)
                        ValueListenableBuilder<int>(
                          valueListenable: _skillLevel,
                          builder: (context, level, _) {
                            return DetailBuilder.buildTextRow(
                              localizations
                                      ?.translate('card', 'skillEffect')
                                      .translated ??
                                  'Skill Effect',
                              generateSkillDescription(
                                descriptionTemplate: descriptionTemplate ?? '',
                                skillsJson: _skillsDetail ?? [],
                                skillId: skillId,
                                skillLevel: level,
                              ),
                            );
                          },
                        ),

                        // Special Training Skill Name
                        if (_cardData!['specialTrainingSkillId'] != null)
                          DetailBuilder.buildTextRow(
                            '${localizations?.translate('card', 'skillName').translated ?? 'Skill Name'}'
                            ' (${localizations?.translate('card', 'trained').translated ?? 'Trained'})',
                            _cardData!['specialTrainingSkillName'],
                          ),

                        // Special Training Skill Description (reacts to both _skillLevel and _characterRank)
                        if (_cardData!['specialTrainingSkillId'] != null)
                          AnimatedBuilder(
                            animation: Listenable.merge([
                              _skillLevel,
                              _characterRank,
                            ]),
                            builder: (context, _) {
                              final level = _skillLevel.value;
                              final rank = _characterRank.value;
                              return DetailBuilder.buildTextRow(
                                '${localizations?.translate('card', 'skillEffect').translated ?? 'Skill Effect'}'
                                ' (${localizations?.translate('card', 'trained').translated ?? 'Trained'})',
                                generateSkillDescription(
                                  descriptionTemplate:
                                      descriptionTemplate ?? '',
                                  skillsJson: _skillsDetail ?? [],
                                  skillId: _cardData!['specialTrainingSkillId'],
                                  skillLevel: level,
                                  characterRank: rank,
                                  chracterName: characterName?.translated,
                                ),
                              );
                            },
                          ),
                      ],
                    ),

                    // Gacha
                    if (_cardData!['gachas'].isNotEmpty)
                      DetailBuilder.buildGachaList(
                        context,
                        localizations
                                ?.translate('common', 'gacha')
                                .translated ??
                            'Gacha',
                        _cardData!['gachas'],
                      ),

                    // Costumes
                    if (_cardData?['costumes'] != "[]")
                      DetailBuilder.buildDetailRowWithMultipleImageUrl(
                        localizations
                                ?.translate('common', 'costume')
                                .translated ??
                            'Costume',
                        costumesUrls!,
                        '',
                        height: 60,
                      ),

                    // Episodes
                    if (episodes != null && episodes.isNotEmpty)
                      Text(
                        localizations
                                ?.translate('card', "sideStory")
                                .translated ??
                            'Side Story',
                        style: Theme.of(context).textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    if (episodes != null && episodes.isNotEmpty)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final episode in episodes)
                            DetailBuilder.buildEpisode(context, episode),
                        ],
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
