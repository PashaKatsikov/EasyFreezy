import 'dart:convert';
import 'dart:typed_data';

const List<int> _spice = <int>[
  0x17, 0xC4, 0x5B, 0x8E, 0x22, 0xA9, 0x63, 0xD1,
  0x4F, 0x90, 0x0C, 0xE6, 0x3D, 0x71, 0xB8, 0x14,
  0x59, 0xAE,
];

const int _span = 33;

Uint8List _tape() {
  var state = 0xC2B2AE35;
  for (var i = 0; i < _spice.length; i++) {
    state = (state + _spice[i] + (i * 0x045D9F3B)) & 0xFFFFFFFF;
    state = (state ^ (state >> 16)) & 0xFFFFFFFF;
  }
  if (state == 0) state = 0x6C8E9CF5;
  final out = Uint8List(_span);
  for (var i = 0; i < _span; i++) {
    state = (state + 0x6C078965) & 0xFFFFFFFF;
    var z = state;
    z = ((z ^ (z >> 16)) * 0x7FEB352D) & 0xFFFFFFFF;
    z = ((z ^ (z >> 15)) * 0x846CA68B) & 0xFFFFFFFF;
    z = (z ^ (z >> 16)) & 0xFFFFFFFF;
    out[i] = (z + i * 13) & 0xFF;
  }
  return out;
}

final Uint8List _tapeBytes = _tape();

int _mask(int i) => (_tapeBytes[i % _span] ^ ((i * 29) & 0xFF)) & 0xFF;

String reveal(List<int> encoded) {
  if (encoded.isEmpty) return '';
  final out = Uint8List(encoded.length);
  for (var i = 0; i < encoded.length; i++) {
    out[i] = (encoded[i] ^ _mask(i)) & 0xFF;
  }
  return utf8.decode(out);
}

List<int> fold(String plain) {
  if (plain.isEmpty) return const <int>[];
  final raw = utf8.encode(plain);
  return <int>[
    for (var i = 0; i < raw.length; i++) (raw[i] ^ _mask(i)) & 0xFF,
  ];
}
