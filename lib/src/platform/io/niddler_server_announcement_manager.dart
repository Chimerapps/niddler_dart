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
  final _extensions = List<AnnouncementExtension>();

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
    final _slaves = List<_Slave>();

    Future.doWhile(() async {
      final streamer = StreamController();
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
            await _runSlave();
            streamer.add(2);
            await streamer.close();
          }
        } catch (e) {
          niddlerVerbosePrint('Got error in slave mode');
          streamer.add(1);
          await streamer.close();
        } finally {
          await Future.delayed(const Duration(seconds: 1));
        }
      }
      await streamer.stream.first;

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
      await _handleAnnounce(dataStream, socket.done, data, slaves);
    }
  }

  Future<List<int>> _handleQuery(
      Stream<List<int>> socket, List<_Slave> slaves) async {
    niddlerVerbosePrint('Got query request');
    final responses = List<Map<String, dynamic>>();

    final responseData = Map<String, dynamic>();
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
      final slaveDescriptor = Map<String, dynamic>();
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

  static Future<void> _handleAnnounce(Stream<List<int>> socket, Future done,
      List<int> initialData, List<_Slave> slaves) async {
    niddlerVerbosePrint('Got slave announce');
    final allDataBlobs = await socket.toList();
    final allData = List<int>()
      ..addAll(initialData.getRange(1, initialData.length));
    allDataBlobs.forEach(allData.addAll);

    final byteBuffer = Int8List.fromList(allData).buffer;
    final byteView = ByteData.view(byteBuffer);

    var offset = 0;
    final version = byteView.getInt32(offset);
    offset += 4;
    final packageNameLength = byteView.getInt32(offset);
    offset += 4;
    final packageName =
        utf8.decode(byteBuffer.asInt8List(offset, packageNameLength));
    offset += packageNameLength;
    final port = byteView.getInt32(offset);
    offset += 4;
    final pid = byteView.getInt32(offset);
    offset += 4;
    final protocolVersion = byteView.getInt32(offset);
    offset += 4;

    final extensions = List<AnnouncementExtension>();
    String icon;
    if (version == 2) {
      final iconLength = byteView.getInt32(offset);
      offset += 4;
      if (iconLength > 0) {
        icon = utf8.decode(byteBuffer.asInt8List(offset, iconLength));
        offset += iconLength;
      }
      extensions.add(IconExtension(icon));
    } else if (version >= _ANNOUNCEMENT_VERSION) {
      final extensionCount = byteView.getInt16(offset);
      offset += 2;
      for (var i = 0; i < extensionCount; ++i) {
        final type = byteView.getInt16(offset);
        offset += 2;
        final size = byteView.getInt16(offset);
        offset += 2;
        final extensionBytes = byteBuffer.asInt8List(offset, size);
        offset += size;

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
    done.then((_) => slaves.remove(slave));
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
    niddlerVerbosePrint('Closing slave');
    await slaveSocket.close();
    niddlerVerbosePrint('Slave closed');
    await lock.synchronized(() async {
      _slaveSocket = null;
    });
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
