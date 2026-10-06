import 'dart:js_interop';
import 'dart:js_interop_unsafe';

String? currentPath() => (globalContext['location'] as JSObject?)?['pathname']?.dartify() as String?;

/// `window.va` is defined by /_vercel/insights/script.js, which only exists on the Vercel deployment.
void pageview({required String path, required String route}) {
  final va = globalContext['va'];
  if (va == null || !va.isA<JSFunction>()) return;
  (va as JSFunction).callAsFunction(null, 'pageview'.toJS, {'path': path, 'route': route}.jsify());
}
