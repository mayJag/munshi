// Generates Munshi's launcher icon assets: a teal square with a white "M"
// monogram (full icon) and a padded transparent foreground for adaptive icons.
// Run: dart run tool/gen_icon.dart  (then: dart run flutter_launcher_icons)

import 'dart:io';

import 'package:image/image.dart' as img;

void main() {
  const size = 1024;
  final teal = img.ColorRgb8(0x0D, 0x94, 0x88);
  final tealDark = img.ColorRgb8(0x0B, 0x3B, 0x36);
  final white = img.ColorRgb8(0xFF, 0xFF, 0xFF);

  Directory('assets/icon').createSync(recursive: true);

  // Full icon: teal diagonal gradient background + monogram.
  final full = img.Image(width: size, height: size);
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final t = (x + y) / (2 * size);
      full.setPixelRgb(
        x,
        y,
        (teal.r + (tealDark.r - teal.r) * t).round(),
        (teal.g + (tealDark.g - teal.g) * t).round(),
        (teal.b + (tealDark.b - teal.b) * t).round(),
      );
    }
  }
  _drawM(full, white, size, scale: 0.24);
  File('assets/icon/munshi_full.png').writeAsBytesSync(img.encodePng(full));

  // Adaptive foreground: transparent, smaller mark inside the safe zone.
  final fg = img.Image(width: size, height: size, numChannels: 4);
  _drawM(fg, white, size, scale: 0.18);
  File('assets/icon/munshi_fg.png').writeAsBytesSync(img.encodePng(fg));

  stdout.writeln('Wrote assets/icon/munshi_full.png and munshi_fg.png');
}

void _drawM(img.Image im, img.Color c, int size, {required double scale}) {
  final cx = size / 2;
  final cy = size / 2;
  final w = size * scale;
  final h = size * scale * 1.25;
  final x1 = (cx - w).round();
  final x2 = (cx + w).round();
  final y1 = (cy - h / 2).round();
  final y2 = (cy + h / 2).round();
  final ymid = (cy + h * 0.12).round();
  final thick = (size * scale * 0.34).round();

  void line(int ax, int ay, int bx, int by) => img.drawLine(im,
      x1: ax, y1: ay, x2: bx, y2: by, color: c, thickness: thick, antialias: true);

  line(x1, y2, x1, y1); // left stem
  line(x1, y1, cx.round(), ymid); // left diagonal to middle
  line(cx.round(), ymid, x2, y1); // right diagonal up
  line(x2, y1, x2, y2); // right stem
}
