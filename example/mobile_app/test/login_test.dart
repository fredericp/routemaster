import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_app/main.dart';
import 'package:mobile_app/pages/feed_page.dart';
import 'package:mobile_app/pages/home_page.dart';
import 'package:mobile_app/pages/login_page.dart';
import 'helpers.dart';

void main() {
  testWidgets('Logs in and out', (tester) async {
    await tester.pumpWidget(MyApp());
    expect(find.byType(LoginPage), findsOneWidget);

    expect(
      await recordUrlChanges(() async {
        await tester.tap(find.text('Log in'));
        await tester.pump();
        await tester.pump(Duration(seconds: 1));
      }),
      ['/feed'],
    );

    expect(find.byType(LoginPage), findsNothing);
    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(FeedPage), findsOneWidget);

    expect(
      await recordUrlChanges(() async {
        await tester.tap(find.text('Settings'));
        await tester.pump();
      }),
      ['/settings'],
    );

    expect(
      await recordUrlChanges(() async {
        await tester.tap(find.text('Log out'));
        await tester.pump();
        await tester.pump();
        await tester.pump(Duration(seconds: 1));
      }),
      ['/'],
    );

    expect(find.byType(HomePage), findsNothing);
    expect(find.byType(LoginPage), findsOneWidget);

    // Log back in just for fun
    expect(
      await recordUrlChanges(() async {
        await tester.tap(find.text('Log in'));
        await tester.pump();
        await tester.pump(Duration(seconds: 1));
      }),
      ['/feed'],
    );

    expect(find.byType(HomePage), findsOneWidget);
    expect(find.byType(LoginPage), findsNothing);
  });
}
