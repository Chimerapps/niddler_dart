Niddler network inspector for dart and flutter. Download the niddler intellij plugin [here](https://plugins.jetbrains.com/plugin/10347-niddler)

![latestVersion](https://img.shields.io/github/release/Chimerapps/niddler_dart.svg)

## Usage

A simple usage example:

For a more complete example, see `example/main.dart`.

```dart
import 'package:niddler_dart/niddler_dart.dart';
import 'package:stack_trace/stack_trace.dart';

main() async {
  await Chain.capture(() async { //For better flutter stack traces, wrap main code in this Chain.capture from package stack_trace
    final niddlerBuilder = NiddlerBuilder()
        ..bundleId = 'com.test.test'
        ..serverInfo = NiddlerServerInfo('Some descriptive name', 'Some description')
        ..includeStackTrace = true //Capture request stack traces. Wrap all content inside main with `Chain.capture`
        ..port = 0; //0 to have niddler pick it's own port. Automatic discovery will make this visible
  
      final niddler = niddlerBuilder.build();
      await niddler.start();
      niddler.install();
  
      //Optionally wait for debugger to connect
      await niddler.debugger.waitForConnection();
    
      //Make http requests ...
    
      await niddler.stop();
  });
}
```

## Debugging support
Since 0.7.0 basic debugging support has been added to the library. Use the plugin to connect with a debugger connection. 
When so required, you can wait for the debugger to be connected before continuing with the application, to ensure the debugger is attached before
any requests are made by using `await niddler.debugger.waitForConnection();`

Not that using the debugger has a more noticeable performance impact

## Request site stack traces
Since 0.6.0, niddler supports capturing stack traces at request site across async boundaries. This can have a (very) small performance impact.

To enable, configure niddler to include stack traces by setting `includeStackTrace = true` in the builder, optionally configuring which stack frames to throw out
via `sanitizer = implementation of StackTraceSanitizer` (defaults to a reasonable sanitizer for dart/flutter/dio).

To capture stack traces across async blocks, wrap **ALL** code inside your main with `Chain.capture` from `package:stack_trace`

Viewing stack traces for dart code is supported in the intellij plugin since version 2.5.0

## Features and bugs

Please file feature requests and bugs at the [issue tracker][tracker].

[tracker]: https://github.com/Chimerapps/niddler_dart/issues
