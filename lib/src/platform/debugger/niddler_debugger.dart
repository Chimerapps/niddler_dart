import 'dart:async';
import 'dart:convert';

import 'package:niddler_dart/niddler_dart.dart';
import 'package:niddler_dart/src/platform/io/niddler_io.dart';
import 'package:niddler_dart/src/platform/io/niddler_server.dart';

class NiddlerDebuggerImpl implements NiddlerDebugger {
  static const _DEBUG_TYPE_KEY = 'controlType';
  static const _DEBUG_PAYLOAD = 'payload';
  static const _KEY_MESSAGE_ID = 'messageId';
  static const _MESSAGE_ACTIVATE = 'activate';
  static const _MESSAGE_DEACTIVATE = 'deactivate';
  static const _MESSAGE_DEBUG_REQUEST = 'debugRequest';
  static const _MESSAGE_ADD_REQUEST_OVERRIDE = 'addRequestOverride';
  static const _MESSAGE_DEBUG_REPLY = 'debugReply';
  static const _MESSAGE_ADD_RESPONSE = 'addResponse';

  _NiddlerDebuggerConfiguration _configuration;
  final _connectionCompleter = Completer<bool>();
  NiddlerConnection _currentConnection;

  NiddlerDebuggerImpl() {
    _configuration = _NiddlerDebuggerConfiguration(this);
  }

  @override
  bool get isActive => _configuration.isActive;

  @override
  Future<bool> waitForConnection() {
    return _connectionCompleter.future;
  }

  @override
  Future<DebugRequest> overrideRequest(NiddlerRequest request) {
    if (!isActive || _currentConnection == null) return Future.value(null);

    return _configuration.overrideRequest(request);
  }

  @override
  Future<DebugResponse> overrideResponse(
      NiddlerRequest request, NiddlerResponse response) {
    if (!isActive || _currentConnection == null) return Future.value(null);

    return _configuration.overrideResponse(request, response);
  }

  void onDebuggerAttached(NiddlerConnection niddlerConnection) {
    niddlerDebugPrint('Got a new debugger connection');
    onDebuggerConnectionClosed();
    _currentConnection = niddlerConnection;
  }

  void onDebuggerConnectionClosed() {
    if (_currentConnection != null) {
      niddlerDebugPrint('Closing old debugger connection');
    }
    _configuration.onConnectionLost();
    _currentConnection = null;
  }

  void onConnectionClosed(NiddlerConnection connection) {
    if (_currentConnection == connection) {
      onDebuggerConnectionClosed();
    }
  }

  void onControlMessage(parsedJson, NiddlerConnection niddlerConnection) {
    if (_currentConnection != niddlerConnection) {
      return;
    }
    _onDebuggerConfigurationMessage(
        parsedJson[_DEBUG_TYPE_KEY], parsedJson[_DEBUG_PAYLOAD], parsedJson);
  }

  void _onDebuggerConfigurationMessage(String messageType, body, envelope) {
    niddlerVerbosePrint('Got a debugger message: $messageType\n\t->$envelope');
    switch (messageType) {
      case _MESSAGE_ACTIVATE:
        _configuration.isActive = true;
        if (!_connectionCompleter.isCompleted) {
          _connectionCompleter.complete(true);
        }
        break;
      case _MESSAGE_DEACTIVATE:
        _configuration.isActive = false;
        break;
      case _MESSAGE_ADD_REQUEST_OVERRIDE:
        _configuration
            .addRequestOverrideAction(_DebugRequestOverrideAction(body));
        break;
      case _MESSAGE_ADD_RESPONSE:
        _configuration
            .addResponseOverrideAction(_DebugResponseOverrideAction(body));
        break;
      case _MESSAGE_DEBUG_REQUEST:
        _configuration.onDebugRequest(
            envelope[_KEY_MESSAGE_ID], _parseRequestOverride(body));
        break;
      case _MESSAGE_DEBUG_REPLY:
        _configuration.onDebugResponse(
            envelope[_KEY_MESSAGE_ID], _parseResponseOverride(body));
        break;
    }
  }

  Future<DebugRequest> sendHandleRequestOverride(NiddlerRequest request) {
    if (_currentConnection == null) return Future.value(null);

    return _configuration.sendHandleRequestOverride(
        request, _currentConnection);
  }

  Future<DebugResponse> sendHandleResponseOverride(
      NiddlerRequest request, NiddlerResponse response) {
    if (_currentConnection == null) return Future.value(null);

    return _configuration.sendHandleResponseOverride(
        request, response, _currentConnection);
  }

  DebugRequest _parseRequestOverride(body) {
    if (body == null) return null;
    return DebugRequest(
      url: body['url'],
      method: body['method'],
      headers: _parseHeaders(body['headers']),
      encodedBody: body['encodedBody'],
      bodyMimeType: body['bodyMimeType'],
    );
  }

  DebugResponse _parseResponseOverride(body) {
    if (body == null) return null;
    return DebugResponse(
      code: body['code'],
      message: body['message'],
      headers: _parseHeaders(body['headers']),
      encodedBody: body['encodedBody'],
      bodyMimeType: body['bodyMimeType'],
    );
  }

  Map<String, List<String>> _parseHeaders(body) {
    if (body == null) return null;

    // ignore: avoid_as
    final headersMap = body as Map<String, dynamic>;
    final finalHeaders = Map<String, List<String>>();
    headersMap.forEach((key, items) {
      // ignore: avoid_as
      finalHeaders[key] = (items as List).map((f) => f.toString()).toList();
    });
    return finalHeaders;
  }
}

class _NiddlerDebuggerConfiguration {
  final NiddlerDebuggerImpl _debugger;
  final _waitingRequests = Map<String, Completer<DebugRequest>>();
  final _waitingResponses = Map<String, Completer<DebugResponse>>();
  final _requestOverrides = List<_RequestOverrideAction>();
  final _responseOverrides = List<_ResponseOverrideAction>();

  bool isActive = false;

  _NiddlerDebuggerConfiguration(this._debugger);

  void onConnectionLost() {
    _waitingRequests.forEach((_, completer) => completer.complete(null));
    _waitingResponses.forEach((_, completer) => completer.complete(null));
    _waitingRequests.clear();
    _waitingResponses.clear();
    _requestOverrides.clear();
    _responseOverrides.clear();
  }

  Future<DebugRequest> sendHandleRequestOverride(
      NiddlerRequest request, NiddlerConnection connection) {
    final completer = Completer<DebugRequest>();
    _waitingRequests[request.messageId] = completer;

    //TODO isolate
    final jsonEnvelope = Map<String, dynamic>();
    jsonEnvelope['type'] = 'debugRequest';
    jsonEnvelope['request'] = request.toJson();

    final jsonMessage = json.encode(jsonEnvelope);

    connection.send(jsonMessage);

    return completer.future;
  }

  Future<DebugResponse> sendHandleResponseOverride(NiddlerRequest request,
      NiddlerResponse response, NiddlerConnection connection) {
    final completer = Completer<DebugResponse>();
    _waitingResponses[request.messageId] = completer;

    //TODO isolate
    final jsonEnvelope = Map<String, dynamic>();
    jsonEnvelope['type'] = 'debugRequest';
    jsonEnvelope['requestId'] = request.messageId;
    jsonEnvelope['response'] = response.toJson();

    final jsonMessage = json.encode(jsonEnvelope);

    connection.send(jsonMessage);

    return completer.future;
  }

  void addRequestOverrideAction(
      _DebugRequestOverrideAction debugRequestOverrideAction) {
    _requestOverrides.add(debugRequestOverrideAction);
  }

  void onDebugRequest(String messageId, DebugRequest debugRequest) {
    _waitingRequests.remove(messageId)?.complete(debugRequest);
  }

  Future<DebugRequest> overrideRequest(NiddlerRequest request) {
    Future<DebugRequest> result;
    _requestOverrides.forEach((handler) {
      if (result != null) return;
      final future = handler.handleRequest(request, _debugger);
      if (future != null) {
        result = future;
      }
    });
    return result ?? Future.value(null);
  }

  Future<DebugResponse> overrideResponse(
      NiddlerRequest request, NiddlerResponse response) {
    Future<DebugResponse> result;
    _responseOverrides.forEach((handler) {
      if (result != null) return;
      final future = handler.handleRequest(request, response, _debugger);
      if (future != null) {
        result = future;
      }
    });
    return result ?? Future.value(null);
  }

  void onDebugResponse(String messageId, DebugResponse debugResponse) {
    _waitingResponses.remove(messageId)?.complete(debugResponse);
  }

  void addResponseOverrideAction(
      _ResponseOverrideAction responseOverrideAction) {
    _responseOverrides.add(responseOverrideAction);
  }
}

class _DebugRequestOverrideAction extends _RequestOverrideAction {
  final RegExp _regex;
  final String _method;

  _DebugRequestOverrideAction(json)
      : _regex = RegExp(json['regex']),
        _method = json['matchMethod']?.toLowerCase(),
        super(json);

  @override
  Future<DebugRequest> handleRequest(
      NiddlerRequest request, NiddlerDebuggerImpl debugger) {
    if (!active) return Future.value(null);

    if (_regex != null && !_regex.hasMatch(request.url)) {
      return Future.value(null);
    }
    if (_method != null && _method != request.method?.toLowerCase()) {
      return Future.value(null);
    }

    return debugger.sendHandleRequestOverride(request);
  }
}

class _DebugResponseOverrideAction extends _ResponseOverrideAction {
  final RegExp _regex;
  final String _method;
  final int _responseCode;

  _DebugResponseOverrideAction(json)
      : _regex = RegExp(json['regex']),
        _method = json['matchMethod']?.toLowerCase(),
        _responseCode = json['responseCode'],
        super(json);

  @override
  Future<DebugResponse> handleRequest(NiddlerRequest request,
      NiddlerResponse response, NiddlerDebuggerImpl debugger) {
    if (!active) return Future.value(null);

    if (_regex != null && !_regex.hasMatch(request.url)) {
      return Future.value(null);
    }
    if (_method != null && _method != request.method?.toLowerCase()) {
      return Future.value(null);
    }
    if (_responseCode != null && _responseCode != response.statusCode) {
      return Future.value(null);
    }

    return debugger.sendHandleResponseOverride(request, response);
  }
}

abstract class _RequestOverrideAction extends _DebugAction {
  _RequestOverrideAction(json) : super(json);

  Future<DebugRequest> handleRequest(
      final NiddlerRequest request, final NiddlerDebuggerImpl debugger);
}

abstract class _ResponseOverrideAction extends _DebugAction {
  _ResponseOverrideAction(json) : super(json);

  Future<DebugResponse> handleRequest(final NiddlerRequest request,
      final NiddlerResponse response, final NiddlerDebuggerImpl debugger);
}

abstract class _DebugAction {
  final String id;
  final bool active;

  _DebugAction(json)
      : id = json['id'],
        active = json['active'];
}
