import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';

/// Encodes user-selected images into a single, compact upload format.
///
/// Keeping this at the upload boundary guarantees that every new image stored
/// by the app is WebP, regardless of whether the source was JPG, PNG, HEIC,
/// or a camera-generated format.
class ImageUploadCodec {
  ImageUploadCodec._();

  static const int _quality = 82;
  static const int _maxDimension = 1600;

  static Future<Uint8List> fromXFile(XFile image) async {
    final source = await image.readAsBytes();
    return fromBytes(source);
  }

  static Future<Uint8List> fromBytes(Uint8List source) async {
    if (source.isEmpty) {
      throw const FormatException('الصورة المختارة فارغة أو تالفة');
    }

    final encoded = await FlutterImageCompress.compressWithList(
      source,
      format: CompressFormat.webp,
      quality: _quality,
      minWidth: _maxDimension,
      minHeight: _maxDimension,
    );

    if (encoded == null || encoded.isEmpty) {
      throw const FormatException('تعذر تحويل الصورة إلى WebP');
    }

    return Uint8List.fromList(encoded);
  }
}
