import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// خدمة رفع الصور إلى Supabase Storage.
///
/// المسارات مطابقة لسياسات Storage الحالية:
/// - charity-images: charities/<user-id>/<file>
/// - restaurant-offers: <user-id>/<file>
/// - community-offers: direct/<user-id>/<file>
class loqmaImageStorageService {
  final SupabaseClient _client;

  loqmaImageStorageService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  Future<User> _requireUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw const loqmaStorageAuthException('يجب تسجيل الدخول أولًا');
    }
    return user;
  }

  Future<String> uploadCharityLogo(XFile image) async {
    final user = await _requireUser();

    return _upload(
      bucket: 'charity-images',
      path: 'charities/${user.id}/${_fileName(image)}',
      image: image,
      errorMessage: 'تعذر رفع صورة الجمعية. حاول مرة أخرى.',
    );
  }

  Future<String> uploadRestaurantOfferImage(XFile image) async {
    final user = await _requireUser();

    // مطابق لسياسة UUID-first الخاصة بـ restaurant-offers
    final path = '${user.id}/${_fileName(image)}';

    debugPrint('UPLOAD BUCKET: restaurant-offers');
    debugPrint('UPLOAD PATH: $path');
    debugPrint('AUTH USER: ${user.id}');

    return _upload(
      bucket: 'restaurant-offers',
      path: path,
      image: image,
      errorMessage: 'تعذر رفع صورة العرض. حاول مرة أخرى.',
    );
  }

  Future<List<String>> uploadRestaurantOfferImages(
    List<XFile> images,
  ) async {
    final paths = <String>[];
    for (final image in images) {
      paths.add(await uploadRestaurantOfferImage(image));
    }
    return paths;
  }

  Future<String> uploadCharityDonationImage(XFile image) async {
    final user = await _requireUser();

    // مطابق لسياسة direct_donation_images_insert.
    // هنا direct صحيح لأن policy تقرأ UUID من الجزء الثاني.
    final path = 'direct/${user.id}/${_fileName(image)}';

    debugPrint('DONATION IMAGE BUCKET: community-offers');
    debugPrint('DONATION IMAGE PATH: $path');
    debugPrint('AUTH USER: ${user.id}');

    return _upload(
      bucket: 'community-offers',
      path: path,
      image: image,
      errorMessage: 'تعذر رفع صورة التبرع. حاول مرة أخرى.',
    );
  }

  Future<List<String>> uploadCharityDonationImages(
    List<XFile> images,
  ) async {
    final paths = <String>[];
    for (final image in images) {
      paths.add(await uploadCharityDonationImage(image));
    }
    return paths;
  }

  Future<String> _upload({
    required String bucket,
    required String path,
    required XFile image,
    required String errorMessage,
  }) async {
    try {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) {
        throw StateError('empty image');
      }

      final extension = _extension(image.name);
      final finalPath = _replaceExtension(path, extension);

      await _client.storage.from(bucket).uploadBinary(
            finalPath,
            Uint8List.fromList(bytes),
            fileOptions: FileOptions(
              contentType: _contentType(extension),
              upsert: false,
            ),
          );

      debugPrint('IMAGE UPLOAD SUCCESS: bucket=$bucket path=$finalPath');

      // تحفظ هذه القيمة نفسها في عمود images داخل قاعدة البيانات.
      return finalPath;
    } on StorageException catch (error, stackTrace) {
      // التفاصيل تبقى للمطور فقط ولا تظهر للمستخدم.
      debugPrint('STORAGE ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw StateError(errorMessage);
    } catch (error, stackTrace) {
      debugPrint('IMAGE UPLOAD ERROR: $error');
      debugPrintStack(stackTrace: stackTrace);
      throw StateError(errorMessage);
    }
  }

  String _fileName(XFile image) {
    return '${DateTime.now().microsecondsSinceEpoch}.${_extension(image.name)}';
  }

  String _replaceExtension(String path, String extension) {
    final pattern = RegExp(r'\.[a-zA-Z0-9]+$');
    if (!pattern.hasMatch(path)) return '$path.$extension';
    return path.replaceFirst(pattern, '.$extension');
  }

  String _extension(String name) {
    final extension = name.split('.').last.toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp'}.contains(extension)
        ? extension
        : 'jpg';
  }

  String _contentType(String extension) {
    switch (extension) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      default:
        return 'image/jpeg';
    }
  }
}

class loqmaStorageAuthException implements Exception {
  final String message;

  const loqmaStorageAuthException(this.message);

  @override
  String toString() => message;
}
