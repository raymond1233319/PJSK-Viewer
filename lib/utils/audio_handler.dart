import 'dart:developer' as developer;

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';
import 'package:rxdart/rxdart.dart';

// Helper class for position data
class PositionData {
  final Duration position;
  final Duration bufferedPosition;
  final Duration duration;
  PositionData(this.position, this.bufferedPosition, this.duration);
}

class PJSKAudioHandler extends BaseAudioHandler with SeekHandler {
  static final AudioPlayer _player = AudioPlayer();
  String? _currentTrackTitle; // To store track title for notification
  String? _currentTrackArtist; // To store track artist for notification
  Uri? _currentArtUri; // To store album art URI

  PJSKAudioHandler() {
    // Listen to playback events from the player and translate them
    // into AudioService events.
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Listen for when the player finishes a track
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) {
        // Optionally, you can stop the service or prepare for the next track.
        // For now, it will just show as completed in the notification.
        // If you want 'replay' behavior, you might call seek(Duration.zero) and pause().
      }
    });
  }

  // Helper to load audio and set MediaItem
  Future<void> loadAudioSource({
    required String url,
    String? title,
    String? artist,
    String? artUrl,
    double? skipSeconds,
  }) async {
    if (isCurrentSource(url)) {
      return;
    }

    _currentTrackTitle = title;
    _currentTrackArtist = artist;
    _currentArtUri = artUrl != null ? Uri.parse(artUrl) : null;
    try {
      MediaItem mediaItemToUse = MediaItem(
        id: url,
        title: _currentTrackTitle!,
        artist: _currentTrackArtist,
        artUri: _currentArtUri,
        displayTitle: _currentTrackTitle,
        displaySubtitle: _currentTrackArtist,
      );
      AudioSource source = AudioSource.uri(Uri.parse(url), tag: mediaItemToUse);

      await _player.setAudioSource(source);
      await _player.seek(Duration(seconds: skipSeconds?.toInt() ?? 0));

      // Notify the system about the new media item
      mediaItem.add(mediaItemToUse.copyWith(duration: _player.duration));
    } catch (_) {}
  }

  /// Check if the current audio source matches the given URL
  static bool isCurrentSource(String url) {
    // Check if we have an active source
    if (_player.audioSource == null) {
      return false;
    }

    // If the current source is a ClippingAudioSource, we need to check its child
    if (_player.audioSource is ClippingAudioSource) {
      final clippingSource = _player.audioSource as ClippingAudioSource;
      final uriSource = clippingSource.child;
      return uriSource.uri.toString() == url;
    }

    // Direct check for UriAudioSource
    if (_player.audioSource is UriAudioSource) {
      final uriSource = _player.audioSource as UriAudioSource;
      return uriSource.uri.toString() == url;
    }

    return false;
  }

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  /// Transform a just_audio event into an audio_service state.
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: const [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState:
          const {
            ProcessingState.idle: AudioProcessingState.idle,
            ProcessingState.loading: AudioProcessingState.loading,
            ProcessingState.buffering: AudioProcessingState.buffering,
            ProcessingState.ready: AudioProcessingState.ready,
            ProcessingState.completed: AudioProcessingState.completed,
          }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }

  Stream<PositionData> get customPositionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (position, buffered, duration) =>
            PositionData(position, buffered, duration ?? Duration.zero),
      ).asBroadcastStream();

  Stream<double> get volumeStream => _player.volumeStream;
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
}
