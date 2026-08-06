import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media.dart';
import '../models/user_account.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.signedIn) {
      return SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 45,
                child: Icon(Icons.person_outline, size: 48),
              ),
              const SizedBox(height: 16),
              const Text(
                'شما به‌عنوان مهمان وارد شده‌اید.',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: state.logout,
                child: const Text('ورود یا ثبت‌نام'),
              ),
            ],
          ),
        ),
      );
    }
    final user = state.account!;
    final watchedMovies = state.allMedia
        .where(
          (e) =>
              e.type == MediaType.movie &&
              state.statusOf(e.id) == WatchStatus.completed,
        )
        .length;
    final watchedSeries = state.allMedia
        .where((e) => e.type == MediaType.series && state.progress(e) > 0)
        .length;
    final watchedCount = state.watchedEpisodes.length;
    final minutes =
        state.allMedia.fold<int>(
          0,
          (sum, media) =>
              sum +
              media.episodes
                  .where((e) => state.isEpisodeWatched(media.id, e.id))
                  .fold(0, (value, e) => value + e.runtime),
        ) +
        state.allMedia
            .where(
              (e) =>
                  e.type == MediaType.movie &&
                  state.statusOf(e.id) == WatchStatus.completed,
            )
            .fold(0, (value, e) => value + e.runtime);
    final average = state.ratings.isEmpty
        ? 0.0
        : state.ratings.values.reduce((a, b) => a + b) / state.ratings.length;
    final genreCounts = <String, int>{};
    for (final media in state.allMedia.where(
      (e) => state.statusOf(e.id) != WatchStatus.none,
    )) {
      for (final genre in media.genres) {
        genreCounts[genre] = (genreCounts[genre] ?? 0) + 1;
      }
    }
    final favoriteGenre = genreCounts.entries.isEmpty
        ? 'ثبت نشده'
        : (genreCounts.entries.toList()
                ..sort((a, b) => b.value.compareTo(a.value)))
              .first
              .key;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 38,
                backgroundColor: const Color(0xFF3B256B),
                child: Text(
                  user.name.substring(0, 1),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: Colors.grey),
                    ),
                    if (user.bio.isNotEmpty) Text(user.bio, maxLines: 2),
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _edit(context),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'آمار تماشا',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 2,
            childAspectRatio: 1.45,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
            children: [
              _Stat(
                icon: Icons.movie_outlined,
                value: '$watchedMovies',
                label: 'فیلم دیده‌شده',
              ),
              _Stat(
                icon: Icons.live_tv_outlined,
                value: '$watchedSeries',
                label: 'سریال دنبال‌شده',
              ),
              _Stat(
                icon: Icons.check_circle_outline,
                value: '$watchedCount',
                label: 'قسمت دیده‌شده',
              ),
              _Stat(
                icon: Icons.schedule_outlined,
                value: '${(minutes / 60).toStringAsFixed(1)} ساعت',
                label: 'زمان تقریبی تماشا',
              ),
              _Stat(
                icon: Icons.category_outlined,
                value: favoriteGenre,
                label: 'ژانر محبوب',
              ),
              _Stat(
                icon: Icons.star_outline,
                value: average.toStringAsFixed(1),
                label: 'میانگین امتیاز',
              ),
            ],
          ),
          const SizedBox(height: 18),
          Card(
            child: ListTile(
              leading: const Icon(Icons.mail_outline),
              title: const Text('ایمیل'),
              subtitle: Text(user.email, textDirection: TextDirection.ltr),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('ذخیره‌سازی محلی'),
              subtitle: const Text(
                'فعالیت‌ها و نشست تا ۳۰ روز روی دستگاه نگهداری می‌شوند.',
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: state.logout,
            icon: const Icon(Icons.logout),
            label: const Text('خروج امن از حساب'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              padding: const EdgeInsets.all(16),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(BuildContext context) async {
    final state = AppScope.of(context);
    final draft = await showModalBottomSheet<_ProfileDraft>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ProfileEditor(account: state.account!),
    );
    if (draft != null && context.mounted) {
      state.updateProfile(
        name: draft.name,
        username: draft.username,
        bio: draft.bio,
      );
    }
  }
}

class _ProfileDraft {
  const _ProfileDraft({
    required this.name,
    required this.username,
    required this.bio,
  });
  final String name;
  final String username;
  final String bio;
}

class _ProfileEditor extends StatefulWidget {
  const _ProfileEditor({required this.account});
  final UserAccount account;

  @override
  State<_ProfileEditor> createState() => _ProfileEditorState();
}

class _ProfileEditorState extends State<_ProfileEditor> {
  late final name = TextEditingController(text: widget.account.name);
  late final username = TextEditingController(text: widget.account.username);
  late final bio = TextEditingController(text: widget.account.bio);

  @override
  void dispose() {
    name.dispose();
    username.dispose();
    bio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      24,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('ویرایش پروفایل', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        TextField(
          controller: name,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'نام و نام خانوادگی'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: username,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'نام کاربری'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: bio,
          maxLines: 3,
          keyboardType: TextInputType.multiline,
          textDirection: TextDirection.rtl,
          textAlign: TextAlign.right,
          decoration: const InputDecoration(labelText: 'درباره من'),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => Navigator.pop(
            context,
            _ProfileDraft(
              name: name.text.trim(),
              username: username.text.trim(),
              bio: bio.text.trim(),
            ),
          ),
          child: const Text('ذخیره'),
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});
  final IconData icon;
  final String value;
  final String label;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: const Color(0xFFB794F6)),
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
          ),
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 11)),
        ],
      ),
    ),
  );
}
