// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_film_management/main.dart';
import 'package:project_film_management/models/media.dart';
import 'package:project_film_management/screens/detail_screen.dart';
import 'package:project_film_management/screens/library_screen.dart';
import 'package:project_film_management/screens/profile_screen.dart';
import 'package:project_film_management/state/app_state.dart';
import 'package:project_film_management/widgets/media_widgets.dart';

import 'fake_backend.dart';

Future<AppState> createTestState([FakeBackend? backend]) =>
    AppState.create(backend: backend ?? FakeBackend());

void main() {
  testWidgets('shows Persian authentication screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await createTestState();
    await tester.pumpWidget(FilmYabApp(state: state));
    expect(find.text('فیلم‌یاب'), findsOneWidget);
    expect(find.text('ورود'), findsOneWidget);
    expect(find.text('ورود به‌عنوان مهمان'), findsOneWidget);
  });

  test('registration validates and hashes passwords', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await createTestState();
    expect(
      await state.register(
        name: 'کاربر تست',
        username: 'tester',
        email: 'bad',
        password: '12345678',
      ),
      isNotNull,
    );
    expect(
      await state.register(
        name: 'کاربر تست',
        username: 'tester',
        email: 'test@example.com',
        password: '12345678',
      ),
      isNull,
    );
    expect(state.account!.passwordHash, isNot('123456'));
  });

  test(
    'guest catalogue caching does not erase the registered account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();
      final state = await createTestState(backend);
      await state.register(
        name: 'کاربر تست',
        username: 'tester',
        email: 'test@example.com',
        password: '12345678',
      );
      await Future<void>.delayed(Duration.zero);
      state.logout();
      state.enterAsGuest();
      state.cacheMedia(state.catalog.first);
      await Future<void>.delayed(Duration.zero);
      state.logout();

      final restored = await createTestState(backend);
      expect(await restored.login('test@example.com', '12345678'), isNull);
      expect(restored.signedIn, isTrue);
    },
  );

  test('catalogue series do not contain hard-coded episode subsets', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await createTestState();
    final series = state.catalog.where((media) => media.isSeries);
    expect(series, isNotEmpty);
    expect(series.every((media) => media.episodes.isEmpty), isTrue);
  });

  testWidgets('accepts Persian comments and closes the composer safely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final state = await createTestState();
    await state.register(
      name: 'کاربر تست',
      username: 'آزمایشگر',
      email: 'test@example.com',
      password: '12345678',
    );
    final media = state.catalog.first;
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: MaterialApp(home: DetailScreen(media: media)),
      ),
    );

    await tester.ensureVisible(find.text('ثبت نظر'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ثبت نظر'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'این فیلم بسیار زیبا بود',
    );
    expect(find.text('این فیلم بسیار زیبا بود'), findsOneWidget);
    await tester.tap(find.text('انتشار نظر'));
    await tester.pumpAndSettle();

    expect(state.reviews[media.id]!.single.text, 'این فیلم بسیار زیبا بود');
    expect(tester.takeException(), isNull);
  });

  testWidgets('creates a list and adds a film after overlays close', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final state = await createTestState();
    await state.register(
      name: 'کاربر تست',
      username: 'آزمایشگر',
      email: 'test@example.com',
      password: '12345678',
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: LibraryScreen()),
      ),
    );

    await tester.tap(find.byIcon(Icons.playlist_add_rounded));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'فیلم‌های آخر هفته');
    await tester.tap(find.text('ساختن'));
    await tester.pumpAndSettle();
    expect(state.customLists, contains('فیلم‌های آخر هفته'));
    expect(tester.takeException(), isNull);

    final navigatorContext = tester.element(find.byType(LibraryScreen));
    Navigator.of(navigatorContext).push(
      MaterialPageRoute<void>(
        builder: (_) => DetailScreen(media: state.catalog.first),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.playlist_add));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فیلم‌های آخر هفته'));
    await tester.tap(find.text('ذخیره تغییرات'));
    await tester.pumpAndSettle();

    expect(
      state.customLists['فیلم‌های آخر هفته'],
      contains(state.catalog.first.id),
    );
    expect(tester.takeException(), isNull);
  });

  test(
    'persists an online series so My Lists can resolve its IMDb id',
    () async {
      SharedPreferences.setMockInitialValues({});
      final backend = FakeBackend();
      final state = await createTestState(backend);
      await state.register(
        name: 'کاربر تست',
        username: 'آزمایشگر',
        email: 'test@example.com',
        password: '12345678',
      );
      const onlineSeries = MediaItem(
        id: 'tt-online-series',
        title: 'سریال آنلاین',
        originalTitle: 'Online Series',
        type: MediaType.series,
        posterUrl: '',
        backdropUrl: '',
        overview: 'سریالی دریافت‌شده از سرویس آنلاین',
        year: 2026,
        genres: ['درام'],
        rating: 8.2,
        runtime: 45,
        country: 'ایران',
        director: 'کارگردان',
        cast: ['بازیگر'],
        declaredSeasonCount: 1,
        episodes: [
          Episode(
            season: 1,
            number: 1,
            title: 'قسمت اول',
            runtime: 45,
            overview: 'شروع داستان',
          ),
        ],
      );
      await state.createList('سریال‌های من');
      await state.setListMembership(onlineSeries.id, {
        'سریال‌های من',
      }, media: onlineSeries);
      await Future<void>.delayed(Duration.zero);

      final restored = await createTestState(backend);
      expect(restored.customLists['سریال‌های من'], contains(onlineSeries.id));
      expect(
        restored.allMedia.map((media) => media.id),
        contains(onlineSeries.id),
      );
      expect(
        restored.allMedia
            .singleWhere((media) => media.id == onlineSeries.id)
            .episodes,
        hasLength(1),
      );
    },
  );

  testWidgets('home poster grids do not overflow on a narrow phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final state = await createTestState();
    state.enterAsGuest();
    await tester.pumpWidget(FilmYabApp(state: state));
    await tester.pump();

    final scrollView = find.byType(CustomScrollView);
    for (var i = 0; i < 8 && find.text('آثار جدید').evaluate().isEmpty; i++) {
      await tester.drag(scrollView, const Offset(0, -500));
      await tester.pump();
    }
    await tester.drag(scrollView, const Offset(0, -500));
    await tester.pump();

    expect(find.byType(MediaPosterCard), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile editor closes before updating global state', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final state = await createTestState();
    await state.register(
      name: 'نام قدیمی',
      username: 'old_user',
      email: 'test@example.com',
      password: '12345678',
    );
    await tester.pumpWidget(
      AppScope(
        state: state,
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );

    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    await tester.enterText(fields.at(0), 'نام جدید');
    await tester.enterText(fields.at(1), 'کاربر جدید');
    await tester.enterText(fields.at(2), 'زندگینامه جدید');
    await tester.tap(find.text('ذخیره'));
    await tester.pumpAndSettle();

    expect(state.account!.name, 'نام جدید');
    expect(state.account!.username, 'کاربر جدید');
    expect(state.account!.bio, 'زندگینامه جدید');
    expect(tester.takeException(), isNull);
  });
}
