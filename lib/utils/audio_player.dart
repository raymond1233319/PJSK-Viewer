import 'dart:async';
import 'dart:developer' as developer;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:pjsk_viewer/utils/globals.dart';
import 'package:pjsk_viewer/utils/helper.dart';
import 'package:rxdart/rxdart.dart';
import 'package:pjsk_viewer/i18n/app_localizations.dart';
import 'package:video_player/video_player.dart';
import 'audio_handler.dart';

/// Mixin with unimplemented audio control methods that must be implemented by classes using it
mixin PlayerController {
  bool get isVideo => false;
  void onDownload(BuildContext context);
  void onPlay();
  void onPause();
  void onReplay();
  void onSeek(Duration position);
  void onNext() {}
  void onPrevious() {}
  bool get supportsPlaylistControls => false;
  bool get needVolumeControl => true;
  bool get needDownloadButton => true;

  Stream<PositionData> getPositionDataStream() {
    return Stream.value(
      PositionData(Duration.zero, Duration.zero, Duration.zero),
    );
  }

  Stream<PlayerState> getPlayerStateStream() {
    return Stream.value(PlayerState(false, ProcessingState.idle));
  }

  Widget? buildVideoWidget(BuildContext context) => null;

  Widget buildPlayerControls(BuildContext context) {
    {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video display (if applicable)
          if (isVideo) buildVideoWidget(context) ?? const SizedBox.shrink(),

          // --- Progress Bar (Slider) ---
          progressBar(getPositionDataStream(), onSeek),
          const SizedBox(height: 8),

          // --- Control Buttons (Row) ---
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Download Button
              if (needDownloadButton && !supportsPlaylistControls) downloadButton(context, onDownload),
              if (needDownloadButton && !supportsPlaylistControls) const Spacer(),

              // Add previous song button if supported
              if (supportsPlaylistControls) previousButton(onPrevious),

              // Play/Pause/Replay Button
              playButton(getPlayerStateStream(), onPlay, onPause, onReplay),

              // Add next song button if supported
              if (supportsPlaylistControls) nextButton(onNext),

              // Volume Control
              if (needVolumeControl && !supportsPlaylistControls)
                const Spacer(),
              if (needVolumeControl && !supportsPlaylistControls)
                voulmnControl(globalVolumnStream),
            ],
          ),
        ],
      );
    }
  }
}

Widget progressBar(Stream<PositionData> positionDataStream, onSeek) {
  // --- Progress Bar (Slider) ---
  return StreamBuilder<PositionData>(
    stream: positionDataStream,
    builder: (context, snapshot) {
      final positionData = snapshot.data;
      final duration = positionData?.duration ?? Duration.zero;
      final position = positionData?.position ?? Duration.zero;
      final displayPosition = (position > duration) ? duration : position;
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
                value: displayPosition.inMilliseconds.toDouble().clamp(
                  0.0,
                  duration.inMilliseconds.toDouble(),
                ),
                onChanged:
                    (value) => onSeek(Duration(milliseconds: value.round())),
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
  );
}

Widget playButton(
  Stream<PlayerState> playerStateStream,
  onPlay,
  onPause,
  onReplay, {
  double size = 36,
}) {
  return StreamBuilder<PlayerState>(
    stream: playerStateStream,
    builder: (context, snapshot) {
      final playerState = snapshot.data;
      final processingState = playerState?.processingState;
      final playing = playerState?.playing;

      if (processingState == ProcessingState.loading ||
          processingState == ProcessingState.buffering) {
        return Container(
          margin: const EdgeInsets.all(8.0),
          width: size,
          height: size,
          child: const CircularProgressIndicator(),
        );
      } else if (playing != true) {
        return Tooltip(
          message:
              AppGlobals.i18n.translate('app', 'tooltip_play_audio').translated,
          child: IconButton(
            icon: const Icon(Icons.play_arrow),
            iconSize: size,
            onPressed: () => onPlay(),
          ),
        );
      } else if (processingState != ProcessingState.completed) {
        return Tooltip(
          message:
              AppGlobals.i18n
                  .translate('app', 'tooltip_pause_audio')
                  .translated,
          child: IconButton(
            icon: const Icon(Icons.pause),
            iconSize: size,
            onPressed: () => onPause(),
          ),
        );
      } else {
        return Tooltip(
          message:
              AppGlobals.i18n
                  .translate('app', 'tooltip_replay_audio')
                  .translated,
          child: IconButton(
            icon: const Icon(Icons.replay),
            iconSize: size,
            onPressed: () => onReplay(),
          ),
        );
      }
    },
  );
}

Widget globalVolumnStream() {
  return StreamBuilder<double>(
    stream: AppGlobals.audioHandler.volumeStream,
    builder: (context, snapshot) {
      return Slider(
        divisions: 10,
        min: 0.0,
        max: 1.0,
        value: snapshot.data ?? 1.0,
        onChanged: (value) {
          AppGlobals.audioHandler.setVolume(value);
        },
      );
    },
  );
}

Widget voulmnControl(volumnStream) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const Icon(Icons.volume_up, size: 24.0),
      SizedBox(width: 100, child: volumnStream()),
    ],
  );
}

Widget downloadButton(BuildContext context, onDownload) {
  return Tooltip(
    message:
        AppGlobals.i18n.translate('app', 'tooltip_download_audio').translated,
    child: IconButton(
      icon: const Icon(Icons.download),
      iconSize: 32.0,
      onPressed: () => onDownload(context),
    ),
  );
}

/// Widget for the previous track button
Widget previousButton(onPrevious) {
  return Tooltip(
    message:
        AppGlobals.i18n.translate('app', 'tooltip_previous_track').translated,
    child: IconButton(
      icon: const Icon(Icons.skip_previous),
      iconSize: 32.0,
      onPressed: onPrevious,
    ),
  );
}

/// Widget for the next track button
Widget nextButton(onNext) {
  return Tooltip(
    message: AppGlobals.i18n.translate('app', 'tooltip_next_track').translated,
    child: IconButton(
      icon: const Icon(Icons.skip_next),
      iconSize: 32.0,
      onPressed: onNext,
    ),
  );
}

/// A full-featured audio player widget with a progress bar, play/pause,
/// replay, download placeholder, and volume control implemented as a stateless widget.
class AudioPlayerFull extends StatelessWidget with PlayerController {
  final MediaItem mediaItem;
  @override
  final bool needVolumeControl;
  @override
  final bool needDownloadButton;
  final bool playerMode;
  final ValueNotifier<bool> _hasLoadedNotifier = ValueNotifier(false);

  /// Creates a new AudioPlayerFull widget
  ///
  /// [mediaItem] contains details of the audio to play
  /// [supportsPlaylistControls] determines if next/previous buttons should be shown
  /// [needVolumeControl] determines if volume slider should be shown
  /// [needDownloadButton] determines if download button should be shown
  AudioPlayerFull({
    super.key,
    required this.mediaItem,
    this.needVolumeControl = true,
    this.needDownloadButton = true,
    this.playerMode = false,
  });

  /// Initialize audio
  Future<void> loadAudio({Duration? startPosition}) async {
    await AppGlobals.audioHandler.updateQueue([mediaItem]);
    await AppGlobals.audioHandler.skipToQueueItem(0);
    if (startPosition != null) {
      await AppGlobals.audioHandler.seek(startPosition);
    }
  }

  @override
  bool get isVideo => false;
  bool get isPlaying =>
      AppGlobals.audioHandler.isPlaying && _hasLoadedNotifier.value;
  @override
  bool get supportsPlaylistControls => playerMode;

  // Alternative async method to get the current position
  Future<Duration> getCurrentPosition() async {
    if (!_hasLoadedNotifier.value) return Duration.zero;
    return AppGlobals.audioHandler.currentPosition;
  }

  @override
  void onDownload(BuildContext context) async {
    await downloadToDevice(context, mediaItem.id);
  }

  @override
  void onPlay() async {
    // Check if we need to load the audio first
    if (!_hasLoadedNotifier.value) {
      await loadAudio();
      _hasLoadedNotifier.value = true;
    }
    AppGlobals.audioHandler.play();
  }

  @override
  void onPause() {
    AppGlobals.audioHandler.pause();
  }

  @override
  void onReplay() {
    AppGlobals.audioHandler.seek(
      Duration(seconds: mediaItem.extras?['skipSeconds']?.toInt() ?? 0),
    );
  }

  @override
  void onSeek(Duration position) {
    AppGlobals.audioHandler.seek(position);
  }

  @override
  void onNext() {
    if (!playerMode) return;
    AppGlobals.audioHandler.skipToNext();
  }

  @override
  void onPrevious() {
    if (!playerMode) return;
    AppGlobals.audioHandler.skipToPrevious();
  }

  @override
  Stream<PositionData> getPositionDataStream() {
    if (!_hasLoadedNotifier.value) return super.getPositionDataStream();
    return AppGlobals.audioHandler.positionDataStream;
  }

  @override
  Stream<PlayerState> getPlayerStateStream() {
    if (!_hasLoadedNotifier.value) return super.getPlayerStateStream();
    return AppGlobals.audioHandler.playerStateStream;
  }

  @override
  Widget build(BuildContext context) {
    // Check if this is the current source when widget is built
    Future.microtask(() async {
      final bool isCurrentSource = await AppGlobals.audioHandler
          .isCurrentSource(mediaItem.id);
      if (isCurrentSource) {
        _hasLoadedNotifier.value = true;
      }
    });
    return ValueListenableBuilder<bool>(
      valueListenable: _hasLoadedNotifier,
      builder: (context, _, _) {
        return buildPlayerControls(context);
      },
    );
  }
}

class AudioPlayerWithMv extends AudioPlayerFull {
  final MVPlayer mvPlayer;
  AudioPlayerWithMv({
    super.key,
    required super.mediaItem,
    required this.mvPlayer,
    super.playerMode,
  });
  @override
  Future<void> loadAudio({Duration? startPosition}) async {
    developer.log(startPosition.toString(), name: 'AudioPlayerWithMv');
    await super.loadAudio(startPosition: startPosition);
    mvPlayer.onSeek(
      startPosition ??
          Duration(seconds: mediaItem.extras?['skipSeconds']?.toInt() ?? 0),
    );
  }

  @override
  void onPlay() {
    super.onPlay();
    mvPlayer.onPlay();
  }

  @override
  void onPause() {
    super.onPause();
    mvPlayer.onPause();
  }

  @override
  void onReplay() {
    super.onReplay();
    mvPlayer.onReplay();
  }

  @override
  void onSeek(Duration position) {
    super.onSeek(position);
    mvPlayer.onSeek(position);
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
        final audioSource = AudioSource.uri(Uri.parse(url));

        AudioSource effectiveSource = audioSource;
        if (skipSeconds != null && skipSeconds > 0) {
          effectiveSource = ClippingAudioSource(
            start: Duration(seconds: skipSeconds.toInt()),
            child: audioSource,
          );
        }
        await player.setAudioSource(effectiveSource);
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

/// Video player
class MVPlayer extends StatelessWidget with PlayerController {
  final String videoUrl;
  final int skipSeconds;
  final VideoPlayerController videoController;
  final bool isInitialized;
  final StreamController<VideoPlayerValue> videoStateController;

  /// Creates a new MVPlayer widget
  ///
  /// [videoUrl] is the URL of the video to play
  /// [skipSeconds] is the number of seconds to skip at the beginning of the video
  /// [videoController] is the externally managed VideoPlayerController
  /// [isInitialized] indicates if the controller is ready to use
  /// [videoStateController] is the stream controller for video state updates
  const MVPlayer({
    super.key,
    required this.videoUrl,
    this.skipSeconds = 0,
    required this.videoController,
    required this.isInitialized,
    required this.videoStateController,
  });

  /// Factory method to create an MVPlayer with its controller
  /// This handles the initialization that was previously in the StatefulWidget
  static Future<MVPlayer> create({
    Key? key,
    required String videoUrl,
    int skipSeconds = 0,
  }) async {
    // Create state controller
    final videoStateController = StreamController<VideoPlayerValue>.broadcast();

    // Create and initialize video controller
    final videoController = VideoPlayerController.networkUrl(
      Uri.parse(videoUrl),
      videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
    );

    // Add listener to update state
    videoController.addListener(() {
      if (videoStateController.hasListener) {
        videoStateController.add(videoController.value);
      }
    });

    // Initialize controller
    bool isInitialized = false;
    try {
      await videoController.initialize();
      await videoController.setLooping(false);
      await videoController.seekTo(Duration(seconds: skipSeconds));
      isInitialized = true;
    } catch (e) {
      developer.log(
        'Error initializing video controller: $e',
        name: 'MVPlayer',
      );
    }

    // Return constructed widget
    return MVPlayer(
      key: key,
      videoUrl: videoUrl,
      skipSeconds: skipSeconds,
      videoController: videoController,
      isInitialized: isInitialized,
      videoStateController: videoStateController,
    );
  }

  @override
  Stream<PositionData> getPositionDataStream() {
    if (!isInitialized) return super.getPositionDataStream();
    return videoStateController.stream.map((videoPlayerValue) {
      final currentPosition = videoPlayerValue.position;
      final currentDuration = videoPlayerValue.duration;
      final currentBufferedPosition =
          videoPlayerValue.buffered.isNotEmpty
              ? videoPlayerValue.buffered.last.end
              : Duration.zero;
      return PositionData(
        currentPosition,
        currentBufferedPosition,
        currentDuration,
      );
    }).asBroadcastStream();
  }

  @override
  Stream<PlayerState> getPlayerStateStream() {
    if (!isInitialized) return super.getPlayerStateStream();

    // Map video controller stream to PlayerState
    return videoStateController.stream.map((value) {
      final bool isPlaying = value.isPlaying;

      ProcessingState state = ProcessingState.idle;
      if (value.position >= value.duration) {
        state = ProcessingState.completed;
      } else if (isPlaying) {
        state = ProcessingState.ready;
      }
      return PlayerState(isPlaying, state);
    }).asBroadcastStream();
  }

  @override
  bool get isVideo => true;

  @override
  void onDownload(BuildContext context) async {
    if (videoUrl.isEmpty) return;
    await downloadToDevice(context, videoUrl);
  }

  @override
  void onPlay() {
    videoController.play();
  }

  @override
  void onPause() {
    videoController.pause();
  }

  @override
  void onReplay() {
    videoController.seekTo(Duration(seconds: skipSeconds));
  }

  @override
  void onSeek(Duration position) {
    videoController.seekTo(position);
  }

  void dispose() {
    videoController.dispose();
    videoStateController.close();
  }

  @override
  Widget build(BuildContext context) {
    if (!isInitialized) {
      return const Center(child: CircularProgressIndicator());
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth;

        // Create a square container
        return Container(
          width: size,
          height: size,
          color: Colors.black,
          child: Center(
            // Keep the original AspectRatio to avoid video distortion
            child: AspectRatio(
              aspectRatio: videoController.value.aspectRatio,
              child: VideoPlayer(videoController),
            ),
          ),
        );
      },
    );
  }
}
