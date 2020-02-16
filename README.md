Niddler network inspector for dart and flutter

![latestVersion](https://img.shields.io/github/release/Chimerapps/niddler_dart.svg)

## Usage

A simple usage example:

For a more complete example, see `example/main.dart`.

```dart
import 'package:niddler_dart/niddler_dart.dart';

main() {

final niddlerBuilder = NiddlerBuilder()
    ..bundleId = 'com.test.test'
    ..serverInfo = NiddlerServerInfo('Some descriptive name', 'Some description')
    ..port = 0; //0 to have niddler pick it's own port. Automatic discovery will make this visible

  final niddler = niddlerBuilder.build();
  await niddler.start();
  niddler.install();
  
  //Make http requests ...
  
  await niddler.stop();
}
```

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Chimerapps/niddler_dart/issues
