import 'dart:io';

import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Picks receipt images and copies them into the app's documents directory so
/// they survive the picker's temp cache being cleared.
class ReceiptService {
  ReceiptService._();
  static final ReceiptService instance = ReceiptService._();

  final _picker = ImagePicker();

  /// Pick from [source], persist a copy, and return its absolute path (or null
  /// if the user cancelled).
  Future<String?> pick(ImageSource source) async {
    final picked = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 1600,
    );
    if (picked == null) return null;
    final dir = await getApplicationDocumentsDirectory();
    final receipts = Directory(p.join(dir.path, 'receipts'));
    if (!receipts.existsSync()) receipts.createSync(recursive: true);
    final ext = p.extension(picked.path).isEmpty
        ? '.jpg'
        : p.extension(picked.path);
    final name = 'r_${picked.name.hashCode.toUnsigned(32)}'
        '_${picked.path.length}$ext';
    final dest = p.join(receipts.path, name);
    await File(picked.path).copy(dest);
    return dest;
  }

  /// Best-effort delete of a stored receipt file.
  Future<void> deleteFile(String? path) async {
    if (path == null) return;
    try {
      final f = File(path);
      if (f.existsSync()) await f.delete();
    } catch (_) {/* ignore */}
  }
}
