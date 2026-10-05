import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/repository.dart';
import 'theme.dart';

void openPoster(
  BuildContext context, {
  required String imagePath,
  required String postUrl,
  required String cinemaName,
}) {
  Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, _, _) => PosterPage(imageUrl: assetUrl(imagePath), postUrl: postUrl, cinemaName: cinemaName),
      transitionsBuilder: (_, animation, _, child) => FadeTransition(opacity: animation, child: child),
    ),
  );
}

/// The cinema's original poster, zoomable. The ground truth behind every extracted showtime.
class PosterPage extends StatelessWidget {
  const PosterPage({super.key, required this.imageUrl, required this.postUrl, required this.cinemaName});

  final String imageUrl;
  final String postUrl;
  final String cinemaName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(cinemaName, style: Theme.of(context).textTheme.titleMedium),
        actions: [
          TextButton.icon(
            onPressed: () => launchUrl(Uri.parse(postUrl), mode: LaunchMode.externalApplication),
            icon: const Icon(Icons.send_rounded, size: 18),
            label: const Text('Open post'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: InteractiveViewer(
        maxScale: 5,
        child: Center(
          child: CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, _) => const CircularProgressIndicator(color: AppColors.gold),
            errorWidget: (_, _, _) => const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.broken_image_outlined, size: 48, color: AppColors.textMuted),
                SizedBox(height: 8),
                Text('Couldn\'t load the poster', style: TextStyle(color: AppColors.textMuted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
