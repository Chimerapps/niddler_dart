// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:niddler_dart/src/niddler_generic.dart';
import 'package:niddler_dart/src/niddler_message.dart';
import 'package:niddler_dart/src/util/uuid.dart';
import 'package:stack_trace/stack_trace.dart';

class NiddlerHttpOverrides extends HttpOverrides {
  final Niddler _niddler;
  final StackTraceSanitizer _sanitizer;
  final bool includeStackTraces;

  NiddlerHttpOverrides(this._niddler, this._sanitizer,
      {required this.includeStackTraces});

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    return _NiddlerHttpClient(
      super.createHttpClient(context),
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

  @override
  bool get autoUncompress => _delegate.autoUncompress;

  @override
  set autoUncompress(bool value) => _delegate.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _delegate.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _delegate.connectionTimeout = value;

  @override
  Duration get idleTimeout => _delegate.idleTimeout;

  @override
  set idleTimeout(Duration value) => _delegate.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _delegate.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) =>
      _delegate.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _delegate.userAgent;

  @override
  set userAgent(String? value) => _delegate.userAgent = value;

  _NiddlerHttpClient(this._delegate, this._niddler, this._sanitizer,
      {required this.includeStackTraces});

  @override
  void addCredentials(
          Uri url, String realm, HttpClientCredentials credentials) =>
      _delegate.addCredentials(url, realm, credentials);

  @override
  void addProxyCredentials(String host, int port, String realm,
          HttpClientCredentials credentials) =>
      _delegate.addProxyCredentials(host, port, realm, credentials);

  @override
  // ignore: avoid_setters_without_getters
  set authenticate(
          Future<bool> Function(Uri url, String scheme, String realm)? f) =>
      _delegate.authenticate = f;

  @override
  // ignore: avoid_setters_without_getters
  set authenticateProxy(
          Future<bool> Function(
                  String host, int port, String scheme, String realm)?
              f) =>
      _delegate.authenticateProxy = f;

  @override
  // ignore: avoid_setters_without_getters
  set badCertificateCallback(
          bool Function(X509Certificate cert, String host, int port)?
              callback) =>
      _delegate.badCertificateCallback = callback;

  @override
  void close({bool force = false}) => _delegate.close(force: force);

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    return open('delete', host, port, path);
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    final deleteRequest = _delegate.deleteUrl(url);
    return deleteRequest;
  }

  @override
  // ignore: avoid_setters_without_getters
  set findProxy(String Function(Uri url)? f) => _delegate.findProxy = f;

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    return getUrl(_createUri(host, port, path));
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    return openUrl('get', url);
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    return headUrl(_createUri(host, port, path));
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) {
    return openUrl('head', url);
  }

  @override
  Future<HttpClientRequest> open(
      String method, String host, int port, String path) {
    return openUrl(method, _createUri(host, port, path));
  }

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) {
    if (_niddler.isBlacklisted(url.toString())) {
      return _delegate.openUrl(method, url);
    }

    return Future.value(_NiddlerHttpClientRequest(
        url, method, _delegate, _niddler, SimpleUUID.uuid(), _sanitizer,
        includeStackTraces: includeStackTraces));
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    return patchUrl(_createUri(host, port, path));
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    return openUrl('patch', url);
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    return postUrl(_createUri(host, port, path));
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    return openUrl('post', url);
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    return putUrl(_createUri(host, port, path));
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    return openUrl('put', url);
  }

  Uri _createUri(String host, int port, String path) {
    const hashMark = 0x23;
    const questionMark = 0x3f;
    var fragmentStart = path.length;
    var queryStart = path.length;
    for (var i = path.length - 1; i >= 0; i--) {
      final char = path.codeUnitAt(i);
      if (char == hashMark) {
        fragmentStart = i;
        queryStart = i;
      } else if (char == questionMark) {
        queryStart = i;
      }
    }
    String? query;
    var newPath = path;
    if (queryStart < fragmentStart) {
      query = path.substring(queryStart + 1, fragmentStart);
      newPath = path.substring(0, queryStart);
    }
    return Uri(
        scheme: 'http', host: host, port: port, path: newPath, query: query);
  }
}

class _NiddlerHttpClientRequest implements HttpClientRequest {
  final Niddler _niddler;
  List<List<int>>? requestBodyBytes;
  final HttpClient _delegateClient;
  final List<String>? _stackTraces;
  final String requestId;

  final _requestTime = DateTime.now().millisecondsSinceEpoch;

  HttpClientRequest? _executingRequest;
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
  late Encoding encoding;
  @override
  var persistentConnection = true;
  @override
  var followRedirects = true;
  @override
  var maxRedirects = 5;
  @override
  final cookies = <Cookie>[];

  @override
  HttpConnectionInfo? get connectionInfo => _executingRequest?.connectionInfo;

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
            ? _expandWithGaps(Chain.current()
                .traces
                .map((trace) => _filterFrames(trace, sanitizer))
                .where((trace) => trace.frames.isNotEmpty)).toList()
            : null;

  @override
  void add(List<int> data) {
    requestBodyBytes ??= <List<int>>[];
    requestBodyBytes!.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) =>
      _executingRequest?.addError(error, stackTrace);

  @override
  Future addStream(Stream<List<int>> stream) {
    return stream.toList().then((data) {
      data.forEach(add);
    });
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    if (!_completer.isCompleted) {
      _completer.completeError(exception ?? const HttpException('Aborted'),
          stackTrace ?? StackTrace.empty);
    }
  }

  @override
  Future<HttpClientResponse> close() async {
    final _originalRequest = NiddlerRequest(
      url: uri.toString(),
      method: method,
      stackTraces: _stackTraces,
      messageId: SimpleUUID.uuid(),
      requestId: requestId,
      timeStamp: _requestTime,
      headers: <String, List<String>>{},
    );
    headers.forEach((key, values) => _originalRequest.headers[key] = values);

    HttpClientRequest? request;
    var executingRequest = _originalRequest;
    if (_niddler.debugger.isActive) {
      final overriddenRequest = await _niddler.debugger
          .overrideRequest(_originalRequest, requestBodyBytes);
      if (overriddenRequest != null) {
        final newUri = Uri.parse(overriddenRequest.url);
        request =
            await _delegateClient.openUrl(overriddenRequest.method, newUri)
              ..bufferOutput = bufferOutput;

        overriddenRequest.headers
            .forEach((key, values) => request!.headers.add(key, values));
        request
          ..persistentConnection = persistentConnection
          ..followRedirects = followRedirects
          ..maxRedirects = maxRedirects;
        //Cookies are added automatically by request object based on headers

        executingRequest = NiddlerRequest(
          url: overriddenRequest.url,
          method: overriddenRequest.method,
          stackTraces: _stackTraces,
          messageId: SimpleUUID.uuid(),
          requestId: requestId,
          timeStamp: _requestTime,
          headers: {
            'x-niddler-debug': ['true'],
          },
        );
        executingRequest.headers.addAll(overriddenRequest.headers);

        if (overriddenRequest.encodedBody != null) {
          final decoded = const Base64Codec.urlSafe()
              .decode(_ensureBase64Padded(overriddenRequest.encodedBody!));
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
        requestBodyBytes!.forEach((list) => request!.add(list));
      }
    }

    final stringData = await _encodeBody(executingRequest, requestBodyBytes);
    _niddler.logRequestJson(stringData);

    final connectionHeader = executingRequest.headers['connection'];
    if (connectionHeader != null &&
        connectionHeader
                .find((element) => element.toLowerCase() == 'upgrade') !=
            null) {
      return request.close().then((value) {
        if (!_completer.isCompleted) {
          _completer.complete(value);
        }
        return value;
      });
    }

    // ignore: unawaited_futures
    request
        .close()
        .then((response) => _handleResponse(_originalRequest, response))
        .then((value) {
      if (!_completer.isCompleted) {
        _completer.complete(value);
      }
    });

    return _completer.future;
  }

  Future<HttpClientResponse> _handleResponse(
      NiddlerRequest request, HttpClientResponse originalResponse) {
    final responseHeaders = <String, List<String>>{};
    originalResponse.headers
        .forEach((key, value) => responseHeaders[key] = value);
    final initialNiddlerResponse = NiddlerResponse(
      statusCode: originalResponse.statusCode,
      statusLine: originalResponse.reasonPhrase,
      httpVersion: null,
      readTime: -1,
      writeTime: -1,
      waitTime: -1,
      messageId: SimpleUUID.uuid(),
      requestId: requestId,
      timeStamp: DateTime.now().millisecondsSinceEpoch,
      headers: responseHeaders,
    );

    return originalResponse.toList().then((bodyBytes) {
      if (!_niddler.debugger.isActive) {
        return _handleDefaultResponse(
            initialNiddlerResponse, originalResponse, bodyBytes);
      }

      return _handleResponseWithDebugger(
          request, initialNiddlerResponse, originalResponse, bodyBytes);
    });
  }

  Future<HttpClientResponse> _handleResponseWithDebugger(
      NiddlerRequest request,
      NiddlerResponse initialNiddlerResponse,
      HttpClientResponse originalResponse,
      List<List<int>> bodyBytes) async {
    final debuggerResponse = await _niddler.debugger
        .overrideResponse(request, initialNiddlerResponse, bodyBytes);
    if (debuggerResponse == null) {
      return _handleDefaultResponse(
          initialNiddlerResponse, originalResponse, bodyBytes);
    }

    final newHeaders = _SimpleHeaders()
      ..host = originalResponse.headers.host
      ..port = originalResponse.headers.port;
    debuggerResponse.headers.forEach(
        (key, values) => values.forEach((value) => newHeaders.add(key, value)));
    final cookies = newHeaders['set-cookie']
            ?.map((value) => Cookie.fromSetCookieValue(value))
            .toList() ??
        [];

    final changedNiddlerResponse = NiddlerResponse(
      statusCode: debuggerResponse.code,
      statusLine: debuggerResponse.message,
      httpVersion: null,
      writeTime: -1,
      readTime: -1,
      waitTime: -1,
      timeStamp: initialNiddlerResponse.timeStamp,
      headers: debuggerResponse.headers,
      messageId: initialNiddlerResponse.messageId,
      requestId: requestId,
    );
    List<List<int>>? newBody;
    if (debuggerResponse.encodedBody != null) {
      newBody = [
        const Base64Codec.urlSafe()
            .decode(_ensureBase64Padded(debuggerResponse.encodedBody!))
      ];
    }
    changedNiddlerResponse.headers['x-niddler-debug'] = ['true'];

    final stringMessage = await _encodeBody(changedNiddlerResponse, newBody);
    _niddler.logResponseJson(stringMessage);

    return _NiddlerHttpClientResponseWrapper(
      originalResponse,
      newBody,
      overrideCookies: cookies,
      overrideHeaders: headers,
      overrideReasonPhrase: debuggerResponse.message,
      overrideStatusCode: debuggerResponse.code,
    );
  }

  Future<HttpClientResponse> _handleDefaultResponse(
    NiddlerResponse initialNiddlerResponse,
    HttpClientResponse originalResponse,
    List<List<int>> bodyBytes,
  ) {
    _encodeBody(initialNiddlerResponse, bodyBytes)
        .then(_niddler.logResponseJson);

    return Future.value(
        _NiddlerHttpClientResponseWrapper(originalResponse, bodyBytes));
  }

  @override
  void write(Object? obj) {
    if (obj != null) {
      add(utf8.encode(obj.toString()));
    }
  }

  @override
  void writeAll(Iterable objects, [String separator = '']) {
    write(objects.join(separator));
  }

  @override
  void writeCharCode(int charCode) => add([]..add(charCode));

  @override
  void writeln([Object? obj = '']) => write('$obj\n');
}

class _IsolateData {
  final NiddlerMessageBase message;
  final List<List<int>>? body;
  final SendPort dataPort;

  _IsolateData(this.message, this.body, this.dataPort);
}

void _encodeBodyJson(_IsolateData body) {
  final convertBodyBytes = body.body;
  if (convertBodyBytes != null && convertBodyBytes.isNotEmpty) {
    final bodyBytes = <int>[];
    convertBodyBytes.forEach(bodyBytes.addAll);
    if (bodyBytes.isNotEmpty) {
      body.message.body = const Base64Codec.urlSafe().encode(bodyBytes);
    }
  }
  body.dataPort.send(body.message.toJsonString());
}

Future<String> _encodeBody(
    NiddlerMessageBase message, List<List<int>>? bytes) async {
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
    final list = trace.frames
        .map((frame) => '${frame.location} ${frame.member}')
        .toList();
    if (++index < length) {
      list.add('<async gap>');
    }
    return list;
  });
}

class _NiddlerHttpClientResponseWrapper
    extends _NiddlerHttpClientResponseStreamBase {
  final HttpClientResponse _originalResponse;
  final List<Cookie>? overrideCookies;
  final HttpHeaders? overrideHeaders;
  final String? overrideReasonPhrase;
  final int? overrideStatusCode;

  _NiddlerHttpClientResponseWrapper(
    this._originalResponse,
    List<List<int>>? body, {
    this.overrideCookies,
    this.overrideHeaders,
    this.overrideReasonPhrase,
    this.overrideStatusCode,
  }) : super(body);

  @override
  X509Certificate? get certificate => _originalResponse.certificate;

  @override
  HttpClientResponseCompressionState get compressionState =>
      _originalResponse.compressionState;

  @override
  HttpConnectionInfo? get connectionInfo => _originalResponse.connectionInfo;

  @override
  int get contentLength => _originalResponse
      .contentLength; //Due to decompressed flag, this can be -1

  @override
  List<Cookie> get cookies => overrideCookies ?? _originalResponse.cookies;

  @override
  Future<Socket> detachSocket() => _originalResponse.detachSocket();

  @override
  HttpHeaders get headers => overrideHeaders ?? _originalResponse.headers;

  @override
  bool get isRedirect => (overrideStatusCode == null)
      ? _originalResponse.isRedirect
      : (overrideStatusCode == HttpStatus.movedPermanently ||
          overrideStatusCode == HttpStatus.found ||
          overrideStatusCode == HttpStatus.movedTemporarily ||
          overrideStatusCode == HttpStatus.seeOther ||
          overrideStatusCode == HttpStatus.temporaryRedirect);

  @override
  bool get persistentConnection => _originalResponse.persistentConnection;

  @override
  String get reasonPhrase =>
      overrideReasonPhrase ?? _originalResponse.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect(
      [String? method, Uri? url, bool? followLoops]) {
    return _originalResponse.redirect(method, url, followLoops);
  }

  @override
  List<RedirectInfo> get redirects => _originalResponse.redirects;

  @override
  int get statusCode => overrideStatusCode ?? _originalResponse.statusCode;
}

abstract class _NiddlerHttpClientResponseStreamBase
    implements HttpClientResponse {
  final Stream<List<int>> _bodyStream;

  _NiddlerHttpClientResponseStreamBase(List<List<int>>? data)
      : _bodyStream =
            data == null ? const Stream.empty() : Stream.fromIterable(data);

  @override
  Future<bool> any(bool Function(List<int> element) test) =>
      _bodyStream.any(test);

  @override
  Stream<List<int>> asBroadcastStream({
    void Function(StreamSubscription<List<int>> subscription)? onListen,
    void Function(StreamSubscription<List<int>> subscription)? onCancel,
  }) =>
      _bodyStream.asBroadcastStream(
        onListen: onListen,
        onCancel: onCancel,
      );

  @override
  Stream<E> asyncExpand<E>(Stream<E>? Function(List<int> event) convert) =>
      _bodyStream.asyncExpand(convert);

  @override
  Stream<E> asyncMap<E>(FutureOr<E> Function(List<int> event) convert) =>
      _bodyStream.asyncMap(convert);

  @override
  Stream<R> cast<R>() => _bodyStream.cast();

  @override
  Future<bool> contains(Object? needle) => _bodyStream.contains(needle);

  @override
  Stream<List<int>> distinct(
          [bool Function(List<int> previous, List<int> next)? equals]) =>
      _bodyStream.distinct(equals);

  @override
  Future<E> drain<E>([E? futureValue]) => _bodyStream.drain(futureValue);

  @override
  Future<List<int>> elementAt(int index) => _bodyStream.elementAt(index);

  @override
  Future<bool> every(bool Function(List<int> element) test) =>
      _bodyStream.every(test);

  @override
  Stream<S> expand<S>(Iterable<S> Function(List<int> element) convert) =>
      _bodyStream.expand(convert);

  @override
  Future<List<int>> get first => _bodyStream.first;

  @override
  Future<List<int>> firstWhere(bool Function(List<int> element) test,
          {List<int> Function()? orElse}) =>
      _bodyStream.firstWhere(test, orElse: orElse);

  @override
  Future<S> fold<S>(
          S initialValue, S Function(S previous, List<int> element) combine) =>
      _bodyStream.fold(initialValue, combine);

  @override
  Future forEach(void Function(List<int> element) action) =>
      _bodyStream.forEach(action);

  @override
  Stream<List<int>> handleError(
    Function onError, {
    bool Function(dynamic error)? test, // ignore: avoid_annotating_with_dynamic
  }) =>
      _bodyStream.handleError(onError, test: test);

  @override
  bool get isBroadcast => _bodyStream.isBroadcast;

  @override
  Future<bool> get isEmpty => _bodyStream.isEmpty;

  @override
  Future<String> join([String separator = '']) => _bodyStream.join(separator);

  @override
  Future<List<int>> get last => _bodyStream.last;

  @override
  Future<List<int>> lastWhere(bool Function(List<int> element) test,
          {List<int> Function()? orElse}) =>
      _bodyStream.lastWhere(test, orElse: orElse);

  @override
  Future<int> get length => _bodyStream.length;

  @override
  StreamSubscription<List<int>> listen(void Function(List<int> event)? onData,
      {Function? onError, void Function()? onDone, bool? cancelOnError}) {
    return _bodyStream.listen(onData,
        onError: onError, onDone: onDone, cancelOnError: cancelOnError);
  }

  @override
  Stream<S> map<S>(S Function(List<int> event) convert) =>
      _bodyStream.map(convert);

  @override
  Future pipe(StreamConsumer<List<int>> streamConsumer) =>
      _bodyStream.pipe(streamConsumer);

  @override
  Future<List<int>> reduce(
          List<int> Function(List<int> previous, List<int> element) combine) =>
      _bodyStream.reduce(combine);

  @override
  Future<List<int>> get single => _bodyStream.single;

  @override
  Future<List<int>> singleWhere(bool Function(List<int> element) test,
          {List<int> Function()? orElse}) =>
      _bodyStream.singleWhere(test, orElse: orElse);

  @override
  Stream<List<int>> skip(int count) => _bodyStream.skip(count);

  @override
  Stream<List<int>> skipWhile(bool Function(List<int> element) test) =>
      _bodyStream.skipWhile(test);

  @override
  Stream<List<int>> take(int count) => _bodyStream.take(count);

  @override
  Stream<List<int>> takeWhile(bool Function(List<int> element) test) =>
      _bodyStream.takeWhile(test);

  @override
  Stream<List<int>> timeout(Duration timeLimit,
          {void Function(EventSink<List<int>> sink)? onTimeout}) =>
      _bodyStream.timeout(timeLimit, onTimeout: onTimeout);

  @override
  Future<List<List<int>>> toList() => _bodyStream.toList();

  @override
  Future<Set<List<int>>> toSet() => _bodyStream.toSet();

  @override
  Stream<S> transform<S>(StreamTransformer<List<int>, S> streamTransformer) =>
      _bodyStream.transform(streamTransformer);

  @override
  Stream<List<int>> where(bool Function(List<int> event) test) =>
      _bodyStream.where(test);
}

class _SimpleHeaders implements HttpHeaders {
  @override
  bool chunkedTransferEncoding = false;

  @override
  int contentLength = -1;

  @override
  ContentType? contentType;

  @override
  DateTime? date;

  @override
  DateTime? expires;

  @override
  String? host;

  @override
  DateTime? ifModifiedSince;

  @override
  bool persistentConnection = true;

  @override
  int? port;

  final _headers = <String, List<String>>{};
  final _noFolding = <String>[];

  void applyHeaders(HttpHeaders to) {
    if (chunkedTransferEncoding) {
      to.chunkedTransferEncoding = chunkedTransferEncoding;
    }
    if (contentLength != -1) {
      to.contentLength = contentLength;
    }
    if (contentType != null) {
      to.contentType = contentType;
    }

    if (date != null) to.date = date;
    if (expires != null) to.expires = expires;
    if (ifModifiedSince != null) to.ifModifiedSince = ifModifiedSince;

    to.persistentConnection = persistentConnection;

    _headers.forEach(
        (key, values) => values.forEach((value) => to.add(key, value)));
    _noFolding.forEach((noFold) => to.noFolding(noFold));
  }

  @override
  List<String>? operator [](String name) {
    return _headers[name.toLowerCase()];
  }

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    final target = _headers.putIfAbsent(
        preserveHeaderCase ? name : name.toLowerCase(), () => <String>[]);
    if (value is List) {
      value.forEach(
          (item) => add(name, item, preserveHeaderCase: preserveHeaderCase));
    } else if (value is DateTime) {
      target.add(HttpDate.format(value));
    } else {
      target.add(value.toString());
    }
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
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    _headers[preserveHeaderCase ? name : name.toLowerCase()] = []
      ..add(value.toString());
  }

  @override
  String? value(String name) {
    final items = _headers[name.toLowerCase()];
    if (items == null || items.isEmpty) return null;
    if (items.length > 1) {
      throw HttpException('More than one value for header $name');
    }
    return items[0];
  }
}

//Since dart can't handle no padding...
String _ensureBase64Padded(String input) {
  return const Base64Codec.urlSafe().normalize(input);
}

extension IterableExtension<E> on Iterable<E> {
  E? find(bool Function(E element) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
