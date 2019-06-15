import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:niddler_dart/niddler_dart.dart';
import 'package:stack_trace/stack_trace.dart';

Future<void> main() async {
  await Chain.capture(() async {
    final niddlerBuilder = NiddlerBuilder()
      ..bundleId = 'com.test.test'
      ..serverInfo = NiddlerServerInfo('Some descriptive name', 'Some description')
      ..port = 0; //0 to have niddler pick it's own port. Automatic discovery will make this visible

    final niddler = niddlerBuilder.build()..addBlacklist(RegExp('.*/get'));
    await niddler.start();
    NiddlerInjector.install(niddler);

    await executePost1();
    await executeGet();
    await executePost2();
    await getImage();

    await Future.delayed(Duration(seconds: 10000));

    await niddler.stop();

    await Future.delayed(Duration(seconds: 2));
  });
}

Future<void> executePost1() async {
  final value = {'test': 'data'};
  final response = await http.post('http://httpbin.org/post', body: json.encode(value), headers: {'content-type': 'application/json'});
  print('Post body: ${response.body}');
}

Future<void> executeGet() async {
  final response2 = await http.get('http://httpbin.org/get', headers: {'content-type': 'application/json'});
  print('Get body (blacklisted): ${response2.body}');
}

Future<void> executePost2() async {
  await http.post('http://httpbin.org/post', body: {'user': 'example@example.com', 'password': 'superSecretPassword'});
}

Future<void> getImage() async {
  await http.get('http://placekitten.com/200/300');
}
