// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:pointycastle/digests/sha512.dart';
import 'package:synchronized/synchronized.dart';

import 'niddler_io.dart';

const _chars = 'abcdefghijklmnopqrstuvwxyz0123456789';

/// Listener for new niddler client connections
// ignore: one_member_abstracts
abstract class NiddlerServerConnectionListener {
  /// Called when a new connection is made AND authenticated if required
  void onNewConnection(NiddlerConnection connection);
}

/// Server component of niddler. Starts a websocket server that is responsible for communicating with clients
class NiddlerServer {
  HttpServer _server;
  final int _port;
  final String _bundleId;
  final String _password;
  final _lock = Lock();
  final List<NiddlerConnection> _connections = List();

  int get port => _server.port;
  NiddlerServerConnectionListener connectionListener;

  NiddlerServer(this._port, [this._bundleId, this._password]);

  /// Starts the server
  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, _port)
      ..transform(WebSocketTransformer()).listen(_onNewConnection);
    niddlerDebugPrint('Server running on ${_server.port}');
  }

  /// Stops the server
  Future<void> shutdown() async {
    await _server.close(force: true);
    _server = null;
  }

  /// Sends this message to all connected (and authenticated) clients
  void sendToAll(String message) {
    _lock.synchronized(() async {
      _connections.forEach((socket) => socket.send(message));
    });
  }

  void _onNewConnection(WebSocket socket) {
    final connection = NiddlerConnection(socket, connectionListener);
    _lock.synchronized(() async {
      _connections.add(connection);
      socket.listen(connection.onMessage,
          onDone: () => _onSocketClosed(connection),
          onError: (_) => _onSocketClosed(connection),
          cancelOnError: true);
    });

    if (_password != null && _bundleId != null) {
      connection.sendAuthRequest(_password, _bundleId);
    } else {
      connection.onAuthSuccess();
    }
  }

  void _onSocketClosed(NiddlerConnection socket) {
    _lock.synchronized(() async {
      _connections.remove(socket);
    });
  }
}

/// Represents a client connection (over websockets). Connections will not send data until they have authenticated (when required)
class NiddlerConnection {
  final WebSocket _socket;
  final NiddlerServerConnectionListener _connectionListener;
  bool _authenticated = false;
  String _currentAuthRequestData;
  String _currentPassword;

  NiddlerConnection(this._socket, this._connectionListener) {
    _socket.add('{"type":"protocol","protocolVersion":3}');
  }

  void sendAuthRequest(String password, String bundleId) {
    final authRequest = _generateAuthRequest();
    _currentAuthRequestData = authRequest;
    _currentPassword = password;
    final messageData = {
      'type': 'authRequest',
      'hash': authRequest,
      'package': bundleId
    };
    _socket.add(json.encode(messageData));
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
      case 'authReply':
        _handleAuthReply(parsedJson['hashKey']);
        break;
    }
  }

  void _handleAuthReply(String hashKey) {
    if (_currentPassword == null || hashKey == null) {
      _socket.close(1000);
      return;
    }
    final shaDigest = SHA512Digest();
    final base64Data = base64Encode(shaDigest
        .process(utf8.encode(_currentAuthRequestData + _currentPassword)));
    if (hashKey == base64Data) {
      onAuthSuccess();
    } else {
      _socket.close(1000, 'Bad auth');
    }
  }

  String _generateAuthRequest() {
    final rnd = Random(DateTime.now().millisecondsSinceEpoch);
    final buffer = StringBuffer();
    for (var i = 0; i < 512; i++) {
      buffer.writeCharCode(_chars.codeUnitAt(rnd.nextInt(_chars.length)));
    }
    return buffer.toString();
  }
}