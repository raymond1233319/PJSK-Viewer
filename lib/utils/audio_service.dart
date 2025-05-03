import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:rxdart/rxdart.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';

// Helper class for position data
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

// Helper function to format duration into mm:ss string
String formatDuration(Duration d) {
  final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return "$minutes:$seconds";
}



/// A full-featured audio player widget with a progress bar, play/pause,
/// replay, download placeholder, and volume control.
class AudioPlayerFull extends StatelessWidget {
  final AudioService audioService;
  const AudioPlayerFull({super.key, required this.audioService});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Progress Bar (Slider) ---
            StreamBuilder<PositionData>(
              stream: audioService.positionDataStream,
              builder: (context, snapshot) {
                final positionData = snapshot.data;
                final duration = positionData?.duration ?? Duration.zero;
                final position = positionData?.position ?? Duration.zero;
                final displayPosition =
                    (position > duration) ? duration : position;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    children: [
                      Text(
                        formatDuration(displayPosition),
                        style: const TextStyle(fontSize: 12),
                      ),
                      Expanded(
                        child: Slider(
                          min: 0.0,
                          max: duration.inMilliseconds.toDouble() + 1.0,
                          value: displayPosition.inMilliseconds
                              .toDouble()
                              .clamp(0.0, duration.inMilliseconds.toDouble()),
                          onChanged: (value) {
                            audioService.player.seek(
                              Duration(milliseconds: value.round()),
                            );
                          },
                        ),
                      ),
                      Text(
                        formatDuration(duration),
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 8),

            // --- Control Buttons (Row) ---
            Row(
              children: [
                // Download Button
                Tooltip(
                  message: localizations.translate('tooltip_download_audio'),
                  child: IconButton(
                    icon: const Icon(Icons.download),
                    iconSize: 32.0,
                    onPressed: () async {
                      final url = audioService.currentAudioUrl;
                      if (url == null) return;
                      await downloadToDevice(context, url);
                    },
                  ),
                ),
                const Spacer(),

                // Play/Pause/Replay Button
                StreamBuilder<PlayerState>(
                  stream: audioService.player.playerStateStream,
                  builder: (context, snapshot) {
                    final playerState = snapshot.data;
                    final processingState = playerState?.processingState;
                    final playing = playerState?.playing;

                    if (processingState == ProcessingState.loading ||
                        processingState == ProcessingState.buffering) {
                      return Container(
                        margin: const EdgeInsets.all(8.0),
                        width: 48.0,
                        height: 48.0,
                        child: const CircularProgressIndicator(),
                      );
                    } else if (playing != true) {
                      return Tooltip(
                        message: localizations.translate('tooltip_play_audio'),
                        child: IconButton(
                          icon: const Icon(Icons.play_arrow),
                          iconSize: 48.0,
                          onPressed: audioService.player.play,
                        ),
                      );
                    } else if (processingState != ProcessingState.completed) {
                      return Tooltip(
                        message: localizations.translate('tooltip_pause_audio'),
                        child: IconButton(
                          icon: const Icon(Icons.pause),
                          iconSize: 48.0,
                          onPressed: audioService.player.pause,
                        ),
                      );
                    } else {
                      return Tooltip(
                        message: localizations.translate(
                          'tooltip_replay_audio',
                        ),
                        child: IconButton(
                          icon: const Icon(Icons.replay),
                          iconSize: 48.0,
                          onPressed:
                              () => audioService.player.seek(Duration.zero),
                        ),
                      );
                    }
                  },
                ),

                const Spacer(),

                // Volume Control
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.volume_up, size: 24.0),
                    SizedBox(
                      width: 100,
                      child: StreamBuilder<double>(
                        stream: audioService.player.volumeStream,
                        builder: (context, snapshot) {
                          return Slider(
                            divisions: 10,
                            min: 0.0,
                            max: 1.0,
                            value: snapshot.data ?? 1.0,
                            onChanged: audioService.player.setVolume,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// A simplified audio player widget with only a play/pause button.
class SimpleAudioPlayer extends StatelessWidget {
  final AudioService audioService;
  const SimpleAudioPlayer({super.key, required this.audioService});

  @override
  Widget build(BuildContext context) {
    final localizations = AppLocalizations.of(context);
    return StreamBuilder<PlayerState>(
      stream: audioService.player.playerStateStream,
      builder: (context, snapshot) {
        final playerState = snapshot.data;
        final processingState = playerState?.processingState;
        final playing = playerState?.playing ?? false;

        // Check if audio has completed playing
        if (processingState == ProcessingState.completed) {
          // When audio completes, reset to beginning
          audioService.player.pause();
          Future.microtask(() => audioService.player.seek(Duration.zero));
        }

        bool isPlaying =
            (playing && processingState != ProcessingState.completed);

        return Row(
          children: [
            Tooltip(
              message:
                  isPlaying
                      ? localizations.translate('tooltip_pause_audio')
                      : localizations.translate('tooltip_play_audio'),
              child: IconButton(
                iconSize: 24.0,
                // Show play icon if not playing or if completed
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () {
                  if (playing) {
                    audioService.player.pause();
                  } else {
                    // If completed, first seek to beginning
                    if (processingState == ProcessingState.completed) {
                      audioService.player.seek(Duration.zero);
                    }
                    audioService.player.play();
                  }
                },
              ),
            ),
            Tooltip(
              message: localizations.translate('tooltip_download_audio'),
              child: IconButton(
                icon: const Icon(Icons.download),
                iconSize: 24.0,
                onPressed: () async {
                  final url = audioService.currentAudioUrl;
                  if (url == null) return;
                  await downloadToDevice(context, url);
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

/// A basic AudioService that holds the player & audioExists status.
class AudioService {
  final AudioPlayer player = AudioPlayer();
  bool audioExists = false; // Set to true if an audio URL is valid
  String? currentAudioUrl; // Current audio URL

  /// Combined stream of playback position, buffer position, and duration.
  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        player.positionStream,
        player.bufferedPositionStream,
        player.durationStream,
        (position, buffered, duration) =>
            PositionData(position, buffered, duration ?? Duration.zero),
      ).asBroadcastStream();

  Future<void> loadAudio(String url, {double? skipSeconds}) async {
    audioExists = false;
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        currentAudioUrl = url;
        final clipped = ClippingAudioSource(
          start: Duration(seconds: (skipSeconds ?? 0).toInt()),
          child: AudioSource.uri(Uri.parse(url)),
        );
        // load the clipped source instead of raw URL
        await player.setAudioSource(clipped);

        audioExists = true;
      } else {
        audioExists = false;
      }
    } catch (e) {
      audioExists = false;
    }
  }

  void dispose() {
    player.dispose();
  }
}
