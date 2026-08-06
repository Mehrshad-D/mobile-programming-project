import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media.dart';
import '../widgets/media_widgets.dart';
import 'detail_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final featured = state.catalog.firstWhere((e) => e.featured);
    final movies = state.catalog
        .where((e) => e.type == MediaType.movie)
        .toList();
    final series = state.catalog
        .where((e) => e.type == MediaType.series)
        .toList();
    final continueWatching = state.catalog
        .where((e) => state.statusOf(e.id) == WatchStatus.watching)
        .toList();
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          title: const Text(
            'فیلم‌یاب',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          actions: [
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 14),
              child: CircleAvatar(
                backgroundColor: const Color(0xFF2A1E46),
                child: Text(
                  state.account == null || state.account!.name.isEmpty
                      ? 'م'
                      : state.account!.name.substring(0, 1),
                ),
              ),
            ),
          ],
        ),
        SliverToBoxAdapter(child: _Hero(media: featured)),
        if (continueWatching.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: SectionTitle('ادامه تماشا', subtitle: 'فعالیت‌های شما'),
          ),
          SliverToBoxAdapter(child: _Horizontal(items: continueWatching)),
        ],
        const SliverToBoxAdapter(
          child: SectionTitle(
            'فیلم‌های محبوب',
            subtitle: 'بر پایه امتیاز IMDb',
          ),
        ),
        SliverToBoxAdapter(child: _Horizontal(items: movies)),
        const SliverToBoxAdapter(child: SectionTitle('سریال‌های محبوب')),
        SliverToBoxAdapter(child: _Horizontal(items: series)),
        SliverToBoxAdapter(
          child: SectionTitle(
            'آثار جدید',
            subtitle: '${state.catalog.length} عنوان',
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          sliver: SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: .58,
              crossAxisSpacing: 14,
              mainAxisSpacing: 16,
            ),
            itemCount: state.catalog.length,
            itemBuilder: (_, i) => MediaPosterCard(
              media: state.catalog[i],
              width: double.infinity,
            ),
          ),
        ),
      ],
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.media});
  final MediaItem media;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(26),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => DetailScreen(media: media)),
      ),
      child: SizedBox(
        height: 260,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(26),
          child: Stack(
            fit: StackFit.expand,
            children: [
              PosterImage(url: media.backdropUrl),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Color(0xF20B0B12)],
                  ),
                ),
              ),
              Positioned(
                right: 20,
                left: 20,
                bottom: 18,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: const Color(0xFF7C3AED),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 9,
                          vertical: 4,
                        ),
                        child: Text(
                          'پیشنهاد ویژه',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      media.title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900),
                    ),
                    Text(
                      '${media.originalTitle}  •  ${media.year}  •  ★ ${media.rating}',
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.right,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Horizontal extends StatelessWidget {
  const _Horizontal({required this.items});
  final List<MediaItem> items;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 270,
    child: ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(width: 13),
      itemBuilder: (_, i) => MediaPosterCard(media: items[i]),
    ),
  );
}
