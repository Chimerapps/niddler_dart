import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:niddler_dart/niddler_dart.dart';
import 'package:stack_trace/stack_trace.dart';

Future<void> main(List<String> arguments) async {
  await Chain.capture(() async {
    final niddlerBuilder = NiddlerBuilder()
      ..bundleId = 'com.test.test'
      ..serverInfo = NiddlerServerInfo(
          'Some descriptive name', 'Some description', icon: 'dart')
      ..includeStackTrace = true
      ..port =
          0; //0 to have niddler pick it's own port. Automatic discovery will make this visible

    final niddler = niddlerBuilder.build()..addBlacklist(RegExp('.*/get'));

    if (arguments.isNotEmpty) {
      print('Starting and waiting for debugger');
    }

    await niddler.start(waitForDebugger: arguments.isNotEmpty);
    if (arguments.isNotEmpty) {
      print('Debugger connected!');
    }
    niddler.install();

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

Future<void> executeGetTypeCode() async {
  final result = await http.get('http://jsonplaceholder.typicode.com/posts');
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
  final response = await http.post('http://httpbin.org/post',
      body: json.encode(value), headers: {'content-type': 'application/json'});
  print('Post body: ${response.body}');
}

Future<void> executeGet() async {
  final response2 = await http.get('http://httpbin.org/get',
      headers: {'content-type': 'application/json'});
  print('Get body (blacklisted): ${response2.body}');
}

Future<void> executePost2() async {
  await http.post('http://httpbin.org/post',
      body: {'user': 'example@example.com', 'password': 'superSecretPassword'});
}

Future<void> getImage() async {
  await http.get('http://placekitten.com/200/300');
}
