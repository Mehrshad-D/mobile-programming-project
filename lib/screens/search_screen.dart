import 'dart:async';

import 'package:flutter/material.dart';

import '../main.dart';
import '../models/media.dart';
import '../widgets/media_widgets.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});
  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final controller = TextEditingController();
  Timer? debounce;
  MediaType? filter;
  @override
  void dispose() {
    debounce?.cancel();
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    var results = controller.text.trim().isEmpty
        ? state.catalog
        : state.searchResults;
    if (filter != null) {
      results = results.where((e) => e.type == filter).toList();
    }
    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'جست‌وجو',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w900),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: controller,
              autofocus: false,
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.right,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'عنوان، بازیگر، کارگردان یا ژانر',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: controller.text.isEmpty
                    ? null
                    : IconButton(
                        onPressed: () {
                          controller.clear();
                          state.search('');
                          setState(() {});
                        },
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (value) {
                setState(() {});
                debounce?.cancel();
                debounce = Timer(
                  const Duration(milliseconds: 550),
                  () => state.search(value),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('همه'),
                  selected: filter == null,
                  onSelected: (_) => setState(() => filter = null),
                ),
                ChoiceChip(
                  label: const Text('فیلم'),
                  selected: filter == MediaType.movie,
                  onSelected: (_) => setState(() => filter = MediaType.movie),
                ),
                ChoiceChip(
                  label: const Text('سریال'),
                  selected: filter == MediaType.series,
                  onSelected: (_) => setState(() => filter = MediaType.series),
                ),
              ],
            ),
          ),
          if (state.catalogue.isConfigured == false)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 18),
              child: Text(
                'حالت نمونه فعال است؛ برای جست‌وجوی آنلاین کلید OMDb را با dart-define وارد کنید.',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ),
          if (state.searching) const LinearProgressIndicator(minHeight: 2),
          if (state.searchError != null)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.wifi_off, color: Colors.amber),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${state.searchError} نتایج ذخیره‌شده نمایش داده می‌شوند.',
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: results.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.manage_search, size: 64, color: Colors.grey),
                        SizedBox(height: 12),
                        Text('نتیجه‌ای پیدا نشد'),
                      ],
                    ),
                  )
                : GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: .58,
                          crossAxisSpacing: 14,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: results.length,
                    itemBuilder: (_, i) => MediaPosterCard(
                      media: results[i],
                      width: double.infinity,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
