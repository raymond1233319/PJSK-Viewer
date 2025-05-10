import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/card_detail.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/pages/index.dart';
import 'package:pjsk_viewer/utils/database/card_database.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pjsk_viewer/utils/globals.dart';

class CardIndexPage extends StatefulWidget {
  final bool Function(Map<String, dynamic>)? filterFunc;
  final String Function(Map<String, dynamic>)? buildTextOverlay;
  const CardIndexPage({super.key, this.filterFunc, this.buildTextOverlay});

  @override
  State<CardIndexPage> createState() => _CardIndexPageState();
}

class _CardIndexPageState extends State<CardIndexPage> {
  bool _isLoading = true;
  bool _isFetching = true;
  List<Map<String, dynamic>> _allCards = [];
  Map<int, String> _idToSkillType = {};

  final ValueNotifier<bool> _showTrainedImage = ValueNotifier<bool>(false);

  // filter option
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadCards();
    _fetchSkillsDetail();
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _showTrainedImage.dispose();
    super.dispose();
  }

  Future<void> _loadCards() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final cards = await CardDatabase.getCardIndex();
      setState(() {
        _allCards = cards;
        _isLoading = false;
      });
    } catch (e) {
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
      setState(() {
        _isFetching = false;
      });
      return;
    }
    final List<Map<String, dynamic>> skills =
        json.decode(skillsJson).cast<Map<String, dynamic>>();

    // build a map from id → descriptionSpriteName
    final Map<int, String> idToSkillType = {
      for (var skill in skills)
        skill['id'] as int: skill['descriptionSpriteName'] as String,
    };
    idToSkillType[11] = 'perfect_score_up';
    idToSkillType[12] = 'life_score_up';
    idToSkillType[13] = 'score_up_keep';
    for (int i = 15; i <= 19; i++) {
      idToSkillType[i] = 'sub_unit_score_up';
    }
    idToSkillType[22] = 'score_up_character_rank';
    idToSkillType[23] = 'other_member_score_up_reference_rate';
    idToSkillType[24] = 'score_up_unit_count';
    if (!mounted) return;
    setState(() {
      _idToSkillType = idToSkillType;
      _isFetching = false;
    });
  }

  Widget buildCardItem(BuildContext context, Map<String, dynamic> card) {
    final localizations = ContentLocalizations.of(context);
    final applocalizations = AppLocalizations.of(context);
    final cardId = card['id'] as int?;
    LocalizedText? displayCardName = localizations?.translate(
      'card_prefix',
      cardId.toString(),
    );
    final originalName =
        card['prefix'] ??
        AppLocalizations.of(context).translate('unknown_card');
    final translatedName =
        AppGlobals.region == 'jp'
            ? displayCardName?.translated
            : displayCardName?.japanese;
    final assetbundleName = card['assetbundleName'] ?? '';

    String attribute = card['attr'].toString();
    String rarity = card['cardRarityType'].toString();
    final attributeAssetPath = 'assets/icon_attribute_$attribute.png';
    final characterId = card['characterId'].toString();
    final firstName =
        localizations
            ?.translate('character_name', characterId, innerKey: 'firstName')
            .translated;
    final lastName =
        localizations
            ?.translate('character_name', characterId, innerKey: 'givenName')
            .translated;
    final characterName = '$firstName $lastName'.trim();
    final cardType = applocalizations.translate(card['gachaType']);

    String subTitleText =
        cardType != '' ? "$characterName\n$cardType" : characterName;

    if (translatedName != originalName) {
      subTitleText = '$translatedName\n$subTitleText';
    }

    final normalUrl =
        assetbundleName != null
            ? "${AppGlobals.assetUrl}/character/member/$assetbundleName/card_normal.webp"
            : null;
    String? trainedUrl;
    if (rarity == 'rarity_3' || rarity == 'rarity_4') {
      trainedUrl =
          assetbundleName != null
              ? "${AppGlobals.assetUrl}/character/member/$assetbundleName/card_after_training.webp"
              : null;
    }
    bool jumpToTrainedImage = false;
    Widget top = ValueListenableBuilder<bool>(
      valueListenable: _showTrainedImage,
      builder: (context, showTrainedImage, _) {
        final imageUrl =
            showTrainedImage && trainedUrl != null ? trainedUrl : normalUrl!;
        final altImageUrl = showTrainedImage ? normalUrl : trainedUrl ?? '';
        jumpToTrainedImage = showTrainedImage;
        return buildFullWidthItem(
          context,
          Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: imageUrl,
                fit: BoxFit.contain,
                placeholder:
                    (context, url) =>
                        const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) {
                  if (altImageUrl == trainedUrl) {
                    jumpToTrainedImage = true;
                  } else {
                    jumpToTrainedImage = false;
                  }
                  // if the image fails to load, show the alternate image
                  return CachedNetworkImage(
                    imageUrl: altImageUrl!,
                    fit: BoxFit.contain,
                    placeholder:
                        (context, url) =>
                            const Center(child: CircularProgressIndicator()),
                    errorWidget:
                        (context, url, error) =>
                            const Center(child: Icon(Icons.broken_image)),
                  );
                },
              ),
              Image.asset(
                'assets/frame/cardFrame_$rarity.png',
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 3,
                right: 3,
                child: Image.asset(
                  attributeAssetPath,
                  height: 30,
                  width: 30,
                  fit: BoxFit.contain,
                ),
              ),
            ],
          ),
          rawH: 1440,
          rawW: 2520,
        );
      },
    );

    if (widget.buildTextOverlay != null) {
      final overlayText = widget.buildTextOverlay!(card);
      if (overlayText.isNotEmpty) {
        final originalTop = top;
        top = Stack(
          children: [
            originalTop,
            Positioned(
              top: 8,
              left: 8,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  overlayText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      }
    }

    return ValueListenableBuilder<bool>(
      valueListenable: _showTrainedImage,
      builder: (context, _, _) {
        return buildIndexItem<int>(
          context: context,
          id: cardId!,
          top: top,
          title: originalName,
          subtitle: subTitleText,
          pageBuilder:
              (id) => CardDetailPage(
                cardId: id,
                showTrainedImage: jumpToTrainedImage,
              ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _isFetching) {
      return const Center(child: CircularProgressIndicator());
    }
    final localizations = ContentLocalizations.of(context);
    FilterOptions filterOptions = FilterOptions(context);
    final title =
        localizations?.translate('common', 'card').translated ?? 'Card';

    // Apply the optional filter function:
    final items =
        widget.filterFunc != null
            ? _allCards.where(widget.filterFunc!).toList()
            : _allCards;

    return IndexPage<Map<String, dynamic>>(
      title: title,
      allItems: items,
      // enable the search bar
      showSearch: true,
      searchPredicate:
          (card, query) => (card['prefix'] as String).toLowerCase().contains(
            query.toLowerCase(),
          ),

      // filters
      filters: [
        FilterConfig<Map<String, dynamic>>(
          header:
              localizations?.translate('common', 'unit').translated ?? 'Unit',
          options: filterOptions.unitOptionsWithoutOther,
          filterFunc: (card, selected) {
            return selected.contains(card['unit']) ||
                selected.contains(card['supportUnit']);
          },
        ),
        FilterConfig<Map<String, dynamic>>(
          header:
              localizations?.translate('common', 'character').translated ??
              'Character',
          options: filterOptions.characterOptions,
          filterFunc: (card, selected) {
            return selected.contains(card['characterId'].toString());
          },
        ),
        FilterConfig<Map<String, dynamic>>(
          header:
              localizations?.translate('common', 'attribute').translated ??
              'Attribute',
          options: filterOptions.attributeOptions,
          filterFunc: (card, selected) {
            return selected.contains(card['attr']);
          },
        ),
        FilterConfig<Map<String, dynamic>>(
          header:
              localizations?.translate('card', 'rarity').translated ?? 'Rarity',
          options: filterOptions.rarityOptions,
          filterFunc: (card, selected) {
            return selected.contains(card['cardRarityType']);
          },
        ),
        FilterConfig<Map<String, dynamic>>(
          header:
              localizations?.translate('common', 'type').translated ?? 'Type',
          options: filterOptions.cardTypeOptions,
          filterFunc: (card, selected) {
            return selected.contains(card['gachaType']);
          },
        ),
        FilterConfig<Map<String, dynamic>>(
          header:
              localizations?.translate('common', 'skill').translated ?? 'Type',
          options: filterOptions.cardSkillTypeOptions,
          filterFunc: (card, selected) {
            for (String select in selected) {
              if (select == 'score_up' &&
                  _idToSkillType[card['skillId']] != 'score_up') {
                continue;
              }
              if (_idToSkillType[card['skillId']]!.contains(select)) {
                return true;
              }
              if (card['specialTrainingSkillId'] != null &&
                  _idToSkillType[card['specialTrainingSkillId']] == select) {
                return true;
              }
            }
            return false;
          },
        ),
      ],

      pageSize: 10,
      scrollController: _scrollController,

      // build each row
      itemBuilder: (context, card) => buildCardItem(context, card),

      appBarActions: [
        ValueListenableBuilder<bool>(
          valueListenable: _showTrainedImage,
          builder: (context, showTrained, _) {
            return Switch(
              value: showTrained,
              onChanged: (newValue) => _showTrainedImage.value = newValue,
            );
          },
        ),
      ],

      appBarSwitchText:
          localizations
              ?.translate('card', "tab", innerKey: "title[2]")
              .translated ??
          'After training image',
    );
  }
}
