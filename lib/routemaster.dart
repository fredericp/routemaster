library routemaster;

export 'src/parser.dart';
export 'src/pages/guard.dart';

import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/widgets.dart';
import 'package:collection/collection.dart';
import 'src/not_found_page.dart';
import 'src/pages/guard.dart';
import 'src/path_parser.dart';
import 'src/system_nav.dart';
import 'src/trie_router/trie_router.dart';

part 'src/pages/page_stack.dart';
part 'src/pages/tab_pages.dart';
part 'src/pages/basic_pages.dart';
part 'src/observers.dart';
part 'src/route_data.dart';

/// A function that builds a [Page] from given [RouteData].
typedef PageBuilder = Page Function(RouteData route);

/// A function that returns a [Page] when the given [path] couldn't be found.
typedef UnknownRouteCallback = Page Function(String path);

/// A standard simple routing table which takes a map of routes.
///
///   * [routes] - A map of paths and [PageBuilder] delegates that return
///     [Page] objects to build.
///
@immutable
class RouteMap {
  final UnknownRouteCallback? _onUnknownRoute;

  final _router = TrieRouter();

  /// Creates a standard simple routing table which takes a map of routes.
  ///
  ///   * [routes] - a map of paths and [PageBuilder] delegates that return
  ///     [Page] objects to build.
  ///
  ///   * [onUnknownRoute] - called when there's no match for a route.
  ///     There are two general options for this callback's operation:
  ///
  ///       1. Return a page, which will be displayed.
  ///
  ///     or
  ///
  ///       2. Use the routing delegate to, for instance, redirect to another
  ///          route and return null.
  ///
  RouteMap({
    required Map<String, PageBuilder> routes,
    UnknownRouteCallback? onUnknownRoute,
  }) : _onUnknownRoute = onUnknownRoute {
    _router.addAll(routes);
  }

  /// Generate a single [RouteResult] for the given [path]. Returns null if the
  /// path isn't valid.
  RouterResult? get(String path) {
    return _router.get(path);
  }

  /// Generate all [RouteResult] objects required to build the navigation tree
  /// for the given [path]. Returns null if the path isn't valid.
  List<RouterResult>? getAll(String path) {
    return _router.getAll(path);
  }

  /// Called when there's no match for a route. By default this returns
  /// [DefaultNotFoundPage], a simple page not found page.
  ///
  /// There are two general options for this callback's operation:
  ///
  ///   1. Return a page, which will be displayed.
  ///
  /// or
  ///
  ///   2. Use the routing delegate to, for instance, redirect to another route
  ///      and return null.
  ///
  Page onUnknownRoute(String path) {
    if (_onUnknownRoute != null) {
      return _onUnknownRoute!(path);
    }

    return MaterialPage<void>(
      child: DefaultNotFoundPage(path: path),
    );
  }
}

/// Provides access to router functionality.
///
/// For example: `Routemaster.of(context).push('/path')`
class Routemaster {
  static final navigatorKey = GlobalKey<NavigatorState>();
  // The current router delegate. This can change if the delegate is recreated.
  late RoutemasterDelegate _delegate;

  Routemaster._();

  /// Uses [PathUrlStrategy] on the web, which removes hashes from URLs. This
  /// must be called at app startup, before `runApp` is called.
  ///
  /// Calling this method does nothing when not running on the web.
  ///
  /// Note: to load pages directly by URL, your server needs to be set up
  /// correctly.
  ///
  /// For example, if your app's home is at http://dash.dev/myapp and you have
  /// an app page with the path '/settings', then trying to load
  /// http://dash.dev/myapp/settings will probably show a server 404 error
  /// without additional server configuration.
  ///
  /// You need to ensure server requests to dash.dev/myapp/*<anything>* return
  /// the Flutter app.
  static void setPathUrlStrategy() {
    if (kIsWeb) {
      SystemNav.setPathUrlStrategy(); // coverage:ignore-line
    }
  }

  /// Retrieves the nearest ancestor [Routemaster] object.
  static Routemaster of(BuildContext context) {
    final widget =
        context.dependOnInheritedWidgetOfExactType<_RoutemasterWidget>();

    assert(
      widget != null,
      "Couldn't get a Routemaster object from the given context.",
    );

    return widget!.routemaster;
  }

  /// The current global route.
  RouteData get currentRoute => _delegate.currentConfiguration!;

  /// Pops the current route from the router. Returns `true` if the pop was
  /// successful, or `false` if it wasn't.
  @optionalTypeArgs
  Future<bool> pop<T extends Object?>([T? value]) {
    return _delegate.pop(value);
  }

  /// Replaces the current route with [path].
  ///
  /// If the given [path] starts with a forward slash, it's treated as an
  /// absolute path.
  ///
  /// If it doesn't start with a forward slash, it's treated as a relative path
  /// to the current route.
  ///
  /// For example:
  ///
  ///   * If the current route is '/products' and you call `replace('1')`
  ///     you'll navigate to '/products/1'.
  ///
  ///   * If the current route is '/products' and you call `replace('/home')`
  ///     you'll navigate to '/home'.
  ///
  void replace(String path, {Map<String, String>? queryParameters}) {
    _delegate.replace(path, queryParameters: queryParameters);
  }

  /// Pushes [path] into the navigation tree.
  ///
  /// If the given [path] starts with a forward slash, it's treated as an
  /// absolute path.
  ///
  /// If it doesn't start with a forward slash, it's treated as a relative path
  /// to the current route.
  ///
  /// For example:
  ///
  ///   * If the current route is '/products' and you call `replace('1')`
  ///     you'll navigate to '/products/1'.
  ///
  ///   * If the current route is '/products' and you call `replace('/home')`
  ///     you'll navigate to '/home'.
  ///
  @optionalTypeArgs
  NavigationResult<T> push<T extends Object?>(
    String path, {
    Map<String, String>? queryParameters,
  }) {
    return _delegate.push<T>(path, queryParameters: queryParameters);
  }
}

/// Provides access to the [Route] created after a route has been pushed.
///
/// Also provides access to any value returned when popping the route.
@immutable
class NavigationResult<T extends Object?> {
  NavigationResult._();

  /// Returns the top-most route that was created as a result of the navigation.
  Future<Route> get route => _routeCompleter.future;
  final Completer<Route> _routeCompleter = Completer<Route>();

  /// Used to get the return value from a route.
  ///
  /// Return values are passed back when popping a route, for example:
  ///
  ///   `Navigator.of(context).pop('Return value')`
  ///
  Future<T?> get result async {
    final route = await _routeCompleter.future;
    final result = await route.popped as T?;
    return result;
  }
}

/// A delegate that is used by the [Router] widget to manage navigation.
class RoutemasterDelegate extends RouterDelegate<RouteData>
    with ChangeNotifier {
  /// Specifies how the top-level [Navigator] transitions between routes.
  ///
  /// If this isn't provided, a [DefaultTransitionDelegate] is used.
  final TransitionDelegate? transitionDelegate;

  /// A function that returns a map of routes, to create pages from paths.
  final RouteMap Function(BuildContext context) routesBuilder;

  /// A list of observers for the router, and nested [Navigator] widgets.
  final List<RoutemasterObserver> observers;

  /// A function that returns the top-level navigator widgets. Normally this
  /// function would return a [PageStackNavigator].
  final Widget Function(
    BuildContext context,
    PageStack stack,
  )? navigatorBuilder;

  _RoutemasterState _state = _RoutemasterState();
  bool _isBuilding = false;
  bool _isDisposed = false;
  late BuildContext _context;

  /// Initializes the delegate.
  ///
  /// This uses a default [PageStackNavigator], to supply your own
  /// use [RoutemasterDelegate.builder].
  RoutemasterDelegate({
    required this.routesBuilder,
    this.transitionDelegate,
    this.observers = const [],
  }) : navigatorBuilder = null {
    _state.routemaster._delegate = this;
  }

  /// Initializes the delegate with a custom [PageStackNavigator] builder via
  /// [navigatorBuilder]. For instance, if you wanted to add a observer to just
  /// the top-level navigator.
  RoutemasterDelegate.builder({
    required this.routesBuilder,
    required this.navigatorBuilder,
    this.observers = const [],
  }) : transitionDelegate = null {
    _state.routemaster._delegate = this;
  }

  /// Disposes the delegate. The delegate must not be used once this method has
  /// been called.
  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  /// Called by the [Router] when the [Router.backButtonDispatcher] reports that
  /// the operating system is requesting that the current route be popped.
  @override
  Future<bool> popRoute() async {
    assert(!_isDisposed);
    return pop();
  }

  /// Attempts to pops the top-level route. Returns `true` if a route was
  /// successfully popped, otherwise `false`.
  ///
  /// An optional value can be passed to the previous route via the [result]
  /// parameter.
  @optionalTypeArgs
  Future<bool> pop<T extends Object?>([T? result]) async {
    assert(!_isDisposed);

    final popResult = await _state.stack.maybePop<T>(result);
    if (popResult) {
      _markNeedsUpdate();
    }
    return popResult;
  }

  /// Replaces the current route with [path]. On the web, this prevents the user
  /// returning to the previous route via the back button.
  ///
  ///   * [path] - an absolute or relative path.
  ///
  ///   * [queryParameters] - an optional map of parameters to be passed to the
  ///     created page.
  ///
  void replace(String path, {Map<String, String>? queryParameters}) {
    assert(!_isDisposed);

    // Otherwise we do a convoluted dance which uses a custom UrlStrategy that
    // supports replacing the URL.
    _navigate(
      uri: PathParser.getAbsolutePath(
        basePath: currentConfiguration!.fullPath,
        path: path,
        queryParameters: queryParameters,
      ),
      queryParameters: queryParameters,
      isReplacement: true,
    );
  }

  /// Pushes [path] into the navigation tree.
  ///
  ///   * [path] - an absolute or relative path.
  ///
  ///   * [queryParameters] - an optional map of parameters to be passed to the
  ///     created page.
  ///
  @optionalTypeArgs
  NavigationResult<T> push<T extends Object?>(String path,
      {Map<String, String>? queryParameters}) {
    assert(!_isDisposed);

    final result = NavigationResult<T>._();
    _navigate(
      uri: PathParser.getAbsolutePath(
        basePath: currentConfiguration!.fullPath,
        path: path,
        queryParameters: queryParameters,
      ),
      queryParameters: queryParameters,
      isReplacement: false,
      navigationResult: result,
    );
    return result;
  }

  /// Marks the router as needing an update, for instance of the current path
  /// has changed.
  void _markNeedsUpdate() {
    assert(!_isDisposed);

    _updateCurrentConfiguration();

    if (!_isBuilding) {
      notifyListeners();
    }
  }

  @override
  Widget build(BuildContext context) {
    assert(!_isDisposed);

    _context = context;

    return _RoutemasterStateTracker(
      delegate: this,
      builder: (context) {
        return _RoutemasterWidget(
          routemaster: _state.routemaster,
          routeData: currentConfiguration!,
          child: navigatorBuilder != null
              ? navigatorBuilder!(context, _state.stack)
              : PageStackNavigator(
                  stack: _state.stack,
                  transitionDelegate: transitionDelegate ??
                      const DefaultTransitionDelegate<dynamic>(),
                ),
        );
      },
    );
  }

  // Returns a [RouteData] that matches the current route state.
  // This is used to update a browser's current URL.
  @override
  RouteData? get currentConfiguration {
    assert(!_isDisposed);

    return _state.currentConfiguration;
  }

  /// Reports the current path to the Flutter routing system, and any observers.
  void _updateCurrentConfiguration({bool isReplacement = false}) {
    final currentPages = _state.stack._getCurrentPages();

    if (currentPages.isNotEmpty) {
      final pageWrapper = currentPages.last;
      final routeData = pageWrapper.routeData;

      void _update() {
        if (_state.currentConfiguration!.fullPath != routeData.fullPath) {
          _state.currentConfiguration = routeData;

          _markNeedsUpdate();

          for (final observer in observers) {
            observer.didChangeRoute(routeData, pageWrapper._getOrCreatePage());
          }
        }
      }

      if (kIsWeb && isReplacement && !_isBuilding) {
        // Update without the router changing the URL or adding a history entry
        Router.neglect(_context, _update); // coverage:ignore-line

        // Set the URL directly
        SystemNav.replaceUrl(routeData); // coverage:ignore-line
      } else {
        _update();
      }
    }
  }

  // Called when a new URL is set. The RouteInformationParser will parse the
  // URL, and return a new [RouteData], that gets passed this this method.
  //
  // This method then modifies the state based on that information.
  @override
  Future<void> setNewRoutePath(RouteData routeData) {
    assert(!_isDisposed);

    push(routeData.fullPath);
    return SynchronousFuture(null);
  }

  @override
  Future<void> setInitialRoutePath(RouteData configuration) {
    assert(!_isDisposed);

    _state.currentConfiguration = configuration;
    return SynchronousFuture(null);
  }

  void _initRouter(BuildContext context) {
    final routerNeedsBuilding = _state.routeMap == null;

    if (routerNeedsBuilding) {
      _state.routeMap = _buildRoutes(context);

      final pending = _state.pendingNavigation;
      if (pending != null) {
        // Process pending navigation after rebuild
        _navigate(
          uri: pending.uri,
          isReplacement: pending.isReplacement,
          navigationResult: pending.result,
          useCurrentState: false,
        );
      } else {
        _navigate(
          uri: currentConfiguration?._uri ?? Uri(path: '/'),
          isReplacement: false,
          useCurrentState: false,
        );
      }
    }
  }

  void _rebuildRouter(BuildContext context) {
    _state.routeMap = null;

    _isBuilding = true;
    _initRouter(context);
    _isBuilding = false;
  }

  void _navigate({
    required Uri uri,
    required bool isReplacement,
    NavigationResult? navigationResult,
    Map<String, String>? queryParameters,
    bool useCurrentState = true,
    bool isRetry = false,
  }) {
    _state.pendingNavigation = null;
    final request = _RouteRequest(
      uri: uri,
      isReplacement: isReplacement,
      result: navigationResult,
    );

    var pages = _createAllPageWrappers(
      currentRoutes:
          useCurrentState ? _state.stack._getCurrentPages().toList() : null,
      request: request,
    );

    if (pages == null) {
      final noCurrentPages = _state.stack._getCurrentPages().isEmpty;

      // No page found from router
      if (isRetry || noCurrentPages) {
        // Either we're retrying after giving the routing map a chance to
        // rebuild, or we don't have a current stack of pages so we *have* to
        // build immediately.
        pages = _onUnknownRoute(request);
      } else {
        // No page has been found, but we don't call onUnknownRoute immediately.
        // Instead we schedule a new navigation for after this frame. This is
        // for cases where the user has updated the route map (e.g. by changing
        // the app state) and called .push() within the same frame.
        _state.pendingNavigation = request;

        if (!_isBuilding) {
          // Schedule rebuild if we're not in build phase
          notifyListeners();
        }

        WidgetsBinding.instance!.addPostFrameCallback((timeStamp) {
          if (_state.pendingNavigation != null) {
            // Retry navigation
            _navigate(
              uri: uri,
              isReplacement: isReplacement,
              useCurrentState: useCurrentState,
              navigationResult: navigationResult,
              queryParameters: queryParameters,
              isRetry: true,
            );
          }
        });

        return;
      }
    }

    assert(pages.isNotEmpty);

    _state.stack._pageWrappers = pages;

    final pathIsSame =
        _state.currentConfiguration!.fullPath == pages.last.routeData.fullPath;

    _updateCurrentConfiguration(
      isReplacement: pathIsSame || isReplacement,
    );
  }

  /// Called when dependencies of the [routesBuilder] changed.
  ///
  /// This triggers a full rebuild of the routes.
  void _didChangeDependencies(BuildContext context) {
    if (currentConfiguration == null) {
      return;
    }

    // Reset state
    _rebuildRouter(context);

    // Already building; schedule rebuild for next frame
    WidgetsBinding.instance?.addPostFrameCallback((_) {
      _markNeedsUpdate();
    });
  }

  /// The main Routemaster algorithm that turns a route request into a list of
  /// pages. It attempts to reuse current pages from [currentRoutes] if they
  /// exist.
  List<PageWrapper>? _createAllPageWrappers({
    required _RouteRequest request,
    List<PageWrapper>? currentRoutes,
    List<String>? redirects,
  }) {
    final requestedPath = request.uri.toString();
    final routerResult = _getAllRouterResults(requestedPath);

    if (routerResult == null || routerResult.isEmpty) {
      return null;
    }

    var result = <PageWrapper>[];
    var i = 0;

    // Loop through routes in reverse order
    for (final routerData in routerResult.reversed) {
      final isLastRoute = i++ == 0;

      // Look the route up in the routing map
      final routeData = RouteData.fromRouterResult(
        routerData,
        // Only the last route gets query parameters
        isLastRoute ? request.uri : Uri(path: routerData.pathSegment),
        isReplacement: request.isReplacement,
      );

      // Get a page wrapper object for the current route
      final current = isLastRoute
          ? _createPageWrapper(
              routeRequest: request,
              page: routerData.builder(routeData),
              routeData: routeData,
            )
          : _getOrCreatePageWrapper(
              routeRequest: request,
              routeData: routeData,
              currentRoutes: currentRoutes,
              routerResult: routerData,
            );

      if (current is _PageWrapperResult) {
        final page = current.pageWrapper;

        if (isLastRoute) {
          page.result = request.result;
        }

        assert(page._routeData != null);
        assert(page._page != null);

        if (result.isNotEmpty && page.maybeSetChildPages(result)) {
          result = [page];
        } else {
          result.insert(0, page);
        }
      }

      if (!isLastRoute) {
        // We only follow redirects and not found for the last route
        continue;
      }

      if (current is _NotFoundResult) {
        return _onUnknownRoute(request);
      }

      if (current is _RedirectResult) {
        if (kDebugMode) {
          redirects = _debugCheckRedirectLoop(redirects, requestedPath);
        }

        return _createAllPageWrappers(
          currentRoutes: currentRoutes,
          redirects: redirects,
          request: _RouteRequest(
            uri: Uri.parse(current.redirectPath),
            isReplacement: request.isReplacement,
          ),
        );
      }
    }

    assert(result.isNotEmpty, "_createAllStates can't return empty list");

    return result;
  }

  /// Gets a list of results from the router. If a result can't be found, the
  /// router is rebuilt and the request retried. This is for cases where some
  /// state has updated but the map hasn't yet been rebuilt.
  List<RouterResult>? _getAllRouterResults(String requestedPath) {
    return _state.routeMap!.getAll(requestedPath);
  }

  RouteMap _buildRoutes(BuildContext context) {
    assert(
      context.owner!.debugBuilding,
      'Tried to call route builder outside of build phase',
    );

    return routesBuilder(context);
  }

  /// If there's a current route matching the path in the tree, return it.
  /// Otherwise create a new one. This could possibly be made more efficient
  /// By using a map rather than iterating over all currentRoutes.
  _PageResult _getOrCreatePageWrapper({
    required _RouteRequest routeRequest,
    required RouteData routeData,
    required List<PageWrapper>? currentRoutes,
    required RouterResult routerResult,
  }) {
    if (currentRoutes != null) {
      final currentState = currentRoutes.firstWhereOrNull(
        ((element) => element.routeData.path == routeData.path),
      );

      if (currentState != null) {
        return _PageWrapperResult(currentState);
      }
    }

    // No current route, create a new one
    return _createPageWrapper(
      routeRequest: routeRequest,
      page: routerResult.builder(routeData),
      routeData: routeData,
    );
  }

  /// Called by tab pages to lazily generate their initial routes
  PageWrapper _getPageForTab(_RouteRequest routeRequest) {
    final requestedPath = routeRequest.uri.toString();
    final routerResult = _state.routeMap!.get(requestedPath);
    if (routerResult != null) {
      final routeData = RouteData.fromRouterResult(
        routerResult,
        Uri.parse(requestedPath),
        isReplacement: routeRequest.isReplacement,
      );

      final wrapper = _createPageWrapper(
        routeRequest: routeRequest,
        page: routerResult.builder(routeData),
        routeData: routeData,
      );

      if (wrapper is _PageWrapperResult) {
        return wrapper.pageWrapper;
      }

      if (wrapper is _RedirectResult) {
        return _getPageForTab(
          _RouteRequest(
            uri: Uri.parse(wrapper.redirectPath),
            isReplacement: routeRequest.isReplacement,
          ),
        );
      }
    }

    return _TabNotFoundPage(routeRequest.uri);
  }

  _PageResult _createPageWrapper({
    required _RouteRequest routeRequest,
    required Page page,
    required RouteData routeData,
  }) {
    while (page is Guard) {
      if (!page.canNavigate(routeData, _context)) {
        if (page.onNavigationFailed == null) {
          return _NotFoundResult();
        }

        final result = page.onNavigationFailed!(routeData, _context);
        return _createPageWrapper(
          routeRequest: routeRequest,
          page: result,
          routeData: routeData,
        );
      }

      page = page.builder();
    }

    if (page is NotFound) {
      return _NotFoundResult();
    }

    if (page is Redirect) {
      return _RedirectResult(page.redirectPath);
    }

    if (page is StatefulPage) {
      final state = page.createState();

      assert(
        state._debugTypesAreRight(page),
        '${page.runtimeType}.createState must return a subtype of PageState<${page.runtimeType}>, but it returned ${state.runtimeType}.',
      );

      state._page = page;
      state._routemaster = _state.routemaster;
      state._routeData = routeData;
      state.initState();

      return _PageWrapperResult(state);
    }

    // Page is just a standard Flutter page, create a wrapper for it
    return _PageWrapperResult(
      PageWrapper.fromPage(routeData: routeData, page: page),
    );
  }

  List<PageWrapper> _onUnknownRoute(_RouteRequest routeRequest) {
    final requestedPath = routeRequest.uri;
    final result = _state.routeMap!.onUnknownRoute(requestedPath.toString());

    if (result is Redirect) {
      final redirectResult = _createAllPageWrappers(
        request: _RouteRequest(
          uri: Uri.parse(result.redirectPath),
          isReplacement: routeRequest.isReplacement,
        ),
      );

      if (redirectResult != null) {
        return redirectResult;
      }
    }

    // Return 404 page
    final routeData = RouteData.fromUri(
      requestedPath,
      isReplacement: routeRequest.isReplacement,
    );
    return [PageWrapper.fromPage(routeData: routeData, page: result)];
  }

  List<String> _debugCheckRedirectLoop(
      List<String>? redirects, String requestedPath) {
    if (redirects == null) {
      return [requestedPath];
    }

    if (redirects.contains(requestedPath)) {
      redirects.add(requestedPath);
      throw RedirectLoopError(redirects);
    }
    redirects.add(requestedPath);

    return redirects;
  }

  void _didPush(Route route) {
    final page = route.settings;
    final current = _state.stack
        ._getCurrentPages()
        .firstWhereOrNull((e) => e._getOrCreatePage() == page);

    final completer = current?.result?._routeCompleter;
    if (completer != null && !completer.isCompleted) {
      completer.complete(route);
    }
  }
}

/// A union type for results from the page map.
@immutable
abstract class _PageResult {}

class _PageWrapperResult extends _PageResult {
  final PageWrapper pageWrapper;

  _PageWrapperResult(this.pageWrapper);
}

class _NotFoundResult extends _PageResult {}

class _RedirectResult extends _PageResult {
  final String redirectPath;

  _RedirectResult(this.redirectPath);
}

class _PushObserver extends NavigatorObserver {
  final Routemaster routemaster;

  _PushObserver(this.routemaster);

  @override
  void didPush(Route route, Route? previousRoute) {
    routemaster._delegate._didPush(route);
  }
}

/// Used internally so descendent widgets can use `Routemaster.of(context)`.
class _RoutemasterWidget extends InheritedWidget {
  final Routemaster routemaster;
  final RouteData routeData;

  const _RoutemasterWidget({
    required Widget child,
    required this.routemaster,
    required this.routeData,
  }) : super(child: child);

  @override
  bool updateShouldNotify(covariant _RoutemasterWidget oldWidget) {
    return oldWidget.routeData != routeData;
  }
}

/// Maintains the router's state so [RoutemasterDelegate] can be replaced but
/// still maintain its state.
class _RoutemasterState {
  final routemaster = Routemaster._();
  final stack = PageStack();
  RouteMap? routeMap;
  RouteData? currentConfiguration;
  _RouteRequest? pendingNavigation;

  late _PushObserver pushObserver = _PushObserver(routemaster);
}

class _RoutemasterStateTracker extends StatefulWidget {
  final RoutemasterDelegate delegate;
  final Widget Function(BuildContext context) builder;

  const _RoutemasterStateTracker({
    required this.delegate,
    required this.builder,
  });

  @override
  _RoutemasterStateTrackerState createState() {
    return _RoutemasterStateTrackerState();
  }
}

class _RoutemasterStateTrackerState extends State<_RoutemasterStateTracker> {
  @override
  Widget build(BuildContext context) {
    return widget.builder(context);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    widget.delegate._didChangeDependencies(context);
  }

  @override
  void didUpdateWidget(_RoutemasterStateTracker oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldDelegate = oldWidget.delegate;
    final newDelegate = widget.delegate;

    // Check if delegate has been recreated
    if (oldDelegate != newDelegate) {
      // Update new delegate's state from old delegate's state
      newDelegate._state = oldDelegate._state;
      newDelegate._state.routemaster._delegate = newDelegate;

      newDelegate._rebuildRouter(context);

      WidgetsBinding.instance!.addPostFrameCallback((_) {
        // Dispose after this frame to allow child widgets to unsubscribe
        oldDelegate.dispose();
      });
    }
  }
}

/// Thrown when the router gets in an endless redirect loop due to a
/// misconfigured routing map.
@immutable
class RedirectLoopError extends Error {
  /// A list of paths in the redirect loop.
  final List<String> redirects;

  /// Initializes an error that the router is in an endless redirect loop.
  RedirectLoopError(this.redirects);

  @override
  String toString() {
    return 'Routemaster is stuck in an endless redirect loop:\n\n' +
        redirects
            .take(redirects.length - 1)
            .mapIndexed((i, path1) =>
                "  * '$path1' redirected to '${redirects[i + 1]}'")
            .join('\n') +
        '\n\nThis is an error in your routing map.';
  }
}

class _RouteRequest {
  final Uri uri;
  final bool isReplacement;
  final NavigationResult? result;

  _RouteRequest({
    required this.uri,
    this.isReplacement = false,
    this.result,
  });
}

/// Provides a [Navigator] that shows pages from a [PageStack].
///
/// This widget listens to that stack, and updates the navigator when the pages
/// change.
class PageStackNavigator extends StatefulWidget {
  /// The stack of pages to show in the [Navigator].
  final PageStack stack;
  final GlobalKey<NavigatorState>? globalKey;

  /// A delegate that decides how pages are animated when they're added or
  /// removed from the [Navigator].
  final TransitionDelegate transitionDelegate;

  /// A list of [NavigatorObserver] that will be passed to the [Navigator].
  final List<NavigatorObserver> observers;

  /// Provides a [Navigator] that shows pages from a [PageStack].
  const PageStackNavigator({
    Key? key,
    this.globalKey,
    required this.stack,
    this.transitionDelegate = const DefaultTransitionDelegate<dynamic>(),
    this.observers = const [],
  }) : super(key: key);

  @override
  PageStackNavigatorState createState() => PageStackNavigatorState();

  /// Retrieves the nearest [PageStackNavigatorState] ancestor.
  static PageStackNavigatorState of(BuildContext context) {
    final state = context.findAncestorStateOfType<PageStackNavigatorState>();
    assert(state != null, "Couldn't find a StackNavigatorState");
    return state!;
  }
}

/// The state for a [PageStackNavigator]. Watches for changes in the stack
/// and rebuilds the [Navigator] when required.
class PageStackNavigatorState extends State<PageStackNavigator> {
  late _StackNavigator _widget;
  late Routemaster _routemaster;

  /// The state for a [PageStackNavigator]. Watches for changes in the stack
  /// and rebuilds the [Navigator] when required.
  PageStackNavigatorState();

  @override
  void initState() {
    super.initState();

    _didUpdateStack(null, widget.stack);
    _updateNavigator();
  }

  @override
  void didUpdateWidget(PageStackNavigator oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.stack != widget.stack) {
      _didUpdateStack(oldWidget.stack, widget.stack);
      _updateNavigator();
    }
  }

  void _didUpdateStack(PageStack? oldStack, PageStack newStack) {
    if (oldStack != null) {
      oldStack.removeListener(_onStackChanged);
    }

    newStack.addListener(_onStackChanged);
  }

  @override
  void dispose() {
    widget.stack.removeListener(_onStackChanged);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _routemaster = Routemaster.of(context);
  }

  void _onStackChanged() {
    setState(() {
      _updateNavigator();
    });
  }

  void _updateDelegate() {
    _routemaster._delegate._markNeedsUpdate();
  }

  void _updateNavigator() {
    _widget = _StackNavigator(
      key: widget.globalKey,
      stack: widget.stack,
      onPopPage: (route, dynamic result) {
        final didPop = widget.stack.onPopPage(route, result);
        if (didPop) {
          _updateDelegate();
        }
        return didPop;
      },
      transitionDelegate: widget.transitionDelegate,
      pages: widget.stack.createPages(),
      observers: [
        _RelayingNavigatorObserver(
          () sync* {
            yield* widget.observers;
            yield* _routemaster._delegate.observers;
            yield _routemaster._delegate._state.pushObserver;
          },
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return _widget;
  }

  /// Retrieves the routing data for the given page.
  RouteData? routeDataFor(Page page) {
    return widget.stack._routeMap[page];
  }
}

/// A subclass of [Navigator] that attaches itself to a [PageStack], so that
/// the stack can use [Navigator.maybePop].
///
/// This is to support popping non-[Page] routes.
class _StackNavigator extends Navigator {
  final PageStack stack;

  const _StackNavigator({
    required this.stack,
    Key? key,
    PopPageCallback? onPopPage,
    TransitionDelegate transitionDelegate =
        const DefaultTransitionDelegate<dynamic>(),
    List<Page> pages = const <Page<dynamic>>[],
    List<NavigatorObserver> observers = const <NavigatorObserver>[],
  }) : super(
          key: key,
          onPopPage: onPopPage,
          transitionDelegate: transitionDelegate,
          pages: pages,
          observers: observers,
        );

  @override
  NavigatorState createState() {
    return _StackNavigatorState();
  }
}

class _StackNavigatorState extends NavigatorState {
  @override
  void initState() {
    super.initState();
    (widget as _StackNavigator).stack._attachedNavigator = this;
  }

  @override
  void dispose() {
    (widget as _StackNavigator).stack._attachedNavigator = null;
    super.dispose();
  }
}
