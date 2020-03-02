// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:niddler_dart/src/niddler_generic.dart';
import 'package:niddler_dart/src/niddler_message.dart';
import 'package:stack_trace/stack_trace.dart';
import 'package:uuid/uuid.dart';

class NiddlerHttpOverrides extends HttpOverrides {
  final Niddler _niddler;
  final StackTraceSanitizer _sanitizer;
  final bool includeStackTraces;

  NiddlerHttpOverrides(this._niddler, this._sanitizer, {this.includeStackTraces});

  @override
  HttpClient createHttpClient(SecurityContext context) {
    return _NiddlerHttpClient(
      super.createHttpClient(context) ?? HttpClient(context: context),
      _niddler,
      _sanitizer,
      includeStackTraces: includeStackTraces,
    );
  }
}

class _NiddlerHttpClient implements HttpClient {
  final HttpClient _delegate;
  final Niddler _niddler;
  final StackTraceSanitizer _sanitizer;
  final bool includeStackTraces;
  final NiddlerDebugger _debugger;

  @override
  bool get autoUncompress => _delegate.autoUncompress;

  @override
  set autoUncompress(bool value) => _delegate.autoUncompress = value;

  @override
  Duration get connectionTimeout => _delegate.connectionTimeout;

  @override
  set connectionTimeout(Duration value) => _delegate.connectionTimeout = value;

  @override
  Duration get idleTimeout => _delegate.idleTimeout;

  @override
  set idleTimeout(Duration value) => _delegate.idleTimeout = value;

  @override
  int get maxConnectionsPerHost => _delegate.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int value) => _delegate.maxConnectionsPerHost = value;

  @override
  String get userAgent => _delegate.userAgent;

  @override
  set userAgent(String value) => _delegate.userAgent = value;

  _NiddlerHttpClient(this._delegate, this._niddler, this._sanitizer, {this.includeStackTraces}) : _debugger = _niddler.debugger;

  @override
  void addCredentials(Uri url, String realm, HttpClientCredentials credentials) => _delegate.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm, HttpClientCredentials credentials) =>
      _delegate.addProxyCredentials(host, port, realm, credentials);

  @override
  // ignore: avoid_setters_without_getters
  set authenticate(Future<bool> Function(Uri url, String scheme, String realm) f) => _delegate.authenticate = f;

  @override
  // ignore: avoid_setters_without_getters
  set authenticateProxy(Future<bool> Function(String host, int port, String scheme, String realm) f) => _delegate.authenticateProxy = f;

  @override
  // ignore: avoid_setters_without_getters
  set badCertificateCallback(bool Function(X509Certificate cert, String host, int port) callback) => _delegate.badCertificateCallback = callback;

  @override
  void close({bool force = false}) => _delegate.close(force: force);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    final deleteRequest = _delegate.delete(host, port, path);
    return deleteRequest;
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    final deleteRequest = _delegate.deleteUrl(url);
    return deleteRequest;
  }

  @override
  // ignore: avoid_setters_without_getters
  set findProxy(String Function(Uri url) f) => _delegate.findProxy = f;

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    final getRequest = _delegate.get(host, port, path);
    return getRequest;
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    final getRequest = _delegate.getUrl(url);
    return getRequest;
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    final headRequest = _delegate.head(host, port, path);
    return headRequest;
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) {
    final headRequest = _delegate.headUrl(url);
    return headRequest;
  }

  @override
  Future<HttpClientRequest> open(String method, String host, int port, String path) {
    final openRequest = _delegate.open(method, host, port, path);
    return openRequest;
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    if (_niddler.isBlacklisted(url.toString())) {
      return _delegate.openUrl(method, url);
    }

    return Future.value(_NiddlerHttpClientRequest(url, method, _delegate, _niddler, Uuid().v4(), _sanitizer, includeStackTraces: includeStackTraces));
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    final patchRequest = _delegate.patch(host, port, path);
    return patchRequest;
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    final patchRequest = _delegate.patchUrl(url);
    return patchRequest;
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    final postRequest = _delegate.post(host, port, path);
    return postRequest;
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    final postRequest = _delegate.postUrl(url);
    return postRequest;
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    final putRequest = _delegate.put(host, port, path);
    return putRequest;
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    final putRequest = _delegate.putUrl(url);
    return putRequest;
  }
}

class _NiddlerHttpClientRequest implements HttpClientRequest {
  final Niddler _niddler;
  List<List<int>> requestBodyBytes;
  final HttpClient _delegateClient;
  final List<String> _stackTraces;
  final String requestId;

  final _requestTime = DateTime.now().millisecondsSinceEpoch;

  HttpClientRequest _executingRequest;
  final _completer = Completer<HttpClientResponse>();

  @override
  Uri uri;
  @override
  String method;

  @override
  var bufferOutput = true;
  @override
  var contentLength = -1;
  @override
  Encoding encoding;
  @override
  var persistentConnection = true;
  @override
  var followRedirects = true;
  @override
  var maxRedirects = 5;
  @override
  final cookies = List<Cookie>();

  @override
  HttpConnectionInfo get connectionInfo => _executingRequest.connectionInfo;

  @override
  Future<HttpClientResponse> get done => _completer.future;

  @override
  Future flush() {
    return Future.value(null);
  }

  @override
  HttpHeaders headers = _SimpleHeaders();

  _NiddlerHttpClientRequest(
    this.uri,
    this.method,
    this._delegateClient,
    this._niddler,
    this.requestId,
    StackTraceSanitizer sanitizer, {
    bool includeStackTraces = false,
  }) : _stackTraces = includeStackTraces
            ? _expandWithGaps(Chain.current().traces.map((trace) => _filterFrames(trace, sanitizer)).where((trace) => trace.frames.isNotEmpty)).toList()
            : null;

  @override
  void add(List<int> data) {
    requestBodyBytes ??= List<List<int>>();
    requestBodyBytes.add(data);
  }

  @override
  void addError(Object error, [StackTrace stackTrace]) => _executingRequest.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) {
    return stream.toList().then((data) {
      data.forEach(add);
    });
  }

  @override
  Future<HttpClientResponse> close() async {
    final _originalRequest = NiddlerRequest(uri.toString(), method, _stackTraces, Uuid().v4(), requestId, _requestTime, Map<String, List<String>>());
    headers.forEach((key, values) => _originalRequest.headers[key] = values);

    //TODO optimize for speeeeeed
    HttpClientRequest request;
    var executingRequest = _originalRequest;
    if (_niddler.debugger.isActive) {
      if (requestBodyBytes != null && requestBodyBytes.isNotEmpty) {
        final bodyBytes = List<int>();
        requestBodyBytes.forEach(bodyBytes.addAll);
        if (bodyBytes.isNotEmpty) {
          _originalRequest.body = const Base64Codec.urlSafe().encode(bodyBytes);
        }
      }
      final overriddenRequest = await _niddler.debugger.overrideRequest(_originalRequest);
      if (overriddenRequest != null) {
        final newUri = Uri.parse(overriddenRequest.url);
        request = await _delegateClient.openUrl(overriddenRequest.method, newUri)
          ..bufferOutput = bufferOutput;

        overriddenRequest.headers.forEach((key, values) => request.headers.add(key, values));
        request
          ..persistentConnection = persistentConnection
          ..followRedirects = followRedirects
          ..maxRedirects = maxRedirects
          ..cookies.addAll(cookies);

        executingRequest = NiddlerRequest(overriddenRequest.url,
            overriddenRequest.method,
            _stackTraces,
            Uuid().v4(),
            requestId,
            _requestTime,
            Map<String, List<String>>());
        executingRequest.headers.addAll(overriddenRequest.headers);

        if (overriddenRequest.encodedBody != null) {
          final decoded = const Base64Codec.urlSafe().decode(overriddenRequest.encodedBody);
          request
            ..contentLength = decoded.length
            ..add(decoded);
        }
      }
    }
    //Build normal request
    if (request == null) {
      request = await _delegateClient.openUrl(method, uri)
        ..bufferOutput = bufferOutput
        ..persistentConnection = persistentConnection
        ..followRedirects = followRedirects
        ..maxRedirects = maxRedirects
        ..cookies.addAll(cookies);

      // ignore: avoid_as
      (headers as _SimpleHeaders).applyHeaders(request.headers);

      if (requestBodyBytes != null) {
        requestBodyBytes.forEach((list) => request.add(list));
      }
    }

    final stringData = await _encodeBody(executingRequest, requestBodyBytes);
    _niddler.logRequestJson(stringData);

    final connectionHeader = executingRequest.headers['connection'];
    if (connectionHeader != null && connectionHeader.firstWhere((element) => element.toLowerCase() == 'upgrade') != null) return request.close();

    return request.close().then((response) {
      final responseHeaders = Map<String, List<String>>();
      response.headers.forEach((key, value) => responseHeaders[key] = value);

      final niddlerResponse = NiddlerResponse(response.statusCode, response.reasonPhrase, null, null, null, -1, -1, -1, Uuid().v4(), requestId,
          DateTime.now().millisecondsSinceEpoch, responseHeaders);

      return response.toList().then((bodyBytes) {
        _encodeBody(niddlerResponse, bodyBytes).then(_niddler.logResponseJson);

        return _NiddlerHttpClientResponse(response, bodyBytes);
      });
    });
  }

  @override
  void write(Object obj) {
    add(utf8.encode(obj.toString()));
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) => add(List()..add(charCode));

  @override
  void writeln([Object obj = '']) => write('$obj\n');
}

class _NiddlerHttpClientResponse implements HttpClientResponse {
  final HttpClientResponse _delegate;
  Stream<List<int>> _stream;

  _NiddlerHttpClientResponse(this._delegate, List<List<int>> body) {
    if (body == null) {
      _stream = const Stream.empty();
    } else {
      _stream = Stream.fromIterable(body);
    }
  }

  @override
  X509Certificate get certificate => _delegate.certificate;

  @override
  HttpConnectionInfo get connectionInfo => _delegate.connectionInfo;

  @override
  int get contentLength => _delegate.contentLength;

  @override
  List<Cookie> get cookies => _delegate.cookies;

  @override
  Future<Socket> detachSocket() => _delegate.detachSocket();

  @override
  HttpHeaders get headers => _delegate.headers;

  @override
  bool get isRedirect => _delegate.isRedirect;

  @override
  bool get persistentConnection => _delegate.persistentConnection;

  @override
  String get reasonPhrase => _delegate.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect([String method, Uri url, bool followLoops]) => _delegate.redirect(method, url, followLoops); //TODO?

  @override
  List<RedirectInfo> get redirects => _delegate.redirects;

  @override
  int get statusCode => _delegate.statusCode;

  @override
  Future<bool> any(bool Function(List<int> element) test) => _stream.any(test);

  @override
  Stream<List<int>> asBroadcastStream(
      {void Function(StreamSubscription<List<int>> subscription) onListen, void Function(StreamSubscription<List<int>> subscription) onCancel}) {
    return _stream.asBroadcastStream(onListen: onListen, onCancel: onCancel);
  }

  @override
  Stream<E> asyncExpand<E>(Stream<E> Function(List<int> event) convert) => _stream.asyncExpand(convert);

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(List<int> event) convert) => _stream.asyncMap(convert);

  @override
  Stream<R> cast<R>() => _stream.cast();

  @override
  Future<bool> contains(Object needle) => _stream.contains(needle);

  @override
  Stream<List<int>> distinct([bool Function(List<int> previous, List<int> next) equals]) => _stream.distinct(equals);

  @override
  Future<E> drain<E>([E futureValue]) => _stream.drain(futureValue);

  @override
  Future<List<int>> elementAt(int index) => _stream.elementAt(index);

  @override
  Future<bool> every(bool Function(List<int> element) test) => _stream.every(test);

  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int> element) convert) => _stream.expand(convert);

  @override
  Future<List<int>> get first => _stream.first;

  @override
  Future<List<int>> firstWhere(bool Function(List<int> element) test, {List<int> Function() orElse}) => _stream.firstWhere(test, orElse: orElse);

  @override
  Future<S> fold<S>(S initialValue, S Function(S previous, List<int> element) combine) => _stream.fold(initialValue, combine);

  @override
  Future forEach(void Function(List<int> element) action) => _stream.forEach(action);

  @override
  Stream<List<int>> handleError(Function onError,
          // ignore: avoid_annotating_with_dynamic
          {bool Function(dynamic error) test}) =>
      _stream.handleError(onError, test: test);

  @override
  bool get isBroadcast => _stream.isBroadcast;

  @override
  Future<bool> get isEmpty => _stream.isEmpty;

  @override
  Future<String> join([String separator = '']) => _stream.join(separator);

  @override
  Future<List<int>> get last => _stream.last;

  @override
  Future<List<int>> lastWhere(bool Function(List<int> element) test, {List<int> Function() orElse}) => _stream.lastWhere(test, orElse: orElse);

  @override
  Future<int> get length => _stream.length;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event) onData, {Function onError, void Function() onDone, bool cancelOnError}) {
    return _stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Stream<S> map<S>(S Function(List<int> event) convert) => _stream.map(convert);

  @override
  Future pipe(StreamConsumer<List<int>> streamConsumer) => _stream.pipe(streamConsumer);

  @override
  Future<List<int>> reduce(List<int> Function(List<int> previous, List<int> element) combine) => _stream.reduce(combine);

  @override
  Future<List<int>> get single => _stream.single;

  @override
  Future<List<int>> singleWhere(bool Function(List<int> element) test, {List<int> Function() orElse}) => _stream.singleWhere(test, orElse: orElse);

  @override
  Stream<List<int>> skip(int count) => _stream.skip(count);

  @override
  Stream<List<int>> skipWhile(bool Function(List<int> element) test) => _stream.skipWhile(test);

  @override
  Stream<List<int>> take(int count) => _stream.take(count);

  @override
  Stream<List<int>> takeWhile(bool Function(List<int> element) test) => _stream.takeWhile(test);

  @override
  Stream<List<int>> timeout(Duration timeLimit, {void Function(EventSink<List<int>> sink) onTimeout}) => _stream.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<List<List<int>>> toList() => _stream.toList();

  @override
  Future<Set<List<int>>> toSet() => _stream.toSet();

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) => _stream.transform(streamTransformer);

  @override
  Stream<List<int>> where(bool Function(List<int> event) test) => _stream.where(test);

  @override
  HttpClientResponseCompressionState get compressionState => _delegate.compressionState;
}

class _IsolateData {
  final NiddlerMessageBase message;
  final List<List<int>> body;
  final SendPort dataPort;

  _IsolateData(this.message, this.body, this.dataPort);
}

void _encodeBodyJson(_IsolateData body) {
  if (body.body != null && body.body.isNotEmpty) {
    final bodyBytes = List<int>();
    body.body.forEach(bodyBytes.addAll);
    if (bodyBytes.isNotEmpty) {
      body.message.body = const Base64Codec.urlSafe().encode(bodyBytes);
    }
  }
  body.dataPort.send(body.message.toJsonString());
}

Future<String> _encodeBody(NiddlerMessageBase message, List<List<int>> bytes) async {
  final resultPort = ReceivePort();
  final errorPort = ReceivePort();
  final isolate = await Isolate.spawn(
    _encodeBodyJson,
    _IsolateData(message, bytes, resultPort.sendPort),
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

Trace _filterFrames(Trace source, StackTraceSanitizer sanitizer) {
  final betterFrames = source.frames.where(sanitizer.accepts).toList();
  return Trace(betterFrames);
}

Iterable<String> _expandWithGaps(Iterable<Trace> source) {
  final length = source.length;
  var index = 0;
  return source.expand((trace) {
    final list = trace.frames.map((frame) => '${frame.location} ${frame.member}').toList();
    if (++index < length) {
      list.add('<async gap>');
    }
    return list;
  });
}

class _SimpleHeaders implements HttpHeaders {
  @override
  bool chunkedTransferEncoding = false;

  @override
  int contentLength = -1;

  @override
  ContentType contentType;

  @override
  DateTime date;

  @override
  DateTime expires;

  @override
  String host;

  @override
  DateTime ifModifiedSince;

  @override
  bool persistentConnection = true;

  @override
  int port;

  final _headers = Map<String, List<String>>();
  final _noFolding = List<String>();

  void applyHeaders(HttpHeaders to) {
    to
      ..chunkedTransferEncoding = chunkedTransferEncoding
      ..contentLength = contentLength
      ..contentType = contentType;

    if (date != null) to.date = date;
    if (expires != null) to.expires = expires;
    if (ifModifiedSince != null) to.ifModifiedSince = ifModifiedSince;
    if (persistentConnection != null) to.persistentConnection = persistentConnection;

    _headers.forEach((key, values) => values.forEach((value) => to.add(key, value)));
    _noFolding.forEach((noFold) => to.noFolding(noFold));
  }

  @override
  List<String> operator [](String name) {
    return _headers[name.toLowerCase()];
  }

  @override
  void add(String name, Object value) {
    _headers.putIfAbsent(name.toLowerCase(), () => List<String>()).add(value);
  }

  @override
  void clear() {
    _headers.clear();
  }

  @override
  void forEach(void Function(String name, List<String> values) f) {
    _headers.forEach(f);
  }

  @override
  void noFolding(String name) {
    _noFolding.add(name.toLowerCase());
  }

  @override
  void remove(String name, Object value) {
    _headers[name.toLowerCase()]?.remove(value);
  }

  @override
  void removeAll(String name) {
    _headers.remove(name.toLowerCase());
  }

  @override
  void set(String name, Object value) {
    _headers[name.toLowerCase()] = List()..add(value);
  }

  @override
  String value(String name) {
    final items = _headers[name.toLowerCase()];
    if (items == null || items.isEmpty) return null;
    if (items.length > 1) throw HttpException('More than one value for header $name');
    return items[0];
  }
}
