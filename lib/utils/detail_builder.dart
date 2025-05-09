import 'dart:convert';
import 'dart:developer' as developer;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/pages/card_detail.dart';
import 'package:pjsk_viewer/pages/gacha_detail.dart';
import 'package:pjsk_viewer/utils/audio_service.dart';
import 'package:pjsk_viewer/utils/helper.dart';

class DetailBuilder {
  static Widget buildCharacterIcon(characterId) {
    return Image.asset(
      'assets/chara_icons/chr_ts_$characterId.png',
      height: 40,
      errorBuilder:
          (context, err, stack) => const Icon(Icons.broken_image, size: 40),
    );
  }

  static buildAppBar(BuildContext context, String? title) {
    return AppBar(
      automaticallyImplyLeading: false,
      leadingWidth: 100,
      leading: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          IconButton(
            icon: const Icon(Icons.home),
            onPressed:
                () => Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      title: Text(title ?? ''),
    );
  }

  /// Builds a standard row with a label on the left and a value widget on the right.
  static Widget buildDetailRow(String label, Widget value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 1,
                child: Text(
                  '$label:',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Expanded(
                flex: 3,
                child: Align(alignment: Alignment.centerRight, child: value),
              ),
            ],
          ),
        ),
        const Divider(height: 5, thickness: 1),
      ],
    );
  }

  static Widget buildDetailRowWithWidgets(String label, List<Widget> widgets) {
    return buildDetailRow(
      label,
      Wrap(spacing: 8.0, runSpacing: 4.0, children: widgets),
    );
  }

  /// Simple row of label + text value
  static Widget buildTextRow(String label, String value) {
    return buildDetailRow(
      label,
      Builder(
        builder:
            (context) => GestureDetector(
              onTap: () async {
                final localizations = AppLocalizations.of(context);
                await Clipboard.setData(ClipboardData(text: value));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      localizations.translate('copied_to_clipboard'),
                    ),
                  ),
                );
              },
              child: Text(value, style: const TextStyle()),
            ),
      ),
    );
  }

  /// Builds a row with a label on left and a localized text on right:
  static Widget buildLocalizedTextRow(
    String label,
    LocalizedText value, {
    Widget? trailing,
  }) {
    return buildDetailRow(
      label,
      Builder(
        builder:
            (context) => GestureDetector(
              onTap: () async {
                final localizations = AppLocalizations.of(context);
                await Clipboard.setData(ClipboardData(text: value.combined));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      localizations.translate('copied_to_clipboard'),
                    ),
                  ),
                );
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // text column: translated (grey) on top-left, Japanese on bottom-right
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(value.japanese, textAlign: TextAlign.right),
                        if (value.japanese != value.translated)
                          Text(
                            value.translated,
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.right,
                          ),
                      ],
                    ),
                  ),
                  if (trailing != null) ...[const SizedBox(width: 8), trailing],
                ],
              ),
            ),
      ),
    );
  }

  /// Row with a list of Image assets
  static Widget buildDetailRowWithAsset(String label, List<String> assetPaths) {
    return buildDetailRowWithWidgets(
      label,
      assetPaths.map((path) {
        return Image.asset(path, fit: BoxFit.contain, height: 40);
      }).toList(),
    );
  }

  /// Builds a row with a label on the left and an image from [imageUrl] on the right.
  /// Shows a spinner while loading and a broken image on error.
  static Widget buildDetailRowWithImageUrl(
    String label,
    String imageUrl,
    String text, {
    double height = 40.0,
    BoxFit fit = BoxFit.contain,
  }) {
    return buildDetailRow(
      label,
      CachedNetworkImage(
        imageUrl: imageUrl,
        height: height,
        fit: fit,
        placeholder:
            (context, url) => SizedBox(
              height: height,
              child: const Center(child: CircularProgressIndicator()),
            ),
        errorWidget:
            (context, u, e) =>
                Text(text), // Expect 'text' to be localized by caller
      ),
    );
  }

  /// Like buildDetailRowWithImageUrl, but attempts each URL in [imageUrls] in order.
  static Widget buildDetailRowWithMultipleImageUrl(
    String label,
    List<String> imageUrls,
    String text, {
    double height = 40.0,
    BoxFit fit = BoxFit.contain,
  }) {
    return buildDetailRowWithWidgets(
      label,
      imageUrls.map((url) {
        return CachedNetworkImage(
          imageUrl: url,
          height: height,
          fit: fit,
          placeholder:
              (context, u) => SizedBox(
                height: height,
                child: const CircularProgressIndicator(),
              ),
          errorWidget: (context, u, e) => Text(text),
        );
      }).toList(),
    );
  }

  /// Specific row handling bonus character data
  static Widget buildCharactersWidget(String label, String jsonString) {
    final dynamic decoded = json.decode(jsonString);
    final List<int> items =
        (decoded is List)
            ? decoded
                .map((item) => item is int ? item : int.parse(item.toString()))
                .toList()
            : <int>[];
            
    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return buildDetailRowWithWidgets(
      label,
      items.map((charId) => buildSingleCharacterDisplay(charId)).toList(),
    );
  }

  static Widget buildSingleCharacterDisplay(int charId) {
    final Map<int, Map<String, dynamic>> characterUnitMap = {
      // Miku
      27: {"gameCharacterId": "21_2", "unit": "light_sound"},
      28: {"gameCharacterId": "21_3", "unit": "idol"},
      29: {"gameCharacterId": "21_4", "unit": "street"},
      30: {"gameCharacterId": "21_5", "unit": "theme_park"},
      31: {"gameCharacterId": "21_6", "unit": "school_refusal"},
      // Rin
      32: {"gameCharacterId": 22, "unit": "light_sound"},
      33: {"gameCharacterId": 22, "unit": "idol"},
      34: {"gameCharacterId": 22, "unit": "street"},
      35: {"gameCharacterId": 22, "unit": "theme_park"},
      36: {"gameCharacterId": 22, "unit": "school_refusal"},
      // Len
      37: {"gameCharacterId": 23, "unit": "light_sound"},
      38: {"gameCharacterId": 23, "unit": "idol"},
      39: {"gameCharacterId": 23, "unit": "street"},
      40: {"gameCharacterId": 23, "unit": "theme_park"},
      41: {"gameCharacterId": 23, "unit": "school_refusal"},
      // Luka
      42: {"gameCharacterId": 24, "unit": "light_sound"},
      43: {"gameCharacterId": 24, "unit": "idol"},
      44: {"gameCharacterId": 24, "unit": "street"},
      45: {"gameCharacterId": 24, "unit": "theme_park"},
      46: {"gameCharacterId": 24, "unit": "school_refusal"},
      // Meiko
      47: {"gameCharacterId": 25, "unit": "light_sound"},
      48: {"gameCharacterId": 25, "unit": "idol"},
      49: {"gameCharacterId": 25, "unit": "street"},
      50: {"gameCharacterId": 25, "unit": "theme_park"},
      51: {"gameCharacterId": 25, "unit": "school_refusal"},
      // Kaito
      52: {"gameCharacterId": 26, "unit": "light_sound"},
      53: {"gameCharacterId": 26, "unit": "idol"},
      54: {"gameCharacterId": 26, "unit": "street"},
      55: {"gameCharacterId": 26, "unit": "theme_park"},
      56: {"gameCharacterId": 26, "unit": "school_refusal"},
    };

    String assetPath;
    String? overlayImagePath;

    final dynamic mappedGameCharacterId =
        characterUnitMap[charId]?["gameCharacterId"];
    final String effectiveCharIdString =
        (mappedGameCharacterId ?? charId).toString();
    assetPath = 'assets/chara_icons/chr_ts_$effectiveCharIdString.png';

    if (charId > 31) {
      final realCharId = characterUnitMap[charId]?["gameCharacterId"] ?? charId;
      assetPath = 'assets/chara_icons/chr_ts_$realCharId.png';
      final unit = characterUnitMap[charId]?["unit"];
      if (unit != null) {
        overlayImagePath = 'assets/common/logo_mini/unit_ts_$unit.png';
      }
    } else {
      final realCharId = characterUnitMap[charId]?["gameCharacterId"] ?? charId;
      assetPath = 'assets/chara_icons/chr_ts_$realCharId.png';
    }

    Widget characterIcon = Image.asset(
      assetPath,
      fit: BoxFit.contain,
      height: 40,
      errorBuilder:
          (context, error, stackTrace) =>
              const Icon(Icons.broken_image, size: 40),
    );

    if (overlayImagePath != null) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          characterIcon,
          Positioned(
            top: -5,
            right: -5,
            child: SizedBox(
              width: 20,
              height: 20,
              child: Image.asset(
                overlayImagePath,
                fit: BoxFit.contain,
                errorBuilder:
                    (context, error, stackTrace) =>
                        const Icon(Icons.error_outline, size: 15),
              ),
            ),
          ),
        ],
      );
    } else {
      return characterIcon;
    }
  }

  static Widget buildGachaPhase(String value, String audioUrl) {
    final audioService = AudioService();
    // Note: Context is obtained within the FutureBuilder below
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: FutureBuilder<void>(
          future: audioService.loadAudio(audioUrl),
          builder: (context, snapshot) {
            final localizations = AppLocalizations.of(
              context,
            ); // Get localizations from context
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                GestureDetector(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: value));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          localizations.translate('copied_to_clipboard'),
                        ),
                      ),
                    );
                  },
                  child: Center(
                    child: Text(
                      value,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                ),
                if (snapshot.connectionState == ConnectionState.done &&
                    audioService.audioExists) ...[
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [SimpleAudioPlayer(audioService: audioService)],
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  /// Builds a row with a label on the left and a “View” button on the right.
  /// Tapping the button shows a modal dialog with the full text.
  static Widget buildModalTextRow(
    BuildContext context,
    String label,
    String content,
  ) {
    final applocalizations = AppLocalizations.of(context);
    return buildDetailRow(
      label,
      TextButton(
        child: Text(applocalizations.translate('view')),
        onPressed: () {
          popUpDialog(context, SingleChildScrollView(child: Text(content)));
        },
      ),
    );
  }

  /// Returns a Stack displaying a single card thumbnail (frame + attribute icon).
  /// By default, shows the normal thumbnail; set `isTrainedImage: true` to show the trained one.
  static Widget buildCardThumbnail({
    required BuildContext context,
    required String assetbundleName,
    required String rarity,
    required String attribute,
    bool isTrainedImage = false,
    double size = 70.0,
    int? cardId,
    bool isJumpToCardPage = false,
  }) {
    // decide which URL and frame to use
    final String url =
        isTrainedImage
            ? 'https://storage.sekai.best/sekai-jp-assets/thumbnail/chara/${assetbundleName}_after_training.webp'
            : 'https://storage.sekai.best/sekai-jp-assets/thumbnail/chara/${assetbundleName}_normal.webp';
    final String frame =
        isTrainedImage
            ? 'assets/frame/frame_thumbnail_${rarity}_trained.png'
            : 'assets/frame/frame_thumbnail_$rarity.png';
    final String attributeIcon = 'assets/icon_attribute_$attribute.png';

    final widget = Stack(
      children: [
        CachedNetworkImage(
          imageUrl: url,
          height: size,
          width: size,
          fit: BoxFit.contain,
          placeholder:
              (context, u) => SizedBox(
                height: size,
                width: size,
                child: const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
          errorWidget: (context, u, e) => const Icon(Icons.error, size: 50),
        ),
        Image.asset(frame, height: size, width: size, fit: BoxFit.contain),
        Positioned(
          top: 0,
          left: 0,
          child: Image.asset(
            attributeIcon,
            height: 15,
            width: 15,
            fit: BoxFit.contain,
          ),
        ),
      ],
    );
    // if cardId provided and jump flag is true, wrap in a tap handler
    if (cardId != null && isJumpToCardPage) {
      return GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => CardDetailPage(cardId: cardId)),
          );
        },
        child: widget,
      );
    }
    return widget;
  }

  static Widget buildCardThumbnailRow(
    BuildContext context,
    String label,
    final cardData,
  ) {
    String assetbundleName = cardData!['assetbundleName'];
    String attribute = cardData!['attr'];
    String rarity = cardData!['cardRarityType'];
    bool showNormal = cardData!['initialSpecialTrainingStatus'] != 'done';
    bool showTrained =
        cardData!['specialTrainingCosts'] != '[]' ||
        cardData!['initialSpecialTrainingStatus'] == 'done';
    return buildDetailRow(
      label,
      Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.end,
        children: [
          if (showNormal)
            buildCardThumbnail(
              context: context,
              assetbundleName: assetbundleName,
              rarity: rarity,
              attribute: attribute,
            ),
          if (showTrained)
            buildCardThumbnail(
              context: context,
              assetbundleName: assetbundleName.replaceFirst(
                '_normal',
                '_after_training',
              ),
              rarity: rarity,
              attribute: attribute,
              isTrainedImage: true,
            ),
        ],
      ),
    );
  }

  static Widget buildCardThumbnailList(
    BuildContext context,
    String label,
    List<Map<String, dynamic>> cards, {
    bool showTrainedImage = false,
    double size = 70.0,
  }) {
    return buildDetailRow(
      label,
      Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        alignment: WrapAlignment.end,
        children:
            cards.map((card) {
              final int cardId = card['id'] as int;
              final String bundle = card['assetbundleName'] as String? ?? '';
              final String rarity = card['cardRarityType'] as String? ?? '';
              final String attribute = card['attr'] as String? ?? '';
              final bool showTrainedImage =
                  card['initialSpecialTrainingStatus'] == 'done';
              return buildCardThumbnail(
                context: context,
                assetbundleName: bundle,
                rarity: rarity,
                attribute: attribute,
                isTrainedImage: showTrainedImage,
                size: size,
                cardId: cardId,
                isJumpToCardPage: true,
              );
            }).toList(),
      ),
    );
  }

  static Widget buildGachaList(
    BuildContext context,
    String label,
    List<Map<String, dynamic>> gachas, {
    double size = 80.0,
  }) {
    bool showBanner = false;
    return buildDetailRow(
      label,
      Wrap(
        spacing: 8.0,
        runSpacing: 8.0,
        children:
            gachas.map((gacha) {
              final int gachaId = gacha['id'] as int;
              final String assetbundleName = gacha['assetbundleName'];
              final String gachaAssetName = 'gacha$gachaId';
              String logoUrl =
                  assetbundleName.isNotEmpty
                      ? 'https://storage.sekai.best/sekai-jp-assets/gacha/$assetbundleName/logo/logo.webp'
                      : '';
              String bannerUrl =
                  assetbundleName.isNotEmpty
                      ? 'https://storage.sekai.best/sekai-jp-assets/home/banner/banner_$gachaAssetName/banner_$gachaAssetName.webp'
                      : '';
              return GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder:
                          (_) => GachaDetailPage(
                            gachaId: gachaId,
                            showBanner: showBanner,
                          ),
                    ),
                  );
                },
                child: CachedNetworkImage(
                  imageUrl: logoUrl,
                  height: size,
                  width: size,
                  fit: BoxFit.contain,
                  placeholder:
                      (_, __) => SizedBox(
                        height: size,
                        width: size,
                        child: const Center(child: CircularProgressIndicator()),
                      ),
                  errorWidget: (context, __, ___) {
                    final localizations = AppLocalizations.of(context);
                    showBanner = true;
                    // if logo failed then try banner
                    return CachedNetworkImage(
                      imageUrl: bannerUrl,
                      height: size,
                      width: size,
                      fit: BoxFit.contain,
                      placeholder:
                          (_, __) => SizedBox(
                            height: size,
                            width: size,
                            child: const Center(
                              child: CircularProgressIndicator(),
                            ),
                          ),
                      // final fallback
                      errorWidget:
                          (_, __, ___) => Container(
                            height: size,
                            width: size,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              gacha['name'] as String? ??
                                  localizations.translate('unknown_gacha'),
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                    );
                  },
                ),
              );
            }).toList(),
      ),
    );
  }

  /// Builds a ExpansionTile.
  static Widget buildExpansion({
    required BuildContext context,
    required String title,
    TextStyle? titleStyle,
    bool initiallyExpanded = false,
    required ValueChanged<bool> onExpansionChanged,
    required List<Widget> children,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            title: Text(title, style: titleStyle, textAlign: TextAlign.left),
            initiallyExpanded: initiallyExpanded,
            onExpansionChanged: onExpansionChanged,
            children: children,
          ),
        ),
        const Divider(height: 5, thickness: 1),
      ],
    );
  }

  static Widget buildGachaRateDisplay({
    required BuildContext context,
    required Map<String, double> ratesMap,
    String label = "Normal Roll Rate", // Default label
  }) {
    return buildDetailRow(
      label,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children:
            ratesMap.entries
                .map((entry) => buildRateRow(context, entry.key, entry.value))
                .toList(),
      ),
    );
  }

  static Widget buildRateRow(context, String rarityType, double rate) {
    if (rate == 0.0) {
      return const SizedBox.shrink(); // Skip if rate is 0
    }
    String assetPath = 'assets/$rarityType.png';

    // Format the rate as a percentage string
    final NumberFormat percentFormat = NumberFormat("0.0' %'");
    final String rateString = percentFormat.format(rate);

    return Padding(
      padding: const EdgeInsets.symmetric(
        vertical: 2.0,
      ), // Add vertical spacing between rows
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end, // Align content to the right
        children: [
          // Star Icons (using placeholder Image.asset)
          // Replace with your actual star icons or widgets
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 1.0,
            ), // Small space between stars
            child: Image.asset(
              assetPath,
              height: 18,
              errorBuilder:
                  (context, error, stackTrace) => const Icon(
                    Icons.star_border,
                    size: 18,
                    color: Colors.grey,
                  ),
            ),
          ),
          // Rate Text
          SizedBox(
            width: 50, // Fixed width for alignment
            child: Text(
              rateString,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  static Widget buildEpisode(
    BuildContext context,
    Map<String, dynamic> episode,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color:
              episode['cardEpisodePartType'] == 'first_part'
                  ? Colors.blue.shade50
                  : Colors.green.shade50,
          borderRadius: BorderRadius.circular(8),
        ),
        child: GestureDetector(
          onTap: () {
            showResourceCostsModal(context, episode);
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                episode['title'],
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              Icon(Icons.arrow_forward_ios_rounded),
            ],
          ),
        ),
      ),
    );
  }

  /// Builds a single resource row (icon + quantity).
  static Widget buildResourceItem(Map<String, dynamic> cost) {
    final resourceId = cost['resourceId'];
    final resourceType = cost['resourceType'];
    final quantity = cost['quantity'];
    final imageUrl =
        'https://storage.sekai.best/sekai-jp-assets/thumbnail/$resourceType/$resourceType$resourceId.webp';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            width: 32,
            height: 32,
            placeholder:
                (context, url) => const SizedBox(
                  width: 32,
                  height: 32,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            errorWidget:
                (context, err, stack) =>
                    const Icon(Icons.error_outline, size: 32),
          ),
          const SizedBox(width: 8),
          Text('x$quantity'),
        ],
      ),
    );
  }

  static void showResourceCostsModal(
    BuildContext context,
    Map<String, dynamic> episode,
  ) {
    final localizations = ContentLocalizations.of(context)!;
    List costs = episode['costs'] as List;
    popUpDialog(
      context,
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            localizations.translate('common', 'releaseCosts').translated,
            style: const TextStyle(
              fontSize: 16.0, // Adjust font size as needed
              fontWeight: FontWeight.bold,
            ),
          ),
          ...costs.map<Widget>(
            (cost) => buildResourceItem(cost as Map<String, dynamic>),
          ),
          Text(
            localizations.translate('common', 'rewards').translated,
            style: const TextStyle(
              fontSize: 16.0, // Adjust font size as needed
              fontWeight: FontWeight.bold,
            ),
          ),
          Row(
            children: [
              CachedNetworkImage(
                imageUrl:
                    'https://storage.sekai.best/sekai-jp-assets/thumbnail/common_material/jewel.webp',
                width: 32,
                height: 32,
                placeholder:
                    (context, url) => const SizedBox(
                      width: 32,
                      height: 32,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                errorWidget:
                    (context, error, stackTrace) =>
                        const Icon(Icons.error_outline, size: 32),
              ),
              const SizedBox(width: 8),
              Text(
                'x${episode['cardEpisodePartType'] == 'first_part' ? 25 : 50}',
              ),
            ],
          ),
        ],
      ),
      height: 300,
      width: 100,
    );
  }

  static Widget buildCheerfulCarnivalColumn(
    context,
    cheerfulCarnivalTeams,
    cheerfulCarnivalSummaries,
    String assetbundleName,
    int eventId,
  ) {
    final localizations = ContentLocalizations.of(context)!;
    final team =
        cheerfulCarnivalTeams
            .where((team) => team['eventId'] == eventId)
            .toList();
    final summaries =
        cheerfulCarnivalSummaries
            .where((summary) => summary['eventId'] == eventId)
            .toList();
    final theme = summaries.isNotEmpty ? summaries[0]['theme'] : '';
    final leftName = team.isNotEmpty ? team[0]['teamName'] : '';
    final rightName = team.length > 1 ? team[1]['teamName'] : '';
    final leftImageUrl =
        team.isNotEmpty
            ? 'https://storage.sekai.best/sekai-jp-assets/event/$assetbundleName/team_image/${team[0]['assetbundleName']}.webp'
            : '';
    final rightImageUrl =
        team.length > 1
            ? 'https://storage.sekai.best/sekai-jp-assets/event/$assetbundleName/team_image/${team[1]['assetbundleName']}.webp'
            : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          localizations
              .translate('event', "type", innerKey: 'cheerful_carnival')
              .translated,
          style: Theme.of(
            context,
          ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          theme,
          style: Theme.of(context).textTheme.titleMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // left team
            Expanded(
              child: Column(
                children: [
                  if (leftImageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: leftImageUrl,
                      height: 60,
                      fit: BoxFit.contain,
                      placeholder:
                          (context, url) => SizedBox(
                            height: 60,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      errorWidget:
                          (context, err, st) =>
                              const Icon(Icons.error_outline, size: 40),
                    ),
                  const SizedBox(height: 4),
                  Text(leftName),
                ],
              ),
            ),
            // right team
            Expanded(
              child: Column(
                children: [
                  if (rightImageUrl.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: rightImageUrl,
                      height: 60,
                      fit: BoxFit.contain,
                      placeholder:
                          (context, url) => SizedBox(
                            height: 60,
                            child: Center(child: CircularProgressIndicator()),
                          ),
                      errorWidget:
                          (context, err, st) =>
                              const Icon(Icons.error_outline, size: 40),
                    ),
                  const SizedBox(height: 4),
                  Text(rightName, textAlign: TextAlign.right),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 8, thickness: 1),
      ],
    );
  }

  static Widget buildWorldBloomColumn(
    BuildContext context,
    int eventId,
    List<Map<String, dynamic>> worldBlooms,
  ) {
    final localizations = ContentLocalizations.of(context)!;

    List<Map<String, dynamic>> filteredWorldBlooms =
        worldBlooms.where((b) => b['eventId'] == eventId).toList();
    filteredWorldBlooms.sort(
      (a, b) =>
          (a['chapterStartAt'] as int).compareTo(b['chapterStartAt'] as int),
    );

    final characters =
        filteredWorldBlooms.map((b) => b['gameCharacterId'] as int?).toList();

    // local selection state
    final isSelected = List<bool>.filled(characters.length, false);

    return StatefulBuilder(
      builder: (context, setState) {
        int selectedIndex = isSelected.indexWhere(
          (isSelectedItem) => isSelectedItem,
        );

        Widget chapterRow;
        if (selectedIndex >= 0) {
          final worldbloom = filteredWorldBlooms[selectedIndex];
          final String startAt = formatDate(
            worldbloom['chapterStartAt'] as int,
          );
          final String aggregateAt = formatDate(
            worldbloom['aggregateAt'] as int,
          );
          chapterRow = Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Column(
              children: [
                DetailBuilder.buildTextRow(
                  localizations.translate('event', "startAt").translated,
                  startAt,
                ),
                DetailBuilder.buildTextRow(
                  localizations.translate('event', "closeAt").translated,
                  aggregateAt,
                ),
              ],
            ),
          );
        } else {
          chapterRow = const SizedBox.shrink();
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localizations
                  .translate('event', 'type', innerKey: 'world_bloom')
                  .translated,
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            buildCharacterToggleButtons(
              characterIds: characters,
              isSelected: isSelected,
              onPressed: (index) {
                setState(() {
                  for (var i = 0; i < isSelected.length; i++) {
                    isSelected[i] = (i == index) ? !isSelected[i] : false;
                  }
                });
              },
            ),
            const SizedBox(height: 8),

            chapterRow,

            const Divider(height: 8, thickness: 1),
          ],
        );
      },
    );
  }

  static Widget buildCharacterToggleButtons({
    required List<int?> characterIds,
    required List<bool> isSelected,
    required ValueChanged<int> onPressed,
  }) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth * 0.95;
        final count = characterIds.isNotEmpty ? characterIds.length : 1;
        final buttonWidth = totalWidth / count;
        const double buttonHeight = 40.0;

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: totalWidth,
              minHeight: buttonHeight,
            ),
            child: ToggleButtons(
              isSelected: isSelected,
              onPressed: onPressed,
              constraints: BoxConstraints(
                minWidth: buttonWidth,
                minHeight: buttonHeight,
              ),
              children:
                  characterIds.map((id) {
                    if (id == -1)
                      return const Icon(Icons.all_inclusive, size: 32);
                    return buildCharacterIcon(id);
                  }).toList(),
            ),
          ),
        );
      },
    );
  }

  static Widget buildEventExchangeList(
    BuildContext context,
    List<Map<String, dynamic>> eventExchanges,
    List<Map<String, dynamic>> eventExchangeResourceBoxDetails,
    List<Map<String, dynamic>> eventCards,
    Map<int, String> eventItemAssetMap,
    List<Map<String, dynamic>> mySekaiMaterials,
  ) {
    if (eventExchanges.isEmpty) {
      return const SizedBox.shrink();
    }
    final appLocalizations = AppLocalizations.of(context);
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: eventExchanges.length,
      itemBuilder: (context, index) {
        final exchange = eventExchanges[index];

        // Get the cost details
        final cost =
            exchange['eventExchangeCost'] as Map<String, dynamic>? ?? {};

        // build the cost widget
        Widget costWidget = buildResourceIcon(
          context: context,
          resourceType: cost['resourceType'],
          resourceId: cost['resourceId'],
          eventItemAssetMap: eventItemAssetMap,
          size: 24.0,
        );

        // Get the resource box details
        final int resourceBoxId = exchange['resourceBoxId'] as int? ?? 0;
        Map<String, dynamic>? resourceBoxDetail;
        try {
          final Map<String, dynamic> resourceBox =
              eventExchangeResourceBoxDetails.firstWhere(
                (detail) => detail['id'] == resourceBoxId,
              );
          resourceBoxDetail = json.decode(resourceBox['details']).first;
        } catch (e) {
          resourceBoxDetail = null;
        }

        // build the exchange item widget
        final String boxResourceType = resourceBoxDetail?['resourceType'] ?? '';
        final int boxResourceId = resourceBoxDetail?['resourceId'] ?? -1;
        final int boxResourceQuantity =
            resourceBoxDetail?['resourceQuantity'] ?? 0;

        Widget leadingWidget = buildResourceIcon(
          context: context,
          resourceType: boxResourceType,
          resourceId: boxResourceId,
          quantity: boxResourceQuantity,
          cards: eventCards,
          eventItemAssetMap: eventItemAssetMap,
          mySekaiMaterials: mySekaiMaterials,
        );

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
          child: ListTile(
            leading: leadingWidget,
            title: Row(
              children: [
                Text('${appLocalizations.translate('cost')}: '),
                costWidget,
                Text(' x${cost['resourceQuantity']}'),
              ],
            ),
            subtitle:
                exchange['exchangeLimit'] != null
                    ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${appLocalizations.translate('limit')}: ${exchange['exchangeLimit']}',
                        ),
                      ],
                    )
                    : const SizedBox.shrink(),
          ),
        );
      },
    );
  }

  /// Returns a Widget for a resource icon based on its type and ID.
  static Widget buildResourceIcon({
    required BuildContext context,
    required String resourceType,
    required int resourceId,
    List<Map<String, dynamic>> cards = const [],
    Map<int, String> eventItemAssetMap = const {},
    List<Map<String, dynamic>> mySekaiMaterials = const [],
    int quantity = 1,
    double size = 60,
  }) {
    Widget icon;
    switch (resourceType) {
      case 'card':
        final card = cards.firstWhere(
          (card) => card['id'] == resourceId,
          orElse: () => {},
        );
        icon = buildCardThumbnail(
          context: context,
          assetbundleName: card['assetbundleName'] as String? ?? '',
          rarity: card['cardRarityType'] as String? ?? '',
          attribute: card['attr'] as String? ?? '',
          size: size,
          cardId: resourceId,
          isJumpToCardPage: true,
        );
        break;

      case 'practice_ticket':
      case 'skill_practice_ticket':
        final url =
            'https://storage.sekai.best/sekai-jp-assets/thumbnail/$resourceType/ticket$resourceId.webp';
        icon = buildImageWithQuantityOverlay(url, size, quantity);
        break;

      case 'event_item':
        final itemAssetbundleName = eventItemAssetMap[resourceId] ?? '';
        final url =
            'https://storage.sekai.best/sekai-jp-assets/thumbnail/common_event/$itemAssetbundleName/icon_eventbadge_1.webp';
        icon = buildImageWithQuantityOverlay(url, size, quantity);
        break;

      case 'mysekai_material':
        final material = mySekaiMaterials.firstWhere(
          (material) => material['id'] == resourceId,
          orElse: () => {},
        );
        final iconAssetbundleName = material['iconAssetbundleName'] as String?;
        final url =
            'https://storage.sekai.best/sekai-jp-assets/mysekai/thumbnail/material/$iconAssetbundleName.webp';
        icon = buildImageWithQuantityOverlay(url, size, quantity);
        break;

      default:
        final url =
            resourceId != -1
                ? 'https://storage.sekai.best/sekai-jp-assets/thumbnail/$resourceType/$resourceType$resourceId.webp'
                : 'https://storage.sekai.best/sekai-jp-assets/thumbnail/common_material/$resourceType.webp';
        icon = buildImageWithQuantityOverlay(url, size, quantity);
    }
    return icon;
  }

  static Widget buildImageWithQuantityOverlay(
    String url,
    double size,
    int quantity,
  ) {
    return Stack(
      children: [
        CachedNetworkImage(
          imageUrl: url,
          width: size,
          height: size,
          fit: BoxFit.contain,
          placeholder:
              (_, __) => SizedBox(
                width: size,
                height: size,
                child: const CircularProgressIndicator(strokeWidth: 2),
              ),
          errorWidget: (_, __, ___) => Icon(Icons.broken_image, size: size),
        ),
        if (quantity > 1)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              color: Colors.black54,
              child: Text(
                'x$quantity',
                style: const TextStyle(color: Colors.white, fontSize: 10),
              ),
            ),
          ),
      ],
    );
  }

  /// Builds a wrap of texts each enclosed in a rounded‐rectangle background.
  static Widget buildTextList(
    String label,
    List<String> texts, {
    Color backgroundColor = Colors.blueGrey,
    Color textColor = Colors.white,
    EdgeInsets padding = const EdgeInsets.symmetric(
      horizontal: 8.0,
      vertical: 4.0,
    ),
    double radius = 8.0,
  }) {
    return buildDetailRowWithWidgets(
      label,
      texts.map((text) {
        return Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: Text(text, style: TextStyle(color: textColor)),
        );
      }).toList(),
    );
  }

  static Widget buildBoolRow(String label, bool flag) {
    return buildDetailRow(
      label,
      Icon(
        flag ? Icons.check_circle : Icons.cancel,
        color: flag ? Colors.green : Colors.red,
      ),
    );
  }

  static void popUpDialog(
    context,
    content, {
    double height = 600,
    double width = 800,
  }) {
    final localizations = ContentLocalizations.of(context)!;
    showDialog(
      context: context,
      builder:
          (_) => Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Container(
              padding: const EdgeInsets.all(16),
              constraints: BoxConstraints(maxWidth: width, maxHeight: height),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(child: SingleChildScrollView(child: content)),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      localizations.translate('common', 'close').translated,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
