/// Where the backend publishes. Override with --dart-define=API_BASE=https://.../
const apiBase = String.fromEnvironment('API_BASE', defaultValue: 'https://etdvlpr.github.io/cinema/');

/// Resolves a path from schedules.json (e.g. "posters/alem/1-0.jpg") against [apiBase].
String assetUrl(String relativePath) => Uri.parse(apiBase).resolve(relativePath).toString();
