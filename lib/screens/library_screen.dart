import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media.dart';
import '../widgets/media_widgets.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});
  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController tabs = TabController(length: 5, vsync: this);
  @override
  void dispose() {
    tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (!state.signedIn) {
      return const SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline, size: 64),
                SizedBox(height: 16),
                Text(
                  'فهرست شخصی مخصوص کاربران عضو است.',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'از پروفایل خارج شوید و یک حساب بسازید.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'فهرست من',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => _newList(context),
                  icon: const Icon(Icons.playlist_add_rounded),
                  tooltip: 'فهرست جدید',
                ),
              ],
            ),
          ),
          TabBar(
            controller: tabs,
            isScrollable: true,
            tabs: const [
              Tab(text: 'در حال تماشا'),
              Tab(text: 'بعداً می‌بینم'),
              Tab(text: 'دیده‌شده'),
              Tab(text: 'علاقه‌مندی'),
              Tab(text: 'شخصی'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: tabs,
              children: [
                _StatusGrid(status: WatchStatus.watching),
                _StatusGrid(status: WatchStatus.plan),
                _StatusGrid(status: WatchStatus.completed),
                _StatusGrid(status: WatchStatus.favorite),
                const _CustomLists(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _newList(BuildContext context) {
    final controller = TextEditingController();
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('فهرست شخصی جدید'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'مثلاً بهترین فیلم‌های اکشن',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('انصراف'),
          ),
          FilledButton(
            onPressed: () {
              AppScope.of(context).createList(controller.text);
              Navigator.pop(dialogContext);
            },
            child: const Text('ساختن'),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }
}

class _StatusGrid extends StatelessWidget {
  const _StatusGrid({required this.status});
  final WatchStatus status;
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    final items = state.catalog
        .where((e) => state.statusOf(e.id) == status)
        .toList();
    if (items.isEmpty) {
      return const Center(
        child: Text(
          'هنوز اثری در این بخش نیست.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: .58,
        crossAxisSpacing: 14,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (_, i) =>
          MediaPosterCard(media: items[i], width: double.infinity),
    );
  }
}

class _CustomLists extends StatelessWidget {
  const _CustomLists();
  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    if (state.customLists.isEmpty) {
      return const Center(
        child: Text(
          'با دکمه بالا یک فهرست شخصی بسازید.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: state.customLists.entries.map((entry) {
        final items = state.catalog
            .where((e) => entry.value.contains(e.id))
            .toList();
        return Card(
          child: ExpansionTile(
            leading: const Icon(Icons.video_library_outlined),
            title: Text(
              entry.key,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            subtitle: Text('${items.length} اثر'),
            trailing: IconButton(
              onPressed: () => state.deleteList(entry.key),
              icon: const Icon(Icons.delete_outline),
            ),
            children: items.isEmpty
                ? [
                    const Padding(
                      padding: EdgeInsets.all(20),
                      child: Text(
                        'در صفحه هر اثر می‌توانید آن را به این فهرست اضافه کنید.',
                      ),
                    ),
                  ]
                : items
                      .map(
                        (e) => ListTile(
                          leading: SizedBox(
                            width: 42,
                            child: PosterImage(url: e.posterUrl),
                          ),
                          title: Text(e.title),
                          subtitle: Text(e.originalTitle),
                          trailing: IconButton(
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () =>
                                state.toggleInList(entry.key, e.id),
                          ),
                        ),
                      )
                      .toList(),
          ),
        );
      }).toList(),
    );
  }
}
