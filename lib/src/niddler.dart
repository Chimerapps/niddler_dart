// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:convert';

import 'niddler_message.dart';
import 'niddler_message_cache.dart';
import 'niddler_server.dart';
import 'niddler_server_announcement_manager.dart';

typedef NiddlerDebugPrintCallback = void Function(String message, {int wrapWidth});

NiddlerDebugPrintCallback niddlerDebugPrint = _niddlerDartDebugPrint;

_niddlerDartDebugPrint(String message, {int wrapWidth}) {
  print(message);
}

/// Heart of the consumer interface of niddler. Use this class to log custom requests and responses and to
/// start and stop the server
class Niddler {
  final _NiddlerImplementation _implementation;

  Niddler._(int maxCacheSize, int port, String password, String bundleId, NiddlerServerInfo serverInfo)
      : _implementation = _NiddlerImplementation(maxCacheSize, port, password, bundleId, serverInfo);

  /// Supply a new request to niddler
  void logRequest(NiddlerRequest request) {
    request.toJsonString().then(_implementation.send);
  }

  /// Supply a new response to niddler
  void logResponse(NiddlerResponse response) {
    response.toJsonString().then(_implementation.send);
  }

  /// Adds the URL pattern to the blacklist. Items in the blacklist will not be reported or retained in the memory cache. Matching happens on the request URL
  void addBlacklist(RegExp regex) {
    _implementation.addBlacklist(regex);
  }

  /// Checks if the given URL matches the current configured blacklist
  bool isBlacklisted(String url) {
    return _implementation.isBlacklisted(url);
  }

  /// Starts the server
  Future<bool> start() async {
    return _implementation.start();
  }

  /// Stops the server
  Future<void> stop() async {
    return _implementation.stop();
  }
}

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
    return Niddler._(maxCacheSize, port, password, bundleId, serverInfo);
  }
}

class _NiddlerImplementation implements NiddlerServerConnectionListener {
  final NiddlerMessageCache _messagesCache;
  final NiddlerServer _server;
  final NiddlerServerInfo _serverInfo;
  final List<RegExp> _blacklist = [];
  final int protocolVersion = 3;
  bool _started = false;
  NiddlerServerAnnouncementManager _announcementManager;

  _NiddlerImplementation(int maxCacheSize, [int port = 0, String password, String bundleId, this._serverInfo])
      : _messagesCache = NiddlerMessageCache(maxCacheSize),
        _server = NiddlerServer(port, password, bundleId) {
    _server.connectionListener = this;
    _announcementManager = NiddlerServerAnnouncementManager(bundleId, (_serverInfo == null) ? null : _serverInfo.icon, _server);
  }

  void send(String message) {
    _messagesCache.put(message);
    _server.sendToAll(message);
  }

  Future<bool> start() async {
    _started = true;
    await _server.start();
    await _announcementManager.start();
    return true;
  }

  Future<void> stop() async {
    _started = false;
    await _announcementManager.stop();
    await _server.shutdown();
  }

  void addBlacklist(RegExp item) {
    _blacklist.add(item);
    if (_started && protocolVersion > 3) {
      _server.sendToAll(_buildBlacklistMessage());
    }
  }

  bool isBlacklisted(String url) {
    return _blacklist.any((item) => item.hasMatch(url));
  }

  @override
  Future<void> onNewConnection(NiddlerConnection connection) async {
    if (_serverInfo != null) {
      final data = {'type': 'serverInfo', 'serverName': _serverInfo.name, 'serverDescription': _serverInfo.description, 'icon': _serverInfo.icon};
      connection.send(jsonEncode(data));
    }
    if (_blacklist.isNotEmpty && protocolVersion > 3) {
      connection.send(_buildBlacklistMessage());
    }

    final allMessages = await _messagesCache.allMessages();
    allMessages.forEach(connection.send);
  }

  String _buildBlacklistMessage() {
    final Map<String, dynamic> data = {'type': 'staticBlacklist', 'id': '<dart>', 'name': '<dart>'}; // ignore: omit_local_variable_types
    data['entries'] = _blacklist.map((regex) => {'pattern': regex.pattern, 'enabled': true}).toList();
    return jsonEncode(data);
  }
}

/// Encapsulates some information about the niddler server instance. This is cosmetic information for the client
class NiddlerServerInfo {
  /// The name to use for this server
  final String name;

  /// The description to use for this server
  final String description;

  /// The icon to use for this server, WIP
  final String icon;

  NiddlerServerInfo(this.name, this.description, {this.icon});
}
