// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'niddler_generic.dart';
import 'platform/niddler_empty.dart'
    if (dart.library.html) 'platform/niddler_noop.dart'
    if (dart.library.io) 'platform/io/niddler_io.dart';

/// Builder used to create niddler instances
/// Uses the following defaults:
///  - no password
///  - server port 0 (for automatic configuration)
///  - cache size 1MB
class NiddlerBuilder {
  /// The password to use to authenticate new clients (just authentication, no encryption). Leave empty to disable (default)
  String password;

  /// The bundle id of the application. Can be an iOS bundle id, android package name, ... Used to identify the application to the client
  String bundleId;

  /// The port to run the server on. Set to 0 to allow niddler to pick a free port (default). A log will be printed with the active port
  int port = 0;

  /// The cache size in bytes the internal niddler cache tries to limit itself to
  int maxCacheSize = 1024 * 1024;

  /// Some cosmetic information about the server for the client
  NiddlerServerInfo serverInfo;

  /// Create the niddler instance
  Niddler build() {
    return createNiddler(maxCacheSize, port, password, bundleId, serverInfo);
  }
}
