import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/demo_catalog.dart';
import '../models/media.dart';
import '../models/user_account.dart';
import '../services/backend_service.dart';
import '../services/omdb_service.dart';

class AppState extends ChangeNotifier {
  AppState(this._prefs, {BackendApi? backend})
    : backend = backend ?? BackendService();
  static const _storageKey = 'filmyab_state_v1';
  final SharedPreferences _prefs;
  final BackendApi backend;
  final OmdbService catalogue = OmdbService();

  String? _accessToken;
  UserAccount? account;
  UserAccount? registeredAccount;
  DateTime? _sessionExpiry;
  bool guest = false;
  bool ready = false;
  bool searching = false;
  String? searchError;
  String? syncError;
  List<MediaItem> searchResults = const [];
  final Map<String, WatchStatus> statuses = {};
  final Set<String> watchedEpisodes = {};
  final Map<String, int> ratings = {};
  final Map<String, List<Review>> reviews = {};
  final Map<String, Set<String>> customLists = {};
  final Map<String, int> customListIds = {};
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

  static Future<AppState> create({BackendApi? backend}) async {
    final state = AppState(
      await SharedPreferences.getInstance(),
      backend: backend,
    );
    state._restore();
    if (state._accessToken != null && state.signedIn) {
      state.backend.token = state._accessToken;
      try {
        await state._synchronizeMemberData();
      } on BackendException catch (error) {
        state.syncError = error.message;
        if (error.code == 'invalid_token') state._clearSession();
      }
    }
    state.ready = true;
    return state;
  }

  Future<String?> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    if (name.trim().length < 2) return 'نام و نام خانوادگی را کامل وارد کنید.';
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email.trim())) {
      return 'ساختار ایمیل معتبر نیست.';
    }
    if (username.trim().length < 3) {
      return 'نام کاربری باید حداقل ۳ کاراکتر باشد.';
    }
    if (password.length < 8) return 'رمز عبور باید حداقل ۸ کاراکتر باشد.';
    try {
      final profile = await backend.register(
        name: name.trim(),
        username: username.trim(),
        email: email.trim(),
        password: password,
      );
      _startSession(profile);
      await _synchronizeMemberData(refreshProfile: false);
      return null;
    } on BackendException catch (error) {
      return error.message;
    }
  }

  Future<String?> login(String email, String password) async {
    try {
      final profile = await backend.login(email.trim(), password);
      _startSession(profile);
      await _synchronizeMemberData(refreshProfile: false);
      return null;
    } on BackendException catch (error) {
      return error.message;
    }
  }

  String? resetPassword(String email, String newPassword) {
    return 'بازیابی امن رمز عبور باید از طریق ایمیل سرور انجام شود.';
  }

  void enterAsGuest() {
    guest = true;
    account = null;
    _sessionExpiry = DateTime.fromMillisecondsSinceEpoch(0);
    _save();
    notifyListeners();
  }

  void logout() {
    _clearSession();
    _save();
    notifyListeners();
  }

  bool requireMember() => signedIn;
  WatchStatus statusOf(String id) => statuses[id] ?? WatchStatus.none;
  bool isFavorite(String id) => statusOf(id) == WatchStatus.favorite;

  void setStatus(String id, WatchStatus status, {MediaItem? media}) {
    if (!signedIn) return;
    final wasFavorite = isFavorite(id);
    _remember(media);
    if (status == WatchStatus.none) {
      statuses.remove(id);
    } else {
      statuses[id] = status;
    }
    _changed();
    _send(backend.setWatchStatus(id, status.name));
    if (wasFavorite != (status == WatchStatus.favorite)) {
      _send(backend.setFavorite(id, status == WatchStatus.favorite));
    }
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
    final watched = !watchedEpisodes.contains(key);
    watched ? watchedEpisodes.add(key) : watchedEpisodes.remove(key);
    _changed();
    final episode = media?.episodes
        .where((item) => item.id == episodeId)
        .firstOrNull;
    if (episode?.databaseId != null) {
      _send(backend.setEpisodeWatched(episode!.databaseId!, watched));
    }
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
      _send(backend.rate(id, ratings[id]!));
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
    _send(backend.addReview(id, text.trim(), spoiler));
  }

  Future<String?> createList(String name) async {
    final cleaned = name.trim();
    if (!signedIn || cleaned.isEmpty) return null;
    try {
      final result = await backend.createList(cleaned);
      customLists.putIfAbsent(result['name'] as String, () => {});
      customListIds[result['name'] as String] = result['id'] as int;
      _changed();
      return null;
    } on BackendException catch (error) {
      return error.message;
    }
  }

  void toggleInList(String list, String id) {
    if (signedIn) {
      final set = customLists.putIfAbsent(list, () => {});
      set.contains(id) ? set.remove(id) : set.add(id);
      _changed();
    }
  }

  Future<String?> setListMembership(
    String id,
    Set<String> selectedLists, {
    MediaItem? media,
  }) async {
    if (!signedIn) return null;
    _remember(media);
    try {
      for (final entry in customLists.entries) {
        final listId = customListIds[entry.key];
        if (listId == null) continue;
        final shouldContain = selectedLists.contains(entry.key);
        final contains = entry.value.contains(id);
        if (shouldContain && !contains) {
          await backend.addListItem(listId, id);
        } else if (!shouldContain && contains) {
          await backend.removeListItem(listId, id);
        }
        shouldContain ? entry.value.add(id) : entry.value.remove(id);
      }
      _changed();
      return null;
    } on BackendException catch (error) {
      return error.message;
    }
  }

  Future<String?> deleteList(String name) async {
    final id = customListIds[name];
    if (id == null) return null;
    try {
      await backend.deleteList(id);
      customLists.remove(name);
      customListIds.remove(name);
      _changed();
      return null;
    } on BackendException catch (error) {
      return error.message;
    }
  }

  void _remember(MediaItem? media) {
    if (media != null) savedMedia[media.id] = media;
  }

  void cacheMedia(MediaItem media) {
    savedMedia[media.id] = media;
    _save();
  }

  Future<String?> updateProfile({
    required String name,
    required String username,
    required String bio,
  }) async {
    if (account == null) return null;
    try {
      final profile = await backend.updateProfile(
        name: name.trim(),
        username: username.trim(),
        bio: bio.trim(),
      );
      account = _accountFromProfile(profile);
      registeredAccount = account;
      _changed();
      return null;
    } on BackendException catch (error) {
      return error.message;
    }
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

  UserAccount _accountFromProfile(Map<String, dynamic> profile) => UserAccount(
    name: profile['name'] as String,
    username: profile['username'] as String,
    email: profile['email'] as String,
    passwordHash: '',
    bio: profile['bio']?.toString() ?? '',
  );

  void _startSession(Map<String, dynamic> profile) {
    _accessToken = backend.token;
    account = _accountFromProfile(profile);
    registeredAccount = account;
    _sessionExpiry = DateTime.now().add(const Duration(days: 30));
    guest = false;
    syncError = null;
    _save();
    notifyListeners();
  }

  void _clearSession() {
    guest = false;
    account = null;
    _accessToken = null;
    backend.token = null;
    _sessionExpiry = DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<void> _synchronizeMemberData({bool refreshProfile = true}) async {
    if (refreshProfile) {
      account = _accountFromProfile(await backend.profile());
      registeredAccount = account;
    }
    final serverLists = await backend.lists();
    customLists.clear();
    customListIds.clear();
    for (final list in serverLists) {
      final name = list['name'] as String;
      customLists[name] = (list['media_ids'] as List<dynamic>)
          .cast<String>()
          .toSet();
      customListIds[name] = list['id'] as int;
    }
    final serverActivity = await backend.activity();
    statuses.clear();
    for (final item in serverActivity['watch_statuses'] as List<dynamic>) {
      final row = item as Map<String, dynamic>;
      statuses[row['media_id'] as String] = WatchStatus.values.byName(
        row['status'] as String,
      );
    }
    for (final id
        in (serverActivity['favorite_ids'] as List<dynamic>).cast<String>()) {
      statuses[id] = WatchStatus.favorite;
    }
    ratings
      ..clear()
      ..addEntries(
        (serverActivity['ratings'] as List<dynamic>).map((item) {
          final row = item as Map<String, dynamic>;
          return MapEntry(row['media_id'] as String, row['value'] as int);
        }),
      );
    final watchedDatabaseIds =
        (serverActivity['watched_episode_ids'] as List<dynamic>)
            .cast<int>()
            .toSet();
    watchedEpisodes.clear();
    for (final media in savedMedia.values) {
      for (final episode in media.episodes) {
        if (watchedDatabaseIds.contains(episode.databaseId)) {
          watchedEpisodes.add('${media.id}:${episode.id}');
        }
      }
    }
    syncError = null;
    _save();
    notifyListeners();
  }

  Future<void> _send(Future<void> request) async {
    try {
      await request;
      syncError = null;
    } on BackendException catch (error) {
      syncError = error.message;
      notifyListeners();
    }
  }

  void _restore() {
    final raw = _prefs.getString(_storageKey);
    if (raw == null) return;
    final json = jsonDecode(raw) as Map<String, dynamic>;
    _accessToken = json['accessToken'] as String?;
    final expiry = DateTime.tryParse(json['sessionExpiry']?.toString() ?? '');
    _sessionExpiry = expiry;
    if (json['account'] != null) {
      registeredAccount = UserAccount.fromJson(
        json['account'] as Map<String, dynamic>,
      );
    }
    if (expiry != null &&
        expiry.isAfter(DateTime.now()) &&
        _accessToken != null) {
      account = registeredAccount;
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
    customListIds
      ..clear()
      ..addAll(
        (json['customListIds'] as Map<String, dynamic>? ?? {}).map(
          (name, id) => MapEntry(name, id as int),
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
      'account': registeredAccount?.toJson(),
      'accessToken': _accessToken,
      'sessionExpiry':
          (_sessionExpiry ?? DateTime.fromMillisecondsSinceEpoch(0))
              .toIso8601String(),
      'statuses': statuses.map((k, v) => MapEntry(k, v.name)),
      'watchedEpisodes': watchedEpisodes.toList(),
      'ratings': ratings,
      'reviews': reviews.map(
        (k, v) => MapEntry(k, v.map((e) => e.toJson()).toList()),
      ),
      'customLists': customLists.map((k, v) => MapEntry(k, v.toList())),
      'customListIds': customListIds,
      'savedMedia': savedMedia.map((id, media) => MapEntry(id, media.toJson())),
    }),
  );
}
