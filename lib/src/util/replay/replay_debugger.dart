// Copyright (c) 2022, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:convert';

import 'package:computer/computer.dart';
import 'package:niddler_dart/src/niddler_generic.dart';
import 'package:niddler_dart/src/niddler_message.dart';

import 'data.dart';

/// Special [NiddlerDebugger] that replays a previously saved
/// session (in HAR format). This can be used to create a very basic
/// dummy service implementation.
///
/// Note: only URL and method are used to match
///
/// Note: URLs are either matched with ALL query parameters or none.
/// If multiple requests are found in the har file that satisfy the
/// same URL/method,  a round-robin implementation will rotate between
/// the matching requests.
class ReplayDebugger implements NiddlerDebugger {
  late final Future<HarFile> _harFuture;

  final _requestCounter = <String, int>{};

  @override
  bool isActive;

  /// Create a new [ReplayDebugger] that will replay the given HAR file from [harContent]
  /// If [isActive] is true (default), the debugger will be active and will intercept requests
  ReplayDebugger({required String harContent, this.isActive = true}) {
    _harFuture = _loadHarContent(harContent);
  }

  @override
  Future<DebugRequest?> overrideRequest(
          NiddlerRequest request, List<List<int>>? nonSerializedBody) =>
      Future.value(null);

  @override
  Future<DebugResponse?> overrideResponse(NiddlerRequest request,
          NiddlerResponse response, List<List<int>> nonSerializedBody) =>
      Future.value(null);

  @override
  Future<DebugResponse?> provideResponse(NiddlerRequest request) async {
    final responses = await _findResponses(request);
    if (responses.second.isEmpty) return null;

    final counter = _requestCounter.putIfAbsent(responses.first, () => 0);
    _requestCounter[responses.first] = counter + 1;

    final response = responses.second[counter % responses.second.length];
    return DebugResponse(
      code: response.status,
      message: response.statusText,
      headers: response.headers.toMultiMap(),
      bodyMimeType: response.content.mimeType,
      encodedBody: _makeEncodedBody(response.content),
    );
  }

  @override
  Future<bool> waitForConnection() => Future.value(true);

  Future<HarFile> _loadHarContent(String content) async {
    final computer = Computer.shared();
    if (!computer.isRunning) {
      await computer.turnOn();
    }
    return computer.compute(parseHarFile, param: content);
  }

  Future<_Pair<String, List<HarResponse>>> _findResponses(
      NiddlerRequest request) async {
    var url = request.url;
    final log = (await _harFuture).log;

    var matches = log.entries
        .where((element) => element.request.url == url)
        .toList(growable: false);
    if (matches.isEmpty) {
      url = url.substring(url.indexOf('?'));
      matches = log.entries
          .where((element) => element.request.url == url)
          .toList(growable: false);
    }
    return _Pair(url, matches.map((e) => e.response).toList(growable: false));
  }

  String _makeEncodedBody(HarContent content) {
    if (content.encoding == 'base64') return content.text;
    return Base64Codec.urlSafe().encode(utf8.encode(content.text));
  }
}

class _Pair<T, U> {
  final T first;
  final U second;

  const _Pair(this.first, this.second);
}

extension _MultiMapExtension on List<HarHeader> {
  Map<String, List<String>> toMultiMap() {
    final map = <String, List<String>>{};
    for (final header in this) {
      map.putIfAbsent(header.name, () => []).add(header.value);
    }
    return map;
  }
}
