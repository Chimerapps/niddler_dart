## 1.5.0

- Support dart 2.17 and up

## 1.4.1

- Replaced worker manager with Computer

## 1.4.0

- Fixed delays caused by json serialization
- Use worker manager to handle isolate pools for performance

## 1.3.0

- Added flag indicating that the debugger supports 'toggle internet'. When the internet is toggled off, all intercepted calls will throw a socket error

## 1.2.0

- Fixed wrong function types passed to delegate

## 1.1.4

- Fixed bug where responses could not be overwritten by the debugger

## 1.1.3

- Fixed typo
- Suppressed warnings

## 1.1.2

- Bugfix where some http exceptions would not be correctly propagated and cause the uncaught exception handler to fire

## 1.1.1

- Bugfix for debugger not accepting some values

## 1.1.0

- Upgraded debugger support

## 1.0.0

- Support null-safety

## 0.11.0-nullsafety.0

- Support null-safety
- Deprecate passwords

## 0.10.4

- Move to using `dart_service_announcement` for announcement

## 0.10.3

- Rewrote the connection handler to better detect dying main/secondaries

## 0.10.2

- Remove dependency on pointycastle, replace with crypto package

## 0.10.1

- Also notify done future when upgrading

## 0.10.0

- Support dart 2.10 and up

## 0.9.1

- Include debugger action id when sending debug requests to the IDE

## 0.9.0

- Allow signaling that the system should wait for the debugger connection in niddler.start. This has the advantage of providing more information to the IDE plugin.

## 0.8.1

- Code cleanup

## 0.8.0

- Support dart 2.8.0

## 0.7.5

- Implement some missing bindings on HttpClient for eg: getUrl, postUrl, ...

## 0.7.4

- Expose logging functions
- Fixes for headers not intercepting correctly

## 0.7.3

- Niddler announcement v3 support
    - Send 'tag' and 'icon' as extensions
- Print tag to allow for fast connection from IDE
- Support sending icon for session

## 0.7.2

- Fixed issue when the debugger would send non-padded base64

## 0.7.1

- Add tag header that indicates that a request/response is modified by the debugger

## 0.7.0

- Basic niddler debugging protocol support

## 0.6.0

- Capture request stack traces if so configured

## 0.5.1

- Fixed issue on hot reload (https://github.com/Chimerapps/niddler_dart/issues/4)

## 0.5.0

- Added support for flutter web by providing a no-op niddler implementation
- Small bugfix that could cause the announcement manager to crash
- Breaking change:
  `NiddlerInjector.install(niddler);` has been replaced with `niddler.install();`

## 0.4.0

- Main release now tracks dart &gt; 2.3.2
- Added extra examples in main.dart

## 0.3.1-master

- Fix for dart pub

## 0.3.0-master

- Support dart 2.3.2 and up

## 0.2.1

- Do not send 0 byte bodies

## 0.1.5

- Revert dart compatibility change. Restrict running to dart < 2.3.2 for now

## 0.1.4

- Support newer versions of dart by implementing noSuchMethod

## 0.1.3

- Use isolates to greatly reduce main event locking

## 0.1.2

- Added support for blacklisting urls

## 0.1.1

- Removed dependency on http

## 0.1.0

- Initial public version
