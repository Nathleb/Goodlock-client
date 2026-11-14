import 'package:flutter/material.dart';

import '../net/models.dart';
import 'die_face_tile.dart';

/// What a face does, in a few characters: its first effect and value ("5", "S" for a Swap, "+" for a
/// stat change, "◆" for a state), "·" for a blank face.
String faceGlyphText(DieFace face) {
  if (face.effects.isEmpty) return '·';
  final e = face.effects.first;
  return switch (e.effect) {
    'Swap' => 'S',
    'ApplyStat' => e.magnitude >= 0 ? '+' : '−',
    'ApplyState' => '◆',
    _ => '${e.magnitude}',
  };
}

/// A face as a small coloured square: the colour of its first effect, its value inside.
class FaceGlyph extends StatelessWidget {
  final DieFace face;
  final double size;
  final bool kept;
  const FaceGlyph({super.key, required this.face, this.size = 26, this.kept = false});

  @override
  Widget build(BuildContext context) {
    final color = face.effects.isEmpty ? Colors.white24 : (effectColors[face.effects.first.effect] ?? Colors.white54);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color, width: kept ? 2 : 1),
      ),
      child: Text(
        faceGlyphText(face),
        style: TextStyle(fontSize: size * 0.5, fontWeight: FontWeight.bold),
      ),
    );
  }
}
