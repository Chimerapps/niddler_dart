// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'package:niddler_dart/src/niddler_generic.dart';
import 'package:niddler_dart/src/niddler_message.dart';

Niddler createNiddler(
  int maxCacheSize,
  int port,
  String password,
  String bundleId,
  NiddlerServerInfo serverInfo,
  StackTraceSanitizer sanitizer, {
  bool includeStackTrace,
}) =>
    NiddlerNoop._();

void installNiddler(Niddler niddler) {}

class NiddlerNoop implements Niddler {
  NiddlerNoop._();

  @override
  void addBlacklist(RegExp regex) {}

  @override
  bool isBlacklisted(String url) => false;

  @override
  void logRequest(NiddlerRequest request) {}

  @override
  void logRequestJson(String request) {}

  @override
  void logResponse(NiddlerResponse response) {}

  @override
  void logResponseJson(String response) {}

  @override
  Future<bool> start() => Future.value(true);

  @override
  Future<void> stop() => Future.value(null);

  @override
  void install() {}
}
