// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

/// Typedef for debug print callbacks
typedef NiddlerDebugPrintCallback = void Function(String message,
    {int wrapWidth});

/// Function used to print debug messages from niddler. Defaults to print
NiddlerDebugPrintCallback niddlerDebugPrint = _niddlerDartDebugPrint;

/// Function used to print verbose message from niddler. Defaults to no output
NiddlerDebugPrintCallback niddlerVerbosePrint = _dontPrint;

void _niddlerDartDebugPrint(String message, {int? wrapWidth}) {
  print(message);
}

void _dontPrint(String message, {int? wrapWidth}) {}
