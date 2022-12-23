import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:niddler_dart/niddler_dart.dart';
import 'package:stack_trace/stack_trace.dart';

Future<void> main(List<String> arguments) async {
  await Chain.capture(() async {
    final niddlerBuilder = NiddlerBuilder()
      ..bundleId = 'com.test.test'
      ..serverInfo = NiddlerServerInfo(
          'Some descriptive name', 'Some description',
          icon: 'dart')
      ..includeStackTrace = true
      ..port =
          0; //0 to have niddler pick it's own port. Automatic discovery will make this visible

    final niddler = niddlerBuilder.build(); //..addBlacklist(RegExp('.*/get'));

    final debugger = arguments.contains('debugger');
    final dummy = arguments.contains('dummy');
    if (debugger && dummy) {
      throw ArgumentError('Cannot use both debugger and dummy');
    }
    if (debugger) {
      print('Starting and waiting for debugger');
    }
    if (dummy) {
      print('Start serving replay data');
      niddler.overrideDebugger(
          ReplayDebugger(harContent: _readFile('example/playback.har')));
    }

    await niddler.start(waitForDebugger: debugger);
    if (debugger) {
      print('Debugger connected!');
    }
    niddler.install();
    await Future.delayed(const Duration(seconds: 1));

    await executeGetTypeCode();
    await executePost1();
    await executeGet();
    await executePost2();
    await getImage();

    const waitDuration = Duration(seconds: 1000000);

    print('Asking niddler to stop for $waitDuration');

    await Future.delayed(waitDuration);

    print('Asking niddler to stop');

    await niddler.stop();

    print('Niddler has stopped');

    await Future.delayed(const Duration(seconds: 1));
  });
}

String _readFile(String path) {
  return File(path).readAsStringSync();
}

Future<void> executeGetTypeCode() async {
  final result = await http
      .get(Uri.parse('http://jsonplaceholder.typicode.com/posts?test=123'));
  print(result.body);
}

Future<void> executePost1() async {
  final value = {
    'test': 'data',
    'arrayData': [
      '1',
      '2',
      '3',
      {'nested': 'nestedData'}
    ]
  };
  final response = await http.post(Uri.parse('http://httpbin.org/post'),
      body: json.encode(value), headers: {'content-type': 'application/json'});
  print('Post body: ${response.bodyBytes.length}');
}

Future<void> executeGet() async {
  final response2 = await http.get(Uri.parse('http://httpbin.org/get'),
      headers: {'content-type': 'application/json'});
  print('Get body (blacklisted): ${response2.bodyBytes.length}');
}

Future<void> executePost2() async {
  await http.post(Uri.parse('http://httpbin.org/post'),
      body: {'user': 'example@example.com', 'password': 'superSecretPassword'});
}

Future<void> getImage() async {
  await http.get(Uri.parse('http://placekitten.com/200/300'));
}
