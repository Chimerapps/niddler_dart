// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'package:synchronized/synchronized.dart';

/// Messages cache for niddler messages. Attempts to guess how much space a message will take up
class NiddlerMessageCache {
  final int _maxCacheSize;
  int _cacheSize = 0;
  final _lock = Lock();
  final List<String> _messages = [];

  NiddlerMessageCache(this._maxCacheSize);

  void clear() {
    _lock.synchronized(() async {
      _messages.clear();
      _cacheSize = 0;
    });
  }

  void put(String message) {
    final length = message.length;
    _lock.synchronized(() async {
      while ((length + _cacheSize) > _maxCacheSize) {
        if (!_evictOld()) return;
      }
      _cacheSize += length;
      _messages.add(message);
    });
  }

  Future<List<String>> allMessages() async {
    return _lock.synchronized(() async {
      return List.from(_messages, growable: false);
    });
  }

  bool _evictOld() {
    if (_messages.isEmpty) return false;

    final size = _messages.removeAt(0).length;
    _cacheSize -= size;
    return true;
  }
}
