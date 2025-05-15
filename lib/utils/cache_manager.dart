import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

/// Cache manager for music files with longer stalePeriod and more storage
class MusicCacheManager {
  static const key = 'music';
  static Future<String> get cacheDir async {
    final appDir = await getApplicationCacheDirectory();
    return '${appDir.path}/$key';
  }

  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 720),
      maxNrOfCacheObjects: 1000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileSystem: IOFileSystem(key),
      fileService: HttpFileService(),
    ),
  );

  /// Calculate the size of the audio cache
  static Future<int> calculateAudioCacheSize() async {
    try {
      final appDir = await getApplicationCacheDirectory();
      final musicCacheDir = Directory('${appDir.path}/$key');
      developer.log('Audio cache directory: ${musicCacheDir.path}');
      return await getDirectorySize(musicCacheDir.path);
    } catch (e) {
      developer.log('Error calculating audio cache size: $e');
      return 0;
    }
  }

  /// Get a cached audio file
  static Future<File> getCachedFile(String url) async {
    developer.log('Getting cached audio file: $url', name: 'CacheManager');
    try {
      // Generate a unique filename based on the URL
      final String fileName = generateFileName(url);

      // Determine the application cache directory
      final Directory appDir = await getApplicationCacheDirectory();

      // Create a subdirectory for music cache if it doesn't exist
      final Directory cacheDir = Directory('${appDir.path}/$key');
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }

      // File object pointing to the expected cache location
      return File('${cacheDir.path}/$fileName.mp3');
    } catch (_) {
      return File('');
    }
  }

  static Future<File> getFile(String url) async {
    developer.log('Caching audio file: $url', name: 'CacheManager');
    try {
      // Get the cached file
      final File file = await getCachedFile(url);
      if (await file.exists()) {
        return file;
      }

      // Download the file and save it to the cache
      final response = await http.get(Uri.parse(url));
      if (response.statusCode == 200) {
        await file.writeAsBytes(response.bodyBytes);
      } else {
        throw Exception('Failed to download file');
      }
      return file;
    } catch (e) {
      return File('');
    }
  }

  static Future<AudioSource> createCachedAudioSource(
    String url, {
    dynamic tag,
  }) async {
    try {
      File file = await getCachedFile(url);
      if (await file.exists()) {
        // If the file exists, return a ProgressiveAudioSource
        return ProgressiveAudioSource(Uri.parse(file.path), tag: tag);
      }
      // Create a caching audio source with the remote URL
      return LockCachingAudioSource(Uri.parse(url), tag: tag, cacheFile: file);
    } catch (e) {
      developer.log(
        'Error creating cached audio source: $e',
        name: 'CacheManager',
      );
      return ProgressiveAudioSource(Uri.parse(url), tag: tag);
    }
  }
}

/// Cache manager for images with shorter stalePeriod
class PJSKImageCacheManager {
  static const key = 'image';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 720),
      maxNrOfCacheObjects: 3000,
      repo: JsonCacheInfoRepository(databaseName: key),
      fileSystem: IOFileSystem(key),
      fileService: HttpFileService(),
    ),
  );

  /// Calculate the size of the image cache
  static Future<int> calculateImageCacheSize() async {
    try {
      final appDir = await getApplicationCacheDirectory();
      final imageCacheDir = Directory(
        '${appDir.path}/${PJSKImageCacheManager.key}',
      );
      return await getDirectorySize(imageCacheDir.path);
    } catch (e) {
      developer.log(
        'Error calculating image cache size: $e',
        name: 'CacheManager',
      );
      return 0;
    }
  }

  static Future<File> getFile(String url) async {
    try {
      return instance.getSingleFile(url);
    } catch (_) {
      return File('');
    }
  }
}

/// Clear all cached images
Future<void> clearImageCache() async {
  try {
    // Clear the cache manager instance
    await PJSKImageCacheManager.instance.emptyCache();
    final appDir = await getApplicationCacheDirectory();
    final imageCacheDir = Directory(
      '${appDir.path}/${PJSKImageCacheManager.key}',
    );
    await deleteDirectory(imageCacheDir);
  } catch (e) {
    developer.log('Error clearing image cache: $e', name: 'CacheManager');
  }
}

/// Clear all cached audio files
Future<void> clearAudioCache() async {
  try {
    await MusicCacheManager.instance.emptyCache();
    final appDir = await getApplicationCacheDirectory();
    final musicCacheDir = Directory('${appDir.path}/${MusicCacheManager.key}');
    await deleteDirectory(musicCacheDir);
  } catch (e) {
    developer.log('Error clearing audio cache: $e', name: 'CacheManager');
  }
}

/// helper
String generateFileName(String url) {
  final bytes = utf8.encode(url);
  final digest = md5.convert(bytes);
  return digest.toString();
}

/// Get the size of a directory
Future<int> getDirectorySize(String path) async {
  int totalSize = 0;
  final Directory directory = Directory(path);
  if (await directory.exists()) {
    await for (final FileSystemEntity entity in directory.list(
      recursive: true,
      followLinks: false,
    )) {
      if (entity is File) {
        final stat = await entity.stat();
        totalSize += stat.size;
      }
    }
  }
  return totalSize;
}

Future<void> deleteDirectory(Directory directory) async {
  if (await directory.exists()) {
    await directory.delete(recursive: true);
  }
}
