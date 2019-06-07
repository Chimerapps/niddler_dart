// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:convert';

/// Base for all niddler messages
abstract class NiddlerMessageBase {
  /// Message id of the message. Must be unique over all messages
  final String messageId;

  /// The request if of the message. Used to associate requests with their responses, they use the same [requestId]
  final String requestId;

  /// The timestamp, in milliseconds since epoch, that this message's content was generated
  final int timeStamp;

  /// List of headers associated with this message
  final Map<String, List<String>> headers;

  /// Binary body of the message, encoded as Base64
  String body;

  /// Constructor
  NiddlerMessageBase(this.messageId, this.requestId, this.timeStamp, this.headers);

  /// Updates the given (json) data with the values stored in this instance
  void updateJson(Map<String, dynamic> jsonData) {
    jsonData['messageId'] = messageId;
    jsonData['requestId'] = requestId;
    jsonData['timestamp'] = timeStamp;
    jsonData['headers'] = headers;
    if (body != null) jsonData['body'] = body;
  }

  String toJsonString();
}

/// Implementation class for representing niddler requests (outgoing). This is not restricted to strictly HTTP requests
class NiddlerRequest extends NiddlerMessageBase {
  /// The url of this request, can be a valid URI or something else that describes your request (eg in websockets)
  final String url;

  /// The method of this request, can be a HTTP method or something else that describes your request (eg in websockets)
  final String method;

  /// Constructor
  NiddlerRequest(this.url, this.method, String messageId, String requestId, int timeStamp, Map<String, List<String>> headers)
      : super(messageId, requestId, timeStamp, headers);

  /// Converts this request to a json object
  dynamic toJson() {
    final data = Map<String, dynamic>();
    data['type'] = 'request';
    data['method'] = method;
    data['url'] = url;
    updateJson(data);
    return data;
  }

  /// Converts this request to a json string
  String toJsonString() {
    return json.encode(toJson());
  }
}

/// Implementation class for representing niddler responses (incoming). This is not restricted to strictly HTTP responses
class NiddlerResponse extends NiddlerMessageBase {
  /// The status code of the request. Eg: 200 for HTTP OK
  final int statusCode;

  /// The status line associated with the request. Eg: 'I am a robot'. Can be empty if unknown
  final String statusLine;

  /// The http version of this request. Can be empty if unknown or non-http. If set, please use the standard notation: HTTP/1.1, ...
  final String httpVersion;

  /// The actual network request that was sent over 'the wire'. Useful for when other interceptors modify the data after niddler has seen it. Can be null
  final NiddlerRequest actualNetworkRequest;

  /// The actual network response that was received over 'the wire'. Useful for when other interceptors modify the data after niddler has seen it. Can be null
  final NiddlerResponse actualNetworkResponse;

  /// The time it took to write the data to 'the wire'. If unknown, set to -1
  final int writeTime;

  /// The time it took to read the data from 'the wire'. If unknown, set to -1
  final int readTime;

  /// The time spent waiting for the first data to become available. If unknown, set to -1
  final int waitTime;

  /// Constructor
  NiddlerResponse(this.statusCode, this.statusLine, this.httpVersion, this.actualNetworkRequest, this.actualNetworkResponse, this.writeTime, this.readTime,
      this.waitTime, String messageId, String requestId, int timeStamp, Map<String, List<String>> headers)
      : super(messageId, requestId, timeStamp, headers);

  /// Converts the response to a json object
  dynamic toJson() {
    final data = Map<String, dynamic>();

    data['type'] = 'response';
    data['statusCode'] = statusCode;
    data['writeTime'] = writeTime;
    data['readTime'] = readTime;
    data['waitTime'] = waitTime;
    data['httpVersion'] = httpVersion;
    data['statusLine'] = statusLine;

    if (actualNetworkRequest != null) data['networkRequest'] = actualNetworkRequest.toJson();
    if (actualNetworkResponse != null) data['networkReply'] = actualNetworkResponse.toJson();
    updateJson(data);
    return data;
  }

  /// Converts the response to a json string
  String toJsonString() {
    return json.encode(toJson());
  }
}
