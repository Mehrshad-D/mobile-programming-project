import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/demo_catalog.dart';
import '../models/media.dart';
import '../models/user_account.dart';
import '../services/omdb_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._prefs);
  static const _storageKey = 'filmyab_state_v1';
  final SharedPreferences _prefs;
  final OmdbService catalogue = OmdbService();

  UserAccount? account;
  bool guest = false;
  bool ready = false;
  bool searching = false;
  String? searchError;
  List<MediaItem> searchResults = const [];
  final Map<String, WatchStatus> statuses = {};
  final Set<String> watchedEpisodes = {};
  final Map<String, int> ratings = {};
  final Map<String, List<Review>> reviews = {};
  final Map<String, Set<String>> customLists = {};
  final Map<String, MediaItem> savedMedia = {};

  bool get signedIn => account != null;
  List<MediaItem> get catalog => demoCatalog;
  List<MediaItem> get allMedia {
    final demoIds = catalog.map((media) => media.id).toSet();
    return [
      ...catalog,
      ...savedMedia.values.where((media) => !demoIds.contains(media.id)),
    ];
  }

  static Future<AppState> create() async {
    final state = AppState(await SharedPreferences.getInstance());
    state._restore();
    state.ready = true;
    return state;
  }

  String _hash(String input) => sha256.convert(utf8.encode(input)).toString();

  String? register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) {
    if (name.trim().length < 2) return 'نام و نام خانوادگی را کامل وارد کنید.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      return 'ساختار ایمیل معتبر نیست.';
    }
    if (username.trim().length < 3) {
      return 'نام کاربری باید حداقل ۳ کاراکتر باشد.';
    }
    if (password.length < 6) return 'رمز عبور باید حداقل ۶ کاراکتر باشد.';
    final stored = _prefs.getString(_storageKey);
    if (stored != null) {
      final old = jsonDecode(stored) as Map<String, dynamic>;
      final oldUser = old['account'] as Map<String, dynamic>?;
      if (oldUser != null &&
          (oldUser['email'] == email.trim() ||
              oldUser['username'] == username.trim())) {
        return 'این ایمیل یا نام کاربری قبلاً ثبت شده است.';
      }
    }
    account = UserAccount(
      name: name.trim(),
      username: username.trim(),
      email: email.trim(),
      passwordHash: _hash(password),
    );
    guest = false;
    _save();
    notifyListeners();
    return null;
  }

  String? login(String email, String password) {
    final stored = _prefs.getString(_storageKey);
    if (stored == null) return 'ابتدا یک حساب کاربری بسازید.';
    final json = jsonDecode(stored) as Map<String, dynamic>;
    final userJson = json['account'] as Map<String, dynamic>?;
    if (userJson == null) return 'حسابی با این ایمیل وجود ندارد.';
    final user = UserAccount.fromJson(userJson);
    if (user.email != email.trim() || user.passwordHash != _hash(password)) {
      return 'ایمیل یا رمز عبور نادرست است.';
    }
    account = user;
    guest = false;
    _restoreActivity(json);
    _save();
    notifyListeners();
    return null;
  }

  String? resetPassword(String email, String newPassword) {
    final stored = _prefs.getString(_storageKey);
    if (stored == null) return 'حساب ذخیره‌شده‌ای وجود ندارد.';
    final json = jsonDecode(stored) as Map<String, dynamic>;
    final userJson = json['account'] as Map<String, dynamic>?;
    if (userJson == null) return 'حساب ذخیره‌شده‌ای وجود ندارد.';
    final storedUser = UserAccount.fromJson(userJson);
    if (storedUser.email != email.trim()) {
      return 'ایمیل وارد شده با حساب ذخیره‌شده مطابقت ندارد.';
    }
    if (newPassword.length < 6) return 'رمز جدید باید حداقل ۶ کاراکتر باشد.';
    account = storedUser.copyWith(passwordHash: _hash(newPassword));
    _save();
    notifyListeners();
    return null;
  }

  void enterAsGuest() {
    guest = true;
    account = null;
    notifyListeners();
  }

  void logout() {
    guest = false;
    final raw = _prefs.getString(_storageKey);
    if (raw != null) {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      json['sessionExpiry'] = DateTime.fromMillisecondsSinceEpoch(
        0,
      ).toIso8601String();
      _prefs.setString(_storageKey, jsonEncode(json));
    }
    account = null;
    notifyListeners();
  }

  bool requireMember() => signedIn;
  WatchStatus statusOf(String id) => statuses[id] ?? WatchStatus.none;
  bool isFavorite(String id) => statusOf(id) == WatchStatus.favorite;

  void setStatus(String id, WatchStatus status, {MediaItem? media}) {
    if (!signedIn) return;
    _remember(media);
    if (status == WatchStatus.none) {
      statuses.remove(id);
    } else {
      statuses[id] = status;
    }
    _changed();
  }

  void toggleFavorite(String id, {MediaItem? media}) => setStatus(
    id,
    isFavorite(id) ? WatchStatus.none : WatchStatus.favorite,
    media: media,
  );
  bool isEpisodeWatched(String mediaId, String episodeId) =>
      watchedEpisodes.contains('$mediaId:$episodeId');
  void toggleEpisode(String mediaId, String episodeId, {MediaItem? media}) {
    if (!signedIn) return;
    _remember(media);
    final key = '$mediaId:$episodeId';
    watchedEpisodes.contains(key)
        ? watchedEpisodes.remove(key)
        : watchedEpisodes.add(key);
    _changed();
  }

  double progress(MediaItem media) {
    if (media.episodes.isEmpty) {
      return statusOf(media.id) == WatchStatus.completed ? 1 : 0;
    }
    final count = media.episodes
        .where((e) => isEpisodeWatched(media.id, e.id))
        .length;
    return count / media.episodes.length;
  }

  void rate(String id, int value, {MediaItem? media}) {
    if (signedIn) {
      _remember(media);
      ratings[id] = value.clamp(1, 5);
      _changed();
    }
  }

  void addReview(String id, String text, bool spoiler, {MediaItem? media}) {
    if (!signedIn || text.trim().isEmpty) return;
    _remember(media);
    reviews
        .putIfAbsent(id, () => [])
        .insert(
          0,
          Review(
            user: account!.username,
            text: text.trim(),
            date: DateTime.now().toIso8601String().substring(0, 10),
            spoiler: spoiler,
          ),
        );
    _changed();
  }

  void createList(String name) {
    if (signedIn && name.trim().isNotEmpty) {
      customLists.putIfAbsent(name.trim(), () => {});
      _changed();
    }
  }

  void toggleInList(String list, String id) {
    if (signedIn) {
      final set = customLists.putIfAbsent(list, () => {});
      set.contains(id) ? set.remove(id) : set.add(id);
      _changed();
    }
  }

  void setListMembership(
    String id,
    Set<String> selectedLists, {
    MediaItem? media,
  }) {
    if (!signedIn) return;
    _remember(media);
    for (final entry in customLists.entries) {
      if (selectedLists.contains(entry.key)) {
        entry.value.add(id);
      } else {
        entry.value.remove(id);
      }
    }
    _changed();
  }

  void deleteList(String name) {
    customLists.remove(name);
    _changed();
  }

  void _remember(MediaItem? media) {
    if (media != null) savedMedia[media.id] = media;
  }

  void cacheMedia(MediaItem media) {
    savedMedia[media.id] = media;
    _save();
  }

  void updateProfile({
    required String name,
    required String username,
    required String bio,
  }) {
    if (account == null) return;
    account = account!.copyWith(
      name: name.trim(),
      username: username.trim(),
      bio: bio.trim(),
    );
    _changed();
  }

  Future<void> search(String query) async {
    final q = query.trim().toLowerCase();
    searchError = null;
    if (q.isEmpty) {
      searchResults = const [];
      notifyListeners();
      return;
    }
    searching = true;
    notifyListeners();
    final local = allMedia
        .where(
          (m) =>
              '${m.title} ${m.originalTitle} ${m.genres.join(' ')} ${m.director} ${m.cast.join(' ')}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    try {
      final remote = await catalogue.search(query);
      for (final media in remote) {
        savedMedia.putIfAbsent(media.id, () => media);
      }
      _save();
      final ids = local.map((e) => e.id).toSet();
      searchResults = [...local, ...remote.where((e) => ids.add(e.id))];
    } on CatalogException catch (e) {
      searchResults = local;
      searchError = e.message;
    } finally {
      searching = false;
      notifyListeners();
    }
  }

  void _changed() {
    _save();
    notifyListeners();
  }

  void _restore() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    final expiry = DateTime.tryParse(json['sessionExpiry']?.toString() ?? '');
    if (expiry != null &&
        expiry.isAfter(DateTime.now()) &&
        json['account'] != null) {
      account = UserAccount.fromJson(json['account'] as Map<String, dynamic>);
    }
    _restoreActivity(json);
  }

  void _restoreActivity(Map<String, dynamic> json) {
    statuses
      ..clear()
      ..addAll(
        (json['statuses'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, WatchStatus.values.byName(v as String)),
        ),
      );
    watchedEpisodes
      ..clear()
      ..addAll(
        (json['watchedEpisodes'] as List<dynamic>? ?? []).cast<String>(),
      );
    ratings
      ..clear()
      ..addAll(
        (json['ratings'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, v as int),
        ),
      );
    reviews
      ..clear()
      ..addAll(
        (json['reviews'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(
            k,
            (v as List)
                .map((e) => Review.fromJson(e as Map<String, dynamic>))
                .toList(),
          ),
        ),
      );
    customLists
      ..clear()
      ..addAll(
        (json['customLists'] as Map<String, dynamic>? ?? {}).map(
          (k, v) => MapEntry(k, (v as List).cast<String>().toSet()),
        ),
      );
    savedMedia
      ..clear()
      ..addAll(
        (json['savedMedia'] as Map<String, dynamic>? ?? {}).map(
          (id, value) =>
              MapEntry(id, MediaItem.fromJson(value as Map<String, dynamic>)),
        ),
      );
  }

  Future<void> _save() => _prefs.setString(
    _storageKey,
    jsonEncode({
      'account': account?.toJson(),
      'sessionExpiry': DateTime.now()
          .add(const Duration(days: 30))
          .toIso8601String(),
      'statuses': statuses.map((k, v) => MapEntry(k, v.name)),
      'watchedEpisodes': watchedEpisodes.toList(),
      'ratings': ratings,
      'reviews': reviews.map(
        (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
      ),
      'customLists': customLists.map((k, v) => MapEntry(k, v.toList())),
      'savedMedia': savedMedia.map((id, media) => MapEntry(id, media.toJson())),
    }),
  );
}
