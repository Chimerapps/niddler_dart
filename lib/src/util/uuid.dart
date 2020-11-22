import 'dart:math';

class SimpleUUID {
  static final _byteToHex =
      List.generate(256, (position) => position.toRadixString(16));

  static String uuid() {
    final bytes = List.filled(16, 0);

    final rand = Random();

    for (var i = 0; i < 16; i++) {
      bytes[i] = rand.nextInt(256);
    }

    bytes.shuffle(rand);

    // per 4.4, set bits for version and clockSeq high and reserved
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    var i = 0;
    return '${_byteToHex[bytes[i++]]}${_byteToHex[bytes[i++]]}'
        '${_byteToHex[bytes[i++]]}${_byteToHex[bytes[i++]]}-'
        '${_byteToHex[bytes[i++]]}${_byteToHex[bytes[i++]]}-'
        '${_byteToHex[bytes[i++]]}${_byteToHex[bytes[i++]]}-'
        '${_byteToHex[bytes[i++]]}${_byteToHex[bytes[i++]]}-'
        '${_byteToHex[bytes[i++]]}${_byteToHex[bytes[i++]]}'
        '${_byteToHex[bytes[i++]]}${_byteToHex[bytes[i++]]}'
        '${_byteToHex[bytes[i++]]}${_byteToHex[bytes[i++]]}';
  }
}
