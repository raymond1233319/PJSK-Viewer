import 'dart:async';
import 'dart:developer' as developer;
import 'package:audio_service/audio_service.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pjsk_viewer/utils/cache_manager.dart';
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
  int _currentTrackIndex = 0; // To store current track index
  ValueNotifier<String> currentTrackTitleNotifier = ValueNotifier('');
  ValueNotifier<String> currentTrackArtistNotifier = ValueNotifier('');
  ValueNotifier<int> currentTrackIndexNotifier = ValueNotifier(-1);

  PJSKAudioHandler() {
    // Listen to playback events from the player and translate them
    // into AudioService events.
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Listen for when the player finishes a track
    _player.processingStateStream.listen((state) {
      if (state == ProcessingState.completed) skipToNext();
    });
  }

  // Helper to load audio and set MediaItem
  Future<void> _loadAudioSource({required MediaItem myMediaItem}) async {
    final url = myMediaItem.id;
    if (await isCurrentSource(url)) {
      return;
    }
    try {
      AudioSource source =
          await MusicCacheManager.createCachedAudioSource(
            url,
            tag: myMediaItem,
          ) ??
          AudioSource.uri(Uri.parse(url), tag: myMediaItem);

      await _player.setAudioSource(
        source,
        initialPosition: Duration(
          seconds: myMediaItem.extras?['skipSeconds']?.toInt() ?? 0,
        ),
      );
      currentTrackArtistNotifier.value = myMediaItem.artist ?? '';
      currentTrackTitleNotifier.value = myMediaItem.title;

      // Notify the system about the new media item
      mediaItem.add(myMediaItem.copyWith(duration: _player.duration));
    } catch (e) {
      developer.log('Error loading audio source: $e');
    }
  }

  // Clear the audio queue
  Future<void> clearQueue() async {
    while (queue.value.isNotEmpty) {
      queue.value.removeLast();
    }
  }

  /// Update the entire queue with a new list of items
  @override
  Future<void> updateQueue(List<MediaItem> newQueue) async {
    clearQueue();
    for (var item in newQueue) {
      queue.value.add(item);
    }
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    final currentQueue = queue.value;

    if (index < 0 || index >= currentQueue.length) {
      return;
    }

    // Get the MediaItem at the specified index
    final myMediaItem = currentQueue[index];
    _currentTrackIndex = index;
    currentTrackIndexNotifier.value = index;
    // Load this MediaItem
    await _loadAudioSource(myMediaItem: myMediaItem);
    prefetchUpcomingTracks();
  }

  /// Prefetch upcoming tracks in the queue
  Future<void> prefetchUpcomingTracks() async {
    if (queue.value.isEmpty) {
      return;
    }

    final currentQueue = queue.value;

    // Start prefetching from the next track after current
    for (int i = 1; i <= 5; i++) {
      final nextIndex = (_currentTrackIndex + i) % currentQueue.length;
      if (nextIndex == _currentTrackIndex) continue;

      final nextItem = currentQueue[nextIndex];
      final url = nextItem.id;

      try {
        // Download the audio file
        await MusicCacheManager.getFile(url);
      } catch (e) {
        developer.log('Error prefetching track: $url - $e');
      }
      // Start prefetching in the background
      developer.log('Prefetching track: $url', name: 'PJSKAudioHandler');
    }
  }

  /// Check if the current audio source matches the given URL
  Future<bool> isCurrentSource(String url) async {
    // Check if we have an active source
    if (_player.audioSource == null) {
      return false;
    }
    return mediaItem.value?.id == url;
  }

  bool get isPlaying => _player.playing;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() async {
    final currentQueue = queue.value;

    if (_currentTrackIndex + 1 < currentQueue.length) {
      _currentTrackIndex++;
      currentTrackIndexNotifier.value = _currentTrackIndex;
      await skipToQueueItem(_currentTrackIndex);
    } else {
      await skipToQueueItem(0);
    }
    // prefetch upcoming tracks
    prefetchUpcomingTracks();
  }

  @override
  Future<void> skipToPrevious() async {
    final currentQueue = queue.value;
    developer.log('Current Queue: $currentQueue');
    if (_currentTrackIndex - 1 >= 0) {
      _currentTrackIndex--;
      currentTrackIndexNotifier.value = _currentTrackIndex;
      await skipToQueueItem(_currentTrackIndex);
    } else {
      await skipToQueueItem(currentQueue.length - 1);
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    await super.stop();
  }

  int get currentTrackIndex => _currentTrackIndex;

  MediaItem? get currentMediaItem => mediaItem.value;

  // Get whether the current media item is in player mode
  bool get isPlayerMode => currentMediaItem?.extras?['playerMode'] ?? false;

  /// Transform a just_audio event into an audio_service state.
  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: const [
        MediaControl.skipToPrevious,
        MediaControl.play,
        MediaControl.pause,
        MediaControl.skipToNext,
      ],
      systemActions: {
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

  Stream<PositionData> get positionDataStream =>
      Rx.combineLatest3<Duration, Duration, Duration?, PositionData>(
        _player.positionStream,
        _player.bufferedPositionStream,
        _player.durationStream,
        (position, buffered, duration) =>
            PositionData(position, buffered, duration ?? Duration.zero),
      ).asBroadcastStream();

  Stream<PlayerState> get playerStateStream =>
      Rx.combineLatest3<bool, ProcessingState, Duration, PlayerState>(
        _player.playingStream,
        _player.processingStateStream,
        _player.positionStream,
        (playing, processingState, position) {
          return PlayerState(playing, processingState);
        },
      ).asBroadcastStream();

  Stream<double> get volumeStream => _player.volumeStream;

  Future<void> setVolume(double volume) => _player.setVolume(volume);

  Duration get currentPosition => _player.position;

  Stream<ProcessingState> get processingStateStream =>
      _player.processingStateStream;
}
