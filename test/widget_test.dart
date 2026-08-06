// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:project_film_management/main.dart';
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
}
