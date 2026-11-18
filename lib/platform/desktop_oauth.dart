// dart:io is not available on the web, so the web build gets a stub.
export 'desktop_oauth_stub.dart' if (dart.library.io) 'desktop_oauth_io.dart';
