// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'package:meta/meta.dart';
import 'package:niddler_dart/src/niddler_message.dart';
import 'package:stack_trace/stack_trace.dart';

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

/// Heart of the consumer interface of niddler. Use this class to log custom requests and responses and to
/// start and stop the server
abstract class Niddler {
  /// Supply a new request to niddler
  void logRequest(NiddlerRequest request);

  /// Supply a new request to niddler, already transformed into json
  void logRequestJson(String request);

  /// Supply a new response to niddler
  void logResponse(NiddlerResponse response);

  /// Supply a new response to niddler, already transformed into json
  void logResponseJson(String response);

  /// Adds the URL pattern to the blacklist. Items in the blacklist will not be reported or retained in the memory cache. Matching happens on the request URL
  void addBlacklist(RegExp regex);

  /// Checks if the given URL matches the current configured blacklist
  bool isBlacklisted(String url);

  /// Starts the server
  Future<bool> start();

  /// Stops the server
  Future<void> stop();

  /// Installs niddler on the process
  void install();

  /// The debugger instance used to debug/change network requests/responses
  NiddlerDebugger get debugger;
}

// ignore: one_member_abstracts
abstract class StackTraceSanitizer {
  bool accepts(Frame frame);
}

abstract class NiddlerDebugger {
  bool get isActive;

  Future<bool> waitForConnection();

  Future<DebugRequest> overrideRequest(NiddlerRequest request);

  Future<DebugResponse> overrideResponse(NiddlerRequest request, NiddlerResponse response);
}

class DebugRequest {
  final String url;
  final String method;
  final Map<String, List<String>> headers;
  final String encodedBody;
  final String bodyMimeType;

  DebugRequest({
    @required this.url,
    @required this.method,
    this.headers,
    this.encodedBody,
    this.bodyMimeType,
  });
}

class DebugResponse {
  final int code;
  final String message;
  final Map<String, List<String>> headers;
  final String encodedBody;
  final String bodyMimeType;

  DebugResponse({
    @required this.code,
    @required this.message,
    this.headers,
    this.encodedBody,
    this.bodyMimeType,
  });
}
