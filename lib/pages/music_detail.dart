import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:pjsk_viewer/pages/image_view.dart';
import 'package:pjsk_viewer/utils/audio_service.dart';
import 'package:pjsk_viewer/utils/database/music_database.dart';
import 'package:pjsk_viewer/i18n/localizations.dart';
import 'package:pjsk_viewer/utils/detail_builder.dart';
import 'package:pjsk_viewer/utils/globals.dart';
class MusicDetailPage extends StatefulWidget {
  final int musicId;
  const MusicDetailPage({required this.musicId, super.key});

  @override
  State<MusicDetailPage> createState() => _MusicDetailPageState();
}

class _MusicDetailPageState extends State<MusicDetailPage> {
  bool _isLoading = true;
  Map<String, dynamic>? _musicDetails;
  String? _errorMessage;
  late final AudioService _audioService;
  List<Map<String, dynamic>> _vocals = [];
  int? _selectedVocalIndex;
  List<String> _outsideCharacterNames = [];

  @override
  void initState() {
    super.initState();
    _audioService = AudioService();
    _fetchMusicDetails();
  }

  @override
  void dispose() {
    _audioService.dispose();
    super.dispose();
  }

  Future<void> _fetchMusicDetails() async {
    setState(() => _isLoading = true);
    try {
      _musicDetails = await MusicDatabase.getMusicById(widget.musicId);
      _vocals =
          json.decode(_musicDetails?['vocals']).cast<Map<String, dynamic>>();
      if (_vocals.isNotEmpty) {
        _selectedVocalIndex = 0;
        _loadSelectedVocal();
      }
      _outsideCharacterNames = await MusicDatabase.getOutsideCharacterNames();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _loadSelectedVocal() {
    final vocal = _vocals[_selectedVocalIndex!];
    final bundle = vocal['assetbundleName'] as String;
    final url = '${AppGlobals.assetUrl}/music/long/$bundle/$bundle.mp3';
    _audioService.loadAudio(url, skipSeconds: _musicDetails?["fillerSec"] ?? 0);
  }

  @override
  Widget build(BuildContext context) {
    final localizations = ContentLocalizations.of(context);

    // extract bundle name and build URL
    final assetbundleName = _musicDetails?['assetbundleName'] as String? ?? '';
    final logoUrl =
        assetbundleName.isNotEmpty
            ? '${AppGlobals.assetUrl}/music/jacket/$assetbundleName/$assetbundleName.webp'
            : '';

    return Scaffold(
      appBar: DetailBuilder.buildAppBar(context, _musicDetails?['title']),
      body: Center(
        child:
            _isLoading
                ? const CircularProgressIndicator()
                : _errorMessage != null
                ? Text('Error: $_errorMessage')
                : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      buildHeroImageViewer(context, logoUrl),
                      const SizedBox(height: 16),

                      // Vocal selector
                      if (_vocals.isNotEmpty) ...[
                        Card(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          margin: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: SizedBox(
                              width: double.infinity,
                              child: DropdownButton<int>(
                                isExpanded: true,
                                value: _selectedVocalIndex,
                                // allow variable item heights
                                itemHeight: null,
                                items:
                                    _vocals.asMap().entries.map((e) {
                                      final caption =
                                          e.value['caption'] as String? ?? '';
                                      final name = MusicDatabase.buildVocalName(
                                        context,
                                        e.value,
                                        _outsideCharacterNames,
                                      );
                                      return DropdownMenuItem<int>(
                                        value: e.key,
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 8.0,
                                            horizontal: 4.0,
                                          ),
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                caption,
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.titleMedium,
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                name,
                                                style:
                                                    Theme.of(
                                                      context,
                                                    ).textTheme.bodyMedium,
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                onChanged: (idx) {
                                  if (_selectedVocalIndex == idx) return;
                                  setState(() {
                                    _selectedVocalIndex = idx;
                                    _loadSelectedVocal();
                                  });
                                },
                              ),
                            ),
                          ),
                        ),

                        //audio player
                        AudioPlayerFull(audioService: _audioService),
                        const SizedBox(height: 16),
                      ],
                    ],
                  ),
                ),
      ),
    );
  }
}
