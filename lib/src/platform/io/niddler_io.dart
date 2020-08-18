// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:niddler_dart/src/niddler_generic.dart';
import 'package:niddler_dart/src/niddler_message.dart';
import 'package:niddler_dart/src/niddler_message_cache.dart';
import 'package:niddler_dart/src/platform/io/niddler_dart.dart';
import 'package:niddler_dart/src/platform/io/niddler_server.dart';
import 'package:niddler_dart/src/platform/io/niddler_server_announcement_manager.dart';

Niddler createNiddler(
  int maxCacheSize,
  int port,
  String password,
  String bundleId,
  NiddlerServerInfo serverInfo,
  StackTraceSanitizer sanitizer, {
  bool includeStackTrace,
}) =>
    NiddlerImpl._(maxCacheSize, port, password, bundleId, serverInfo, sanitizer,
        includeStackTrace: includeStackTrace);

/// Heart of the consumer interface of niddler. Use this class to log custom requests and responses and to
/// start and stop the server
class NiddlerImpl implements Niddler {
  final _NiddlerImplementation _implementation;

  NiddlerImpl._(
    int maxCacheSize,
    int port,
    String password,
    String bundleId,
    NiddlerServerInfo serverInfo,
    StackTraceSanitizer sanitizer, {
    bool includeStackTrace,
  }) : _implementation = _NiddlerImplementation(
          maxCacheSize,
          port: port,
          password: password,
          bundleId: bundleId,
          serverInfo: serverInfo,
          stackTraceSanitizer: sanitizer,
          includeStackTraces: includeStackTrace,
        );

  /// Supply a new request to niddler
  @override
  void logRequest(NiddlerRequest request) {
    _jsonBody(request).then(logRequestJson);
  }

  /// Supply a new request to niddler, already transformed into json
  @override
  void logRequestJson(String request) {
    _implementation.send(request);
  }

  /// Supply a new response to niddler
  @override
  void logResponse(NiddlerResponse response) {
    _jsonBody(response).then(logResponseJson);
  }

  /// Supply a new response to niddler, already transformed into json
  @override
  void logResponseJson(String response) {
    _implementation.send(response);
  }

  /// Adds the URL pattern to the blacklist. Items in the blacklist will not be reported or retained in the memory cache. Matching happens on the request URL
  @override
  void addBlacklist(RegExp regex) {
    _implementation.addBlacklist(regex);
  }

  /// Checks if the given URL matches the current configured blacklist
  @override
  bool isBlacklisted(String url) {
    return _implementation.isBlacklisted(url);
  }

  /// Starts the server
  @override
  Future<bool> start({bool waitForDebugger = false}) async {
    return _implementation.start(waitForDebugger: waitForDebugger);
  }

  /// Stops the server
  @override
  Future<void> stop() async {
    return _implementation.stop();
  }

  /// Installs niddler on the process
  @override
  void install() {
    HttpOverrides.global = NiddlerHttpOverrides(
      this,
      _implementation.stackTraceSanitizer,
      includeStackTraces: _implementation.includeStackTraces,
    );
  }

  @override
  NiddlerDebugger get debugger => _implementation.debugger;
}

class _NiddlerImplementation implements NiddlerServerConnectionListener {
  final NiddlerMessageCache _messagesCache;
  final NiddlerServer _server;
  final NiddlerServerInfo serverInfo;
  final List<RegExp> _blacklist = [];
  final int protocolVersion = 3;
  final StackTraceSanitizer stackTraceSanitizer;
  final bool includeStackTraces;
  bool _started = false;
  NiddlerServerAnnouncementManager _announcementManager;

  _NiddlerImplementation(
    int maxCacheSize, {
    int port = 0,
    String password,
    String bundleId,
    this.serverInfo,
    this.stackTraceSanitizer,
    this.includeStackTraces,
  })  : _messagesCache = NiddlerMessageCache(maxCacheSize),
        _server = NiddlerServer(port, password, bundleId) {
    _server.connectionListener = this;
    _announcementManager = NiddlerServerAnnouncementManager(bundleId, _server);

    if (serverInfo?.icon != null) {
      _announcementManager.addExtension(IconExtension(serverInfo.icon));
    }
    _announcementManager.addExtension(TagExtension(_server.tag));
  }

  NiddlerDebugger get debugger => _server.debugger;

  void send(String message) {
    _messagesCache.put(message);
    _server.sendToAll(message);
  }

  Future<bool> start({bool waitForDebugger}) async {
    _started = true;
    await _server.start(waitForDebugger: waitForDebugger);
    await _announcementManager.start();
    if (waitForDebugger) {
      await _server.debugger.waitForConnection();
    }
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
    if (serverInfo != null) {
      final data = {
        'type': 'serverInfo',
        'serverName': serverInfo.name,
        'serverDescription': serverInfo.description,
        'icon': serverInfo.icon,
      };
      connection.send(jsonEncode(data));
    }
    if (_blacklist.isNotEmpty && protocolVersion > 3) {
      connection.send(_buildBlacklistMessage());
    }

    final allMessages = await _messagesCache.allMessages();
    allMessages.forEach(connection.send);
  }

  String _buildBlacklistMessage() {
    // ignore: omit_local_variable_types
    final Map<String, dynamic> data = {
      'type': 'staticBlacklist',
      'id': '<dart>',
      'name': '<dart>'
    }; // ignore: omit_local_variable_types
    data['entries'] = _blacklist
        .map((regex) => {'pattern': regex.pattern, 'enabled': true})
        .toList();
    return jsonEncode(data);
  }
}

class _IsolateData {
  final dynamic body;
  final SendPort dataPort;

  _IsolateData(this.body, this.dataPort);
}

void _encodeJson(_IsolateData body) {
  body.dataPort.send(body.body.toJsonString());
}

Future<String> _jsonBody(body) async {
  final resultPort = ReceivePort();
  final errorPort = ReceivePort();
  final isolate = await Isolate.spawn(
    _encodeJson,
    _IsolateData(body, resultPort.sendPort),
    errorsAreFatal: true,
    onExit: resultPort.sendPort,
    onError: errorPort.sendPort,
  );
  final result = Completer<String>();
  errorPort.listen((errorData) {
    assert(errorData is List<dynamic>);
    assert(errorData.length == 2);
    final exception = Exception(errorData[0]);
    final stack = StackTrace.fromString(errorData[1]);
    if (result.isCompleted) {
      Zone.current.handleUncaughtError(exception, stack);
    } else {
      result.completeError(exception, stack);
    }
  });
  resultPort.listen((resultData) {
    assert(resultData == null || resultData is String);
    if (!result.isCompleted) {
      result.complete(resultData);
    }
  });
  await result.future;
  resultPort.close();
  errorPort.close();
  isolate.kill();
  return result.future;
}
