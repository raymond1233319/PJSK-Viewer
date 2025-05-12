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

  Stream<PositionData> getPositionDataStream() {
    return Stream.value(
      PositionData(Duration.zero, Duration.zero, Duration.zero),
    );
  }

  Stream<PlayerState> getPlayerStateStream() {
    return Stream.value(PlayerState(false, ProcessingState.idle));
  }

  Widget volumnStream() {
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

  Widget? buildVideoWidget(BuildContext context) => null;

  Widget buildPlayerControls(BuildContext context) {
    {
      final localizations = AppLocalizations.of(context);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Video display (if applicable)
          if (isVideo) buildVideoWidget(context) ?? const SizedBox.shrink(),

          // --- Progress Bar (Slider) ---
          StreamBuilder<PositionData>(
            stream: getPositionDataStream(),
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
                        value: displayPosition.inMilliseconds.toDouble().clamp(
                          0.0,
                          duration.inMilliseconds.toDouble(),
                        ),
                        onChanged:
                            (value) =>
                                onSeek(Duration(milliseconds: value.round())),
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
                  onPressed: () => onDownload(context),
                ),
              ),
              const Spacer(),

              // Play/Pause/Replay Button
              StreamBuilder<PlayerState>(
                stream: getPlayerStateStream(),
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
                        onPressed: () => onPlay(),
                      ),
                    );
                  } else if (processingState != ProcessingState.completed) {
                    return Tooltip(
                      message: localizations.translate('tooltip_pause_audio'),
                      child: IconButton(
                        icon: const Icon(Icons.pause),
                        iconSize: 48.0,
                        onPressed: () => onPause(),
                      ),
                    );
                  } else {
                    return Tooltip(
                      message: localizations.translate('tooltip_replay_audio'),
                      child: IconButton(
                        icon: const Icon(Icons.replay),
                        iconSize: 48.0,
                        onPressed: () => onReplay(),
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
                  SizedBox(width: 100, child: volumnStream()),
                ],
              ),
            ],
          ),
        ],
      );
    }
  }
}

/// A full-featured audio player widget with a progress bar, play/pause,
/// replay, download placeholder, and volume control.
class AudioPlayerFull extends StatefulWidget {
  final bool loadOnDemand;
  final String url;
  final String? title;
  final String? artist;
  final String? artUrl;
  final double? skipSeconds;

  const AudioPlayerFull({
    super.key,
    this.loadOnDemand = true,
    required this.url,
    this.title,
    this.artist,
    this.artUrl,
    this.skipSeconds,
  });

  @override
  State<AudioPlayerFull> createState() => _AudioPlayerFullState();
}

class _AudioPlayerFullState extends State<AudioPlayerFull>
    with PlayerController {
  bool _hasLoadedAudio = false;

  @override
  void initState() {
    super.initState();
    if (!widget.loadOnDemand) {
      _loadAudio();
    }
  }

  Future<void> _loadAudio() async {
    if (_hasLoadedAudio) return;

    await AppGlobals.audioHandler.loadAudioSource(
      url: widget.url,
      title: widget.title,
      artist: widget.artist,
      artUrl: widget.artUrl,
      skipSeconds: widget.skipSeconds,
    );
    setState(() {
      _hasLoadedAudio = true;
    });
  }

  @override
  bool get isVideo => false;

  @override
  void onDownload(BuildContext context) async {
    await downloadToDevice(context, widget.url);
  }

  @override
  void onPlay() async {
    if (widget.loadOnDemand && !_hasLoadedAudio) {
      await _loadAudio();
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
      Duration(seconds: widget.skipSeconds?.toInt() ?? 0),
    );
  }

  @override
  void onSeek(Duration position) {
    AppGlobals.audioHandler.seek(position);
  }

  @override
  Stream<PositionData> getPositionDataStream() {
    if (!_hasLoadedAudio) return super.getPositionDataStream();
    return AppGlobals.audioHandler.customPositionDataStream;
  }

  @override
  Stream<PlayerState> getPlayerStateStream() {
    if (!_hasLoadedAudio) return super.getPlayerStateStream();
    return AppGlobals.audioHandler.playbackState.map((state) {
      final processingState = switch (state.processingState) {
        AudioProcessingState.idle => ProcessingState.idle,
        AudioProcessingState.loading => ProcessingState.loading,
        AudioProcessingState.buffering => ProcessingState.buffering,
        AudioProcessingState.ready => ProcessingState.ready,
        AudioProcessingState.completed => ProcessingState.completed,
        AudioProcessingState.error => ProcessingState.idle,
      };
      return PlayerState(state.playing, processingState);
    });
  }

  @override
  Widget build(BuildContext context) {
    return buildPlayerControls(context);
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

/// A video player implementation using PlayerController and video_player package
class MVPlayer extends StatefulWidget {
  final String videoUrl;
  final int skipSeconds;

  const MVPlayer({super.key, required this.videoUrl, this.skipSeconds = 0});
  @override
  State<MVPlayer> createState() => _MVPlayerState();
}

class _MVPlayerState extends State<MVPlayer> with PlayerController {
  VideoPlayerController? _videoController;
  bool _isInitialized = false;
  bool _isLoading = false;
  final StreamController<VideoPlayerValue> _videoStateController =
      StreamController<VideoPlayerValue>.broadcast();

  @override
  void initState() {
    super.initState();
    _initVideoPlayer();
  }

  @override
  Stream<PositionData> getPositionDataStream() {
    if (!_isInitialized) return super.getPositionDataStream();
    return _videoStateController.stream.map((videoPlayerValue) {
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
    if (!_isInitialized) return super.getPlayerStateStream();
    developer.log(
      'VideoPlayerController: ${_videoController?.value}',
      name: 'MVPlayer',
    );
    // Map video controller stream to PlayerState
    return _videoStateController.stream.map((value) {
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

  Future<void> _initVideoPlayer() async {
    _videoController = VideoPlayerController.networkUrl(
      Uri.parse(widget.videoUrl),
    );

    try {
      _videoController!.addListener(_updateVideoState);
      await _videoController!.initialize();
      await _videoController!.setLooping(false);
      await _videoController!.seekTo(Duration(seconds: widget.skipSeconds));
      setState(() {
        _isInitialized = true;
        _isLoading = false;
      });
    } catch (_) {}
  }

  void _updateVideoState() {
    if (_videoController != null && _videoStateController.hasListener) {
      _videoStateController.add(_videoController!.value);
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    _videoStateController.close();
    super.dispose();
  }

  @override
  bool get isVideo => true;

  @override
  void onDownload(BuildContext context) async {
    final url = widget.videoUrl;
    if (url.isEmpty) return;
    await downloadToDevice(context, url);
  }

  @override
  void onPlay() {
    _videoController!.play();
  }

  @override
  void onPause() {
    _videoController!.pause();
  }

  @override
  void onReplay() {
    _videoController!.seekTo(Duration(seconds: widget.skipSeconds.toInt()));
    _videoController!.play();
  }

  @override
  void onSeek(Duration position) {
    _videoController!.seekTo(position);
  }

  @override
  Widget? buildVideoWidget(BuildContext context) {
    if (_isLoading) {
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
              aspectRatio: _videoController!.value.aspectRatio,
              child: VideoPlayer(_videoController!),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return buildPlayerControls(context);
  }
}
