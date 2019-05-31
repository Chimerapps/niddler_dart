import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:niddler_dart/niddler_dart.dart';

Future<void> main() async {
  final niddlerBuilder = NiddlerBuilder()
    ..bundleId = 'com.test.test'
    ..serverInfo = NiddlerServerInfo('Some descriptive name', 'Some description')
    ..port = 0; //0 to have niddler pick it's own port. Automatic discovery will make this visible

  final niddler = niddlerBuilder.build();
  await niddler.start();
  NiddlerInjector.install(niddler);

  final value = {'test': 'data'};

  final response = await http.post('http://httpbin.org/post', body: json.encode(value), headers: {'content-type': 'application/json'});
  print('Post body: ${response.body}');

  await Future.delayed(Duration(seconds: 100));

  await niddler.stop();

  await Future.delayed(Duration(seconds: 2));
}
