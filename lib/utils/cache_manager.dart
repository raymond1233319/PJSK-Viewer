import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/io_client.dart';

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
      stalePeriod: const Duration(days: 60),
      maxNrOfCacheObjects: 500,
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
      developer.log(
        'Audio cache directory: ${musicCacheDir.path}',
        name: 'CacheManager',
      );
      return await getDirectorySize(musicCacheDir.path);
    } catch (e) {
      developer.log(
        'Error calculating audio cache size: $e',
        name: 'CacheManager',
      );
      return 0;
    }
  }
}

/// Cache manager for images with shorter stalePeriod
class PJSKImageCacheManager {
  static const key = 'image';
  static CacheManager instance = CacheManager(
    Config(
      key,
      stalePeriod: const Duration(days: 30),
      maxNrOfCacheObjects: 2000,
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
}

/// Clear all cached images
Future<void> clearImageCache() async {
  await PJSKImageCacheManager.instance.emptyCache();
}

/// Get a cached audio file, downloading if necessary
Future<File> getCachedAudioFile(String url) async {
  developer.log('Getting cached audio file: $url', name: 'CacheManager');
  try {
    // Generate a unique filename based on the URL
    final String fileName = generateFileName(url);

    // Determine the application cache directory
    final Directory appDir = await getApplicationCacheDirectory();

    // Create a subdirectory for music cache if it doesn't exist
    final Directory cacheDir = Directory(
      '${appDir.path}/${MusicCacheManager.key}',
    );
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }

    // File object pointing to the expected cache location
    final File file = File('${cacheDir.path}/$fileName.mp3');
    developer.log('Cache file path: ${file.path}', name: 'CacheManager');

    // If the file is already downloaded, return it immediately
    if (await file.exists()) {
      return file;
    }
    final IOClient ioClient = IOClient();
    final http.Response httpResponse = await ioClient.get(Uri.parse(url));
    if (httpResponse.statusCode != 200) {
      throw HttpException(
        'Failed to download audio file: HTTP ${httpResponse.statusCode}',
      );
    }
    // Write response bytes directly to cache file
    await file.writeAsBytes(httpResponse.bodyBytes, flush: true);
    ioClient.close();

    return file;
  } catch (e) {
    developer.log('Error getting cached audio file: $e', name: 'CacheManager');
    rethrow;
  }
}

/// helper
String generateFileName(String url) {
  final bytes = utf8.encode(url);
  final digest = md5.convert(bytes);
  return digest.toString();
}

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

Future<AudioSource> createCachedAudioSource(String url, {dynamic tag}) async {
  developer.log('Creating cached audio source: $url', name: 'CacheManager');
  try {
    // Create a caching audio source with the remote URL
    return LockCachingAudioSource(
      Uri.parse(url),
      tag: tag,
      cacheFile: await getCachedAudioFile(url),
    );
  } catch (e) {
    developer.log(
      'Error creating cached audio source: $e',
      name: 'CacheManager',
    );
    return ProgressiveAudioSource(Uri.parse(url), tag: tag);
  }
}

/// Check if audio exists in cache and is valid
Future<bool> isAudioCached(String url) async {
  final fileInfo = await MusicCacheManager.instance.getFileFromCache(url);
  return fileInfo != null && !fileInfo.validTill.isBefore(DateTime.now());
}

/// Clear all cached audio files
Future<void> clearAudioCache() async {
  await MusicCacheManager.instance.emptyCache();
}
