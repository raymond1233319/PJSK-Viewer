import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:pjsk_viewer/pages/card_index.dart';
import 'package:pjsk_viewer/utils/database/card_database.dart';
import 'package:pjsk_viewer/utils/database/gacha_database.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:pjsk_viewer/utils/image_selector.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';

class GachaDetailPage extends StatefulWidget {
  final int gachaId;
  final bool showBanner;
  const GachaDetailPage({
    super.key,
    required this.gachaId,
    this.showBanner = false,
  });

  @override
  State<GachaDetailPage> createState() => _GachaDetailPageState();
}

class _GachaDetailPageState extends State<GachaDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _gacha;

  @override
  void initState() {
    super.initState();
    _loadGacha();
  }

  Future<void> _loadGacha() async {
    try {
      _gacha = await GachaDatabase.getGachaById(widget.gachaId);
      setState(() => _isLoading = false);
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);
    final appLocalizations = AppLocalizations.of(context);
    if (_isLoading) {
      return _gacha == null
          ? const Center(child: CircularProgressIndicator())
          : Center(child: Text(appLocalizations.translate('gacha_not_found')));
    }
    final int gachaId = _gacha?['id'] as int? ?? 0;
    final String gachaInfoJson = _gacha?['gachaInformation'] as String? ?? '{}';
    final Map<String, dynamic> gachaInformation = json.decode(gachaInfoJson);
    final String assetbundleName = _gacha?['assetbundleName'] ?? '';
    final String gachaAssetName = 'gacha$gachaId';
    String logoUrl =
        assetbundleName.isNotEmpty
            ? 'https://storage.sekai.best/sekai-jp-assets/gacha/$assetbundleName/logo/logo.webp'
            : '';
    String bannerUrl =
        assetbundleName.isNotEmpty
            ? 'https://storage.sekai.best/sekai-jp-assets/home/banner/banner_$gachaAssetName/banner_$gachaAssetName.webp'
            : '';
    String backgroundUrl =
        assetbundleName.isNotEmpty
            ? 'https://storage.sekai.best/sekai-jp-assets/gacha/$assetbundleName/screen/texture/bg_${gachaAssetName}_1.webp'
            : '';

    final List<dynamic> ratesList =
        json.decode(_gacha?['gachaCardRarityRates'] as String? ?? '[]')
            as List<dynamic>;
    final Map<String, double> ratesMap = {};

    for (final dynamic rateEntry in ratesList) {
      final String? rarityType = rateEntry['cardRarityType'] as String?;
      if (rarityType == null) continue;
      final double rateValue = rateEntry['rate'].toDouble();
      ratesMap[rarityType] = (ratesMap[rarityType] ?? 0.0) + rateValue;
    }

    List<Map<String, dynamic>> pickupCards = _gacha?['pickupCards'] ?? [];
    return Scaffold(
      appBar: DetailBuilder.buildAppBar(context, _gacha?['name']),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _gacha == null
              ? Center(
                child: Text(appLocalizations.translate('gacha_not_found')),
              )
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Image Section
                    Column(
                      children: [
                        MultiImageSelector(
                          options: [
                            MultiImageOption(
                              label: appLocalizations.translate('logo'),
                              imageUrl: logoUrl,
                            ),
                            MultiImageOption(
                              label: appLocalizations.translate('banner'),
                              imageUrl: bannerUrl,
                            ),
                            MultiImageOption(
                              label:
                                  localizations
                                      ?.translate(
                                        'gacha',
                                        "tab",
                                        innerKey: "title[3]",
                                      )
                                      .translated ??
                                  'background',
                              imageUrl: backgroundUrl,
                            ),
                          ],
                          startPosition: widget.showBanner ? 1 : 0,
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
                            // ID
                            DetailBuilder.buildTextRow(
                              localizations
                                      ?.translate('common', "id")
                                      .translated ??
                                  'ID',
                              gachaId.toString(),
                            ),

                            // Title
                            DetailBuilder.buildTextRow(
                              localizations
                                      ?.translate('common', "title")
                                      .translated ??
                                  'Title',
                              _gacha?['name'] ?? '',
                            ),

                            // Available From
                            DetailBuilder.buildTextRow(
                              localizations
                                      ?.translate('common', "startAt")
                                      .translated ??
                                  'Available From',
                              formatDate(_gacha!['startAt']),
                            ),

                            // Available Until
                            DetailBuilder.buildTextRow(
                              localizations
                                      ?.translate('common', "endAt")
                                      .translated ??
                                  'Available Until',
                              formatDate(_gacha!['endAt']),
                            ),

                            // Type
                            DetailBuilder.buildTextRow(
                              localizations
                                      ?.translate('common', "type")
                                      .translated ??
                                  'Type',
                              appLocalizations.translate(
                                "gacha_${_gacha!['gachaType']}",
                              ),
                            ),

                            // Summary
                            DetailBuilder.buildModalTextRow(
                              context,
                              localizations
                                      ?.translate('gacha', "summary")
                                      .translated ??
                                  'Summary',
                              gachaInformation['summary'],
                            ),

                            // Description
                            DetailBuilder.buildModalTextRow(
                              context,
                              localizations
                                      ?.translate('gacha', "description")
                                      .translated ??
                                  'Description',
                              gachaInformation['description'],
                            ),

                            // Pickup Members
                            DetailBuilder.buildCardThumbnailList(
                              context,
                              localizations
                                      ?.translate(
                                        'gacha',
                                        "pickupMember_plural",
                                      )
                                      .translated ??
                                  "Pick-up Members",
                              pickupCards,
                            ),
                            // Rate
                            DetailBuilder.buildGachaRateDisplay(
                              context: context,
                              ratesMap: ratesMap,
                              label:
                                  localizations!
                                      .translate('gacha', 'normalRate')
                                      .translated,
                            ),
                            DetailBuilder.buildDetailRow(
                              localizations
                                  .translate('gacha', "gacha_cards")
                                  .translated,
                              IconButton(
                                icon: const Icon(Icons.arrow_forward),
                                onPressed: () async {
                                  final List<Map<String, dynamic>> details =
                                      (json.decode(_gacha!['gachaDetails'])
                                              as List)
                                          .cast<Map<String, dynamic>>();
                                  final cards =
                                      await CardDatabase.getCardIndex();
                                  final Map<int, String> idToRarity = {
                                    for (var c in cards)
                                      c['id'] as int:
                                          c['cardRarityType'] as String,
                                  };
                                  final Map<String, int> rarityTotals = {};
                                  for (var e in details) {
                                    final r =
                                        idToRarity[e['cardId'] as int] ??
                                        'unknown';
                                    rarityTotals[r] =
                                        (rarityTotals[r] ?? 0) +
                                        (e['weight'] as num).toInt();
                                  }
                                  final cardIds =
                                      details
                                          .map((weight) => weight['cardId'])
                                          .toList();
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder:
                                          (_) => CardIndexPage(
                                            filterFunc:
                                                (card) => cardIds.contains(
                                                  card['id'] as int,
                                                ),
                                            buildTextOverlay: (card) {
                                              final cid = card['id'] as int;
                                              final w =
                                                  (details.firstWhere(
                                                            (e) =>
                                                                e['cardId'] ==
                                                                cid,
                                                          )['weight']
                                                          as num)
                                                      .toInt();
                                              final r = card['cardRarityType'];
                                              final total =
                                                  rarityTotals[r] ?? 0;
                                              final pct =
                                                  w /
                                                  total *
                                                  (ratesMap[r] ?? 0);
                                              return '${pct.toStringAsFixed(4)}%';
                                            },
                                          ),
                                    ),
                                  );
                                },
                              ),
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
