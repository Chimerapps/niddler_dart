// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:dart_service_announcement/dart_service_announcement.dart';
import 'package:niddler_dart/niddler_dart.dart';
import 'package:niddler_dart/src/platform/debugger/niddler_debugger.dart';
import 'package:niddler_dart/src/util/uuid.dart';
import 'package:synchronized/synchronized.dart';

/// Listener for new niddler client connections
// ignore: one_member_abstracts
abstract class NiddlerServerConnectionListener {
  /// Called when a new connection is made AND authenticated if required
  void onNewConnection(NiddlerConnection connection);
}

/// Server component of niddler. Starts a websocket server that is responsible for communicating with clients
class NiddlerServer extends ToolingServer {
  HttpServer? _server;
  final int _port;
  final _lock = Lock();
  final List<NiddlerConnection> _connections = [];
  NiddlerDebugger _debugger = NiddlerDebuggerImpl();
  final String tag = SimpleUUID.uuid().substring(0, 6);

  @override
  int get protocolVersion => 4; //Debugging support

  @override
  int get port => _server?.port ?? -1;

  NiddlerDebugger get debugger => _debugger;

  late final NiddlerServerConnectionListener connectionListener;

  NiddlerServer(this._port);

  /// Starts the server
  Future<void> start({required bool waitForDebugger}) async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port)
      ..transform(WebSocketTransformer()).listen(_onNewConnection);
    niddlerDebugPrint(
        'Niddler Server running on $port [$tag][waitingForDebugger=$waitForDebugger]');
  }

  /// Stops the server
  Future<void> shutdown() async {
    final server = _server;
    _server = null;
    if (server != null) {
      await server.close(force: true);
    }
    await _lock.synchronized(() async {
      _connections.forEach((socket) => socket.close());
    });
  }

  /// Sends this message to all connected (and authenticated) clients
  void sendToAll(String message) {
    _lock.synchronized(() async {
      _connections.forEach((socket) => socket.send(message));
    });
  }

  void _onNewConnection(WebSocket socket) {
    final connection = NiddlerConnection(socket, connectionListener, this);
    _lock.synchronized(() async {
      _connections.add(connection);
      socket.listen(connection.onMessage,
          onDone: () => _onSocketClosed(connection),
          onError: (_) => _onSocketClosed(connection),
          cancelOnError: true);
    });

    connection.onAuthSuccess();
  }

  void _onSocketClosed(NiddlerConnection socket) {
    final debugger = _debugger;
    if (debugger is NiddlerDebuggerImpl) debugger.onConnectionClosed(socket);
    _lock.synchronized(() async {
      _connections.remove(socket);
    });
  }

  void overrideDebugger(NiddlerDebugger debugger) {
    _debugger = debugger;
  }
}

/// Represents a client connection (over websockets). Connections will not send data until they have authenticated (when required)
class NiddlerConnection {
  static const _MESSAGE_START_DEBUG = 'startDebug';
  static const _MESSAGE_END_DEBUG = 'endDebug';
  static const _MESSAGE_DEBUG_CONTROL = 'controlDebug';

  final WebSocket _socket;
  final NiddlerServer _server;
  final NiddlerServerConnectionListener _connectionListener;
  bool _authenticated = false;

  NiddlerConnection(this._socket, this._connectionListener, this._server) {
    _socket.add('{"type":"protocol","protocolVersion":4}');
  }

  void send(String message) {
    if (_authenticated) _socket.add(message);
  }

  void authNotRequired() {
    _authenticated = true;
    _connectionListener.onNewConnection(this);
  }

  void onAuthSuccess() {
    _authenticated = true;
    _connectionListener.onNewConnection(this);
  }

  void onMessage(data) {
    final parsedJson = jsonDecode(data);
    final type = parsedJson['type'];
    switch (type) {
      case _MESSAGE_START_DEBUG:
        if (_authenticated) {
          _asImpl(_server._debugger)?.onDebuggerAttached(this);
        }
        break;
      case _MESSAGE_END_DEBUG:
        _asImpl(_server._debugger)?.onDebuggerConnectionClosed();
        break;
      case _MESSAGE_DEBUG_CONTROL:
        _asImpl(_server._debugger)?.onControlMessage(parsedJson, this);
        break;
    }
  }

  void close() {
    _socket.close();
  }

  NiddlerDebuggerImpl? _asImpl(NiddlerDebugger debugger) =>
      debugger is NiddlerDebuggerImpl ? debugger : null;
}
