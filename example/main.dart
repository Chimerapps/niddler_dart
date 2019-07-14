import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:niddler_dart/niddler_dart.dart';

Future<void> main() async {
  final niddlerBuilder = NiddlerBuilder()
    ..bundleId = 'com.test.test'
    ..serverInfo =
        NiddlerServerInfo('Some descriptive name', 'Some description')
    ..port =
        0; //0 to have niddler pick it's own port. Automatic discovery will make this visible

  final niddler = niddlerBuilder.build()..addBlacklist(RegExp('.*/get'));
  await niddler.start();
  NiddlerInjector.install(niddler);

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
  final response2 = await http.get('http://httpbin.org/get',
      headers: {'content-type': 'application/json'});
  await http.get(
      'https://raw.githubusercontent.com/zynksoftware/samples/master/XML%20Samples/Credit%20note%20with%20Sales%20Payment.xml');
  await http.get('https://www.google.com/'); //Some html!
  await http.get('http://placekitten.com/200/300');

  print('Post body: ${response.body}');
  print('Get body (blacklisted): ${response2.body}');

  await Future.delayed(Duration(seconds: 100));

  await niddler.stop();

  await Future.delayed(Duration(seconds: 2));
}
