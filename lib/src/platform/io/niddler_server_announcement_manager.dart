// Copyright (c) 2019, Nicola Verbeeck
// All rights reserved. Use of this source code is governed by
// an MIT license that can be found in the LICENSE file.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:niddler_dart/src/niddler_log.dart';
import 'package:niddler_dart/src/platform/io/niddler_server.dart';
import 'package:synchronized/synchronized.dart';

const int _ANNOUNCEMENT_SOCKET_PORT = 6394;
const int _COMMAND_REQUEST_QUERY = 0x01;
const int _COMMAND_REQUEST_ANNOUNCE = 0x02;
const int _ANNOUNCEMENT_VERSION = 3;

const int EXTENSION_TYPE_ICON = 1;
const int EXTENSION_TYPE_TAG = 2;

/// TCP based server that handles niddler client announcements.
/// These announcements allow clients to discover all processes which currently have niddler enabled.
class NiddlerServerAnnouncementManager {
  final String _packageName;
  final _extensions = <AnnouncementExtension>[];

  final NiddlerServer _server;
  final lock = Lock();
  bool _running = false;
  ServerSocket _serverSocket;
  Socket _slaveSocket;

  NiddlerServerAnnouncementManager(this._packageName, this._server);

  void addExtension(AnnouncementExtension extension) {
    _extensions.add(extension);
  }

  /// Start the announcement server
  Future<void> start() async {
    return lock.synchronized(() async {
      if (_running) return;
      _running = true;

      _startLoop();
    });
  }

  void _startLoop() {
    final _slaves = <_Slave>[];

    Future.doWhile(() async {
      final streamer = StreamController();
      var awaitStreamer = true;
      try {
        niddlerVerbosePrint('Attempting to start in master mode');
        final serverSocket = await ServerSocket.bind(
            InternetAddress.anyIPv4, _ANNOUNCEMENT_SOCKET_PORT)
          ..listen((socket) {
            _onSocket(socket, _slaves);
          }, onError: (e) async {
            niddlerDebugPrint('On error, closing ($e)');
            streamer.add(1);
            // ignore: cascade_invocations
            await streamer.close();
          }, onDone: () async {
            niddlerVerbosePrint('Server socket done');
            streamer.add(2);
            // ignore: cascade_invocations
            await streamer.close();
          });
        await lock.synchronized(() {
          if (_running) {
            _serverSocket = serverSocket;
          } else {
            serverSocket.close();
            _slaveSocket = null;
          }
        });
      } catch (e) {
        niddlerVerbosePrint('Got error in master mode, trying as slave');
        try {
          if (await lock.synchronized(() => _running)) {
            awaitStreamer = false;
            await _runSlave();
            niddlerVerbosePrint('Run slave has returned');
          }
        } catch (e) {
          niddlerVerbosePrint('Got error in slave mode');
          awaitStreamer = false;
        } finally {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      if (awaitStreamer) {
        niddlerVerbosePrint('Awaiting run loop results');
        final data = await streamer.stream.first;
        niddlerVerbosePrint('Run loop finished a loop with $data');
      }

      return lock.synchronized(() => _running);
    });
  }

  /// Stop the announcement server
  Future<void> stop() async {
    return lock.synchronized(() async {
      _running = false;
      if (_serverSocket != null) {
        await _serverSocket.close();
      }
      if (_slaveSocket != null) {
        await _slaveSocket.close();
      }
      _serverSocket = null;
      _slaveSocket = null;
    });
  }

  Future<void> _onSocket(Socket socket, List<_Slave> slaves) async {
    niddlerVerbosePrint('Got announcement slave connection');
    Stream<List<int>> dataStream;
    if (!socket.isBroadcast) {
      dataStream = socket.asBroadcastStream();
    } else {
      dataStream = socket;
    }
    final data = await dataStream.first;
    if (data.isEmpty) {
      return socket.close();
    }
    final command = data[0];
    if (command == _COMMAND_REQUEST_QUERY) {
      final responseData = await _handleQuery(dataStream, slaves);
      socket.add(responseData);
      await socket.flush();
      await socket.close();
    } else if (command == _COMMAND_REQUEST_ANNOUNCE) {
      await _handleAnnounce(dataStream, socket, data, slaves);
    }
  }

  Future<List<int>> _handleQuery(
      Stream<List<int>> socket, List<_Slave> slaves) async {
    niddlerVerbosePrint('Got query request');
    final responses = <Map<String, dynamic>>[];

    final responseData = <String, dynamic>{};
    responseData['packageName'] = _packageName;
    responseData['port'] = _server.port;
    responseData['pid'] = -1;
    responseData['protocol'] = NiddlerServer.protocolVersion;
    responseData['extensions'] = _extensions.map((ext) {
      return {
        'name': ext.name,
        'data': base64.encoder.convert(ext.data()),
      };
    }).toList();
    responses.add(responseData);

    slaves.forEach((slave) {
      final slaveDescriptor = <String, dynamic>{};
      slaveDescriptor['packageName'] = slave.packageName;
      slaveDescriptor['port'] = slave.port;
      slaveDescriptor['pid'] = slave.pid;
      slaveDescriptor['protocol'] = slave.protocolVersion;
      slaveDescriptor['extensions'] = slave.extensions.map((ext) {
        return {
          'name': ext.name,
          'data': base64.encoder.convert(ext.data()),
        };
      }).toList();
      responses.add(slaveDescriptor);
    });
    return utf8.encode(json.encode(responses));
  }

  static Future<void> _handleAnnounce(Stream<List<int>> socket, Socket done,
      List<int> initialData, List<_Slave> slaves) async {
    niddlerVerbosePrint('Got slave announce');

    final byteView = _SocketByteView(initialData, socket);

    final version = await byteView.getInt32();
    final packageNameLength = await byteView.getInt32();
    final packageName = utf8.decode(await byteView.getBytes(packageNameLength));
    final port = await byteView.getInt32();
    final pid = await byteView.getInt32();
    final protocolVersion = await byteView.getInt32();

    final extensions = <AnnouncementExtension>[];
    String icon;
    if (version == 2) {
      final iconLength = await byteView.getInt32();
      if (iconLength > 0) {
        icon = utf8.decode(await byteView.getBytes(iconLength));
      }
      extensions.add(IconExtension(icon));
    } else if (version >= _ANNOUNCEMENT_VERSION) {
      final extensionCount = await byteView.getInt16();
      for (var i = 0; i < extensionCount; ++i) {
        final type = await byteView.getInt16();
        final size = await byteView.getInt16();
        final extensionBytes = await byteView.getBytes(size);

        switch (type) {
          case EXTENSION_TYPE_TAG:
            extensions.add(TagExtension(utf8.decode(extensionBytes)));
            break;
          case EXTENSION_TYPE_ICON:
            extensions.add(IconExtension(utf8.decode(extensionBytes)));
            break;
        }
      }
    }

    final slave = _Slave(
      packageName,
      port,
      pid,
      protocolVersion,
      extensions,
    );
    niddlerVerbosePrint('Got new slave: $packageName on $port');
    slaves.add(slave);
    // ignore: unawaited_futures
    socket.drain().then((_) {
      print('Slave at $port closed');
      return slaves.remove(slave);
    });
    return;
  }

  Future<void> _runSlave() async {
    niddlerVerbosePrint('Connecting slave socket');
    final slaveSocket = await Socket.connect(
        InternetAddress.loopbackIPv4, _ANNOUNCEMENT_SOCKET_PORT);
    final doContinue = await lock.synchronized(() async {
      if (_running) {
        _slaveSocket = slaveSocket;
        return true;
      } else {
        await slaveSocket.close();
        return false;
      }
    });
    if (!doContinue) return;

    final packageNameBytes = utf8.encode(_packageName);
    //Command + version + packageName length + packageName + port + pid + protocolVersion + extension count
    var length = 1 + 4 + 4 + packageNameBytes.length + 4 + 4 + 4 + 2;

    _extensions.forEach((ex) => length += 4 + ex.length());

    final data = Int8List(length);
    final bytes = data.buffer;
    final byteView = ByteData.view(bytes);
    data[0] = _COMMAND_REQUEST_ANNOUNCE;
    var offset = 1;
    byteView.setInt32(offset, _ANNOUNCEMENT_VERSION);
    offset += 4;
    byteView.setInt32(offset, packageNameBytes.length);
    offset += 4;
    data.setAll(offset, packageNameBytes);
    offset += packageNameBytes.length;
    byteView.setInt32(offset, _server.port);
    offset += 4;
    byteView.setInt32(offset, -1); //PID
    offset += 4;
    byteView.setInt32(offset, NiddlerServer.protocolVersion);
    offset += 4;
    byteView.setInt16(offset, _extensions.length);
    offset += 2;

    _extensions.forEach((extension) {
      byteView.setInt16(offset, extension.type);
      offset += 2;
      byteView.setInt16(offset, extension.length());
      offset += 2;
      data.setAll(offset, extension.data());
      offset += extension.length();
    });

    niddlerVerbosePrint('Sending slave data');
    slaveSocket.add(data);
    niddlerVerbosePrint('Flushing slave data');
    await slaveSocket.flush();
    niddlerVerbosePrint('Waiting for slave socket to close');
    slaveSocket.drain().then((value) async {
      // ignore: unawaited_futures
      niddlerVerbosePrint('Master seems to have gone away! Closing slave');
      await slaveSocket.close();
      niddlerVerbosePrint('Slave closed for master');

      await lock.synchronized(() async {
        _slaveSocket = null;
      });
    });
    await slaveSocket.done.then((value) async {
      niddlerVerbosePrint('Closing slave');
      await slaveSocket.close();
      niddlerVerbosePrint('Slave closed');

      await lock.synchronized(() async {
        _slaveSocket = null;
      });
    });
    niddlerVerbosePrint('Run slave existing');
  }
}

class _Slave {
  final String packageName;
  final int port;
  final int pid;
  final int protocolVersion;
  final List<AnnouncementExtension> extensions;

  _Slave(
    this.packageName,
    this.port,
    this.pid,
    this.protocolVersion,
    this.extensions,
  );
}

abstract class AnnouncementExtension {
  final int type;
  final String name;

  AnnouncementExtension(this.type, this.name);

  int length();

  List<int> data();
}

class StringExtension extends AnnouncementExtension {
  final List<int> _data;

  StringExtension(int type, String name, String data)
      : _data = utf8.encode(data),
        super(type, name);

  @override
  List<int> data() => _data;

  @override
  int length() => _data.length;
}

class TagExtension extends StringExtension {
  TagExtension(String tag) : super(EXTENSION_TYPE_TAG, 'tag', tag);
}

class IconExtension extends StringExtension {
  IconExtension(String tag) : super(EXTENSION_TYPE_ICON, 'icon', tag);
}

class _SocketByteView {
  final Stream<List<int>> _socket;
  List<int> _currentBlob;
  int _offsetInCurrentBlob = 1;

  _SocketByteView(this._currentBlob, this._socket);

  Future<int> getInt32() async {
    final list = Int8List(4);
    list[0] = await getByte();
    list[1] = await getByte();
    list[2] = await getByte();
    list[3] = await getByte();
    return ByteData.view(list.buffer).getInt32(0);
  }

  Future<int> getInt16() async {
    final list = Int8List(2);
    list[0] = await getByte();
    list[1] = await getByte();
    return ByteData.view(list.buffer).getInt16(0);
  }

  Future<Int8List> getBytes(int length) async {
    final list = Int8List(length);
    for (var i = 0; i < length; ++i) {
      list[i] = await getByte();
    }
    return list;
  }

  Future<int> getByte() async {
    if (_currentBlob != null && _offsetInCurrentBlob < _currentBlob.length)
      return _currentBlob[_offsetInCurrentBlob++];

    _currentBlob = await _socket.first;
    _offsetInCurrentBlob = 0;

    return getByte();
  }
}
