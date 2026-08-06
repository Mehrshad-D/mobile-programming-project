import 'package:project_film_management/services/backend_service.dart';

class FakeBackend implements BackendApi {
  Map<String, dynamic>? _account;
  final Map<int, Map<String, dynamic>> _lists = {};
  int _nextListId = 1;

  @override
  String? token;

  @override
  Future<Map<String, dynamic>> register({
    required String name,
    required String username,
    required String email,
    required String password,
  }) async {
    _account = {
      'id': 1,
      'name': name,
      'username': username,
      'email': email,
      'bio': '',
    };
    token = 'fake-token';
    return Map.of(_account!);
  }

  @override
  Future<Map<String, dynamic>> login(String email, String password) async {
    if (_account?['email'] != email) {
      throw const BackendException('ایمیل یا رمز عبور نادرست است.');
    }
    token = 'fake-token';
    return Map.of(_account!);
  }

  @override
  Future<Map<String, dynamic>> profile() async => Map.of(_account!);

  @override
  Future<Map<String, dynamic>> updateProfile({
    required String name,
    required String username,
    required String bio,
  }) async {
    _account!.addAll({'name': name, 'username': username, 'bio': bio});
    return Map.of(_account!);
  }

  @override
  Future<List<Map<String, dynamic>>> lists() async =>
      _lists.values.map(Map<String, dynamic>.of).toList();

  @override
  Future<Map<String, dynamic>> createList(String name) async {
    final row = <String, dynamic>{
      'id': _nextListId++,
      'name': name,
      'media_ids': <String>[],
    };
    _lists[row['id'] as int] = row;
    return Map.of(row);
  }

  @override
  Future<void> deleteList(int id) async => _lists.remove(id);

  @override
  Future<void> addListItem(int listId, String mediaId) async {
    final ids = (_lists[listId]!['media_ids'] as List<String>);
    if (!ids.contains(mediaId)) ids.add(mediaId);
  }

  @override
  Future<void> removeListItem(int listId, String mediaId) async =>
      (_lists[listId]!['media_ids'] as List<String>).remove(mediaId);

  @override
  Future<Map<String, dynamic>> activity() async => {
    'watch_statuses': <dynamic>[],
    'watched_episode_ids': <dynamic>[],
    'ratings': <dynamic>[],
    'favorite_ids': <dynamic>[],
  };

  @override
  Future<void> setWatchStatus(String mediaId, String status) async {}

  @override
  Future<void> setEpisodeWatched(int episodeId, bool watched) async {}

  @override
  Future<void> rate(String mediaId, int value) async {}

  @override
  Future<void> setFavorite(String mediaId, bool favorite) async {}

  @override
  Future<void> addReview(String mediaId, String text, bool spoiler) async {}
}
