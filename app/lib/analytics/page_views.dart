import 'package:flutter/widgets.dart';

import 'vercel_stub.dart' if (dart.library.js_interop) 'vercel_web.dart' as vercel;

/// Reports in-app page changes to Vercel Web Analytics (web only; a no-op elsewhere).
///
/// The Vercel script counts the first page load itself and watches `history.pushState`, but
/// Flutter updates the URL with `replaceState`, so every page after the first is reported here.
class PageViewObserver extends NavigatorObserver {
  String? _last = vercel.currentPath();

  void _report(Route<dynamic>? route) {
    final path = route?.settings.name;
    // Unnamed routes (bottom sheets, the poster viewer) aren't pages of their own.
    if (path == null || path == _last) return;
    _last = path;
    vercel.pageview(path: path, route: _routePattern(path));
  }

  /// Groups pages in the dashboard: /movie/spidermanbrandnewday → /movie/[film].
  static String _routePattern(String path) => switch (Uri.parse(path).pathSegments) {
    ['movie', _] => '/movie/[film]',
    ['cinema', _] => '/cinema/[id]',
    _ => path,
  };

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) => _report(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) => _report(previousRoute);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) => _report(newRoute);
}
