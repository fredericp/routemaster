@TestOn('browser')
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:routemaster/routemaster.dart';
import 'package:routemaster/src/system_nav.dart';
import 'helpers.dart';

void main() {
  test('makeUrl makes hash URL with null query params', () {
    expect(
      SystemNav.makeUrl(
        path: '/new-path',
        queryParameters: null,
      ),
      '#/new-path',
    );
  });

  test('makeUrl makes hash URL with empty query params', () {
    expect(
      SystemNav.makeUrl(
        path: '/new-path',
        queryParameters: {},
      ),
      '#/new-path',
    );
  });

  test('makeUrl makes hash URL with query params', () {
    expect(
      SystemNav.makeUrl(
        path: '/new-path',
        queryParameters: {'query': 'param'},
      ),
      '#/new-path?query=param',
    );
  });

  test('makeUrl makes hash URL with just query params', () {
    expect(
      SystemNav.makeUrl(
        path: '/new-path',
        queryParameters: {'query': 'param'},
      ),
      '#/new-path?query=param',
    );
  });

  test('makeUrl makes hash URL with query params', () {
    expect(
      SystemNav.makeUrl(
        path: '/new-path',
        queryParameters: {'query': 'param'},
      ),
      '#/new-path?query=param',
    );
  });

  testWidgets('Replaces URL when redirecting to tabs', (tester) async {
    final routes1 = RouteMap(
      routes: {'/': (_) => MaterialPage<void>(child: Container())},
    );

    final routes2 = RouteMap(
      routes: {
        '/': (_) => CupertinoTabPage(
              child: Container(),
              paths: const ['/one', '/two'],
            ),
        '/one': (_) => const MaterialPageOne(),
        '/two': (_) => const MaterialPageTwo(),
      },
    );

    expect(
      await recordUrlChanges(() async {
        await tester.pumpWidget(
          MaterialApp.router(
            routerDelegate: RoutemasterDelegate(routesBuilder: (_) => routes1),
            routeInformationParser: const RoutemasterParser(),
          ),
        );

        await tester.pumpWidget(
          MaterialApp.router(
            routerDelegate: RoutemasterDelegate(routesBuilder: (_) => routes2),
            routeInformationParser: const RoutemasterParser(),
          ),
        );
        await tester.pump();
      }),
      ['/', '/one'],
    );
  });
}
