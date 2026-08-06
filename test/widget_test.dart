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
import 'package:project_film_management/screens/detail_screen.dart';
import 'package:project_film_management/screens/library_screen.dart';
import 'package:project_film_management/state/app_state.dart';

void main() {
  testWidgets('shows Persian authentication screen', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.create();
    await tester.pumpWidget(FilmYabApp(state: state));
    expect(find.text('فیلم‌یاب'), findsOneWidget);
    expect(find.text('ورود'), findsOneWidget);
    expect(find.text('ورود به‌عنوان مهمان'), findsOneWidget);
  });

  test('registration validates and hashes passwords', () async {
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.create();
    expect(
      state.register(
        name: 'کاربر تست',
        username: 'tester',
        email: 'bad',
        password: '123456',
      ),
      isNotNull,
    );
    expect(
      state.register(
        name: 'کاربر تست',
        username: 'tester',
        email: 'test@example.com',
        password: '123456',
      ),
      isNull,
    );
    expect(state.account!.passwordHash, isNot('123456'));
  });

  testWidgets('accepts Persian comments and closes the composer safely', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    final state = await AppState.create();
    state.register(
      name: 'کاربر تست',
      username: 'آزمایشگر',
      email: 'test@example.com',
      password: '123456',
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
    final state = await AppState.create();
    state.register(
      name: 'کاربر تست',
      username: 'آزمایشگر',
      email: 'test@example.com',
      password: '123456',
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
}
