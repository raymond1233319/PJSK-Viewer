import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:pjsk_viewer/utils/audio_service.dart';
import 'package:share_plus/share_plus.dart';

class FullScreenImagePage extends StatelessWidget {
  final String imageUrl;
  final String tag;

  const FullScreenImagePage({
    super.key,
    required this.imageUrl,
    required this.tag,
  });
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: Colors.black),
        // image
        Hero(
          tag: tag,
          child: PhotoView(
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            loadingBuilder:
                (context, event) =>
                    const Center(child: CircularProgressIndicator()),
            imageProvider: CachedNetworkImageProvider(imageUrl),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.contained * 2,
          ),
        ),
        // back & download buttons in a SafeArea
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // back
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                // download
                IconButton(
                  icon: const Icon(Icons.download, color: Colors.white),
                  onPressed: () async {
                    final file = await downloadToDevice(context, imageUrl);
                    if (file != null) {
                      final params = ShareParams(files: [XFile(file.path)]);
                      await SharePlus.instance.share(params);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Shows [imageUrl] or a placeholder. On tap opens full‑screen via [FullScreenImagePage].
Widget buildHeroImageViewer(BuildContext context, String? imageUrl) {
  if (imageUrl == null || imageUrl.isEmpty) {
    return const SizedBox(
      height: 300,
      child: Center(
        child: Icon(Icons.image_not_supported, size: 50, color: Colors.grey),
      ),
    );
  }

  return GestureDetector(
    onTap: () {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder:
              (_) => FullScreenImagePage(imageUrl: imageUrl, tag: imageUrl),
        ),
      );
    },
    child: Hero(
      tag: imageUrl,
      child: CachedNetworkImage(
        imageUrl: imageUrl,
        placeholder:
            (_, __) => const SizedBox(
              height: 300,
              child: Center(child: CircularProgressIndicator()),
            ),
        errorWidget:
            (_, __, ___) => const SizedBox(
              height: 300,
              child: Center(
                child: Icon(
                  Icons.image_not_supported,
                  size: 50,
                  color: Colors.grey,
                ),
              ),
            ),
        fit: BoxFit.contain,
      ),
    ),
  );
}
