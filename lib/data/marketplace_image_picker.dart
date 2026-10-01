import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import 'marketplace_repository.dart';

class PickedImage {
  const PickedImage({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Thrown when the chosen file cannot be used as a listing photo.
class ImagePickException implements Exception {
  const ImagePickException(this.message);
  final String message;
}

typedef ImagePickerFn = Future<PickedImage?> Function();

/// Checks type and size against the bucket rules.
void checkListingImage(String name, int sizeBytes) {
  final ext = name.split('.').last.toLowerCase();
  if (!kListingImageExtensions.contains(ext)) {
    throw const ImagePickException('Use a JPG, PNG or WebP image.');
  }
  if (sizeBytes > kListingImageMaxBytes) {
    throw const ImagePickException('The image must be 2 MB or smaller.');
  }
}

/// Default picker: same file_picker call the job application CV upload
/// uses. Returns null if the user cancels.
Future<PickedImage?> pickListingImage() async {
  final file = await FilePicker.pickFile(
    type: FileType.custom,
    allowedExtensions: kListingImageExtensions,
  );
  if (file == null) return null;
  final bytes = await file.xFile.readAsBytes();
  checkListingImage(file.name, bytes.length);
  return PickedImage(name: file.name, bytes: bytes);
}
