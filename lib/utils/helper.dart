import 'dart:convert';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart' as perm;
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:share_plus/share_plus.dart';

class MarqueeText extends StatefulWidget {
  final String text;
  final double scrollSpeed;
  final TextStyle? style;

  const MarqueeText(
    this.text, {
    this.scrollSpeed = 30.0,
    this.style,
    super.key,
  });

  @override
  State<MarqueeText> createState() => _MarqueeTextState();
}

class _MarqueeTextState extends State<MarqueeText>
    with SingleTickerProviderStateMixin {
  late ScrollController _scrollController;
  late AnimationController _animationController;
  double _textWidth = 0.0;
  double _containerWidth = 0.0;
  bool _needsScroll = false;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    );
    WidgetsBinding.instance.addPostFrameCallback(_postFrameCallback);
  }

  void _postFrameCallback(_) {
    if (!mounted) return;
    final RenderBox? renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null || !renderBox.hasSize) return;
    _containerWidth = renderBox.size.width;

    final textStyle = widget.style ?? Theme.of(context).textTheme.titleLarge;

    final TextPainter painter = TextPainter(
      text: TextSpan(text: widget.text, style: textStyle),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);

    _textWidth = painter.width;
    _needsScroll = _textWidth > _containerWidth;

    if (_needsScroll) {
      final scrollDistance = _textWidth;
      final duration = Duration(
        milliseconds: (scrollDistance / widget.scrollSpeed * 1000).round(),
      );
      _animationController.duration = duration;
      _startAnimation();
    }
  }

  void _startAnimation() {
    if (!mounted) return;
    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _scrollController.jumpTo(0.0);
        _animationController.forward(from: 0.0);
      }
    });
    _scrollController.jumpTo(0.0);
    _animationController.forward(from: 0.0);
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final textStyle = widget.style ?? Theme.of(context).textTheme.titleLarge;

    if (!_needsScroll) {
      return Text(
        widget.text,
        style: textStyle,
        overflow: TextOverflow.ellipsis,
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      controller: _scrollController,
      physics: const NeverScrollableScrollPhysics(),
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          final scrollPosition = _animationController.value * _textWidth;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && _scrollController.hasClients) {
              _scrollController.jumpTo(scrollPosition);
            }
          });
          return child!;
        },
        child: Row(
          children: [
            Text(widget.text, style: textStyle),
            SizedBox(width: _containerWidth > 0 ? _containerWidth * 0.5 : 50),
            Text(widget.text, style: textStyle),
          ],
        ),
      ),
    );
  }
}

// Helper function to format duration into mm:ss string
String formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}

// Helper to format dates
String formatDate(int? timestamp) {
  final DateFormat dateFormatter = DateFormat("yyyy-MM-dd HH:mm:ss");
  if (timestamp == null || timestamp == 0) return 'N/A';
  try {
    return dateFormatter.format(
      DateTime.fromMillisecondsSinceEpoch(timestamp).toLocal(),
    );
  } catch (e) {
    return 'Invalid Date';
  }
}

/// Helper to navigate to detail page
void navigateToDetailPage<T>({
  required BuildContext context,
  required T? id,
  required Widget Function(T id) pageBuilder,
  String? errorMessage,
}) {
  final localizations = AppLocalizations.of(context);
  if (id != null) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => pageBuilder(id)));
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          errorMessage ?? localizations.translate('item_not_found'),
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }
}

String generateSkillDescription({
  required String descriptionTemplate,
  required List<Map<String, dynamic>> skillsJson,
  required int skillId,
  required int skillLevel,
  String? chracterName,
  int characterRank = 1,
}) {
  final Map<String, dynamic>? skillDetail = skillsJson.firstWhereOrNull(
    (s) => s['id'] == skillId,
  );
  if (skillDetail == null) return descriptionTemplate;

  if (descriptionTemplate.isEmpty) {
    descriptionTemplate = skillDetail['description'] ?? '';
  }

  final skillEffectsData =
      (skillDetail['skillEffects'] as List).cast<Map<String, dynamic>>();

  final placeholderRegex = RegExp(r'\{\{([\d,]+);([A-Za-z]+)\}\}');
  return descriptionTemplate.replaceAllMapped(placeholderRegex, (m) {
    final idsPart = m.group(1)!;
    final valueType = m.group(2)!;
    final ids = idsPart.split(',').map(int.parse).toList();

    Map<String, dynamic>? effect;
    Map<String, dynamic>? detail;
    double raw = 0;

    for (var id in ids) {
      effect = skillEffectsData.firstWhereOrNull((e) => e['id'] == id);
      if (effect != null) {
        detail = (effect['skillEffectDetails'] as List)
            .cast<Map<String, dynamic>>()
            .firstWhereOrNull((d) => d['level'] == skillLevel);
        if (detail != null && detail.containsKey('activateEffectValue')) {
          switch (valueType) {
            case 'd':
              raw += detail['activateEffectDuration'].toDouble();
              break;
            case 'e':
              raw += effect["skillEnhance"]["activateEffectValue"];
              break;
            case 'm':
              raw += detail['activateEffectValue'].toDouble() + 50;
              break;
            default:
              raw += detail['activateEffectValue'].toDouble();
              break;
          }
        }
      }
    }

    if (valueType == 'c') {
      return chracterName ?? 'Unknown';
    }
    if (valueType == 'r') {
      raw -= 51 - (characterRank / 2).toInt();
    }
    if (valueType == 's') {
      raw -= 50 - (characterRank / 2).toInt();
    }

    if (raw == raw.truncateToDouble()) {
      return raw.toInt().toString();
    }
    return raw.toString();
  });
}

/// Returns the combined LocalizedText (first + last name) for a character.
LocalizedText getLocalizedCharacterName(
  ContentLocalizations localizations,
  String characterId,
) {
  final first = localizations.translate(
    'character_name',
    characterId,
    innerKey: 'firstName',
  );
  final last = localizations.translate(
    'character_name',
    characterId,
    innerKey: 'givenName',
  );
  final japanese = '${first.japanese} ${last.japanese}'.trim();
  final translated = '${first.translated} ${last.translated}'.trim();
  return LocalizedText(japaneseText: japanese, translatedText: translated);
}

Widget buildFullWidthItem(
  BuildContext context,
  Widget child, {
  required double rawW,
  required double rawH,
}) {
  return AspectRatio(aspectRatio: rawW / rawH, child: child);
}

/// Downloads the file at [url] to the device’s downloads directory (or app doc dir),
/// showing SnackBars for status.
Future<void> downloadToDevice(BuildContext context, String url) async {
  final localizations = AppLocalizations.of(context);
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(localizations.translate('downloading_message'))),
  );
  try {
    if (Platform.isAndroid) {
      bool permissionGranted = false;
      var status = await perm.Permission.storage.status;
      if (status.isGranted) {
        permissionGranted = true;
      } else {
        status = await perm.Permission.storage.request();
        if (status.isGranted) {
          permissionGranted = true;
        }
      }
      if (!permissionGranted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              localizations.translate('storage_permission_required_message'),
            ),
          ),
        );
      }
      final fileName = url.split('/').last;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$fileName');
      final respone = await http.get(Uri.parse(url));
      debugPrint(url);
      await file.writeAsBytes(respone.bodyBytes);
      final params = ShareParams(files: [XFile(file.path)]);
      await SharePlus.instance.share(params);
    }
    if (Platform.isIOS) {
      final box = context.findRenderObject() as RenderBox?;
      final params = ShareParams(
        uri: Uri.parse(url),
        sharePositionOrigin: box!.localToGlobal(Offset.zero) & box.size,
      );
      SharePlus.instance.share(params);
    }
  } catch (e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          localizations
              .translate('download_failed_message')
              .replaceFirst('%s', '$e'),
        ),
      ),
    );
  }
}

Future<List<Map<String, dynamic>>> fetchEventRanking(
  int eventId,
  int characterId,
) async {
  final uri =
      (characterId != -1)
          ? await () async {
            final timeResp = await http.get(
              Uri.parse(
                '${AppGlobals.apiUrl}/event/$eventId/chapter_rankings/time?charaId=$characterId&region=${AppGlobals.region}',
              ),
            );
            final times =
                (json.decode(timeResp.body) as Map<String, dynamic>)['data']
                    as List;
            final ts = times.last as String;
            return Uri.parse(
              '${AppGlobals.apiUrl}/event/$eventId/chapter_rankings?charaId=$characterId&region=${AppGlobals.region}&timestamp=$ts',
            );
          }()
          : await () async {
            final timeResp = await http.get(
              Uri.parse(
                '${AppGlobals.apiUrl}/event/$eventId/rankings/time?region=${AppGlobals.region}',
              ),
            );
            final times =
                (json.decode(timeResp.body) as Map<String, dynamic>)['data']
                    as List;
            final ts = times.last as String;
            return Uri.parse(
              '${AppGlobals.apiUrl}/event/$eventId/rankings?region=${AppGlobals.region}&timestamp=$ts',
            );
          }();
  final respone = await http.get(uri);

  if (respone.statusCode == 200) {
    final jsonMap = json.decode(respone.body) as Map<String, dynamic>;
    return (jsonMap['data']['eventRankings'] as List)
        .map((e) => e as Map<String, dynamic>)
        .toList();
  } else {
    throw Exception('Error: ${respone.statusCode}');
  }
}

LocalizedText replaceMainText(LocalizedText original, String mainText) {
  return LocalizedText(
    japaneseText: mainText,
    translatedText: original.japanese,
  );
}
