import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media.dart';
import '../widgets/media_widgets.dart';

class DetailScreen extends StatefulWidget {
  const DetailScreen({super.key, required this.media});
  final MediaItem media;

  @override
  State<DetailScreen> createState() => _DetailScreenState();
}

class _DetailScreenState extends State<DetailScreen> {
  late MediaItem media = widget.media;
  bool _requestedEpisodes = false;
  bool _loadingEpisodes = false;
  String? _episodeError;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (media.isSeries && !_requestedEpisodes) {
      _loadEpisodes();
    }
  }

  Future<void> _loadEpisodes() async {
    _requestedEpisodes = true;
    _loadingEpisodes = true;
    _episodeError = null;
    try {
      final loaded = await AppScope.of(
        context,
      ).catalogue.findById(media.id, includeEpisodes: true);
      if (!mounted) return;
      if (loaded != null) AppScope.of(context).cacheMedia(loaded);
      setState(() {
        if (loaded != null) media = loaded;
        _loadingEpisodes = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingEpisodes = false;
        _episodeError = error.toString();
      });
    }
  }

  void _retryEpisodes() {
    setState(() => _requestedEpisodes = false);
    _loadEpisodes();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 315,
            pinned: true,
            actions: [
              IconButton(
                onPressed: () {
                  if (!state.signedIn) return showMemberRequired(context);
                  state.toggleFavorite(media.id, media: media);
                },
                icon: Icon(
                  state.isFavorite(media.id)
                      ? Icons.favorite
                      : Icons.favorite_border,
                  color: state.isFavorite(media.id) ? Colors.pinkAccent : null,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  PosterImage(
                    url: media.backdropUrl.isNotEmpty
                        ? media.backdropUrl
                        : media.posterUrl,
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Color(0xFF0B0B12)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      SizedBox(
                        width: 105,
                        child: AspectRatio(
                          aspectRatio: .68,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: PosterImage(url: media.posterUrl),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              media.title,
                              style: Theme.of(context).textTheme.headlineSmall
                                  ?.copyWith(fontWeight: FontWeight.w900),
                            ),
                            Text(
                              media.originalTitle,
                              textDirection: TextDirection.ltr,
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 7,
                              runSpacing: 6,
                              children: [
                                Chip(
                                  avatar: const Icon(
                                    Icons.star,
                                    size: 16,
                                    color: Colors.amber,
                                  ),
                                  label: Text('${media.rating} IMDb'),
                                ),
                                Chip(
                                  label: Text(
                                    '${media.year}${media.endYear != null ? '–${media.endYear}' : ''}',
                                  ),
                                ),
                                Chip(
                                  label: Text(
                                    media.isSeries
                                        ? _loadingEpisodes
                                              ? 'دریافت فصل‌ها...'
                                              : '${media.seasonCount} فصل'
                                        : '${media.runtime} دقیقه',
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 7,
                    children: media.genres
                        .map((g) => Chip(label: Text(g)))
                        .toList(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    media.overview,
                    style: const TextStyle(height: 1.8, fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  _InfoRow(
                    icon: Icons.public,
                    label: 'کشور سازنده',
                    value: media.country,
                  ),
                  _InfoRow(
                    icon: Icons.movie_creation_outlined,
                    label: 'سازنده / کارگردان',
                    value: media.director,
                  ),
                  _InfoRow(
                    icon: Icons.groups_outlined,
                    label: 'بازیگران',
                    value: media.cast.join('، '),
                  ),
                  if (media.isSeries)
                    _InfoRow(
                      icon: Icons.podcasts_outlined,
                      label: 'وضعیت پخش',
                      value: media.status,
                    ),
                  const SizedBox(height: 20),
                  _Actions(media: media),
                  if (media.isSeries) ...[
                    const SizedBox(height: 8),
                    _Progress(media: media),
                    const SizedBox(height: 10),
                    if (_loadingEpisodes)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('در حال دریافت فصل‌ها و قسمت‌ها...'),
                            ],
                          ),
                        ),
                      )
                    else if (_episodeError != null)
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18),
                          child: Column(
                            children: [
                              const Icon(Icons.cloud_off, size: 38),
                              const SizedBox(height: 8),
                              Text(_episodeError!, textAlign: TextAlign.center),
                              const SizedBox(height: 10),
                              FilledButton.tonalIcon(
                                onPressed: _retryEpisodes,
                                icon: const Icon(Icons.refresh),
                                label: const Text('تلاش دوباره'),
                              ),
                            ],
                          ),
                        ),
                      )
                    else if (media.episodes.isEmpty)
                      const Card(
                        child: Padding(
                          padding: EdgeInsets.all(20),
                          child: Text(
                            'اطلاعات قسمت‌های این سریال در OMDb ثبت نشده است.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    else
                      _Episodes(media: media),
                  ],
                  const SizedBox(height: 25),
                  _Rating(media: media),
                  const SizedBox(height: 22),
                  _Reviews(media: media),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: const Color(0xFFB794F6)),
        const SizedBox(width: 10),
        SizedBox(
          width: 105,
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Text(value)),
      ],
    ),
  );
}

class _Actions extends StatelessWidget {
  const _Actions({required this.media});
  final MediaItem media;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: () => _statusSheet(context),
            icon: const Icon(Icons.add_to_queue_outlined),
            label: Text(state.statusOf(media.id).label),
            style: FilledButton.styleFrom(padding: const EdgeInsets.all(15)),
          ),
        ),
        const SizedBox(width: 9),
        IconButton.filledTonal(
          onPressed: () => _listsSheet(context),
          icon: const Icon(Icons.playlist_add),
        ),
        const SizedBox(width: 7),
        IconButton.filledTonal(
          onPressed: () {
            if (!state.signedIn) return showMemberRequired(context);
            state.toggleFavorite(media.id, media: media);
          },
          icon: Icon(
            state.isFavorite(media.id) ? Icons.favorite : Icons.favorite_border,
          ),
        ),
      ],
    );
  }

  Future<void> _statusSheet(BuildContext context) async {
    final state = AppScope.of(context);
    if (!state.signedIn) return showMemberRequired(context);
    final status = await showModalBottomSheet<WatchStatus>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'وضعیت تماشا',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 10),
              RadioGroup<WatchStatus>(
                groupValue: state.statusOf(media.id),
                onChanged: (value) {
                  if (value != null) Navigator.pop(sheetContext, value);
                },
                child: Column(
                  children: WatchStatus.values
                      .map(
                        (status) => RadioListTile<WatchStatus>(
                          value: status,
                          title: Text(status.label),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (status != null && context.mounted) {
      state.setStatus(media.id, status, media: media);
    }
  }

  Future<void> _listsSheet(BuildContext context) async {
    final state = AppScope.of(context);
    if (!state.signedIn) return showMemberRequired(context);
    final selected = await showModalBottomSheet<Set<String>>(
      context: context,
      builder: (_) => _ListMembershipSheet(
        listNames: state.customLists.keys.toList(),
        initiallySelected: state.customLists.entries
            .where((entry) => entry.value.contains(media.id))
            .map((entry) => entry.key)
            .toSet(),
      ),
    );
    if (selected != null && context.mounted) {
      state.setListMembership(media.id, selected, media: media);
    }
  }
}

class _ListMembershipSheet extends StatefulWidget {
  const _ListMembershipSheet({
    required this.listNames,
    required this.initiallySelected,
  });
  final List<String> listNames;
  final Set<String> initiallySelected;

  @override
  State<_ListMembershipSheet> createState() => _ListMembershipSheetState();
}

class _ListMembershipSheetState extends State<_ListMembershipSheet> {
  late final Set<String> selected = {...widget.initiallySelected};

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'افزودن به فهرست شخصی',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
          ),
          if (widget.listNames.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 20),
              child: Text('ابتدا در بخش «فهرست من» یک فهرست شخصی بسازید.'),
            ),
          ...widget.listNames.map(
            (name) => CheckboxListTile(
              value: selected.contains(name),
              title: Text(name),
              onChanged: (checked) => setState(() {
                checked == true ? selected.add(name) : selected.remove(name);
              }),
            ),
          ),
          if (widget.listNames.isNotEmpty)
            FilledButton(
              onPressed: () => Navigator.pop(context, selected),
              child: const Text('ذخیره تغییرات'),
            ),
        ],
      ),
    ),
  );
}

class _Progress extends StatelessWidget {
  const _Progress({required this.media});
  final MediaItem media;
  @override
  Widget build(BuildContext context) {
    final value = AppScope.of(context).progress(media);
    final watched = (value * media.episodes.length).round();
    final color = value == 0
        ? Colors.grey
        : value == 1 && media.status == 'در حال پخش'
        ? Colors.green
        : value == 1
        ? Colors.purple
        : Colors.amber;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'پیشرفت تماشا',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                Text('$watched از ${media.episodes.length} قسمت'),
              ],
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: value,
              minHeight: 9,
              borderRadius: BorderRadius.circular(6),
              color: color,
            ),
            const SizedBox(height: 7),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${(value * 100).round()}٪',
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Episodes extends StatefulWidget {
  const _Episodes({required this.media});
  final MediaItem media;
  @override
  State<_Episodes> createState() => _EpisodesState();
}

class _EpisodesState extends State<_Episodes> {
  int season = 1;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final episodes = widget.media.episodes
        .where((e) => e.season == season)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle('فصل‌ها و قسمت‌ها'),
        Wrap(
          spacing: 8,
          children: [
            for (var i = 1; i <= widget.media.seasonCount; i++)
              ChoiceChip(
                label: Text('فصل $i'),
                selected: season == i,
                onSelected: (_) => setState(() => season = i),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ...episodes.map(
          (e) => Card(
            child: CheckboxListTile(
              value: state.isEpisodeWatched(widget.media.id, e.id),
              onChanged: (_) {
                if (!state.signedIn) return showMemberRequired(context);
                state.toggleEpisode(widget.media.id, e.id, media: widget.media);
              },
              title: Text(
                '${e.number}. ${e.title}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text(
                '${e.runtime} دقیقه • ${e.overview}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              secondary: CircleAvatar(child: Text('${e.number}')),
            ),
          ),
        ),
      ],
    );
  }
}

class _Rating extends StatelessWidget {
  const _Rating({required this.media});
  final MediaItem media;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final selected = state.ratings[media.id] ?? 0;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Text(
              'امتیاز شما',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    onPressed: () {
                      if (!state.signedIn) return showMemberRequired(context);
                      state.rate(media.id, i, media: media);
                    },
                    icon: Icon(
                      i <= selected
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: Colors.amber,
                      size: 34,
                    ),
                  ),
              ],
            ),
            Text(selected == 0 ? 'هنوز امتیاز نداده‌اید' : '$selected از ۵'),
          ],
        ),
      ),
    );
  }
}

class _Reviews extends StatelessWidget {
  const _Reviews({required this.media});
  final MediaItem media;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final reviews = state.reviews[media.id] ?? const <Review>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'نظرها (${reviews.length})',
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            FilledButton.tonalIcon(
              onPressed: () => _newReview(context),
              icon: const Icon(Icons.add_comment_outlined),
              label: const Text('ثبت نظر'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (reviews.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(22),
              child: Text(
                'اولین نفری باشید که نظر می‌دهد.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
            ),
          ),
        ...reviews.map((review) => _ReviewCard(review: review)),
      ],
    );
  }

  Future<void> _newReview(BuildContext context) async {
    final state = AppScope.of(context);
    if (!state.signedIn) return showMemberRequired(context);
    final draft = await showModalBottomSheet<_ReviewDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ReviewComposer(),
    );
    if (draft != null && context.mounted) {
      state.addReview(media.id, draft.text, draft.spoiler, media: media);
    }
  }
}

class _ReviewDraft {
  const _ReviewDraft(this.text, this.spoiler);
  final String text;
  final bool spoiler;
}

class _ReviewComposer extends StatefulWidget {
  const _ReviewComposer();

  @override
  State<_ReviewComposer> createState() => _ReviewComposerState();
}

class _ReviewComposerState extends State<_ReviewComposer> {
  final controller = TextEditingController();
  bool spoiler = false;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'نظر شما',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          keyboardType: TextInputType.multiline,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(hintText: 'نظر خود را بنویسید...'),
        ),
        SwitchListTile(
          value: spoiler,
          title: const Text('این نظر داستان را لو می‌دهد'),
          onChanged: (value) => setState(() => spoiler = value),
        ),
        FilledButton(
          onPressed: () {
            final text = controller.text.trim();
            if (text.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('متن نظر نمی‌تواند خالی باشد.')),
              );
              return;
            }
            Navigator.pop(context, _ReviewDraft(text, spoiler));
          },
          child: const Text('انتشار نظر'),
        ),
      ],
    ),
  );
}

class _ReviewCard extends StatefulWidget {
  const _ReviewCard({required this.review});
  final Review review;
  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  bool revealed = false;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              CircleAvatar(child: Text(widget.review.user.substring(0, 1))),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '@${widget.review.user}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                widget.review.date,
                style: const TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.review.spoiler && !revealed)
            OutlinedButton.icon(
              onPressed: () => setState(() => revealed = true),
              icon: const Icon(Icons.visibility_off_outlined),
              label: const Text('این نظر اسپویل دارد؛ نمایش بده'),
            )
          else
            Text(widget.review.text, style: const TextStyle(height: 1.6)),
        ],
      ),
    ),
  );
}
