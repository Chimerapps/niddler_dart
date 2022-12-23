// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'package:niddler_dart/src/niddler_generic.dart';
import 'package:niddler_dart/src/niddler_message.dart';

Niddler createNiddler(
  int maxCacheSize,
  int port,
  String bundleId,
  NiddlerServerInfo? serverInfo,
  StackTraceSanitizer sanitizer, {
  required bool includeStackTrace,
}) =>
    const NiddlerNoop._();

void installNiddler(Niddler niddler) {}

class NiddlerNoop implements Niddler {
  const NiddlerNoop._();

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
  Future<bool> start({bool waitForDebugger = false}) => Future.value(true);

  @override
  Future<void> stop() => Future.value(null);

  @override
  void install() {}

  @override
  NiddlerDebugger get debugger => const NiddlerDebuggerNoop._();

  @override
  void overrideDebugger(NiddlerDebugger debugger) {}
}

class NiddlerDebuggerNoop implements NiddlerDebugger {
  const NiddlerDebuggerNoop._();

  @override
  bool get isActive => false;

  @override
  Future<bool> waitForConnection() => Future.value(false);

  @override
  Future<DebugRequest?> overrideRequest(
          NiddlerRequest request, List<List<int>>? nonSerializedBody) =>
      Future.value(null);

  @override
  Future<DebugResponse?> overrideResponse(NiddlerRequest request,
          NiddlerResponse response, List<List<int>>? nonSerializedBody) =>
      Future.value(null);

  @override
  Future<DebugResponse?> provideResponse(NiddlerRequest request) =>
      Future.value(null);
}
