import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media.dart';
import '../screens/detail_screen.dart';

class PosterImage extends StatelessWidget {
  const PosterImage({super.key, required this.url, this.fit = BoxFit.cover});
  final String url;
  final BoxFit fit;
  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return const ColoredBox(
        color: Color(0xFF242230),
        child: Center(child: Icon(Icons.movie_outlined, size: 44)),
      );
    }
    return Image.network(
      url,
      fit: fit,
      frameBuilder: (context, child, frame, _) => frame == null
          ? const ColoredBox(
              color: Color(0xFF242230),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            )
          : child,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Color(0xFF242230),
        child: Center(child: Icon(Icons.broken_image_outlined)),
      ),
    );
  }
}

class MediaPosterCard extends StatelessWidget {
  const MediaPosterCard({super.key, required this.media, this.width = 142});
  final MediaItem media;
  final double width;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(media: media)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AspectRatio(
              aspectRatio: .68,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: PosterImage(url: media.posterUrl),
                  ),
                  Positioned(
                    top: 8,
                    left: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 4,
                        ),
                        child: Text(
                          '★ ${media.rating}',
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ),
                  if (state.statusOf(media.id) != WatchStatus.none)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      left: 0,
                      child: LinearProgressIndicator(
                        value: media.isSeries
                            ? state.progress(media)
                            : (state.statusOf(media.id) == WatchStatus.completed
                                  ? 1
                                  : .25),
                        minHeight: 5,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 9),
            Text(
              media.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(
              '${media.year} • ${media.type == MediaType.movie ? 'فیلم' : 'سریال'}',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 26, 20, 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        if (subtitle != null)
          Text(
            subtitle!,
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
      ],
    ),
  );
}

void showMemberRequired(BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('برای ثبت فعالیت، ابتدا وارد حساب کاربری شوید.'),
      ),
    );
