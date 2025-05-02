import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:pjsk_viewer/pages/gacha_detail.dart';
import 'package:pjsk_viewer/pages/index.dart';
import 'package:pjsk_viewer/utils/database/gacha_database.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/helper.dart';

class GachaIndexPage extends StatefulWidget {
  const GachaIndexPage({super.key});

  @override
  State<GachaIndexPage> createState() => _GachaIndexPageState();
}

class _GachaIndexPageState extends State<GachaIndexPage> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _allGachas = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _loadGachas();
  }

  Future<void> _loadGachas() async {
    setState(() => _isLoading = true);
    try {
      _allGachas = await GachaDatabase.getGachaIndex();
    } catch (_) {
      // handle error or leave empty
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Widget _buildGachaItem(BuildContext context, Map<String, dynamic> g) {
    final applocalizations = AppLocalizations.of(context);
    final gachaId = g['id']!;
    final localizedName =
        g['name'] as String? ?? applocalizations.translate('unknown_gacha');

    final asset = g['assetbundleName'] as String? ?? '';
    final logoUrl =
        asset.isNotEmpty
            ? 'https://storage.sekai.best/sekai-jp-assets/gacha/$asset/logo/logo.webp'
            : null;
    final String gachaAssetName = 'gacha$gachaId';
    final bannerUrl =
        asset.isNotEmpty
            ? 'https://storage.sekai.best/sekai-jp-assets/home/banner/banner_$gachaAssetName/banner_$gachaAssetName.webp'
            : '';

    final DateFormat fmt = DateFormat('dd/MM/yyyy HH:mm');
    final String startDateStr = fmt.format(
      DateTime.fromMillisecondsSinceEpoch(g['startAt'] as int? ?? 0).toLocal(),
    );
    final String endDateStr = fmt.format(
      DateTime.fromMillisecondsSinceEpoch(g['endAt'] as int? ?? 0).toLocal(),
    );
    String gachaTypeDisplay = applocalizations.translate(g['gachaType']);
    final subTitleText = "$gachaTypeDisplay\n$startDateStr ~ \n$endDateStr";
    bool showBanner = false;
    final Widget top =
        logoUrl != null
            ? CachedNetworkImage(
              imageUrl: logoUrl,
              fit: BoxFit.cover,
              placeholder:
                  (_, __) => const Center(child: CircularProgressIndicator()),
              errorWidget: (_, __, ___) {
                showBanner = true;
                return CachedNetworkImage(
                  imageUrl: bannerUrl,
                  fit: BoxFit.cover,
                  placeholder:
                      (_, __) =>
                          const Center(child: CircularProgressIndicator()),
                  errorWidget: (_, __, ___) {
                    return const Center(child: Icon(Icons.broken_image));
                  },
                );
              },
            )
            : const Center(
              child: Icon(Icons.casino, size: 50, color: Colors.grey),
            );
    return buildIndexItem<int>(
      context: context,
      id: gachaId,
      top: top,
      title: localizedName,
      subtitle: subTitleText,
      pageBuilder: (id) => GachaDetailPage(gachaId: id, showBanner: showBanner),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        ContentLocalizations.of(
          context,
        )?.translate('common', "gacha").translated ??
        'Gacha';

    final localizations = ContentLocalizations.of(context);
    FilterOptions filterOptions = FilterOptions(context);
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : IndexPage<Map<String, dynamic>>(
          title: title,
          allItems: _allGachas,
          showSearch: true,
          searchPredicate:
              (gacha, query) => (gacha['name'] as String)
                  .toLowerCase()
                  .contains(query.toLowerCase()),
          filters: [
            FilterConfig<Map<String, dynamic>>(
              header:
                  localizations?.translate('common', 'character').translated ??
                  'Character',
              options: filterOptions.characterOptions,
              filterFunc: (gacha, selected) {
                final characters =
                    (json.decode(gacha['characters'] ?? '[]') as List<dynamic>);
                return characters.any(
                  (character) => selected.contains(character.toString()),
                );
              },
            ),
            FilterConfig<Map<String, dynamic>>(
              header:
                  localizations?.translate('common', 'type').translated ??
                  'Type',
              options: filterOptions.gachatypeOptions,
              filterFunc: (gacha, selected) {
                return selected.contains(gacha['gachaType']);
              },
            ),
          ],
          pageSize: 10,
          scrollController: _scrollController,
          itemBuilder: _buildGachaItem,
        );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
