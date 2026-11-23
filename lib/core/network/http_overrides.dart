import 'dart:io';

// Sets a browser-friendly User-Agent for image loading from Wikimedia and similar.
class WikimediaFriendlyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.userAgent = 'Mozilla/5.0 (compatible; Flutter)';
    return client;
  }
}
