// Copyright (c) 2022, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:convert';

HarFile parseHarFile(String content) {
  final root = json.decode(content) as Map<String, dynamic>;
  final log = root['log'] as Map<String, dynamic>;
  final entries = log['entries'] as List<dynamic>;

  return HarFile(HarLog(
      entries.map((e) => _makeEntry(e as Map<String, dynamic>)).toList()));
}

HarEntry _makeEntry(Map<String, dynamic> json) {
  return HarEntry(_makeRequest(json['request'] as Map<String, dynamic>),
      _makeResponse(json['response'] as Map<String, dynamic>));
}

HarResponse _makeResponse(Map<String, dynamic> json) {
  return HarResponse(
    json['status'] as int,
    json['statusText'] as String,
    _makeHeaders(json['headers'] as List<dynamic>),
    _makeContent(json['content'] as Map<String, dynamic>),
  );
}

HarContent _makeContent(Map<String, dynamic> json) {
  return HarContent(json['mimeType'] as String, json['text'] as String,
      json['encoding'] as String?);
}

List<HarHeader> _makeHeaders(List<dynamic> json) {
  return json
      .map((e) => HarHeader(e['name'] as String, e['value'] as String))
      .toList();
}

HarRequest _makeRequest(Map<String, dynamic> json) {
  return HarRequest(json['method'] as String, json['url'] as String);
}

class HarFile {
  final HarLog log;

  const HarFile(this.log);
}

class HarLog {
  final List<HarEntry> entries;

  const HarLog(this.entries);
}

class HarEntry {
  final HarRequest request;
  final HarResponse response;

  const HarEntry(this.request, this.response);
}

class HarResponse {
  final int status;
  final String statusText;
  final List<HarHeader> headers;
  final HarContent content;

  const HarResponse(this.status, this.statusText, this.headers, this.content);
}

class HarContent {
  final String mimeType;
  final String text;
  final String? encoding;

  const HarContent(this.mimeType, this.text, this.encoding);
}

class HarHeader {
  final String name;
  final String value;

  const HarHeader(this.name, this.value);
}

class HarRequest {
  final String method;
  final String url;

  const HarRequest(this.method, this.url);
}
